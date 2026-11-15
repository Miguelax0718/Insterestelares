import 'package:astramed/features/01_general_health/agent/general_health_skills.dart';
import 'package:astramed/features/01_general_health/domain/scientific_criteria_engine.dart';
import 'package:astramed/features/01_general_health/domain/telemetry_ingestion_service.dart';
import 'package:astramed/features/01_general_health/domain/telemetry_view_contracts.dart';
import 'package:astramed/features/05_clinical_triage/domain/apollo_triage_engine.dart';
import 'package:astramed/features/05_clinical_triage/domain/hybrid_llm_triage_service.dart';
import 'package:astramed/features/05_clinical_triage/models/triage_decision.dart';
import 'package:astramed/features/agent/domain/agent_contracts.dart';
import 'package:astramed/features/agent/providers/agent_providers.dart';
import 'package:astramed/features/crew/models/astronaut_profile.dart';
import 'package:astramed/features/crew/presentation/providers/crew_provider.dart';

/// Extrae el porcentaje numérico de calidad de señal (p. ej. "optimal (98%)" -> 98.0).
double parseSignalQualityPercent(String raw, {double fallback = 97.0}) {
  final match = RegExp(r'(\d+(?:\.\d+)?)').firstMatch(raw);
  if (match == null) return fallback;
  final parsed = double.tryParse(match.group(1) ?? '');
  if (parsed == null) return fallback;
  return parsed.clamp(0.0, 100.0);
}

List<AgentSkill> scientificTelemetryAgentSkills() {
  return [
    AgentSkill(
      id: 'scientific_telemetry_criteria',
      instructions:
          'You execute Apolo scientific telemetry evaluation and ADA+APOLO clinical triage across 4 continuous passive dimensions: '
          '(1) Cardiorespiratory/Metabolic (HR +3.44 bpm 0g shift, HRV RMSSD/SDNN, RR, SpO2, Draeger heat-flux core temp, BIS hydration corrected for fluid shift), '
          '(2) Neurological/Sensory (IR pupillometry NPi/PLR, ToF hyperopic shift for SANS, background PVT-B reaction/lapses), '
          '(3) Musculoskeletal (IMU impact/cadence, localized quadriceps/gastrocnemius BIS atrophy, strength), '
          '(4) Circadian/Psychoemotional (actigraphy duration/efficiency/fragmentation/regularity, nocturnal HRV & SpO2/RR). '
          'Call evaluate_passive_dimensions_telemetry for full 4-dimension audits, evaluate_scientific_vitals_criteria for contextual criterion checks, '
          'run_ada_apollo_triage for deterministic symptom+telemetry triage, or run_hybrid_ada_apollo_consultation when hybrid LLM/SLM synthesis is needed. '
          'Never skip contextual validity checks (exercise vs rest vs sleep) or signal quality.',
      tools: const [
        _EvaluateScientificVitalsCriteriaTool(),
        _EvaluatePassiveDimensionsTelemetryTool(),
        _RunAdaApolloTriageTool(),
        _RunHybridAdaApolloConsultationTool(),
      ],
      componentIds: const [
        ComponentIds.vitalsCard,
        ComponentIds.alertBanner,
      ],
      triggers: const [
        'criterio',
        'criterios',
        'scientific',
        'telemetry',
        'telemetria',
        'pasiva',
        'pasivas',
        'dimensiones',
        'dimension',
        'actigrafia',
        'actigrafía',
        'bimodal',
        'hrv',
        'rmssd',
        'sdnn',
        'pupilometria',
        'pupilometría',
        'npi',
        'plr',
        'tof',
        'sans',
        'hyperopic',
        'hiperopico',
        'pvt',
        'imu',
        'impacto',
        'bioimpedancia',
        'bis',
        'hidratacion',
        'hidratación',
        'heat-flux',
        'draeger',
        'bio-monitor',
        'nocturna',
        'apolo',
        'apollo',
        'ada',
        'triage',
        'slm',
      ],
      offlineFlow: const ScientificTelemetryOfflineFlow(),
    ),
  ];
}

