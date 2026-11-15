import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../data/agent_api_client.dart';
import '../data/local_speech_to_text_service.dart';
import '../data/local_text_to_speech_service.dart';
import '../data/remote_speech_to_text_service.dart';
import '../data/remote_text_to_speech_service.dart';
import '../data/resilient_agent_services.dart';
import '../domain/agent_config.dart';
import '../domain/agent_models.dart';
import '../domain/agent_ports.dart';

final agentConfigProvider = Provider<AgentConfig>(
  (ref) => const AgentConfig.fromEnvironment(),
);

final httpClientProvider = Provider<http.Client>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
});

final agentApiClientProvider = Provider<AgentApiClient>((ref) {
  final config = ref.watch(agentConfigProvider);
  final client = ref.watch(httpClientProvider);
  return AgentApiClient(config: config, client: client);
});

final remoteSpeechToTextProvider = Provider<SpeechToTextService>((ref) {
  final service = RemoteSpeechToTextService(
    client: ref.watch(agentApiClientProvider),
  );
  ref.onDispose(service.dispose);
  return service;
});

final localSpeechToTextProvider = Provider<SpeechToTextService>((ref) {
  final service = LocalSpeechToTextService();
  ref.onDispose(service.dispose);
  return service;
});

final speechToTextServiceProvider = Provider<SpeechToTextService>((ref) {
  final config = ref.watch(agentConfigProvider);
  return ResilientSpeechToTextService(
    remote: ref.watch(remoteSpeechToTextProvider),
    local: ref.watch(localSpeechToTextProvider),
    isRemoteConfigured: config.isConfigured,
  );
});

final remoteTextToSpeechProvider = Provider<TextToSpeechService>((ref) {
  final service = RemoteTextToSpeechService(
    client: ref.watch(agentApiClientProvider),
  );
  ref.onDispose(service.dispose);
  return service;
});

final localTextToSpeechProvider = Provider<TextToSpeechService>((ref) {
  final service = LocalTextToSpeechService();
  ref.onDispose(service.dispose);
  return service;
});

final textToSpeechServiceProvider = Provider<TextToSpeechService>((ref) {
  final config = ref.watch(agentConfigProvider);
  return ResilientTextToSpeechService(
    remote: ref.watch(remoteTextToSpeechProvider),
    local: ref.watch(localTextToSpeechProvider),
    isRemoteConfigured: config.isConfigured,
  );
});

final agentChatServiceProvider = Provider<AgentChatService>((ref) {
  final config = ref.watch(agentConfigProvider);
  return ResilientAgentChatService(
    remote: ref.watch(agentApiClientProvider),
    isRemoteConfigured: config.isConfigured,
  );
});

final agentHealthProvider = FutureProvider<HealthStatus>((ref) {
  return ref.watch(agentApiClientProvider).health();
});
