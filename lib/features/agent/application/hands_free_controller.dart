import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/network_error.dart';
import '../data/remote_speech_to_text_service.dart';
import '../data/voice_activity_detector.dart';
import '../data/wav_encoder.dart';
import '../domain/agent_exception.dart';
import '../domain/agent_ports.dart';

enum HandsFreeStatus {
  off,
  listening,
  hearingSpeech,
  transcribing,
  pausedWhileSpeaking,
  permissionDenied,
  error,
}

class HandsFreeState {
  const HandsFreeState({
    this.enabled = false,
    this.status = HandsFreeStatus.off,
    this.usingLocalFallback = false,
    this.supported = true,
    this.lastEnergyDb,
    this.errorMessage,
  });

  final bool enabled;
  final HandsFreeStatus status;
  final bool usingLocalFallback;
  final bool supported;
  final double? lastEnergyDb;
  final String? errorMessage;

  bool get isActive =>
      status == HandsFreeStatus.listening ||
      status == HandsFreeStatus.hearingSpeech ||
      status == HandsFreeStatus.transcribing ||
      status == HandsFreeStatus.pausedWhileSpeaking;

  bool get permissionDenied => status == HandsFreeStatus.permissionDenied;

  HandsFreeState copyWith({
    bool? enabled,
    HandsFreeStatus? status,
    bool? usingLocalFallback,
    bool? supported,
    double? lastEnergyDb,
    bool clearLastEnergyDb = false,
    String? errorMessage,
    bool clearErrorMessage = false,
  }) {
    return HandsFreeState(
      enabled: enabled ?? this.enabled,
      status: status ?? this.status,
      usingLocalFallback: usingLocalFallback ?? this.usingLocalFallback,
      supported: supported ?? this.supported,
      lastEnergyDb: clearLastEnergyDb
          ? null
          : (lastEnergyDb ?? this.lastEnergyDb),
      errorMessage: clearErrorMessage
          ? null
          : (errorMessage ?? this.errorMessage),
    );
  }
}

enum _BackendMode { none, remotePcm, localContinuous }

/// Manages always-on hands-free voice capture:
/// PCM stream -> [VoiceActivityDetector] -> WAV encoding -> STT -> agent submit,
/// with automatic pause/gating while TTS is speaking and local continuous STT fallback.
class HandsFreeController extends StateNotifier<HandsFreeState> {
  HandsFreeController({
    this._capture,
    this._transcribeRemoteWav,
    this._localContinuousStt,
    this._isRemoteConfigured = false,
    this._speakingSignal,
    required this._onTranscript,
    VoiceActivityDetector? vad,
    this.language = 'en',
    this.postSpeakCooldown = const Duration(milliseconds: 250),
    DateTime Function()? clock,
  }) : _vad = vad ?? VoiceActivityDetector(),
       _clock = clock ?? (() => DateTime.now().toUtc()),
       super(const HandsFreeState()) {
    _isSpeaking = _speakingSignal?.isSpeaking ?? false;
    _speakingSub = _speakingSignal?.isSpeakingStream.listen(
      _handleSpeakingChange,
    );
  }

  final AudioCapturePort? _capture;
  final Future<String> Function(Uint8List wavBytes, {String language})?
  _transcribeRemoteWav;
  final ContinuousSpeechToTextService? _localContinuousStt;
  final bool _isRemoteConfigured;
  final TtsSpeakingSignal? _speakingSignal;
  final FutureOr<void> Function(String transcript) _onTranscript;
  final VoiceActivityDetector _vad;
  final String language;
  final Duration postSpeakCooldown;
  final DateTime Function() _clock;

  StreamSubscription<Uint8List>? _pcmSub;
  StreamSubscription<bool>? _speakingSub;
  Timer? _cooldownTimer;

  _BackendMode _mode = _BackendMode.none;
  bool _initialized = false;
  bool _disposed = false;
  bool _isSpeaking = false;
  bool _processingUtterance = false;
  bool _pausedForManual = false;
  bool _wasEnabledBeforeManual = false;
  DateTime? _lastTtsEndedAt;

  bool get _hasAnyBackend =>
      (_isRemoteConfigured &&
          _capture != null &&
          _transcribeRemoteWav != null) ||
      _localContinuousStt != null;

  bool get _inPostSpeakCooldown {
    final ended = _lastTtsEndedAt;
    if (ended == null || postSpeakCooldown <= Duration.zero) {
      return false;
    }
    return _clock().difference(ended) < postSpeakCooldown;
  }

  bool get _isGatedBySpeech => _isSpeaking || _inPostSpeakCooldown;

