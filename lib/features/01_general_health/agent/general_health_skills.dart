import 'dart:convert';

import 'package:astramed/core/constants/medical_thresholds.dart';
import 'package:astramed/features/01_general_health/agent/artifact_filter_engine.dart';
import 'package:astramed/features/01_general_health/agent/cross_correlation_engine.dart';
import 'package:astramed/features/01_general_health/agent/status_report_engine.dart';
import 'package:astramed/features/01_general_health/models/vitals_record.dart';
import 'package:astramed/features/agent/domain/agent_contracts.dart';
import 'package:astramed/features/crew/models/astronaut_profile.dart';
import 'package:astramed/features/crew/presentation/providers/crew_provider.dart';
import 'package:astramed/features/telemetry/models/telemetry_machine.dart';
import 'package:astramed/features/telemetry/presentation/providers/telemetry_provider.dart';
import 'package:flutter/services.dart';

typedef InventoryLoader = Future<List<Map<String, dynamic>>> Function();

class StatusReportViewModel extends AgentViewModel {
  const StatusReportViewModel({
    required super.title,
    required this.astronautId,
    required this.astronautName,
    required this.callsign,
    required this.riskLevel,
    required this.riskTitle,
    required this.summary,
    required this.activeAlerts,
    required this.activeFlags,
    required this.subsystems,
    required this.generatedAt,
  }) : super(componentId: ComponentIds.statusReport);

  factory StatusReportViewModel.fromReport(StatusReport report) {
    return StatusReportViewModel(
      title: '${report.astronautName} (${report.callsign})',
      astronautId: report.astronautId,
      astronautName: report.astronautName,
      callsign: report.callsign,
      riskLevel: report.riskLevel.name,
      riskTitle: report.riskTitle,
      summary: report.summary,
      activeAlerts: report.activeAlerts,
      activeFlags: report.activeFlags,
      subsystems: report.subsystems,
      generatedAt: report.generatedAt.toUtc().toIso8601String(),
    );
  }

  factory StatusReportViewModel.fromProps(Map<String, dynamic> props) {
    final astronautId = props['astronaut_id'];
    final astronautName = props['astronaut_name'];
    final riskLevel = props['risk_level'];
    final summary = props['summary'];
    if (astronautId is! String ||
        astronautId.isEmpty ||
        astronautName is! String ||
        astronautName.isEmpty ||
        riskLevel is! String ||
        summary is! String) {
      throw const FormatException('Invalid status_report props.');
    }
    return StatusReportViewModel(
      title: props['title'] as String? ?? '$astronautName Status',
      astronautId: astronautId,
      astronautName: astronautName,
      callsign: props['callsign'] as String? ?? '',
      riskLevel: riskLevel,
      riskTitle: props['risk_title'] as String? ?? riskLevel,
      summary: summary,
      activeAlerts: _stringList(props['active_alerts']),
      activeFlags: _stringMap(props['active_flags']),
      subsystems: _stringMap(props['subsystems']),
      generatedAt: props['generated_at'] as String? ?? '',
    );
  }

  final String astronautId;
  final String astronautName;
  final String callsign;
  final String riskLevel;
  final String riskTitle;
  final String summary;
  final List<String> activeAlerts;
  final Map<String, dynamic> activeFlags;
  final Map<String, dynamic> subsystems;
  final String generatedAt;

  @override
  Map<String, dynamic> toProps() => {
        'title': title,
        'astronaut_id': astronautId,
        'astronaut_name': astronautName,
        'callsign': callsign,
        'risk_level': riskLevel,
        'risk_title': riskTitle,
        'summary': summary,
        'active_alerts': activeAlerts,
        'active_flags': activeFlags,
        'subsystems': subsystems,
        'generated_at': generatedAt,
      };
}

class AlertBannerViewModel extends AgentViewModel {
  const AlertBannerViewModel({
    required super.title,
    required this.severity,
    required this.classification,
    required this.message,
    required this.suppressed,
    this.recommendedAction,
    this.astronautId,
    this.details = const [],
  }) : super(componentId: ComponentIds.alertBanner);

  factory AlertBannerViewModel.fromProps(Map<String, dynamic> props) {
    final severity = props['severity'];
    final classification = props['classification'];
    final message = props['message'];
    final suppressed = props['suppressed'];
    if (severity is! String ||
        severity.isEmpty ||
        classification is! String ||
        classification.isEmpty ||
        message is! String ||
        suppressed is! bool) {
      throw const FormatException('Invalid alert_banner props.');
    }
    return AlertBannerViewModel(
      title: props['title'] as String? ?? 'Clinical Alert',
      severity: severity,
      classification: classification,
      message: message,
      suppressed: suppressed,
      recommendedAction: props['recommended_action'] as String?,
      astronautId: props['astronaut_id'] as String?,
      details: _stringList(props['details']),
    );
  }

  final String severity;
  final String classification;
  final String message;
  final bool suppressed;
  final String? recommendedAction;
  final String? astronautId;
  final List<String> details;

  @override
  Map<String, dynamic> toProps() => {
        'title': title,
        'severity': severity,
        'classification': classification,
        'message': message,
        'suppressed': suppressed,
        if (recommendedAction != null) 'recommended_action': recommendedAction,
        if (astronautId != null) 'astronaut_id': astronautId,
        'details': details,
      };
}

class VitalsCardViewModel extends AgentViewModel {
  const VitalsCardViewModel({
    required super.title,
    required this.astronautId,
    required this.astronautName,
    required this.heartRate,
    required this.systolicBP,
    required this.diastolicBP,
    required this.spO2,
    required this.bodyTemp,
    required this.bloodGlucose,
    required this.respiratoryRate,
    required this.capillaryRefillSeconds,
    required this.activityState,
    required this.signalQuality,
    required this.source,
    required this.timestamp,
  }) : super(componentId: ComponentIds.vitalsCard);

