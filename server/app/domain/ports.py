from collections.abc import AsyncIterator
from dataclasses import dataclass
from typing import Protocol, runtime_checkable

from app.domain.models import ChatResult, ChatTurn, LLMStreamChunk, TranscriptionResult


@runtime_checkable
class LLMProvider(Protocol):
    @property
    def name(self) -> str: ...

    async def complete(self, messages: list[ChatTurn]) -> ChatResult: ...

    def stream(self, messages: list[ChatTurn]) -> AsyncIterator[LLMStreamChunk]: ...


@runtime_checkable
class STTProvider(Protocol):
    @property
    def name(self) -> str: ...

    async def transcribe(
        self,
        audio: bytes,
        *,
        filename: str,
        content_type: str | None,
        language: str,
    ) -> TranscriptionResult: ...


@runtime_checkable
class TTSProvider(Protocol):
    @property
    def name(self) -> str: ...

    async def synthesize(self, text: str, *, voice: str | None = None) -> bytes: ...


@dataclass(slots=True)
class ProviderRegistry:
    llm: LLMProvider
    stt: STTProvider
    tts: TTSProvider
