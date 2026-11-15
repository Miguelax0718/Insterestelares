import 'agent_exception.dart';

class AgentConfig {
  const AgentConfig({
    this.baseUrl = '',
    this.apiKey = '',
    this.timeout = const Duration(seconds: 30),
    this.streamTimeout = const Duration(seconds: 90),
  });

  const AgentConfig.fromEnvironment({
    this.timeout = const Duration(seconds: 30),
    this.streamTimeout = const Duration(seconds: 90),
  }) : baseUrl = const String.fromEnvironment('ASTRAMED_API_URL'),
       apiKey = const String.fromEnvironment('ASTRAMED_API_KEY');

  final String baseUrl;
  final String apiKey;
  final Duration timeout;
  final Duration streamTimeout;

  bool get isConfigured => baseUrl.trim().isNotEmpty;

  Uri resolveUri(String path) {
    final trimmed = baseUrl.trim();
    if (trimmed.isEmpty) {
      throw const AgentUnavailableException(
        message: 'ASTRAMED_API_URL is not configured.',
      );
    }
    final normalizedBase = trimmed.endsWith('/')
        ? trimmed.substring(0, trimmed.length - 1)
        : trimmed;
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$normalizedBase$normalizedPath');
  }

  Map<String, String> authHeaders() {
    final key = apiKey.trim();
    if (key.isEmpty) {
      return const {};
    }
    return {'X-AstraMed-Key': key};
  }
}