  factory VitalsCardViewModel.fromAstronaut(AstronautProfile profile) {
    final v = profile.vitals;
    return VitalsCardViewModel(
      title: '${profile.name} Vitals',
      astronautId: profile.id,
      astronautName: profile.name,
      heartRate: v.heartRate,
      systolicBP: v.systolicBP,
      diastolicBP: v.diastolicBP,
      spO2: v.spO2,
      bodyTemp: v.bodyTemp,
      bloodGlucose: v.bloodGlucose,
      respiratoryRate: v.respiratoryRate,
      capillaryRefillSeconds: v.capillaryRefillSeconds,
      activityState: v.activityState,
      signalQuality: v.signalQuality,
      source: v.source,
      timestamp: v.timestamp.toUtc().toIso8601String(),
    );
  }

  factory VitalsCardViewModel.fromProps(Map<String, dynamic> props) {
    final astronautId = props['astronaut_id'];
    final hr = props['heart_rate'];
    final sbp = props['systolic_bp'];
    final dbp = props['diastolic_bp'];
    final spo2 = props['spo2'];
    if (astronautId is! String ||
        astronautId.isEmpty ||
        hr is! num ||
        sbp is! num ||
        dbp is! num ||
        spo2 is! num) {
      throw const FormatException('Invalid vitals_card props.');
    }
    return VitalsCardViewModel(
      title: props['title'] as String? ?? 'Vitals',
      astronautId: astronautId,
      astronautName: props['astronaut_name'] as String? ?? astronautId,
      heartRate: hr.toDouble(),
      systolicBP: sbp.toDouble(),
      diastolicBP: dbp.toDouble(),
      spO2: spo2.toDouble(),
      bodyTemp: (props['body_temp'] as num?)?.toDouble() ?? 36.6,
      bloodGlucose: (props['blood_glucose'] as num?)?.toDouble() ?? 90.0,
      respiratoryRate: (props['respiratory_rate'] as num?)?.toDouble() ?? 16.0,
      capillaryRefillSeconds:
          (props['capillary_refill_seconds'] as num?)?.toDouble() ?? 1.5,
      activityState: props['activity_state'] as String? ?? 'active_duty',
      signalQuality: props['signal_quality'] as String? ?? 'optimal',
      source: props['source'] as String? ?? 'telemetry',
      timestamp: props['timestamp'] as String? ?? '',
    );
  }

  final String astronautId;
  final String astronautName;
  final double heartRate;
  final double systolicBP;
  final double diastolicBP;
  final double spO2;
  final double bodyTemp;
  final double bloodGlucose;
  final double respiratoryRate;
  final double capillaryRefillSeconds;
  final String activityState;
  final String signalQuality;
  final String source;
  final String timestamp;

  @override
  Map<String, dynamic> toProps() => {
        'title': title,
        'astronaut_id': astronautId,
        'astronaut_name': astronautName,
        'heart_rate': heartRate,
        'systolic_bp': systolicBP,
        'diastolic_bp': diastolicBP,
        'spo2': spO2,
        'body_temp': bodyTemp,
        'blood_glucose': bloodGlucose,
        'respiratory_rate': respiratoryRate,
        'capillary_refill_seconds': capillaryRefillSeconds,
        'activity_state': activityState,
        'signal_quality': signalQuality,
        'source': source,
        'timestamp': timestamp,
      };
}

class TelemetryDataPoint {
  const TelemetryDataPoint({
    required this.label,
    required this.value,
    this.metadata = const {},
  });

  factory TelemetryDataPoint.fromJson(Map<String, dynamic> json) {
    final label = json['label'];
    final value = json['value'];
    if (label is! String || value is! num) {
      throw const FormatException('Invalid telemetry data point.');
    }
    return TelemetryDataPoint(
      label: label,
      value: value.toDouble(),
      metadata: json['metadata'] is Map
          ? Map<String, dynamic>.from(json['metadata'] as Map)
          : const {},
    );
  }

  final String label;
  final double value;
  final Map<String, dynamic> metadata;

  Map<String, dynamic> toJson() => {
        'label': label,
        'value': value,
        if (metadata.isNotEmpty) 'metadata': metadata,
      };
}

class TelemetryChartViewModel extends AgentViewModel {
  const TelemetryChartViewModel({
    required super.title,
    required this.metric,
    required this.unit,
    required this.astronautId,
    required this.series,
    this.summary = const {},
  }) : super(componentId: ComponentIds.telemetryChart);

  factory TelemetryChartViewModel.fromProps(Map<String, dynamic> props) {
    final metric = props['metric'];
    final unit = props['unit'];
    final rawSeries = props['series'];
    if (metric is! String ||
        metric.isEmpty ||
        unit is! String ||
        rawSeries is! List) {
      throw const FormatException('Invalid telemetry_chart props.');
    }
    final points = <TelemetryDataPoint>[];
    for (final item in rawSeries) {
      if (item is! Map) {
        throw const FormatException('Invalid telemetry_chart series item.');
      }
      points.add(TelemetryDataPoint.fromJson(Map<String, dynamic>.from(item)));
    }
    return TelemetryChartViewModel(
      title: props['title'] as String? ?? metric,
      metric: metric,
      unit: unit,
      astronautId: props['astronaut_id'] as String? ?? 'CREW',
      series: List<TelemetryDataPoint>.unmodifiable(points),
      summary: _stringMap(props['summary']),
    );
  }

  final String metric;
  final String unit;
  final String astronautId;
  final List<TelemetryDataPoint> series;
  final Map<String, dynamic> summary;

  @override
  Map<String, dynamic> toProps() => {
        'title': title,
        'metric': metric,
        'unit': unit,
        'astronaut_id': astronautId,
        'series': series.map((p) => p.toJson()).toList(growable: false),
        'summary': summary,
      };
}

