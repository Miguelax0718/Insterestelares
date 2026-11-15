import '../domain/agent_exception.dart';
import '../domain/agent_models.dart';
import '../domain/agent_ports.dart';
import 'network_error.dart';

class ResilientAgentChatService implements AgentChatService {
  ResilientAgentChatService({
    required this._remote,
    required this._isRemoteConfigured,
  });

  final AgentChatService _remote;
  final bool _isRemoteConfigured;

  @override
  Future<AgentReply> send(
    List<ChatMessage> messages, {
    Map<String, dynamic>? context,
  }) async {
    if (!_isRemoteConfigured) {
      throw const AgentUnavailableException(
        message: 'Clinical agent gateway is not configured.',
      );
    }
    try {
      return await _remote.send(messages, context: context);
    } catch (e) {
      if (e is AgentApiException && !e.isFallbackEligible) {
        rethrow;
      }
      if (isFallbackEligibleError(e)) {
        throw AgentUnavailableException(
          message:
              'Clinical agent is unavailable (offline or gateway unreachable).',
          statusCode: e is AgentApiException ? e.statusCode : null,
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
  }) async* {
    if (!_isRemoteConfigured) {
      throw const AgentUnavailableException(
        message: 'Clinical agent gateway is not configured.',
      );
    }
    try {
      await for (final event in _remote.stream(messages, context: context)) {
        yield event;
      }
    } catch (e) {
      if (e is AgentApiException && !e.isFallbackEligible) {
        rethrow;
      }
      if (isFallbackEligibleError(e)) {
        throw AgentUnavailableException(
          message:
              'Clinical agent is unavailable (offline or gateway unreachable).',
          statusCode: e is AgentApiException ? e.statusCode : null,
          cause: e,
        );
      }
      rethrow;
    }
  }
}

class ResilientSpeechToTextService implements SpeechToTextService {
  ResilientSpeechToTextService({
    required this._remote,
    required this._local,
    required this._isRemoteConfigured,
  });

  final SpeechToTextService _remote;
  final SpeechToTextService _local;
  final bool _isRemoteConfigured;
  bool _activeLocal = false;

  @override
  Future<bool> isAvailable() async {
    if (_isRemoteConfigured && await _remote.isAvailable()) {
      return true;
    }
    return _local.isAvailable();
  }

  @override
  Future<void> startListening({String language = 'es'}) async {
    if (!_isRemoteConfigured) {
      _activeLocal = true;
      await _local.startListening(language: language);
      return;
    }
    try {
      _activeLocal = false;
      await _remote.startListening(language: language);
    } catch (e) {
      if (!isFallbackEligibleError(e)) {
        rethrow;
      }
      _activeLocal = true;
      await _local.startListening(language: language);
    }
  }

  @override
  Future<String> stopListening() async {
    if (_activeLocal) {
      _activeLocal = false;
      return _local.stopListening();
    }
    try {
      return await _remote.stopListening();
    } catch (e) {
      if (!isFallbackEligibleError(e)) {
        rethrow;
      }
      return _local.stopListening();
    }
  }

  @override
  Future<String> listen({
    String language = 'es',
    Duration maxDuration = const Duration(seconds: 15),
  }) async {
    if (!_isRemoteConfigured) {
      return _local.listen(language: language, maxDuration: maxDuration);
    }
    try {
      return await _remote.listen(language: language, maxDuration: maxDuration);
    } catch (e) {
      if (!isFallbackEligibleError(e)) {
        rethrow;
      }
      return _local.listen(language: language, maxDuration: maxDuration);
    }
  }

  @override
  Future<void> cancel() async {
    _activeLocal = false;
    await _remote.cancel();
    await _local.cancel();
  }

  @override
  Future<void> dispose() async {
    await _remote.dispose();
    await _local.dispose();
  }
}

class ResilientTextToSpeechService implements TextToSpeechService {
  ResilientTextToSpeechService({
    required this._remote,
    required this._local,
    required this._isRemoteConfigured,
  });

  final TextToSpeechService _remote;
  final TextToSpeechService _local;
  final bool _isRemoteConfigured;

  @override
  Future<void> speak(
    String text, {
    String? voice,
    String language = 'es-ES',
  }) async {
    if (!_isRemoteConfigured) {
      await _local.speak(text, voice: voice, language: language);
      return;
    }
    try {
      await _remote.speak(text, voice: voice, language: language);
    } catch (e) {
      if (!isFallbackEligibleError(e)) {
        rethrow;
      }
      await _local.speak(text, voice: voice, language: language);
    }
  }

  @override
  Future<void> stop() async {
    await _remote.stop();
    await _local.stop();
  }

  @override
  Future<void> dispose() async {
    await _remote.dispose();
    await _local.dispose();
  }
}
