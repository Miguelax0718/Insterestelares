import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:astramed/features/agent/data/agent_api_client.dart';
import 'package:astramed/features/agent/domain/agent_config.dart';
import 'package:astramed/features/agent/domain/agent_exception.dart';
import 'package:astramed/features/agent/domain/agent_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  const testConfig = AgentConfig(
    baseUrl: 'https://gateway.astramed.local/',
    apiKey: 'test-secret-key',
    timeout: Duration(seconds: 5),
    streamTimeout: Duration(seconds: 10),
  );

  group('AgentConfig', () {
    test('normalizes trailing slash when resolving paths', () {
      expect(
        testConfig.resolveUri('/v1/chat').toString(),
        'https://gateway.astramed.local/v1/chat',
      );
      expect(
        const AgentConfig(baseUrl: 'https://example.com')
            .resolveUri('/health')
            .toString(),
        'https://example.com/health',
      );
    });

    test('includes X-AstraMed-Key only when apiKey is non-empty', () {
      expect(testConfig.authHeaders(), {'X-AstraMed-Key': 'test-secret-key'});
      expect(
        const AgentConfig(baseUrl: 'https://x.com').authHeaders(),
        isEmpty,
      );
    });

    test('throws AgentUnavailableException when baseUrl is empty', () {
      const unconfigured = AgentConfig();
      expect(unconfigured.isConfigured, isFalse);
      expect(
        () => unconfigured.resolveUri('/v1/chat'),
        throwsA(isA<AgentUnavailableException>()),
      );
    });
  });

  group('AgentApiClient GET /health', () {
    test(
      'calls GET /health without auth header and parses providers',
      () async {
        late http.Request captured;
        final client = AgentApiClient(
          config: testConfig,
          client: MockClient((request) async {
            captured = request;
            return http.Response(
              jsonEncode({
                'status': 'ok',
                'version': '0.1.0',
                'providers': {
                  'llm': 'agentrouter',
                  'stt': 'faster-whisper',
                  'tts': 'piper',
                },
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          }),
        );

        final health = await client.health();

        expect(captured.method, 'GET');
        expect(
          captured.url.toString(),
          'https://gateway.astramed.local/health',
        );
        expect(captured.headers.containsKey('X-AstraMed-Key'), isFalse);
        expect(health.status, 'ok');
        expect(health.version, '0.1.0');
        expect(health.providers, {
          'llm': 'agentrouter',
          'stt': 'faster-whisper',
          'tts': 'piper',
        });
      },
    );
  });

  group('AgentApiClient POST /v1/chat (non-stream)', () {
    test(
      'sends messages, context, stream=false and X-AstraMed-Key header',
      () async {
        late http.Request captured;
        final client = AgentApiClient(
          config: testConfig,
          client: MockClient((request) async {
            captured = request;
            return http.Response(
              jsonEncode({
                'reply': 'Hydrate with 500 ml of electrolytes.',
                'model': 'gpt-4o-mini',
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          }),
        );

        final reply = await client.chat(
          const [
            ChatMessage(role: ChatRole.user, content: 'Mild headache'),
            ChatMessage(role: ChatRole.assistant, content: 'Check BP'),
          ],
          context: const {'hr': 78, 'spo2': 98},
        );

        expect(captured.method, 'POST');
        expect(
          captured.url.toString(),
          'https://gateway.astramed.local/v1/chat',
        );
        expect(captured.headers['X-AstraMed-Key'], 'test-secret-key');
        expect(
          captured.headers['content-type'],
          startsWith('application/json'),
        );

        final payload = jsonDecode(captured.body) as Map<String, dynamic>;
        expect(payload, {
          'messages': [
            {'role': 'user', 'content': 'Mild headache'},
            {'role': 'assistant', 'content': 'Check BP'},
          ],
          'context': {'hr': 78, 'spo2': 98},
          'stream': false,
        });

        expect(
          reply,
          const AgentReply(
            reply: 'Hydrate with 500 ml of electrolytes.',
            model: 'gpt-4o-mini',
          ),
        );
      },
    );
  });

  group('AgentApiClient POST /v1/chat (SSE stream)', () {
    test('parses multi-delta and done events from SSE response', () async {
      late http.Request captured;
      final sseBody = [
        'data: {"delta":"Check "}\n\n',
        'data: {"delta":"oxygen."}\n\n',
        'data: {"done":true,"model":"claude-sonnet"}\n\n',
      ].join();

      final client = AgentApiClient(
        config: testConfig,
        client: MockClient((request) async {
          captured = request;
          return http.Response(
            sseBody,
            200,
            headers: {'content-type': 'text/event-stream'},
          );
        }),
      );

      final events = await client.chatStream(const [
        ChatMessage(role: ChatRole.user, content: 'Status?'),
      ]).toList();

      expect(captured.method, 'POST');
      expect(captured.url.toString(), 'https://gateway.astramed.local/v1/chat');
      expect(captured.headers['X-AstraMed-Key'], 'test-secret-key');
      expect(captured.headers['accept'], 'text/event-stream');
      final payload = jsonDecode(captured.body) as Map<String, dynamic>;
      expect(payload['stream'], isTrue);
      expect(payload['context'], isNull);

      expect(events, const [
        AgentStreamDelta('Check '),
        AgentStreamDelta('oxygen.'),
        AgentStreamDone('claude-sonnet'),
      ]);
    });

    test(
      'handles SSE chunks split across lines and UTF-8 boundaries',
      () async {
        final fullSse =
            'data: {"delta":"Saturación "}\n\n'
            'data: {"delta":"normal"}\n\n'
            'data: {"done":true,"model":"m1"}\n\n';
        final bytes = utf8.encode(fullSse);

        // Split into tiny 5-byte chunks (splitting inside UTF-8 chars & JSON lines).
        final chunks = <List<int>>[];
        for (var i = 0; i < bytes.length; i += 5) {
          final end = (i + 5 < bytes.length) ? i + 5 : bytes.length;
          chunks.add(bytes.sublist(i, end));
        }

        final client = AgentApiClient(
          config: testConfig,
          client: MockClient.streaming((request, bodyStream) async {
            return http.StreamedResponse(
              Stream.fromIterable(chunks),
              200,
              headers: {'content-type': 'text/event-stream'},
            );
          }),
        );

        final events = await client.chatStream(const [
          ChatMessage(role: ChatRole.user, content: 'SpO2?'),
        ]).toList();

        expect(events, const [
          AgentStreamDelta('Saturación '),
          AgentStreamDelta('normal'),
          AgentStreamDone('m1'),
        ]);
      },
    );

    test('emits typed AgentApiException on mid-stream error event', () async {
      final sseBody =
          'data: {"delta":"Partial "}\n\n'
          'data: {"error":{"code":"upstream_unavailable","message":"Gateway dropped"}}\n\n';

      final client = AgentApiClient(
        config: testConfig,
        client: MockClient((request) async {
          return http.Response(
            sseBody,
            200,
            headers: {'content-type': 'text/event-stream'},
          );
        }),
      );

      final received = <AgentStreamEvent>[];
      Object? caught;
      try {
        await for (final event in client.chatStream(const [
          ChatMessage(role: ChatRole.user, content: 'Help'),
        ])) {
          received.add(event);
        }
      } catch (e) {
        caught = e;
      }

      expect(received, const [AgentStreamDelta('Partial ')]);
      expect(
        caught,
        isA<AgentApiException>()
            .having((e) => e.code, 'code', AgentErrorCode.upstreamUnavailable)
            .having((e) => e.message, 'message', 'Gateway dropped')
            .having((e) => e.isFallbackEligible, 'isFallbackEligible', isTrue),
      );
    });
  });

  group('AgentApiClient POST /v1/stt', () {
    test(
      'uploads multipart field audio and language and parses result',
      () async {
        late http.BaseRequest captured;
        late List<int> capturedBody;

        final client = AgentApiClient(
          config: testConfig,
          client: MockClient.streaming((request, bodyStream) async {
            captured = request;
            capturedBody = await bodyStream.toBytes();
            return http.StreamedResponse(
              Stream.value(
                utf8.encode(
                  jsonEncode({
                    'text': 'Frecuencia cardiaca setenta y dos',
                    'language': 'es',
                    'duration_s': 2.4,
                  }),
                ),
              ),
              200,
              headers: {'content-type': 'application/json'},
            );
          }),
        );

        final fakeWav = Uint8List.fromList([82, 73, 70, 70, 1, 2, 3, 4]);
        final result = await client.transcribe(
          fakeWav,
          filename: 'sample.wav',
          mimeType: 'audio/wav',
          language: 'es',
        );

        expect(captured.method, 'POST');
        expect(
          captured.url.toString(),
          'https://gateway.astramed.local/v1/stt',
        );
        expect(captured.headers['X-AstraMed-Key'], 'test-secret-key');
        expect(
          captured.headers['content-type'],
          startsWith('multipart/form-data; boundary='),
        );

        final multipartText = utf8.decode(capturedBody, allowMalformed: true);
        expect(multipartText, contains('name="audio"'));
        expect(multipartText, contains('filename="sample.wav"'));
        expect(
          multipartText.toLowerCase(),
          contains('content-type: audio/wav'),
        );
        expect(multipartText, contains('name="language"'));
        expect(multipartText, contains('es'));

        expect(result.text, 'Frecuencia cardiaca setenta y dos');
        expect(result.language, 'es');
        expect(result.durationSeconds, 2.4);
      },
    );
  });

  group('AgentApiClient POST /v1/tts', () {
    test('posts text and voice and returns raw WAV bytes', () async {
      late http.Request captured;
      final expectedWav = Uint8List.fromList([82, 73, 70, 70, 9, 8, 7, 6]);

      final client = AgentApiClient(
        config: testConfig,
        client: MockClient((request) async {
          captured = request;
          return http.Response.bytes(
            expectedWav,
            200,
            headers: {'content-type': 'audio/wav'},
          );
        }),
      );

      final wav = await client.synthesize('Alerta roja', voice: 'es_MX-claude');

      expect(captured.method, 'POST');
      expect(captured.url.toString(), 'https://gateway.astramed.local/v1/tts');
      expect(captured.headers['X-AstraMed-Key'], 'test-secret-key');
      expect(captured.headers['content-type'], startsWith('application/json'));
      expect(jsonDecode(captured.body), {
        'text': 'Alerta roja',
        'voice': 'es_MX-claude',
      });
      expect(wav, expectedWav);
    });
  });

  group('S6 error envelope mapping', () {
    final cases =
        <
          ({
            int status,
            String wireCode,
            AgentErrorCode expectedCode,
            bool fallbackEligible,
          })
        >[
          (
            status: 401,
            wireCode: 'unauthorized',
            expectedCode: AgentErrorCode.unauthorized,
            fallbackEligible: false,
          ),
          (
            status: 429,
            wireCode: 'rate_limited',
            expectedCode: AgentErrorCode.rateLimited,
            fallbackEligible: false,
          ),
          (
            status: 422,
            wireCode: 'invalid_request',
            expectedCode: AgentErrorCode.invalidRequest,
            fallbackEligible: false,
          ),
          (
            status: 400,
            wireCode: 'invalid_request',
            expectedCode: AgentErrorCode.invalidRequest,
            fallbackEligible: false,
          ),
          (
            status: 413,
            wireCode: 'payload_too_large',
            expectedCode: AgentErrorCode.payloadTooLarge,
            fallbackEligible: false,
          ),
          (
            status: 502,
            wireCode: 'upstream_unavailable',
            expectedCode: AgentErrorCode.upstreamUnavailable,
            fallbackEligible: true,
          ),
          (
            status: 503,
            wireCode: 'upstream_unavailable',
            expectedCode: AgentErrorCode.upstreamUnavailable,
            fallbackEligible: true,
          ),
          (
            status: 500,
            wireCode: 'internal',
            expectedCode: AgentErrorCode.internal,
            fallbackEligible: true,
          ),
        ];

    for (final c in cases) {
      test('maps ${c.status} ${c.wireCode} to ${c.expectedCode}', () async {
        final client = AgentApiClient(
          config: testConfig,
          client: MockClient((request) async {
            return http.Response(
              jsonEncode({
                'error': {'code': c.wireCode, 'message': 'msg-${c.status}'},
              }),
              c.status,
              headers: {'content-type': 'application/json'},
            );
          }),
        );

        await expectLater(
          () => client.chat(const [
            ChatMessage(role: ChatRole.user, content: 'hi'),
          ]),
          throwsA(
            isA<AgentApiException>()
                .having((e) => e.code, 'code', c.expectedCode)
                .having((e) => e.statusCode, 'statusCode', c.status)
                .having((e) => e.message, 'message', 'msg-${c.status}')
                .having(
                  (e) => e.isFallbackEligible,
                  'isFallbackEligible',
                  c.fallbackEligible,
                ),
          ),
        );
      });
    }

    test(
      'maps http.ClientException to networkError (fallback eligible)',
      () async {
        final client = AgentApiClient(
          config: testConfig,
          client: MockClient((request) async {
            throw http.ClientException('Connection refused');
          }),
        );

        await expectLater(
          () => client.synthesize('hola'),
          throwsA(
            isA<AgentApiException>()
                .having((e) => e.code, 'code', AgentErrorCode.networkError)
                .having(
                  (e) => e.isFallbackEligible,
                  'isFallbackEligible',
                  isTrue,
                ),
          ),
        );
      },
    );

    test('maps TimeoutException to timeout (fallback eligible)', () async {
      final client = AgentApiClient(
        config: testConfig,
        client: MockClient((request) async {
          throw TimeoutException('Timed out');
        }),
      );

      await expectLater(
        () => client.health(),
        throwsA(
          isA<AgentApiException>()
              .having((e) => e.code, 'code', AgentErrorCode.timeout)
              .having(
                (e) => e.isFallbackEligible,
                'isFallbackEligible',
                isTrue,
              ),
        ),
      );
    });
  });
}
