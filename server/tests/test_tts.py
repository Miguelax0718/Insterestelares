import io
import sys
import types
import wave
from pathlib import Path

import pytest

from app.adapters.fakes import FakeTTSProvider
from app.core.config import Settings
from app.main import build_providers, create_app
from tests.conftest import auth_headers, make_client, make_providers, make_settings


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


def test_build_providers_selects_kokoro_lazily_and_preserves_piper_and_fake() -> None:
    kokoro_reg = build_providers(
        make_settings(
            tts_provider="kokoro",
            kokoro_model_path="/nonexistent/kokoro-v1.0.onnx",
            kokoro_voices_path="/nonexistent/voices-v1.0.bin",
            kokoro_voice="af_heart",
            kokoro_speed=1.0,
        )
    )
    assert kokoro_reg.tts.name == "kokoro"

    piper_reg = build_providers(make_settings(tts_provider="piper"))
    assert piper_reg.tts.name == "piper"

    fake_reg = build_providers(make_settings(tts_provider="fake"))
    assert fake_reg.tts.name == "fake"


def test_kokoro_tts_endpoint_returns_wav_with_mocked_engine(
    monkeypatch: pytest.MonkeyPatch, tmp_path: Path
) -> None:
    model_file = tmp_path / "kokoro-v1.0.onnx"
    voices_file = tmp_path / "voices-v1.0.bin"
    model_file.write_bytes(b"fake-onnx")
    voices_file.write_bytes(b"fake-voices")

    calls: list[dict[str, object]] = []

    class FakeKokoroEngine:
        def __init__(self, model_path: str, voices_path: str) -> None:
            self.model_path = model_path
            self.voices_path = voices_path

        def get_voices(self) -> list[str]:
            return ["af_heart", "af_bella", "bf_emma"]

        def create(
            self, text: str, *, voice: str, speed: float = 1.0, lang: str = "en-us"
        ) -> tuple[list[float], int]:
            calls.append({"text": text, "voice": voice, "speed": speed, "lang": lang})
            return [0.0, 0.25, -0.25, 0.5, -0.5, 0.0], 24000

    fake_module = types.ModuleType("kokoro_onnx")
    fake_module.Kokoro = FakeKokoroEngine  # type: ignore[attr-defined]
    monkeypatch.setitem(sys.modules, "kokoro_onnx", fake_module)

    app = create_app(
        settings=make_settings(
            tts_provider="kokoro",
            kokoro_model_path=str(model_file),
            kokoro_voices_path=str(voices_file),
            kokoro_voice="af_heart",
            kokoro_speed=1.1,
        )
    )
    client = make_client(providers=app.state.providers)

    health = client.get("/health")
    assert health.status_code == 200
    assert health.json()["providers"]["tts"] == "kokoro"

    resp = client.post(
        "/v1/tts",
        headers=auth_headers(),
        json={"text": "Heart rate is seventy-two beats per minute."},
    )
    assert resp.status_code == 200
    assert resp.headers["content-type"].startswith("audio/wav")
    assert resp.content.startswith(b"RIFF")
    assert b"WAVE" in resp.content[:16]
    with wave.open(io.BytesIO(resp.content), "rb") as wf:
        assert wf.getnchannels() == 1
        assert wf.getsampwidth() == 2
        assert wf.getframerate() == 24000
        assert wf.getnframes() == 6

    assert calls == [
        {
            "text": "Heart rate is seventy-two beats per minute.",
            "voice": "af_heart",
            "speed": 1.1,
            "lang": "en-us",
        }
    ]

    # British prefix uses en-gb automatically
    resp_uk = client.post(
        "/v1/tts",
        headers=auth_headers(),
        json={"text": "Oxygen levels nominal.", "voice": "bf_emma"},
    )
    assert resp_uk.status_code == 200
    assert calls[-1]["lang"] == "en-gb"


