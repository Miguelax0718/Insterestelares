# Feature: Clinical Agent Core — tools, memory, skills, proactive monitor, actions
Objective: turn the voice/chat gateway into a tool-using clinical agent covering every action in `Plan de Arquitectura Agente.md`, with UI injection points ready for the frontend designer's visuals. Branch: `feat/clinical-agent-core` (stacked on `feat/clinical-agent-voice-api`).
Delivery: ask-on-risk; user authorized pushing in several commits. Runners: `server/.venv/bin/python -m pytest -q` + ruff (server); `~/development/flutter/bin/flutter test` + `flutter analyze` (client).

## Specs

- **S1 — Memory (verbatim):** "debe tener memoria ( por lo menos entre sesiones )". Design: on-device per-astronaut memory (stable facts, session summaries, clinical events) persisted in Hive; injected into context; agent tools `recall_memory`, `save_memory`; session summary generated at session close.
- **S2 — Skills (verbatim):** "debe tener skills". Design: a skill = instructions + tool set + deterministic clinical logic + UI component id. Deterministic rules own clinical verdicts (thresholds, Graybiel score, LRM-50, EVA readiness); the LLM converses and guides. Only relevant skills are loaded into the prompt.
- **S3 — Live data (verbatim):** "poder acceder a los datos en vivo". Design: read-only client-side tools over existing Riverpod providers / Hive (vitals, radiation, microgravity, sleep/mental, crew, telemetry machines, inventory) read at call time.
- **S4 — Proactive (verbatim):** "debe poder escribir el a ti si es necesario" — clarified by user: "el punto 4", i.e. an on-device monitor watches telemetry/thresholds/space weather/schedules and triggers an agent turn that speaks and notifies the astronaut. Critical alerts fire from deterministic rules even without the LLM.
- **S5 — All plan actions (verbatim):** "debe poder hacer todas las acciones mencinadas en el md". Every capability in `Plan de Arquitectura Agente.md` §3 maps to a skill/tool: status report, pre-EVA/landing readiness, on-demand telemetry, space weather + astropharmacy (DONKI, batch flagging, Raman request, leukocyte scheduling), cross-physiology correlation (e.g. renal stone risk), telemetry artifact filtering (accelerometry), Graybiel voice questionnaire, PVT/MPT + LRM-50 and drug calibration, SANS tests, exercise guidance, LBNP ramp and ultrasound guides, daily voice diary with semantic + acoustic indicators and adaptive recommendations.
- **S6 — Tone (verbatim):** "evitemos q haga microcopy o que sobre explique, que sea lo mas natural posible, luego definimos la personalidad pero por ahora eso." Done in server prompt (commit on parent branch); tool/skill instructions must keep the same tone.
- **S7 — Replaceable visuals (verbatim):** "le di una lista a mi frontend, entonces hagamos todo pero listo para reemplazar visual por lo de ella." Design: headless component contract — the agent emits `show_component(id, props)` / `hide_component(id)`; the client resolves ids through a component registry; every component has a typed props/view-model and a placeholder widget, so the designer swaps widgets without touching agent/skill logic. Documented in a frontend handoff doc.
- **S8 — Safety:** actions with consequences (blocking EVA, medication route/dose changes, flagging batches) require crew confirmation and are written to an audit log. Medication suggestions must be validated against inventory and allergies by deterministic logic (observed: model suggested a paracetamol dose without checks).
- **S9 — Offline:** without gateway, deterministic skill flows still run with on-device voice; free-form LLM chat reports unavailable (no fabricated answers). Server stays stateless.
- **S10 — Tests:** every rule above gets tests through public interfaces (server pytest with fakes; client flutter tests with fake providers/MockClient).

## Tasks

| ID | Specs | Route | Status | Commit |
|----|-------|-------|--------|--------|
| T0 | S1–S10 | opus-architect design (contracts, units, edit surfaces) | pending | — |
| T1+ | defined after T0 | parallel writers per independent unit | pending | — |

## Resume on another machine

1. `git fetch && git switch feat/clinical-agent-core` (stacked on `feat/clinical-agent-voice-api`, both pushed).
2. Server: `cd server && cp .env.example .env`, then set `AGENTROUTER_BASE_URL=https://generativelanguage.googleapis.com/v1beta/openai`, `AGENTROUTER_API_KEY=<Gemini key>`, `AGENTROUTER_MODEL=gemini-3.5-flash-lite`, `APP_API_KEYS=dev-local-key`, `ALLOWED_ORIGINS=*`. `.env` is gitignored: keys never go to git. For real voice: `uv sync --extra voice` (heavy download), then `STT_PROVIDER=faster-whisper`, `TTS_PROVIDER=piper`, and download the Piper voice locally (see `server/README.md`); otherwise use `fake`.
3. Run: `cd server && set -a && . ./.env && set +a && uv run uvicorn app.main:app --host 0.0.0.0 --port 8000`.
4. Phone (USB): `adb reverse tcp:8000 tcp:8000`, then `flutter run -d <id> --dart-define=ASTRAMED_API_URL=http://127.0.0.1:8000 --dart-define=ASTRAMED_API_KEY=dev-local-key`. The dev console opens from the waveform icon in the app bar.
5. Next step: run T0 (opus-architect) with this document, then launch the parallel writers it defines.

## Log

- **L1 (2026-11-14, user verbatim):** "vamos planeando las funciones para el agente, debe tener memoria ( por lo menos entre sesiones ) debe tener skills poder acceder a los datos en vivo, debe poder escribir el a ti si es necesario, y debe poder hacer todas las acciones mencinadas en el md"
- **L2 (user verbatim):** "el punto 4, ademas evitemos q haga microcopy o que sobre explique, que sea lo mas natural posible, luego definimos la personalidad pero por ahora eso. Ademas le di una lista a mi frontend, entonces hagamos todo pero listo para reemplazar visual por lo de ella. Despliega los subagentes necesarios"
- **L3 (user verbatim):** "ve pusheando todo en varios commits"
- **L4:** Prompt rewritten for natural brief replies; found Gemini OpenAI-compat honored only one system message → merged prompt+context into one (RED→GREEN, 31 passed). Parent branch pushed. LLM: Gemini `gemini-3.5-flash-lite` via `https://generativelanguage.googleapis.com/v1beta/openai` (AgentRouter rejected the key as unauthorized client).
