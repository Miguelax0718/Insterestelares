import json
import re
from typing import Any, Literal

from pydantic import BaseModel, Field, field_validator

MAX_CHAT_MESSAGES = 40
MAX_MESSAGE_CHARS = 4000
MAX_CONTEXT_BYTES = 16 * 1024
MAX_TTS_CHARS = 1000
VOICE_NAME_RE = re.compile(r"^[A-Za-z0-9_.-]+$")


class ProvidersStatus(BaseModel):
    llm: str
    stt: str
    tts: str


class HealthResponse(BaseModel):
    status: Literal["ok"] = "ok"
    version: str
    providers: ProvidersStatus


class ChatMessageIn(BaseModel):
    role: Literal["user", "assistant"]
    content: str = Field(min_length=1, max_length=MAX_MESSAGE_CHARS)


class ChatRequest(BaseModel):
    messages: list[ChatMessageIn] = Field(min_length=1, max_length=MAX_CHAT_MESSAGES)
    context: dict[str, Any] | None = None
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


class ChatResponse(BaseModel):
    reply: str
    model: str


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
