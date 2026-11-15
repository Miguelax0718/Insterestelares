from app.adapters.fakes import FakeTTSProvider
from tests.conftest import auth_headers, make_client, make_providers


def test_tts_returns_audio_wav() -> None:
    fake_tts = FakeTTSProvider()
    client = make_client(providers=make_providers(tts=fake_tts))

    resp = client.post(
        "/v1/tts",
        headers=auth_headers(),
        json={"text": "Mantenga calma y respire profundo.", "voice": "es_MX-claude-high"},
    )
    assert resp.status_code == 200
    assert resp.headers["content-type"].startswith("audio/wav")
    assert resp.content.startswith(b"RIFF")
    assert b"WAVE" in resp.content[:16]
    assert fake_tts.last_voice == "es_MX-claude-high"


def test_tts_rejects_empty_and_over_1000_chars() -> None:
    client = make_client()

    r_empty = client.post("/v1/tts", headers=auth_headers(), json={"text": ""})
    assert r_empty.status_code == 422
    assert r_empty.json()["error"]["code"] == "invalid_request"

    r_blank = client.post("/v1/tts", headers=auth_headers(), json={"text": "   "})
    assert r_blank.status_code == 422
    assert r_blank.json()["error"]["code"] == "invalid_request"

    r_over = client.post("/v1/tts", headers=auth_headers(), json={"text": "a" * 1001})
    assert r_over.status_code == 422
    assert r_over.json()["error"]["code"] == "invalid_request"

    r_exact = client.post("/v1/tts", headers=auth_headers(), json={"text": "a" * 1000})
    assert r_exact.status_code == 200


def test_tts_rejects_unsafe_voice_name() -> None:
    client = make_client()
    resp = client.post(
        "/v1/tts",
        headers=auth_headers(),
        json={"text": "Hola", "voice": "../../etc/passwd"},
    )
    assert resp.status_code == 422
    assert resp.json()["error"]["code"] == "invalid_request"


def test_tts_upstream_failure_returns_502_or_503() -> None:
    client = make_client(providers=make_providers(tts=FakeTTSProvider(fail=True)))
    resp = client.post(
        "/v1/tts",
        headers=auth_headers(),
        json={"text": "Hola"},
    )
    assert resp.status_code in (502, 503)
    assert resp.json()["error"]["code"] == "upstream_unavailable"