/// Offline deterministic step flow for `status_report` when the remote LLM
/// gateway is unavailable (S9).
class StatusReportOfflineFlow implements DeterministicFlow {
  StatusReportOfflineFlow({
    StatusReportEngine? statusReportEngine,
    CrossCorrelationEngine? correlationEngine,
  })  : _statusReportEngine = statusReportEngine ?? const StatusReportEngine(),
        _correlationEngine =
            correlationEngine ?? const CrossCorrelationEngine();

  final StatusReportEngine _statusReportEngine;
  final CrossCorrelationEngine _correlationEngine;

  @override
  String get skillId => 'status_report';

  @override
  Future<DeterministicStep> start(ToolContext ctx) async {
    final profile = _resolveAstronaut(ctx, null);
    final flags = await ctx.flags.allForAstronaut(profile.id);
    final report = _statusReportEngine.build(
      profile: profile,
      activeFlags: flags,
      now: ctx.now,
    );
    final vm = StatusReportViewModel.fromReport(report);
    return DeterministicStep(
      prompt: report.summary,
      options: const ['Vitals card', 'Subsystem correlation', 'Done'],
      uiEvents: [AgentComponentEvent.show(ComponentIds.statusReport, vm.toProps())],
    );
  }

  @override
  Future<DeterministicStep> advance(String userInput, ToolContext ctx) async {
    final normalized = userInput.trim().toLowerCase();
    final profile = _resolveAstronaut(ctx, null);
    final flags = await ctx.flags.allForAstronaut(profile.id);

    if (normalized.contains('vital')) {
      final vm = VitalsCardViewModel.fromAstronaut(profile);
      final v = profile.vitals;
      return DeterministicStep(
        prompt:
            '${profile.name}: HR ${v.heartRate.toStringAsFixed(0)} bpm, BP ${v.systolicBP.toStringAsFixed(0)}/${v.diastolicBP.toStringAsFixed(0)} mmHg, SpO2 ${v.spO2.toStringAsFixed(0)}%, Temp ${v.bodyTemp.toStringAsFixed(1)} C.',
        options: const ['Subsystem correlation', 'Done'],
        uiEvents: [
          AgentComponentEvent.show(ComponentIds.vitalsCard, vm.toProps()),
        ],
      );
    }

    if (normalized.contains('correlat') || normalized.contains('subsystem')) {
      final correlation = _correlationEngine.correlateSubsystems(
        profile: profile,
        activeFlags: flags,
      );
      final banner = AlertBannerViewModel(
        title: 'Cross-Subsystem Correlation (${profile.callsign})',
        severity: _mapCorrelationSeverity(correlation.overallRiskLevel),
        classification: 'cross_correlation',
        message: correlation.activeCrossSubsystemAlerts.isEmpty
            ? 'No cascading cross-subsystem risks detected.'
            : correlation.activeCrossSubsystemAlerts.join(' '),
        suppressed: false,
        astronautId: profile.id,
        details: correlation.recommendations,
      );
      return DeterministicStep(
        prompt: correlation.activeCrossSubsystemAlerts.isEmpty
            ? 'All monitored subsystems show nominal correlation.'
            : correlation.activeCrossSubsystemAlerts.join(' '),
        options: const ['Vitals card', 'Done'],
        uiEvents: [
          AgentComponentEvent.show(ComponentIds.alertBanner, banner.toProps()),
        ],
      );
    }

    final report = _statusReportEngine.build(
      profile: profile,
      activeFlags: flags,
      now: ctx.now,
    );
    return DeterministicStep(
      prompt: 'Status review complete for ${profile.name}.',
      isTerminal: true,
      verdict: report.toJson(),
    );
  }
}

/// Exports the 4 general-health and cross-subsystem [AgentSkill]s from D5.
List<AgentSkill> generalHealthSkills({
  StatusReportEngine? statusReportEngine,
  ArtifactFilterEngine? artifactFilterEngine,
  CrossCorrelationEngine? crossCorrelationEngine,
  InventoryLoader? inventoryLoader,
}) {
  final statusEngine = statusReportEngine ?? const StatusReportEngine();
  final filterEngine = artifactFilterEngine ?? const ArtifactFilterEngine();
  final correlationEngine =
      crossCorrelationEngine ?? const CrossCorrelationEngine();
  final loadInventory = inventoryLoader ?? _defaultInventoryLoader;

  return [
    AgentSkill(
      id: 'status_report',
      instructions:
          'Call build_status_report for overall crew member status across vitals, radiation, sleep, exercise, and active flags. Relay the deterministic verdict concisely and naturally without inventing thresholds.',
      tools: [_BuildStatusReportTool(statusEngine)],
      componentIds: const [
        ComponentIds.statusReport,
        ComponentIds.vitalsCard,
      ],
      triggers: const [
        'status',
        'report',
        'estado',
        'reporte',
        'resumen',
        'overview',
      ],
      offlineFlow: StatusReportOfflineFlow(
        statusReportEngine: statusEngine,
        correlationEngine: correlationEngine,
      ),
    ),
    AgentSkill(
      id: 'telemetry',
      instructions:
          'Use get_radiation_dose, get_sleep_history, get_exercise_session, and get_inventory for on-demand subsystem telemetry or medical kit stock. Present the exact returned values briefly.',
      tools: [
        const _GetRadiationDoseTool(),
        const _GetSleepHistoryTool(),
        const _GetExerciseSessionTool(),
        _GetInventoryTool(loadInventory),
      ],
      componentIds: const [ComponentIds.telemetryChart],
      triggers: const [
        'telemetry',
        'radiation',
        'radiacion',
        'sleep',
        'sueno',
        'sueño',
        'exercise',
        'ejercicio',
        'inventory',
        'inventario',
        'chart',
      ],
    ),
    AgentSkill(
      id: 'artifact_filter',
      instructions:
          'When SpO2 or heart rate alarms trigger during activity or motion, call classify_alarm_artifact first before escalating. Never override a true_clinical_alert verdict.',
      tools: [_ClassifyAlarmArtifactTool(filterEngine)],
      componentIds: const [ComponentIds.alertBanner],
      triggers: const [
        'artifact',
        'artefacto',
        'false alarm',
        'falsa alarma',
        'hypoxia',
        'hipoxia',
        'tachycardia',
        'taquicardia',
        'spo2',
        'accelerometry',
      ],
    ),
    AgentSkill(
      id: 'correlation',
      instructions:
          'Use assess_renal_stone_risk or correlate_subsystems when vomiting, dehydration, bone loss, orthostatic symptoms, sleep debt, or radiation load overlap. Relay the deterministic risk level and actions briefly.',
      tools: [
        _AssessRenalStoneRiskTool(correlationEngine),
        _CorrelateSubsystemsTool(correlationEngine, statusEngine),
      ],
      componentIds: const [
        ComponentIds.statusReport,
        ComponentIds.alertBanner,
      ],
      triggers: const [
        'renal',
        'stone',
        'litiasis',
        'kidney',
        'correlation',
        'correlacion',
        'cascade',
        'cascada',
        'hydration',
        'hidratacion',
        'orthostatic',
      ],
    ),
  ];
}