  /// Auto-enables hands-free mode on startup if supported and mic permission
  /// is granted; falls back cleanly to manual mode otherwise.
  Future<void> initialize() async {
    if (_initialized || _disposed) {
      return;
    }
    _initialized = true;
    if (!_hasAnyBackend) {
      _setState(
        const HandsFreeState(
          enabled: false,
          status: HandsFreeStatus.off,
          supported: false,
        ),
      );
      return;
    }
    await setEnabled(true);
  }

  Future<void> toggle() => setEnabled(!state.enabled);

  Future<void> setEnabled(bool enabled) async {
    if (_disposed) {
      return;
    }
    if (!enabled) {
      _wasEnabledBeforeManual = false;
      _setState(
        state.copyWith(
          enabled: false,
          status: HandsFreeStatus.off,
          usingLocalFallback: false,
          clearLastEnergyDb: true,
          clearErrorMessage: true,
        ),
      );
      await _stopCapture();
      return;
    }

    if (!_hasAnyBackend) {
      _setState(
        state.copyWith(
          enabled: false,
          status: HandsFreeStatus.error,
          supported: false,
          errorMessage: 'Hands-free voice capture is unavailable.',
        ),
      );
      return;
    }

    _pausedForManual = false;
    await _startCapture();
  }

  Future<void> pauseForManualInput() async {
    if (_disposed || _pausedForManual) {
      return;
    }
    _wasEnabledBeforeManual = state.enabled;
    if (!state.enabled) {
      return;
    }
    _pausedForManual = true;
    _setState(
      state.copyWith(
        enabled: false,
        status: HandsFreeStatus.off,
        clearLastEnergyDb: true,
      ),
    );
    await _stopCapture();
  }

  Future<void> resumeAfterManualInput() async {
    if (_disposed) {
      return;
    }
    _pausedForManual = false;
    if (_wasEnabledBeforeManual) {
      _wasEnabledBeforeManual = false;
      await setEnabled(true);
    }
  }

  Future<void> stop() => setEnabled(false);

  Future<void> _startCapture() async {
    if (_isRemoteConfigured &&
        _capture != null &&
        _transcribeRemoteWav != null) {
      final startedRemote = await _tryStartRemotePcm();
      if (startedRemote || _disposed) {
        return;
      }
      if (state.status == HandsFreeStatus.permissionDenied) {
        return;
      }
    }

    await _tryStartLocalContinuous();
  }

  Future<bool> _tryStartRemotePcm() async {
    final capture = _capture!;
    try {
      final permitted = await capture.hasPermission();
      if (!permitted) {
        _setPermissionDenied();
        return false;
      }

      final stream = await capture.startPcmStream();
      if (_disposed) {
        await capture.stopPcmStream();
        return false;
      }

      _vad.reset();
      await _pcmSub?.cancel();
      _pcmSub = stream.listen(
        _onPcmChunk,
        onError: (Object err, StackTrace _) {
          unawaited(_handleRemoteStreamFailure(err));
        },
      );

      _mode = _BackendMode.remotePcm;
      _isSpeaking = _speakingSignal?.isSpeaking ?? _isSpeaking;
      _setState(
        state.copyWith(
          enabled: true,
          status: _isGatedBySpeech
              ? HandsFreeStatus.pausedWhileSpeaking
              : HandsFreeStatus.listening,
          usingLocalFallback: false,
          supported: true,
          clearErrorMessage: true,
        ),
      );
      return true;
    } catch (e) {
      if (_isPermissionError(e)) {
        _setPermissionDenied();
        return false;
      }
      if (_localContinuousStt == null) {
        _setState(
          state.copyWith(
            enabled: false,
            status: HandsFreeStatus.error,
            errorMessage: 'Unable to start microphone stream: $e',
          ),
        );
      }
      return false;
    }
  }

  Future<bool> _tryStartLocalContinuous({String? remoteFailureReason}) async {
    final local = _localContinuousStt;
    if (local == null) {
      _setState(
        state.copyWith(
          enabled: false,
          status: HandsFreeStatus.error,
          errorMessage:
              remoteFailureReason ?? 'Voice transcription is unavailable.',
        ),
      );
      return false;
    }

    try {
      final available = await local.isAvailable();
      if (!available) {
        if (_capture != null) {
          try {
            final permitted = await _capture.hasPermission();
            if (!permitted) {
              _setPermissionDenied();
              return false;
            }
          } catch (_) {
            // Fall through to generic unavailable error below.
          }
        }
        _setState(
          state.copyWith(
            enabled: false,
            status: HandsFreeStatus.error,
            errorMessage:
                remoteFailureReason ??
                'On-device speech recognition is unavailable.',
          ),
        );
        return false;
      }

      _mode = _BackendMode.localContinuous;
      _isSpeaking = _speakingSignal?.isSpeaking ?? _isSpeaking;

      if (_isGatedBySpeech) {
        _setState(
          state.copyWith(
            enabled: true,
            status: HandsFreeStatus.pausedWhileSpeaking,
            usingLocalFallback: true,
            supported: true,
            clearErrorMessage: true,
          ),
        );
        return true;
      }

      await local.startContinuous(
        language: language,
        onTranscript: _onLocalTranscript,
        onError: _onLocalError,
      );
      if (_disposed) {
        await local.stopContinuous();
        return false;
      }

      _setState(
        state.copyWith(
          enabled: true,
          status: HandsFreeStatus.listening,
          usingLocalFallback: true,
          supported: true,
          clearErrorMessage: true,
        ),
      );
      return true;
    } catch (e) {
      if (_isPermissionError(e)) {
        _setPermissionDenied();
      } else {
        _setState(
          state.copyWith(
            enabled: false,
            status: HandsFreeStatus.error,
            errorMessage: 'Voice input failed: $e',
          ),
        );
      }
      return false;
    }
  }

