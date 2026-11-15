import 'package:astramed/features/05_clinical_triage/agent/operational_readiness_engine.dart';
import 'package:astramed/features/05_clinical_triage/models/triage_decision.dart';
import 'package:astramed/features/agent/domain/agent_contracts.dart';
import 'package:astramed/features/crew/models/astronaut_profile.dart';
import 'package:astramed/features/crew/presentation/providers/crew_provider.dart';

class EvaReadinessViewModel extends AgentViewModel {
  const EvaReadinessViewModel({
    required this.astronautId,
    required this.astronautName,
    required this.activityType,
    required this.authorized,
    required this.priority,
    required this.blockingReasons,
    required this.cautionReasons,
    required this.immediateActions,
    required this.requiredSupplies,
    required this.evaluatedAt,
    this.metrics = const {},
    super.title = 'Operational Readiness Assessment',
  }) : super(componentId: ComponentIds.evaReadiness);

  factory EvaReadinessViewModel.fromVerdict(
    OperationalReadinessVerdict verdict, {
    required String astronautName,
  }) {
    return EvaReadinessViewModel(
      title: '${verdict.activityLabel} Readiness ($astronautName)',
      astronautId: verdict.astronautId,
      astronautName: astronautName,
      activityType: verdict.activityType,
      authorized: verdict.authorized,
      priority: verdict.priority,
      blockingReasons: verdict.blockingReasons,
      cautionReasons: verdict.cautionReasons,
      immediateActions: verdict.immediateActions,
      requiredSupplies: verdict.requiredSupplies,
      evaluatedAt: verdict.evaluatedAt.toUtc().toIso8601String(),
      metrics: verdict.metricsSnapshot,
    );
  }

  factory EvaReadinessViewModel.fromProps(Map<String, dynamic> props) {
    final astronautId = props['astronaut_id'];
    final activityType = props['activity_type'];
    final authorized = props['authorized'];
    final priorityRaw = props['priority'];

    if (astronautId is! String || astronautId.trim().isEmpty) {
      throw const FormatException(
        'eva_readiness requires non-empty "astronaut_id".',
      );
    }
    if (activityType is! String ||
        (activityType != 'pre_eva' && activityType != 'landing')) {
      throw const FormatException(
        'eva_readiness "activity_type" must be "pre_eva" or "landing".',
      );
    }
    if (authorized is! bool) {
      throw const FormatException(
        'eva_readiness requires boolean "authorized".',
      );
    }
    if (priorityRaw is! String) {
      throw const FormatException(
        'eva_readiness requires string "priority".',
      );
    }

    final priority = TriagePriority.values.where(
      (p) => p.name == priorityRaw.trim().toLowerCase(),
    );
    if (priority.isEmpty) {
      throw FormatException(
        'eva_readiness invalid priority "$priorityRaw".',
      );
    }

    return EvaReadinessViewModel(
      title: props['title'] as String? ?? 'Operational Readiness Assessment',
      astronautId: astronautId.trim(),
      astronautName: props['astronaut_name'] as String? ?? astronautId.trim(),
      activityType: activityType,
      authorized: authorized,
      priority: priority.first,
      blockingReasons: _requireStringList(props['blocking_reasons']),
      cautionReasons: _requireStringList(props['caution_reasons']),
      immediateActions: _requireStringList(props['immediate_actions']),
      requiredSupplies: _requireStringList(props['required_supplies']),
      evaluatedAt: props['evaluated_at'] as String? ?? '',
      metrics: props['metrics'] is Map
          ? Map<String, dynamic>.from(props['metrics'] as Map)
          : const {},
    );
  }

  final String astronautId;
  final String astronautName;
  final String activityType;
  final bool authorized;
  final TriagePriority priority;
  final List<String> blockingReasons;
  final List<String> cautionReasons;
  final List<String> immediateActions;
  final List<String> requiredSupplies;
  final String evaluatedAt;
  final Map<String, dynamic> metrics;

  @override
  Map<String, dynamic> toProps() => {
        'component_id': componentId,
        'title': title,
        'astronaut_id': astronautId,
        'astronaut_name': astronautName,
        'activity_type': activityType,
        'authorized': authorized,
        'priority': priority.name,
        'blocking_reasons': blockingReasons,
        'caution_reasons': cautionReasons,
        'immediate_actions': immediateActions,
        'required_supplies': requiredSupplies,
        'evaluated_at': evaluatedAt,
        'metrics': metrics,
      };
}

