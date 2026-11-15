import 'dart:async';

import 'package:speech_to_text/speech_to_text.dart';

import '../domain/agent_ports.dart';

abstract interface class SpeechToTextDriver {
  Future<bool> initialize({
    void Function(String status)? onStatus,
    void Function(String error)? onError,
  });

  Future<void> listen({
    required String localeId,
    required Duration listenFor,
    required void Function(String words, bool isFinal) onResult,
  });

  Future<void> stop();

  Future<void> cancel();
}

class DeviceSpeechToTextDriver implements SpeechToTextDriver {
  DeviceSpeechToTextDriver({this._plugin});

  SpeechToText? _plugin;

  SpeechToText get _instance => _plugin ??= SpeechToText();

  @override
  Future<bool> initialize({
    void Function(String status)? onStatus,
    void Function(String error)? onError,
  }) {
    return _instance.initialize(
      onStatus: onStatus,
      onError: onError == null ? null : (err) => onError(err.errorMsg),
    );
  }

  @override
  Future<void> listen({
    required String localeId,
    required Duration listenFor,
    required void Function(String words, bool isFinal) onResult,
  }) {
    return _instance.listen(
      onResult: (result) =>
          onResult(result.recognizedWords, result.finalResult),
      listenOptions: SpeechListenOptions(
        localeId: localeId,
        listenFor: listenFor,
        partialResults: true,
        cancelOnError: true,
      ),
    );
  }

  @override
  Future<void> stop() async {
    final plugin = _plugin;
    if (plugin != null) {
      await plugin.stop();
    }
  }

  @override
  Future<void> cancel() async {
    final plugin = _plugin;
    if (plugin != null) {
      await plugin.cancel();
    }
  }
}

