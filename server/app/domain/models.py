from dataclasses import dataclass, field
from typing import Any, Literal

ChatRole = Literal["system", "user", "assistant", "tool"]


@dataclass(frozen=True, slots=True)
class ToolCall:
    id: str
    name: str
    arguments: dict[str, Any]
    invalid_arguments: bool = False


@dataclass(frozen=True, slots=True)
class ToolSpec:
    name: str
    description: str
    parameters: dict[str, Any]


@dataclass(frozen=True, slots=True)
class ChatTurn:
    role: ChatRole
    content: str | None = None
    tool_calls: list[ToolCall] = field(default_factory=list)
    tool_call_id: str | None = None


@dataclass(frozen=True, slots=True)
class ChatResult:
    reply: str
    model: str
    tool_calls: list[ToolCall] = field(default_factory=list)


@dataclass(frozen=True, slots=True)
class LLMStreamChunk:
    delta: str | None = None
    done: bool = False
    model: str | None = None
    tool_call: ToolCall | None = None


@dataclass(frozen=True, slots=True)
class TranscriptionResult:
    text: str
    language: str
    duration_s: float
