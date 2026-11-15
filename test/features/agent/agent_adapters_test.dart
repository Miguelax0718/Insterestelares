import 'dart:convert';
import 'dart:typed_data';

import 'package:astramed/features/agent/data/agent_api_client.dart';
import 'package:astramed/features/agent/data/local_speech_to_text_service.dart';
import 'package:astramed/features/agent/data/local_text_to_speech_service.dart';
import 'package:astramed/features/agent/data/remote_speech_to_text_service.dart';
import 'package:astramed/features/agent/data/remote_text_to_speech_service.dart';
import 'package:astramed/features/agent/data/wav_encoder.dart';
import 'package:astramed/features/agent/domain/agent_config.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class FakeAudioCapture implements AudioCapturePort {
  FakeAudioCapture(this.wavBytes);

  final Uint8List wavBytes;
  bool started = false;
  bool stopped = false;

  @override
  Future<bool> hasPermission() async => true;

  @override
  Future<void> start() async {
    started = true;
  }

  @override
  Future<Uint8List> stop() async {
    stopped = true;
    return wavBytes;
  }

  @override
  Future<void> cancel() async {}

  @override
  Future<void> dispose() async {}
}

class FakeAudioPlayback implements AudioPlaybackPort {
  final List<Uint8List> played = [];
  bool stopped = false;

  @override
  Future<void> playWav(Uint8List wavBytes) async {
    played.add(wavBytes);
  }

  @override
  Future<void> stop() async {
    stopped = true;
  }

  @override
  Future<void> dispose() async {}
}

class FakeSpeechDriver implements SpeechToTextDriver {
  String? lastLocale;
  late void Function(String words, bool isFinal) _onResult;

  @override
  Future<bool> initialize({
    void Function(String status)? onStatus,
    void Function(String error)? onError,
  }) async {
    return true;
  }

  @override
  Future<void> listen({
    required String localeId,
    required Duration listenFor,
    required void Function(String words, bool isFinal) onResult,
  }) async {
    lastLocale = localeId;
    _onResult = onResult;
  }

  void emitResult(String words, {bool isFinal = true}) {
    _onResult(words, isFinal);
  }

  @override
  Future<void> stop() async {}

  @override
  Future<void> cancel() async {}
}

class FakeTtsDriver implements TtsDriver {
  String? language;
  bool? awaitCompletion;
  final List<String> spoken = [];
  bool stopped = false;

  @override
  Future<void> awaitSpeakCompletion(bool awaitCompletion) async {
    this.awaitCompletion = awaitCompletion;
  }

  @override
  Future<void> setLanguage(String language) async {
    this.language = language;
  }

  @override
  Future<void> speak(String text) async {
    spoken.add(text);
  }

  @override
  Future<void> stop() async {
    stopped = true;
  }
}

void main() {
  test(
    'buildWavBytes writes valid 44-byte RIFF/WAVE header around PCM data',
    () {
      final pcm = Uint8List.fromList([1, 2, 3, 4]);
      final wav = buildWavBytes(pcm);

      expect(wav.length, 48);
      expect(ascii.decode(wav.sublist(0, 4)), 'RIFF');
      expect(ascii.decode(wav.sublist(8, 12)), 'WAVE');
      expect(ascii.decode(wav.sublist(12, 16)), 'fmt ');
      expect(ascii.decode(wav.sublist(36, 40)), 'data');
      expect(wav.sublist(44), pcm);
    },
  );

  test(
    'RemoteSpeechToTextService records WAV bytes and uploads to /v1/stt',
    () async {
      final wav = buildWavBytes(Uint8List.fromList([10, 20, 30, 40]));
      final capture = FakeAudioCapture(wav);
      final client = AgentApiClient(
        config: const AgentConfig(baseUrl: 'https://gw.test', apiKey: 'k'),
        client: MockClient((request) async {
          return http.Response(
            jsonEncode({
              'text': 'Dolor leve',
              'language': 'es',
              'duration_s': 1.1,
            }),
            200,
          );
        }),
      );

      final service = RemoteSpeechToTextService(
        client: client,
        capture: capture,
      );
      await service.startListening(language: 'es');
      final text = await service.stopListening();

      expect(capture.started, isTrue);
      expect(capture.stopped, isTrue);
      expect(text, 'Dolor leve');
    },
  );

  test(
    'RemoteTextToSpeechService fetches WAV and plays via AudioPlaybackPort',
    () async {
      final wavBytes = Uint8List.fromList([82, 73, 70, 70, 5, 6]);
      final playback = FakeAudioPlayback();
      final client = AgentApiClient(
        config: const AgentConfig(baseUrl: 'https://gw.test', apiKey: 'k'),
        client: MockClient((request) async {
          return http.Response.bytes(wavBytes, 200);
        }),
      );

      final service = RemoteTextToSpeechService(
        client: client,
        playback: playback,
      );
      await service.speak('Presión estable');

      expect(playback.played, [wavBytes]);
    },
  );

  test(
    'LocalSpeechToTextService defaults to English locale and returns speech',
    () async {
      final driver = FakeSpeechDriver();
      final service = LocalSpeechToTextService(driver: driver);

      final future = service.listen();
      await Future<void>.delayed(Duration.zero);
      driver.emitResult('Oxygen nominal');

      expect(await future, 'Oxygen nominal');
      expect(driver.lastLocale, 'en-US');
    },
  );

  test(
    'LocalTextToSpeechService configures English language and speaks',
    () async {
      final driver = FakeTtsDriver();
      final service = LocalTextToSpeechService(driver: driver);

      await service.speak('Check pulse');

      expect(driver.awaitCompletion, isTrue);
      expect(driver.language, 'en-US');
      expect(driver.spoken, ['Check pulse']);
    },
  );
}
