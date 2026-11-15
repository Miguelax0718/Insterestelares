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


SAMPLE_TOOLS = [
    {
        "name": "get_vitals",
        "description": "Read latest vital signs for an astronaut.",
        "parameters": {
            "type": "object",
            "properties": {"astronaut_id": {"type": "string"}},
            "required": ["astronaut_id"],
        },
    }
]


def test_plain_chat_without_tools_preserves_behavior_and_returns_empty_tool_calls() -> None:
    fake_llm = FakeLLMProvider(reply="Signos estables.", model="fake-v1")
    client = make_client(providers=make_providers(llm=fake_llm))

    resp = client.post(
        "/v1/chat",
        headers=auth_headers(),
        json={
            "messages": [{"role": "user", "content": "Estado general"}],
            "context": {"heart_rate_bpm": 70},
            "stream": False,
        },
    )
    assert resp.status_code == 200
    assert resp.json() == {
        "reply": "Signos estables.",
        "model": "fake-v1",
        "tool_calls": [],
    }
    assert len(fake_llm.recorded_messages) == 1
    assert fake_llm.recorded_messages[0][0].role == "system"
    assert "Tool rules:" not in fake_llm.recorded_messages[0][0].content
    assert fake_llm.recorded_tools == [None]


def test_single_system_message_with_tools_skills_and_context() -> None:
    fake_llm = FakeLLMProvider(reply="Revisando signos.", model="fake-v1")
    client = make_client(providers=make_providers(llm=fake_llm))

    resp = client.post(
        "/v1/chat",
        headers=auth_headers(),
        json={
            "messages": [{"role": "user", "content": "Checa mis signos"}],
            "tools": SAMPLE_TOOLS,
            "skill_instructions": [
                "Skill vitals: compare heart rate against baseline before advising."
            ],
            "context": {"heart_rate_bpm": 76, "mission_day": 14},
            "stream": False,
        },
    )
    assert resp.status_code == 200
    sent = fake_llm.recorded_messages[0]
    assert [m.role for m in sent].count("system") == 1
    assert sent[0].role == "system"
    system_text = sent[0].content or ""
    assert "flight surgeon" in system_text.lower()
    assert "Tool rules:" in system_text
    assert "Skill vitals: compare heart rate against baseline before advising." in system_text
    assert "heart_rate_bpm" in system_text
    assert sent[1].role == "user"
    assert sent[1].content == "Checa mis signos"


def test_agentrouter_forwards_tools_and_returns_non_stream_tool_calls() -> None:
    captured_bodies: list[dict] = []

    def handler(request: httpx2.Request) -> httpx2.Response:
        captured_bodies.append(json.loads(request.content.decode("utf-8")))
        return httpx2.Response(
            200,
            json={
                "id": "chatcmpl-tool-1",
                "object": "chat.completion",
                "created": 1700000000,
                "model": "gemini-3.5-flash-lite",
                "choices": [
                    {
                        "index": 0,
                        "message": {
                            "role": "assistant",
                            "content": None,
                            "tool_calls": [
                                {
                                    "id": "call_abc",
                                    "type": "function",
                                    "function": {
                                        "name": "get_vitals",
                                        "arguments": '{"astronaut_id":"crew-1"}',
                                    },
                                }
                            ],
                        },
                        "finish_reason": "tool_calls",
                    }
                ],
            },
        )

    provider = AgentRouterLLMProvider(
        base_url="https://agentrouter.test/v1",
        api_key="sk-test",
        model="gemini-3.5-flash-lite",
        timeout_s=5.0,
        http_client=openai.DefaultAsyncHttpxClient(transport=httpx2.MockTransport(handler)),
    )
    client = make_client(
        settings=make_settings(llm_provider="agentrouter", agentrouter_api_key="sk-test"),
        providers=make_providers(llm=provider),
    )

    resp = client.post(
        "/v1/chat",
        headers=auth_headers(),
        json={
            "messages": [{"role": "user", "content": "¿Cómo está mi pulso?"}],
            "tools": SAMPLE_TOOLS,
            "stream": False,
        },
    )
    assert resp.status_code == 200
    assert resp.json() == {
        "reply": "",
        "model": "gemini-3.5-flash-lite",
        "tool_calls": [
            {
                "id": "call_abc",
                "name": "get_vitals",
                "arguments": {"astronaut_id": "crew-1"},
            }
        ],
    }
    assert len(captured_bodies) == 1
    assert captured_bodies[0]["tools"] == [
        {
            "type": "function",
            "function": {
                "name": "get_vitals",
                "description": "Read latest vital signs for an astronaut.",
                "parameters": SAMPLE_TOOLS[0]["parameters"],
            },
        }
    ]