AstronautProfile? _findAstronaut(ToolContext ctx, Map<String, dynamic> args) {
  final crew = ctx.read<List<AstronautProfile>>(crewMembersProvider);
  if (crew.isEmpty) return null;
  final requested = args['astronaut_id'] as String?;
  final targetId =
      (requested != null && requested.trim().isNotEmpty) ? requested.trim() : ctx.astronautId;
  for (final member in crew) {
    if (member.id == targetId) return member;
  }
  return crew.firstWhere(
    (m) => m.id == ctx.astronautId,
    orElse: () => crew.first,
  );
}

SpaceOperationalEnvironment _resolveEnvironment(
  ToolContext ctx,
  Map<String, dynamic> args,
) {
  final rawEnv = args['environment'] as String?;
  if (rawEnv != null && rawEnv.trim().isNotEmpty) {
    return SpaceOperationalEnvironment.fromString(rawEnv);
  }
  return ctx.read<SpaceOperationalEnvironment>(operationalEnvironmentProvider);
}

class _EvaluateScientificVitalsCriteriaTool extends AgentTool {
  const _EvaluateScientificVitalsCriteriaTool();

  @override
  String get name => 'evaluate_scientific_vitals_criteria';

  @override
  String get description =>
      'Evaluate astronaut vitals against contextual NASA/clinical criteria (HR +3.44 lpm 0g, RR, SpO2, heat-flux, BIS hydration, sleep, muscle, bimodal HRV-actigraphy).';

  @override
  Map<String, dynamic> get parameters => const {
        'type': 'object',
        'properties': {
          'astronaut_id': {'type': 'string'},
          'activity_context': {
            'type': 'string',
            'enum': ['rest', 'sleep', 'physical_activity', 'eva'],
          },
          'environment': {'type': 'string'},
          'comparable_protocol': {'type': 'boolean'},
          'muscle_strength_retention_percent': {'type': 'number'},
        },
      };

