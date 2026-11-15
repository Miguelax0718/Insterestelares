import asyncio
import io
import logging
import re
import wave
from pathlib import Path
from typing import Any

from app.core.errors import InvalidRequestError, UpstreamUnavailableError

logger = logging.getLogger(__name__)

VOICE_NAME_RE = re.compile(r"^[A-Za-z0-9_.-]+$")


class PiperTTSProvider:
    def __init__(
        self,
        *,
        default_voice: str = "es_MX-claude-high",
        voices_dir: str = "/app/voices",
    ) -> None:
        self._default_voice = default_voice
        self._voices_dir = Path(voices_dir)
        self._voices: dict[str, Any] = {}
        self._lock = asyncio.Lock()

    @property
    def name(self) -> str:
        return "piper"

    def _resolve_voice_path(self, voice_name: str) -> Path:
        if not VOICE_NAME_RE.fullmatch(voice_name) or ".." in voice_name:
            raise InvalidRequestError("Invalid voice identifier.")
        onnx_name = voice_name if voice_name.endswith(".onnx") else f"{voice_name}.onnx"
        candidate = (self._voices_dir / onnx_name).resolve()
        base_dir = self._voices_dir.resolve()
        if candidate.parent != base_dir and base_dir not in candidate.parents:
            raise InvalidRequestError("Invalid voice path.")
        return candidate

    async def _get_voice(self, voice_name: str) -> Any:
        if voice_name in self._voices:
            return self._voices[voice_name]
        model_path = self._resolve_voice_path(voice_name)
        async with self._lock:
            if voice_name in self._voices:
                return self._voices[voice_name]
            try:
                loaded = await asyncio.to_thread(self._load_voice_sync, model_path)
            except Exception as exc:
                logger.warning("Failed to load Piper voice %s: %s", voice_name, type(exc).__name__)
                raise UpstreamUnavailableError(
                    "TTS voice model is unavailable.",
                    status_code=503,
                ) from None
            self._voices[voice_name] = loaded
            return loaded

    @staticmethod
    def _load_voice_sync(model_path: Path) -> Any:
        from piper.voice import PiperVoice

        if not model_path.is_file():
            raise FileNotFoundError(f"Voice model not found: {model_path.name}")
        return PiperVoice.load(str(model_path))

    @staticmethod
    def _synthesize_sync(voice_model: Any, text: str) -> bytes:
        buf = io.BytesIO()
        with wave.open(buf, "wb") as wav_file:
            voice_model.synthesize_wav(text, wav_file)
        return buf.getvalue()

    async def synthesize(self, text: str, *, voice: str | None = None) -> bytes:
        selected_voice = voice or self._default_voice
        voice_model = await self._get_voice(selected_voice)
        try:
            return await asyncio.to_thread(self._synthesize_sync, voice_model, text)
        except Exception as exc:
            logger.warning("Piper TTS synthesis failed: %s", type(exc).__name__)
            raise UpstreamUnavailableError(
                "TTS synthesis failed.",
                status_code=502,
            ) from None