def test_agentrouter_stream_emits_tool_calls_after_deltas_and_before_done() -> None:
    chunks = [
        {
            "id": "1",
            "object": "chat.completion.chunk",
            "created": 1,
            "model": "gemini-3.5-flash-lite",
            "choices": [
                {
                    "index": 0,
                    "delta": {
                        "content": "Consultando ",
                        "tool_calls": [
                            {
                                "index": 0,
                                "id": "call_s1",
                                "type": "function",
                                "function": {"name": "get_vitals", "arguments": '{"astronaut'},
                            }
                        ],
                    },
                    "finish_reason": None,
                }
            ],
        },
        {
            "id": "1",
            "object": "chat.completion.chunk",
            "created": 1,
            "model": "gemini-3.5-flash-lite",
            "choices": [
                {
                    "index": 0,
                    "delta": {
                        "content": "datos.",
                        "tool_calls": [
                            {
                                "index": 0,
                                "function": {"arguments": '_id":"crew-1"}'},
                            },
                            {
                                "index": 1,
                                "id": "call_s2",
                                "type": "function",
                                "function": {"name": "recall_memory", "arguments": "{}"},
                            },
                        ],
                    },
                    "finish_reason": "tool_calls",
                }
            ],
        },
    ]
    sse_payload = "".join(f"data: {json.dumps(c)}\n\n" for c in chunks) + "data: [DONE]\n\n"

    def handler(_request: httpx2.Request) -> httpx2.Response:
        return httpx2.Response(
            200,
            content=sse_payload.encode("utf-8"),
            headers={"content-type": "text/event-stream"},
        )

    provider = AgentRouterLLMProvider(
        base_url="https://agentrouter.test/v1",
        api_key="sk-test",
        model="gemini-3.5-flash-lite",
        timeout_s=5.0,
        http_client=openai.DefaultAsyncHttpxClient(transport=httpx2.MockTransport(handler)),
    )
    client = make_client(
        settings=make_settings(llm_provider="agentrouter", agentrouter_api_key="sk-test"),
        providers=make_providers(llm=provider),
    )

    resp = client.post(
        "/v1/chat",
        headers=auth_headers(),
        json={
            "messages": [{"role": "user", "content": "Revisa signos"}],
            "tools": SAMPLE_TOOLS,
            "stream": True,
        },
    )
    assert resp.status_code == 200
    events = _parse_sse_events(resp.text)
    assert events == [
        {"delta": "Consultando "},
        {"delta": "datos."},
        {
            "tool_call": {
                "id": "call_s1",
                "name": "get_vitals",
                "arguments": {"astronaut_id": "crew-1"},
            }
        },
        {
            "tool_call": {
                "id": "call_s2",
                "name": "recall_memory",
                "arguments": {},
            }
        },
        {"done": True, "model": "gemini-3.5-flash-lite"},
    ]


