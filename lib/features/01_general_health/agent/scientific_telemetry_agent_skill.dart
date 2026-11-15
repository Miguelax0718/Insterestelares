import 'package:astramed/features/01_general_health/agent/general_health_skills.dart';
import 'package:astramed/features/01_general_health/domain/scientific_criteria_engine.dart';
import 'package:astramed/features/01_general_health/domain/telemetry_view_contracts.dart';
import 'package:astramed/features/01_general_health/presentation/providers/telemetry_panel_provider.dart';
import 'package:astramed/features/05_clinical_triage/domain/apollo_triage_engine.dart';
import 'package:astramed/features/05_clinical_triage/models/triage_decision.dart';
import 'package:astramed/features/agent/domain/agent_contracts.dart';
import 'package:astramed/features/crew/models/astronaut_profile.dart';
import 'package:astramed/features/crew/presentation/providers/crew_provider.dart';
import 'package:astramed/features/telemetry/presentation/providers/telemetry_provider.dart';

/// Exporta el skill del agente que integra el motor de criterios científicos
/// contextuales y el triaje determinista ADA + APOLO con la telemetría en vivo.
List<AgentSkill> scientificTelemetryAgentSkills() {
  return [
    AgentSkill(
      id: 'scientific_telemetry_criteria',
      instructions:
          'Use evaluate_scientific_vitals_criteria when asked for contextual physiological criteria across rest, sleep, or physical activity, or run_ada_apollo_triage when evaluating specific aerospace symptoms under ADA + APOLO protocols.',
      tools: const [
        _EvaluateScientificVitalsCriteriaTool(),
        _RunAdaApolloTriageTool(),
      ],
      componentIds: const [
        ComponentIds.vitalsCard,
        ComponentIds.alertBanner,
      ],
      triggers: const [
        'criterio',
        'criteria',
        'contexto',
        'reposo',
        'ada',
        'apolo',
        'vitales detallados',
        'scientific',
      ],
      offlineFlow: const ScientificTelemetryOfflineFlow(),
    ),
  ];
}

class _EvaluateScientificVitalsCriteriaTool extends AgentTool {
  const _EvaluateScientificVitalsCriteriaTool();

  @override
  String get name => 'evaluate_scientific_vitals_criteria';

  @override
  String get description =>
      'Evaluates all 7 core vital signs plus hydration and bimodal HRV contextually (rest, sleep, or physical activity) against NASA-STD-3001, AHA/ACC, ADA, and ATS/ERS criteria.';

  @override
  ToolEffect get effect => ToolEffect.ui;

  @override
  Map<String, dynamic> get parameters => const {
        'type': 'object',
        'properties': {
          'astronaut_id': {
            'type': 'string',
            'description': 'Astronaut ID; defaults to the active crew member.',
          },
          'activity_context': {
            'type': 'string',
            'enum': ['auto', 'rest', 'sleep', 'physical_activity'],
            'description':
                'Contextual state for evaluation; defaults to auto via bimodal actigraphy.',
          },
        },
      };

  @override
  Future<ToolResult> call(Map<String, dynamic> args, ToolContext ctx) async {
    final profile = _resolveAstronaut(ctx, args['astronaut_id'] as String?);
    final telemetry = _tryRead<TelemetryState>(ctx, telemetryProvider);
    final snapshot =
        _tryRead<TelemetrySeriesSnapshot>(ctx, telemetrySeriesSnapshotProvider);

    final output = _buildEvaluationOutput(
      profile: profile,
      telemetry: telemetry,
      snapshot: snapshot,
      requestedContext: args['activity_context'] as String?,
    );

    return ToolResult.ok(output.data, uiEvents: output.uiEvents);
  }
}

class _RunAdaApolloTriageTool extends AgentTool {
  const _RunAdaApolloTriageTool();

  @override
  String get name => 'run_ada_apollo_triage';

  @override
  String get description =>
      'Runs deterministic ADA + APOLO clinical triage combining reported symptoms, live astronaut telemetry, and the active space operational environment.';

  @override
  ToolEffect get effect => ToolEffect.ui;

