from app.adapters.fakes import FakeSTTProvider
from tests.conftest import auth_headers, make_client, make_providers


def test_stt_multipart_happy_path_default_and_custom_language() -> None:
    client = make_client()

    resp = client.post(
        "/v1/stt",
        headers=auth_headers(),
        files={"audio": ("sample.wav", b"RIFF0000WAVEfmt ", "audio/wav")},
    )
    assert resp.status_code == 200
    body = resp.json()
    assert isinstance(body["text"], str) and len(body["text"]) > 0
    assert body["language"] == "es"
    assert isinstance(body["duration_s"], int | float)

    resp_en = client.post(
        "/v1/stt",
        headers=auth_headers(),
        files={"audio": ("voice.webm", b"\x1a\x45\xdf\xa3", "audio/webm")},
        data={"language": "en"},
    )
    assert resp_en.status_code == 200
    assert resp_en.json()["language"] == "en"


def test_stt_missing_file_returns_422_invalid_request() -> None:
    client = make_client()
    resp = client.post("/v1/stt", headers=auth_headers(), data={"language": "es"})
    assert resp.status_code == 422
    assert resp.json()["error"]["code"] == "invalid_request"


def test_stt_unsupported_format_returns_invalid_request() -> None:
    client = make_client()
    resp = client.post(
        "/v1/stt",
        headers=auth_headers(),
        files={"audio": ("notes.txt", b"hello world", "text/plain")},
    )
    assert resp.status_code in (400, 422)
    assert resp.json()["error"]["code"] == "invalid_request"


def test_stt_empty_file_returns_invalid_request() -> None:
    client = make_client()
    resp = client.post(
        "/v1/stt",
        headers=auth_headers(),
        files={"audio": ("empty.wav", b"", "audio/wav")},
    )
    assert resp.status_code in (400, 422)
    assert resp.json()["error"]["code"] == "invalid_request"


def test_stt_accepts_all_documented_formats() -> None:
    client = make_client()
    for fname, mime in [
        ("a.wav", "audio/wav"),
        ("a.webm", "audio/webm"),
        ("a.ogg", "audio/ogg"),
        ("a.m4a", "audio/mp4"),
        ("a.mp3", "audio/mpeg"),
    ]:
        resp = client.post(
            "/v1/stt",
            headers=auth_headers(),
            files={"audio": (fname, b"data", mime)},
        )
        assert resp.status_code == 200


def test_stt_over_10mb_returns_413_payload_too_large() -> None:
    client = make_client()
    oversized = b"0" * (10 * 1024 * 1024 + 1)
    resp = client.post(
        "/v1/stt",
        headers=auth_headers(),
        files={"audio": ("big.wav", oversized, "audio/wav")},
    )
    assert resp.status_code == 413
    assert resp.json()["error"]["code"] == "payload_too_large"


def test_stt_upstream_failure_returns_502_or_503() -> None:
    client = make_client(providers=make_providers(stt=FakeSTTProvider(fail=True)))
    resp = client.post(
        "/v1/stt",
        headers=auth_headers(),
        files={"audio": ("sample.wav", b"RIFF0000WAVE", "audio/wav")},
    )
    assert resp.status_code in (502, 503)
    assert resp.json()["error"]["code"] == "upstream_unavailable"
