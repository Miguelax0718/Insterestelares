import logging
from collections.abc import AsyncIterator
from typing import Any

from openai import APIConnectionError, APIError, APITimeoutError, AsyncOpenAI, OpenAIError

from app.core.errors import UpstreamUnavailableError
from app.domain.models import ChatResult, ChatTurn, LLMStreamChunk

logger = logging.getLogger(__name__)


class AgentRouterLLMProvider:
    def __init__(
        self,
        *,
        base_url: str,
        api_key: str,
        model: str,
        timeout_s: float = 30.0,
        client: AsyncOpenAI | None = None,
        http_client: Any = None,
    ) -> None:
        self._base_url = base_url
        self._api_key = api_key
        self._model = model
        self._timeout_s = timeout_s
        self._client = client
        self._http_client = http_client

    @property
    def name(self) -> str:
        return "agentrouter"

    def _get_client(self) -> AsyncOpenAI:
        if self._client is not None:
            return self._client
        if not self._api_key:
            raise UpstreamUnavailableError(
                "LLM provider is not configured.",
                status_code=503,
            )
        kwargs: dict[str, Any] = {
            "api_key": self._api_key,
            "base_url": self._base_url,
            "timeout": self._timeout_s,
            "max_retries": 0,
        }
        if self._http_client is not None:
            kwargs["http_client"] = self._http_client
        self._client = AsyncOpenAI(**kwargs)
        return self._client

    @staticmethod
    def _to_openai_messages(messages: list[ChatTurn]) -> list[dict[str, Any]]:
        return [{"role": m.role, "content": m.content} for m in messages]

    async def complete(self, messages: list[ChatTurn]) -> ChatResult:
        client = self._get_client()
        try:
            response = await client.chat.completions.create(
                model=self._model,
                messages=self._to_openai_messages(messages),  # type: ignore[arg-type]
                stream=False,
            )
        except (APITimeoutError, APIConnectionError) as exc:
            logger.warning("AgentRouter connection/timeout error: %s", type(exc).__name__)
            raise UpstreamUnavailableError(
                "LLM upstream provider timed out or is unreachable.",
                status_code=503,
            ) from None
        except (APIError, OpenAIError) as exc:
            status = getattr(exc, "status_code", None)
            logger.warning(
                "AgentRouter API error: type=%s status=%s",
                type(exc).__name__,
                status,
            )
            raise UpstreamUnavailableError(
                "LLM upstream provider returned an error.",
                status_code=502,
            ) from None

        if not response.choices:
            raise UpstreamUnavailableError("LLM upstream returned empty choices.", status_code=502)
        reply = response.choices[0].message.content or ""
        resolved_model = response.model or self._model
        return ChatResult(reply=reply, model=resolved_model)

    async def stream(self, messages: list[ChatTurn]) -> AsyncIterator[LLMStreamChunk]:
        client = self._get_client()
        resolved_model = self._model
        try:
            stream = await client.chat.completions.create(
                model=self._model,
                messages=self._to_openai_messages(messages),  # type: ignore[arg-type]
                stream=True,
            )
            async for chunk in stream:
                if getattr(chunk, "model", None):
                    resolved_model = chunk.model
                choices = getattr(chunk, "choices", None) or []
                if not choices:
                    continue
                delta_obj = choices[0].delta
                content = getattr(delta_obj, "content", None)
                if content:
                    yield LLMStreamChunk(delta=content, done=False, model=resolved_model)
        except (APITimeoutError, APIConnectionError) as exc:
            logger.warning("AgentRouter stream connection/timeout error: %s", type(exc).__name__)
            raise UpstreamUnavailableError(
                "LLM upstream provider timed out or is unreachable.",
                status_code=503,
            ) from None
        except (APIError, OpenAIError) as exc:
            status = getattr(exc, "status_code", None)
            logger.warning(
                "AgentRouter stream API error: type=%s status=%s",
                type(exc).__name__,
                status,
            )
            raise UpstreamUnavailableError(
                "LLM upstream provider returned an error.",
                status_code=502,
            ) from None

        yield LLMStreamChunk(delta=None, done=True, model=resolved_model)