class _BuildStatusReportTool extends AgentTool {
  const _BuildStatusReportTool(this._engine);

  final StatusReportEngine _engine;

  @override
  String get name => 'build_status_report';

  @override
  String get description =>
      'Synthesizes a cross-subsystem status report from the astronaut profile, MedicalThresholds, CrewRiskLevel, active alerts, and active flags.';

  @override
  ToolEffect get effect => ToolEffect.ui;

  @override
  Map<String, dynamic> get parameters => const {
        'type': 'object',
        'properties': {
          'astronaut_id': {
            'type': 'string',
            'description': 'Astronaut ID; defaults to active astronaut.',
          },
          'include_vitals_card': {
            'type': 'boolean',
            'description': 'Also display the vitals_card component.',
          },
        },
      };

  @override
  Future<ToolResult> call(Map<String, dynamic> args, ToolContext ctx) async {
    final profile = _resolveAstronaut(ctx, args['astronaut_id'] as String?);
    final flags = await ctx.flags.allForAstronaut(profile.id);
    final report = _engine.build(
      profile: profile,
      activeFlags: flags,
      now: ctx.now,
    );
    final vm = StatusReportViewModel.fromReport(report);
    final uiEvents = <AgentComponentEvent>[
      AgentComponentEvent.show(ComponentIds.statusReport, vm.toProps()),
      if (args['include_vitals_card'] == true)
        AgentComponentEvent.show(
          ComponentIds.vitalsCard,
          VitalsCardViewModel.fromAstronaut(profile).toProps(),
        ),
    ];
    return ToolResult.ok(report.toJson(), uiEvents: uiEvents);
  }
}

class _GetRadiationDoseTool extends AgentTool {
  const _GetRadiationDoseTool();

  @override
  String get name => 'get_radiation_dose';

  @override
  String get description =>
      'Returns current radiation dose rate, cumulative exposure, PEL percentage, and emits a telemetry_chart.';

  @override
  ToolEffect get effect => ToolEffect.ui;

  @override
  Map<String, dynamic> get parameters => const {
        'type': 'object',
        'properties': {
          'astronaut_id': {'type': 'string'},
        },
      };

  @override
  Future<ToolResult> call(Map<String, dynamic> args, ToolContext ctx) async {
    final profile = _resolveAstronaut(ctx, args['astronaut_id'] as String?);
    final telemetry = _tryRead<TelemetryState>(ctx, telemetryProvider);
    final rad = profile.radiation;

    final packets = telemetry?.recentLogs
            .where((p) =>
                p.astronautId == profile.id &&
                p.metrics.containsKey('doseRateMicroSvPerHour'))
            .toList() ??
        const <TelemetryPacket>[];

    final series = <TelemetryDataPoint>[
      if (packets.isNotEmpty)
        for (final p in packets.reversed)
          TelemetryDataPoint(
            label: _shortTime(p.timestamp),
            value: (p.metrics['doseRateMicroSvPerHour'] as num).toDouble(),
            metadata: {
              'cumulative_msv': p.metrics['cumulativeDoseMilliSv'],
              'device': p.device,
            },
          )
      else ...[
        TelemetryDataPoint(
          label: '-12h',
          value: double.parse(
            (rad.doseRateMicroSvPerHour * 0.92).toStringAsFixed(1),
          ),
        ),
        TelemetryDataPoint(
          label: '-6h',
          value: double.parse(
            (rad.doseRateMicroSvPerHour * 0.96).toStringAsFixed(1),
          ),
        ),
        TelemetryDataPoint(
          label: _shortTime(rad.timestamp),
          value: rad.doseRateMicroSvPerHour,
          metadata: {'cumulative_msv': rad.cumulativeDoseMilliSv},
        ),
      ],
    ];

    final careerPct = double.parse(
      ((rad.cumulativeDoseMilliSv / MedicalThresholds.radiationCareerLimitMax) *
              100.0)
          .toStringAsFixed(1),
    );
    final summary = {
      'astronaut_id': profile.id,
      'dose_rate_usv_h': rad.doseRateMicroSvPerHour,
      'cumulative_dose_msv': rad.cumulativeDoseMilliSv,
      'career_limit_msv': MedicalThresholds.radiationCareerLimitMax,
      'career_limit_percent': careerPct,
      'severity': rad.severity.name,
      'device': rad.device,
    };

    final vm = TelemetryChartViewModel(
      title: 'Radiation Dose Rate (${profile.callsign})',
      metric: 'radiation_dose',
      unit: 'uSv/h',
      astronautId: profile.id,
      series: series,
      summary: summary,
    );

    return ToolResult.ok(
      summary,
      uiEvents: [AgentComponentEvent.show(ComponentIds.telemetryChart, vm.toProps())],
    );
  }
}

