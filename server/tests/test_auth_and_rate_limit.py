import logging

from tests.conftest import auth_headers, make_client, make_settings


def test_missing_api_key_returns_401_envelope() -> None:
    client = make_client()
    resp = client.post("/v1/chat", json={"messages": [{"role": "user", "content": "hola"}]})
    assert resp.status_code == 401
    assert resp.json()["error"]["code"] == "unauthorized"
    assert isinstance(resp.json()["error"]["message"], str)


def test_wrong_api_key_returns_401_envelope() -> None:
    client = make_client()
    resp = client.post(
        "/v1/tts",
        json={"text": "Hola"},
        headers=auth_headers("wrong-key"),
    )
    assert resp.status_code == 401
    assert resp.json()["error"]["code"] == "unauthorized"


def test_empty_api_keys_fails_closed_when_auth_enabled() -> None:
    client = make_client(settings=make_settings(app_api_keys="", auth_disabled=False))
    resp = client.post(
        "/v1/tts",
        json={"text": "Hola"},
        headers=auth_headers("anything"),
    )
    assert resp.status_code == 401
    assert resp.json()["error"]["code"] == "unauthorized"


def test_multiple_comma_separated_keys_accepted() -> None:
    client = make_client(settings=make_settings(app_api_keys="key-one, key-two"))
    resp = client.post(
        "/v1/tts",
        json={"text": "Hola"},
        headers=auth_headers("key-two"),
    )
    assert resp.status_code == 200


def test_auth_disabled_bypasses_key_and_logs_warning(caplog) -> None:
    with caplog.at_level(logging.WARNING):
        client = make_client(settings=make_settings(auth_disabled=True, app_api_keys=""))
    assert any("AUTH_DISABLED" in rec.message for rec in caplog.records)
    resp = client.post("/v1/tts", json={"text": "Hola"})
    assert resp.status_code == 200


def test_rate_limit_returns_429_envelope_and_health_is_exempt() -> None:
    client = make_client(settings=make_settings(rate_limit_per_min=2))
    for _ in range(2):
        ok = client.post("/v1/tts", json={"text": "Hola"}, headers=auth_headers())
        assert ok.status_code == 200

    limited = client.post("/v1/tts", json={"text": "Hola"}, headers=auth_headers())
    assert limited.status_code == 429
    assert limited.json()["error"]["code"] == "rate_limited"

    health = client.get("/health")
    assert health.status_code == 200
