import 'agent_models.dart';

abstract interface class AgentChatService {
  Future<AgentReply> send(
    List<ChatMessage> messages, {
    Map<String, dynamic>? context,
  });

  Stream<AgentStreamEvent> stream(
    List<ChatMessage> messages, {
    Map<String, dynamic>? context,
  });
}

abstract interface class SpeechToTextService {
  Future<bool> isAvailable();

  Future<void> startListening({String language = 'es'});

  Future<String> stopListening();

  Future<String> listen({
    String language = 'es',
    Duration maxDuration = const Duration(seconds: 15),
  });

  Future<void> cancel();

  Future<void> dispose();
}

abstract interface class TextToSpeechService {
  Future<void> speak(String text, {String? voice, String language = 'es-ES'});

  Future<void> stop();

  Future<void> dispose();
}
