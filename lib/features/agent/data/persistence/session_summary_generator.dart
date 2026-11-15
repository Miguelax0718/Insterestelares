import '../../domain/agent_contracts.dart';
import '../../domain/agent_models.dart';

/// Deterministic generator that builds and persists a compact
/// [MemoryKind.sessionSummary] entry when a clinical agent session closes.
class SessionSummaryGenerator {
  SessionSummaryGenerator(this._memoryStore);

  final MemoryStore _memoryStore;

  static const int _maxConcernChars = 120;
  static const int _maxConcerns = 3;

  Future<MemoryEntry?> summarize({
    required String astronautId,
    required List<ChatMessage> transcript,
    List<AuditEntry> audits = const [],
    DateTime? now,
  }) async {
    if (transcript.isEmpty) {
      return null;
    }

    final timestamp = (now ?? DateTime.now().toUtc()).toUtc();
    final concerns = <String>[];
    final tools = <String>[];
    final seenTools = <String>{};
    String? fallbackText;

    for (final message in transcript) {
      final trimmed = message.content.trim();
      if (trimmed.isNotEmpty) {
        fallbackText ??= trimmed;
      }
      if (message.role == ChatRole.user && trimmed.isNotEmpty) {
        if (concerns.length < _maxConcerns) {
          concerns.add(_compact(trimmed, _maxConcernChars));
        }
      } else if (message.role == ChatRole.assistant) {
        for (final call in message.toolCalls) {
          if (call.name.isNotEmpty && seenTools.add(call.name)) {
            tools.add(call.name);
          }
        }
      }
    }

    final relevantAudits = audits
        .where((audit) => audit.astronautId == astronautId)
        .toList(growable: false);

    final actionSummaries = <String>[];
    final tags = <String>{'session_summary'};
    for (final tool in tools) {
      tags.add(tool);
    }
    for (final audit in relevantAudits) {
      tags.add(audit.actionType);
      tags.add(audit.decision.wireName);
      final reasonSuffix =
          audit.reason != null && audit.reason!.trim().isNotEmpty
              ? ' (${_compact(audit.reason!.trim(), 60)})'
              : '';
      actionSummaries.add(
        '${audit.actionType}: ${audit.decision.wireName}$reasonSuffix',
      );
    }

    final parts = <String>[
      if (concerns.isNotEmpty) 'Concerns: ${concerns.join(' | ')}',
      if (tools.isNotEmpty) 'Tools: ${tools.join(', ')}',
      if (actionSummaries.isNotEmpty) 'Actions: ${actionSummaries.join('; ')}',
    ];

    final summary = parts.isNotEmpty
        ? parts.join('. ')
        : 'Session: ${_compact(fallbackText ?? 'completed', _maxConcernChars)}';

    final entry = MemoryEntry(
      id: 'session_${astronautId}_${timestamp.microsecondsSinceEpoch}',
      astronautId: astronautId,
      kind: MemoryKind.sessionSummary,
      summary: summary,
      createdAt: timestamp,
      tags: tags.toList(growable: false),
      data: <String, dynamic>{
        'message_count': transcript.length,
        'user_concerns': concerns,
        'tools_executed': tools,
        'audits': relevantAudits
            .map(
              (a) => <String, dynamic>{
                'id': a.id,
                'action_type': a.actionType,
                'decision': a.decision.wireName,
                if (a.reason != null) 'reason': a.reason,
              },
            )
            .toList(growable: false),
      },
    );

    return _memoryStore.save(entry);
  }

  String _compact(String input, int maxChars) {
    final normalized = input.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.length <= maxChars) {
      return normalized;
    }
    return '${normalized.substring(0, maxChars - 3)}...';
  }
}
