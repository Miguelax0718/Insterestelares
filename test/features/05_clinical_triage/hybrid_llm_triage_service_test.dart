import 'dart:convert';

import 'package:astramed/features/01_general_health/models/vitals_record.dart';
import 'package:astramed/features/02_radiation/models/radiation_dose.dart';
import 'package:astramed/features/03_microgravity/models/microgravity_data.dart';
import 'package:astramed/features/04_mental_health/models/sleep_record.dart';
import 'package:astramed/features/05_clinical_triage/domain/apollo_triage_engine.dart';
import 'package:astramed/features/05_clinical_triage/domain/hybrid_llm_triage_service.dart';
import 'package:astramed/features/05_clinical_triage/models/triage_decision.dart';
import 'package:astramed/features/agent/application/context_builder.dart';
import 'package:astramed/features/agent/domain/agent_contracts.dart';
import 'package:astramed/features/agent/providers/agent_providers.dart';
import 'package:astramed/features/crew/models/astronaut_profile.dart';
import 'package:astramed/features/crew/presentation/providers/crew_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class _RecordingUiSink implements AgentUiSink {
  final List<AgentComponentEvent> events = [];

  @override
  void emit(AgentComponentEvent event) => events.add(event);

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
  ) async =>
      Map<String, Map<String, dynamic>>.from(_store[astronautId] ?? {});

  @override
  Future<Map<String, dynamic>?> getFlag(String astronautId, String key) async =>
      _store[astronautId]?[key];

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
  Future<MedicationCheck> validate(MedicationRequest request) async =>
      const MedicationCheck(allowed: true, reasons: []);
}

class _TestCrewNotifier extends CrewNotifier {
  _TestCrewNotifier(List<AstronautProfile> initial) {
    state = initial;
  }
}

AstronautProfile _makeProfile({
  String id = 'AST-01',
  double sleepHours = 7.5,
  VitalsRecord? vitals,
}) {
  final now = DateTime.utc(2026, 11, 15, 12, 0);
  return AstronautProfile(
    id: id,
    name: 'Cmdr. Elena Vance',
    role: 'Commander',
    rank: 'Col.',
    callsign: 'Vance',
    avatarInitials: 'EV',
    age: 39,
    bloodType: 'O+',
    currentZone: 'Destiny Lab',
    vitals: vitals ??
        VitalsRecord(
          timestamp: now,
          astronautId: id,
          heartRate: 70.0,
          systolicBP: 118.0,
          diastolicBP: 76.0,
          spO2: 98.0,
          bodyTemp: 36.6,
          bloodGlucose: 92.0,
        ),
    radiation: RadiationDose(
      timestamp: now,
      astronautId: id,
      doseRateMicroSvPerHour: 40.0,
      cumulativeDoseMilliSv: 28.5,
      severity: RadiationSeverity.normal,
    ),
    sleep: SleepRecord(
      date: now,
      astronautId: id,
      sleepHours: sleepHours,
      wakeEpisodes: 1,
      morningMood: MoodLevel.good,
    ),
    exercise: ExerciseSession(
      date: now,
      astronautId: id,
      deviceName: 'ARED',
      durationMinutes: 45,
      caloriesBurned: 320.0,
      targetReached: true,
    ),
    riskLevel: CrewRiskLevel.nominal,
    riskTitle: 'Nominal',
    riskDescription: 'All passive dimensions stable.',
    activeAlerts: const [],
  );
}

