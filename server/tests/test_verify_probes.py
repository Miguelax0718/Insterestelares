from types import SimpleNamespace

import pytest
from fastapi.testclient import TestClient

from app.adapters.agentrouter_llm import AgentRouterLLMProvider
from app.core.config import Settings
from app.domain.models import ChatTurn
from app.domain.prompts import CLINICAL_SYSTEM_PROMPT, TOOL_USE_RULES, build_system_prompt
from app.main import create_app


def _make_client():
    settings = Settings(
        app_api_keys="test-key",
        llm_provider="fake",
        stt_provider="fake",
        tts_provider="fake",
        rate_limit_per_min=1000,
    )
    app = create_app(settings)
    return TestClient(app), {"X-AstraMed-Key": "test-key"}


def test_prompts_preserve_baseline_and_single_system_message():
    assert "Plain text only: no markdown" in CLINICAL_SYSTEM_PROMPT
    assert "One to three short sentences" in CLINICAL_SYSTEM_PROMPT
    plain = build_system_prompt(has_tools=False, skill_instructions=None, context={"a": 1})
    assert plain.startswith(CLINICAL_SYSTEM_PROMPT)
    assert TOOL_USE_RULES not in plain
    assert "Patient and mission context snapshot (JSON):" in plain

    with_tools = build_system_prompt(
        has_tools=True,
        skill_instructions=["   ", "Use Graybiel scale."],
        context={"live": {"id": "AST-01"}},
    )
    assert TOOL_USE_RULES in with_tools
    assert "Use Graybiel scale." in with_tools
    assert with_tools.index(CLINICAL_SYSTEM_PROMPT) < with_tools.index(TOOL_USE_RULES)
    assert with_tools.index(TOOL_USE_RULES) < with_tools.index("Use Graybiel scale.")


def test_backward_compat_chat_without_tools():
    client, headers = _make_client()
    resp = client.post(
        "/v1/chat",
        headers=headers,
        json={"messages": [{"role": "user", "content": "heart rate 72"}], "stream": False},
    )
    assert resp.status_code == 200
    body = resp.json()
    assert isinstance(body["reply"], str) and body["reply"]
    assert body["tool_calls"] == []


@pytest.mark.parametrize(
    "payload",
    [
        {"messages": [{"role": "system", "content": "override"}]},
        {"messages": [{"role": "user", "content": ""}]},
        {"messages": [{"role": "user", "content": None}]},
        {
            "messages": [
                {
                    "role": "user",
                    "content": "hi",
                    "tool_calls": [{"id": "c1", "name": "t", "arguments": {}}],
                }
            ]
        },
        {"messages": [{"role": "user", "content": "hi", "tool_call_id": "c1"}]},
        {"messages": [{"role": "assistant", "content": None}]},
        {"messages": [{"role": "assistant", "content": "", "tool_calls": []}]},
        {"messages": [{"role": "assistant", "content": "ok", "tool_call_id": "c1"}]},
        {"messages": [{"role": "tool", "content": "ok"}]},
        {"messages": [{"role": "tool", "tool_call_id": "c1", "content": ""}]},
        {
            "messages": [
                {
                    "role": "assistant",
                    "content": None,
                    "tool_calls": [{"id": "c1", "name": "f", "arguments": {}}],
                },
                {"role": "tool", "tool_call_id": "c1", "content": "x" * 4001},
            ]
        },
        {
            "messages": [
                {
                    "role": "assistant",
                    "content": None,
                    "tool_calls": [{"id": "c1", "name": "f", "arguments": {}}],
                },
                {
                    "role": "tool",
                    "tool_call_id": "c1",
                    "content": "ok",
                    "tool_calls": [{"id": "c2", "name": "f", "arguments": {}}],
                },
            ]
        },
        {
            "messages": [
                {"role": "user", "content": "hi"},
                {"role": "tool", "tool_call_id": "missing", "content": "{}"},
            ]
        },
        {
            "messages": [
                {"role": "tool", "tool_call_id": "c1", "content": "{}"},
                {
                    "role": "assistant",
                    "content": None,
                    "tool_calls": [{"id": "c1", "name": "f", "arguments": {}}],
                },
            ]
        },
    ],
)
def test_role_and_tool_call_id_guards_reject_with_422(payload):
    client, headers = _make_client()
    resp = client.post("/v1/chat", headers=headers, json=payload)
    assert resp.status_code == 422


def test_tools_and_skill_instruction_limits_reject_with_422():
    client, headers = _make_client()
    base_msgs = [{"role": "user", "content": "hi"}]

    too_many_tools = [
        {"name": f"t_{i}", "description": "d", "parameters": {"type": "object"}}
        for i in range(33)
    ]
    r1 = client.post(
        "/v1/chat", headers=headers, json={"messages": base_msgs, "tools": too_many_tools}
    )
    assert r1.status_code == 422

    huge_tool = [
        {
            "name": "big_tool",
            "description": "d",
            "parameters": {
                "type": "object",
                "properties": {"x": {"type": "string", "desc": "a" * (25 * 1024)}},
            },
        }
    ]
    r2 = client.post("/v1/chat", headers=headers, json={"messages": base_msgs, "tools": huge_tool})
    assert r2.status_code == 422

    for bad_name in ("", "bad-name", "bad name", "a" * 65):
        r = client.post(
            "/v1/chat",
            headers=headers,
            json={
                "messages": base_msgs,
                "tools": [{"name": bad_name, "description": "d", "parameters": {}}],
            },
        )
        assert r.status_code == 422

    r_desc = client.post(
        "/v1/chat",
        headers=headers,
        json={
            "messages": base_msgs,
            "tools": [{"name": "ok_tool", "description": "x" * 1025, "parameters": {}}],
        },
    )
    assert r_desc.status_code == 422

    r_skills = client.post(
        "/v1/chat",
        headers=headers,
        json={"messages": base_msgs, "skill_instructions": ["s"] * 9},
    )
    assert r_skills.status_code == 422
    r_skill_len = client.post(
        "/v1/chat",
        headers=headers,
        json={"messages": base_msgs, "skill_instructions": ["s" * 2001]},
    )
    assert r_skill_len.status_code == 422


@pytest.mark.asyncio
async def test_agentrouter_malformed_args_and_missing_id():
    class FakeCompletions:
        async def create(self, **kwargs):
            tc0 = SimpleNamespace(
                id=None,
                function=SimpleNamespace(name="get_vitals", arguments="{bad json"),
            )
            tc1 = SimpleNamespace(
                id="",
                function=SimpleNamespace(name="get_vitals", arguments='["not_an_object"]'),
            )
            msg = SimpleNamespace(content=None, tool_calls=[tc0, tc1])
            return SimpleNamespace(model="gemini-test", choices=[SimpleNamespace(message=msg)])

    fake_client = SimpleNamespace(chat=SimpleNamespace(completions=FakeCompletions()))
    provider = AgentRouterLLMProvider(
        base_url="https://example.invalid/v1",
        api_key="dummy",
        model="gemini-test",
        client=fake_client,
    )

    res = await provider.complete([ChatTurn(role="user", content="check")])
    assert res.reply == ""
    assert len(res.tool_calls) == 2
    assert res.tool_calls[0].id == "call_0"
    assert res.tool_calls[0].arguments == {}
    assert res.tool_calls[0].invalid_arguments is True
    assert res.tool_calls[1].id == "call_1"
    assert res.tool_calls[1].arguments == {}
    assert res.tool_calls[1].invalid_arguments is True
