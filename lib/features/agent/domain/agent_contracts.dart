import 'dart:convert';

import 'agent_models.dart';

abstract final class ComponentIds {
  static const String vitalsCard = 'vitals_card';
  static const String telemetryChart = 'telemetry_chart';
  static const String crewStatus = 'crew_status';
  static const String statusReport = 'status_report';
  static const String evaReadiness = 'eva_readiness';
  static const String alertBanner = 'alert_banner';
  static const String spaceWeatherAlert = 'space_weather_alert';
  static const String pharmacyBatches = 'pharmacy_batches';
  static const String ramanRequest = 'raman_request';
  static const String medicationCheck = 'medication_check';
  static const String graybielQuestionnaire = 'graybiel_questionnaire';
  static const String pvtTest = 'pvt_test';
  static const String mptTest = 'mpt_test';
  static const String sansGrid = 'sans_grid';
  static const String sansContrast = 'sans_contrast';
  static const String sansFocus = 'sans_focus';
  static const String exerciseMonitor = 'exercise_monitor';
  static const String lbnpRamp = 'lbnp_ramp';
  static const String ultrasoundGuide = 'ultrasound_guide';
  static const String diaryRecorder = 'diary_recorder';
  static const String recommendations = 'recommendations';
  static const String confirmAction = 'confirm_action';

  static const Set<String> all = {
    vitalsCard,
    telemetryChart,
    crewStatus,
    statusReport,
    evaReadiness,
    alertBanner,
    spaceWeatherAlert,
    pharmacyBatches,
    ramanRequest,
    medicationCheck,
    graybielQuestionnaire,
    pvtTest,
    mptTest,
    sansGrid,
    sansContrast,
    sansFocus,
    exerciseMonitor,
    lbnpRamp,
    ultrasoundGuide,
    diaryRecorder,
    recommendations,
    confirmAction,
  };
}

enum ToolEffect { read, ui, consequential }

sealed class AgentComponentEvent {
  const AgentComponentEvent();

  const factory AgentComponentEvent.show(
    String id, [
    Map<String, dynamic> props,
  ]) = ShowComponentEvent;

  const factory AgentComponentEvent.hide(String id) = HideComponentEvent;
}

final class ShowComponentEvent extends AgentComponentEvent {
  const ShowComponentEvent(this.id, [this.props = const {}]);

  final String id;
  final Map<String, dynamic> props;
}

final class HideComponentEvent extends AgentComponentEvent {
  const HideComponentEvent(this.id);

  final String id;
}

abstract class AgentViewModel {
  const AgentViewModel({required this.componentId, required this.title});

  final String componentId;
  final String title;

  Map<String, dynamic> toProps();
}

abstract interface class AgentUiSink {
  void emit(AgentComponentEvent event);

  void submit(String componentId, Map<String, dynamic> result);
}

class ToolResult {
  const ToolResult({
    required this.ok,
    this.data = const {},
    this.error,
    this.uiEvents = const [],
  });

  const ToolResult.ok(this.data, {this.uiEvents = const []})
    : ok = true,
      error = null;

  const ToolResult.fail(String this.error, {this.data = const {}})
    : ok = false,
      uiEvents = const [];

  static const int maxWireChars = 4000;

  final bool ok;
  final Map<String, dynamic> data;
  final String? error;
  final List<AgentComponentEvent> uiEvents;

  String toWireJson() {
    final payload = <String, dynamic>{
      'ok': ok,
      if (ok) 'data': data else 'error': error,
    };
    final encoded = jsonEncode(payload);
    if (encoded.length <= maxWireChars) {
      return encoded;
    }
    var budget = (maxWireChars - 80).clamp(0, encoded.length);
    while (budget > 0) {
      final candidate = jsonEncode({
        'ok': ok,
        'preview': '${encoded.substring(0, budget)}...',
        'truncated': true,
      });
      if (candidate.length <= maxWireChars) {
        return candidate;
      }
      budget = (budget * 3) ~/ 4;
    }
    return jsonEncode({'ok': ok, 'truncated': true});
  }
}