class _GetSleepHistoryTool extends AgentTool {
  const _GetSleepHistoryTool();

  @override
  String get name => 'get_sleep_history';

  @override
  String get description =>
      'Returns recent sleep duration, wake episodes, morning mood, and emits a telemetry_chart.';

  @override
  ToolEffect get effect => ToolEffect.ui;

  @override
  Map<String, dynamic> get parameters => const {
        'type': 'object',
        'properties': {
          'astronaut_id': {'type': 'string'},
          'days': {'type': 'integer', 'minimum': 1, 'maximum': 30},
        },
      };

  @override
  Future<ToolResult> call(Map<String, dynamic> args, ToolContext ctx) async {
    final profile = _resolveAstronaut(ctx, args['astronaut_id'] as String?);
    final days = ((args['days'] as num?)?.toInt() ?? 3).clamp(1, 30);
    final telemetry = _tryRead<TelemetryState>(ctx, telemetryProvider);
    final sleep = profile.sleep;

    final packets = telemetry?.recentLogs
            .where((p) =>
                p.astronautId == profile.id &&
                p.metrics.containsKey('sleepHours'))
            .take(days)
            .toList() ??
        const <TelemetryPacket>[];

    final series = <TelemetryDataPoint>[
      if (packets.isNotEmpty)
        for (final p in packets.reversed)
          TelemetryDataPoint(
            label: _shortDate(p.timestamp),
            value: (p.metrics['sleepHours'] as num).toDouble(),
            metadata: {'wake_episodes': p.metrics['wakeEpisodes']},
          )
      else
        TelemetryDataPoint(
          label: _shortDate(sleep.date),
          value: sleep.sleepHours,
          metadata: {
            'wake_episodes': sleep.wakeEpisodes,
            'morning_mood': sleep.morningMood.name,
          },
        ),
    ];

    final deficit = sleep.sleepHours < MedicalThresholds.minRecommendedSleepHours
        ? double.parse(
            (MedicalThresholds.minRecommendedSleepHours - sleep.sleepHours)
                .toStringAsFixed(1),
          )
        : 0.0;

    final summary = {
      'astronaut_id': profile.id,
      'sleep_hours': sleep.sleepHours,
      'wake_episodes': sleep.wakeEpisodes,
      'morning_mood': sleep.morningMood.name,
      'recommended_min_hours': MedicalThresholds.minRecommendedSleepHours,
      'optimal_hours': MedicalThresholds.optimalSleepHours,
      'deficit_hours': deficit,
      'device': sleep.device,
    };

    final vm = TelemetryChartViewModel(
      title: 'Sleep Duration (${profile.callsign})',
      metric: 'sleep_history',
      unit: 'hours',
      astronautId: profile.id,
      series: series,
      summary: summary,
    );

    return ToolResult.ok(
      summary,
      uiEvents: [AgentComponentEvent.show(ComponentIds.telemetryChart, vm.toProps())],
    );
  }
}

class _GetExerciseSessionTool extends AgentTool {
  const _GetExerciseSessionTool();

  @override
  String get name => 'get_exercise_session';

  @override
  String get description =>
      'Returns the astronaut exercise countermeasure session metrics and emits a telemetry_chart.';

  @override
  ToolEffect get effect => ToolEffect.ui;

  @override
  Map<String, dynamic> get parameters => const {
        'type': 'object',
        'properties': {
          'astronaut_id': {'type': 'string'},
        },
      };

  @override
  Future<ToolResult> call(Map<String, dynamic> args, ToolContext ctx) async {
    final profile = _resolveAstronaut(ctx, args['astronaut_id'] as String?);
    final telemetry = _tryRead<TelemetryState>(ctx, telemetryProvider);
    final ex = profile.exercise;

    final packets = telemetry?.recentLogs
            .where((p) =>
                p.astronautId == profile.id &&
                p.metrics.containsKey('durationMinutes'))
            .toList() ??
        const <TelemetryPacket>[];

    final series = <TelemetryDataPoint>[
      if (packets.isNotEmpty)
        for (final p in packets.reversed)
          TelemetryDataPoint(
            label: p.metrics['deviceName']?.toString() ?? p.device,
            value: (p.metrics['durationMinutes'] as num).toDouble(),
            metadata: {
              'calories_burned': p.metrics['caloriesBurned'],
              'target_reached': p.metrics['targetReached'],
            },
          )
      else
        TelemetryDataPoint(
          label: ex.deviceName,
          value: ex.durationMinutes.toDouble(),
          metadata: {
            'calories_burned': ex.caloriesBurned,
            'target_reached': ex.targetReached,
          },
        ),
    ];

    final summary = {
      'astronaut_id': profile.id,
      'device_name': ex.deviceName,
      'duration_minutes': ex.durationMinutes,
      'calories_burned': ex.caloriesBurned,
      'target_reached': ex.targetReached,
      'activity_state': ex.activityState,
      'date': ex.date.toUtc().toIso8601String(),
    };

    final vm = TelemetryChartViewModel(
      title: 'Exercise Countermeasure (${profile.callsign})',
      metric: 'exercise_session',
      unit: 'min',
      astronautId: profile.id,
      series: series,
      summary: summary,
    );

    return ToolResult.ok(
      summary,
      uiEvents: [AgentComponentEvent.show(ComponentIds.telemetryChart, vm.toProps())],
    );
  }
}

