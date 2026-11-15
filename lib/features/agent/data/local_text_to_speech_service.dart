import 'package:flutter_tts/flutter_tts.dart';

import '../domain/agent_ports.dart';

abstract interface class TtsDriver {
  Future<void> setLanguage(String language);
  Future<void> awaitSpeakCompletion(bool awaitCompletion);
  Future<void> speak(String text);
  Future<void> stop();
}

class DeviceTtsDriver implements TtsDriver {
  DeviceTtsDriver({this._plugin});

  FlutterTts? _plugin;

  FlutterTts get _instance => _plugin ??= FlutterTts();

  @override
  Future<void> setLanguage(String language) async {
    await _instance.setLanguage(language);
  }

  @override
  Future<void> awaitSpeakCompletion(bool awaitCompletion) async {
    await _instance.awaitSpeakCompletion(awaitCompletion);
  }

  @override
  Future<void> speak(String text) async {
    await _instance.speak(text);
  }

  @override
  Future<void> stop() async {
    final plugin = _plugin;
    if (plugin != null) {
      await plugin.stop();
    }
  }
}

class LocalTextToSpeechService implements TextToSpeechService {
  LocalTextToSpeechService({TtsDriver? driver, this.defaultLanguage = 'en-US'})
    : _driver = driver ?? DeviceTtsDriver();

  final TtsDriver _driver;
  final String defaultLanguage;
  bool _configured = false;

  @override
  Future<void> speak(
    String text, {
    String? voice,
    String language = 'en-US',
  }) async {
    if (!_configured) {
      await _driver.awaitSpeakCompletion(true);
      _configured = true;
    }
    final targetLanguage = language.trim().isEmpty ? defaultLanguage : language;
    await _driver.setLanguage(targetLanguage);
    await _driver.speak(text);
  }

  @override
  Future<void> stop() => _driver.stop();

  @override
  Future<void> dispose() => _driver.stop();
}
