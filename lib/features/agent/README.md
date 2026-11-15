# Clinical Agent Client Layer

Client-side service layer for the AstraMed clinical voice and chat gateway.

## Purpose

Provides offline-first voice (STT/TTS) and LLM chat abstractions for AstraMed without embedding third-party LLM keys in the Flutter build. No UI screen is included in this module.

## Architecture Layers

- `domain/`: Platform-agnostic ports (`AgentChatService`, `SpeechToTextService`, `TextToSpeechService`, `TtsSpeakingSignal`, `ContinuousSpeechToTextService`), immutable models (`ChatMessage`, `AgentReply`, `AgentStreamEvent`, `HealthStatus`, `TranscriptionResult`), `AgentConfig`, and typed `AgentApiException` / `AgentUnavailableException`.
- `data/`:
  - `AgentApiClient` over `package:http` implementing `GET /health`, `POST /v1/chat` (blocking and SSE streaming), `POST /v1/stt` (multipart `audio`), and `POST /v1/tts` (WAV audio bytes).
  - Remote voice adapters: `RemoteSpeechToTextService` (captures PCM16 audio via `record` for push-to-talk and exposes a raw 16 kHz mono PCM16 stream via `AudioCapturePort.startPcmStream()` for VAD, wrapping utterances into RIFF/WAV bytes via `buildWavBytes` and uploading to `/v1/stt`) and `RemoteTextToSpeechService` (plays `/v1/tts` WAV bytes via `audioplayers` `BytesSource` with completion tracking in providers).
  - `VoiceActivityDetector`: Pure-Dart energy-based VAD over PCM16 frames with adaptive noise-floor tracking, emitting `VadSpeechStart` and `VadSpeechEnd`.
  - Local offline adapters: `LocalSpeechToTextService` (`speech_to_text`, English `en-US` default, supporting push-to-talk and `ContinuousSpeechToTextService` restart loop) and `LocalTextToSpeechService` (`flutter_tts`, English `en-US` default).
  - Resilient wrappers (`ResilientAgentChatService`, `ResilientSpeechToTextService`, `ResilientTextToSpeechService`, `SpeakingTrackedTextToSpeechService`) implementing remote-first + offline fallback rules and TTS speaking-state signaling.
- `application/`:
  - `HandsFreeController`: Always-on capture loop (`capture stream -> VAD -> buildWavBytes -> STT -> agent submit`), exposing `HandsFreeStatus` (`off`, `listening`, `hearingSpeech`, `transcribing`, `pausedWhileSpeaking`, `permissionDenied`, `error`), local continuous STT fallback, and manual push-to-talk pause/resume coordination.
- `presentation/`:
  - `AgentCanvasView`, `AgentComponentWidgetRegistry`, and `hands_free_widgets.dart` (`HandsFreeToggleViewModel` / `listening_indicator` replaceable via `componentWidgetOverridesProvider` using ids `'hands_free_toggle'` and `'listening_indicator'`).
- `providers/`: Riverpod providers (`agentConfigProvider`, `httpClientProvider`, `agentApiClientProvider`, `audioCapturePortProvider`, `agentChatServiceProvider`, `speechToTextServiceProvider`, `textToSpeechServiceProvider`, `trackedTextToSpeechProvider`, `handsFreeControllerProvider`, `agentHealthProvider`) wired for dependency injection and test overrides.

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

## Hands-Free Active Listening & VAD

`AgentCanvasView` enables hands-free listening by default once microphone permission is granted (falling back visibly to manual push-to-talk if permission is denied). Manual push-to-talk remains active and temporarily pauses hands-free capture while held.

### VAD Parameters (`VadConfig`)

- **Format**: 16 kHz, 16-bit signed little-endian mono PCM (`20 ms` frames = 320 samples / 640 bytes).
- **Pre-roll**: `300 ms` circular ring buffer prepended at speech onset so initial syllables are preserved.
- **Onset confirmation**: `2` consecutive above-threshold frames (`40 ms`) and `minUtteranceDuration = 400 ms` before emitting `VadSpeechStart` (short clicks/coughs under `400 ms` are ignored).
- **End-of-speech silence**: `800 ms` trailing silence emits `VadSpeechEnd` (trimmed to `200 ms` tail padding).
- **Max utterance cut**: `15 s` continuous speech forces `VadSpeechEnd` so uploads stay bounded.
- **Adaptive noise floor**: EMA-tracked during non-speech (`initialNoiseFloorDb = -55.0 dBFS`, clamped `[-75.0, -35.0]`), threshold `max(-45.0, noiseFloorDb + 10.0)` dBFS.
- **Transcript filtering**: Empty, whitespace, punctuation-only (`...`), and blank markers (`[BLANK_AUDIO]`, `(silence)`) are discarded silently without submitting to the agent.

### Echo Avoidance

- **TTS speaking gate**: `trackedTextToSpeechProvider` wraps `textToSpeechServiceProvider` in `SpeakingTrackedTextToSpeechService` (`TtsSpeakingSignal`). While `isSpeaking` is `true`—and during a `250 ms` `postSpeakCooldown` after TTS finishes—`HandsFreeController` drops incoming PCM frames and resets the VAD (or stops/restarts `LocalSpeechToTextService` continuous listening) to prevent self-transcription.
- **Remote playback completion**: `remoteTextToSpeechProvider` uses `_CompletionAwareAudioPlayback` so `RemoteTextToSpeechService.speak()` awaits `AudioPlayer` completion/stop instead of returning at playback start.
- **Platform AEC/NS**: `RecordAudioCapture` configures `RecordConfig(echoCancel: true, noiseSuppress: true)` on `record`. Browser/WebRTC and Android hardware AEC availability varies by device, so the TTS speaking gate remains the primary echo safeguard.
