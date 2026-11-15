from fastapi import APIRouter, Depends, Request, Response

from app.api.schemas import TTSRequest
from app.core.rate_limit import enforce_rate_limit
from app.domain.ports import ProviderRegistry

router = APIRouter(prefix="/v1", tags=["tts"])


@router.post(
    "/tts",
    dependencies=[Depends(enforce_rate_limit)],
)
async def post_tts(request: Request, payload: TTSRequest) -> Response:
    providers: ProviderRegistry = request.app.state.providers
    wav_bytes = await providers.tts.synthesize(payload.text, voice=payload.voice)
    return Response(content=wav_bytes, media_type="audio/wav")