class EvaluateReadinessTool extends AgentTool {
  const EvaluateReadinessTool([
    this._engine = const OperationalReadinessEngine(),
  ]);

  final OperationalReadinessEngine _engine;

  @override
  String get name => 'evaluate_readiness';

  @override
  String get description =>
      'Evaluate Pre-EVA or Planetary Landing operational readiness across vestibular, neurocognitive, cardiovascular, respiratory, and radiation criteria.';

  @override
  ToolEffect get effect => ToolEffect.ui;

  @override
  Map<String, dynamic> get parameters => const {
        'type': 'object',
        'properties': {
          'astronaut_id': {'type': 'string'},
          'activity_type': {
            'type': 'string',
            'enum': ['pre_eva', 'landing'],
          },
          'graybiel_score': {'type': 'integer', 'minimum': 0},
          'lrm50_ms': {'type': 'number', 'minimum': 0},
          'pvt_lapses': {'type': 'integer', 'minimum': 0},
          'sleep_hours': {'type': 'number', 'minimum': 0},
          'uncompensated_sedative': {'type': 'boolean'},
          'space_weather_critical': {'type': 'boolean'},
        },
      };

  @override
  Future<ToolResult> call(Map<String, dynamic> args, ToolContext ctx) async {
    final rawActivity = args['activity_type']?.toString() ?? 'pre_eva';
    final String activityType;
    try {
      activityType = OperationalReadinessEngine.normalizeActivityType(
        rawActivity,
      );
    } on ArgumentError catch (e) {
      return ToolResult.fail(e.message?.toString() ?? e.toString());
    }

    final profile = _resolveAstronaut(ctx, args['astronaut_id'] as String?);
    if (profile == null) {
      return ToolResult.fail(
        'Astronaut ${args['astronaut_id'] ?? ctx.astronautId} not found in crew state.',
      );
    }

    final flags = await ctx.flags.allForAstronaut(profile.id);
    final verdict = _engine.evaluate(
      profile: profile,
      activityType: activityType,
      graybielScore: (args['graybiel_score'] as num?)?.toInt(),
      lrm50Ms: (args['lrm50_ms'] as num?)?.toDouble(),
      pvtLapses: (args['pvt_lapses'] as num?)?.toInt(),
      sleepHoursOverride: (args['sleep_hours'] as num?)?.toDouble(),
      hasUncompensatedSedative: args['uncompensated_sedative'] as bool?,
      spaceWeatherCritical: args['space_weather_critical'] as bool?,
      activeFlags: flags,
      now: ctx.now,
    );

    final vm = EvaReadinessViewModel.fromVerdict(
      verdict,
      astronautName: profile.name,
    );
    final event = AgentComponentEvent.show(
      ComponentIds.evaReadiness,
      vm.toProps(),
    );
    ctx.ui.emit(event);
    return ToolResult.ok(verdict.toJson(), uiEvents: [event]);
  }
}

int _blockEvaSequence = 0;

class BlockEvaTool extends AgentTool {
  const BlockEvaTool();

  @override
  String get name => 'block_eva';

  @override
  String get description =>
      'Place an operational hold (eva_blocked flag) on Pre-EVA or Landing duty for a crew member. Requires crew confirmation.';

  @override
  ToolEffect get effect => ToolEffect.consequential;

  @override
  Map<String, dynamic> get parameters => const {
        'type': 'object',
        'required': ['reason'],
        'properties': {
          'astronaut_id': {'type': 'string'},
          'reason': {'type': 'string'},
          'activity_type': {
            'type': 'string',
            'enum': ['pre_eva', 'landing', 'all'],
          },
          'duration_hours': {'type': 'number', 'minimum': 0.5},
        },
      };

