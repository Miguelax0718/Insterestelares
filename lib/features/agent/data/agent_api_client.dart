import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../domain/agent_config.dart';
import '../domain/agent_exception.dart';
import '../domain/agent_models.dart';
import '../domain/agent_ports.dart';
import 'network_error.dart';

class AgentApiClient implements AgentChatService {
  AgentApiClient({required this.config, http.Client? client})
    : _client = client ?? http.Client(),
      _ownsClient = client == null;

  final AgentConfig config;
  final http.Client _client;
  final bool _ownsClient;

  Future<HealthStatus> health() async {
    final uri = config.resolveUri('/health');
    try {
      final response = await _client
          .get(uri, headers: const {'Accept': 'application/json'})
          .timeout(config.timeout);
      if (response.statusCode != 200) {
        throw _parseErrorResponse(response.statusCode, response.body);
      }
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return HealthStatus.fromJson(json);
    } on AgentApiException {
      rethrow;
    } on TimeoutException catch (e) {
      throw AgentApiException(
        code: AgentErrorCode.timeout,
        message: 'Health check timed out.',
        cause: e,
      );
    } on FormatException catch (e) {
      throw AgentApiException(
        code: AgentErrorCode.unknown,
        message: 'Invalid health response payload.',
        cause: e,
      );
    } catch (e) {
      if (isNetworkTransportError(e)) {
        throw AgentApiException(
          code: AgentErrorCode.networkError,
          message: 'Network error during health check.',
          cause: e,
        );
      }
      rethrow;
    }
  }

  @override
  Future<AgentReply> send(
    List<ChatMessage> messages, {
    Map<String, dynamic>? context,
    List<ToolSpec>? tools,
    List<String>? skillInstructions,
  }) => chat(
    messages,
    context: context,
    tools: tools,
    skillInstructions: skillInstructions,
  );