def test_kokoro_tts_rejects_unknown_voice(
    monkeypatch: pytest.MonkeyPatch, tmp_path: Path
) -> None:
    model_file = tmp_path / "kokoro-v1.0.onnx"
    voices_file = tmp_path / "voices-v1.0.bin"
    model_file.write_bytes(b"fake-onnx")
    voices_file.write_bytes(b"fake-voices")

    class FakeKokoroEngine:
        def __init__(self, model_path: str, voices_path: str) -> None:
            pass

        def get_voices(self) -> list[str]:
            return ["af_heart", "am_michael"]

        def create(
            self, text: str, *, voice: str, speed: float = 1.0, lang: str = "en-us"
        ) -> tuple[list[float], int]:
            return [0.0, 0.0], 24000

    fake_module = types.ModuleType("kokoro_onnx")
    fake_module.Kokoro = FakeKokoroEngine  # type: ignore[attr-defined]
    monkeypatch.setitem(sys.modules, "kokoro_onnx", fake_module)

    app = create_app(
        settings=make_settings(
            tts_provider="kokoro",
            kokoro_model_path=str(model_file),
            kokoro_voices_path=str(voices_file),
            kokoro_voice="af_heart",
        )
    )
    client = make_client(providers=app.state.providers)

    resp = client.post(
        "/v1/tts",
        headers=auth_headers(),
        json={"text": "Check pressure.", "voice": "unknown_voice_xyz"},
    )
    assert resp.status_code == 422
    assert resp.json()["error"]["code"] == "invalid_request"


def test_kokoro_tts_load_failure_returns_503_without_path_leakage() -> None:
    secret_model_path = "/var/private/secret-models/kokoro-v1.0.onnx"
    secret_voices_path = "/var/private/secret-models/voices-v1.0.bin"
    app = create_app(
        settings=make_settings(
            tts_provider="kokoro",
            kokoro_model_path=secret_model_path,
            kokoro_voices_path=secret_voices_path,
        )
    )
    client = make_client(providers=app.state.providers)

    resp = client.post(
        "/v1/tts",
        headers=auth_headers(),
        json={"text": "Vital signs nominal."},
    )
    assert resp.status_code == 503
    body = resp.json()
    assert body["error"]["code"] == "upstream_unavailable"
    assert secret_model_path not in resp.text
    assert secret_voices_path not in resp.text
    assert "secret-models" not in resp.text


def test_kokoro_tts_synthesis_failure_returns_502_without_path_leakage(
    monkeypatch: pytest.MonkeyPatch, tmp_path: Path
) -> None:
    model_file = tmp_path / "kokoro-v1.0.onnx"
    voices_file = tmp_path / "voices-v1.0.bin"
    model_file.write_bytes(b"fake-onnx")
    voices_file.write_bytes(b"fake-voices")

    class FailingKokoroEngine:
        def __init__(self, model_path: str, voices_path: str) -> None:
            pass

        def get_voices(self) -> list[str]:
            return ["af_heart"]

        def create(
            self, text: str, *, voice: str, speed: float = 1.0, lang: str = "en-us"
        ) -> tuple[list[float], int]:
            raise RuntimeError(f"onnx crash at {model_file}")

    fake_module = types.ModuleType("kokoro_onnx")
    fake_module.Kokoro = FailingKokoroEngine  # type: ignore[attr-defined]
    monkeypatch.setitem(sys.modules, "kokoro_onnx", fake_module)

    app = create_app(
        settings=make_settings(
            tts_provider="kokoro",
            kokoro_model_path=str(model_file),
            kokoro_voices_path=str(voices_file),
            kokoro_voice="af_heart",
        )
    )
    client = make_client(providers=app.state.providers)

    resp = client.post(
        "/v1/tts",
        headers=auth_headers(),
        json={"text": "Vital signs nominal."},
    )
    assert resp.status_code == 502
    body = resp.json()
    assert body["error"]["code"] == "upstream_unavailable"
    assert str(tmp_path) not in resp.text


def test_kokoro_speed_bounds_validated() -> None:
    with pytest.raises(ValueError):
        Settings(kokoro_speed=0.2)
    with pytest.raises(ValueError):
        Settings(kokoro_speed=2.5)