class LocalSpeechToTextService
    implements SpeechToTextService, ContinuousSpeechToTextService {
  LocalSpeechToTextService({
    SpeechToTextDriver? driver,
    this.defaultLocale = 'en-US',
    this.continuousRestartDelay = const Duration(milliseconds: 150),
  }) : _driver = driver ?? DeviceSpeechToTextDriver();

  final SpeechToTextDriver _driver;
  final String defaultLocale;
  final Duration continuousRestartDelay;

  bool _initialized = false;
  bool _listening = false;
  String _latestTranscript = '';
  Completer<String>? _pendingCompleter;

  bool _continuousActive = false;
  String _continuousLanguage = 'en';
  String _continuousLatestTranscript = '';
  bool _continuousEmittedCycle = false;
  Timer? _continuousRestartTimer;
  void Function(String transcript)? _onContinuousTranscript;
  void Function(Object error)? _onContinuousError;

  String _resolveLocale(String language) {
    final trimmed = language.trim();
    if (trimmed.isEmpty || trimmed == 'en') {
      return defaultLocale;
    }
    if (trimmed == 'es') {
      return 'es-ES';
    }
    return trimmed;
  }

  Future<bool> _ensureInitialized() async {
    if (_initialized) return true;
    _initialized = await _driver.initialize(
      onStatus: _handleDriverStatus,
      onError: _handleDriverError,
    );
    return _initialized;
  }

  void _handleDriverStatus(String status) {
    if (status != 'done' && status != 'notListening') {
      return;
    }
    if (_continuousActive) {
      final pending = _continuousLatestTranscript.trim();
      if (!_continuousEmittedCycle && pending.isNotEmpty) {
        _continuousEmittedCycle = true;
        _onContinuousTranscript?.call(pending);
      }
      _scheduleContinuousRestart();
      return;
    }
    if (_pendingCompleter != null && !_pendingCompleter!.isCompleted) {
      _listening = false;
      _pendingCompleter!.complete(_latestTranscript);
    }
  }

  void _handleDriverError(String error) {
    if (_continuousActive) {
      final lower = error.toLowerCase();
      final isBenignTimeout =
          lower.contains('no_match') ||
          lower.contains('speech_timeout') ||
          lower.contains('timeout');
      if (isBenignTimeout) {
        _scheduleContinuousRestart();
      } else {
        _continuousActive = false;
        _continuousRestartTimer?.cancel();
        _onContinuousError?.call(StateError('On-device STT error: $error'));
      }
      return;
    }
    if (_pendingCompleter != null && !_pendingCompleter!.isCompleted) {
      _listening = false;
      _pendingCompleter!.complete(_latestTranscript);
    }
  }

  void _scheduleContinuousRestart() {
    if (!_continuousActive) {
      return;
    }
    _continuousRestartTimer?.cancel();
    _continuousRestartTimer = Timer(continuousRestartDelay, () {
      if (_continuousActive) {
        unawaited(_startContinuousCycle());
      }
    });
  }

  Future<void> _startContinuousCycle() async {
    if (!_continuousActive) {
      return;
    }
    _continuousLatestTranscript = '';
    _continuousEmittedCycle = false;
    try {
      await _driver.listen(
        localeId: _resolveLocale(_continuousLanguage),
        listenFor: const Duration(seconds: 30),
        onResult: (words, isFinal) {
          if (!_continuousActive) return;
          _continuousLatestTranscript = words;
          if (isFinal) {
            final trimmed = words.trim();
            if (trimmed.isNotEmpty) {
              _continuousEmittedCycle = true;
              _onContinuousTranscript?.call(trimmed);
            }
          }
        },
      );
    } catch (e) {
      if (_continuousActive) {
        _continuousActive = false;
        _onContinuousError?.call(e);
      }
    }
  }

  @override
  Future<bool> isAvailable() => _ensureInitialized();

  @override
  Future<void> startContinuous({
    String language = 'en',
    required void Function(String transcript) onTranscript,
    void Function(Object error)? onError,
  }) async {
    final ok = await _ensureInitialized();
    if (!ok) {
      throw StateError('On-device speech recognition is unavailable.');
    }
    _continuousRestartTimer?.cancel();
    _continuousLanguage = language;
    _onContinuousTranscript = onTranscript;
    _onContinuousError = onError;
    _continuousActive = true;
    await _startContinuousCycle();
  }

  @override
  Future<void> stopContinuous() async {
    _continuousActive = false;
    _continuousRestartTimer?.cancel();
    _continuousRestartTimer = null;
    _onContinuousTranscript = null;
    _onContinuousError = null;
    await _driver.stop();
  }

  @override
  Future<void> startListening({String language = 'en'}) async {
    final ok = await _ensureInitialized();
    if (!ok) {
      throw StateError('On-device speech recognition is unavailable.');
    }
    _latestTranscript = '';
    _listening = true;
    _pendingCompleter = Completer<String>();
    await _driver.listen(
      localeId: _resolveLocale(language),
      listenFor: const Duration(seconds: 30),
      onResult: (words, isFinal) {
        _latestTranscript = words;
        if (isFinal &&
            _pendingCompleter != null &&
            !_pendingCompleter!.isCompleted) {
          _listening = false;
          _pendingCompleter!.complete(words);
        }
      },
    );
  }

  @override
  Future<String> stopListening() async {
    if (!_listening) {
      return _latestTranscript;
    }
    _listening = false;
    await _driver.stop();
    if (_pendingCompleter != null && !_pendingCompleter!.isCompleted) {
      _pendingCompleter!.complete(_latestTranscript);
    }
    return _latestTranscript;
  }

  @override
  Future<String> listen({
    String language = 'en',
    Duration maxDuration = const Duration(seconds: 15),
  }) async {
    final ok = await _ensureInitialized();
    if (!ok) {
      throw StateError('On-device speech recognition is unavailable.');
    }
    _latestTranscript = '';
    _listening = true;
    final completer = Completer<String>();
    _pendingCompleter = completer;

    await _driver.listen(
      localeId: _resolveLocale(language),
      listenFor: maxDuration,
      onResult: (words, isFinal) {
        _latestTranscript = words;
        if (isFinal && !completer.isCompleted) {
          _listening = false;
          completer.complete(words);
        }
      },
    );

    try {
      return await completer.future.timeout(
        maxDuration,
        onTimeout: () async {
          await _driver.stop();
          _listening = false;
          return _latestTranscript;
        },
      );
    } finally {
      _pendingCompleter = null;
      _listening = false;
    }
  }

  @override
  Future<void> cancel() async {
    _listening = false;
    await _driver.cancel();
    if (_pendingCompleter != null && !_pendingCompleter!.isCompleted) {
      _pendingCompleter!.complete('');
    }
  }

  @override
  Future<void> dispose() async {
    await stopContinuous();
    await cancel();
  }
}
