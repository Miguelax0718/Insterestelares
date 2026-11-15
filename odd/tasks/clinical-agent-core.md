# Feature: Clinical Agent Core — tools, memory, skills, proactive monitor, actions
Objective: turn the voice/chat gateway into a tool-using clinical agent covering every action in `Plan de Arquitectura Agente.md`, with UI injection points ready for the frontend designer's visuals. Branch: `feat/clinical-agent-core` (stacked on `feat/clinical-agent-voice-api`).
Delivery: ask-on-risk; user authorized pushing in several commits. Runners: `server/.venv/bin/python -m pytest -q` + `server/.venv/bin/ruff check .` (server, run from `server/`); `~/fvm/default/bin/flutter test` + `~/fvm/default/bin/flutter analyze` (client; Flutter 3.50.0 via fvm). Baseline: client 82 passed, analyze 19 pre-existing infos.

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

## Design (T0 decision)

**D1 — Tool loop runs on the client; the server is a stateless tool-calling relay.** Tools need on-device live data, memory and UI (S1, S3, S7) and must keep working offline (S9). Alternatives rejected: server-side loop with callbacks to the client (needs server state and a bidirectional channel, breaks S9); prompt-only JSON "tools" without native function calling (fragile with flash-lite, unvalidated arguments). Cost: each tool round is one more HTTP round-trip; mitigated by a hard cap of 6 tool rounds per user turn, after which the client asks for a final reply with `tools` omitted.

**D2 — Wire contract for `POST /v1/chat` (additive; existing clients keep working).**
- Request messages:
  - `{"role":"user","content":str}`
  - `{"role":"assistant","content":str|null,"tool_calls":[{"id":str,"name":str,"arguments":object}]}` (`tool_calls` optional; `content` may be null only when `tool_calls` is non-empty)
  - `{"role":"tool","tool_call_id":str,"content":str}` (content = JSON-encoded tool result, ≤4000 chars; `tool_call_id` must match a `tool_calls[].id` of an earlier assistant message, else 422 `invalid_request`)
  - `system` stays rejected.
- Request extras: `tools: [{"name":^[a-zA-Z0-9_]{1,64}$, "description":str≤1024, "parameters":object(JSON Schema)}]` (≤32, serialized ≤24 KB); `skill_instructions: [str]` (≤8, each ≤2000 chars); `context` unchanged (≤16 KB; client puts `live`, `memory`, `active_components` inside it).
- System message stays single and first: `CLINICAL_SYSTEM_PROMPT` + (when tools present) a short tool-use rule block + each skill instruction + the context snapshot. Same natural, brief tone (S6).
- Non-stream response: `{"reply":str, "model":str, "tool_calls":[{"id","name","arguments"}]}` — `tool_calls` defaults to `[]`, `reply` is `""` when the model only called tools.
- Stream: zero or more `{"delta":str}`, then zero or more `{"tool_call":{"id","name","arguments"}}` (server accumulates provider deltas per index and emits each call complete), then `{"done":true,"model":str}`. Errors unchanged.
- Model arguments that are not a JSON object → `arguments: {}` plus `"invalid_arguments": true` on that call. Missing provider id → server generates `call_<index>`.
- Server port widens: `LLMProvider.complete/stream(messages, tools=None)`; `ChatTurn` gains `tool_calls`/`tool_call_id`; `ChatResult.tool_calls`; `LLMStreamChunk.tool_call`.