enum MemoryKind {
  fact('fact'),
  sessionSummary('session_summary'),
  clinicalEvent('clinical_event');

  const MemoryKind(this.wireName);

  final String wireName;

  static MemoryKind fromWire(String value) {
    return MemoryKind.values.firstWhere(
      (k) => k.wireName == value,
      orElse: () => MemoryKind.fact,
    );
  }
}

class MemoryEntry {
  const MemoryEntry({
    required this.id,
    required this.astronautId,
    required this.kind,
    required this.summary,
    required this.createdAt,
    this.tags = const [],
    this.data = const {},
  });

  factory MemoryEntry.fromJson(Map<String, dynamic> json) {
    return MemoryEntry(
      id: json['id'] as String,
      astronautId: json['astronaut_id'] as String,
      kind: MemoryKind.fromWire(json['kind'] as String? ?? 'fact'),
      summary: json['summary'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      tags: (json['tags'] as List<dynamic>? ?? const []).cast<String>(),
      data: (json['data'] as Map<String, dynamic>?) ?? const {},
    );
  }

  final String id;
  final String astronautId;
  final MemoryKind kind;
  final String summary;
  final DateTime createdAt;
  final List<String> tags;
  final Map<String, dynamic> data;

  Map<String, dynamic> toJson() => {
    'id': id,
    'astronaut_id': astronautId,
    'kind': kind.wireName,
    'summary': summary,
    'created_at': createdAt.toUtc().toIso8601String(),
    'tags': tags,
    'data': data,
  };
}

abstract interface class MemoryStore {
  Future<List<MemoryEntry>> recall(
    String astronautId, {
    String? query,
    Set<MemoryKind>? kinds,
    int limit = 10,
  });

  Future<MemoryEntry> save(MemoryEntry entry);

  Future<List<MemoryEntry>> recentForPrompt(
    String astronautId, {
    int limit = 8,
  });
}

enum ConfirmationDecision {
  confirmed('confirmed'),
  rejected('rejected'),
  expired('expired');

  const ConfirmationDecision(this.wireName);

  final String wireName;

  static ConfirmationDecision fromWire(String value) {
    return ConfirmationDecision.values.firstWhere(
      (d) => d.wireName == value,
      orElse: () => ConfirmationDecision.rejected,
    );
  }
}

class ConsequentialAction {
  const ConsequentialAction({
    required this.id,
    required this.astronautId,
    required this.actionType,
    required this.description,
    required this.payload,
  });

  final String id;
  final String astronautId;
  final String actionType;
  final String description;
  final Map<String, dynamic> payload;

  Map<String, dynamic> toJson() => {
    'id': id,
    'astronaut_id': astronautId,
    'action_type': actionType,
    'description': description,
    'payload': payload,
  };
}

class AuditEntry {
  const AuditEntry({
    required this.id,
    required this.astronautId,
    required this.actionType,
    required this.description,
    required this.payload,
    required this.decision,
    required this.timestamp,
    this.reason,
  });

  factory AuditEntry.fromJson(Map<String, dynamic> json) {
    return AuditEntry(
      id: json['id'] as String,
      astronautId: json['astronaut_id'] as String,
      actionType: json['action_type'] as String,
      description: json['description'] as String,
      payload: (json['payload'] as Map<String, dynamic>?) ?? const {},
      decision: ConfirmationDecision.fromWire(
        json['decision'] as String? ?? 'rejected',
      ),
      timestamp: DateTime.parse(json['timestamp'] as String),
      reason: json['reason'] as String?,
    );
  }

  final String id;
  final String astronautId;
  final String actionType;
  final String description;
  final Map<String, dynamic> payload;
  final ConfirmationDecision decision;
  final DateTime timestamp;
  final String? reason;

  Map<String, dynamic> toJson() => {
    'id': id,
    'astronaut_id': astronautId,
    'action_type': actionType,
    'description': description,
    'payload': payload,
    'decision': decision.wireName,
    'timestamp': timestamp.toUtc().toIso8601String(),
    if (reason != null) 'reason': reason,
  };
}

abstract interface class AuditLog {
  Future<void> append(AuditEntry entry);