class _GetInventoryTool extends AgentTool {
  const _GetInventoryTool(this._loadInventory);

  final InventoryLoader _loadInventory;

  @override
  String get name => 'get_inventory';

  @override
  String get description =>
      'Returns spacecraft medical kit & astropharmacy inventory levels with flagged batch status and emits a telemetry_chart.';

  @override
  ToolEffect get effect => ToolEffect.ui;

  @override
  Map<String, dynamic> get parameters => const {
        'type': 'object',
        'properties': {
          'category': {'type': 'string'},
          'item': {'type': 'string'},
        },
      };

  @override
  Future<ToolResult> call(Map<String, dynamic> args, ToolContext ctx) async {
    final categoryFilter =
        (args['category'] as String?)?.trim().toLowerCase();
    final itemFilter = (args['item'] as String?)?.trim().toLowerCase();

    final rawItems = await _loadInventory();
    final flags = await ctx.flags.allForAstronaut(ctx.astronautId);
    final flaggedBatchesRaw = flags['flagged_batches']?['batches'];
    final flaggedBatches = flaggedBatchesRaw is List
        ? flaggedBatchesRaw.map((e) => e.toString()).toSet()
        : <String>{};

    final filtered = rawItems.where((entry) {
      final cat = entry['category']?.toString().toLowerCase() ?? '';
      final name = entry['name']?.toString().toLowerCase() ?? '';
      if (categoryFilter != null &&
          categoryFilter.isNotEmpty &&
          !cat.contains(categoryFilter)) {
        return false;
      }
      if (itemFilter != null &&
          itemFilter.isNotEmpty &&
          !name.contains(itemFilter)) {
        return false;
      }
      return true;
    }).map((entry) {
      final batchId = entry['batch_id']?.toString() ?? '';
      final isFlagged = entry['flagged'] == true ||
          (batchId.isNotEmpty && flaggedBatches.contains(batchId));
      return {
        ...entry,
        'flagged': isFlagged,
      };
    }).toList(growable: false);

    final series = filtered
        .map(
          (entry) => TelemetryDataPoint(
            label: entry['name'].toString(),
            value: (entry['units'] as num).toDouble(),
            metadata: {
              'batch_id': entry['batch_id'],
              'category': entry['category'],
              'location': entry['location'],
              'flagged': entry['flagged'],
            },
          ),
        )
        .toList(growable: false);

    final summary = {
      'total_items': filtered.length,
      'flagged_count': filtered.where((e) => e['flagged'] == true).length,
      'items': filtered,
    };

    final vm = TelemetryChartViewModel(
      title: 'Medical Kit & Pharmacy Inventory',
      metric: 'inventory',
      unit: 'units',
      astronautId: ctx.astronautId,
      series: series,
      summary: summary,
    );

    return ToolResult.ok(
      summary,
      uiEvents: [AgentComponentEvent.show(ComponentIds.telemetryChart, vm.toProps())],
    );
  }
}

class _ClassifyAlarmArtifactTool extends AgentTool {
  const _ClassifyAlarmArtifactTool(this._engine);

  final ArtifactFilterEngine _engine;

  @override
  String get name => 'classify_alarm_artifact';

  @override
  String get description =>
      'Crosses SpO2/heart-rate biometric alarms with triaxial accelerometry, exercise state, and optical signal quality to distinguish kinetic artifacts or physiological exercise response from true clinical alerts.';

  @override
  ToolEffect get effect => ToolEffect.ui;

  @override
  Map<String, dynamic> get parameters => const {
        'type': 'object',
        'properties': {
          'astronaut_id': {'type': 'string'},
          'acceleration_rms_g': {'type': 'number', 'minimum': 0},
          'motion_artifact_index': {
            'type': 'number',
            'minimum': 0,
            'maximum': 1,
          },
          'activity_state': {'type': 'string'},
          'signal_quality': {'type': 'string'},
          'spo2': {'type': 'number'},
          'heart_rate': {'type': 'number'},
          'respiratory_rate': {'type': 'number'},
          'systolic_bp': {'type': 'number'},
          'capillary_refill_seconds': {'type': 'number'},
        },
      };

  @override
  Future<ToolResult> call(Map<String, dynamic> args, ToolContext ctx) async {
    final profile = _resolveAstronaut(ctx, args['astronaut_id'] as String?);
    final baseVitals = profile.vitals;
    final motionArtifactIndex =
        (args['motion_artifact_index'] as num?)?.toDouble();
    final explicitSignalQuality = args['signal_quality'] as String?;
    final resolvedSignalQuality = explicitSignalQuality ??
        ((motionArtifactIndex != null &&
                motionArtifactIndex >=
                    ArtifactFilterEngine.highMotionArtifactIndex)
            ? 'degraded (motion artifact)'
            : baseVitals.signalQuality);

    final effectiveVitals = VitalsRecord(
      timestamp: baseVitals.timestamp,
      astronautId: profile.id,
      source: baseVitals.source,
      deviceId: baseVitals.deviceId,
      device: baseVitals.device,
      protocol: baseVitals.protocol,
      measurementMethod: baseVitals.measurementMethod,
      activityState:
          args['activity_state'] as String? ?? baseVitals.activityState,
      signalQuality: resolvedSignalQuality,
      recordType: baseVitals.recordType,
      algorithm: baseVitals.algorithm,
      criterionReference: baseVitals.criterionReference,
      heartRate: (args['heart_rate'] as num?)?.toDouble() ?? baseVitals.heartRate,
      systolicBP:
          (args['systolic_bp'] as num?)?.toDouble() ?? baseVitals.systolicBP,
      diastolicBP: baseVitals.diastolicBP,
      spO2: (args['spo2'] as num?)?.toDouble() ?? baseVitals.spO2,
      bodyTemp: baseVitals.bodyTemp,
      bloodGlucose: baseVitals.bloodGlucose,
      respiratoryRate: (args['respiratory_rate'] as num?)?.toDouble() ??
          baseVitals.respiratoryRate,
      capillaryRefillSeconds:
          (args['capillary_refill_seconds'] as num?)?.toDouble() ??
              baseVitals.capillaryRefillSeconds,
    );

    final result = _engine.classify(
      vitals: effectiveVitals,
      accelerationRmsG: (args['acceleration_rms_g'] as num?)?.toDouble() ?? 0.0,
      motionArtifactIndex: motionArtifactIndex,
      exercise: profile.exercise,
    );

    final severity = switch (result.classification) {
      ArtifactClassification.trueClinicalAlert => 'critical',
      ArtifactClassification.kineticMotionArtifact => 'info',
      ArtifactClassification.physiologicalExerciseResponse => 'info',
      ArtifactClassification.nominal => 'info',
    };

    final banner = AlertBannerViewModel(
      title: 'Telemetry Alarm Filter (${profile.callsign})',
      severity: severity,
      classification: result.classification.wireName,
      message: result.recommendedAction,
      suppressed: result.suppressAlarm,
      recommendedAction: result.recommendedAction,
      astronautId: profile.id,
      details: result.reasons,
    );

    return ToolResult.ok(
      result.toJson(),
      uiEvents: [AgentComponentEvent.show(ComponentIds.alertBanner, banner.toProps())],
    );
  }
}

