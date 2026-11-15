import 'package:astramed/features/01_general_health/agent/artifact_filter_engine.dart';
import 'package:astramed/features/01_general_health/agent/cross_correlation_engine.dart';
import 'package:astramed/features/01_general_health/agent/general_health_skills.dart';
import 'package:astramed/features/01_general_health/agent/status_report_engine.dart';
import 'package:astramed/features/01_general_health/models/vitals_record.dart';
import 'package:astramed/features/02_radiation/models/radiation_dose.dart';
import 'package:astramed/features/03_microgravity/models/microgravity_data.dart';
import 'package:astramed/features/04_mental_health/models/sleep_record.dart';
import 'package:astramed/features/agent/domain/agent_contracts.dart';
import 'package:astramed/features/crew/data/mock_crew_data.dart';
import 'package:astramed/features/crew/models/astronaut_profile.dart';
import 'package:astramed/features/crew/presentation/providers/crew_provider.dart';
import 'package:flutter_test/flutter_test.dart';

class _RecordingUiSink implements AgentUiSink {
  final List<AgentComponentEvent> events = [];

  @override
  void emit(AgentComponentEvent event) {
    events.add(event);
  }

  @override
  void submit(String componentId, Map<String, dynamic> result) {}
}

class _FakeMemoryStore implements MemoryStore {
  @override
  Future<List<MemoryEntry>> recall(
    String astronautId, {
    String? query,
    Set<MemoryKind>? kinds,
    int limit = 10,
  }) async =>
      const [];

  @override
  Future<List<MemoryEntry>> recentForPrompt(
    String astronautId, {
    int limit = 8,
  }) async =>
      const [];

  @override
  Future<MemoryEntry> save(MemoryEntry entry) async => entry;
}

class _FakeAuditLog implements AuditLog {
  @override
  Future<void> append(AuditEntry entry) async {}

  @override
  Future<List<AuditEntry>> list({String? astronautId, int limit = 50}) async =>
      const [];
}

class _FakeConfirmationGate implements ConfirmationGate {
  @override
  ConsequentialAction? get pending => null;

  @override
  Future<ConfirmationDecision> request(
    ConsequentialAction action, {
    required Future<Map<String, dynamic>> Function() onConfirmed,
  }) async =>
      ConfirmationDecision.confirmed;

  @override
  Future<Map<String, dynamic>?> resolve(
    String actionId,
    ConfirmationDecision decision, {
    String? reason,
  }) async =>
      null;
}

class _FakeFlagsStore implements AgentFlagsStore {
  _FakeFlagsStore([Map<String, Map<String, Map<String, dynamic>>>? initial])
      : _store = initial ?? {};

  final Map<String, Map<String, Map<String, dynamic>>> _store;

  @override
  Future<Map<String, Map<String, dynamic>>> allForAstronaut(
    String astronautId,
  ) async {
    return Map<String, Map<String, dynamic>>.from(_store[astronautId] ?? {});
  }

  @override
  Future<Map<String, dynamic>?> getFlag(String astronautId, String key) async {
    return _store[astronautId]?[key];
  }

  @override
  Future<void> setFlag(
    String astronautId,
    String key,
    Map<String, dynamic> value,
  ) async {
    _store.putIfAbsent(astronautId, () => {})[key] = value;
  }
}

class _FakeMedicationSafety implements MedicationSafety {
  @override
  Future<MedicationCheck> validate(MedicationRequest request) async {
    return const MedicationCheck(allowed: true, reasons: []);
  }
}

ToolContext _makeContext({
  required List<AstronautProfile> crew,
  String astronautId = 'AST-01',
  _FakeFlagsStore? flags,
  _RecordingUiSink? ui,
}) {
  return ToolContext(
    astronautId: astronautId,
    read: <T>(Object provider) {
      if (provider == crewMembersProvider) {
        return crew as T;
      }
      if (provider == selectedAstronautIdProvider) {
        return astronautId as T;
      }
      throw UnimplementedError('Provider not stubbed in test: $provider');
    },
    ui: ui ?? _RecordingUiSink(),
    confirm: _FakeConfirmationGate(),
    audit: _FakeAuditLog(),
    memory: _FakeMemoryStore(),
    flags: flags ?? _FakeFlagsStore(),
    medication: _FakeMedicationSafety(),
    now: DateTime.utc(2026, 11, 14, 21, 0),
  );
}