  @override
  Future<ToolResult> call(Map<String, dynamic> args, ToolContext ctx) async {
    final crew = _findAstronaut(ctx, args);
    if (crew == null) {
      return ToolResult.fail('No crew telemetry available.');
    }

    final vitals = crew.vitals;
    final rawContext = args['activity_context'] as String? ?? vitals.activityState;
    final activityContext = ActivityContext.fromString(rawContext);
    final environment = _resolveEnvironment(ctx, args);
    final signalQuality = parseSignalQualityPercent(vitals.signalQuality);
    final comparable = args['comparable_protocol'] as bool? ?? true;
    final muscleStrength =
        (args['muscle_strength_retention_percent'] as num?)?.toDouble() ??
            vitals.muscleVolumeRetentionPercent;

    const engine = ScientificCriteriaEngine();
    final checks = <EvaluationResult>[
      engine.evaluateHeartRate(
        bpm: vitals.heartRate,
        context: activityContext,
        signalQualityPercent: signalQuality,
        inMicrogravity: environment.isMicrogravity,
      ),
      engine.evaluateRespiratoryRate(
        rpm: vitals.respiratoryRate,
        context: activityContext,
        signalQualityPercent: signalQuality,
      ),
      engine.evaluateSpO2(
        spo2Percent: vitals.spO2,
        signalQualityPercent: signalQuality,
      ),
      engine.evaluateCoreTemperatureHeatFlux(
        tempCelsius: vitals.coreTempHeatFluxC,
        context: activityContext,
        signalQualityPercent: signalQuality,
      ),
      engine.evaluateHydrationBioimpedance(
        rawIndexPercent: vitals.hydrationBioimpedanceIndex,
        missionDay: vitals.missionDay,
        inMicrogravity: environment.isMicrogravity,
        signalQualityPercent: signalQuality,
      ),
      engine.evaluateSleepDuration(
        hours: crew.sleep.sleepHours,
        context: ActivityContext.sleep,
      ),
      engine.evaluateMuscleStrength(
        retentionPercent: muscleStrength,
        comparableBaselineProtocol: comparable,
      ),
    ];

    final bimodal = engine.evaluateActigraphyBimodal(
      hrvRmssdMs: vitals.hrvRmssdMs,
      hrvSdnnMs: vitals.hrvSdnnMs,
      actigraphyAxisG: vitals.accelerometryRmsG,
      context: activityContext,
      signalQualityPercent: signalQuality,
    );

    final warnings = checks.where((c) => c.hasWarning).toList();
    final hasCritical =
        warnings.any((w) => w.severity == EvaluationSeverity.clinicalAttention);

    final uiEvents = <AgentComponentEvent>[
      AgentComponentEvent.show(
        ComponentIds.vitalsCard,
        VitalsCardViewModel.fromAstronaut(crew).toProps(),
      ),
    ];

    if (warnings.isNotEmpty || bimodal.severity == EvaluationSeverity.contextualWarning) {
      uiEvents.add(
        AgentComponentEvent.show(
          ComponentIds.alertBanner,
          AlertBannerViewModel(
            title: 'Evaluación Científica (${crew.name})',
            severity: hasCritical ? 'critical' : 'warning',
            classification: hasCritical ? 'clinical_attention' : 'contextual_warning',
            message: warnings.isNotEmpty
                ? warnings.first.interpretation
                : bimodal.interpretation,
            suppressed: false,
            recommendedAction:
                'Validar contexto (${activityContext.label}) y calidad de señal (${signalQuality.toStringAsFixed(0)}%).',
            astronautId: crew.id,
            details: warnings.map((w) => w.interpretation).toList(),
          ).toProps(),
        ),
      );
    }

    return ToolResult.ok({
      'astronaut_id': crew.id,
      'astronaut_name': crew.name,
      'environment': environment.name,
      'activity_context': activityContext.name,
      'signal_quality_percent': signalQuality,
      'warning_count': warnings.length,
      'actigraphy_bimodal': bimodal.toJson(),
      'results': checks.map((c) => c.toJson()).toList(),
    }, uiEvents: uiEvents);
  }
}

class _EvaluatePassiveDimensionsTelemetryTool extends AgentTool {
  const _EvaluatePassiveDimensionsTelemetryTool();

  @override
  String get name => 'evaluate_passive_dimensions_telemetry';

  @override
  String get description =>
      'Run full 4-dimension continuous passive telemetry audit (Cardiorespiratory/Metabolic, Neurological/Sensory eye-tracking/ToF/PVT-B, Musculoskeletal IMU/BIS, Circadian/Nocturnal HRV).';

  @override
  Map<String, dynamic> get parameters => const {
        'type': 'object',
        'properties': {
          'astronaut_id': {'type': 'string'},
          'activity_context': {
            'type': 'string',
            'enum': ['rest', 'sleep', 'physical_activity', 'eva'],
          },
          'environment': {'type': 'string'},
          'optic_nerve_sheath_diameter_mm': {'type': 'number'},
        },
      };