**D3 — Client architecture (`lib/features/agent/`), dependencies point inward.**
- `domain/` (T1, contracts only, no Flutter widgets): wire models; `AgentTool{name, description, parameters, effect: read|ui|consequential, call(args, ToolContext) → ToolResult}`; `ToolContext{astronautId, read<T>(ProviderListenable<T>), ui: AgentUiSink, confirm: ConfirmationGate, audit: AuditLog, memory: MemoryStore, medication: MedicationSafety, now}`; `AgentSkill{id, instructions, tools, componentIds, triggers, alwaysOn, offlineFlow?}`; `SkillRegistry.select(SkillQuery) → List<AgentSkill>`; `AgentComponentEvent.show(id, props)/hide(id)`; `ComponentIds` catalog; `AgentViewModel` base; `MemoryEntry`/`MemoryStore`; `ConsequentialAction`/`ConfirmationGate`/`AuditEntry`/`AuditLog`; `MedicationRequest`/`MedicationCheck`/`MedicationSafety`; `ProactiveEvent`/`ProactiveRule`/`AgentNotifier`; `DeterministicFlow` (offline step machine: prompt → expected answers → next step / verdict).
- `application/` (T3): `AgentConversationController` (Riverpod `Notifier<AgentState>`): build context (live snapshot + memory), select skills, call gateway with `tools`/`skill_instructions`, execute tool calls (consequential ones only through `ConfirmationGate`, every consequential outcome written to `AuditLog`), apply UI events, cap 6 rounds; offline → run the matched skill's `DeterministicFlow` or reply that free chat is unavailable (S9). Default `SkillRegistry`, `ComponentRegistry`, core tools.
- `data/persistence/` (T4): Hive boxes storing JSON maps (no TypeAdapters, no typeIds): `agent_memory`, `agent_audit` (append-only), `agent_flags` (blocked EVA, flagged batches, pending checks).
- Clinical logic lives in each module (`lib/features/0X_*/agent/`), pure Dart, deterministic, unit-tested; each module exports `List<AgentSkill> <module>Skills()`.
- Clinical verdicts (thresholds, Graybiel score, LRM-50, SANS grade, renal risk, EVA readiness, medication safety) are computed only by deterministic code; tool results carry the verdict and the LLM only phrases it (S2, S8).
- Writes to crew vitals/telemetry go only through `CrewNotifier.applyTelemetryPacket` / `updateVitals` (crew_provider.dart:59-69, 409-432). Never re-implement `_evaluateClinicalTriage`.

**D4 — Headless UI contract (S7).** The agent emits `show_component(id, props)` / `hide_component(id)` (a core tool, plus side-effects from skill tools). `ComponentRegistry` maps `id → ComponentSpec{fromProps → typed AgentViewModel (validates, rejects unknown/invalid props), placeholderBuilder}`. Component ids: `vitals_card, telemetry_chart, crew_status, status_report, eva_readiness, alert_banner, space_weather_alert, pharmacy_batches, raman_request, medication_check, graybiel_questionnaire, pvt_test, mpt_test, sans_grid, sans_contrast, sans_focus, exercise_monitor, lbnp_ramp, ultrasound_guide, diary_recorder, recommendations, confirm_action`. Interactive components report results back through `AgentUiSink.submit(componentId, result)` so the designer's widget only needs the view-model + callback. Handoff doc: `docs/frontend/agent-components.md`.

**D5 — S5 capability map (skill → tools → components).**
| Capability | Skill id (module) | Tools | Components |
|---|---|---|---|
| core: live data, memory, UI | `core` (agent, always on) | `get_crew_overview`, `get_vitals`, `get_telemetry_series`, `recall_memory`, `save_memory`, `show_component`, `hide_component` | `crew_status`, `vitals_card`, `telemetry_chart` |
| status report | `status_report` (01) | `build_status_report` | `status_report` |
| on-demand telemetry | `telemetry` (01) | `get_radiation_dose`, `get_sleep_history`, `get_exercise_session`, `get_inventory` | `telemetry_chart` |
| artifact filtering | `artifact_filter` (01) | `classify_alarm_artifact` | `alert_banner` |
| cross-physiology correlation | `correlation` (01) | `assess_renal_stone_risk`, `correlate_subsystems` | `status_report`, `alert_banner` |
| space weather + astropharmacy | `space_weather` (02 + `pharmacy`) | `get_space_weather`, `assess_pharmacy_radiation`, `flag_batches`*, `request_raman_check`*, `schedule_leukocyte_count`* | `space_weather_alert`, `pharmacy_batches`, `raman_request` |
| medication safety | `medication` (`pharmacy`) | `check_medication` | `medication_check` |
| Graybiel | `graybiel` (03) | `start_graybiel`, `record_graybiel_answer`, `score_graybiel`, `change_medication_route`* | `graybiel_questionnaire` |
| SANS | `sans` (03) | `start_sans_test`, `classify_sans`, `assign_goggles`* | `sans_grid`, `sans_contrast`, `sans_focus` |
| exercise guidance | `exercise` (03) | `get_exercise_guidance` | `exercise_monitor` |
| LBNP + ultrasound | `procedures` (03) | `start_lbnp`, `advance_lbnp`, `abort_lbnp`, `start_ultrasound_guide` | `lbnp_ramp`, `ultrasound_guide` |
| PVT/MPT + LRM-50 + drug calibration | `cognition` (04) | `start_pvt`, `start_mpt`, `compute_lrm50`, `check_stimulant_dose`, `check_hypnotic_dose` | `pvt_test`, `mpt_test`, `medication_check` |
| voice diary + recommendations | `diary` (04) | `start_diary`, `analyze_diary`, `get_recommendations` | `diary_recorder`, `recommendations` |
| pre-EVA / landing readiness | `readiness` (05) | `evaluate_readiness`, `block_eva`* | `eva_readiness` |
| proactive monitor | (05, not a chat skill) | rules → `ProactiveEvent` → TTS + in-app alert + agent turn | `alert_banner` |
`*` = consequential: confirmation + audit (S8).

