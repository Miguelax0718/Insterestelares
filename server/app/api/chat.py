import json
import logging
from collections.abc import AsyncIterator
from typing import Any

from fastapi import APIRouter, Depends, Request
from fastapi.responses import StreamingResponse

from app.api.schemas import ChatRequest, ChatResponse, ToolCallOut
from app.core.errors import UpstreamUnavailableError
from app.core.rate_limit import enforce_rate_limit
from app.domain.models import ChatTurn, ToolCall, ToolSpec
from app.domain.ports import ProviderRegistry
from app.domain.prompts import build_system_prompt

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/v1", tags=["chat"])


def _build_turns(payload: ChatRequest) -> list[ChatTurn]:
    # One system message only: some OpenAI-compatible providers keep just one.
    system = build_system_prompt(
        has_tools=bool(payload.tools),
        skill_instructions=payload.skill_instructions,
        context=payload.context,
    )
    turns: list[ChatTurn] = [ChatTurn(role="system", content=system)]
    for msg in payload.messages:
        tool_calls = [
            ToolCall(
                id=tc.id,
                name=tc.name,
                arguments=tc.arguments,
                extra_content=tc.extra_content,
            )
            for tc in (msg.tool_calls or ())
        ]
        turns.append(
            ChatTurn(
                role=msg.role,
                content=msg.content,
                tool_calls=tool_calls,
                tool_call_id=msg.tool_call_id,
            )
        )
    return turns


def _build_tools(payload: ChatRequest) -> list[ToolSpec] | None:
    if not payload.tools:
        return None
    return [
        ToolSpec(name=t.name, description=t.description, parameters=t.parameters)
        for t in payload.tools
    ]


def _serialize_tool_call(tc: ToolCall) -> dict[str, Any]:
    data: dict[str, Any] = {
        "id": tc.id,
        "name": tc.name,
        "arguments": tc.arguments,
    }
    if tc.invalid_arguments:
        data["invalid_arguments"] = True
    if tc.extra_content is not None:
        data["extra_content"] = tc.extra_content
    return data


@router.post(
    "/chat",
    response_model=ChatResponse,
    response_model_exclude_none=True,
    dependencies=[Depends(enforce_rate_limit)],
)
async def post_chat(request: Request, payload: ChatRequest) -> ChatResponse | StreamingResponse:
    providers: ProviderRegistry = request.app.state.providers
    turns = _build_turns(payload)
    tools = _build_tools(payload)

    if not payload.stream:
        result = await providers.llm.complete(turns, tools=tools)
        return ChatResponse(
            reply=result.reply,
            model=result.model,
            tool_calls=[
                ToolCallOut(
                    id=tc.id,
                    name=tc.name,
                    arguments=tc.arguments,
                    invalid_arguments=True if tc.invalid_arguments else None,
                    extra_content=tc.extra_content,
                )
                for tc in result.tool_calls
            ],
        )

    async def sse_stream() -> AsyncIterator[str]:
        sent_done = False
        last_model = ""
        try:
            async for chunk in providers.llm.stream(turns, tools=tools):
                if chunk.model:
                    last_model = chunk.model
                if chunk.delta:
                    data = json.dumps({"delta": chunk.delta}, ensure_ascii=False)
                    yield f"data: {data}\n\n"
                if chunk.tool_call is not None:
                    data = json.dumps(
                        {"tool_call": _serialize_tool_call(chunk.tool_call)},
                        ensure_ascii=False,
                    )
                    yield f"data: {data}\n\n"
                if chunk.done:
                    done_data = json.dumps({"done": True, "model": last_model}, ensure_ascii=False)
                    yield f"data: {done_data}\n\n"
                    sent_done = True
            if not sent_done:
                done_data = json.dumps({"done": True, "model": last_model}, ensure_ascii=False)
                yield f"data: {done_data}\n\n"
        except UpstreamUnavailableError as exc:
            err = json.dumps(
                {"error": {"code": exc.code, "message": exc.message}},
                ensure_ascii=False,
            )
            yield f"data: {err}\n\n"
        except Exception:
            logger.exception("Unexpected error during /v1/chat SSE stream")
            err = json.dumps(
                {"error": {"code": "internal", "message": "Internal server error."}},
                ensure_ascii=False,
            )
            yield f"data: {err}\n\n"

    return StreamingResponse(
        sse_stream(),
        media_type="text/event-stream",
        headers={
            "Cache-Control": "no-cache",
            "X-Accel-Buffering": "no",
        },
    )