  @override
  Future<ToolResult> call(Map<String, dynamic> args, ToolContext ctx) async {
    final crew = _findAstronaut(ctx, args);
    if (crew == null) {
      return ToolResult.fail('No crew telemetry available.');
    }

    final vitals = crew.vitals;
    final environment = _resolveEnvironment(ctx, args);
    final activityContext = ActivityContext.fromString(
      args['activity_context'] as String? ?? vitals.activityState,
    );
    final signalQuality = parseSignalQualityPercent(vitals.signalQuality);

    final streamRecord = ContinuousWearableStreamRecord.fromVitals(
      vitals.copyWith(activityState: activityContext.name),
      environment: environment,
      sleepDurationHours: crew.sleep.sleepHours,
      signalQualityPercent: signalQuality,
    );

    final fixedTelemetry = StationFixedTelemetryRecord(
      timestamp: vitals.timestamp,
      moduleId: crew.currentZone,
      ppCo2MmHg: vitals.localCo2MmHg,
      o2Percent: vitals.localO2Percent,
      cabinPressureKPa: vitals.cabinPressureKPa,
      ambientTempC: 22.4,
      radiationRateMSvPerHour: crew.radiation.doseRateMicroSvPerHour / 1000.0,
    );

    final periodicAssessment = PeriodicManualAssessmentRecord(
      timestamp: vitals.timestamp,
      astronautId: crew.id,
      systolicBP: vitals.systolicBP,
      diastolicBP: vitals.diastolicBP,
      bloodGlucoseMgDl: vitals.bloodGlucose,
      muscleStrengthRetentionPercent: vitals.muscleVolumeRetentionPercent,
      opticNerveSheathDiameterMm:
          (args['optic_nerve_sheath_diameter_mm'] as num?)?.toDouble() ?? 4.6,
    );

    const ingestion = TelemetryIngestionService();
    final summary = ingestion.classifyAndSummarize(
      wearableStream: [streamRecord],
      fixedTelemetry: fixedTelemetry,
      periodicAssessment: periodicAssessment,
    );

    final uiEvents = <AgentComponentEvent>[];
    final overall = summary.passiveEvaluation.overallSeverity;
    if (overall != EvaluationSeverity.normal || summary.environmentalFlags.isNotEmpty) {
      final isCritical = overall == EvaluationSeverity.clinicalAttention;
      uiEvents.add(
        AgentComponentEvent.show(
          ComponentIds.alertBanner,
          AlertBannerViewModel(
            title: 'Auditoría 4 Dimensiones Pasivas (${crew.name})',
            severity: isCritical ? 'critical' : 'warning',
            classification: overall.name,
            message: summary.passiveEvaluation.alerts.isNotEmpty
                ? summary.passiveEvaluation.alerts.first
                : summary.environmentalFlags.first,
            suppressed: false,
            recommendedAction:
                summary.passiveEvaluation.recommendations.join(' '),
            astronautId: crew.id,
            details: [
              ...summary.passiveEvaluation.alerts,
              ...summary.environmentalFlags,
            ],
          ).toProps(),
        ),
      );
    }

    return ToolResult.ok(summary.toJson(), uiEvents: uiEvents);
  }
}

class _RunAdaApolloTriageTool extends AgentTool {
  const _RunAdaApolloTriageTool();

  @override
  String get name => 'run_ada_apollo_triage';

  @override
  String get description =>
      'Run offline-first deterministic ADA+APOLO clinical triage correlating astronaut symptoms with all 4 passive telemetry dimensions and cabin atmosphere.';

  @override
  Map<String, dynamic> get parameters => const {
        'type': 'object',
        'properties': {
          'astronaut_id': {'type': 'string'},
          'clinical_query': {
            'type': 'string',
            'description': 'Symptom or clinical question reported by crew.',
          },
          'activity_context': {
            'type': 'string',
            'enum': ['rest', 'sleep', 'physical_activity', 'eva'],
          },
          'environment': {'type': 'string'},
        },
        'required': ['clinical_query'],
      };

  @override
  Future<ToolResult> call(Map<String, dynamic> args, ToolContext ctx) async {
    final query = (args['clinical_query'] as String?)?.trim() ?? '';
    if (query.isEmpty) {
      return ToolResult.fail('clinical_query is required for ADA+APOLO triage.');
    }

    final crew = _findAstronaut(ctx, args);
    if (crew == null) {
      return ToolResult.fail('No crew telemetry available.');
    }

    final environment = _resolveEnvironment(ctx, args);
    final activityContext = ActivityContext.fromString(
      args['activity_context'] as String? ?? crew.vitals.activityState,
    );
    final signalQuality = parseSignalQualityPercent(crew.vitals.signalQuality);

    const engine = ApolloTriageEngine();
    final result = engine.processQuery(
      query: query,
      vitals: crew.vitals,
      sleepHours: crew.sleep.sleepHours,
      activityContext: activityContext,
      inMicrogravity: environment.isMicrogravity,
      signalQualityPercent: signalQuality,
    );

    final uiEvents = <AgentComponentEvent>[];
    if (result.priority == TriagePriority.yellow ||
        result.priority == TriagePriority.red) {
      uiEvents.add(
        AgentComponentEvent.show(
          ComponentIds.alertBanner,
          AlertBannerViewModel(
            title: result.triageResult?.conditionName ?? 'ADA+APOLO Triage',
            severity: result.priority == TriagePriority.red ? 'critical' : 'warning',
            classification: result.triggeredRule,
            message: result.text,
            suppressed: false,
            recommendedAction:
                result.triageResult?.immediateActions.join(' | '),
            astronautId: crew.id,
            details: result.referencedMetrics,
          ).toProps(),
        ),
      );
    }

    return ToolResult.ok({
      'astronaut_id': crew.id,
      'astronaut_name': crew.name,
      'environment': environment.name,
      ...result.toJson(),
    }, uiEvents: uiEvents);
  }
}

