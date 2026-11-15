import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:astramed/features/agent/application/hands_free_controller.dart';
import 'package:astramed/features/agent/data/remote_speech_to_text_service.dart';
import 'package:astramed/features/agent/domain/agent_exception.dart';
import 'package:astramed/features/agent/domain/agent_ports.dart';
import 'package:flutter_test/flutter_test.dart';

Uint8List _silencePcm(int durationMs) =>
    Uint8List((16000 * durationMs ~/ 1000) * 2);

Uint8List _tonePcm(int durationMs, {int amplitude = 7000}) {
  final sampleCount = 16000 * durationMs ~/ 1000;
  final data = ByteData(sampleCount * 2);
  for (var i = 0; i < sampleCount; i++) {
    final s = (amplitude * math.sin(2 * math.pi * 440 * i / 16000)).round();
    data.setInt16(i * 2, s, Endian.little);
  }
  return data.buffer.asUint8List();
}

class _FakePcmCapture implements AudioCapturePort {
  _FakePcmCapture({this.permitted = true});

  bool permitted;
  bool streamStarted = false;
  bool streamStopped = false;
  StreamController<Uint8List>? _controller;

  @override
  Future<bool> hasPermission() async => permitted;

  @override
  Future<void> start() async {}

  @override
  Future<Uint8List> stop() async => Uint8List(0);

  @override
  Future<void> cancel() async {}

  @override
  Future<void> dispose() async {
    await _controller?.close();
  }

  @override
  Future<Stream<Uint8List>> startPcmStream() async {
    if (!permitted) {
      throw const AgentApiException(
        code: AgentErrorCode.unknown,
        message: 'Microphone permission denied.',
      );
    }
    streamStarted = true;
    streamStopped = false;
    _controller = StreamController<Uint8List>.broadcast();
    return _controller!.stream;
  }

  @override
  Future<void> stopPcmStream() async {
    streamStopped = true;
    await _controller?.close();
    _controller = null;
  }

  void emitPcm(Uint8List bytes) {
    _controller?.add(bytes);
  }
}

class _FakeSpeakingSignal implements TtsSpeakingSignal {
  bool _speaking = false;
  final StreamController<bool> _controller = StreamController<bool>.broadcast();

  @override
  bool get isSpeaking => _speaking;

  @override
  Stream<bool> get isSpeakingStream => _controller.stream;

  void setSpeaking(bool value) {
    _speaking = value;
    _controller.add(value);
  }

  Future<void> dispose() => _controller.close();
}

class _FakeLocalContinuousStt implements ContinuousSpeechToTextService {
  _FakeLocalContinuousStt({this.available = true});

  bool available;
  bool started = false;
  bool stopped = false;
  void Function(String transcript)? _onTranscript;
  void Function(Object error)? _onError;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<void> startContinuous({
    String language = 'en',
    required void Function(String transcript) onTranscript,
    void Function(Object error)? onError,
  }) async {
    if (!available) {
      throw StateError('Local STT unavailable');
    }
    started = true;
    stopped = false;
    _onTranscript = onTranscript;
    _onError = onError;
  }

  @override
  Future<void> stopContinuous() async {
    stopped = true;
  }

  void emitTranscript(String text) => _onTranscript?.call(text);
  void emitError(Object err) => _onError?.call(err);
}

