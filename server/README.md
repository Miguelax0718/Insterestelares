# AstraMed Clinical Voice Gateway

Stateless Python 3.12 FastAPI gateway providing clinical LLM chat (via AgentRouter), speech-to-text (`faster-whisper`), and text-to-speech (`piper-tts`) for the AstraMed Flutter client.

## Architecture

Hexagonal (ports & adapters) layout under `server/app/`:

- `domain/` — Core models (`ChatTurn`, `ChatResult`, `LLMStreamChunk`, `TranscriptionResult`), provider `Protocol` ports (`LLMProvider`, `STTProvider`, `TTSProvider`), and server-side clinical system prompt (`prompts.py`).
- `adapters/` — Concrete provider implementations:
  - `agentrouter_llm.py` — OpenAI-compatible client targeting `AGENTROUTER_BASE_URL` (supports non-streaming and SSE streaming).
  - `faster_whisper_stt.py` — Lazy-loaded `faster-whisper` (`base`, `int8`, CPU).
  - `piper_tts.py` — Lazy-loaded `piper-tts` producing `audio/wav` bytes.
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
| `TTS_PROVIDER` | `piper` | `piper` or `fake` |
| `AGENTROUTER_BASE_URL` | `https://agentrouter.org/v1` | OpenAI-compatible upstream base URL |
| `AGENTROUTER_API_KEY` | `""` | Upstream AgentRouter API key (server-side only) |
| `AGENTROUTER_MODEL` | `gpt-4o-mini` | Model identifier sent to AgentRouter |
| `LLM_TIMEOUT_S` | `30.0` | Upstream LLM request timeout in seconds |
| `WHISPER_MODEL` | `base` | `faster-whisper` model size |
| `WHISPER_COMPUTE_TYPE` | `int8` | CTranslate2 compute type (`int8`, `float32`, etc.) |
| `WHISPER_DEVICE` | `cpu` | Inference device (`cpu`, `cuda`) |
| `WHISPER_DOWNLOAD_ROOT` | `None` | Optional directory for Whisper model cache |
| `PIPER_VOICE` | `es_MX-claude-high` | Default Piper voice name |
| `PIPER_VOICES_DIR` | `/app/voices` | Directory containing `<voice>.onnx` and `.onnx.json` |

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

The `Dockerfile` uses `python:3.12-slim`, installs the `voice` optional extra (`faster-whisper` + `piper-tts`), downloads the Piper voice at build time, and runs a single `uvicorn` worker as a non-root user.

```bash
cd server
docker build -t astramed-gateway --build-arg PIPER_VOICE=es_MX-claude-high .
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
  -d '{"text": "Signos vitales dentro de rango nominal.", "voice": "es_MX-claude-high"}' \
  --output reply.wav
```