class _AssessRenalStoneRiskTool extends AgentTool {
  const _AssessRenalStoneRiskTool(this._engine);

  final CrossCorrelationEngine _engine;

  @override
  String get name => 'assess_renal_stone_risk';

  @override
  String get description =>
      'Crosses emesis/vomiting episodes, daily hydration intake (<1800 mL), and microgravity bone resorption markers to assess nephrolithiasis risk.';

  @override
  ToolEffect get effect => ToolEffect.ui;

  @override
  Map<String, dynamic> get parameters => const {
        'type': 'object',
        'properties': {
          'astronaut_id': {'type': 'string'},
          'emesis_episodes': {'type': 'integer', 'minimum': 0},
          'hydration_ml_per_day': {'type': 'number', 'minimum': 0},
          'low_urine_output': {'type': 'boolean'},
          'urinary_calcium_mg_per_day': {'type': 'number', 'minimum': 0},
          'bone_resorption_elevated': {'type': 'boolean'},
          'bone_loss_percent': {'type': 'number', 'minimum': 0},
        },
      };

  @override
  Future<ToolResult> call(Map<String, dynamic> args, ToolContext ctx) async {
    final profile = _resolveAstronaut(ctx, args['astronaut_id'] as String?);
    final assessment = _engine.assessRenalStoneRisk(
      profile: profile,
      emesisEpisodes: (args['emesis_episodes'] as num?)?.toInt() ?? 0,
      hydrationMlPerDay: (args['hydration_ml_per_day'] as num?)?.toDouble(),
      lowUrineOutput: args['low_urine_output'] as bool? ?? false,
      urinaryCalciumMgPerDay:
          (args['urinary_calcium_mg_per_day'] as num?)?.toDouble(),
      boneResorptionElevated:
          args['bone_resorption_elevated'] as bool? ?? false,
      boneLossPercent: (args['bone_loss_percent'] as num?)?.toDouble(),
    );

    final banner = AlertBannerViewModel(
      title: 'Renal Stone Risk (${profile.callsign})',
      severity: _mapCorrelationSeverity(assessment.riskLevel),
      classification: 'renal_stone_risk',
      message: assessment.summary,
      suppressed: false,
      recommendedAction:
          'Target ${assessment.hydrationTargetMl} mL/day hydration.',
      astronautId: profile.id,
      details: assessment.contributingFactors,
    );

    return ToolResult.ok(
      assessment.toJson(),
      uiEvents: [AgentComponentEvent.show(ComponentIds.alertBanner, banner.toProps())],
    );
  }
}

class _CorrelateSubsystemsTool extends AgentTool {
  const _CorrelateSubsystemsTool(
    this._correlationEngine,
    this._statusReportEngine,
  );

  final CrossCorrelationEngine _correlationEngine;
  final StatusReportEngine _statusReportEngine;

  @override
  String get name => 'correlate_subsystems';

  @override
  String get description =>
      'Runs full cross-subsystem correlation (renal stone cascade and cardiovascular-vestibular-fatigue cascade) and emits status_report and alert_banner.';

  @override
  ToolEffect get effect => ToolEffect.ui;

  @override
  Map<String, dynamic> get parameters => const {
        'type': 'object',
        'properties': {
          'astronaut_id': {'type': 'string'},
          'emesis_episodes': {'type': 'integer', 'minimum': 0},
          'hydration_ml_per_day': {'type': 'number', 'minimum': 0},
          'low_urine_output': {'type': 'boolean'},
          'urinary_calcium_mg_per_day': {'type': 'number', 'minimum': 0},
          'bone_resorption_elevated': {'type': 'boolean'},
          'bone_loss_percent': {'type': 'number', 'minimum': 0},
          'orthostatic_intolerance': {'type': 'boolean'},
          'graybiel_score': {'type': 'integer', 'minimum': 0},
        },
      };

