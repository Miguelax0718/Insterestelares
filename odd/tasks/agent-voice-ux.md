# Feature: Agent voice UX — natural TTS, calm proactive alerts, hands-free listening
Objective: make the agent feel natural to talk to. Branch: `feat/clinical-agent-core` (continues on it; user authorized pushing in several commits).
Delivery: ask-on-risk. Runners: `server/.venv/bin/python -m pytest -q` + `ruff check .` (server); `~/development/flutter/bin/flutter test` + `flutter analyze` (client).

## Specs

- **S1 — Natural voice (verbatim):** "Que sea una voz mas natural, menos robotica, evaluemos opciones gratis."
  Free/open, self-hostable, offline-capable candidates to evaluate on this machine (CPU): Kokoro-82M (Apache-2.0, e.g. `kokoro-onnx`), higher-quality Piper voices (e.g. `en_US-amy-medium`, `en_US-ryan-high`, `en_US-libritts_r-medium`), and the browser/OS voices already reachable through the on-device fallback (`flutter_tts`). Online-only services that need an account or violate offline-first are reported but not adopted. Deliverable: an evaluation table (license, size, CPU latency for a ~15-word sentence, subjective naturalness, offline) in `server/README.md`, plus the chosen engine wired as a new `TTSProvider` selectable via `TTS_PROVIDER` without breaking `piper`/`fake`. Default language English (`en`), per earlier user decision "quedemonos con ingles".
- **S2 — Calm proactive alerts (verbatim):** "Al abrir el panel del agente, empieza a hablar demasiado por todas las alertas, debe ser algo mas natural."
  Opening the panel must not trigger a burst of spoken alerts. Rules: (a) critical events are still spoken immediately (safety, deterministic); (b) non-critical events raised together are coalesced into at most ONE short spoken line (e.g. "Two things need a look when you have a moment: X and Y.") and the rest stay visible/silent; (c) the same event (astronaut + kind) is not spoken again within its cooldown, including across panel reopen; (d) a global speech budget: no more than one non-critical spoken proactive line per 2 minutes; (e) non-critical proactive turns do not each call the LLM — one coalesced turn at most.
- **S3 — Hands-free active listening (verbatim):** "Debe ser un modo tipo escucha activa, al hablar sin tener q undir el boton del mic."
  A hands-free mode (toggle, on by default in the agent panel once mic permission is granted) where the mic stays open and voice activity detection (energy-based over the PCM16 stream already captured by `record`) detects speech start and end (end after ~800 ms of silence, min utterance ~400 ms, max ~15 s), sends the utterance to STT, and submits it to the agent automatically. The mic is paused while the agent is speaking (no self-transcription) and resumes after TTS finishes. Manual push-to-talk keeps working. Empty/noise-only utterances are discarded silently. Works on web and Android.
- **S4 — Replaceable visuals:** UI additions (hands-free toggle, listening indicator) go through the existing component/widget registry conventions so the frontend designer can restyle them (same rule as `odd/tasks/clinical-agent-core.md` S7).
- **S5 — Tests:** every rule above is covered through public interfaces (server pytest with fakes, no model downloads in tests; client flutter tests with fake capture/TTS/clock).

## Tasks

| ID | Specs | Route | Status | Commit |
|----|-------|-------|--------|--------|
| T1 | S1, S5 | delegated writer A — server TTS (`server/**`) | done (RED observed; 67 passed; ruff clean; live gateway switched to kokoro: cold 2.1 s, warm 0.46 s) | `95bda32` |
| T2 | S2, S5 | delegated writer B — proactive pacing (`lib/features/05_clinical_triage/agent/proactive_monitor.dart`, orchestrator `handleProactiveEvent`, tests) | done (RED observed; 31 passed; shared `proactiveAlertStoreProvider` wiring pending until T3 releases `agent_providers.dart`) | see git log `feat(agent): coalesce proactive alerts...` |
| T3 | S3, S4, S5 | delegated writer C — hands-free listening (STT data layer, VAD, canvas mic UI, providers, tests) | done (RED observed; 120 agent tests; web release build ok; live mic untested headless) | see git log `feat(agent): add hands-free listening...` |

Route evidence: Writer trigger (a) — three independent units with disjoint edit surfaces, each several files / 100+ lines, launched together; user asked for subagents.

## Log

- **L1 (2026-11-15, user verbatim):** "Necesitamos: 1. Que sea una voz mas natural, menos robotica, evaluemos opciones gratis. 2. Al abrir el panel del agente, empieza a hablar demasiado por todas las alertas, debe ser algo mas natural. 3. Debe ser un modo tipo escucha activa, al hablar sin tener q undir el boton del mic. Despliega los subagentes necesarios"
- **L2:** Context: gateway uses Gemini `gemini-3.5-flash-lite`, STT faster-whisper `base` (en), TTS Piper `en_US-lessac-medium`; panel = `AgentCanvasView`; `proactiveMonitorProvider` watched in both `main.dart` and `agent_canvas_view.dart`; non-critical proactive events each run an LLM turn with `speakReply: true` (cause of the burst).
- **L3:** T1 Kokoro-82M `af_heart` adopted (1.0 s avg CPU; live gateway cold 2.1 s / warm 0.46 s); `.env` + `.env.example` switched by parent. T2 coalesced digest + cooldown + 2-min budget, zero LLM calls for non-critical. T3 energy VAD (20 ms frames, 800 ms silence end, 400 ms min, 15 s max, 300 ms pre-roll), TTS speaking gate + 250 ms cooldown, local continuous fallback. Parent applied T2's shared `proactiveAlertStoreProvider` wiring in `agent_providers.dart` after T3 finished; full suite 241 passed (+3 pre-existing skips). Open: provider-level test of the shared store not added; real mic/echo behavior needs a browser/phone test.
