from fastapi import APIRouter, Request

from app.api.schemas import HealthResponse, ProvidersStatus
from app.core.config import Settings
from app.domain.ports import ProviderRegistry

router = APIRouter(tags=["health"])


@router.get("/health", response_model=HealthResponse)
async def get_health(request: Request) -> HealthResponse:
    settings: Settings = request.app.state.settings
    providers: ProviderRegistry = request.app.state.providers
    return HealthResponse(
        status="ok",
        version=settings.app_version,
        providers=ProvidersStatus(
            llm=providers.llm.name,
            stt=providers.stt.name,
            tts=providers.tts.name,
        ),
    )