void main() {
  const apollo = ApolloTriageEngine();

  group('ApolloTriageEngine 7 ADA+APOLO rules', () {
    test('triggers rules 1 through 7 deterministically with telemetry correlation', () {
      final nominal = _makeProfile().vitals;

      // Rule 1: CO2 / Hypoxia Red
      final r1 = apollo.processQuery(
        query: 'Siento ahogo y cefalea',
        vitals: nominal.copyWith(localCo2MmHg: 5.4, spO2: 90.5),
      );
      expect(r1.triggeredRule, 'rule_1_co2_hypoxia_cardiorespiratory');
      expect(r1.priority, TriagePriority.red);

      // Rule 2: SANS / NPi / ToF
      final r2 = apollo.processQuery(
        query: 'Veo borroso de cerca',
        vitals: nominal.copyWith(
          passiveNearFocusCm: 40.0,
          estimatedHyperopicShiftDiopters: 0.75,
        ),
      );
      expect(r2.triggeredRule, 'rule_2_sans_pupillometry_tof');
      expect(r2.priority, TriagePriority.yellow);

      // Rule 3: IMU Impact Trauma Red
      final r3 = apollo.processQuery(
        query: 'Golpe contra mamparo',
        vitals: nominal.copyWith(peakImpactG: 3.8),
      );
      expect(r3.triggeredRule, 'rule_3_imu_impact_trauma');
      expect(r3.priority, TriagePriority.red);

      // Rule 4: BIS Hydration / Renal
      final r4 = apollo.processQuery(
        query: 'Tengo dolor en flanco renal',
        vitals: nominal.copyWith(hydrationBioimpedanceIndex: 72.0),
      );
      expect(r4.triggeredRule, 'rule_4_bis_hydration_renal');
      expect(r4.priority, TriagePriority.yellow);

      // Rule 5: PVT-B Fatigue / Sleep / Nocturnal HRV
      final r5 = apollo.processQuery(
        query: 'Mucha fatiga cognitiva',
        vitals: nominal.copyWith(passivePvtReactionMs: 380.0, passivePvtLapsesCount: 4),
        sleepHours: 5.8,
      );
      expect(r5.triggeredRule, 'rule_5_cognitive_pvt_circadian_hrv');
      expect(r5.priority, TriagePriority.yellow);

      // Rule 6: Muscle Atrophy / Heat-Flux Fever
      final r6 = apollo.processQuery(
        query: 'Tengo fiebre y dolor muscular en cuadriceps',
        vitals: nominal.copyWith(coreTempHeatFluxC: 39.0),
      );
      expect(r6.triggeredRule, 'rule_6_muscle_bis_heatflux_thermal');
      expect(r6.priority, TriagePriority.red);

      // Rule 7: Nominal 4-dimension scan
      final r7 = apollo.processQuery(
        query: 'Estado general actual',
        vitals: nominal,
        sleepHours: 7.5,
      );
      expect(r7.triggeredRule, 'rule_7_general_multidimension_scan');
      expect(r7.priority, TriagePriority.green);
    });
  });

  group('HybridLlmTriageService offline guardrail & fallback', () {
    test('runs offline deterministic without HTTP calls', () async {
      var httpCalled = false;
      final client = MockClient((_) async {
        httpCalled = true;
        return http.Response('{}', 200);
      });
      final service = HybridLlmTriageService(httpClient: client);
      final res = await service.evaluate(
        query: 'chequeo general',
        vitals: _makeProfile().vitals,
        config: const HybridAiConfig(backend: AiInferenceBackend.offlineDeterministic),
      );

      expect(httpCalled, isFalse);
      expect(res.effectiveBackend, AiInferenceBackend.offlineDeterministic);
      expect(res.usedOfflineFallback, isFalse);
      expect(res.message.priority, TriagePriority.green);
    });

    test('preserves ADA+APOLO Red priority when local SLM succeeds and falls back on HTTP failure', () async {
      final redVitals = _makeProfile().vitals.copyWith(spO2: 89.0, localCo2MmHg: 5.5);

      final okClient = MockClient(
        (_) async => http.Response(
          jsonEncode({'response': 'Move immediately to a ventilated module.'}),
          200,
        ),
      );
      final okService = HybridLlmTriageService(httpClient: okClient);
      final okRes = await okService.evaluate(
        query: 'Siento ahogo',
        vitals: redVitals,
        config: const HybridAiConfig(
          backend: AiInferenceBackend.localSlm,
          endpointUrl: 'http://127.0.0.1:11434/api/generate',
        ),
      );
      expect(okRes.effectiveBackend, AiInferenceBackend.localSlm);
      expect(okRes.usedOfflineFallback, isFalse);
      expect(okRes.message.priority, TriagePriority.red);
      expect(okRes.message.text, contains('ADA+APOLO'));

      final failClient = MockClient(
        (_) async => http.Response('Service unavailable', 503),
      );
      final failService = HybridLlmTriageService(httpClient: failClient);
      final fallbackRes = await failService.evaluate(
        query: 'Siento ahogo',
        vitals: redVitals,
        config: const HybridAiConfig(
          backend: AiInferenceBackend.cloudLlm,
          endpointUrl: 'https://invalid.local/triage',
        ),
      );
      expect(fallbackRes.effectiveBackend, AiInferenceBackend.offlineDeterministic);
      expect(fallbackRes.usedOfflineFallback, isTrue);
      expect(fallbackRes.message.priority, TriagePriority.red);
    });
  });

  group('AgentContextBuilder passive_dimensions & Apolo Skill integration', () {
    test('includes all 4 passive dimensions in AgentContextBuilder within budget', () async {
      final profile = _makeProfile();
      const builder = AgentContextBuilder();
      final context = await builder.build(
        astronaut: profile,
        memory: _FakeMemoryStore(),
        flags: _FakeFlagsStore(),
        activeComponentIds: const [ComponentIds.vitalsCard],
        missionDay: 18,
      );

      final live = context['live'] as Map<String, dynamic>;
      final passive = live['passive_dimensions'] as Map<String, dynamic>;
      expect(passive.containsKey('cardiorespiratory_metabolic'), isTrue);
      expect(passive.containsKey('neurological_sensory'), isTrue);
      expect(passive.containsKey('musculoskeletal'), isTrue);
      expect(passive.containsKey('circadian_psychoemotional'), isTrue);
      expect(
        utf8.encode(jsonEncode(context)).length,
        lessThanOrEqualTo(AgentContextBuilder.maxBytes),
      );
    });

    test('executes all 4 Apolo tools and ScientificTelemetryOfflineFlow from skillRegistryProvider', () async {
      final profile = _makeProfile(
        vitals: _makeProfile().vitals.copyWith(
              passiveNearFocusCm: 39.0,
              estimatedHyperopicShiftDiopters: 0.75,
            ),
      );
      final mockClient = MockClient(
        (_) async => http.Response(
          jsonEncode({'response': 'Optical SANS screening recommended.'}),
          200,
        ),
      );
      final container = ProviderContainer(
        overrides: [
          crewMembersProvider.overrideWith((ref) => _TestCrewNotifier([profile])),
          httpClientProvider.overrideWithValue(mockClient),
        ],
      );
      addTearDown(container.dispose);

      final registry = container.read(skillRegistryProvider);
      final skill = registry.skills.firstWhere(
        (s) => s.id == 'scientific_telemetry_criteria',
      );
      expect(skill.tools.length, 4);
      expect(skill.offlineFlow, isNotNull);

      final ui = _RecordingUiSink();
      final ctx = ToolContext(
        astronautId: profile.id,
        read: <T>(Object provider) => container.read(provider as ProviderListenable<T>),
        ui: ui,
        confirm: _FakeConfirmationGate(),
        audit: _FakeAuditLog(),
        memory: _FakeMemoryStore(),
        flags: _FakeFlagsStore(),
        medication: _FakeMedicationSafety(),
      );

      final t1 = skill.tools.firstWhere((t) => t.name == 'evaluate_scientific_vitals_criteria');
      final r1 = await t1.call({'astronaut_id': 'AST-01'}, ctx);
      expect(r1.ok, isTrue);
      expect(
        r1.uiEvents.any((e) => e is ShowComponentEvent && e.id == ComponentIds.vitalsCard),
        isTrue,
      );

      final t2 = skill.tools.firstWhere((t) => t.name == 'evaluate_passive_dimensions_telemetry');
      final r2 = await t2.call({'astronaut_id': 'AST-01'}, ctx);
      expect(r2.ok, isTrue);
      expect(r2.data['passive_evaluation'], isNotNull);
      expect(
        r2.uiEvents.any((e) => e is ShowComponentEvent && e.id == ComponentIds.alertBanner),
        isTrue,
      );

      final t3 = skill.tools.firstWhere((t) => t.name == 'run_ada_apollo_triage');
      final r3 = await t3.call({'clinical_query': 'vista borrosa de cerca'}, ctx);
      expect(r3.ok, isTrue);
      expect(r3.data['triggered_rule'], 'rule_2_sans_pupillometry_tof');

      final t4 = skill.tools.firstWhere((t) => t.name == 'run_hybrid_ada_apollo_consultation');
      final r4 = await t4.call({
        'clinical_query': 'vista borrosa',
        'backend_override': 'local_slm',
        'endpoint_url': 'http://127.0.0.1:11434/api/generate',
      }, ctx);
      expect(r4.ok, isTrue);
      expect(r4.data['effective_backend'], 'localSlm');

      final flow = skill.offlineFlow!;
      final step1 = await flow.start(ctx);
      expect(step1.isTerminal, isFalse);
      final step2 = await flow.advance('Triage SANS / Pupila / Enfoque ToF', ctx);
      expect(step2.isTerminal, isTrue);
      expect(step2.verdict?['triggered_rule'], 'rule_2_sans_pupillometry_tof');
    });
  });
}
