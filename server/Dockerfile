# syntax=docker/dockerfile:1
FROM python:3.12-slim AS base

ARG PIPER_VOICE=en_US-lessac-medium
ARG KOKORO_RELEASE_URL=https://github.com/thewh1teagle/kokoro-onnx/releases/download/model-files-v1.1
ARG KOKORO_MODEL_FILE=kokoro-v1.0.onnx
ARG KOKORO_VOICES_FILE=voices-v1.0.bin

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    UV_COMPILE_BYTECODE=1 \
    UV_LINK_MODE=copy \
    PORT=8000 \
    TTS_PROVIDER=kokoro \
    PIPER_VOICE=${PIPER_VOICE} \
    PIPER_VOICES_DIR=/app/voices \
    KOKORO_MODEL_PATH=/app/models/kokoro/${KOKORO_MODEL_FILE} \
    KOKORO_VOICES_PATH=/app/models/kokoro/${KOKORO_VOICES_FILE} \
    KOKORO_VOICE=af_heart \
    KOKORO_SPEED=1.0 \
    KOKORO_LANG=en-us \
    WHISPER_DOWNLOAD_ROOT=/app/models

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    ffmpeg \
    libsndfile1 \
    && rm -rf /var/lib/apt/lists/*

COPY --from=ghcr.io/astral-sh/uv:0.11 /uv /uvx /usr/local/bin/

WORKDIR /app

# Install dependencies (including voice extra: faster-whisper + piper-tts + kokoro-onnx)
COPY pyproject.toml uv.lock .python-version ./
RUN uv sync --frozen --no-dev --extra voice

ENV PATH="/app/.venv/bin:$PATH"

# Download TTS & voice models at build time so the container runs offline
RUN mkdir -p "${PIPER_VOICES_DIR}" "${WHISPER_DOWNLOAD_ROOT}/kokoro" \
    && python -m piper.download_voices "${PIPER_VOICE}" --data-dir "${PIPER_VOICES_DIR}" \
    && python -c "import sys, urllib.request; urllib.request.urlretrieve(sys.argv[1], sys.argv[2]); urllib.request.urlretrieve(sys.argv[3], sys.argv[4])" \
       "${KOKORO_RELEASE_URL}/${KOKORO_MODEL_FILE}" "${KOKORO_MODEL_PATH}" \
       "${KOKORO_RELEASE_URL}/${KOKORO_VOICES_FILE}" "${KOKORO_VOICES_PATH}"

COPY app ./app

# Run as non-root user
RUN useradd --create-home --shell /usr/sbin/nologin astramed \
    && chown -R astramed:astramed /app
USER astramed

EXPOSE 8000

CMD ["sh", "-c", "exec uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-8000} --workers 1"]
