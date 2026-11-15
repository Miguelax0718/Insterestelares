from fastapi.testclient import TestClient

from app.adapters.fakes import FakeLLMProvider, FakeSTTProvider, FakeTTSProvider
from app.core.config import Settings
from app.domain.ports import ProviderRegistry
from app.main import create_app

TEST_API_KEY = "test-astramed-key-123"


def make_settings(**overrides: object) -> Settings:
    defaults: dict[str, object] = {
        "app_api_keys": TEST_API_KEY,
        "auth_disabled": False,
        "allowed_origins": "https://astramed.local,http://localhost:3000",
        "rate_limit_per_min": 30,
        "llm_provider": "fake",
        "stt_provider": "fake",
        "tts_provider": "fake",
    }
    defaults.update(overrides)
    return Settings(**defaults)  # type: ignore[arg-type]


def make_providers(
    *,
    llm: FakeLLMProvider | None = None,
    stt: FakeSTTProvider | None = None,
    tts: FakeTTSProvider | None = None,
) -> ProviderRegistry:
    return ProviderRegistry(
        llm=llm or FakeLLMProvider(),
        stt=stt or FakeSTTProvider(),
        tts=tts or FakeTTSProvider(),
    )


def make_client(
    *,
    settings: Settings | None = None,
    providers: ProviderRegistry | None = None,
) -> TestClient:
    app = create_app(
        settings=settings or make_settings(),
        providers=providers or make_providers(),
    )
    return TestClient(app, raise_server_exceptions=False)


def auth_headers(key: str = TEST_API_KEY) -> dict[str, str]:
    return {"X-AstraMed-Key": key}