  @override
  Map<String, dynamic> get parameters => const {
        'type': 'object',
        'required': ['query'],
        'properties': {
          'query': {
            'type': 'string',
            'description': 'Symptom description or clinical triage query.',
          },
          'astronaut_id': {'type': 'string'},
          'environment': {
            'type': 'string',
            'enum': ['spaceStation', 'spacecraft', 'rover', 'planetaryBase'],
          },
        },
      };

  @override
  Future<ToolResult> call(Map<String, dynamic> args, ToolContext ctx) async {
    final query = (args['query'] as String?)?.trim() ?? '';
    if (query.isEmpty) {
      return const ToolResult.fail(
        'Missing required parameter "query" for ADA + APOLO triage.',
      );
    }

    final profile = _resolveAstronaut(ctx, args['astronaut_id'] as String?);
    final env = _resolveEnvironment(ctx, args['environment'] as String?);
    final reply = ApolloTriageEngine.processQuery(
      query: query,
      astronaut: profile,
      environment: env,
    );

    final priority = reply.triageLevel ?? TriagePriority.green;
    final uiEvents = <AgentComponentEvent>[];
    if (priority == TriagePriority.yellow || priority == TriagePriority.red) {
      final banner = AlertBannerViewModel(
        title: 'Triaje ADA + APOLO (${profile.callsign})',
        severity: priority == TriagePriority.red ? 'critical' : 'warning',
        classification: 'ada_apollo_triage',
        message: reply.text.split('\n\n').first,
        suppressed: false,
        recommendedAction: reply.actionChecklist?.join(' '),
        astronautId: profile.id,
        details: reply.actionChecklist ?? const [],
      );
      uiEvents.add(
        AgentComponentEvent.show(ComponentIds.alertBanner, banner.toProps()),
      );
    }

    return ToolResult.ok({
      'astronaut_id': profile.id,
      'environment': env.name,
      'environment_label': env.label,
      'priority': priority.name,
      'summary': reply.text,
      'recommended_hardware': reply.recommendedHardware,
      'action_checklist': reply.actionChecklist ?? const <String>[],
      'follow_up_options': reply.followUpOptions ?? const <String>[],
      'inference_source': reply.inferenceSource,
    }, uiEvents: uiEvents);
  }
}

/// Flujo determinista offline para consultas sobre criterios científicos
/// contextuales y triaje ADA + APOLO cuando no hay pasarela remota LLM.
class ScientificTelemetryOfflineFlow implements DeterministicFlow {
  const ScientificTelemetryOfflineFlow();

  @override
  String get skillId => 'scientific_telemetry_criteria';

  @override
  Future<DeterministicStep> start(ToolContext ctx) async {
    final profile = _resolveAstronaut(ctx, null);
    final telemetry = _tryRead<TelemetryState>(ctx, telemetryProvider);
    final snapshot =
        _tryRead<TelemetrySeriesSnapshot>(ctx, telemetrySeriesSnapshotProvider);

    final output = _buildEvaluationOutput(
      profile: profile,
      telemetry: telemetry,
      snapshot: snapshot,
      requestedContext: 'auto',
    );

    final status = output.overallSeverity;
    final ctxLabel = output.context.label;
    final summary =
        'Evaluación contextual (${profile.name}, $ctxLabel): estado $status. ${output.findingsSummary}';

    return DeterministicStep(
      prompt: summary,
      options: const [
        'Triaje ADA: Cefalea y visión borrosa (SANS)',
        'Triaje ADA: Falta de aire / CO2',
        'Finalizar',
      ],
      uiEvents: output.uiEvents,
    );
  }

