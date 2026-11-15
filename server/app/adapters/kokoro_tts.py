import array
import asyncio
import io
import logging
import re
import sys
import wave
from pathlib import Path
from typing import Any

from app.core.errors import InvalidRequestError, UpstreamUnavailableError

logger = logging.getLogger(__name__)

VOICE_NAME_RE = re.compile(r"^[A-Za-z0-9_.-]+$")


def _float_samples_to_wav(samples: Any, sample_rate: int) -> bytes:
    if hasattr(samples, "dtype") and hasattr(samples, "astype"):
        import numpy as np

        arr = np.asarray(samples, dtype=np.float32).ravel()
        if arr.size == 0:
            raise ValueError("Synthesized audio is empty")
        pcm_bytes = (np.clip(arr, -1.0, 1.0) * 32767.0).astype("<i2").tobytes()
    else:
        pcm = array.array("h")
        for sample in samples:
            clamped = max(-1.0, min(1.0, float(sample)))
            pcm.append(int(clamped * 32767.0))
        if not pcm:
            raise ValueError("Synthesized audio is empty")
        if sys.byteorder != "little":
            pcm.byteswap()
        pcm_bytes = pcm.tobytes()

    buf = io.BytesIO()
    with wave.open(buf, "wb") as wav_file:
        wav_file.setnchannels(1)
        wav_file.setsampwidth(2)
        wav_file.setframerate(int(sample_rate))
        wav_file.writeframes(pcm_bytes)
    return buf.getvalue()


class KokoroTTSProvider:
    def __init__(
        self,
        *,
        model_path: str = "/app/models/kokoro/kokoro-v1.0.onnx",
        voices_path: str = "/app/models/kokoro/voices-v1.0.bin",
        default_voice: str = "af_heart",
        speed: float = 1.0,
        default_lang: str = "en-us",
    ) -> None:
        self._model_path = Path(model_path)
        self._voices_path = Path(voices_path)
        self._default_voice = default_voice
        self._speed = speed
        self._default_lang = default_lang
        self._engine: Any = None
        self._lock = asyncio.Lock()

    @property
    def name(self) -> str:
        return "kokoro"

    def _resolve_lang(self, voice_name: str) -> str:
        if voice_name.startswith(("bf_", "bm_")):
            return "en-gb"
        if voice_name.startswith(("af_", "am_")):
            return "en-us"
        return self._default_lang

    async def _get_engine(self) -> Any:
        if self._engine is not None:
            return self._engine
        async with self._lock:
            if self._engine is not None:
                return self._engine
            try:
                loaded = await asyncio.to_thread(self._load_engine_sync)
            except Exception as exc:
                logger.warning("Failed to load Kokoro TTS model: %s", type(exc).__name__)
                raise UpstreamUnavailableError(
                    "TTS model is unavailable.",
                    status_code=503,
                ) from None
            self._engine = loaded
            return loaded

    def _load_engine_sync(self) -> Any:
        from kokoro_onnx import Kokoro

        if not self._model_path.is_file():
            raise FileNotFoundError("Kokoro model file not found")
        if not self._voices_path.is_file():
            raise FileNotFoundError("Kokoro voices file not found")
        return Kokoro(str(self._model_path), str(self._voices_path))

    @staticmethod
    def _synthesize_sync(
        engine: Any,
        text: str,
        voice_name: str,
        speed: float,
        lang: str,
    ) -> bytes:
        samples, sample_rate = engine.create(
            text,
            voice=voice_name,
            speed=speed,
            lang=lang,
        )
        return _float_samples_to_wav(samples, int(sample_rate))

    async def synthesize(self, text: str, *, voice: str | None = None) -> bytes:
        selected_voice = voice or self._default_voice
        if not VOICE_NAME_RE.fullmatch(selected_voice) or ".." in selected_voice:
            raise InvalidRequestError("Invalid voice identifier.")

        engine = await self._get_engine()

        if hasattr(engine, "get_voices"):
            available = set(engine.get_voices())
            if available and selected_voice not in available:
                raise InvalidRequestError("Unknown TTS voice.")

        lang = self._resolve_lang(selected_voice)
        try:
            return await asyncio.to_thread(
                self._synthesize_sync,
                engine,
                text,
                selected_voice,
                self._speed,
                lang,
            )
        except Exception as exc:
            logger.warning("Kokoro TTS synthesis failed: %s", type(exc).__name__)
            raise UpstreamUnavailableError(
                "TTS synthesis failed.",
                status_code=502,
            ) from None
