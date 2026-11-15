# Feature: Clinical Agent — Voice (STT/TTS) + Agent API
Objective: backend gateway (LLM via AgentRouter, STT, TTS) + Flutter client layer with offline fallback. Branch: `feat/clinical-agent-voice-api`.
Delivery: ask-on-risk. Runners: `uv run pytest` (server/), `flutter test` + `flutter analyze` (client).

## Specs

- **S1 — Scope (verbatim):** "por ahora solo quiero el tts, stt y la api, usaremos agentrouter para eso, para los tts y stt te lo dejo a eleccion, ten en cuenta que la idea final es desplegar esto."
  Non-goals now: agent canvas UI, sidebar redesign, tool-calling into modules 01–04, voice diary analysis, DONKI.
- **S2 — Architecture (design decision):** Thin client + stateless backend gateway.
  - API keys (AgentRouter) NEVER ship in the Flutter build; only the backend holds them.
  - Backend is stateless: no DB. Clinical data stays on-device (Hive); the client sends a context snapshot per request.
  - Offline-first preserved: when the gateway is unreachable, the client falls back to on-device STT/TTS (`speech_to_text`, `flutter_tts`) and reports the agent LLM as unavailable (no fake answers).
  - Backend layout (hexagonal): `server/app/domain` (ports + models), `server/app/adapters` (agentrouter LLM, faster-whisper STT, Piper TTS, fakes), `server/app/api` (routers), `server/app/core` (config, auth, errors, rate limit).
- **S3 — LLM via AgentRouter:** OpenAI-compatible chat completions. `AGENTROUTER_BASE_URL` default `https://agentrouter.org/v1`, `AGENTROUTER_API_KEY`, `AGENTROUTER_MODEL` (configurable, no hardcoded model in code beyond a documented default). System prompt lives server-side: clinical assistant for astronauts, replies in the user's language (default Spanish), short and voice-friendly, never presents itself as a substitute for flight surgeons, escalates red-flag symptoms.
- **S4 — STT (choice):** self-hosted `faster-whisper` (default model `base`, `int8`, CPU), lazy-loaded, provider port so it can be swapped (e.g. any OpenAI-compatible `/audio/transcriptions`) via `STT_PROVIDER`. Rationale: no third-party key, runs on a ship-side server without Earth link, deployable in one container.
- **S5 — TTS (choice):** self-hosted `piper-tts` with a Spanish voice (default `es_MX-claude-high` or closest available medium voice, configurable via `PIPER_VOICE`), voice downloaded at image build, provider port swappable via `TTS_PROVIDER`. Output WAV.
- **S6 — HTTP contract (shared by server and client, MUST match exactly):**
  - `GET /health` → `200 {"status":"ok","version":str,"providers":{"llm":str,"stt":str,"tts":str}}` (no auth).
  - `POST /v1/chat` JSON `{"messages":[{"role":"user"|"assistant","content":str}], "context": object|null, "stream": bool=false}`.
    - `stream=false` → `200 {"reply":str,"model":str}`.
    - `stream=true` → `text/event-stream`, events `data: {"delta":str}` repeated, then `data: {"done":true,"model":str}`; on upstream failure mid-stream `data: {"error":{"code":str,"message":str}}`.
    - Limits: max 40 messages, each content ≤ 4000 chars, context JSON ≤ 16 KB.
  - `POST /v1/stt` multipart: field `audio` (wav/webm/ogg/m4a/mp3, ≤ 10 MB), optional field `language` (default `es`) → `200 {"text":str,"language":str,"duration_s":number}`.
  - `POST /v1/tts` JSON `{"text":str (1..1000 chars),"voice":str|null}` → `200 audio/wav` bytes.
  - Errors (all endpoints): `{"error":{"code":str,"message":str}}` with codes `unauthorized` (401), `rate_limited` (429), `invalid_request` (422/400), `payload_too_large` (413), `upstream_unavailable` (502/503), `internal` (500). Never leak upstream keys or stack traces.
  - Auth: header `X-AstraMed-Key` checked (constant-time) against `APP_API_KEYS` (comma-separated). Required unless `AUTH_DISABLED=true` (dev only, logs a warning). Documented as a soft gate: a key embedded in a web build is extractable.
  - CORS from `ALLOWED_ORIGINS`. In-memory rate limit per key/IP (`RATE_LIMIT_PER_MIN`, default 30).
