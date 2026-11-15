# AstraMed Clinical Voice Gateway

Stateless Python 3.12 FastAPI gateway providing clinical LLM chat (via AgentRouter), speech-to-text (`faster-whisper`), and text-to-speech (`kokoro-onnx` or `piper-tts`) for the AstraMed Flutter client.

## Architecture

Hexagonal (ports & adapters) layout under `server/app/`:

- `domain/` — Core models (`ChatTurn`, `ChatResult`, `LLMStreamChunk`, `TranscriptionResult`), provider `Protocol` ports (`LLMProvider`, `STTProvider`, `TTSProvider`), and server-side clinical system prompt (`prompts.py`).
- `adapters/` — Concrete provider implementations:
  - `agentrouter_llm.py` — OpenAI-compatible client targeting `AGENTROUTER_BASE_URL` (supports non-streaming and SSE streaming).
  - `faster_whisper_stt.py` — Lazy-loaded `faster-whisper` (`base`, `int8`, CPU).
  - `kokoro_tts.py` — Lazy-loaded `kokoro-onnx` (Kokoro-82M, 24 kHz) producing `audio/wav` bytes.
  - `piper_tts.py` — Lazy-loaded `piper-tts` (22.05 kHz) producing `audio/wav` bytes.
  - `fakes.py` — Deterministic in-memory fakes for tests and local development without keys or models.
- `api/` — HTTP routers and Pydantic contracts (`/health`, `/v1/chat`, `/v1/stt`, `/v1/tts`).
- `core/` — `pydantic-settings` configuration, constant-time `X-AstraMed-Key` auth, in-memory rate limiter, and uniform JSON error envelope handlers.

The gateway is **stateless** (no database). Clinical records remain on-device in the Flutter client, which sends a bounded JSON `context` snapshot (`<= 16 KB`) per `/v1/chat` request.

## Environment Variables

Copy `.env.example` to `.env` for local runs:

| Variable | Default | Description |
|---|---|---|
| `APP_VERSION` | `0.1.0` | Version reported by `GET /health` |
| `PORT` | `8000` | HTTP port used by the container entrypoint |
| `APP_API_KEYS` | `""` | Comma-separated valid values for `X-AstraMed-Key` |
| `AUTH_DISABLED` | `false` | Set `true` for local dev without keys (logs warning) |
| `ALLOWED_ORIGINS` | *(empty: no cross-origin access)* | Comma-separated CORS origins; `*` must be set explicitly to allow any origin |
| `RATE_LIMIT_PER_MIN` | `30` | In-memory requests/minute limit per API key or IP |
| `LLM_PROVIDER` | `agentrouter` | `agentrouter` or `fake` |
| `STT_PROVIDER` | `faster-whisper` | `faster-whisper` or `fake` |
| `TTS_PROVIDER` | `piper` | `kokoro`, `piper`, or `fake` |
| `AGENTROUTER_BASE_URL` | `https://agentrouter.org/v1` | OpenAI-compatible upstream base URL |
| `AGENTROUTER_API_KEY` | `""` | Upstream AgentRouter API key (server-side only) |
| `AGENTROUTER_MODEL` | `gpt-4o-mini` | Model identifier sent to AgentRouter |
| `LLM_TIMEOUT_S` | `30.0` | Upstream LLM request timeout in seconds |
| `WHISPER_MODEL` | `base` | `faster-whisper` model size |
| `WHISPER_COMPUTE_TYPE` | `int8` | CTranslate2 compute type (`int8`, `float32`, etc.) |
| `WHISPER_DEVICE` | `cpu` | Inference device (`cpu`, `cuda`) |
| `WHISPER_DOWNLOAD_ROOT` | `None` | Optional directory for Whisper model cache |
| `PIPER_VOICE` | `en_US-lessac-medium` | Default Piper voice name |
| `PIPER_VOICES_DIR` | `/app/voices` | Directory containing `<voice>.onnx` and `.onnx.json` |
| `KOKORO_MODEL_PATH` | `/app/models/kokoro/kokoro-v1.0.onnx` | Path to Kokoro ONNX model file |
| `KOKORO_VOICES_PATH` | `/app/models/kokoro/voices-v1.0.bin` | Path to Kokoro packed voice embeddings (`.bin`) |
| `KOKORO_VOICE` | `am_puck` | Default Kokoro voice adopted for APOLO (`am_puck`, `af_heart`, `af_bella`, `am_michael`, `bf_emma`, etc.) |
| `KOKORO_SPEED` | `1.0` | Kokoro speaking rate (`0.5`–`2.0`) |
| `KOKORO_LANG` | `en-us` | Fallback phonemizer language (`en-us` or `en-gb`; auto-selected for `af_`/`am_` vs `bf_`/`bm_` prefixes) |

## TTS Engine Evaluation & Switching

### Local CPU Evaluation