  @override
  Future<ToolResult> call(Map<String, dynamic> args, ToolContext ctx) async {
    final targetId = (args['astronaut_id'] as String?)?.trim().isNotEmpty == true
        ? (args['astronaut_id'] as String).trim()
        : ctx.astronautId;
    final reason = (args['reason'] as String? ?? '').trim();
    if (reason.isEmpty) {
      return const ToolResult.fail('reason must be a non-empty string.');
    }

    final rawActivity =
        (args['activity_type'] as String? ?? 'pre_eva').trim().toLowerCase();
    final String activityType;
    if (rawActivity == 'all') {
      activityType = 'all';
    } else {
      try {
        activityType = OperationalReadinessEngine.normalizeActivityType(
          rawActivity,
        );
      } on ArgumentError catch (e) {
        return ToolResult.fail(e.message?.toString() ?? e.toString());
      }
    }

    final durationHours = (args['duration_hours'] as num?)?.toDouble() ?? 24.0;
    if (durationHours <= 0) {
      return const ToolResult.fail('duration_hours must be greater than zero.');
    }

    final timestamp = ctx.now.toUtc().toIso8601String();
    final expiresAt = ctx.now
        .toUtc()
        .add(Duration(minutes: (durationHours * 60).round()))
        .toIso8601String();
    _blockEvaSequence++;
    final actionId =
        'block-eva-$targetId-${ctx.now.microsecondsSinceEpoch}-$_blockEvaSequence';

    final action = ConsequentialAction(
      id: actionId,
      astronautId: targetId,
      actionType: 'block_eva',
      description:
          'Block $activityType for $targetId (${durationHours.toStringAsFixed(0)}h): $reason',
      payload: {
        'astronaut_id': targetId,
        'reason': reason,
        'activity_type': activityType,
        'duration_hours': durationHours,
        'timestamp': timestamp,
      },
    );

    final decision = await ctx.confirm.request(
      action,
      onConfirmed: () async {
        final flagValue = <String, dynamic>{
          'blocked': true,
          'reason': reason,
          'activity_type': activityType,
          'duration_hours': durationHours,
          'timestamp': timestamp,
          'expires_at': expiresAt,
        };
        await ctx.flags.setFlag(targetId, 'eva_blocked', flagValue);
        return flagValue;
      },
    );

    if (decision != ConfirmationDecision.confirmed) {
      return ToolResult.ok({
        'confirmed': false,
        'decision': decision.wireName,
        'applied': false,
        'astronaut_id': targetId,
        'reason': reason,
        'activity_type': activityType,
      });
    }

    return ToolResult.ok({
      'confirmed': true,
      'decision': decision.wireName,
      'applied': true,
      'astronaut_id': targetId,
      'reason': reason,
      'activity_type': activityType,
      'duration_hours': durationHours,
      'timestamp': timestamp,
      'expires_at': expiresAt,
    });
  }
}

enum _ReadinessFlowStage { idle, awaitingActivity, awaitingSymptoms }

class ReadinessOfflineFlow implements DeterministicFlow {
  ReadinessOfflineFlow([
    this._engine = const OperationalReadinessEngine(),
  ]);

  final OperationalReadinessEngine _engine;
  final Map<String, _ReadinessFlowStage> _stages = {};
  final Map<String, String> _activities = {};

  @override
  String get skillId => 'readiness';

  @override
  Future<DeterministicStep> start(ToolContext ctx) async {
    _stages[ctx.astronautId] = _ReadinessFlowStage.awaitingActivity;
    _activities.remove(ctx.astronautId);
    return const DeterministicStep(
      prompt:
          'Offline operational readiness check: select Pre-EVA or Planetary Landing.',
      options: ['Pre-EVA', 'Planetary Landing'],
    );
  }