  Future<List<AuditEntry>> list({String? astronautId, int limit = 50});
}

abstract interface class ConfirmationGate {
  ConsequentialAction? get pending;

  Future<ConfirmationDecision> request(
    ConsequentialAction action, {
    required Future<Map<String, dynamic>> Function() onConfirmed,
  });

  Future<Map<String, dynamic>?> resolve(
    String actionId,
    ConfirmationDecision decision, {
    String? reason,
  });
}

abstract interface class AgentFlagsStore {
  Future<void> setFlag(
    String astronautId,
    String key,
    Map<String, dynamic> value,
  );

  Future<Map<String, dynamic>?> getFlag(String astronautId, String key);

  Future<Map<String, Map<String, dynamic>>> allForAstronaut(String astronautId);
}

class MedicationRequest {
  const MedicationRequest({
    required this.astronautId,
    required this.medication,
    required this.doseMg,
    required this.route,
    this.indication,
  });

  final String astronautId;
  final String medication;
  final double doseMg;
  final String route;
  final String? indication;
}

class MedicationCheck {
  const MedicationCheck({
    required this.allowed,
    required this.reasons,
    this.batchId,
    this.remainingUnits,
    this.suggestedAlternativeRoute,
  });

  final bool allowed;
  final List<String> reasons;
  final String? batchId;
  final int? remainingUnits;
  final String? suggestedAlternativeRoute;

  Map<String, dynamic> toJson() => {
    'allowed': allowed,
    'reasons': reasons,
    if (batchId != null) 'batch_id': batchId,
    if (remainingUnits != null) 'remaining_units': remainingUnits,
    if (suggestedAlternativeRoute != null)
      'suggested_alternative_route': suggestedAlternativeRoute,
  };
}

abstract interface class MedicationSafety {
  Future<MedicationCheck> validate(MedicationRequest request);
}

class ToolContext {
  ToolContext({
    required this.astronautId,
    required this.read,
    required this.ui,
    required this.confirm,
    required this.audit,
    required this.memory,
    required this.flags,
    required this.medication,
    DateTime? now,
  }) : now = now ?? DateTime.now().toUtc();

  final String astronautId;
  final T Function<T>(Object provider) read;
  final AgentUiSink ui;
  final ConfirmationGate confirm;
  final AuditLog audit;
  final MemoryStore memory;
  final AgentFlagsStore flags;
  final MedicationSafety medication;
  final DateTime now;
}

abstract class AgentTool {
  const AgentTool();

  String get name;
  String get description;
  Map<String, dynamic> get parameters;
  ToolEffect get effect => ToolEffect.read;

  ToolSpec toSpec() =>
      ToolSpec(name: name, description: description, parameters: parameters);

  Future<ToolResult> call(Map<String, dynamic> args, ToolContext ctx);
}

class DeterministicStep {
  const DeterministicStep({
    required this.prompt,
    this.options = const [],
    this.uiEvents = const [],
    this.isTerminal = false,
    this.verdict,
  });

  final String prompt;
  final List<String> options;
  final List<AgentComponentEvent> uiEvents;
  final bool isTerminal;
  final Map<String, dynamic>? verdict;
}

abstract interface class DeterministicFlow {
  String get skillId;

  Future<DeterministicStep> start(ToolContext ctx);

  Future<DeterministicStep> advance(String userInput, ToolContext ctx);
}

/// Optional extension for offline flows that can act on the very first
/// message (e.g. "I drank 500 ml") instead of only greeting. The
/// orchestrator calls [startWithQuery] instead of [start] when available.
abstract interface class QueryAwareDeterministicFlow
    implements DeterministicFlow {
  Future<DeterministicStep> startWithQuery(String query, ToolContext ctx);
}

class AgentSkill {
  const AgentSkill({
    required this.id,
    required this.instructions,
    required this.tools,
    this.componentIds = const [],
    this.triggers = const [],
    this.alwaysOn = false,
    this.offlineFlow,
  });

