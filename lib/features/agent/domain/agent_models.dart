enum ChatRole {
  user('user'),
  assistant('assistant');

  const ChatRole(this.wireName);

  final String wireName;

  static ChatRole fromWire(String value) {
    return switch (value) {
      'user' => ChatRole.user,
      'assistant' => ChatRole.assistant,
      _ => throw FormatException('Unsupported chat role: $value'),
    };
  }
}

class ChatMessage {
  const ChatMessage({required this.role, required this.content});

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      role: ChatRole.fromWire(json['role'] as String),
      content: json['content'] as String,
    );
  }

  final ChatRole role;
  final String content;

  Map<String, dynamic> toJson() => {'role': role.wireName, 'content': content};

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is ChatMessage && other.role == role && other.content == content;
  }

  @override
  int get hashCode => Object.hash(role, content);

  @override
  String toString() => 'ChatMessage(role: ${role.wireName}, content: $content)';
}

class AgentReply {
  const AgentReply({required this.reply, required this.model});

  factory AgentReply.fromJson(Map<String, dynamic> json) {
    return AgentReply(
      reply: json['reply'] as String,
      model: json['model'] as String,
    );
  }

  final String reply;
  final String model;

  Map<String, dynamic> toJson() => {'reply': reply, 'model': model};

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is AgentReply && other.reply == reply && other.model == model;
  }

  @override
  int get hashCode => Object.hash(reply, model);

  @override
  String toString() => 'AgentReply(model: $model, reply: $reply)';
}

sealed class AgentStreamEvent {
  const AgentStreamEvent();
}

final class AgentStreamDelta extends AgentStreamEvent {
  const AgentStreamDelta(this.delta);

  final String delta;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is AgentStreamDelta && other.delta == delta;
  }

  @override
  int get hashCode => delta.hashCode;

  @override
  String toString() => 'AgentStreamDelta($delta)';
}

final class AgentStreamDone extends AgentStreamEvent {
  const AgentStreamDone(this.model);

  final String model;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is AgentStreamDone && other.model == model;
  }

  @override
  int get hashCode => model.hashCode;

  @override
  String toString() => 'AgentStreamDone($model)';
}

class HealthStatus {
  const HealthStatus({
    required this.status,
    required this.version,
    required this.providers,
  });

  factory HealthStatus.fromJson(Map<String, dynamic> json) {
    final rawProviders = json['providers'] as Map<String, dynamic>? ?? const {};
    return HealthStatus(
      status: json['status'] as String,
      version: json['version'] as String,
      providers: rawProviders.map(
        (key, value) => MapEntry(key, value.toString()),
      ),
    );
  }

  final String status;
  final String version;
  final Map<String, String> providers;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! HealthStatus) return false;
    if (other.status != status || other.version != version) return false;
    if (other.providers.length != providers.length) return false;
    for (final entry in providers.entries) {
      if (other.providers[entry.key] != entry.value) return false;
    }
    return true;
  }

  @override
  int get hashCode =>
      Object.hash(status, version, Object.hashAll(providers.entries));
}

class TranscriptionResult {
  const TranscriptionResult({
    required this.text,
    required this.language,
    required this.durationSeconds,
  });

  factory TranscriptionResult.fromJson(Map<String, dynamic> json) {
    return TranscriptionResult(
      text: json['text'] as String,
      language: json['language'] as String,
      durationSeconds: (json['duration_s'] as num).toDouble(),
    );
  }

  final String text;
  final String language;
  final double durationSeconds;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is TranscriptionResult &&
            other.text == text &&
            other.language == language &&
            other.durationSeconds == durationSeconds;
  }

  @override
  int get hashCode => Object.hash(text, language, durationSeconds);
}