def test_tool_role_round_trip_mapped_to_openai_shape() -> None:
    captured_bodies: list[dict] = []

    def handler(request: httpx2.Request) -> httpx2.Response:
        captured_bodies.append(json.loads(request.content.decode("utf-8")))
        return httpx2.Response(
            200,
            json={
                "id": "chatcmpl-roundtrip",
                "object": "chat.completion",
                "created": 1700000000,
                "model": "gemini-3.5-flash-lite",
                "choices": [
                    {
                        "index": 0,
                        "message": {"role": "assistant", "content": "Pulso en 72 lpm, nominal."},
                        "finish_reason": "stop",
                    }
                ],
            },
        )

    provider = AgentRouterLLMProvider(
        base_url="https://agentrouter.test/v1",
        api_key="sk-test",
        model="gemini-3.5-flash-lite",
        timeout_s=5.0,
        http_client=openai.DefaultAsyncHttpxClient(transport=httpx2.MockTransport(handler)),
    )
    client = make_client(
        settings=make_settings(llm_provider="agentrouter", agentrouter_api_key="sk-test"),
        providers=make_providers(llm=provider),
    )

    resp = client.post(
        "/v1/chat",
        headers=auth_headers(),
        json={
            "messages": [
                {"role": "user", "content": "¿Cómo está mi pulso?"},
                {
                    "role": "assistant",
                    "content": None,
                    "tool_calls": [
                        {
                            "id": "call_1",
                            "name": "get_vitals",
                            "arguments": {"astronaut_id": "crew-1"},
                        }
                    ],
                },
                {
                    "role": "tool",
                    "tool_call_id": "call_1",
                    "content": '{"heart_rate_bpm":72}',
                },
            ],
            "tools": SAMPLE_TOOLS,
            "stream": False,
        },
    )
    assert resp.status_code == 200
    assert resp.json() == {
        "reply": "Pulso en 72 lpm, nominal.",
        "model": "gemini-3.5-flash-lite",
        "tool_calls": [],
    }
    sent_messages = captured_bodies[0]["messages"]
    assert sent_messages[0]["role"] == "system"
    assert sent_messages[1] == {"role": "user", "content": "¿Cómo está mi pulso?"}
    assert sent_messages[2]["role"] == "assistant"
    assert sent_messages[2]["content"] is None
    assert len(sent_messages[2]["tool_calls"]) == 1
    tc_sent = sent_messages[2]["tool_calls"][0]
    assert tc_sent["id"] == "call_1"
    assert tc_sent["type"] == "function"
    assert tc_sent["function"]["name"] == "get_vitals"
    assert json.loads(tc_sent["function"]["arguments"]) == {"astronaut_id": "crew-1"}
    assert sent_messages[3] == {
        "role": "tool",
        "tool_call_id": "call_1",
        "content": '{"heart_rate_bpm":72}',
    }


def test_unmatched_tool_call_id_returns_422() -> None:
    client = make_client()

    # No earlier assistant tool call
    resp = client.post(
        "/v1/chat",
        headers=auth_headers(),
        json={
            "messages": [
                {"role": "user", "content": "Hola"},
                {
                    "role": "tool",
                    "tool_call_id": "call_unknown",
                    "content": '{"ok":true}',
                },
            ]
        },
    )
    assert resp.status_code == 422
    assert resp.json()["error"]["code"] == "invalid_request"

    # Assistant has call_1, tool references call_other
    resp_mismatch = client.post(
        "/v1/chat",
        headers=auth_headers(),
        json={
            "messages": [
                {"role": "user", "content": "Hola"},
                {
                    "role": "assistant",
                    "content": None,
                    "tool_calls": [{"id": "call_1", "name": "get_vitals", "arguments": {}}],
                },
                {
                    "role": "tool",
                    "tool_call_id": "call_other",
                    "content": '{"ok":true}',
                },
            ]
        },
    )
    assert resp_mismatch.status_code == 422
    assert resp_mismatch.json()["error"]["code"] == "invalid_request"

    # Tool message appears before the assistant message declaring call_1
    resp_order = client.post(
        "/v1/chat",
        headers=auth_headers(),
        json={
            "messages": [
                {"role": "user", "content": "Hola"},
                {
                    "role": "tool",
                    "tool_call_id": "call_1",
                    "content": '{"ok":true}',
                },
                {
                    "role": "assistant",
                    "content": None,
                    "tool_calls": [{"id": "call_1", "name": "get_vitals", "arguments": {}}],
                },
            ]
        },
    )
    assert resp_order.status_code == 422
    assert resp_order.json()["error"]["code"] == "invalid_request"