  @override
  Future<ToolResult> call(Map<String, dynamic> args, ToolContext ctx) async {
    final profile = _resolveAstronaut(ctx, args['astronaut_id'] as String?);
    final flags = await ctx.flags.allForAstronaut(profile.id);

    final report = _correlationEngine.correlateSubsystems(
      profile: profile,
      emesisEpisodes: (args['emesis_episodes'] as num?)?.toInt() ?? 0,
      hydrationMlPerDay: (args['hydration_ml_per_day'] as num?)?.toDouble(),
      lowUrineOutput: args['low_urine_output'] as bool? ?? false,
      urinaryCalciumMgPerDay:
          (args['urinary_calcium_mg_per_day'] as num?)?.toDouble(),
      boneResorptionElevated:
          args['bone_resorption_elevated'] as bool? ?? false,
      boneLossPercent: (args['bone_loss_percent'] as num?)?.toDouble(),
      orthostaticIntolerance:
          args['orthostatic_intolerance'] as bool? ?? false,
      graybielScore: (args['graybiel_score'] as num?)?.toInt(),
      activeFlags: flags,
    );

    final statusReport = _statusReportEngine.build(
      profile: profile,
      activeFlags: flags,
      now: ctx.now,
    );
    final statusVm = StatusReportViewModel.fromReport(statusReport);

    final bannerVm = AlertBannerViewModel(
      title: 'Cross-Subsystem Correlation (${profile.callsign})',
      severity: _mapCorrelationSeverity(report.overallRiskLevel),
      classification: 'cross_correlation',
      message: report.activeCrossSubsystemAlerts.isEmpty
          ? 'No cascading cross-subsystem risks detected.'
          : report.activeCrossSubsystemAlerts.join(' '),
      suppressed: false,
      recommendedAction: report.recommendations.isNotEmpty
          ? report.recommendations.join(' ')
          : null,
      astronautId: profile.id,
      details: report.recommendations,
    );

    return ToolResult.ok(
      report.toJson(),
      uiEvents: [
        AgentComponentEvent.show(ComponentIds.statusReport, statusVm.toProps()),
        AgentComponentEvent.show(ComponentIds.alertBanner, bannerVm.toProps()),
      ],
    );
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

T? _tryRead<T>(ToolContext ctx, Object provider) {
  try {
    return ctx.read<T>(provider);
  } catch (_) {
    return null;
  }
}

String _mapCorrelationSeverity(CorrelationRiskLevel level) {
  return switch (level) {
    CorrelationRiskLevel.high => 'critical',
    CorrelationRiskLevel.elevated => 'warning',
    CorrelationRiskLevel.nominal => 'info',
  };
}

String _shortTime(DateTime dt) {
  final u = dt.toUtc();
  final hh = u.hour.toString().padLeft(2, '0');
  final mm = u.minute.toString().padLeft(2, '0');
  return '$hh:$mm';
}

String _shortDate(DateTime dt) {
  final u = dt.toUtc();
  final mm = u.month.toString().padLeft(2, '0');
  final dd = u.day.toString().padLeft(2, '0');
  return '${u.year}-$mm-$dd';
}

List<String> _stringList(Object? raw) {
  if (raw is! List) return const [];
  return raw.map((e) => e.toString()).toList(growable: false);
}

Map<String, dynamic> _stringMap(Object? raw) {
  if (raw is! Map) return const {};
  return Map<String, dynamic>.from(raw);
}

Future<List<Map<String, dynamic>>> _defaultInventoryLoader() async {
  try {
    final jsonStr = await rootBundle.loadString(
      'DB/Pharmacy/medication_inventory.json',
    );
    final decoded = jsonDecode(jsonStr);
    if (decoded is List) {
      return decoded
          .whereType<Map>()
          .map((m) => Map<String, dynamic>.from(m))
          .toList(growable: false);
    }
    if (decoded is Map) {
      final list = decoded['batches'] ?? decoded['items'];
      if (list is List) {
        return list
            .whereType<Map>()
            .map((m) => Map<String, dynamic>.from(m))
            .toList(growable: false);
      }
    }
  } catch (_) {
    // Fallback when asset is absent or Flutter binding is not initialized in unit tests.
  }
  return _baselineMedicalKitInventory;
}

const List<Map<String, dynamic>> _baselineMedicalKitInventory = [
  {
    'id': 'MED-KCIT',
    'name': 'Potassium Citrate',
    'category': 'renal_prophylaxis',
    'batch_id': 'BATCH-KCIT-01',
    'units': 60,
    'location': 'Medical Bay Rack A',
    'flagged': false,
  },
  {
    'id': 'MED-OND',
    'name': 'Ondansetron',
    'category': 'antiemetic',
    'batch_id': 'BATCH-OND-02',
    'units': 24,
    'location': 'Medical Bay Rack A',
    'flagged': false,
  },
  {
    'id': 'MED-PROM',
    'name': 'Promethazine (Intranasal/IM)',
    'category': 'antiemetic',
    'batch_id': 'BATCH-PROM-01',
    'units': 12,
    'location': 'Unshielded Node Locker',
    'flagged': false,
  },
  {
    'id': 'MED-ORS',
    'name': 'Oral Rehydration Salts',
    'category': 'hydration',
    'batch_id': 'BATCH-ORS-04',
    'units': 48,
    'location': 'Galley Medical Drawer',
    'flagged': false,
  },
  {
    'id': 'MED-MOD',
    'name': 'Modafinil',
    'category': 'stimulant',
    'batch_id': 'BATCH-MOD-01',
    'units': 18,
    'location': 'Medical Bay Rack B',
    'flagged': false,
  },
  {
    'id': 'MED-ZAL',
    'name': 'Zaleplon',
    'category': 'hypnotic',
    'batch_id': 'BATCH-ZAL-01',
    'units': 20,
    'location': 'Medical Bay Rack B',
    'flagged': false,
  },
  {
    'id': 'SUP-O2',
    'name': 'Oxygen Mask & Cylinder',
    'category': 'emergency_airway',
    'batch_id': 'BATCH-O2-01',
    'units': 4,
    'location': 'Airlock Quest Emergency Kit',
    'flagged': false,
  },
];
