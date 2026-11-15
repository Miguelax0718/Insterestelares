import logging

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.adapters.agentrouter_llm import AgentRouterLLMProvider
from app.adapters.fakes import FakeLLMProvider, FakeSTTProvider, FakeTTSProvider
from app.adapters.faster_whisper_stt import FasterWhisperSTTProvider
from app.adapters.kokoro_tts import KokoroTTSProvider
from app.adapters.piper_tts import PiperTTSProvider
from app.api import chat, health, stt, tts
from app.core.config import Settings
from app.core.errors import register_exception_handlers
from app.core.rate_limit import InMemoryRateLimiter
from app.domain.ports import LLMProvider, ProviderRegistry, STTProvider, TTSProvider

logger = logging.getLogger(__name__)


def build_providers(settings: Settings) -> ProviderRegistry:
    llm_name = settings.llm_provider.strip().lower()
    if llm_name == "fake":
        llm: LLMProvider = FakeLLMProvider()
    elif llm_name == "agentrouter":
        llm = AgentRouterLLMProvider(
            base_url=settings.agentrouter_base_url,
            api_key=settings.agentrouter_api_key,
            model=settings.agentrouter_model,
            timeout_s=settings.llm_timeout_s,
        )
    else:
        raise ValueError(f"Unsupported LLM_PROVIDER: {settings.llm_provider!r}")

    stt_name = settings.stt_provider.strip().lower()
    if stt_name == "fake":
        stt_provider: STTProvider = FakeSTTProvider()
    elif stt_name == "faster-whisper":
        stt_provider = FasterWhisperSTTProvider(
            model_size=settings.whisper_model,
            compute_type=settings.whisper_compute_type,
            device=settings.whisper_device,
            download_root=settings.whisper_download_root,
        )
    else:
        raise ValueError(f"Unsupported STT_PROVIDER: {settings.stt_provider!r}")

    tts_name = settings.tts_provider.strip().lower()
    if tts_name == "fake":
        tts_provider: TTSProvider = FakeTTSProvider()
    elif tts_name == "piper":
        tts_provider = PiperTTSProvider(
            default_voice=settings.piper_voice,
            voices_dir=settings.piper_voices_dir,
        )
    elif tts_name == "kokoro":
        tts_provider = KokoroTTSProvider(
            model_path=settings.kokoro_model_path,
            voices_path=settings.kokoro_voices_path,
            default_voice=settings.kokoro_voice,
            speed=settings.kokoro_speed,
            default_lang=settings.kokoro_lang,
        )
    else:
        raise ValueError(f"Unsupported TTS_PROVIDER: {settings.tts_provider!r}")

    return ProviderRegistry(llm=llm, stt=stt_provider, tts=tts_provider)


def create_app(
    settings: Settings | None = None,
    providers: ProviderRegistry | None = None,
) -> FastAPI:
    resolved_settings = settings or Settings()
    resolved_providers = providers or build_providers(resolved_settings)

    if resolved_settings.auth_disabled:
        logger.warning(
            "AUTH_DISABLED=true: API key authentication is bypassed (development only)."
        )

    app = FastAPI(
        title="AstraMed Clinical Voice Gateway",
        version=resolved_settings.app_version,
        docs_url="/docs",
        redoc_url=None,
    )
    app.state.settings = resolved_settings
    app.state.providers = resolved_providers
    app.state.rate_limiter = InMemoryRateLimiter(resolved_settings.rate_limit_per_min)

    origins = resolved_settings.parsed_allowed_origins()
    app.add_middleware(
        CORSMiddleware,
        allow_origins=origins,
        allow_credentials=False,
        allow_methods=["*"],
        allow_headers=["*"],
    )

    register_exception_handlers(app)

    app.include_router(health.router)
    app.include_router(chat.router)
    app.include_router(stt.router)
    app.include_router(tts.router)

    return app


app = create_app()