def test_invalid_arguments_and_missing_id_from_upstream() -> None:
    def handler(_request: httpx2.Request) -> httpx2.Response:
        return httpx2.Response(
            200,
            json={
                "id": "chatcmpl-bad-args",
                "object": "chat.completion",
                "created": 1700000000,
                "model": "gemini-3.5-flash-lite",
                "choices": [
                    {
                        "index": 0,
                        "message": {
                            "role": "assistant",
                            "content": "",
                            "tool_calls": [
                                {
                                    "type": "function",
                                    "function": {
                                        "name": "get_vitals",
                                        "arguments": "{not valid json",
                                    },
                                },
                                {
                                    "id": "call_arr",
                                    "type": "function",
                                    "function": {
                                        "name": "get_vitals",
                                        "arguments": "[1, 2, 3]",
                                    },
                                },
                            ],
                        },
                        "finish_reason": "tool_calls",
                    }
                ],
            },
        )

    provider = AgentRouterLLMProvider(
        base_url="https://agentrouter.test/v1",
        api_key="sk-test",
        model="gemini-3.5-flash-lite",
        timeout_s=5.0,
        http_client=openai.DefaultAsyncHttpxClient(transport=httpx2.MockTransport(handler)),
    )
    client = make_client(
        settings=make_settings(llm_provider="agentrouter", agentrouter_api_key="sk-test"),
        providers=make_providers(llm=provider),
    )

    resp = client.post(
        "/v1/chat",
        headers=auth_headers(),
        json={
            "messages": [{"role": "user", "content": "Dame signos"}],
            "tools": SAMPLE_TOOLS,
            "stream": False,
        },
    )
    assert resp.status_code == 200
    assert resp.json() == {
        "reply": "",
        "model": "gemini-3.5-flash-lite",
        "tool_calls": [
            {
                "id": "call_0",
                "name": "get_vitals",
                "arguments": {},
                "invalid_arguments": True,
            },
            {
                "id": "call_arr",
                "name": "get_vitals",
                "arguments": {},
                "invalid_arguments": True,
            },
        ],
    }


def test_tools_and_skill_instructions_limits_return_422() -> None:
    client = make_client()

    # 33 tools > 32
    too_many_tools = [
        {
            "name": f"tool_{i}",
            "description": "Tool",
            "parameters": {"type": "object", "properties": {}},
        }
        for i in range(33)
    ]
    r_33 = client.post(
        "/v1/chat",
        headers=auth_headers(),
        json={"messages": [{"role": "user", "content": "hi"}], "tools": too_many_tools},
    )
    assert r_33.status_code == 422
    assert r_33.json()["error"]["code"] == "invalid_request"

    # Invalid tool name regex
    r_bad_name = client.post(
        "/v1/chat",
        headers=auth_headers(),
        json={
            "messages": [{"role": "user", "content": "hi"}],
            "tools": [
                {
                    "name": "bad-tool-name!",
                    "description": "Tool",
                    "parameters": {"type": "object"},
                }
            ],
        },
    )
    assert r_bad_name.status_code == 422
    assert r_bad_name.json()["error"]["code"] == "invalid_request"

    # Tools serialized > 24 KB
    r_big_tools = client.post(
        "/v1/chat",
        headers=auth_headers(),
        json={
            "messages": [{"role": "user", "content": "hi"}],
            "tools": [
                {
                    "name": "big_tool",
                    "description": "Tool",
                    "parameters": {"type": "object", "blob": "a" * 25000},
                }
            ],
        },
    )
    assert r_big_tools.status_code == 422
    assert r_big_tools.json()["error"]["code"] == "invalid_request"

    # Oversized skill instruction (> 2000 chars)
    r_big_skill = client.post(
        "/v1/chat",
        headers=auth_headers(),
        json={
            "messages": [{"role": "user", "content": "hi"}],
            "skill_instructions": ["s" * 2001],
        },
    )
    assert r_big_skill.status_code == 422
    assert r_big_skill.json()["error"]["code"] == "invalid_request"

    # > 8 skill instructions
    r_many_skills = client.post(
        "/v1/chat",
        headers=auth_headers(),
        json={
            "messages": [{"role": "user", "content": "hi"}],
            "skill_instructions": ["skill" for _ in range(9)],
        },
    )
    assert r_many_skills.status_code == 422
    assert r_many_skills.json()["error"]["code"] == "invalid_request"

    # Assistant message with null content and no tool_calls rejected
    r_null_assist = client.post(
        "/v1/chat",
        headers=auth_headers(),
        json={"messages": [{"role": "assistant", "content": None}]},
    )
    assert r_null_assist.status_code == 422
    assert r_null_assist.json()["error"]["code"] == "invalid_request"


