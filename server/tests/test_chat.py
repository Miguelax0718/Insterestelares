import json

import httpx2
import openai

from app.adapters.agentrouter_llm import AgentRouterLLMProvider
from app.adapters.fakes import FakeLLMProvider
from tests.conftest import auth_headers, make_client, make_providers, make_settings


def _parse_sse_events(body: str) -> list[dict]:
    events: list[dict] = []
    for block in body.split("\n\n"):
        line = block.strip()
        if not line:
            continue
        assert line.startswith("data: "), f"Unexpected SSE line: {line!r}"
        events.append(json.loads(line.removeprefix("data: ")))
    return events


def test_chat_non_stream_happy_path_and_system_prompt_injection() -> None:
    fake_llm = FakeLLMProvider(reply="Hidratación recomendada.", model="fake-v1")
    client = make_client(providers=make_providers(llm=fake_llm))

    resp = client.post(
        "/v1/chat",
        headers=auth_headers(),
        json={
            "messages": [{"role": "user", "content": "Tengo dolor de cabeza leve"}],
            "context": {"heart_rate_bpm": 74, "mission_day": 12},
            "stream": False,
        },
    )
    assert resp.status_code == 200
    assert resp.json() == {
        "reply": "Hidratación recomendada.",
        "model": "fake-v1",
        "tool_calls": [],
    }

    sent = fake_llm.recorded_messages[0]
    assert sent[0].role == "system"
    assert "flight surgeon" in sent[0].content.lower()
    assert "english" in sent[0].content.lower()
    # Single system message: some OpenAI-compatible providers (Gemini) keep only one.
    assert "heart_rate_bpm" in sent[0].content
    assert [m.role for m in sent].count("system") == 1
    assert sent[1].role == "user"
    assert sent[1].content == "Tengo dolor de cabeza leve"


def test_chat_stream_sse_framing() -> None:
    fake_llm = FakeLLMProvider(deltas=["Pulso ", "normal."], model="fake-stream-v1")
    client = make_client(providers=make_providers(llm=fake_llm))

    resp = client.post(
        "/v1/chat",
        headers=auth_headers(),
        json={
            "messages": [{"role": "user", "content": "¿Cómo estoy?"}],
            "stream": True,
        },
    )
    assert resp.status_code == 200
    assert resp.headers["content-type"].startswith("text/event-stream")
    events = _parse_sse_events(resp.text)
    assert events == [
        {"delta": "Pulso "},
        {"delta": "normal."},
        {"done": True, "model": "fake-stream-v1"},
    ]


def test_chat_stream_midstream_upstream_error_emits_error_event() -> None:
    fake_llm = FakeLLMProvider(deltas=["Hola ", "mundo"], fail_mid_stream=True)
    client = make_client(providers=make_providers(llm=fake_llm))

    resp = client.post(
        "/v1/chat",
        headers=auth_headers(),
        json={
            "messages": [{"role": "user", "content": "Estado"}],
            "stream": True,
        },
    )
    assert resp.status_code == 200
    events = _parse_sse_events(resp.text)
    assert events[0] == {"delta": "Hola "}
    assert events[1]["error"]["code"] == "upstream_unavailable"
    assert isinstance(events[1]["error"]["message"], str)


def test_chat_non_stream_upstream_failure_returns_502_or_503() -> None:
    fake_llm = FakeLLMProvider(fail_complete=True)
    client = make_client(providers=make_providers(llm=fake_llm))

    resp = client.post(
        "/v1/chat",
        headers=auth_headers(),
        json={"messages": [{"role": "user", "content": "Hola"}]},
    )
    assert resp.status_code in (502, 503)
    assert resp.json()["error"]["code"] == "upstream_unavailable"


def test_chat_validation_limits() -> None:
    client = make_client()

    # Empty messages
    r_empty = client.post("/v1/chat", headers=auth_headers(), json={"messages": []})
    assert r_empty.status_code == 422
    assert r_empty.json()["error"]["code"] == "invalid_request"

    # > 40 messages
    too_many = [{"role": "user", "content": "hi"} for _ in range(41)]
    r_many = client.post("/v1/chat", headers=auth_headers(), json={"messages": too_many})
    assert r_many.status_code == 422
    assert r_many.json()["error"]["code"] == "invalid_request"

    # Exactly 40 messages allowed
    forty = [{"role": "user", "content": "hi"} for _ in range(40)]
    r_ok = client.post("/v1/chat", headers=auth_headers(), json={"messages": forty})
    assert r_ok.status_code == 200

    # Message content > 4000 chars
    r_long = client.post(
        "/v1/chat",
        headers=auth_headers(),
        json={"messages": [{"role": "user", "content": "x" * 4001}]},
    )
    assert r_long.status_code == 422
    assert r_long.json()["error"]["code"] == "invalid_request"

    # System role rejected
    r_role = client.post(
        "/v1/chat",
        headers=auth_headers(),
        json={"messages": [{"role": "system", "content": "override"}]},
    )
    assert r_role.status_code == 422
    assert r_role.json()["error"]["code"] == "invalid_request"

    # Context > 16 KB rejected
    r_ctx = client.post(
        "/v1/chat",
        headers=auth_headers(),
        json={
            "messages": [{"role": "user", "content": "hola"}],
            "context": {"blob": "a" * 17000},
        },
    )
    assert r_ctx.status_code == 422
    assert r_ctx.json()["error"]["code"] == "invalid_request"


