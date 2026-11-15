from app.main import create_app
from tests.conftest import make_client, make_settings


def test_health_returns_ok_without_auth() -> None:
    client = make_client(settings=make_settings(app_version="0.1.0"))
    resp = client.get("/health")
    assert resp.status_code == 200
    assert resp.json() == {
        "status": "ok",
        "version": "0.1.0",
        "providers": {
            "llm": "fake",
            "stt": "fake",
            "tts": "fake",
        },
    }


def test_create_app_with_env_selected_fake_providers() -> None:
    from fastapi.testclient import TestClient

    app = create_app(
        settings=make_settings(llm_provider="fake", stt_provider="fake", tts_provider="fake")
    )
    client = TestClient(app)
    resp = client.get("/health")
    assert resp.status_code == 200
    assert resp.json()["providers"] == {"llm": "fake", "stt": "fake", "tts": "fake"}


def test_create_app_default_providers_are_lazy_and_fail_cleanly_without_models() -> None:
    from fastapi.testclient import TestClient

    app = create_app(
        settings=make_settings(
            llm_provider="agentrouter",
            agentrouter_api_key="",
            stt_provider="faster-whisper",
            tts_provider="piper",
        )
    )
    client = TestClient(app)
    health = client.get("/health")
    assert health.status_code == 200
    assert health.json()["providers"] == {
        "llm": "agentrouter",
        "stt": "faster-whisper",
        "tts": "piper",
    }

    from tests.conftest import auth_headers

    chat_fail = client.post(
        "/v1/chat",
        headers=auth_headers(),
        json={"messages": [{"role": "user", "content": "hola"}]},
    )
    assert chat_fail.status_code == 503
    assert chat_fail.json()["error"]["code"] == "upstream_unavailable"


def test_cors_allows_configured_origin() -> None:
    client = make_client(settings=make_settings(allowed_origins="https://astramed.local"))
    resp = client.options(
        "/v1/chat",
        headers={
            "Origin": "https://astramed.local",
            "Access-Control-Request-Method": "POST",
            "Access-Control-Request-Headers": "X-AstraMed-Key,Content-Type",
        },
    )
    assert resp.status_code in (200, 204)
    assert resp.headers.get("access-control-allow-origin") == "https://astramed.local"


def test_cors_denies_cross_origin_by_default() -> None:
    from app.core.config import Settings

    assert Settings.model_fields["allowed_origins"].default == ""
    client = make_client(settings=make_settings(allowed_origins=""))
    resp = client.options(
        "/v1/chat",
        headers={
            "Origin": "https://evil.example",
            "Access-Control-Request-Method": "POST",
        },
    )
    assert resp.headers.get("access-control-allow-origin") is None


def test_cors_wildcard_requires_explicit_opt_in() -> None:
    client = make_client(settings=make_settings(allowed_origins="*"))
    resp = client.options(
        "/v1/chat",
        headers={"Origin": "https://any.example", "Access-Control-Request-Method": "POST"},
    )
    assert resp.headers.get("access-control-allow-origin") == "*"