Benchmarked on CPU (AMD Ryzen 7 5700, 16 threads) using the 16-word clinical sentence:
`"Your heart rate is seventy-two and you slept seven hours, so you're good for the EVA."`
(average of 3 runs after a warm-up run):

| Engine / Voice | License | Download Size | CPU Latency (avg) | Offline | Naturalness & Notes | Status |
|---|---|---|---|---|---|---|
| **Kokoro-82M (`kokoro-onnx`, `kokoro-v1.0.onnx` fp32, `af_heart`)** | Apache-2.0 (weights) / MIT (`kokoro-onnx`) | 338 MiB (311 MiB + 27 MiB voices) | **1.012 s** (24 kHz) | Yes | Best — warm, expressive, human prosody; under 1.5 s budget (`af_bella`: 1.287 s, `am_michael`: 1.160 s) | **Adopted** |
| Kokoro-82M (`kokoro-v1.0.int8.onnx`, `af_heart`) | Apache-2.0 / MIT | 136 MiB (109 MiB + 27 MiB voices) | 1.809 s (24 kHz) | Yes | Very good, but slower than fp32 on x86 CPU (>1.5 s) and lower spectral fidelity | Not adopted |
| Piper (`en_US-ryan-high`) | GPL-3.0-or-later (`piper-tts`) | 116 MiB | 0.485 s (22.05 kHz) | Yes | Best Piper English voice, clear cadence, still slightly synthetic vs Kokoro | Fallback option |
| Piper (`en_US-amy-medium`) | GPL-3.0-or-later (`piper-tts`) | 61 MiB | 0.143 s (22.05 kHz) | Yes | Slightly warmer than `lessac`, noticeable VITS prosody flatness | Not adopted |
| Piper (`en_US-libritts_r-medium`) | GPL-3.0-or-later (`piper-tts`) | 75 MiB | 0.088 s (22.05 kHz) | Yes | Fast multi-speaker baseline, somewhat monotone | Not adopted |
| Piper (`en_US-lessac-medium`) | GPL-3.0-or-later (`piper-tts`) | 61 MiB | 0.138 s (22.05 kHz) | Yes | Previous default; robotic prosody | Replaced |
| Client OS/Browser (`flutter_tts`) | OS / Browser built-in | 0 MiB | < 0.1 s | OS-dependent | Robotic/inconsistent voices across Web and Android; remains client-side offline fallback | Client fallback |
| Edge TTS / ElevenLabs (free tier) | Proprietary / ToS | 0 MiB | Network-bound | **No** | Requires internet, accounts, or third-party ToS; breaks strict offline-first requirement | **Not adopted** |

> **Adopted APOLO default voice:** `am_puck` (young, playful male voice on Kokoro-82M fp32; selected over `af_heart` from the initial benchmark while keeping the same fp32 model and latency profile).

### Switching TTS Engines

To use **Kokoro-82M** locally (after running `uv sync --extra voice` and downloading `kokoro-v1.0.onnx` and `voices-v1.0.bin` into `server/models/kokoro/`):

```env
TTS_PROVIDER=kokoro
KOKORO_MODEL_PATH=models/kokoro/kokoro-v1.0.onnx
KOKORO_VOICES_PATH=models/kokoro/voices-v1.0.bin
KOKORO_VOICE=am_puck
KOKORO_SPEED=1.0
```

To switch back to **Piper** (for example `en_US-ryan-high` on low-RAM hosts):

```bash
cd server
.venv/bin/python -m piper.download_voices --download-dir voices en_US-ryan-high
```

```env
TTS_PROVIDER=piper
PIPER_VOICE=en_US-ryan-high
PIPER_VOICES_DIR=voices
```

To use deterministic **Fake** WAV bytes in dev/CI: `TTS_PROVIDER=fake`.

### Security Caveat: `X-AstraMed-Key` Soft Gate

`X-AstraMed-Key` protects the gateway against casual unauthenticated abuse, while keeping `AGENTROUTER_API_KEY` strictly on the server. However, any client key embedded via `--dart-define` in a Flutter web or mobile binary can be extracted from the client bundle. For production multi-user deployments, pair this gateway with per-user authentication/tokens and enforce tight `RATE_LIMIT_PER_MIN` and upstream spending caps.

## Local Development with `uv`

Install lightweight runtime + test dependencies (excludes heavy ML voice packages):

```bash
cd server
uv sync --python 3.12
```

Run tests and linter:

```bash
uv run pytest -q
uv run ruff check .
```

Run locally in fake/dev mode (no AgentRouter key or ML models needed):

```bash
AUTH_DISABLED=true LLM_PROVIDER=fake STT_PROVIDER=fake TTS_PROVIDER=fake \
  uv run uvicorn app.main:app --reload --port 8000
```

Run with real AgentRouter LLM + fake voice locally:

