from dataclasses import dataclass
from typing import Literal

ChatRole = Literal["system", "user", "assistant"]


@dataclass(frozen=True, slots=True)
class ChatTurn:
    role: ChatRole
    content: str


@dataclass(frozen=True, slots=True)
class ChatResult:
    reply: str
    model: str


@dataclass(frozen=True, slots=True)
class LLMStreamChunk:
    delta: str | None = None
    done: bool = False
    model: str | None = None


@dataclass(frozen=True, slots=True)
class TranscriptionResult:
    text: str
    language: str
    duration_s: float