void main() {
  group('HandsFreeController', () {
    test('utterance triggers one STT call with WAV and one submit', () async {
      final capture = _FakePcmCapture();
      final speaking = _FakeSpeakingSignal();
      addTearDown(speaking.dispose);

      final sttCalls = <Uint8List>[];
      final submitted = <String>[];
      var now = DateTime.utc(2026, 11, 15, 12, 0, 0);

      final controller = HandsFreeController(
        capture: capture,
        isRemoteConfigured: true,
        transcribeRemoteWav: (wavBytes, {language = 'en'}) async {
          sttCalls.add(wavBytes);
          return 'Check crew vitals';
        },
        speakingSignal: speaking,
        onTranscript: (text) async => submitted.add(text),
        clock: () => now,
      );
      addTearDown(controller.dispose);

      await controller.initialize();
      expect(controller.state.enabled, isTrue);
      expect(controller.state.status, HandsFreeStatus.listening);
      expect(capture.streamStarted, isTrue);

      capture.emitPcm(_silencePcm(400));
      capture.emitPcm(_tonePcm(600));
      await Future<void>.delayed(Duration.zero);
      expect(controller.state.status, HandsFreeStatus.hearingSpeech);

      capture.emitPcm(_silencePcm(900));
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(sttCalls, hasLength(1));
      expect(ascii.decode(sttCalls.single.sublist(0, 4)), 'RIFF');
      expect(submitted, ['Check crew vitals']);
      expect(controller.state.status, HandsFreeStatus.listening);
    });

    test('ignores frames while TTS is speaking and during cooldown on fake clock', () async {
      final capture = _FakePcmCapture();
      final speaking = _FakeSpeakingSignal();
      addTearDown(speaking.dispose);

      var sttCount = 0;
      final submitted = <String>[];
      var now = DateTime.utc(2026, 11, 15, 12, 0, 0);

      final controller = HandsFreeController(
        capture: capture,
        isRemoteConfigured: true,
        transcribeRemoteWav: (wavBytes, {language = 'en'}) async {
          sttCount++;
          return 'Post TTS query';
        },
        speakingSignal: speaking,
        onTranscript: (text) => submitted.add(text),
        postSpeakCooldown: const Duration(milliseconds: 300),
        clock: () => now,
      );
      addTearDown(controller.dispose);

      await controller.initialize();
      expect(controller.state.status, HandsFreeStatus.listening);

      speaking.setSpeaking(true);
      await Future<void>.delayed(Duration.zero);
      expect(controller.state.status, HandsFreeStatus.pausedWhileSpeaking);

      // Utterance while TTS is speaking must be ignored.
      capture.emitPcm(_tonePcm(700));
      capture.emitPcm(_silencePcm(900));
      await Future<void>.delayed(Duration.zero);
      expect(sttCount, 0);
      expect(submitted, isEmpty);

      // TTS stops at t=0; frames at +100ms (inside 300ms cooldown) are ignored.
      speaking.setSpeaking(false);
      await Future<void>.delayed(Duration.zero);
      now = now.add(const Duration(milliseconds: 100));
      capture.emitPcm(_tonePcm(700));
      capture.emitPcm(_silencePcm(900));
      await Future<void>.delayed(Duration.zero);
      expect(sttCount, 0);

      // Advance fake clock past 300ms cooldown -> frames are accepted again.
      now = now.add(const Duration(milliseconds: 350));
      capture.emitPcm(_silencePcm(400));
      capture.emitPcm(_tonePcm(600));
      capture.emitPcm(_silencePcm(900));
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(sttCount, 1);
      expect(submitted, ['Post TTS query']);
    });

    test('discards empty and punctuation-only transcripts silently', () async {
      final capture = _FakePcmCapture();
      final responses = ['   ', '...', ''];
      var callIdx = 0;
      final submitted = <String>[];

      final controller = HandsFreeController(
        capture: capture,
        isRemoteConfigured: true,
        transcribeRemoteWav: (_, {language = 'en'}) async =>
            responses[callIdx++],
        onTranscript: (text) => submitted.add(text),
      );
      addTearDown(controller.dispose);

      await controller.initialize();

      for (var i = 0; i < responses.length; i++) {
        capture.emitPcm(_silencePcm(400));
        capture.emitPcm(_tonePcm(600));
        capture.emitPcm(_silencePcm(900));
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);
      }

      expect(callIdx, 3);
      expect(submitted, isEmpty);
      expect(controller.state.status, HandsFreeStatus.listening);
      expect(controller.state.errorMessage, isNull);
    });

    test(
      'permission denied falls back to manual mode with visible state',
      () async {
        final capture = _FakePcmCapture(permitted: false);
        final local = _FakeLocalContinuousStt(available: false);

        final controller = HandsFreeController(
          capture: capture,
          localContinuousStt: local,
          isRemoteConfigured: true,
          transcribeRemoteWav: (_, {language = 'en'}) async => 'unused',
          onTranscript: (_) {},
        );
        addTearDown(controller.dispose);

        await controller.initialize();

        expect(controller.state.enabled, isFalse);
        expect(controller.state.status, HandsFreeStatus.permissionDenied);
        expect(controller.state.permissionDenied, isTrue);
        expect(controller.state.errorMessage, isNotNull);
      },
    );

    test(
      'falls back to local continuous STT when remote fails with 503',
      () async {
        final capture = _FakePcmCapture();
        final local = _FakeLocalContinuousStt(available: true);
        final submitted = <String>[];

        final controller = HandsFreeController(
          capture: capture,
          localContinuousStt: local,
          isRemoteConfigured: true,
          transcribeRemoteWav: (_, {language = 'en'}) async {
            throw const AgentApiException(
              code: AgentErrorCode.upstreamUnavailable,
              message: 'STT down',
              statusCode: 503,
            );
          },
          onTranscript: (t) => submitted.add(t),
        );
        addTearDown(controller.dispose);

        await controller.initialize();
        capture.emitPcm(_silencePcm(400));
        capture.emitPcm(_tonePcm(600));
        capture.emitPcm(_silencePcm(900));
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        expect(capture.streamStopped, isTrue);
        expect(local.started, isTrue);
        expect(controller.state.usingLocalFallback, isTrue);
        expect(controller.state.status, HandsFreeStatus.listening);

        local.emitTranscript('Local fallback command');
        await Future<void>.delayed(Duration.zero);
        expect(submitted, ['Local fallback command']);
      },
    );

    test('surfaces error state when both remote and local STT fail', () async {
      final capture = _FakePcmCapture();
      final local = _FakeLocalContinuousStt(available: false);

      final controller = HandsFreeController(
        capture: capture,
        localContinuousStt: local,
        isRemoteConfigured: true,
        transcribeRemoteWav: (_, {language = 'en'}) async {
          throw const AgentApiException(
            code: AgentErrorCode.networkError,
            message: 'Offline',
          );
        },
        onTranscript: (_) {},
      );
      addTearDown(controller.dispose);

      await controller.initialize();
      capture.emitPcm(_silencePcm(400));
      capture.emitPcm(_tonePcm(600));
      capture.emitPcm(_silencePcm(900));
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(controller.state.enabled, isFalse);
      expect(controller.state.status, HandsFreeStatus.error);
      expect(controller.state.errorMessage, isNotNull);
    });

    test('pauseForManualInput stops capture and resumeAfterManualInput restarts it', () async {
      final capture = _FakePcmCapture();
      final controller = HandsFreeController(
        capture: capture,
        isRemoteConfigured: true,
        transcribeRemoteWav: (_, {language = 'en'}) async => '',
        onTranscript: (_) {},
      );
      addTearDown(controller.dispose);

      await controller.initialize();
      expect(controller.state.status, HandsFreeStatus.listening);

      await controller.pauseForManualInput();
      expect(capture.streamStopped, isTrue);
      expect(controller.state.status, HandsFreeStatus.off);

      capture.streamStarted = false;
      await controller.resumeAfterManualInput();
      expect(capture.streamStarted, isTrue);
      expect(controller.state.status, HandsFreeStatus.listening);
    });

    test('exposes transcribing status while STT is in flight and does not fallback on 401', () async {
      final capture = _FakePcmCapture();
      final local = _FakeLocalContinuousStt(available: true);
      final sttCompleter = Completer<String>();

      final controller = HandsFreeController(
        capture: capture,
        localContinuousStt: local,
        isRemoteConfigured: true,
        transcribeRemoteWav: (_, {language = 'en'}) => sttCompleter.future,
        onTranscript: (_) {},
      );
      addTearDown(controller.dispose);

      await controller.initialize();
      capture.emitPcm(_silencePcm(400));
      capture.emitPcm(_tonePcm(600));
      capture.emitPcm(_silencePcm(900));
      await Future<void>.delayed(Duration.zero);

      expect(controller.state.status, HandsFreeStatus.transcribing);

      sttCompleter.completeError(
        const AgentApiException(
          code: AgentErrorCode.unauthorized,
          message: 'Bad API key',
          statusCode: 401,
        ),
      );
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(local.started, isFalse);
      expect(controller.state.enabled, isFalse);
      expect(controller.state.status, HandsFreeStatus.error);
      expect(controller.state.errorMessage, contains('Bad API key'));
    });
  });
}