```bash
APP_API_KEYS=dev-key-123 AGENTROUTER_API_KEY=sk-... STT_PROVIDER=fake TTS_PROVIDER=fake \
  uv run uvicorn app.main:app --reload --port 8000
```

## Docker Build & Run

The `Dockerfile` uses `python:3.12-slim`, installs the `voice` optional extra (`faster-whisper` + `kokoro-onnx` + `piper-tts`), downloads the Kokoro-82M (`kokoro-v1.0.onnx` + `voices-v1.0.bin`) and Piper voices at build time, and runs a single `uvicorn` worker as a non-root user with `TTS_PROVIDER=kokoro` by default.

```bash
cd server
docker build -t astramed-gateway --build-arg PIPER_VOICE=en_US-lessac-medium .
docker run --rm -p 8000:8000 \
  -e APP_API_KEYS=your-client-key \
  -e AGENTROUTER_API_KEY=your-agentrouter-key \
  astramed-gateway
```

## Deploying to Container Hosts

Any container platform (Render, Fly.io, Railway, Google Cloud Run) works out of the box:

- Build context: `server/` (`server/Dockerfile`).
- Health check path: `GET /health` (returns HTTP 200 without auth).
- Port binding: the container honors `$PORT` automatically.
- Worker count: keep **1 worker** (`--workers 1`) so in-memory rate limiting and lazy-loaded STT/TTS models share one process memory space.
- Minimum memory recommendation: >= 1–2 GB RAM when running `faster-whisper` (`base`, `int8`) and `piper-tts` together.
- Secrets: set `AGENTROUTER_API_KEY` and `APP_API_KEYS` in the host's secret manager (never commit `.env`).

## Chat API Contract (`POST /v1/chat`)

`POST /v1/chat` is a stateless relay supporting client-executed tool calling:

- **`messages`**: up to 40 turns (`role`: `"user"`, `"assistant"`, or `"tool"`; `"system"` is rejected).
  - `"assistant"` turns may include `tool_calls: [{"id": str, "name": str, "arguments": object}]`, and `content` may be `null` only when `tool_calls` is non-empty.
  - `"tool"` turns carry `tool_call_id` (must match an earlier assistant `tool_calls[].id`, else `422 invalid_request`) and `content` (<= 4000 chars).
- **`tools`** *(optional)*: up to 32 tool definitions (`name` matching `^[a-zA-Z0-9_]{1,64}$`, `description` <= 1024 chars, `parameters` JSON Schema object; serialized total <= 24 KB). When present, the server appends concise tool-use rules to the single system message.
- **`skill_instructions`** *(optional)*: up to 8 strings (each <= 2000 chars) appended to the single system message.
- **`context`** *(optional)*: JSON object (<= 16 KB) appended to the single system message.
- **Non-stream response** (`stream: false`): `{"reply": str, "model": str, "tool_calls": [{"id": str, "name": str, "arguments": object}]}`. `tool_calls` defaults to `[]`, and `reply` is `""` when the model only calls tools. If upstream tool arguments are not a JSON object, `arguments` is `{}` and `"invalid_arguments": true` is included on that call.
- **Stream events** (`stream: true`, `text/event-stream`): zero or more `data: {"delta": str}`, followed by zero or more `data: {"tool_call": {"id": str, "name": str, "arguments": object[, "invalid_arguments": true]}}`, ending with `data: {"done": true, "model": str}` (or `data: {"error": {"code": str, "message": str}}` on failure).

## Endpoint Examples (`curl`)

### Health (`GET /health`)

```bash
curl -s http://localhost:8000/health
```

### Chat Non-Streaming (`POST /v1/chat`)

```bash
curl -s -X POST http://localhost:8000/v1/chat \
  -H "Content-Type: application/json" \
  -H "X-AstraMed-Key: dev-key-123" \
  -d '{
    "messages": [{"role": "user", "content": "Tengo mareo leve despues de ejercicio."}],
    "context": {"heart_rate_bpm": 88, "mission_day": 14},
    "stream": false
  }'
```

### Chat Streaming SSE (`POST /v1/chat` with `stream: true`)

```bash
curl -N -X POST http://localhost:8000/v1/chat \
  -H "Content-Type: application/json" \
  -H "X-AstraMed-Key: dev-key-123" \
  -d '{
    "messages": [{"role": "user", "content": "Resume mi estado actual"}],
    "stream": true
  }'
```

### Speech-to-Text (`POST /v1/stt`)

```bash
curl -s -X POST http://localhost:8000/v1/stt \
  -H "X-AstraMed-Key: dev-key-123" \
  -F "audio=@sample.wav" \
  -F "language=es"
```

### Text-to-Speech (`POST /v1/tts`)

```bash
curl -s -X POST http://localhost:8000/v1/tts \
  -H "Content-Type: application/json" \
  -H "X-AstraMed-Key: dev-key-123" \
  -d '{"text": "Vital signs within nominal range."}' \
  --output reply.wav
```