def test_fake_llm_provider_tool_calls_and_recorded_tools() -> None:
    from app.domain.models import ToolCall

    fake_llm = FakeLLMProvider(
        reply="",
        deltas=[],
        tool_calls=[
            ToolCall(id="call_f1", name="get_vitals", arguments={"astronaut_id": "crew-1"})
        ],
    )
    client = make_client(providers=make_providers(llm=fake_llm))

    resp = client.post(
        "/v1/chat",
        headers=auth_headers(),
        json={
            "messages": [{"role": "user", "content": "Checa pulso"}],
            "tools": SAMPLE_TOOLS,
            "stream": False,
        },
    )
    assert resp.status_code == 200
    assert resp.json() == {
        "reply": "",
        "model": "fake-clinical-model",
        "tool_calls": [
            {
                "id": "call_f1",
                "name": "get_vitals",
                "arguments": {"astronaut_id": "crew-1"},
            }
        ],
    }
    assert len(fake_llm.recorded_tools) == 1
    assert fake_llm.recorded_tools[0] is not None
    assert fake_llm.recorded_tools[0][0].name == "get_vitals"


def test_agentrouter_stream_invalid_arguments_and_missing_id() -> None:
    chunks = [
        {
            "id": "1",
            "object": "chat.completion.chunk",
            "created": 1,
            "model": "gemini-3.5-flash-lite",
            "choices": [
                {
                    "index": 0,
                    "delta": {
                        "tool_calls": [
                            {
                                "index": 0,
                                "type": "function",
                                "function": {"name": "get_vitals", "arguments": "not-json"},
                            }
                        ]
                    },
                    "finish_reason": "tool_calls",
                }
            ],
        }
    ]
    sse_payload = "".join(f"data: {json.dumps(c)}\n\n" for c in chunks) + "data: [DONE]\n\n"

    def handler(_request: httpx2.Request) -> httpx2.Response:
        return httpx2.Response(
            200,
            content=sse_payload.encode("utf-8"),
            headers={"content-type": "text/event-stream"},
        )

    provider = AgentRouterLLMProvider(
        base_url="https://agentrouter.test/v1",
        api_key="sk-test",
        model="gemini-3.5-flash-lite",
        timeout_s=5.0,
        http_client=openai.DefaultAsyncHttpxClient(transport=httpx2.MockTransport(handler)),
    )
    client = make_client(
        settings=make_settings(llm_provider="agentrouter", agentrouter_api_key="sk-test"),
        providers=make_providers(llm=provider),
    )

    resp = client.post(
        "/v1/chat",
        headers=auth_headers(),
        json={
            "messages": [{"role": "user", "content": "Signos"}],
            "tools": SAMPLE_TOOLS,
            "stream": True,
        },
    )
    assert resp.status_code == 200
    events = _parse_sse_events(resp.text)
    assert events == [
        {
            "tool_call": {
                "id": "call_0",
                "name": "get_vitals",
                "arguments": {},
                "invalid_arguments": True,
            }
        },
        {"done": True, "model": "gemini-3.5-flash-lite"},
    ]


def test_empty_tools_list_omits_tools_upstream_and_tool_rules() -> None:
    captured_bodies: list[dict] = []

    def handler(request: httpx2.Request) -> httpx2.Response:
        captured_bodies.append(json.loads(request.content.decode("utf-8")))
        return httpx2.Response(
            200,
            json={
                "id": "chatcmpl-no-tools",
                "object": "chat.completion",
                "created": 1700000000,
                "model": "gemini-3.5-flash-lite",
                "choices": [
                    {
                        "index": 0,
                        "message": {"role": "assistant", "content": "Sin herramientas."},
                        "finish_reason": "stop",
                    }
                ],
            },
        )

    provider = AgentRouterLLMProvider(
        base_url="https://agentrouter.test/v1",
        api_key="sk-test",
        model="gemini-3.5-flash-lite",
        timeout_s=5.0,
        http_client=openai.DefaultAsyncHttpxClient(transport=httpx2.MockTransport(handler)),
    )
    client = make_client(
        settings=make_settings(llm_provider="agentrouter", agentrouter_api_key="sk-test"),
        providers=make_providers(llm=provider),
    )

    resp = client.post(
        "/v1/chat",
        headers=auth_headers(),
        json={
            "messages": [{"role": "user", "content": "Hola"}],
            "tools": [],
            "stream": False,
        },
    )
    assert resp.status_code == 200
    assert resp.json() == {
        "reply": "Sin herramientas.",
        "model": "gemini-3.5-flash-lite",
        "tool_calls": [],
    }
    assert "tools" not in captured_bodies[0]
    assert "Tool rules:" not in captured_bodies[0]["messages"][0]["content"]


