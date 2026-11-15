#!/usr/bin/env bash
# Builds the Flutter web app for Vercel (Vercel images ship no Flutter SDK).
# Required env vars (Vercel project settings):
#   ASTRAMED_API_URL  public URL of the gateway, e.g. https://apolo-gateway.up.railway.app
#   ASTRAMED_API_KEY  one of the gateway's APP_API_KEYS
set -euo pipefail

FLUTTER_VERSION="${FLUTTER_VERSION:-3.50.0}"
FLUTTER_HOME="${FLUTTER_HOME:-$HOME/flutter-sdk}"

: "${ASTRAMED_API_URL:?Set ASTRAMED_API_URL in the Vercel project environment}"
: "${ASTRAMED_API_KEY:?Set ASTRAMED_API_KEY in the Vercel project environment}"

if ! command -v flutter >/dev/null 2>&1; then
  if [ ! -x "$FLUTTER_HOME/bin/flutter" ]; then
    git clone --depth 1 --branch "$FLUTTER_VERSION" \
      https://github.com/flutter/flutter.git "$FLUTTER_HOME"
  fi
  export PATH="$FLUTTER_HOME/bin:$PATH"
fi

flutter config --no-analytics >/dev/null 2>&1 || true
flutter pub get
flutter build web --release \
  --dart-define=ASTRAMED_API_URL="$ASTRAMED_API_URL" \
  --dart-define=ASTRAMED_API_KEY="$ASTRAMED_API_KEY"
