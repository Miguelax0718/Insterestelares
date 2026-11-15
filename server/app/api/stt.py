import re
from pathlib import Path
from typing import Annotated

from fastapi import APIRouter, Depends, File, Form, Request, UploadFile

from app.api.schemas import STTResponse
from app.core.errors import InvalidRequestError, PayloadTooLargeError
from app.core.rate_limit import enforce_rate_limit
from app.domain.ports import ProviderRegistry

router = APIRouter(prefix="/v1", tags=["stt"])

MAX_AUDIO_BYTES = 10 * 1024 * 1024
READ_CHUNK_BYTES = 64 * 1024
ALLOWED_EXTENSIONS = {".wav", ".webm", ".ogg", ".m4a", ".mp3"}
ALLOWED_CONTENT_TYPES = {
    "audio/wav",
    "audio/x-wav",
    "audio/wave",
    "audio/vnd.wave",
    "audio/webm",
    "video/webm",
    "audio/ogg",
    "application/ogg",
    "audio/mp4",
    "audio/m4a",
    "audio/x-m4a",
    "audio/mpeg",
    "audio/mp3",
}
LANGUAGE_RE = re.compile(r"^[A-Za-z]{2,3}(-[A-Za-z0-9]{2,8})?$")


def _validate_audio_metadata(filename: str, content_type: str | None) -> None:
    ext = Path(filename).suffix.lower()
    ct = (content_type or "").split(";", 1)[0].strip().lower()

    if ext:
        if ext not in ALLOWED_EXTENSIONS:
            raise InvalidRequestError(
                "Unsupported audio format. Allowed: wav, webm, ogg, m4a, mp3."
            )
        if ct and ct != "application/octet-stream" and ct not in ALLOWED_CONTENT_TYPES:
            raise InvalidRequestError(
                "Unsupported audio content type. Allowed: wav, webm, ogg, m4a, mp3."
            )
        return

    if ct not in ALLOWED_CONTENT_TYPES:
        raise InvalidRequestError(
            "Unsupported audio format. Allowed: wav, webm, ogg, m4a, mp3."
        )


async def _read_bounded_audio(upload: UploadFile) -> bytes:
    chunks: list[bytes] = []
    total = 0
    while True:
        chunk = await upload.read(READ_CHUNK_BYTES)
        if not chunk:
            break
        total += len(chunk)
        if total > MAX_AUDIO_BYTES:
            raise PayloadTooLargeError("Audio file exceeds 10 MB limit.")
        chunks.append(chunk)
    return b"".join(chunks)


@router.post(
    "/stt",
    response_model=STTResponse,
    dependencies=[Depends(enforce_rate_limit)],
)
async def post_stt(
    request: Request,
    audio: Annotated[UploadFile, File(...)],
    language: Annotated[str, Form()] = "en",
) -> STTResponse:
    clean_lang = language.strip() or "en"
    if not LANGUAGE_RE.fullmatch(clean_lang):
        raise InvalidRequestError("Invalid language code.")

    filename = audio.filename or ""
    _validate_audio_metadata(filename, audio.content_type)

    audio_bytes = await _read_bounded_audio(audio)
    if not audio_bytes:
        raise InvalidRequestError("Audio file must not be empty.")

    providers: ProviderRegistry = request.app.state.providers
    result = await providers.stt.transcribe(
        audio_bytes,
        filename=filename or "audio.wav",
        content_type=audio.content_type,
        language=clean_lang,
    )
    return STTResponse(
        text=result.text,
        language=result.language,
        duration_s=result.duration_s,
    )