class _RunHybridAdaApolloConsultationTool extends AgentTool {
  const _RunHybridAdaApolloConsultationTool();

  @override
  String get name => 'run_hybrid_ada_apollo_consultation';

  @override
  String get description =>
      'Run hybrid ADA+APOLO triage combining deterministic safety rules with configured local SLM or cloud LLM (auto-falls back offline).';

  @override
  Map<String, dynamic> get parameters => const {
        'type': 'object',
        'properties': {
          'astronaut_id': {'type': 'string'},
          'clinical_query': {'type': 'string'},
          'backend_override': {
            'type': 'string',
            'enum': ['offline_deterministic', 'local_slm', 'cloud_llm'],
          },
          'endpoint_url': {'type': 'string'},
          'environment': {'type': 'string'},
        },
        'required': ['clinical_query'],
      };

  @override
  Future<ToolResult> call(Map<String, dynamic> args, ToolContext ctx) async {
    final query = (args['clinical_query'] as String?)?.trim() ?? '';
    if (query.isEmpty) {
      return ToolResult.fail('clinical_query is required.');
    }

    final crew = _findAstronaut(ctx, args);
    if (crew == null) {
      return ToolResult.fail('No crew telemetry available.');
    }

    final environment = _resolveEnvironment(ctx, args);
    final service = ctx.read<HybridLlmTriageService>(hybridLlmTriageServiceProvider);
    var config = ctx.read<HybridAiConfig>(hybridAiConfigProvider);

    final backendOverride = args['backend_override'] as String?;
    final endpointOverride = args['endpoint_url'] as String?;
    if (backendOverride != null && backendOverride.isNotEmpty) {
      config = config.copyWith(
        backend: AiInferenceBackend.fromString(backendOverride),
      );
    }
    if (endpointOverride != null && endpointOverride.trim().isNotEmpty) {
      config = config.copyWith(endpointUrl: endpointOverride.trim());
    }

    final response = await service.evaluate(
      query: query,
      vitals: crew.vitals,
      config: config,
      sleepHours: crew.sleep.sleepHours,
      activityContext: ActivityContext.fromString(crew.vitals.activityState),
      inMicrogravity: environment.isMicrogravity,
      signalQualityPercent: parseSignalQualityPercent(crew.vitals.signalQuality),
    );

    return ToolResult.ok({
      'astronaut_id': crew.id,
      'astronaut_name': crew.name,
      'environment': environment.name,
      ...response.toJson(),
    });
  }
}

/// Flujo determinista 100% Offline-First para auditoría de las 4 dimensiones
/// pasivas y triage clínico ADA+APOLO sin dependencia de LLM remoto.
class ScientificTelemetryOfflineFlow implements QueryAwareDeterministicFlow {
  const ScientificTelemetryOfflineFlow();

  @override
  String get skillId => 'scientific_telemetry_criteria';

  @override
  Future<DeterministicStep> startWithQuery(String query, ToolContext ctx) =>
      advance(query, ctx);