  @override
  Future<DeterministicStep> advance(String userInput, ToolContext ctx) async {
    final normalized = userInput.trim().toLowerCase();
    if (normalized.contains('finaliz') ||
        normalized.contains('done') ||
        normalized.contains('listo')) {
      return const DeterministicStep(
        prompt: 'Revisión de criterios científicos y triaje ADA finalizada.',
        isTerminal: true,
      );
    }

    final profile = _resolveAstronaut(ctx, null);
    final env = _resolveEnvironment(ctx, null);
    final reply = ApolloTriageEngine.processQuery(
      query: userInput,
      astronaut: profile,
      environment: env,
    );
    final priority = reply.triageLevel ?? TriagePriority.green;
    final uiEvents = <AgentComponentEvent>[];
    if (priority == TriagePriority.yellow || priority == TriagePriority.red) {
      final banner = AlertBannerViewModel(
        title: 'Triaje ADA + APOLO (${profile.callsign})',
        severity: priority == TriagePriority.red ? 'critical' : 'warning',
        classification: 'ada_apollo_triage',
        message: reply.text.split('\n\n').first,
        suppressed: false,
        recommendedAction: reply.actionChecklist?.join(' '),
        astronautId: profile.id,
        details: reply.actionChecklist ?? const [],
      );
      uiEvents.add(
        AgentComponentEvent.show(ComponentIds.alertBanner, banner.toProps()),
      );
    }

    return DeterministicStep(
      prompt: reply.text,
      options: [
        ...(reply.followUpOptions ?? const <String>[]),
        'Finalizar',
      ],
      uiEvents: uiEvents,
      verdict: {
        'priority': priority.name,
        'recommended_hardware': reply.recommendedHardware,
        'inference_source': reply.inferenceSource,
      },
    );
  }
}

class _ContextualEvaluationOutput {
  const _ContextualEvaluationOutput({
    required this.context,
    required this.overallSeverity,
    required this.findingsSummary,
    required this.data,
    required this.uiEvents,
  });

  final ActivityContext context;
  final String overallSeverity;
  final String findingsSummary;
  final Map<String, dynamic> data;
  final List<AgentComponentEvent> uiEvents;
}

_ContextualEvaluationOutput _buildEvaluationOutput({
  required AstronautProfile profile,
  required TelemetryState? telemetry,
  required TelemetrySeriesSnapshot? snapshot,
  required String? requestedContext,
}) {
  final v = profile.vitals;
  final baselineHr = snapshot?.individualHrBaselineBpm;
  final baselineRr = snapshot?.individualRrBaselineRpm;
  final baselineSpo2 = snapshot?.individualSpo2BaselinePercent;

  final actigraphy = ScientificCriteriaEngine.inferActivityAndValidateHrv(
    accelerometryRmsG: v.accelerometryRmsG,
    heartRateBpm: v.heartRate,
    respiratoryRateRpm: v.respiratoryRate,
    rawActivityState: v.activityState,
    restingWakefulHrBaselineBpm: baselineHr ?? 68.0,
  );

  final ActivityContext context = _parseRequestedContext(requestedContext) ??
      actigraphy.inferredContext;
  final signalQualityPct = parseSignalQualityPercent(v.signalQuality);
  final bool signalValid = signalQualityPct == null || signalQualityPct >= 60.0;

  final results = <EvaluationResult>[
    ScientificCriteriaEngine.evaluateHeartRate(
      bpm: v.heartRate,
      context: context,
      individualBaselineBpm: baselineHr,
      localCo2MmHg: v.localCo2MmHg,
      missionDay: v.missionDay,
    ),
    ScientificCriteriaEngine.evaluateRespiratoryRate(
      rpm: v.respiratoryRate,
      context: context,
      individualBaselineRpm: baselineRr,
      localCo2MmHg: v.localCo2MmHg,
    ),
    ScientificCriteriaEngine.evaluateSpO2(
      percent: v.spO2,
      context: context,
      individualBaselinePercent: baselineSpo2,
      isSignalValid: signalValid,
    ),
    ScientificCriteriaEngine.evaluateBloodPressureContextual(
      systolicMmHg: v.systolicBP,
      diastolicMmHg: v.diastolicBP,
      context: context,
    ),
    ScientificCriteriaEngine.evaluateCapillaryRefillContextual(
      seconds: v.capillaryRefillSeconds,
      context: context,
    ),
    ScientificCriteriaEngine.evaluateBodyTemperatureContextual(
      tempCelsius: v.bodyTemp,
      context: context,
    ),
    ScientificCriteriaEngine.evaluateBloodGlucoseContextual(
      mgDl: v.bloodGlucose,
      context: context,
    ),
    ScientificCriteriaEngine.evaluateHydrationContextual(
      calibratedHydrationPercent: v.calibratedHydrationIndex,
      missionDay: v.missionDay,
      context: context,
    ),
    ScientificCriteriaEngine.evaluateHrvContextual(
      hrvRmssdMs: v.hrvRmssdMs,
      actigraphy: actigraphy,
    ),
  ];

  final hasCritical = results.any(
    (r) => r.severity == EvaluationSeverity.operationalAlert,
  );
  final hasWarning = results.any(
    (r) => r.severity == EvaluationSeverity.informativeNotice,
  );
  final overallSeverity =
      hasCritical ? 'critical' : (hasWarning ? 'warning' : 'nominal');

  final findings = results
      .where(
        (r) =>
            r.severity == EvaluationSeverity.operationalAlert ||
            r.severity == EvaluationSeverity.informativeNotice,
      )
      .map((r) => '${r.variable}: ${r.summary}')
      .toList(growable: false);

  final vitalsVm = VitalsCardViewModel.fromAstronaut(profile);
  final uiEvents = <AgentComponentEvent>[
    AgentComponentEvent.show(ComponentIds.vitalsCard, vitalsVm.toProps()),
    if (overallSeverity != 'nominal')
      AgentComponentEvent.show(
        ComponentIds.alertBanner,
        AlertBannerViewModel(
          title: 'Criterios Científicos (${profile.callsign})',
          severity: overallSeverity,
          classification: 'scientific_criteria',
          message: findings.join(' '),
          suppressed: false,
          recommendedAction:
              'Contrastar con contexto ${context.label}, basal individual y protocolos NASA-STD-3001.',
          astronautId: profile.id,
          details: findings,
        ).toProps(),
      ),
  ];

  final telemetryPacketCount = telemetry?.recentLogs
          .where((p) => p.astronautId == profile.id)
          .length ??
      0;

  final data = <String, dynamic>{
    'astronaut_id': profile.id,
    'astronaut_name': profile.name,
    'mission_day': v.missionDay,
    'context': context.label,
    'overall_severity': overallSeverity,
    'is_hrv_valid_for_stress': actigraphy.isHrvValidForStress,
    'telemetry_packets_buffered': telemetryPacketCount,
    'references': const [
      'NASA-STD-3001',
      'AHA/ACC',
      'ADA',
      'ATS/ERS',
      'FDA/NHLBI',
    ],
    'evaluations': results
        .map(
          (r) => {
            'variable': r.variable,
            'value': r.value,
            'unit': r.unit,
            'severity': r.severity.name,
            'summary': r.summary,
            if (r.appliedCriterion != null)
              'source': r.appliedCriterion!.source,
          },
        )
        .toList(growable: false),
  };

  return _ContextualEvaluationOutput(
    context: context,
    overallSeverity: overallSeverity,
    findingsSummary: findings.isEmpty
        ? 'Todos los parámetros dentro de criterios esperados para ${context.label}.'
        : findings.join(' '),
    data: data,
    uiEvents: uiEvents,
  );
}