**D6 — Assumptions (marked, isolated as named constants for later clinical review).** A1: LRM-50 = median PVT reaction time (ms) over valid trials, with lapses (>500 ms) counted separately; fatigue when LRM-50 > 300 ms or lapses ≥ 3 (no source in `sources/`). A2: Graybiel diagnostic categories use the standard point scale (frank sickness ≥16, severe malaise 8–15, moderate 5–7, slight 3–4, minimal 1–2). A3: DONKI is fetched directly from `api.nasa.gov` only when online, with key from `--dart-define=NASA_API_KEY` (default `DEMO_KEY`), cached; offline uses the last cache or a bundled sample. A4: in-app alert + TTS for proactive notifications; OS notifications deferred (would need a new dependency). A5: medication inventory, allergies and storage shielding live in new assets under `DB/Pharmacy/`.

## Tasks

| ID | Specs | Route | Status | Commit |
|----|-------|-------|--------|--------|
| T0 | S1–S10 | inline (parent, software-architect; opus subagent denied by runtime) | done | (with T1) |
| T1 | S1,S2,S7,S8,S9 | inline (parent): domain contracts + client wire models/serialization for D2 | done | (this commit) |
| T2 | S3,S5,S9,S10 | delegated writer (parallel with T1): server tool-calling relay per D2 | done | 0e840e6 |
| T3 | S2,S3,S7,S9 | delegated writer (wave 2): agent runtime, registries, core tools | pending | — |
| T4 | S1,S8 | delegated writer (wave 2): Hive memory, audit log, flags, confirmation gate, session summary | pending | — |
| T5 | S5,S8 | delegated writer (wave 2): pharmacy + space weather (02) | pending | — |
| T6 | S5,S8 | delegated writer (wave 2): microgravity skills (03) | pending | — |
| T7 | S5,S8 | delegated writer (wave 2): mental-health skills (04) | pending | — |
| T8 | S3,S5 | delegated writer (wave 2): general-health skills (01) | pending | — |
| T9 | S4,S5,S9 | wave 3: readiness + proactive monitor (05) | pending | — |
| T10 | S7 | wave 3: agent canvas, component placeholders, crew sidebar, Hive init, main wiring, frontend handoff doc | pending | — |
| T11 | S8 | independent verifier: confirmation gate + medication safety (Risk item 2) | pending | — |

Shared files and owners: `pubspec.yaml`, `lib/main.dart`, `lib/features/agent/domain/**` → parent. Writers that need an asset path or contract change report it instead of editing.

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
- **L5 (user verbatim):** "usa los de gentle, para opus hazlo tu" — after the runtime denied the `opus-architect` subagent. T0 done inline by the parent; mapping delegated to two `gentle-ai-explore` runs (client + server); writers use `gentle-ai-worker`, verification `gentle-ai-verify`.
- **L6 (T0 evidence):** server has no tool support (`server/app/adapters/agentrouter_llm.py:54-56` sends only role/content; `schemas.py:27` role literal user|assistant). Client: no Hive init and no typeIds in use; crew writes funnel through `crew_provider.dart:59-69,409-432`; no engines exist for Graybiel/LRM-50/PVT/SANS/DONKI/inventory/triage. Flutter lives at `~/fvm/default/bin/flutter` on this machine.