  final String id;
  final String instructions;
  final List<AgentTool> tools;
  final List<String> componentIds;
  final List<String> triggers;
  final bool alwaysOn;
  final DeterministicFlow? offlineFlow;
}

enum ProactiveSeverity { info, warning, critical }

class ProactiveEvent {
  const ProactiveEvent({
    required this.id,
    required this.astronautId,
    required this.severity,
    required this.kind,
    required this.spokenMessage,
    required this.createdAt,
    this.skillId,
    this.data = const {},
    this.uiEvents = const [],
  });

  final String id;
  final String astronautId;
  final ProactiveSeverity severity;
  final String kind;
  final String spokenMessage;
  final DateTime createdAt;
  final String? skillId;
  final Map<String, dynamic> data;
  final List<AgentComponentEvent> uiEvents;
}

abstract interface class AgentNotifier {
  Future<void> notify(ProactiveEvent event);
}

class ProactiveEmittedRecord {
  const ProactiveEmittedRecord({
    required this.timestamp,
    required this.severity,
  });

  final DateTime timestamp;
  final ProactiveSeverity severity;
}

/// Session-scoped deduplication and speech-budget store shared across
/// [ProactiveMonitor] and [AgentConversationOrchestrator] so cooldowns and
/// speech budgets survive provider rebuilds and panel reopens.
class ProactiveAlertStore {
  final Map<String, ProactiveEmittedRecord> _lastEmitted = {};
  final Map<String, ProactiveEmittedRecord> _lastSpoken = {};
  DateTime? _lastNonCriticalSpokenAt;

  static String keyFor(String astronautId, String kind) =>
      '$astronautId::$kind';

  DateTime? get lastNonCriticalSpokenAt => _lastNonCriticalSpokenAt;

  bool shouldEmit(
    ProactiveEvent candidate, {
    required DateTime now,
    required Duration cooldown,
  }) {
    return _passesCooldown(
      _lastEmitted[keyFor(candidate.astronautId, candidate.kind)],
      candidate.severity,
      now: now,
      cooldown: cooldown,
    );
  }

  void recordEmitted(ProactiveEvent event, {required DateTime now}) {
    _lastEmitted[keyFor(event.astronautId, event.kind)] =
        ProactiveEmittedRecord(timestamp: now, severity: event.severity);
  }

  bool shouldSpeak(
    ProactiveEvent candidate, {
    required DateTime now,
    required Duration cooldown,
  }) {
    return _passesCooldown(
      _lastSpoken[keyFor(candidate.astronautId, candidate.kind)],
      candidate.severity,
      now: now,
      cooldown: cooldown,
    );
  }

  bool canSpeakNonCritical({
    required DateTime now,
    required Duration budgetWindow,
  }) {
    final last = _lastNonCriticalSpokenAt;
    if (last == null) {
      return true;
    }
    return now.difference(last) >= budgetWindow;
  }

  void recordSpoken(ProactiveEvent event, {required DateTime now}) {
    _lastSpoken[keyFor(event.astronautId, event.kind)] = ProactiveEmittedRecord(
      timestamp: now,
      severity: event.severity,
    );
    if (event.severity != ProactiveSeverity.critical) {
      _lastNonCriticalSpokenAt = now;
    }
  }

  void recordNonCriticalDigestSpoken(
    Iterable<ProactiveEvent> events, {
    required DateTime now,
  }) {
    _lastNonCriticalSpokenAt = now;
    for (final event in events) {
      _lastSpoken[keyFor(event.astronautId, event.kind)] =
          ProactiveEmittedRecord(timestamp: now, severity: event.severity);
    }
  }

  void reset() {
    _lastEmitted.clear();
    _lastSpoken.clear();
    _lastNonCriticalSpokenAt = null;
  }

  static bool _passesCooldown(
    ProactiveEmittedRecord? previous,
    ProactiveSeverity severity, {
    required DateTime now,
    required Duration cooldown,
  }) {
    if (previous == null) {
      return true;
    }
    final elapsed = now.difference(previous.timestamp);
    if (elapsed >= cooldown) {
      return true;
    }
    return severity.index > previous.severity.index;
  }
}