ActivityContext? _parseRequestedContext(String? raw) {
  switch (raw?.trim().toLowerCase()) {
    case 'rest':
      return ActivityContext.rest;
    case 'sleep':
      return ActivityContext.sleep;
    case 'physical_activity':
    case 'activity':
      return ActivityContext.physicalActivity;
    default:
      return null;
  }
}

AstronautProfile _resolveAstronaut(ToolContext ctx, String? requestedId) {
  final id = (requestedId != null && requestedId.trim().isNotEmpty)
      ? requestedId.trim()
      : ctx.astronautId;
  final crew = ctx.read<List<AstronautProfile>>(crewMembersProvider);
  return crew.firstWhere(
    (a) => a.id == id,
    orElse: () => crew.first,
  );
}

SpaceOperationalEnvironment _resolveEnvironment(
  ToolContext ctx,
  String? requestedEnv,
) {
  if (requestedEnv != null && requestedEnv.trim().isNotEmpty) {
    for (final env in SpaceOperationalEnvironment.values) {
      if (env.name == requestedEnv.trim()) {
        return env;
      }
    }
  }
  return _tryRead<SpaceOperationalEnvironment>(
        ctx,
        selectedEnvironmentProvider,
      ) ??
      SpaceOperationalEnvironment.spaceStation;
}

T? _tryRead<T>(ToolContext ctx, Object provider) {
  try {
    return ctx.read<T>(provider);
  } catch (_) {
    return null;
  }
}
