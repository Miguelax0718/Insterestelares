import 'dart:async';
import 'dart:typed_data';

import 'package:astramed/features/agent/data/agent_api_client.dart';
import 'package:astramed/features/agent/data/remote_text_to_speech_service.dart';
import 'package:astramed/features/agent/data/resilient_agent_services.dart';
import 'package:astramed/features/agent/domain/agent_config.dart';
import 'package:astramed/features/agent/domain/agent_exception.dart';
import 'package:astramed/features/agent/domain/agent_models.dart';
import 'package:astramed/features/agent/domain/agent_ports.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class FakeAgentChatService implements AgentChatService {
  Future<AgentReply> Function(
    List<ChatMessage> messages,
    Map<String, dynamic>? context,
  )?
  onSend;
  Stream<AgentStreamEvent> Function(
    List<ChatMessage> messages,
    Map<String, dynamic>? context,
  )?
  onStream;

  @override
  Future<AgentReply> send(
    List<ChatMessage> messages, {
    Map<String, dynamic>? context,
    List<ToolSpec>? tools,
    List<String>? skillInstructions,
  }) {
    return onSend!(messages, context);
  }

  @override
  Stream<AgentStreamEvent> stream(
    List<ChatMessage> messages, {
    Map<String, dynamic>? context,
    List<ToolSpec>? tools,
    List<String>? skillInstructions,
  }) {
    return onStream!(messages, context);
  }
}

class FakeSpeechToTextService implements SpeechToTextService {
  FakeSpeechToTextService({this.available = true, this.result = 'transcript'});

  final bool available;
  final String result;
  Object? errorToThrow;
  int startCount = 0;
  int stopCount = 0;
  int listenCount = 0;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<void> startListening({String language = 'es'}) async {
    startCount++;
    if (errorToThrow != null) throw errorToThrow!;
  }

  @override
  Future<String> stopListening() async {
    stopCount++;
    if (errorToThrow != null) throw errorToThrow!;
    return result;
  }

  @override
  Future<String> listen({
    String language = 'es',
    Duration maxDuration = const Duration(seconds: 15),
  }) async {
    listenCount++;
    if (errorToThrow != null) throw errorToThrow!;
    return result;
  }

  @override
  Future<void> cancel() async {}

  @override
  Future<void> dispose() async {}
}

class FakeTextToSpeechService implements TextToSpeechService {
  Object? errorToThrow;
  final List<String> spokenTexts = [];
  int stopCount = 0;

  @override
  Future<void> speak(
    String text, {
    String? voice,
    String language = 'es-ES',
  }) async {
    if (errorToThrow != null) throw errorToThrow!;
    spokenTexts.add(text);
  }

  @override
  Future<void> stop() async {
    stopCount++;
  }

  @override
  Future<void> dispose() async {}
}

