import 'agent_models.dart';

abstract interface class AgentChatService {
  Future<AgentReply> send(
    List<ChatMessage> messages, {
    Map<String, dynamic>? context,
    List<ToolSpec>? tools,
    List<String>? skillInstructions,
  });

  Stream<AgentStreamEvent> stream(
    List<ChatMessage> messages, {
    Map<String, dynamic>? context,
    List<ToolSpec>? tools,
    List<String>? skillInstructions,
  });
}

abstract interface class SpeechToTextService {
  Future<bool> isAvailable();

  Future<void> startListening({String language = 'en'});

  Future<String> stopListening();

  Future<String> listen({
    String language = 'en',
    Duration maxDuration = const Duration(seconds: 15),
  });

  Future<void> cancel();

  Future<void> dispose();
}

abstract interface class TextToSpeechService {
  Future<void> speak(String text, {String? voice, String language = 'en-US'});

  Future<void> stop();

  Future<void> dispose();
}

/// Optional speaking-state signal exposed by TTS wrappers/services so
/// hands-free capture can avoid self-transcription while the agent speaks.
abstract interface class TtsSpeakingSignal {
  bool get isSpeaking;

  Stream<bool> get isSpeakingStream;
}

/// Optional continuous listening capability for on-device STT fallback.
abstract interface class ContinuousSpeechToTextService {
  Future<bool> isAvailable();

  Future<void> startContinuous({
    String language = 'en',
    required void Function(String transcript) onTranscript,
    void Function(Object error)? onError,
  });

  Future<void> stopContinuous();
}
