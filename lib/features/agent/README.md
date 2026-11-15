# Clinical Agent Client Layer

Client-side service layer for the AstraMed clinical voice and chat gateway.

## Purpose

Provides offline-first voice (STT/TTS) and LLM chat abstractions for AstraMed without embedding third-party LLM keys in the Flutter build. No UI screen is included in this module.

## Architecture Layers

- `domain/`: Platform-agnostic ports (`AgentChatService`, `SpeechToTextService`, `TextToSpeechService`), immutable models (`ChatMessage`, `AgentReply`, `AgentStreamEvent`, `HealthStatus`, `TranscriptionResult`), `AgentConfig`, and typed `AgentApiException` / `AgentUnavailableException`.
- `data/`:
  - `AgentApiClient` over `package:http` implementing `GET /health`, `POST /v1/chat` (blocking and SSE streaming), `POST /v1/stt` (multipart `audio`), and `POST /v1/tts` (WAV audio bytes).
  - Remote voice adapters: `RemoteSpeechToTextService` (captures PCM16 audio via `record`, wraps into RIFF/WAV bytes in memory, uploads to `/v1/stt`) and `RemoteTextToSpeechService` (plays `/v1/tts` WAV bytes via `audioplayers` `BytesSource`).
  - Local offline adapters: `LocalSpeechToTextService` (`speech_to_text`, English `en-US` default) and `LocalTextToSpeechService` (`flutter_tts`, English `en-US` default).
  - Resilient wrappers (`ResilientAgentChatService`, `ResilientSpeechToTextService`, `ResilientTextToSpeechService`) implementing remote-first + offline fallback rules.
- `providers/`: Riverpod providers (`agentConfigProvider`, `httpClientProvider`, `agentApiClientProvider`, `agentChatServiceProvider`, `speechToTextServiceProvider`, `textToSpeechServiceProvider`, `agentHealthProvider`) wired for dependency injection and test overrides.

## Configuration (`--dart-define`)

`AgentConfig.fromEnvironment()` reads compile-time Dart defines:

```bash
flutter run \
  --dart-define=ASTRAMED_API_URL=https://your-gateway.example.com \
  --dart-define=ASTRAMED_API_KEY=your-app-client-key
```

`ASTRAMED_API_KEY` is sent in the `X-AstraMed-Key` request header on `/v1/*` endpoints (`/health` is unauthenticated).

## Fallback Behavior

- **STT & TTS**: Remote gateway is attempted first when `ASTRAMED_API_URL` is configured. On network errors, timeouts, `5xx` responses, `upstream_unavailable`, or unconfigured `ASTRAMED_API_URL`, calls fall back transparently to on-device `speech_to_text` / `flutter_tts`. Auth (`401 unauthorized`) and validation (`422 invalid_request`, `413 payload_too_large`, `429 rate_limited`) errors are surfaced directly without falling back.
- **Chat**: There is no on-device LLM. When `ASTRAMED_API_URL` is unconfigured or the gateway is unreachable / returns `5xx` / `upstream_unavailable`, `ResilientAgentChatService` throws `AgentUnavailableException` rather than fabricating clinical guidance. Client/auth errors (`401`, `422`, `429`) are surfaced as `AgentApiException`.