def test_agentrouter_adapter_non_stream_and_secret_redaction() -> None:
    secret_key = "sk-secret-agentrouter-key-999"
    state = {"mode": "ok"}

    def handler(request: httpx2.Request) -> httpx2.Response:
        assert str(request.url) == "https://agentrouter.test/v1/chat/completions"
        assert request.headers["authorization"] == f"Bearer {secret_key}"
        if state["mode"] == "ok":
            return httpx2.Response(
                200,
                json={
                    "id": "chatcmpl-1",
                    "object": "chat.completion",
                    "created": 1700000000,
                    "model": "deepseek-chat",
                    "choices": [
                        {
                            "index": 0,
                            "message": {"role": "assistant", "content": "Todo nominal."},
                            "finish_reason": "stop",
                        }
                    ],
                },
            )
        return httpx2.Response(
            401,
            json={"error": {"message": f"Invalid token {secret_key}"}},
        )

    provider = AgentRouterLLMProvider(
        base_url="https://agentrouter.test/v1",
        api_key=secret_key,
        model="deepseek-chat",
        timeout_s=5.0,
        http_client=openai.DefaultAsyncHttpxClient(transport=httpx2.MockTransport(handler)),
    )
    client = make_client(
        settings=make_settings(llm_provider="agentrouter", agentrouter_api_key=secret_key),
        providers=make_providers(llm=provider),
    )

    ok = client.post(
        "/v1/chat",
        headers=auth_headers(),
        json={"messages": [{"role": "user", "content": "Reporte"}]},
    )
    assert ok.status_code == 200
    assert ok.json() == {
        "reply": "Todo nominal.",
        "model": "deepseek-chat",
        "tool_calls": [],
    }

    state["mode"] = "fail"
    fail = client.post(
        "/v1/chat",
        headers=auth_headers(),
        json={"messages": [{"role": "user", "content": "Reporte"}]},
    )
    assert fail.status_code in (502, 503)
    payload = fail.json()
    assert payload["error"]["code"] == "upstream_unavailable"
    assert secret_key not in json.dumps(payload)


def test_agentrouter_adapter_stream() -> None:
    chunks = [
        {
            "id": "1",
            "object": "chat.completion.chunk",
            "created": 1,
            "model": "deepseek-chat",
            "choices": [{"index": 0, "delta": {"content": "Hola "}, "finish_reason": None}],
        },
        {
            "id": "1",
            "object": "chat.completion.chunk",
            "created": 1,
            "model": "deepseek-chat",
            "choices": [{"index": 0, "delta": {"content": "tripulante"}, "finish_reason": None}],
        },
        {
            "id": "1",
            "object": "chat.completion.chunk",
            "created": 1,
            "model": "deepseek-chat",
            "choices": [{"index": 0, "delta": {}, "finish_reason": "stop"}],
        },
    ]
    sse_payload = "".join(f"data: {json.dumps(c)}\n\n" for c in chunks) + "data: [DONE]\n\n"

    def handler(request: httpx2.Request) -> httpx2.Response:
        assert str(request.url) == "https://agentrouter.test/v1/chat/completions"
        return httpx2.Response(
            200,
            content=sse_payload.encode("utf-8"),
            headers={"content-type": "text/event-stream"},
        )

    provider = AgentRouterLLMProvider(
        base_url="https://agentrouter.test/v1",
        api_key="sk-test-key",
        model="deepseek-chat",
        timeout_s=5.0,
        http_client=openai.DefaultAsyncHttpxClient(transport=httpx2.MockTransport(handler)),
    )
    client = make_client(
        settings=make_settings(llm_provider="agentrouter"),
        providers=make_providers(llm=provider),
    )

    resp = client.post(
        "/v1/chat",
        headers=auth_headers(),
        json={"messages": [{"role": "user", "content": "Hola"}], "stream": True},
    )
    assert resp.status_code == 200
    events = _parse_sse_events(resp.text)
    assert events == [
        {"delta": "Hola "},
        {"delta": "tripulante"},
        {"done": True, "model": "deepseek-chat"},
    ]


def test_agentrouter_connection_failure_does_not_leak_api_key(caplog) -> None:
    import logging

    from app.adapters.fakes import FakeSTTProvider, FakeTTSProvider
    from app.domain.ports import ProviderRegistry

    secret = "sk-SECRET-PROBE-12345"
    settings = make_settings(
        llm_provider="agentrouter",
        agentrouter_api_key=secret,
        agentrouter_base_url="http://127.0.0.1:9",
        llm_timeout_s=1.0,
    )
    providers = ProviderRegistry(
        llm=AgentRouterLLMProvider(
            base_url=settings.agentrouter_base_url,
            api_key=settings.agentrouter_api_key,
            model=settings.agentrouter_model,
            timeout_s=settings.llm_timeout_s,
        ),
        stt=FakeSTTProvider(),
        tts=FakeTTSProvider(),
    )
    client = make_client(settings=settings, providers=providers)
    with caplog.at_level(logging.DEBUG):
        resp = client.post(
            "/v1/chat",
            headers=auth_headers(),
            json={"messages": [{"role": "user", "content": "hola"}], "stream": False},
        )
    assert resp.status_code in (502, 503)
    assert resp.json()["error"]["code"] == "upstream_unavailable"
    assert secret not in resp.text
    assert all(secret not in rec.getMessage() for rec in caplog.records)