VitalsRecord _vitals({
  String astronautId = 'AST-01',
  double heartRate = 72.0,
  double systolicBP = 120.0,
  double diastolicBP = 78.0,
  double spO2 = 98.0,
  double bodyTemp = 36.6,
  double bloodGlucose = 92.0,
  double respiratoryRate = 16.0,
  double capillaryRefillSeconds = 1.5,
  String activityState = 'active_duty',
  String signalQuality = 'optimal (98%)',
}) {
  return VitalsRecord(
    timestamp: DateTime.utc(2026, 11, 14, 21, 0),
    astronautId: astronautId,
    heartRate: heartRate,
    systolicBP: systolicBP,
    diastolicBP: diastolicBP,
    spO2: spO2,
    bodyTemp: bodyTemp,
    bloodGlucose: bloodGlucose,
    respiratoryRate: respiratoryRate,
    capillaryRefillSeconds: capillaryRefillSeconds,
    activityState: activityState,
    signalQuality: signalQuality,
  );
}

AgentTool _findTool(List<AgentSkill> skills, String name) {
  for (final skill in skills) {
    for (final tool in skill.tools) {
      if (tool.name == name) return tool;
    }
  }
  throw StateError('Tool not found: $name');
}

void main() {
  group('generalHealthSkills registry', () {
    test('exports all 4 D5 skills and 8 tools with expected componentIds', () {
      final skills = generalHealthSkills();
      expect(skills.map((s) => s.id), containsAll([
        'status_report',
        'telemetry',
        'artifact_filter',
        'correlation',
      ]));

      final toolNames = skills.expand((s) => s.tools).map((t) => t.name).toSet();
      expect(toolNames, {
        'build_status_report',
        'get_radiation_dose',
        'get_sleep_history',
        'get_exercise_session',
        'get_inventory',
        'classify_alarm_artifact',
        'assess_renal_stone_risk',
        'correlate_subsystems',
      });

      final statusSkill = skills.firstWhere((s) => s.id == 'status_report');
      expect(statusSkill.offlineFlow, isNotNull);
      expect(statusSkill.componentIds, contains(ComponentIds.statusReport));
    });
  });

  group('StatusReportEngine & build_status_report', () {
    test('reflects AstronautProfile riskLevel, alerts, and active flags', () async {
      final crew = MockCrewData.getInitialCrew();
      final flags = _FakeFlagsStore({
        'AST-03': {
          'eva_blocked': {'blocked': true, 'reason': 'Post-EVA hypoxia'},
        },
      });
      final ctx = _makeContext(crew: crew, astronautId: 'AST-03', flags: flags);
      final engine = const StatusReportEngine();
      final ast3 = crew.firstWhere((a) => a.id == 'AST-03');

      final report = engine.build(
        profile: ast3,
        activeFlags: await flags.allForAstronaut('AST-03'),
        now: ctx.now,
      );

      expect(report.riskLevel, CrewRiskLevel.critical);
      expect(report.activeAlerts, equals(ast3.activeAlerts));
      expect(report.activeFlags.containsKey('eva_blocked'), isTrue);

      final tool = _findTool(generalHealthSkills(), 'build_status_report');
      final result = await tool.call({'include_vitals_card': true}, ctx);
      expect(result.ok, isTrue);
      expect(result.data['risk_level'], 'critical');
      expect(result.data['active_alerts'], equals(ast3.activeAlerts));
      expect((result.data['active_flags'] as Map).containsKey('eva_blocked'), isTrue);
      expect(result.uiEvents.length, 2);

      final statusEvent = result.uiEvents.first as ShowComponentEvent;
      expect(statusEvent.id, ComponentIds.statusReport);
      final vm = StatusReportViewModel.fromProps(statusEvent.props);
      expect(vm.riskLevel, 'critical');
      expect(vm.astronautId, 'AST-03');

      final vitalsEvent = result.uiEvents[1] as ShowComponentEvent;
      expect(vitalsEvent.id, ComponentIds.vitalsCard);
      final vitalsVm = VitalsCardViewModel.fromProps(vitalsEvent.props);
      expect(vitalsVm.spO2, ast3.vitals.spO2);
    });

    test('StatusReportOfflineFlow runs start and advance deterministically', () async {
      final crew = MockCrewData.getInitialCrew();
      final ctx = _makeContext(crew: crew, astronautId: 'AST-01');
      final statusSkill =
          generalHealthSkills().firstWhere((s) => s.id == 'status_report');
      final flow = statusSkill.offlineFlow!;

      final step1 = await flow.start(ctx);
      expect(step1.isTerminal, isFalse);
      expect(step1.uiEvents.whereType<ShowComponentEvent>().first.id,
          ComponentIds.statusReport);
      expect(step1.options, isNotEmpty);

      final step2 = await flow.advance('Vitals card', ctx);
      expect(step2.uiEvents.whereType<ShowComponentEvent>().first.id,
          ComponentIds.vitalsCard);

      final step3 = await flow.advance('Done', ctx);
      expect(step3.isTerminal, isTrue);
      expect(step3.verdict?['risk_level'], 'nominal');
    });
  });

  group('ArtifactFilterEngine & classify_alarm_artifact', () {
    const engine = ArtifactFilterEngine();

    test('suppresses false SpO2 hypoxia during high-motion exercise with degraded signal', () {
      final result = engine.classify(
        vitals: _vitals(
          spO2: 90.0,
          heartRate: 132.0,
          systolicBP: 124.0,
          respiratoryRate: 20.0,
          capillaryRefillSeconds: 1.5,
          activityState: 'exercise',
          signalQuality: 'degraded (54%)',
        ),
        accelerationRmsG: 0.48,
        motionArtifactIndex: 0.72,
      );

      expect(result.classification, ArtifactClassification.kineticMotionArtifact);
      expect(result.suppressAlarm, isTrue);
      expect(result.recommendedAction.toLowerCase(), contains('30'));
    });

    test('classifies proportional exercise tachycardia as physiological_exercise_response', () {
      final result = engine.classify(
        vitals: _vitals(
          spO2: 97.0,
          heartRate: 148.0,
          systolicBP: 134.0,
          respiratoryRate: 21.0,
          capillaryRefillSeconds: 1.4,
          activityState: 'exercise',
          signalQuality: 'optimal (95%)',
        ),
        accelerationRmsG: 0.42,
        exercise: ExerciseSession(
          date: DateTime.utc(2026, 11, 14, 21, 0),
          deviceName: 'CEVIS',
          durationMinutes: 25,
          caloriesBurned: 240,
          targetReached: false,
        ),
      );

      expect(
        result.classification,
        ArtifactClassification.physiologicalExerciseResponse,
      );
      expect(result.suppressAlarm, isTrue);
    });

    test('preserves true hypoxia at rest even with degraded signal', () {
      final result = engine.classify(
        vitals: _vitals(
          spO2: 90.0,
          heartRate: 118.0,
          systolicBP: 115.0,
          respiratoryRate: 20.0,
          capillaryRefillSeconds: 1.6,
          activityState: 'resting',
          signalQuality: 'degraded (52%)',
        ),
        accelerationRmsG: 0.03,
      );

      expect(result.classification, ArtifactClassification.trueClinicalAlert);
      expect(result.suppressAlarm, isFalse);
    });

    test('preserves true hypoxia when optical signal quality is good', () {
      final result = engine.classify(
        vitals: _vitals(
          spO2: 90.0,
          heartRate: 122.0,
          systolicBP: 118.0,
          respiratoryRate: 20.0,
          capillaryRefillSeconds: 1.6,
          activityState: 'exercise',
          signalQuality: 'optimal (98%)',
        ),
        accelerationRmsG: 0.45,
      );

      expect(result.classification, ArtifactClassification.trueClinicalAlert);
      expect(result.suppressAlarm, isFalse);
    });

    test('preserves true hypoxia when SpO2 < 88% regardless of motion or poor signal', () {
      final result = engine.classify(
        vitals: _vitals(
          spO2: 86.0,
          heartRate: 135.0,
          systolicBP: 120.0,
          respiratoryRate: 20.0,
          capillaryRefillSeconds: 1.5,
          activityState: 'exercise',
          signalQuality: 'degraded (48%)',
        ),
        accelerationRmsG: 0.65,
        motionArtifactIndex: 0.85,
      );

      expect(result.classification, ArtifactClassification.trueClinicalAlert);
      expect(result.suppressAlarm, isFalse);
    });

    test('preserves true clinical alert when accompanied by hypotension, tachypnea >= 26, or capillary refill > 2.5s', () {
      final hypotensive = engine.classify(
        vitals: _vitals(
          spO2: 91.0,
          systolicBP: 84.0,
          activityState: 'exercise',
          signalQuality: 'degraded (50%)',
        ),
        accelerationRmsG: 0.5,
      );
      expect(hypotensive.classification, ArtifactClassification.trueClinicalAlert);

      final tachypneic = engine.classify(
        vitals: _vitals(
          spO2: 91.0,
          respiratoryRate: 26.0,
          activityState: 'exercise',
          signalQuality: 'degraded (50%)',
        ),
        accelerationRmsG: 0.5,
      );
      expect(tachypneic.classification, ArtifactClassification.trueClinicalAlert);

      final poorPerfusion = engine.classify(
        vitals: _vitals(
          spO2: 91.0,
          capillaryRefillSeconds: 2.7,
          activityState: 'exercise',
          signalQuality: 'degraded (50%)',
        ),
        accelerationRmsG: 0.5,
      );
      expect(poorPerfusion.classification, ArtifactClassification.trueClinicalAlert);
    });

    test('classify_alarm_artifact tool emits alert_banner component', () async {
      final crew = MockCrewData.getInitialCrew();
      final ctx = _makeContext(crew: crew, astronautId: 'AST-01');
      final tool = _findTool(generalHealthSkills(), 'classify_alarm_artifact');

      final res = await tool.call({
        'spo2': 90.0,
        'heart_rate': 130.0,
        'acceleration_rms_g': 0.5,
        'activity_state': 'exercise',
        'signal_quality': 'degraded (55%)',
      }, ctx);

      expect(res.ok, isTrue);
      expect(res.data['classification'], 'kinetic_motion_artifact');
      expect(res.data['suppress_alarm'], isTrue);
      final event = res.uiEvents.single as ShowComponentEvent;
      expect(event.id, ComponentIds.alertBanner);
      final banner = AlertBannerViewModel.fromProps(event.props);
      expect(banner.suppressed, isTrue);
      expect(banner.classification, 'kinetic_motion_artifact');
    });
  });

  group('CrossCorrelationEngine & correlation tools', () {
    const engine = CrossCorrelationEngine();

    test('renal stone cascade triggers high risk on emesis + low hydration + bone resorption', () {
      final crew = MockCrewData.getInitialCrew();
      final ast1 = crew.firstWhere((a) => a.id == 'AST-01');

      final assessment = engine.assessRenalStoneRisk(
        profile: ast1,
        emesisEpisodes: 2,
        hydrationMlPerDay: 1200,
        boneResorptionElevated: true,
        urinaryCalciumMgPerDay: 310,
      );

      expect(assessment.riskLevel, CorrelationRiskLevel.high);
      expect(assessment.recommendRenalUltrasound, isTrue);
      expect(assessment.recommendPotassiumCitrate, isTrue);
      expect(assessment.hydrationTargetMl, greaterThanOrEqualTo(2500));
      expect(assessment.contributingFactors.length, greaterThanOrEqualTo(3));
    });

    test('renal stone cascade stays nominal when hydrated and asymptomatic', () {
      final crew = MockCrewData.getInitialCrew();
      final ast1 = crew.firstWhere((a) => a.id == 'AST-01');

      final assessment = engine.assessRenalStoneRisk(
        profile: ast1,
        emesisEpisodes: 0,
        hydrationMlPerDay: 2400,
        boneResorptionElevated: false,
      );

      expect(assessment.riskLevel, CorrelationRiskLevel.nominal);
      expect(assessment.recommendRenalUltrasound, isFalse);
      expect(assessment.recommendPotassiumCitrate, isFalse);
      expect(assessment.contributingFactors, isEmpty);
    });

    test('cardio-vestibular-fatigue cascade detects multi-subsystem compounding risk', () {
      final crew = MockCrewData.getInitialCrew();
      final ast3 = crew.firstWhere((a) => a.id == 'AST-03').copyWith(
            vitals: _vitals(
              astronautId: 'AST-03',
              systolicBP: 86.0,
              heartRate: 112.0,
              spO2: 96.0,
            ),
            sleep: SleepRecord(
              date: DateTime.utc(2026, 11, 14),
              astronautId: 'AST-03',
              sleepHours: 4.2,
              wakeEpisodes: 4,
              morningMood: MoodLevel.stressed,
            ),
            radiation: RadiationDose(
              timestamp: DateTime.utc(2026, 11, 14),
              astronautId: 'AST-03',
              doseRateMicroSvPerHour: 140.0,
              cumulativeDoseMilliSv: 65.0,
              severity: RadiationSeverity.warning,
            ),
          );

      final report = engine.correlateSubsystems(
        profile: ast3,
        emesisEpisodes: 2,
        hydrationMlPerDay: 1400,
        boneResorptionElevated: true,
        orthostaticIntolerance: true,
        graybielScore: 8,
      );

      expect(report.overallRiskLevel, CorrelationRiskLevel.high);
      expect(report.cardioVestibularFatigue.riskLevel, CorrelationRiskLevel.high);
      expect(report.renalStoneRisk.riskLevel, CorrelationRiskLevel.high);
      expect(report.activeCrossSubsystemAlerts, isNotEmpty);
    });

    test('assess_renal_stone_risk & correlate_subsystems emit alert_banner / status_report', () async {
      final crew = MockCrewData.getInitialCrew();
      final ctx = _makeContext(crew: crew, astronautId: 'AST-01');
      final skills = generalHealthSkills();

      final renalTool = _findTool(skills, 'assess_renal_stone_risk');
      final renalRes = await renalTool.call({
        'emesis_episodes': 2,
        'hydration_ml_per_day': 1150,
        'bone_resorption_elevated': true,
      }, ctx);

      expect(renalRes.ok, isTrue);
      expect(renalRes.data['risk_level'], 'high');
      expect(renalRes.data['recommend_renal_ultrasound'], isTrue);
      expect(renalRes.data['recommend_potassium_citrate'], isTrue);
      expect(
        (renalRes.uiEvents.single as ShowComponentEvent).id,
        ComponentIds.alertBanner,
      );

      final corrTool = _findTool(skills, 'correlate_subsystems');
      final corrRes = await corrTool.call({
        'emesis_episodes': 2,
        'hydration_ml_per_day': 1150,
        'bone_resorption_elevated': true,
      }, ctx);

      expect(corrRes.ok, isTrue);
      expect(corrRes.data['overall_risk_level'], 'high');
      final eventIds = corrRes.uiEvents
          .whereType<ShowComponentEvent>()
          .map((e) => e.id)
          .toList();
      expect(eventIds, contains(ComponentIds.statusReport));
      expect(eventIds, contains(ComponentIds.alertBanner));
    });
  });

  group('On-demand telemetry tools', () {
    test('get_radiation_dose, get_sleep_history, get_exercise_session, get_inventory emit telemetry_chart', () async {
      final crew = MockCrewData.getInitialCrew();
      final flags = _FakeFlagsStore({
        'AST-01': {
          'flagged_batches': {
            'batches': ['BATCH-OND-02'],
          },
        },
      });
      final ctx = _makeContext(crew: crew, astronautId: 'AST-01', flags: flags);
      final skills = generalHealthSkills();

      for (final toolName in [
        'get_radiation_dose',
        'get_sleep_history',
        'get_exercise_session',
        'get_inventory',
      ]) {
        final tool = _findTool(skills, toolName);
        final res = await tool.call({}, ctx);
        expect(res.ok, isTrue, reason: '$toolName should succeed');
        final event = res.uiEvents.single as ShowComponentEvent;
        expect(event.id, ComponentIds.telemetryChart, reason: toolName);
        final vm = TelemetryChartViewModel.fromProps(event.props);
        expect(vm.series, isNotEmpty, reason: '$toolName series should not be empty');
      }

      final invTool = _findTool(skills, 'get_inventory');
      final invRes = await invTool.call({'item': 'Ondansetron'}, ctx);
      expect(invRes.ok, isTrue);
      expect(invRes.data['flagged_count'], 1);
      final items = invRes.data['items'] as List;
      expect(items.length, 1);
      expect((items.first as Map)['flagged'], isTrue);
    });

    test('StatusReportOfflineFlow advances through subsystem correlation branch', () async {
      final crew = MockCrewData.getInitialCrew();
      final ctx = _makeContext(crew: crew, astronautId: 'AST-03');
      final flow =
          generalHealthSkills().firstWhere((s) => s.id == 'status_report').offlineFlow!;

      await flow.start(ctx);
      final corrStep = await flow.advance('Subsystem correlation', ctx);
      expect(
        corrStep.uiEvents.whereType<ShowComponentEvent>().first.id,
        ComponentIds.alertBanner,
      );
      expect(corrStep.isTerminal, isFalse);
    });
  });

  group('ViewModel validation', () {
    test('ViewModels round-trip and throw FormatException on invalid props', () {
      const alertVm = AlertBannerViewModel(
        title: 'Test Alert',
        severity: 'warning',
        classification: 'renal_stone_risk',
        message: 'Hydration low',
        suppressed: false,
        recommendedAction: 'Drink 2500 mL/day',
        astronautId: 'AST-01',
        details: ['Factor A'],
      );
      final alertRoundTrip = AlertBannerViewModel.fromProps(alertVm.toProps());
      expect(alertRoundTrip.severity, 'warning');
      expect(alertRoundTrip.details, ['Factor A']);

      expect(
        () => StatusReportViewModel.fromProps({'title': 'missing fields'}),
        throwsFormatException,
      );
      expect(
        () => AlertBannerViewModel.fromProps({'title': 'missing severity'}),
        throwsFormatException,
      );
      expect(
        () => VitalsCardViewModel.fromProps({'title': 'missing vitals'}),
        throwsFormatException,
      );
      expect(
        () => TelemetryChartViewModel.fromProps({'title': 'missing series'}),
        throwsFormatException,
      );
    });
  });
}