void main() {
  group('ResilientTextToSpeechService', () {
    test('uses remote when healthy and does not invoke local', () async {
      final remote = FakeTextToSpeechService();
      final local = FakeTextToSpeechService();
      final service = ResilientTextToSpeechService(
        remote: remote,
        local: local,
        isRemoteConfigured: true,
      );

      await service.speak('Oxygen nominal');

      expect(remote.spokenTexts, ['Oxygen nominal']);
      expect(local.spokenTexts, isEmpty);
    });

    test('falls back to local on 503 upstream_unavailable', () async {
      final remote = FakeTextToSpeechService()
        ..errorToThrow = const AgentApiException(
          code: AgentErrorCode.upstreamUnavailable,
          message: 'Piper down',
          statusCode: 503,
        );
      final local = FakeTextToSpeechService();
      final service = ResilientTextToSpeechService(
        remote: remote,
        local: local,
        isRemoteConfigured: true,
      );

      await service.speak('Check vitals');

      expect(local.spokenTexts, ['Check vitals']);
    });

    test('falls back to local on network error and timeout', () async {
      final remote = FakeTextToSpeechService()
        ..errorToThrow = http.ClientException('Offline');
      final local = FakeTextToSpeechService();
      final service = ResilientTextToSpeechService(
        remote: remote,
        local: local,
        isRemoteConfigured: true,
      );

      await service.speak('First');
      remote.errorToThrow = TimeoutException('Slow link');
      await service.speak('Second');

      expect(local.spokenTexts, ['First', 'Second']);
    });

    test('does NOT fall back on 401 unauthorized and surfaces error', () async {
      final remote = FakeTextToSpeechService()
        ..errorToThrow = const AgentApiException(
          code: AgentErrorCode.unauthorized,
          message: 'Bad key',
          statusCode: 401,
        );
      final local = FakeTextToSpeechService();
      final service = ResilientTextToSpeechService(
        remote: remote,
        local: local,
        isRemoteConfigured: true,
      );

      await expectLater(
        () => service.speak('Test'),
        throwsA(
          isA<AgentApiException>().having(
            (e) => e.code,
            'code',
            AgentErrorCode.unauthorized,
          ),
        ),
      );
      expect(local.spokenTexts, isEmpty);
    });

    test(
      'does NOT fall back on 422 invalid_request and surfaces error',
      () async {
        final remote = FakeTextToSpeechService()
          ..errorToThrow = const AgentApiException(
            code: AgentErrorCode.invalidRequest,
            message: 'Text too long',
            statusCode: 422,
          );
        final local = FakeTextToSpeechService();
        final service = ResilientTextToSpeechService(
          remote: remote,
          local: local,
          isRemoteConfigured: true,
        );

        await expectLater(
          () => service.speak('Test'),
          throwsA(
            isA<AgentApiException>().having(
              (e) => e.code,
              'code',
              AgentErrorCode.invalidRequest,
            ),
          ),
        );
        expect(local.spokenTexts, isEmpty);
      },
    );
  });

  group('ResilientSpeechToTextService', () {
    test('uses remote when healthy', () async {
      final remote = FakeSpeechToTextService(result: 'remote text');
      final local = FakeSpeechToTextService(result: 'local text');
      final service = ResilientSpeechToTextService(
        remote: remote,
        local: local,
        isRemoteConfigured: true,
      );

      final text = await service.listen(language: 'es');
      expect(text, 'remote text');
      expect(remote.listenCount, 1);
      expect(local.listenCount, 0);
    });

    test('falls back to local on 503 and network error', () async {
      final remote = FakeSpeechToTextService()
        ..errorToThrow = const AgentApiException(
          code: AgentErrorCode.upstreamUnavailable,
          message: 'Whisper unavailable',
          statusCode: 503,
        );
      final local = FakeSpeechToTextService(result: 'local fallback');
      final service = ResilientSpeechToTextService(
        remote: remote,
        local: local,
        isRemoteConfigured: true,
      );

      expect(await service.listen(), 'local fallback');

      remote.errorToThrow = const AgentApiException(
        code: AgentErrorCode.networkError,
        message: 'Socket closed',
      );
      expect(await service.listen(), 'local fallback');
      expect(local.listenCount, 2);
    });

    test('does NOT fall back on 401 or 422', () async {
      final remote = FakeSpeechToTextService()
        ..errorToThrow = const AgentApiException(
          code: AgentErrorCode.unauthorized,
          message: 'Unauthorized',
          statusCode: 401,
        );
      final local = FakeSpeechToTextService(result: 'local fallback');
      final service = ResilientSpeechToTextService(
        remote: remote,
        local: local,
        isRemoteConfigured: true,
      );

      await expectLater(
        () => service.listen(),
        throwsA(
          isA<AgentApiException>().having(
            (e) => e.code,
            'code',
            AgentErrorCode.unauthorized,
          ),
        ),
      );

      remote.errorToThrow = const AgentApiException(
        code: AgentErrorCode.invalidRequest,
        message: 'Bad audio format',
        statusCode: 422,
      );
      await expectLater(
        () => service.listen(),
        throwsA(
          isA<AgentApiException>().having(
            (e) => e.code,
            'code',
            AgentErrorCode.invalidRequest,
          ),
        ),
      );
      expect(local.listenCount, 0);
    });
  });

  group('ResilientAgentChatService', () {
    test('returns reply when gateway succeeds', () async {
      final remote = FakeAgentChatService()
        ..onSend = (_, _) async =>
            const AgentReply(reply: 'All systems nominal', model: 'm1');
      final service = ResilientAgentChatService(
        remote: remote,
        isRemoteConfigured: true,
      );

      final reply = await service.send(const [
        ChatMessage(role: ChatRole.user, content: 'Check'),
      ]);
      expect(reply.reply, 'All systems nominal');
    });

    test(
      'throws AgentUnavailableException when unconfigured or unreachable',
      () async {
        final unconfigured = ResilientAgentChatService(
          remote: FakeAgentChatService(),
          isRemoteConfigured: false,
        );
        await expectLater(
          () => unconfigured.send(const [
            ChatMessage(role: ChatRole.user, content: 'Hi'),
          ]),
          throwsA(isA<AgentUnavailableException>()),
        );

        final remote503 = FakeAgentChatService()
          ..onSend = (_, _) async => throw const AgentApiException(
            code: AgentErrorCode.upstreamUnavailable,
            message: '503',
            statusCode: 503,
          );
        final service = ResilientAgentChatService(
          remote: remote503,
          isRemoteConfigured: true,
        );
        await expectLater(
          () => service.send(const [
            ChatMessage(role: ChatRole.user, content: 'Hi'),
          ]),
          throwsA(
            isA<AgentUnavailableException>().having(
              (e) => e.code,
              'code',
              AgentErrorCode.agentUnavailable,
            ),
          ),
        );
      },
    );

    test(
      'converts mid-stream 503/network failures to AgentUnavailableException',
      () async {
        final remote = FakeAgentChatService()
          ..onStream = (_, _) async* {
            yield const AgentStreamDelta('Start ');
            throw http.ClientException('Link lost');
          };
        final service = ResilientAgentChatService(
          remote: remote,
          isRemoteConfigured: true,
        );

        await expectLater(
          service.stream(const [
            ChatMessage(role: ChatRole.user, content: 'Hi'),
          ]),
          emitsInOrder([
            const AgentStreamDelta('Start '),
            emitsError(isA<AgentUnavailableException>()),
          ]),
        );
      },
    );

    test(
      'surfaces 401 and 422 without converting to AgentUnavailableException',
      () async {
        final remote = FakeAgentChatService()
          ..onSend = (_, _) async => throw const AgentApiException(
            code: AgentErrorCode.unauthorized,
            message: 'Invalid API key',
            statusCode: 401,
          );
        final service = ResilientAgentChatService(
          remote: remote,
          isRemoteConfigured: true,
        );

        await expectLater(
          () => service.send(const [
            ChatMessage(role: ChatRole.user, content: 'Hi'),
          ]),
          throwsA(
            isA<AgentApiException>()
                .having((e) => e.code, 'code', AgentErrorCode.unauthorized)
                .having(
                  (e) => e is AgentUnavailableException,
                  'not unavailable',
                  isFalse,
                ),
          ),
        );
      },
    );
  });

  group('SpeakingTrackedTextToSpeechService', () {
    test(
      'tracks isSpeaking and emits stream transitions across speak and stop',
      () async {
        final gate = Completer<void>();
        final inner = _BlockingFakeTts(gate);
        final tracked = SpeakingTrackedTextToSpeechService(inner: inner);
        addTearDown(tracked.dispose);

        final events = <bool>[];
        final sub = tracked.isSpeakingStream.listen(events.add);
        addTearDown(sub.cancel);

        expect(tracked.isSpeaking, isFalse);
        final speakFuture = tracked.speak('Oxygen nominal');
        await Future<void>.delayed(Duration.zero);
        expect(tracked.isSpeaking, isTrue);

        gate.complete();
        await speakFuture;
        await Future<void>.delayed(Duration.zero);

        expect(tracked.isSpeaking, isFalse);
        expect(events, [true, false]);

        // stop() resets speaking state immediately.
        final gate2 = Completer<void>();
        final inner2 = _BlockingFakeTts(gate2);
        final tracked2 = SpeakingTrackedTextToSpeechService(inner: inner2);
        addTearDown(tracked2.dispose);
        unawaited(tracked2.speak('Long alert'));
        await Future<void>.delayed(Duration.zero);
        expect(tracked2.isSpeaking, isTrue);
        await tracked2.stop();
        expect(tracked2.isSpeaking, isFalse);
        gate2.complete();
      },
    );

    test('speakSynchronized keeps isSpeaking false during synthesis and flips true when onAudioReady fires', () async {
      final synthGate = Completer<void>();
      final playGate = Completer<void>();
      final timeline = <String>[];
      final inner = _ControllableSyncFakeTts(
        synthGate: synthGate,
        playGate: playGate,
        timeline: timeline,
      );
      final tracked = SpeakingTrackedTextToSpeechService(inner: inner);
      addTearDown(tracked.dispose);

      final events = <bool>[];
      final sub = tracked.isSpeakingStream.listen(events.add);
      addTearDown(sub.cancel);

      final speakFuture = tracked.speakSynchronized(
        'Oxygen nominal',
        onAudioReady: () {
          timeline.add('caller_ready:${tracked.isSpeaking}');
        },
      );
      await Future<void>.delayed(Duration.zero);

      // During synthesis, isSpeaking must remain false.
      expect(tracked.isSpeaking, isFalse);
      expect(events, isEmpty);

      // Complete synthesis -> onAudioReady fires and isSpeaking flips true.
      synthGate.complete();
      await Future<void>.delayed(Duration.zero);
      expect(tracked.isSpeaking, isTrue);
      expect(events, [true]);
      expect(timeline, ['synth_done', 'caller_ready:true']);

      // Complete playback -> isSpeaking flips false.
      playGate.complete();
      await speakFuture;
      await Future<void>.delayed(Duration.zero);
      expect(tracked.isSpeaking, isFalse);
      expect(events, [true, false]);
    });

    test('speakSynchronized leaves isSpeaking false if inner throws before onAudioReady', () async {
      final inner = _FailingSyncFakeTts(StateError('Synth boom'));
      final tracked = SpeakingTrackedTextToSpeechService(inner: inner);
      addTearDown(tracked.dispose);

      var readyCalled = false;
      await expectLater(
        () => tracked.speakSynchronized(
          'Hello',
          onAudioReady: () => readyCalled = true,
        ),
        throwsStateError,
      );
      expect(readyCalled, isFalse);
      expect(tracked.isSpeaking, isFalse);
    });

    test('speakSynchronized resets isSpeaking if playback throws after onAudioReady and ignores duplicate onAudioReady', () async {
      final inner = _PostReadyFailingSyncTts(StateError('playback failed'));
      final tracked = SpeakingTrackedTextToSpeechService(inner: inner);
      addTearDown(tracked.dispose);

      final events = <bool>[];
      final sub = tracked.isSpeakingStream.listen(events.add);
      addTearDown(sub.cancel);

      var readyCalls = 0;
      await expectLater(
        () => tracked.speakSynchronized(
          'Hello',
          onAudioReady: () => readyCalls++,
        ),
        throwsStateError,
      );
      await Future<void>.delayed(Duration.zero);

      expect(readyCalls, 1);
      expect(tracked.isSpeaking, isFalse);
      expect(events, [true, false]);
    });
  });

  group('RemoteTextToSpeechService.speakSynchronized', () {
    test(
      'completes synthesis before calling onAudioReady and playWav',
      () async {
        final synthCompleter = Completer<http.Response>();
        final playCompleter = Completer<void>();
        final timeline = <String>[];

        final mockHttp = MockClient((request) async {
          timeline.add('http_start');
          return synthCompleter.future;
        });
        final client = AgentApiClient(
          config: const AgentConfig(baseUrl: 'https://example.test'),
          client: mockHttp,
        );
        final playback = _RecordingAudioPlayback(
          onPlay: (_) {
            timeline.add('play_start');
            return playCompleter.future;
          },
        );
        final service = RemoteTextToSpeechService(
          client: client,
          playback: playback,
        );
        addTearDown(service.dispose);

        final speakFuture = service.speakSynchronized(
          'Listen! Hydrate now.',
          voice: 'am_puck',
          onAudioReady: () {
            timeline.add('onAudioReady');
          },
        );
        await Future<void>.delayed(Duration.zero);

        // Synthesis still pending: neither onAudioReady nor playWav has run.
        expect(timeline, ['http_start']);
        expect(playback.playedBytes, isEmpty);

        synthCompleter.complete(
          http.Response.bytes(Uint8List.fromList([1, 2, 3, 4]), 200),
        );
        await Future<void>.delayed(Duration.zero);

        expect(timeline, ['http_start', 'onAudioReady', 'play_start']);
        expect(playback.playedBytes, hasLength(1));

        playCompleter.complete();
        await speakFuture;
      },
    );

    test('does not call onAudioReady when synthesis throws', () async {
      final mockHttp = MockClient(
        (_) async => http.Response('{"error":"upstream"}', 503),
      );
      final client = AgentApiClient(
        config: const AgentConfig(baseUrl: 'https://example.test'),
        client: mockHttp,
      );
      final playback = _RecordingAudioPlayback();
      final service = RemoteTextToSpeechService(
        client: client,
        playback: playback,
      );
      addTearDown(service.dispose);

      var readyCalled = false;
      await expectLater(
        () => service.speakSynchronized(
          'Test',
          onAudioReady: () => readyCalled = true,
        ),
        throwsA(isA<AgentApiException>()),
      );
      expect(readyCalled, isFalse);
      expect(playback.playedBytes, isEmpty);
    });
  });

  group('ResilientTextToSpeechService.speakSynchronized', () {
    test(
      'fires onAudioReady once before local fallback on 503 or unconfigured',
      () async {
        final remote = _FailingSyncFakeTts(
          const AgentApiException(
            code: AgentErrorCode.upstreamUnavailable,
            message: 'TTS down',
            statusCode: 503,
          ),
        );
        final local = FakeTextToSpeechService();
        final service = ResilientTextToSpeechService(
          remote: remote,
          local: local,
          isRemoteConfigured: true,
        );

        var readyCount = 0;
        await service.speakSynchronized(
          'Fallback phrase',
          onAudioReady: () => readyCount++,
        );
        expect(readyCount, 1);
        expect(local.spokenTexts, ['Fallback phrase']);

        final unconfigured = ResilientTextToSpeechService(
          remote: remote,
          local: local,
          isRemoteConfigured: false,
        );
        var unconfiguredReadyCount = 0;
        await unconfigured.speakSynchronized(
          'Offline phrase',
          onAudioReady: () => unconfiguredReadyCount++,
        );
        expect(unconfiguredReadyCount, 1);
        expect(local.spokenTexts, ['Fallback phrase', 'Offline phrase']);
      },
    );
  });
}

