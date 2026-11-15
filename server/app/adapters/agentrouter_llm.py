import json
import logging
from collections.abc import AsyncIterator
from typing import Any

from openai import APIConnectionError, APIError, APITimeoutError, AsyncOpenAI, OpenAIError

from app.core.errors import UpstreamUnavailableError
from app.domain.models import ChatResult, ChatTurn, LLMStreamChunk, ToolCall, ToolSpec

logger = logging.getLogger(__name__)


def _parse_tool_arguments(raw: Any) -> tuple[dict[str, Any], bool]:
    if isinstance(raw, dict):
        return raw, False
    if not isinstance(raw, str):
        return {}, True
    try:
        parsed = json.loads(raw)
    except json.JSONDecodeError:
        return {}, True
    if not isinstance(parsed, dict):
        return {}, True
    return parsed, False


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
        mapped: list[dict[str, Any]] = []
        for m in messages:
            if m.role == "assistant":
                entry: dict[str, Any] = {"role": "assistant", "content": m.content}
                if m.tool_calls:
                    entry["tool_calls"] = [
                        {
                            "id": tc.id,
                            "type": "function",
                            "function": {
                                "name": tc.name,
                                "arguments": json.dumps(
                                    tc.arguments,
                                    ensure_ascii=False,
                                    separators=(",", ":"),
                                ),
                            },
                        }
                        for tc in m.tool_calls
                    ]
                mapped.append(entry)
            elif m.role == "tool":
                mapped.append(
                    {
                        "role": "tool",
                        "tool_call_id": m.tool_call_id,
                        "content": m.content or "",
                    }
                )
            else:
                mapped.append({"role": m.role, "content": m.content or ""})
        return mapped

    @staticmethod
    def _to_openai_tools(tools: list[ToolSpec]) -> list[dict[str, Any]]:
        return [
            {
                "type": "function",
                "function": {
                    "name": t.name,
                    "description": t.description,
                    "parameters": t.parameters,
                },
            }
            for t in tools
        ]

    async def complete(
        self,
        messages: list[ChatTurn],
        tools: list[ToolSpec] | None = None,
    ) -> ChatResult:
        client = self._get_client()
        kwargs: dict[str, Any] = {
            "model": self._model,
            "messages": self._to_openai_messages(messages),
            "stream": False,
        }
        if tools:
            kwargs["tools"] = self._to_openai_tools(tools)
        try:
            response = await client.chat.completions.create(**kwargs)
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
        message = response.choices[0].message
        reply = message.content or ""
        resolved_model = response.model or self._model
        parsed_tool_calls: list[ToolCall] = []
        raw_tool_calls = getattr(message, "tool_calls", None) or []
        for idx, tc in enumerate(raw_tool_calls):
            tc_id = getattr(tc, "id", None) or f"call_{idx}"
            fn = getattr(tc, "function", None)
            fn_name = getattr(fn, "name", None) or ""
            raw_args = getattr(fn, "arguments", None)
            args, invalid = _parse_tool_arguments(raw_args)
            parsed_tool_calls.append(
                ToolCall(
                    id=tc_id,
                    name=fn_name,
                    arguments=args,
                    invalid_arguments=invalid,
                )
            )
        return ChatResult(reply=reply, model=resolved_model, tool_calls=parsed_tool_calls)

    async def stream(
        self,
        messages: list[ChatTurn],
        tools: list[ToolSpec] | None = None,
    ) -> AsyncIterator[LLMStreamChunk]:
        client = self._get_client()
        resolved_model = self._model
        kwargs: dict[str, Any] = {
            "model": self._model,
            "messages": self._to_openai_messages(messages),
            "stream": True,
        }
        if tools:
            kwargs["tools"] = self._to_openai_tools(tools)

        acc: dict[int, dict[str, Any]] = {}
        try:
            stream = await client.chat.completions.create(**kwargs)
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
                delta_tcs = getattr(delta_obj, "tool_calls", None) or []
                for dtc in delta_tcs:
                    idx = getattr(dtc, "index", None)
                    if idx is None:
                        idx = 0
                    entry = acc.setdefault(idx, {"id": None, "name": "", "arguments_parts": []})
                    dtc_id = getattr(dtc, "id", None)
                    if dtc_id:
                        entry["id"] = dtc_id
                    fn = getattr(dtc, "function", None)
                    if fn is not None:
                        fn_name = getattr(fn, "name", None)
                        if fn_name:
                            entry["name"] += fn_name
                        fn_args = getattr(fn, "arguments", None)
                        if fn_args is not None:
                            entry["arguments_parts"].append(fn_args)
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

        for idx in sorted(acc.keys()):
            entry = acc[idx]
            tc_id = entry["id"] or f"call_{idx}"
            raw_args = "".join(entry["arguments_parts"])
            args, invalid = _parse_tool_arguments(raw_args)
            yield LLMStreamChunk(
                tool_call=ToolCall(
                    id=tc_id,
                    name=entry["name"],
                    arguments=args,
                    invalid_arguments=invalid,
                ),
                done=False,
                model=resolved_model,
            )

        yield LLMStreamChunk(delta=None, done=True, model=resolved_model)