  Future<AgentReply> chat(
    List<ChatMessage> messages, {
    Map<String, dynamic>? context,
    List<ToolSpec>? tools,
    List<String>? skillInstructions,
  }) async {
    final uri = config.resolveUri('/v1/chat');
    final body = jsonEncode({
      'messages': messages.map((m) => m.toJson()).toList(),
      'context': context,
      'stream': false,
      if (tools != null && tools.isNotEmpty)
        'tools': tools.map((t) => t.toJson()).toList(),
      if (skillInstructions != null && skillInstructions.isNotEmpty)
        'skill_instructions': skillInstructions,
    });
    try {
      final response = await _client
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
              ...config.authHeaders(),
            },
            body: body,
          )
          .timeout(config.timeout);
      if (response.statusCode != 200) {
        throw _parseErrorResponse(response.statusCode, response.body);
      }
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return AgentReply.fromJson(json);
    } on AgentApiException {
      rethrow;
    } on TimeoutException catch (e) {
      throw AgentApiException(
        code: AgentErrorCode.timeout,
        message: 'Chat request timed out.',
        cause: e,
      );
    } on FormatException catch (e) {
      throw AgentApiException(
        code: AgentErrorCode.unknown,
        message: 'Invalid chat response payload.',
        cause: e,
      );
    } catch (e) {
      if (isNetworkTransportError(e)) {
        throw AgentApiException(
          code: AgentErrorCode.networkError,
          message: 'Network error during chat request.',
          cause: e,
        );
      }
      rethrow;
    }
  }

  @override
  Stream<AgentStreamEvent> stream(
    List<ChatMessage> messages, {
    Map<String, dynamic>? context,
    List<ToolSpec>? tools,
    List<String>? skillInstructions,
  }) => chatStream(
    messages,
    context: context,
    tools: tools,
    skillInstructions: skillInstructions,
  );

  Stream<AgentStreamEvent> chatStream(
    List<ChatMessage> messages, {
    Map<String, dynamic>? context,
    List<ToolSpec>? tools,
    List<String>? skillInstructions,
  }) async* {
    final uri = config.resolveUri('/v1/chat');
    final request = http.Request('POST', uri)
      ..headers.addAll({
        'Content-Type': 'application/json',
        'Accept': 'text/event-stream',
        ...config.authHeaders(),
      })
      ..body = jsonEncode({
        'messages': messages.map((m) => m.toJson()).toList(),
        'context': context,
        'stream': true,
        if (tools != null && tools.isNotEmpty)
          'tools': tools.map((t) => t.toJson()).toList(),
        if (skillInstructions != null && skillInstructions.isNotEmpty)
          'skill_instructions': skillInstructions,
      });

    late final http.StreamedResponse response;
    try {
      response = await _client.send(request).timeout(config.streamTimeout);
    } on TimeoutException catch (e) {
      throw AgentApiException(
        code: AgentErrorCode.timeout,
        message: 'Chat stream timed out.',
        cause: e,
      );
    } catch (e) {
      if (isNetworkTransportError(e)) {
        throw AgentApiException(
          code: AgentErrorCode.networkError,
          message: 'Network error starting chat stream.',
          cause: e,
        );
      }
      rethrow;
    }

    if (response.statusCode != 200) {
      final errorBody = await response.stream.bytesToString();
      throw _parseErrorResponse(response.statusCode, errorBody);
    }

    try {
      final lines = response.stream
          .timeout(config.streamTimeout)
          .transform(utf8.decoder)
          .transform(const LineSplitter());

      await for (final line in lines) {
        if (line.isEmpty || line.startsWith(':')) {
          continue;
        }
        if (!line.startsWith('data:')) {
          continue;
        }
        final data = line.substring(5).trimLeft();
        if (data.isEmpty || data == '[DONE]') {
          continue;
        }
        final decoded = jsonDecode(data);
        if (decoded is! Map<String, dynamic>) {
          continue;
        }
        if (decoded.containsKey('error')) {
          throw AgentApiException.fromErrorEnvelope(decoded);
        }
        if (decoded.containsKey('delta')) {
          yield AgentStreamDelta(decoded['delta'] as String);
        } else if (decoded['tool_call'] is Map<String, dynamic>) {
          yield AgentStreamToolCall(
            ToolCall.fromJson(decoded['tool_call'] as Map<String, dynamic>),
          );
        } else if (decoded['done'] == true) {
          yield AgentStreamDone(decoded['model'] as String? ?? '');
        }
      }
    } on AgentApiException {
      rethrow;
    } on TimeoutException catch (e) {
      throw AgentApiException(
        code: AgentErrorCode.timeout,
        message: 'Chat stream timed out.',
        cause: e,
      );
    } on FormatException catch (e) {
      throw AgentApiException(
        code: AgentErrorCode.unknown,
        message: 'Malformed SSE event payload.',
        cause: e,
      );
    } catch (e) {
      if (isNetworkTransportError(e)) {
        throw AgentApiException(
          code: AgentErrorCode.networkError,
          message: 'Network error during chat stream.',
          cause: e,
        );
      }
      rethrow;
    }
  }

  Future<TranscriptionResult> transcribe(
    Uint8List audioBytes, {
    String filename = 'audio.wav',
    String mimeType = 'audio/wav',
    String language = 'en',
  }) async {
    final uri = config.resolveUri('/v1/stt');
    final request = http.MultipartRequest('POST', uri)
      ..headers.addAll(config.authHeaders())
      ..fields['language'] = language
      ..files.add(
        http.MultipartFile.fromBytes(
          'audio',
          audioBytes,
          filename: filename,
          contentType: http.MediaType.parse(mimeType),
        ),
      );

    try {
      final streamed = await _client.send(request).timeout(config.timeout);
      final response = await http.Response.fromStream(streamed);
      if (response.statusCode != 200) {
        throw _parseErrorResponse(response.statusCode, response.body);
      }
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return TranscriptionResult.fromJson(json);
    } on AgentApiException {
      rethrow;
    } on TimeoutException catch (e) {
      throw AgentApiException(
        code: AgentErrorCode.timeout,
        message: 'Speech transcription timed out.',
        cause: e,
      );
    } on FormatException catch (e) {
      throw AgentApiException(
        code: AgentErrorCode.unknown,
        message: 'Invalid transcription response payload.',
        cause: e,
      );
    } catch (e) {
      if (isNetworkTransportError(e)) {
        throw AgentApiException(
          code: AgentErrorCode.networkError,
          message: 'Network error during transcription.',
          cause: e,
        );
      }
      rethrow;
    }
  }

  Future<Uint8List> synthesize(String text, {String? voice}) async {
    final uri = config.resolveUri('/v1/tts');
    final body = jsonEncode({'text': text, 'voice': voice});
    try {
      final response = await _client
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'audio/wav',
              ...config.authHeaders(),
            },
            body: body,
          )
          .timeout(config.timeout);
      if (response.statusCode != 200) {
        throw _parseErrorResponse(response.statusCode, response.body);
      }
      return response.bodyBytes;
    } on AgentApiException {
      rethrow;
    } on TimeoutException catch (e) {
      throw AgentApiException(
        code: AgentErrorCode.timeout,
        message: 'Speech synthesis timed out.',
        cause: e,
      );
    } catch (e) {
      if (isNetworkTransportError(e)) {
        throw AgentApiException(
          code: AgentErrorCode.networkError,
          message: 'Network error during synthesis.',
          cause: e,
        );
      }
      rethrow;
    }
  }

  AgentApiException _parseErrorResponse(int statusCode, String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        return AgentApiException.fromErrorEnvelope(
          decoded,
          statusCode: statusCode,
        );
      }
    } catch (_) {
      // Non-JSON proxy or transport error body; fall back to status mapping.
    }
    return AgentApiException(
      code: AgentErrorCode.fromStatusCode(statusCode),
      message: 'Gateway request failed ($statusCode).',
      statusCode: statusCode,
    );
  }

  void close() {
    if (_ownsClient) {
      _client.close();
    }
  }
}