- **S7 — Deployable:** `server/Dockerfile` (python 3.12-slim, non-root, `PORT` env, single uvicorn process), `server/.env.example`, `server/README.md` with run/deploy steps (any container host: Render/Fly/Railway/Cloud Run). Flutter config via `--dart-define=ASTRAMED_API_URL=...` and `--dart-define=ASTRAMED_API_KEY=...`.
- **S8 — Flutter client layer:** `lib/features/agent/` with `domain/` (ports `AgentChatService`, `SpeechToTextService`, `TextToSpeechService`; models `ChatMessage`, `AgentReply`), `data/` (`AgentApiClient` over `http` implementing S6; remote STT/TTS adapters using `record` for capture and `audioplayers` for playback; local adapters over `speech_to_text`/`flutter_tts`; resilient wrappers: remote first, local fallback on network/5xx), `providers/` (Riverpod). Mic permissions for Android/iOS/macOS. No UI screen in this feature.
- **S9 — Tests:** server: pytest with fakes and mocked AgentRouter (no real network, no model downloads in tests) covering every S6 endpoint, auth, limits, error envelope, SSE framing. Client: `flutter test` with `package:http/testing` MockClient for every S6 call and fake adapters for fallback logic.

## Tasks

| ID | Specs | Route | Status | Commit |
|----|-------|-------|--------|--------|
| T1 | S2–S7, S9 (server) | delegated writer — parallel unit A (`server/`) | pending | — |
| T2 | S2, S6, S7, S8, S9 (client) | delegated writer — parallel unit B (`lib/features/agent/`, pubspec, platform perms) | done (RED observed; GREEN 38/38 agent, 82 full suite; analyze clean; web build ok) | see git log `feat(agent): add voice and agent API client layer` |
| T3 | S1–S9 | delegated independent verifier (Risk items 2 auth/keys, 5 deps/deploy) | pending | — |

Route evidence: Writer trigger (a) — two independent units, disjoint edit surfaces (Python service vs Flutter layer), each several files / 100+ lines, launched together; also explicitly requested by the user.

## Log

- **L1 (2026-11-14, user verbatim):** "Lee @Plan de Arquitectura Agente.md , vamos a crear una rama nueva y empezar a implementar el agente como tal, por ahora solo quiero el tts, stt y la api, usaremos agentrouter para eso, para los tts y stt te lo dejo a eleccion, ten en cuenta que la idea final es desplegar esto. Tu solo disena la arquitectura y como se va a hacer, despliega subagentes para hacerlo todo despues."
- **L2:** Evidence: AgentRouter is OpenAI-compatible at `https://agentrouter.org/v1`; audio endpoint support is unconfirmed → STT/TTS kept independent of AgentRouter. Local env: Python 3.14 + `uv` available; Flutter/Dart and Docker NOT installed (client checks need a scratch SDK; Docker build unverifiable locally).
- **L3:** Toolchain installed (Flutter 3.50.0/Dart 3.14.0 in ~/development/flutter, Android SDK, Chromium, udev). First T1/T2 workers stalled on environment setup (scratch SDK bootstrap, heavy voice deps); user asked to switch to `google/antigravity-gemini-4-hydrogen-medium`; first attempt HTTP 403, retry succeeded.
- **L4:** T2 done. Parent spot check `flutter test test/features/agent` → 38 passed. Generated plugin registrants (linux/macos/windows) changed by `pub get`, accepted. Open: flutter_tts web has Wasm interop warnings (JS build fine); native mic/speaker untested on hardware.
