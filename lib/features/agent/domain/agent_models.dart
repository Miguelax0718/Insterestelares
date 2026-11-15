import 'package:flutter/foundation.dart';

enum ChatRole {
  user('user'),
  assistant('assistant'),
  tool('tool');

  const ChatRole(this.wireName);

  final String wireName;

  static ChatRole fromWire(String value) {
    return switch (value) {
      'user' => ChatRole.user,
      'assistant' => ChatRole.assistant,
      'tool' => ChatRole.tool,
      _ => throw FormatException('Unsupported chat role: $value'),
    };
  }
}

class ToolSpec {
  const ToolSpec({
    required this.name,
    required this.description,
    required this.parameters,
  });

  final String name;
  final String description;
  final Map<String, dynamic> parameters;

  Map<String, dynamic> toJson() => {
    'name': name,
    'description': description,
    'parameters': parameters,
  };
}

class ToolCall {
  const ToolCall({
    required this.id,
    required this.name,
    required this.arguments,
    this.invalidArguments = false,
  });

  factory ToolCall.fromJson(Map<String, dynamic> json) {
    final rawArgs = json['arguments'];
    final args = rawArgs is Map<String, dynamic>
        ? Map<String, dynamic>.unmodifiable(rawArgs)
        : const <String, dynamic>{};
    return ToolCall(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      arguments: args,
      invalidArguments: json['invalid_arguments'] as bool? ?? false,
    );
  }

  final String id;
  final String name;
  final Map<String, dynamic> arguments;
  final bool invalidArguments;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'arguments': arguments,
    if (invalidArguments) 'invalid_arguments': true,
  };

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is ToolCall &&
            other.id == id &&
            other.name == name &&
            other.invalidArguments == invalidArguments &&
            mapEquals(other.arguments, arguments);
  }

  @override
  int get hashCode =>
      Object.hash(id, name, invalidArguments, Object.hashAll(arguments.entries));

  @override
  String toString() => 'ToolCall(id: $id, name: $name, arguments: $arguments)';
}

class ChatMessage {
  const ChatMessage({
    required this.role,
    required this.content,
    this.toolCalls = const [],
    this.toolCallId,
  });

  const ChatMessage.assistantToolCalls(
    this.toolCalls, {
    String? content,
  }) : role = ChatRole.assistant,
       content = content ?? '',
       toolCallId = null;

  const ChatMessage.toolResult({
    required String this.toolCallId,
    required this.content,
  }) : role = ChatRole.tool,
       toolCalls = const [];

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    final rawCalls = json['tool_calls'] as List<dynamic>? ?? const [];
    return ChatMessage(
      role: ChatRole.fromWire(json['role'] as String),
      content: json['content'] as String? ?? '',
      toolCalls: rawCalls
          .whereType<Map<String, dynamic>>()
          .map(ToolCall.fromJson)
          .toList(growable: false),
      toolCallId: json['tool_call_id'] as String?,
    );
  }

  final ChatRole role;
  final String content;
  final List<ToolCall> toolCalls;
  final String? toolCallId;

  Map<String, dynamic> toJson() {
    if (role == ChatRole.tool) {
      return {
        'role': role.wireName,
        'tool_call_id': toolCallId,
        'content': content,
      };
    }
    if (toolCalls.isNotEmpty) {
      return {
        'role': role.wireName,
        'content': content.isEmpty ? null : content,
        'tool_calls': toolCalls.map((c) => c.toJson()).toList(),
      };
    }
    return {'role': role.wireName, 'content': content};
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is ChatMessage &&
            other.role == role &&
            other.content == content &&
            other.toolCallId == toolCallId &&
            listEquals(other.toolCalls, toolCalls);
  }

  @override
  int get hashCode =>
      Object.hash(role, content, toolCallId, Object.hashAll(toolCalls));

  @override
  String toString() => 'ChatMessage(role: ${role.wireName}, content: $content)';
}

class AgentReply {
  const AgentReply({
    required this.reply,
    required this.model,
    this.toolCalls = const [],
  });

  factory AgentReply.fromJson(Map<String, dynamic> json) {
    final rawCalls = json['tool_calls'] as List<dynamic>? ?? const [];
    return AgentReply(
      reply: json['reply'] as String? ?? '',
      model: json['model'] as String? ?? '',
      toolCalls: rawCalls
          .whereType<Map<String, dynamic>>()
          .map(ToolCall.fromJson)
          .toList(growable: false),
    );
  }

  final String reply;
  final String model;
  final List<ToolCall> toolCalls;

  bool get hasToolCalls => toolCalls.isNotEmpty;

  Map<String, dynamic> toJson() => {
    'reply': reply,
    'model': model,
    if (toolCalls.isNotEmpty)
      'tool_calls': toolCalls.map((c) => c.toJson()).toList(),
  };

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is AgentReply &&
            other.reply == reply &&
            other.model == model &&
            listEquals(other.toolCalls, toolCalls);
  }

  @override
  int get hashCode => Object.hash(reply, model, Object.hashAll(toolCalls));

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

final class AgentStreamToolCall extends AgentStreamEvent {
  const AgentStreamToolCall(this.toolCall);

  final ToolCall toolCall;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is AgentStreamToolCall && other.toolCall == toolCall;
  }

  @override
  int get hashCode => toolCall.hashCode;

  @override
  String toString() => 'AgentStreamToolCall($toolCall)';
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
    return identical(this, other) ||
        other is HealthStatus &&
            other.status == status &&
            other.version == version &&
            mapEquals(other.providers, providers);
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
