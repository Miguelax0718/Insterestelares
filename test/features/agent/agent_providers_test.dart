import 'dart:convert';

import 'package:astramed/features/agent/domain/agent_config.dart';
import 'package:astramed/features/agent/domain/agent_models.dart';
import 'package:astramed/features/agent/domain/agent_ports.dart';
import 'package:astramed/features/agent/providers/agent_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test(
    'Riverpod providers wire config -> client -> services and allow overrides',
    () async {
      final mockClient = MockClient((request) async {
        if (request.url.path == '/health') {
          return http.Response(
            jsonEncode({
              'status': 'ok',
              'version': '1.0.0',
              'providers': {
                'llm': 'agentrouter',
                'stt': 'whisper',
                'tts': 'piper',
              },
            }),
            200,
          );
        }
        if (request.url.path == '/v1/chat') {
          return http.Response(
            jsonEncode({'reply': 'Nominal', 'model': 'm1'}),
            200,
          );
        }
        return http.Response('Not found', 404);
      });

      final container = ProviderContainer(
        overrides: [
          agentConfigProvider.overrideWithValue(
            const AgentConfig(baseUrl: 'https://gateway.test', apiKey: 'k1'),
          ),
          httpClientProvider.overrideWithValue(mockClient),
        ],
      );
      addTearDown(container.dispose);

      final chat = container.read(agentChatServiceProvider);
      expect(chat, isA<AgentChatService>());
      expect(
        container.read(speechToTextServiceProvider),
        isA<SpeechToTextService>(),
      );
      expect(
        container.read(textToSpeechServiceProvider),
        isA<TextToSpeechService>(),
      );

      final health = await container.read(agentHealthProvider.future);
      expect(health.status, 'ok');

      final reply = await chat.send(const [
        ChatMessage(role: ChatRole.user, content: 'Status'),
      ]);
      expect(reply.reply, 'Nominal');
    },
  );
}