  @override
  Future<DeterministicStep> start(ToolContext ctx) async {
    final crew = _findAstronaut(ctx, const {});
    if (crew == null) {
      return const DeterministicStep(
        prompt: 'Sin telemetría de tripulación disponible.',
        isTerminal: true,
      );
    }

    const engine = ScientificCriteriaEngine();
    final eval = engine.evaluateAllPassiveDimensions(
      vitals: crew.vitals,
      sleepHours: crew.sleep.sleepHours,
      context: ActivityContext.fromString(crew.vitals.activityState),
      signalQualityPercent: parseSignalQualityPercent(crew.vitals.signalQuality),
    );

    return DeterministicStep(
      prompt:
          'Auditoría Pasiva Apolo (Offline) para ${crew.name}: estado global ${eval.overallSeverity.label} '
          '(${eval.alerts.length} alertas activas). Selecciona un protocolo de inspección o describe síntomas:',
      options: const [
        'Escanear 4 Dimensiones Pasivas',
        'Triage SANS / Pupila / Enfoque ToF',
        'Triage Fatiga PVT-B / Sueño / HRV Nocturna',
        'Triage CO2 / SpO2 / Impacto IMU',
      ],
      uiEvents: [
        AgentComponentEvent.show(
          ComponentIds.vitalsCard,
          VitalsCardViewModel.fromAstronaut(crew).toProps(),
        ),
      ],
    );
  }

  @override
  Future<DeterministicStep> advance(String userInput, ToolContext ctx) async {
    final crew = _findAstronaut(ctx, const {});
    if (crew == null) {
      return const DeterministicStep(
        prompt: 'Sin perfil de tripulante activo para completar evaluación offline.',
        isTerminal: true,
      );
    }

    final normalized = userInput.toLowerCase();
    final String query;
    if (normalized.contains('sans') || normalized.contains('pupila')) {
      query = 'chequeo sans vista enfoque pupila';
    } else if (normalized.contains('pvt') ||
        normalized.contains('sueño') ||
        normalized.contains('fatiga')) {
      query = 'chequeo fatiga pvt sueño hrv nocturna';
    } else if (normalized.contains('co2') ||
        normalized.contains('spo2') ||
        normalized.contains('impacto')) {
      query = 'chequeo co2 spo2 impacto imu';
    } else if (normalized.contains('4 dimensiones') || normalized.contains('escanear')) {
      query = 'chequeo integral 4 dimensiones pasivas';
    } else {
      query = userInput;
    }

    const apollo = ApolloTriageEngine();
    final msg = apollo.processQuery(
      query: query,
      vitals: crew.vitals,
      sleepHours: crew.sleep.sleepHours,
      activityContext: ActivityContext.fromString(crew.vitals.activityState),
      signalQualityPercent: parseSignalQualityPercent(crew.vitals.signalQuality),
    );

    final events = <AgentComponentEvent>[
      AgentComponentEvent.show(
        ComponentIds.vitalsCard,
        VitalsCardViewModel.fromAstronaut(crew).toProps(),
      ),
      if (msg.priority == TriagePriority.yellow ||
          msg.priority == TriagePriority.red)
        AgentComponentEvent.show(
          ComponentIds.alertBanner,
          AlertBannerViewModel(
            title: msg.triageResult?.conditionName ?? 'Triage Offline ADA+APOLO',
            severity: msg.priority == TriagePriority.red ? 'critical' : 'warning',
            classification: msg.triggeredRule,
            message: msg.text,
            suppressed: false,
            astronautId: crew.id,
            details: msg.referencedMetrics,
          ).toProps(),
        ),
    ];

    return DeterministicStep(
      prompt: msg.text,
      isTerminal: true,
      uiEvents: events,
      verdict: {
        'astronaut_id': crew.id,
        'priority': msg.priority?.name ?? 'green',
        'triggered_rule': msg.triggeredRule,
        'recommended_supplies': msg.recommendedSupplies,
        'referenced_metrics': msg.referencedMetrics,
        'sources': msg.sources,
      },
    );
  }
}
