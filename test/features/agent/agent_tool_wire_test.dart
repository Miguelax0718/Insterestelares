import 'dart:convert';

import 'package:astramed/features/agent/data/agent_api_client.dart';
import 'package:astramed/features/agent/domain/agent_config.dart';
import 'package:astramed/features/agent/domain/agent_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  const config = AgentConfig(
    baseUrl: 'https://gateway.astramed.local',
    apiKey: 'k',
    timeout: Duration(seconds: 5),
    streamTimeout: Duration(seconds: 5),
  );

  const vitalsTool = ToolSpec(
    name: 'get_vitals',
    description: 'Current vitals of an astronaut.',
    parameters: {
      'type': 'object',
      'properties': {
        'astronaut_id': {'type': 'string'},
      },
    },
  );

  group('ChatMessage tool wire shapes', () {
    test('assistant tool call message serializes tool_calls and null content',
        () {
      const message = ChatMessage.assistantToolCalls([
        ToolCall(id: 'call_1', name: 'get_vitals', arguments: {'astronaut_id': 'AST-01'}),
      ]);

      expect(message.toJson(), {
        'role': 'assistant',
        'content': null,
        'tool_calls': [
          {
            'id': 'call_1',
            'name': 'get_vitals',
            'arguments': {'astronaut_id': 'AST-01'},
          },
        ],
      });
    });

    test('tool result message serializes role tool and tool_call_id', () {
      const message = ChatMessage.toolResult(
        toolCallId: 'call_1',
        content: '{"hr":78}',
      );

      expect(message.toJson(), {
        'role': 'tool',
        'tool_call_id': 'call_1',
        'content': '{"hr":78}',
      });
      expect(ChatRole.fromWire('tool'), ChatRole.tool);
    });

    test('plain messages keep their previous shape', () {
      const message = ChatMessage(role: ChatRole.user, content: 'Hi');
      expect(message.toJson(), {'role': 'user', 'content': 'Hi'});
    });
  });

  group('AgentReply tool calls', () {
    test('parses tool_calls including invalid_arguments flag', () {
      final reply = AgentReply.fromJson({
        'reply': '',
        'model': 'm',
        'tool_calls': [
          {'id': 'call_1', 'name': 'get_vitals', 'arguments': {}},
          {
            'id': 'call_2',
            'name': 'score_graybiel',
            'arguments': {},
            'invalid_arguments': true,
          },
        ],
      });

      expect(reply.hasToolCalls, isTrue);
      expect(reply.toolCalls, const [
        ToolCall(id: 'call_1', name: 'get_vitals', arguments: {}),
        ToolCall(
          id: 'call_2',
          name: 'score_graybiel',
          arguments: {},
          invalidArguments: true,
        ),
      ]);
    });

    test('defaults to no tool calls when the field is absent', () {
      final reply = AgentReply.fromJson({'reply': 'ok', 'model': 'm'});
      expect(reply.toolCalls, isEmpty);
      expect(reply, const AgentReply(reply: 'ok', model: 'm'));
    });
  });

  group('AgentApiClient tool requests', () {
    test('sends tools and skill_instructions when provided', () async {
      late http.Request captured;
      final client = AgentApiClient(
        config: config,
        client: MockClient((request) async {
          captured = request;
          return http.Response(
            jsonEncode({
              'reply': '',
              'model': 'm',
              'tool_calls': [
                {
                  'id': 'call_1',
                  'name': 'get_vitals',
                  'arguments': {'astronaut_id': 'AST-01'},
                },
              ],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

      final reply = await client.send(
        const [ChatMessage(role: ChatRole.user, content: 'How am I?')],
        tools: const [vitalsTool],
        skillInstructions: const ['Use get_vitals for vitals.'],
      );

      final payload = jsonDecode(captured.body) as Map<String, dynamic>;
      expect(payload['tools'], [
        {
          'name': 'get_vitals',
          'description': 'Current vitals of an astronaut.',
          'parameters': {
            'type': 'object',
            'properties': {
              'astronaut_id': {'type': 'string'},
            },
          },
        },
      ]);
      expect(payload['skill_instructions'], ['Use get_vitals for vitals.']);
      expect(reply.toolCalls.single.name, 'get_vitals');
      expect(reply.toolCalls.single.arguments, {'astronaut_id': 'AST-01'});
    });

    test('stream yields tool_call events before done', () async {
      final sse = [
        'data: {"delta":"Checking"}',
        '',
        'data: {"tool_call":{"id":"call_1","name":"get_vitals","arguments":{}}}',
        '',
        'data: {"done":true,"model":"m"}',
        '',
      ].join('\n');
      final client = AgentApiClient(
        config: config,
        client: MockClient.streaming((request, body) async {
          return http.StreamedResponse(
            Stream.value(utf8.encode(sse)),
            200,
            headers: {'content-type': 'text/event-stream'},
          );
        }),
      );

      final events = await client
          .stream(
            const [ChatMessage(role: ChatRole.user, content: 'Hi')],
            tools: const [vitalsTool],
          )
          .toList();

      expect(events, const [
        AgentStreamDelta('Checking'),
        AgentStreamToolCall(
          ToolCall(id: 'call_1', name: 'get_vitals', arguments: {}),
        ),
        AgentStreamDone('m'),
      ]);
    });
  });
}
