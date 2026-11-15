# Deploying APOLO

Two pieces, deployed separately:

| Piece | What | Where | Config in repo |
|-------|------|-------|----------------|
| Frontend | Flutter web app (APOLO) | Vercel | `vercel.json`, `scripts/vercel-build.sh` |
| Backend | FastAPI gateway (LLM relay, STT, TTS) | Railway (any container host works) | `server/Dockerfile`, `server/railway.json` |

Deploy the **backend first**: the frontend build needs its public URL.

## 1. Backend (Railway)

1. New project -> *Deploy from GitHub repo* -> pick this repo.
2. Service settings -> **Root Directory** = `server` (Railway then picks up `server/Dockerfile` and `server/railway.json`).
3. Give the service **at least 2 GB RAM** (faster-whisper `base` + Kokoro run in one process; keep `--workers 1`).
4. Variables (never commit these):

   | Variable | Value |
   |----------|-------|
   | `LLM_PROVIDER` | `agentrouter` |
   | `AGENTROUTER_BASE_URL` | `https://generativelanguage.googleapis.com/v1beta/openai` |
   | `AGENTROUTER_MODEL` | `gemini-3.5-flash-lite` |
   | `AGENTROUTER_API_KEY` | your Gemini API key |
   | `APP_API_KEYS` | a long random key (this is what the frontend sends) |
   | `ALLOWED_ORIGINS` | the Vercel URL, e.g. `https://apolo.vercel.app` (comma-separated for several) |
   | `RATE_LIMIT_PER_MIN` | `30` |

   `STT_PROVIDER`, `TTS_PROVIDER` and the model paths already default correctly inside the image.
5. Networking -> *Generate Domain*. Check `https://<domain>/health` returns `{"status":"ok", ...}`.

The first build is slow (~1 GB of model downloads: Kokoro, Piper, Whisper `base`). The container then runs without internet for voice.

## 2. Frontend (Vercel)

1. *Add New Project* -> import this repo (root directory = repo root; framework preset **Other**).
2. Environment variables (Production + Preview):

   | Variable | Value |
   |----------|-------|
   | `ASTRAMED_API_URL` | the Railway URL from step 1.5 (no trailing slash) |
   | `ASTRAMED_API_KEY` | one of the gateway's `APP_API_KEYS` |

3. Deploy. `scripts/vercel-build.sh` clones Flutter 3.50.0, then runs `flutter build web --release`; output goes to `build/web`.
4. Go back to Railway and set `ALLOWED_ORIGINS` to the final Vercel domain, then redeploy the gateway (CORS blocks the browser otherwise).

The mic only works over HTTPS, which both platforms provide.

## Known limits

- `ASTRAMED_API_KEY` is baked into the web bundle, so anyone can extract it. It is a soft gate; the real protection is `RATE_LIMIT_PER_MIN` and a spending cap on the Gemini key. Per-user auth is the next step for a public launch.
- Rate limiting is in-memory, so keep a single replica and a single worker.
- The Docker build has not been run locally (no Docker on the dev machine); the first Railway build is its first real test.
- Vercel's first build downloads the Flutter SDK (a few minutes); later builds are cached by Vercel.