  void _onPcmChunk(Uint8List chunk) {
    if (_disposed ||
        !state.enabled ||
        _pausedForManual ||
        _mode != _BackendMode.remotePcm) {
      return;
    }

    if (_isGatedBySpeech) {
      _vad.reset();
      if (state.status != HandsFreeStatus.pausedWhileSpeaking &&
          !_processingUtterance) {
        _setState(state.copyWith(status: HandsFreeStatus.pausedWhileSpeaking));
      }
      return;
    }

    if (_processingUtterance) {
      return;
    }

    if (state.status == HandsFreeStatus.pausedWhileSpeaking) {
      _setState(state.copyWith(status: HandsFreeStatus.listening));
    }

    final events = _vad.process(chunk);
    for (final event in events) {
      switch (event) {
        case VadSpeechStart(:final energyDb):
          _setState(
            state.copyWith(
              status: HandsFreeStatus.hearingSpeech,
              lastEnergyDb: energyDb,
            ),
          );
        case VadSpeechEnd(:final pcmBytes):
          unawaited(_handleUtterance(pcmBytes));
      }
    }
  }

  Future<void> _handleUtterance(Uint8List pcmBytes) async {
    if (_disposed || !state.enabled || _pausedForManual) {
      return;
    }
    final transcribe = _transcribeRemoteWav;
    if (transcribe == null) {
      return;
    }

    _processingUtterance = true;
    _setState(
      state.copyWith(
        status: HandsFreeStatus.transcribing,
        clearLastEnergyDb: true,
      ),
    );

    try {
      final wavBytes = buildWavBytes(
        pcmBytes,
        sampleRate: _vad.config.sampleRate,
        channels: 1,
        bitsPerSample: 16,
      );
      final transcript = await transcribe(wavBytes, language: language);
      if (_disposed || !state.enabled || _pausedForManual) {
        return;
      }

      final cleaned = _normalizeTranscript(transcript);
      if (cleaned == null) {
        _setState(
          state.copyWith(
            status: _isGatedBySpeech
                ? HandsFreeStatus.pausedWhileSpeaking
                : HandsFreeStatus.listening,
          ),
        );
        return;
      }

      _setState(
        state.copyWith(
          status: _isGatedBySpeech
              ? HandsFreeStatus.pausedWhileSpeaking
              : HandsFreeStatus.listening,
        ),
      );
      await _onTranscript(cleaned);
    } catch (e) {
      if (_disposed || !state.enabled) {
        return;
      }
      await _handleRemoteUtteranceError(e);
    } finally {
      _processingUtterance = false;
      if (!_disposed &&
          state.enabled &&
          !_pausedForManual &&
          state.status == HandsFreeStatus.transcribing) {
        _setState(
          state.copyWith(
            status: _isGatedBySpeech
                ? HandsFreeStatus.pausedWhileSpeaking
                : HandsFreeStatus.listening,
          ),
        );
      }
    }
  }

  Future<void> _handleRemoteUtteranceError(Object error) async {
    if (error is AgentApiException && !error.isFallbackEligible) {
      await _stopCapture();
      if (_disposed) return;
      _setState(
        state.copyWith(
          enabled: false,
          status: HandsFreeStatus.error,
          errorMessage: error.message,
        ),
      );
      return;
    }

    if (isFallbackEligibleError(error)) {
      await _stopRemotePcmOnly();
      if (_disposed) return;
      await _tryStartLocalContinuous(
        remoteFailureReason: 'Remote STT failed and local STT is unavailable.',
      );
      return;
    }

    await _stopCapture();
    if (_disposed) return;
    _setState(
      state.copyWith(
        enabled: false,
        status: HandsFreeStatus.error,
        errorMessage: 'Voice transcription failed: $error',
      ),
    );
  }

  Future<void> _handleRemoteStreamFailure(Object error) async {
    if (_disposed || !state.enabled) {
      return;
    }
    if (_isPermissionError(error)) {
      await _stopCapture();
      if (_disposed) return;
      _setPermissionDenied();
      return;
    }
    await _stopRemotePcmOnly();
    if (_disposed) return;
    await _tryStartLocalContinuous(
      remoteFailureReason: 'Audio stream interrupted: $error',
    );
  }

