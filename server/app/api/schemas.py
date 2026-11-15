import json
import re
from typing import Annotated, Any, Literal

from pydantic import BaseModel, Field, field_validator, model_validator

MAX_CHAT_MESSAGES = 40
MAX_MESSAGE_CHARS = 4000
MAX_CONTEXT_BYTES = 16 * 1024
MAX_TOOLS = 32
MAX_TOOLS_BYTES = 24 * 1024
MAX_TOOL_DESCRIPTION_CHARS = 1024
MAX_SKILL_INSTRUCTIONS = 8
MAX_SKILL_INSTRUCTION_CHARS = 2000
MAX_TTS_CHARS = 1000
TOOL_NAME_RE = re.compile(r"^[a-zA-Z0-9_]{1,64}$")
VOICE_NAME_RE = re.compile(r"^[A-Za-z0-9_.-]+$")


class ProvidersStatus(BaseModel):
    llm: str
    stt: str
    tts: str


class HealthResponse(BaseModel):
    status: Literal["ok"] = "ok"
    version: str
    providers: ProvidersStatus


class ToolCallIn(BaseModel):
    id: str = Field(min_length=1, max_length=256)
    name: str = Field(min_length=1, max_length=64)
    arguments: dict[str, Any]


class ToolCallOut(BaseModel):
    id: str
    name: str
    arguments: dict[str, Any]
    invalid_arguments: bool | None = None


class ToolSpecIn(BaseModel):
    name: str = Field(min_length=1, max_length=64)
    description: str = Field(max_length=MAX_TOOL_DESCRIPTION_CHARS)
    parameters: dict[str, Any]

    @field_validator("name")
    @classmethod
    def validate_tool_name(cls, value: str) -> str:
        if not TOOL_NAME_RE.fullmatch(value):
            raise ValueError("tool name must match ^[a-zA-Z0-9_]{1,64}$")
        return value


class ChatMessageIn(BaseModel):
    role: Literal["user", "assistant", "tool"]
    content: str | None = Field(default=None, max_length=MAX_MESSAGE_CHARS)
    tool_calls: list[ToolCallIn] | None = None
    tool_call_id: str | None = Field(default=None, min_length=1, max_length=256)

    @model_validator(mode="after")
    def validate_role_fields(self) -> "ChatMessageIn":
        if self.role == "user":
            if self.content is None or len(self.content) < 1:
                raise ValueError("user message content must be a non-empty string")
            if self.tool_calls:
                raise ValueError("user message cannot include tool_calls")
            if self.tool_call_id is not None:
                raise ValueError("user message cannot include tool_call_id")
        elif self.role == "assistant":
            if self.tool_call_id is not None:
                raise ValueError("assistant message cannot include tool_call_id")
            if not self.tool_calls and (self.content is None or len(self.content) < 1):
                raise ValueError(
                    "assistant message content must be non-empty when tool_calls is empty"
                )
        elif self.role == "tool":
            if self.tool_call_id is None:
                raise ValueError("tool message requires tool_call_id")
            if self.content is None or len(self.content) < 1:
                raise ValueError("tool message content must be a non-empty string")
            if self.tool_calls:
                raise ValueError("tool message cannot include tool_calls")
        return self


class ChatRequest(BaseModel):
    messages: list[ChatMessageIn] = Field(min_length=1, max_length=MAX_CHAT_MESSAGES)
    context: dict[str, Any] | None = None
    tools: list[ToolSpecIn] | None = Field(default=None, max_length=MAX_TOOLS)
    skill_instructions: (
        list[Annotated[str, Field(max_length=MAX_SKILL_INSTRUCTION_CHARS)]] | None
    ) = Field(default=None, max_length=MAX_SKILL_INSTRUCTIONS)
    stream: bool = False

    @field_validator("context")
    @classmethod
    def validate_context_size(cls, value: dict[str, Any] | None) -> dict[str, Any] | None:
        if value is None:
            return None
        encoded = json.dumps(value, ensure_ascii=False, separators=(",", ":")).encode("utf-8")
        if len(encoded) > MAX_CONTEXT_BYTES:
            raise ValueError(f"context JSON must not exceed {MAX_CONTEXT_BYTES} bytes (16 KB)")
        return value

    @field_validator("tools")
    @classmethod
    def validate_tools_size(cls, value: list[ToolSpecIn] | None) -> list[ToolSpecIn] | None:
        if value is None:
            return None
        encoded = json.dumps(
            [tool.model_dump() for tool in value],
            ensure_ascii=False,
            separators=(",", ":"),
        ).encode("utf-8")
        if len(encoded) > MAX_TOOLS_BYTES:
            raise ValueError(f"tools JSON must not exceed {MAX_TOOLS_BYTES} bytes (24 KB)")
        return value

    @model_validator(mode="after")
    def validate_tool_call_references(self) -> "ChatRequest":
        seen_tool_call_ids: set[str] = set()
        for msg in self.messages:
            if msg.role == "assistant" and msg.tool_calls:
                seen_tool_call_ids.update(tc.id for tc in msg.tool_calls)
            elif msg.role == "tool":
                assert msg.tool_call_id is not None
                if msg.tool_call_id not in seen_tool_call_ids:
                    raise ValueError(
                        f"tool_call_id {msg.tool_call_id!r} does not match an earlier "
                        "assistant tool call"
                    )
        return self


class ChatResponse(BaseModel):
    reply: str
    model: str
    tool_calls: list[ToolCallOut] = Field(default_factory=list)


class STTResponse(BaseModel):
    text: str
    language: str
    duration_s: float


class TTSRequest(BaseModel):
    text: str = Field(min_length=1, max_length=MAX_TTS_CHARS)
    voice: str | None = Field(default=None, max_length=128)

    @field_validator("text")
    @classmethod
    def validate_non_blank_text(cls, value: str) -> str:
        if not value.strip():
            raise ValueError("text must contain non-whitespace characters")
        return value

    @field_validator("voice")
    @classmethod
    def validate_voice(cls, value: str | None) -> str | None:
        if value is None:
            return None
        cleaned = value.strip()
        if not cleaned:
            return None
        if ".." in cleaned or not VOICE_NAME_RE.fullmatch(cleaned):
            raise ValueError("voice contains invalid characters")
        return cleaned
