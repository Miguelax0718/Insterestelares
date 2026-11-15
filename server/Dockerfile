# syntax=docker/dockerfile:1
FROM python:3.12-slim AS base

ARG PIPER_VOICE=es_MX-claude-high

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    UV_COMPILE_BYTECODE=1 \
    UV_LINK_MODE=copy \
    PORT=8000 \
    PIPER_VOICE=${PIPER_VOICE} \
    PIPER_VOICES_DIR=/app/voices \
    WHISPER_DOWNLOAD_ROOT=/app/models

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    ffmpeg \
    libsndfile1 \
    && rm -rf /var/lib/apt/lists/*

COPY --from=ghcr.io/astral-sh/uv:0.11 /uv /uvx /usr/local/bin/

WORKDIR /app

# Install dependencies (including voice extra: faster-whisper + piper-tts)
COPY pyproject.toml uv.lock .python-version ./
RUN uv sync --frozen --no-dev --extra voice

ENV PATH="/app/.venv/bin:$PATH"

# Download Piper voice model at build time so the container runs offline
RUN mkdir -p "${PIPER_VOICES_DIR}" "${WHISPER_DOWNLOAD_ROOT}" \
    && python -m piper.download_voices "${PIPER_VOICE}" --data-dir "${PIPER_VOICES_DIR}"

COPY app ./app

# Run as non-root user
RUN useradd --create-home --shell /usr/sbin/nologin astramed \
    && chown -R astramed:astramed /app
USER astramed

EXPOSE 8000

CMD ["sh", "-c", "exec uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-8000} --workers 1"]