  void _onLocalTranscript(String transcript) {
    if (_disposed || !state.enabled || _pausedForManual || _isGatedBySpeech) {
      return;
    }
    final cleaned = _normalizeTranscript(transcript);
    if (cleaned == null) {
      return;
    }
    unawaited(Future.sync(() => _onTranscript(cleaned)));
  }

  void _onLocalError(Object error) {
    if (_disposed || !state.enabled) {
      return;
    }
    _mode = _BackendMode.none;
    if (_isPermissionError(error)) {
      _setPermissionDenied();
      return;
    }
    _setState(
      state.copyWith(
        enabled: false,
        status: HandsFreeStatus.error,
        errorMessage: 'Voice recognition error: $error',
      ),
    );
  }

  void _handleSpeakingChange(bool speaking) {
    if (_disposed) {
      return;
    }
    _isSpeaking = speaking;
    _cooldownTimer?.cancel();
    _cooldownTimer = null;
    _vad.reset();

    if (!state.enabled || _pausedForManual) {
      return;
    }

    if (speaking) {
      _setState(
        state.copyWith(
          status: HandsFreeStatus.pausedWhileSpeaking,
          clearLastEnergyDb: true,
        ),
      );
      if (_mode == _BackendMode.localContinuous) {
        unawaited(_localContinuousStt?.stopContinuous());
      }
      return;
    }

    _lastTtsEndedAt = _clock();
    if (postSpeakCooldown <= Duration.zero) {
      _resumeAfterCooldown();
    } else {
      _cooldownTimer = Timer(postSpeakCooldown, _resumeAfterCooldown);
    }
  }

  void _resumeAfterCooldown() {
    if (_disposed || !state.enabled || _pausedForManual || _isSpeaking) {
      return;
    }
    if (_mode == _BackendMode.localContinuous) {
      unawaited(
        _localContinuousStt
            ?.startContinuous(
              language: language,
              onTranscript: _onLocalTranscript,
              onError: _onLocalError,
            )
            .catchError(_onLocalError),
      );
    }
    if (!_processingUtterance) {
      _setState(state.copyWith(status: HandsFreeStatus.listening));
    }
  }

  Future<void> _stopRemotePcmOnly() async {
    final sub = _pcmSub;
    _pcmSub = null;
    _vad.reset();
    if (sub != null) {
      unawaited(sub.cancel());
    }
    if (_mode == _BackendMode.remotePcm) {
      _mode = _BackendMode.none;
      try {
        await _capture?.stopPcmStream();
      } catch (_) {
        // Ignore stop errors during teardown/fallback.
      }
    }
  }

  Future<void> _stopCapture() async {
    _cooldownTimer?.cancel();
    _cooldownTimer = null;
    await _stopRemotePcmOnly();
    if (_mode == _BackendMode.localContinuous) {
      _mode = _BackendMode.none;
      try {
        await _localContinuousStt?.stopContinuous();
      } catch (_) {
        // Ignore stop errors during teardown.
      }
    }
  }

  void _setPermissionDenied() {
    _mode = _BackendMode.none;
    _setState(
      state.copyWith(
        enabled: false,
        status: HandsFreeStatus.permissionDenied,
        usingLocalFallback: false,
        clearLastEnergyDb: true,
        errorMessage:
            'Microphone permission denied. Switched to manual push-to-talk.',
      ),
    );
  }

  bool _isPermissionError(Object error) {
    final msg = error.toString().toLowerCase();
    return msg.contains('permission') || msg.contains('notallowederror');
  }

  String? _normalizeTranscript(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    final lower = trimmed.toLowerCase();
    if (lower == '[blank_audio]' ||
        lower == '(silence)' ||
        lower == '[silence]') {
      return null;
    }
    // Discard punctuation/whitespace-only artifacts (e.g. "..." or "---").
    final hasWordChar = RegExp(
      r'[\p{L}\p{N}]',
      unicode: true,
    ).hasMatch(trimmed);
    if (!hasWordChar) {
      return null;
    }
    return trimmed;
  }

  void _setState(HandsFreeState next) {
    if (!_disposed) {
      state = next;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _cooldownTimer?.cancel();
    _cooldownTimer = null;
    unawaited(_pcmSub?.cancel());
    unawaited(_speakingSub?.cancel());
    if (_mode == _BackendMode.remotePcm) {
      unawaited(_capture?.stopPcmStream().catchError((_) {}));
    } else if (_mode == _BackendMode.localContinuous) {
      unawaited(_localContinuousStt?.stopContinuous().catchError((_) {}));
    }
    _mode = _BackendMode.none;
    super.dispose();
  }
}
