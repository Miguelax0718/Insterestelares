import io
import wave
from collections.abc import AsyncIterator

from app.core.errors import UpstreamUnavailableError
from app.domain.models import ChatResult, ChatTurn, LLMStreamChunk, TranscriptionResult


def _build_silent_wav(duration_s: float = 0.1, sample_rate: int = 16000) -> bytes:
    buf = io.BytesIO()
    n_frames = max(1, int(duration_s * sample_rate))
    with wave.open(buf, "wb") as wf:
        wf.setnchannels(1)
        wf.setsampwidth(2)
        wf.setframerate(sample_rate)
        wf.writeframes(b"\x00\x00" * n_frames)
    return buf.getvalue()


class FakeLLMProvider:
    def __init__(
        self,
        *,
        reply: str = "Signos vitales estables. Mantenga hidratación y monitoreo.",
        model: str = "fake-clinical-model",
        deltas: list[str] | None = None,
        fail_complete: bool = False,
        fail_mid_stream: bool = False,
    ) -> None:
        self._reply = reply
        self._model = model
        self._deltas = deltas or ["Signos ", "vitales ", "estables."]
        self._fail_complete = fail_complete
        self._fail_mid_stream = fail_mid_stream
        self.recorded_messages: list[list[ChatTurn]] = []

    @property
    def name(self) -> str:
        return "fake"

    async def complete(self, messages: list[ChatTurn]) -> ChatResult:
        self.recorded_messages.append(messages)
        if self._fail_complete:
            raise UpstreamUnavailableError("Fake upstream LLM failure.")
        return ChatResult(reply=self._reply, model=self._model)

    async def stream(self, messages: list[ChatTurn]) -> AsyncIterator[LLMStreamChunk]:
        self.recorded_messages.append(messages)
        if self._fail_complete:
            raise UpstreamUnavailableError("Fake upstream LLM failure.")
        for idx, part in enumerate(self._deltas):
            if self._fail_mid_stream and idx >= 1:
                raise UpstreamUnavailableError("Fake upstream stream interrupted.")
            yield LLMStreamChunk(delta=part, done=False, model=self._model)
        yield LLMStreamChunk(delta=None, done=True, model=self._model)


class FakeSTTProvider:
    def __init__(
        self,
        *,
        text: str = "Frecuencia cardíaca de setenta y dos latidos por minuto.",
        duration_s: float = 1.5,
        fail: bool = False,
    ) -> None:
        self._text = text
        self._duration_s = duration_s
        self._fail = fail

    @property
    def name(self) -> str:
        return "fake"

    async def transcribe(
        self,
        audio: bytes,
        *,
        filename: str,
        content_type: str | None,
        language: str,
    ) -> TranscriptionResult:
        if self._fail:
            raise UpstreamUnavailableError("Fake STT failure.")
        return TranscriptionResult(
            text=self._text,
            language=language,
            duration_s=self._duration_s,
        )


class FakeTTSProvider:
    def __init__(self, *, fail: bool = False) -> None:
        self._fail = fail
        self.last_voice: str | None = None

    @property
    def name(self) -> str:
        return "fake"

    async def synthesize(self, text: str, *, voice: str | None = None) -> bytes:
        self.last_voice = voice
        if self._fail:
            raise UpstreamUnavailableError("Fake TTS failure.")
        return _build_silent_wav()
