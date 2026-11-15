import json
import logging
from collections.abc import AsyncIterator

from fastapi import APIRouter, Depends, Request
from fastapi.responses import StreamingResponse

from app.api.schemas import ChatRequest, ChatResponse
from app.core.errors import UpstreamUnavailableError
from app.core.rate_limit import enforce_rate_limit
from app.domain.models import ChatTurn
from app.domain.ports import ProviderRegistry
from app.domain.prompts import CLINICAL_SYSTEM_PROMPT, format_context_system_message

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/v1", tags=["chat"])


def _build_turns(payload: ChatRequest) -> list[ChatTurn]:
    # One system message only: some OpenAI-compatible providers keep just one.
    system = CLINICAL_SYSTEM_PROMPT
    if payload.context is not None:
        system = f"{system}\n\n{format_context_system_message(payload.context)}"
    turns: list[ChatTurn] = [ChatTurn(role="system", content=system)]
    for msg in payload.messages:
        turns.append(ChatTurn(role=msg.role, content=msg.content))
    return turns


@router.post(
    "/chat",
    response_model=ChatResponse,
    dependencies=[Depends(enforce_rate_limit)],
)
async def post_chat(request: Request, payload: ChatRequest) -> ChatResponse | StreamingResponse:
    providers: ProviderRegistry = request.app.state.providers
    turns = _build_turns(payload)

    if not payload.stream:
        result = await providers.llm.complete(turns)
        return ChatResponse(reply=result.reply, model=result.model)

    async def sse_stream() -> AsyncIterator[str]:
        sent_done = False
        last_model = ""
        try:
            async for chunk in providers.llm.stream(turns):
                if chunk.model:
                    last_model = chunk.model
                if chunk.delta:
                    data = json.dumps({"delta": chunk.delta}, ensure_ascii=False)
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