  @override
  Future<DeterministicStep> advance(String userInput, ToolContext ctx) async {
    final stage = _stages[ctx.astronautId] ?? _ReadinessFlowStage.idle;
    if (stage == _ReadinessFlowStage.idle) {
      return start(ctx);
    }

    final normalized = userInput.trim().toLowerCase();

    if (stage == _ReadinessFlowStage.awaitingActivity) {
      final String? activity;
      if (normalized.contains('land') || normalized.contains('aterriz')) {
        activity = 'landing';
      } else if (normalized.contains('eva')) {
        activity = 'pre_eva';
      } else {
        activity = null;
      }

      if (activity == null) {
        return const DeterministicStep(
          prompt: 'Please choose Pre-EVA or Planetary Landing.',
          options: ['Pre-EVA', 'Planetary Landing'],
        );
      }

      _activities[ctx.astronautId] = activity;
      _stages[ctx.astronautId] = _ReadinessFlowStage.awaitingSymptoms;
      return const DeterministicStep(
        prompt:
            'Any space motion sickness symptoms (Graybiel >= 5), severe fatigue, or uncompensated sedative? Reply "Nominal" or describe symptoms.',
        options: [
          'Nominal (no symptoms)',
          'Motion sickness (Graybiel >= 5)',
          'Fatigue / sedative',
        ],
      );
    }

    final profile = _resolveAstronaut(ctx, null);
    if (profile == null) {
      _stages[ctx.astronautId] = _ReadinessFlowStage.idle;
      return const DeterministicStep(
        prompt: 'Unable to evaluate readiness: astronaut profile unavailable.',
        isTerminal: true,
      );
    }

    int? graybielScore;
    double? lrm50Ms;
    bool? uncompensatedSedative;

    final graybielMatch = RegExp(r'graybiel[^0-9]*(\d+)').firstMatch(normalized);
    if (graybielMatch != null) {
      graybielScore = int.tryParse(graybielMatch.group(1)!);
    } else if (normalized.contains('motion') ||
        normalized.contains('sickness') ||
        normalized.contains('mareo') ||
        normalized.contains('nausea') ||
        normalized.contains('vomit')) {
      graybielScore = 6;
    }

    if (normalized.contains('fatigue') || normalized.contains('fatiga')) {
      lrm50Ms = 320.0;
    }
    if (normalized.contains('sedative') || normalized.contains('sedante')) {
      uncompensatedSedative = true;
    }

    final activity = _activities[ctx.astronautId] ?? 'pre_eva';
    final flags = await ctx.flags.allForAstronaut(profile.id);
    final verdict = _engine.evaluate(
      profile: profile,
      activityType: activity,
      graybielScore: graybielScore,
      lrm50Ms: lrm50Ms,
      hasUncompensatedSedative: uncompensatedSedative,
      activeFlags: flags,
      now: ctx.now,
    );

    final vm = EvaReadinessViewModel.fromVerdict(
      verdict,
      astronautName: profile.name,
    );
    final event = AgentComponentEvent.show(
      ComponentIds.evaReadiness,
      vm.toProps(),
    );
    ctx.ui.emit(event);

    _stages[ctx.astronautId] = _ReadinessFlowStage.idle;
    _activities.remove(ctx.astronautId);

    final String summaryPrompt;
    if (verdict.authorized) {
      final note = verdict.cautionReasons.isEmpty
          ? 'All criteria nominal.'
          : 'Cautions: ${verdict.cautionReasons.join(' ')}';
      summaryPrompt =
          '${verdict.activityLabel} authorized (${verdict.priority.name}) for ${profile.name}. $note';
    } else {
      summaryPrompt =
          '${verdict.activityLabel} blocked (${verdict.priority.name}) for ${profile.name}: ${verdict.blockingReasons.join(' ')}';
    }

    return DeterministicStep(
      prompt: summaryPrompt,
      uiEvents: [event],
      isTerminal: true,
      verdict: verdict.toJson(),
    );
  }
}

List<AgentSkill> triageAgentSkills({
  OperationalReadinessEngine? readinessEngine,
}) {
  final engine = readinessEngine ?? const OperationalReadinessEngine();
  return [
    AgentSkill(
      id: 'readiness',
      instructions:
          'Call evaluate_readiness for Pre-EVA or Planetary Landing clearance using deterministic clinical thresholds. '
          'Never clear an astronaut if evaluate_readiness returns authorized=false. '
          'Use block_eva only after explicit crew confirmation.',
      tools: [
        EvaluateReadinessTool(engine),
        const BlockEvaTool(),
      ],
      componentIds: const [ComponentIds.evaReadiness],
      triggers: const [
        'eva',
        'pre-eva',
        'pre_eva',
        'landing',
        'aterrizaje',
        'readiness',
        'aptitud',
        'clearance',
        'block eva',
        'bloquear eva',
      ],
      offlineFlow: ReadinessOfflineFlow(engine),
    ),
  ];
}

AstronautProfile? _resolveAstronaut(ToolContext ctx, String? requestedId) {
  final id = (requestedId != null && requestedId.trim().isNotEmpty)
      ? requestedId.trim()
      : ctx.astronautId;
  try {
    final crew = ctx.read<List<AstronautProfile>>(crewMembersProvider);
    for (final member in crew) {
      if (member.id == id) {
        return member;
      }
    }
    if (requestedId == null && crew.isNotEmpty) {
      return crew.first;
    }
    if (crew.isEmpty) {
      return null;
    }
  } catch (_) {
    // Fall back to selectedAstronautProvider if crewMembersProvider is unavailable.
  }
  try {
    final selected = ctx.read<AstronautProfile>(selectedAstronautProvider);
    if (requestedId == null || selected.id == id) {
      return selected;
    }
  } catch (_) {}
  return null;
}

List<String> _requireStringList(Object? raw) {
  if (raw == null) {
    return const [];
  }
  if (raw is! List) {
    throw const FormatException('Expected list of strings in eva_readiness props.');
  }
  return raw.map((e) => e.toString()).toList(growable: false);
}