class _BlockingFakeTts implements TextToSpeechService {
  _BlockingFakeTts(this.gate);

  final Completer<void> gate;

  @override
  Future<void> dispose() async {}

  @override
  Future<void> speak(String text, {String? voice, String language = 'en-US'}) =>
      gate.future;

  @override
  Future<void> stop() async {}
}

class _ControllableSyncFakeTts implements SynchronizedTextToSpeechService {
  _ControllableSyncFakeTts({
    required this.synthGate,
    required this.playGate,
    required this.timeline,
  });

  final Completer<void> synthGate;
  final Completer<void> playGate;
  final List<String> timeline;

  @override
  Future<void> speakSynchronized(
    String text, {
    String? voice,
    String language = 'en-US',
    required void Function() onAudioReady,
  }) async {
    await synthGate.future;
    timeline.add('synth_done');
    onAudioReady();
    await playGate.future;
  }

  @override
  Future<void> speak(String text, {String? voice, String language = 'en-US'}) =>
      speakSynchronized(
        text,
        voice: voice,
        language: language,
        onAudioReady: () {},
      );

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() async {}
}

class _FailingSyncFakeTts implements SynchronizedTextToSpeechService {
  _FailingSyncFakeTts(this.error);

  final Object error;

  @override
  Future<void> speakSynchronized(
    String text, {
    String? voice,
    String language = 'en-US',
    required void Function() onAudioReady,
  }) async {
    throw error;
  }

  @override
  Future<void> speak(
    String text, {
    String? voice,
    String language = 'en-US',
  }) async {
    throw error;
  }

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() async {}
}

class _PostReadyFailingSyncTts implements SynchronizedTextToSpeechService {
  _PostReadyFailingSyncTts(this.error);

  final Object error;

  @override
  Future<void> speakSynchronized(
    String text, {
    String? voice,
    String language = 'en-US',
    required void Function() onAudioReady,
  }) async {
    onAudioReady();
    onAudioReady();
    throw error;
  }

  @override
  Future<void> speak(
    String text, {
    String? voice,
    String language = 'en-US',
  }) async {
    throw error;
  }

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() async {}
}

class _RecordingAudioPlayback implements AudioPlaybackPort {
  _RecordingAudioPlayback({this.onPlay});

  final Future<void> Function(Uint8List wavBytes)? onPlay;
  final List<Uint8List> playedBytes = [];

  @override
  Future<void> playWav(Uint8List wavBytes) async {
    playedBytes.add(wavBytes);
    if (onPlay != null) {
      await onPlay!(wavBytes);
    }
  }

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() async {}
}
