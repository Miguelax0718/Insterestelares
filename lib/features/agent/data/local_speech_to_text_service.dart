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

class LocalSpeechToTextService implements SpeechToTextService {
  LocalSpeechToTextService({
    SpeechToTextDriver? driver,
    this.defaultLocale = 'en-US',
  }) : _driver = driver ?? DeviceSpeechToTextDriver();

  final SpeechToTextDriver _driver;
  final String defaultLocale;

  bool _initialized = false;
  bool _listening = false;
  String _latestTranscript = '';
  Completer<String>? _pendingCompleter;

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
      onStatus: (status) {
        if ((status == 'done' || status == 'notListening') &&
            _pendingCompleter != null &&
            !_pendingCompleter!.isCompleted) {
          _listening = false;
          _pendingCompleter!.complete(_latestTranscript);
        }
      },
      onError: (_) {
        if (_pendingCompleter != null && !_pendingCompleter!.isCompleted) {
          _listening = false;
          _pendingCompleter!.complete(_latestTranscript);
        }
      },
    );
    return _initialized;
  }

  @override
  Future<bool> isAvailable() => _ensureInitialized();

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
  Future<void> dispose() => cancel();
}
