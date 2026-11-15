import asyncio
import logging
import os
import tempfile
from pathlib import Path
from typing import Any

from app.core.errors import UpstreamUnavailableError
from app.domain.models import TranscriptionResult

logger = logging.getLogger(__name__)


class FasterWhisperSTTProvider:
    def __init__(
        self,
        *,
        model_size: str = "base",
        compute_type: str = "int8",
        device: str = "cpu",
        download_root: str | None = None,
    ) -> None:
        self._model_size = model_size
        self._compute_type = compute_type
        self._device = device
        self._download_root = download_root
        self._model: Any = None
        self._lock = asyncio.Lock()

    @property
    def name(self) -> str:
        return "faster-whisper"

    async def _get_model(self) -> Any:
        if self._model is not None:
            return self._model
        async with self._lock:
            if self._model is not None:
                return self._model
            try:
                self._model = await asyncio.to_thread(self._load_model_sync)
            except Exception as exc:
                logger.warning("Failed to load faster-whisper model: %s", type(exc).__name__)
                raise UpstreamUnavailableError(
                    "STT model is unavailable.",
                    status_code=503,
                ) from None
        return self._model

    def _load_model_sync(self) -> Any:
        from faster_whisper import WhisperModel

        kwargs: dict[str, Any] = {
            "device": self._device,
            "compute_type": self._compute_type,
        }
        if self._download_root:
            kwargs["download_root"] = self._download_root
        return WhisperModel(self._model_size, **kwargs)

    @staticmethod
    def _transcribe_sync(
        model: Any,
        audio: bytes,
        suffix: str,
        language: str,
    ) -> TranscriptionResult:
        tmp_path = ""
        try:
            with tempfile.NamedTemporaryFile(suffix=suffix, delete=False) as tmp:
                tmp.write(audio)
                tmp_path = tmp.name
            segments, info = model.transcribe(tmp_path, language=language or None)
            parts = [seg.text.strip() for seg in segments if getattr(seg, "text", "")]
            text = " ".join(parts).strip()
            detected_lang = getattr(info, "language", None) or language or "en"
            duration = float(getattr(info, "duration", 0.0) or 0.0)
            return TranscriptionResult(text=text, language=detected_lang, duration_s=duration)
        finally:
            if tmp_path and os.path.exists(tmp_path):
                os.unlink(tmp_path)

    async def transcribe(
        self,
        audio: bytes,
        *,
        filename: str,
        content_type: str | None,
        language: str,
    ) -> TranscriptionResult:
        model = await self._get_model()
        suffix = Path(filename).suffix.lower() or ".wav"
        try:
            return await asyncio.to_thread(
                self._transcribe_sync,
                model,
                audio,
                suffix,
                language,
            )
        except Exception as exc:
            logger.warning("faster-whisper transcription error: %s", type(exc).__name__)
            raise UpstreamUnavailableError(
                "STT transcription failed.",
                status_code=502,
            ) from None