def test_tool_call_preserves_extra_content_roundtrip_non_stream_and_stream() -> None:
    captured_bodies: list[dict] = []
    extra = {"google": {"thought_signature": "sig-roundtrip-123"}}
    call_count = 0

    def handler(request: httpx2.Request) -> httpx2.Response:
        nonlocal call_count
        body = json.loads(request.content.decode("utf-8"))
        captured_bodies.append(body)
        call_count += 1
        if body.get("stream"):
            sse = (
                "data: "
                + json.dumps(
                    {
                        "id": "chatcmpl-s1",
                        "model": "gemini-3.5-flash-lite",
                        "choices": [
                            {
                                "index": 0,
                                "delta": {
                                    "role": "assistant",
                                    "tool_calls": [
                                        {
                                            "index": 0,
                                            "id": "call_s1",
                                            "type": "function",
                                            "function": {
                                                "name": "get_vitals",
                                                "arguments": '{"astronaut_id":"AST-01"}',
                                            },
                                            "extra_content": extra,
                                        }
                                    ],
                                },
                                "finish_reason": None,
                            }
                        ],
                    }
                )
                + "\n\n"
                + "data: [DONE]\n\n"
            )
            return httpx2.Response(
                200,
                content=sse.encode("utf-8"),
                headers={"content-type": "text/event-stream"},
            )
        if call_count == 1:
            return httpx2.Response(
                200,
                json={
                    "id": "chatcmpl-1",
                    "object": "chat.completion",
                    "created": 1700000000,
                    "model": "gemini-3.5-flash-lite",
                    "choices": [
                        {
                            "index": 0,
                            "message": {
                                "role": "assistant",
                                "content": None,
                                "tool_calls": [
                                    {
                                        "id": "call_1",
                                        "type": "function",
                                        "function": {
                                            "name": "get_vitals",
                                            "arguments": '{"astronaut_id":"AST-01"}',
                                        },
                                        "extra_content": extra,
                                    }
                                ],
                            },
                            "finish_reason": "tool_calls",
                        }
                    ],
                },
            )
        return httpx2.Response(
            200,
            json={
                "id": "chatcmpl-2",
                "object": "chat.completion",
                "created": 1700000001,
                "model": "gemini-3.5-flash-lite",
                "choices": [
                    {
                        "index": 0,
                        "message": {"role": "assistant", "content": "Todo estable."},
                        "finish_reason": "stop",
                    }
                ],
            },
        )

    provider = AgentRouterLLMProvider(
        base_url="https://agentrouter.test/v1",
        api_key="sk-test",
        model="gemini-3.5-flash-lite",
        timeout_s=5.0,
        http_client=openai.DefaultAsyncHttpxClient(transport=httpx2.MockTransport(handler)),
    )
    client = make_client(
        settings=make_settings(llm_provider="agentrouter", agentrouter_api_key="sk-test"),
        providers=make_providers(llm=provider),
    )

    r1 = client.post(
        "/v1/chat",
        headers=auth_headers(),
        json={
            "messages": [{"role": "user", "content": "Signos"}],
            "tools": [{"name": "get_vitals", "description": "d", "parameters": {"type": "object"}}],
            "stream": False,
        },
    )
    assert r1.status_code == 200
    tc_out = r1.json()["tool_calls"][0]
    assert tc_out["extra_content"] == extra

    r2 = client.post(
        "/v1/chat",
        headers=auth_headers(),
        json={
            "messages": [
                {"role": "user", "content": "Signos"},
                {"role": "assistant", "content": None, "tool_calls": [tc_out]},
                {"role": "tool", "tool_call_id": "call_1", "content": '{"hr":72}'},
            ],
            "tools": [{"name": "get_vitals", "description": "d", "parameters": {"type": "object"}}],
            "stream": False,
        },
    )
    assert r2.status_code == 200
    assert captured_bodies[1]["messages"][2]["tool_calls"][0]["extra_content"] == extra

    rs = client.post(
        "/v1/chat",
        headers=auth_headers(),
        json={
            "messages": [{"role": "user", "content": "Signos"}],
            "tools": [{"name": "get_vitals", "description": "d", "parameters": {"type": "object"}}],
            "stream": True,
        },
    )
    assert rs.status_code == 200
    events = [
        json.loads(line[6:])
        for line in rs.text.splitlines()
        if line.startswith("data: ")
    ]
    tc_events = [e["tool_call"] for e in events if "tool_call" in e]
    assert tc_events[0]["extra_content"] == extra
