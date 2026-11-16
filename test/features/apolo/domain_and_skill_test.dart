import 'package:astramed/features/agent/domain/agent_contracts.dart';
import 'package:astramed/features/apolo/agent/apolo_urine_skill.dart';
import 'package:astramed/features/apolo/data/apolo_repository.dart';
import 'package:astramed/features/apolo/domain/apolo_biomarker_engine.dart';
import 'package:astramed/features/apolo/domain/apolo_models.dart';
import 'package:astramed/features/apolo/providers/apolo_contract_providers.dart';
import 'package:astramed/features/apolo/providers/apolo_providers.dart';
import 'package:astramed/features/crew/presentation/providers/crew_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeUiSink implements AgentUiSink {
  final List<AgentComponentEvent> events = [];

  @override
  void emit(AgentComponentEvent event) => events.add(event);

  @override
  void submit(String componentId, Map<String, dynamic> result) {}
}

class _FakeConfirmationGate implements ConfirmationGate {
  @override
  ConsequentialAction? get pending => null;

  @override
  Future<ConfirmationDecision> request(
    ConsequentialAction action, {
    required Future<Map<String, dynamic>> Function() onConfirmed,
  }) async => ConfirmationDecision.confirmed;

  @override
  Future<Map<String, dynamic>?> resolve(
    String actionId,
    ConfirmationDecision decision, {
    String? reason,
  }) async => null;
}

class _FakeAuditLog implements AuditLog {
  @override
  Future<void> append(AuditEntry entry) async {}

  @override
  Future<List<AuditEntry>> list({String? astronautId, int limit = 50}) async =>
      const [];
}

class _FakeMemoryStore implements MemoryStore {
  @override
  Future<List<MemoryEntry>> recall(
    String astronautId, {
    String? query,
    Set<MemoryKind>? kinds,
    int limit = 10,
  }) async => const [];

  @override
  Future<List<MemoryEntry>> recentForPrompt(
    String astronautId, {
    int limit = 8,
  }) async => const [];

  @override
  Future<MemoryEntry> save(MemoryEntry entry) async => entry;
}

class _FakeFlagsStore implements AgentFlagsStore {
  @override
  Future<Map<String, Map<String, dynamic>>> allForAstronaut(
    String astronautId,
  ) async => const {};

  @override
  Future<Map<String, dynamic>?> getFlag(String astronautId, String key) async =>
      null;

  @override
  Future<void> setFlag(
    String astronautId,
    String key,
    Map<String, dynamic> value,
  ) async {}
}

class _FakeMedicationSafety implements MedicationSafety {
  @override
  Future<MedicationCheck> validate(MedicationRequest request) async =>
      const MedicationCheck(allowed: true, reasons: []);
}

ToolContext _makeToolContext(
  ProviderContainer container, {
  String astronautId = 'AST-01',
  DateTime? now,
}) {
  return ToolContext(
    astronautId: astronautId,
    read: <T>(provider) => container.read(provider as ProviderListenable<T>),
    ui: _FakeUiSink(),
    confirm: _FakeConfirmationGate(),
    audit: _FakeAuditLog(),
    memory: _FakeMemoryStore(),
    flags: _FakeFlagsStore(),
    medication: _FakeMedicationSafety(),
    now: now ?? DateTime.utc(2026, 11, 15, 10, 0),
  );
}

ApoloUrineSample _sampleWith(
  Map<String, double> values, {
  String id = 's-1',
  String astronautId = 'AST-01',
  int missionDay = 142,
  DateTime? takenAt,
}) {
  return ApoloUrineSample(
    id: id,
    astronautId: astronautId,
    missionDay: missionDay,
    takenAt: takenAt ?? DateTime.utc(2026, 11, 15, 7, 30),
    method: 'sensor',
    values: values,
  );
}

void main() {
  group('ApoloBiomarkerEngine', () {
    test(
      'defines full catalog with English names and derived/boolean flags',
      () {
        const expectedKeys = [
          'vol',
          'dens',
          'osm',
          'color',
          'ca',
          'ox',
          'cit',
          'ua',
          'ph',
          'ntx',
          'ctx',
          'ohdg',
          'iso',
          'leu',
          'nit',
          'bld',
          'cort',
          'mel',
          'na',
          'k',
          'nak',
          'acr',
          'glu',
          'ket',
          'prot',
          'urea',
          'crea',
        ];
        for (final key in expectedKeys) {
          expect(
            ApoloBiomarkerEngine.catalog.containsKey(key),
            isTrue,
            reason: 'Missing biomarker $key',
          );
        }
        expect(ApoloBiomarkerEngine.catalog['vol']!.name, '24h volume');
        expect(ApoloBiomarkerEngine.catalog['vol']!.unit, 'L');
        expect(ApoloBiomarkerEngine.catalog['nak']!.isDerived, isTrue);
        expect(ApoloBiomarkerEngine.catalog['nit']!.isBoolean, isTrue);
        expect(ApoloBiomarkerEngine.catalog['bld']!.isBoolean, isTrue);
        expect(ApoloBiomarkerEngine.catalog['glu']!.isBoolean, isTrue);
        expect(ApoloBiomarkerEngine.catalog['ket']!.isBoolean, isTrue);
      },
    );

    test('computes derived Na/K ratio and severity boundaries accurately', () {
      final sample = _sampleWith({
        'na': 150,
        'k': 50,
        'ca': 200, // ok (100..250)
        'ox': 41, // warn (>40, <= 40*1.35=54)
        'ohdg': 10.9, // crit (>8*1.35=10.8)
        'cit': 290, // crit (<450*0.65=292.5)
        'nit': 1, // boolean warn
        'bld': 0, // boolean ok
      });

      expect(ApoloBiomarkerEngine.valueOf([sample], 'nak'), 3.0);
      expect(ApoloBiomarkerEngine.severityOf([sample], 'ca'), ApoloSeverity.ok);
      expect(
        ApoloBiomarkerEngine.severityOf([sample], 'ox'),
        ApoloSeverity.warn,
      );
      expect(
        ApoloBiomarkerEngine.severityOf([sample], 'ohdg'),
        ApoloSeverity.crit,
      );
      expect(
        ApoloBiomarkerEngine.severityOf([sample], 'cit'),
        ApoloSeverity.crit,
      );
      expect(
        ApoloBiomarkerEngine.severityOf([sample], 'nit'),
        ApoloSeverity.warn,
      );
      expect(
        ApoloBiomarkerEngine.severityOf([sample], 'bld'),
        ApoloSeverity.ok,
      );

      final zeroKSample = _sampleWith({'na': 120, 'k': 0});
      expect(ApoloBiomarkerEngine.valueOf([zeroKSample], 'nak'), isNull);
    });

    test(
      'applies hydration water-goal and radiation solar-storm overrides',
      () {
        final sample = _sampleWith({
          'vol': 1.4,
          'dens': 1.028,
          'osm': 890,
          'color': 5,
          'ohdg': 5.0,
          'iso': 0.7,
        });

        final lowWaterMods = ApoloBiomarkerEngine.buildModules(
          samples: [sample],
          waterMlToday: 1700,
          waterGoalMl: 2500,
          doseMsv: 140,
          doseLimitMsv: 600,
          sleepHours: 7.2,
          solarStormActive: false,
          recommendations: const [],
        );
        expect(
          lowWaterMods[ApoloModuleId.hidratacion]!.severity,
          ApoloSeverity.warn,
        );
        expect(
          lowWaterMods[ApoloModuleId.radiacion]!.severity,
          ApoloSeverity.ok,
        );

        final goalReachedMods = ApoloBiomarkerEngine.buildModules(
          samples: [sample],
          waterMlToday: 2500,
          waterGoalMl: 2500,
          doseMsv: 140,
          doseLimitMsv: 600,
          sleepHours: 7.2,
          solarStormActive: true,
          recommendations: const [],
        );
        expect(
          goalReachedMods[ApoloModuleId.hidratacion]!.severity,
          ApoloSeverity.ok,
        );
        expect(
          goalReachedMods[ApoloModuleId.radiacion]!.severity,
          ApoloSeverity.crit,
        );
      },
    );

    test('computes sampleSchedule due state and countdown correctly', () {
      final nowMorningDue = DateTime.utc(2026, 11, 15, 10, 0);
      final oldSample = _sampleWith(const {
        'vol': 2.0,
      }, takenAt: DateTime.utc(2026, 11, 14, 7, 30));
      final dueState = ApoloBiomarkerEngine.sampleSchedule(
        nowMorningDue,
        samples: [oldSample],
      );
      expect(dueState.isDue, isTrue);
      expect(dueState.shortLabel, 'Now');

      final freshSample = _sampleWith(const {
        'vol': 2.0,
      }, takenAt: DateTime.utc(2026, 11, 15, 8, 0));
      final okState = ApoloBiomarkerEngine.sampleSchedule(
        nowMorningDue,
        samples: [freshSample],
        lastSubmittedAt: DateTime.utc(2026, 11, 15, 8, 0),
      );
      expect(okState.isDue, isFalse);
      expect(okState.nextSlot, DateTime.utc(2026, 11, 15, 15, 30));
    });

    test('computes module calculators renalRisk, boneResorptionPct, infection, sleepQuality, and stressLevel', () {
      final baseline = List.generate(
        10,
        (i) => _sampleWith({
          'ntx': 40,
          'ca': 180,
          'ox': 25,
          'cit': 700,
          'ph': 6.3,
          'vol': 2.0,
          'cort': 45,
          'mel': 20,
          'leu': 2,
          'nit': 0,
          'bld': 0,
        }, id: 'b-$i'),
      );
      final latest = _sampleWith({
        'ntx': 60, // +50% vs baseline 40
        'ca': 290, // warn
        'ox': 42, // warn
        'cit': 380, // warn
        'ph': 6.2, // ok
        'vol': 1.4, // warn -> 4 factors out -> Moderate
        'cort': 92, // warn -> high stress
        'mel': 7, // warn
        'leu': 6, // warn
        'nit': 1, // warn
        'bld': 0,
      }, id: 'latest');
      final all = [...baseline, latest];

      final renal = ApoloBiomarkerEngine.renalRisk(all);
      expect(renal.outOfRangeCount, 4);
      expect(renal.label, 'Moderate');

      expect(ApoloBiomarkerEngine.boneResorptionPct(all), 50);
      expect(ApoloBiomarkerEngine.hasInfectionSigns(all), isTrue);
      expect(ApoloBiomarkerEngine.sleepQuality(5.1, all).word, 'poor');
      expect(ApoloBiomarkerEngine.stressLevel(all), 'high');
    });
  });

  group('ApoloRepository and ApoloStateNotifier', () {
    test(
      'maps 5 crew IDs and aliases with deterministic 40-sample history',
      () {
        final repo = ApoloRepository(
          clock: () => DateTime.utc(2026, 11, 15, 10, 0),
        );
        final states = repo.buildInitialStates();

        expect(
          states.keys,
          containsAll(['AST-01', 'AST-02', 'AST-03', 'AST-04', 'AST-05']),
        );
        for (final id in ['AST-01', 'AST-02', 'AST-03', 'AST-04', 'AST-05']) {
          expect(states[id]!.samples.length, 40);
        }

        // AST-01 (ana): hydration + renal warn
        expect(states['AST-01']!.apoloCrewKey, 'ana');
        expect(
          states['AST-01']!.visibleOrbs,
          containsAll([ApoloModuleId.renal, ApoloModuleId.hidratacion]),
        );
        expect(states['AST-01']!.overallSeverity, ApoloSeverity.warn);

        // AST-02 (sami): stress/sleep warn
        expect(states['AST-02']!.apoloCrewKey, 'sami');
        expect(states['AST-02']!.visibleOrbs, [ApoloModuleId.estres]);

        // AST-03 (mateo): radiation crit
        expect(states['AST-03']!.apoloCrewKey, 'mateo');
        expect(states['AST-03']!.samples.last.values['ohdg'], 11.2);
        expect(states['AST-03']!.samples.last.values['iso'], 1.6);
        expect(states['AST-03']!.visibleOrbs, [ApoloModuleId.radiacion]);
        expect(states['AST-03']!.overallSeverity, ApoloSeverity.crit);

        // AST-04 (yuki): immunity warn
        expect(states['AST-04']!.apoloCrewKey, 'yuki');
        expect(states['AST-04']!.samples.last.values['leu'], 6.0);
        expect(states['AST-04']!.samples.last.values['nit'], 1.0);
        expect(states['AST-04']!.visibleOrbs, [ApoloModuleId.inmunidad]);

        // AST-05 (leo): bone warn
        expect(states['AST-05']!.apoloCrewKey, 'leo');
        expect(states['AST-05']!.samples.last.values['ntx'], 64.0);
        expect(states['AST-05']!.samples.last.values['ctx'], 530.0);
        expect(states['AST-05']!.visibleOrbs, [ApoloModuleId.osea]);

        // Aliases and unknown custom crew ID
        final notifier = ApoloStateNotifier(repository: repo);
        expect(notifier.stateFor('ana').astronautId, 'AST-01');
        expect(notifier.stateFor('sami').astronautId, 'AST-02');
        expect(notifier.stateFor('mateo').astronautId, 'AST-03');
        expect(notifier.stateFor('yuki').astronautId, 'AST-04');
        expect(notifier.stateFor('leo').astronautId, 'AST-05');

        final custom = notifier.stateFor('AST-CUSTOM-99');
        expect(custom.astronautId, 'AST-CUSTOM-99');
        expect(custom.overallSeverity, ApoloSeverity.ok);
      },
    );

    test('supports addWater, addExercise, toggleRecommendation, submitSample, and orb/ui actions', () {
      final now = DateTime.utc(2026, 11, 15, 10, 0);
      final notifier = ApoloStateNotifier(
        repository: ApoloRepository(clock: () => now),
        clock: () => now,
      );

      // Invalid water bounds
      expect(notifier.addWater(49), isFalse);
      expect(notifier.addWater(2001), isFalse);

      // Valid water flips hidratacion to ok when goal (2500 ml) is reached
      expect(notifier.addWater(800), isTrue);
      final afterWater = notifier.stateFor('AST-01');
      expect(afterWater.waterMlToday, 2500);
      expect(afterWater.visibleOrbs, contains(ApoloModuleId.hidratacion));
      expect(
        afterWater.modules[ApoloModuleId.hidratacion]!.severity,
        ApoloSeverity.ok,
      );

      // Exercise bounds and increment
      expect(notifier.addExercise(0), isFalse);
      expect(notifier.addExercise(301), isFalse);
      expect(notifier.addExercise(30), isTrue);
      final afterEx = notifier.stateFor('AST-01');
      expect(afterEx.exerciseMinToday, 75);
      expect(afterEx.resistanceSessionsWeek, 4);
      expect(afterEx.visibleOrbs, contains(ApoloModuleId.osea));

      // Toggle recommendation
      notifier.toggleRecommendation('ana1', true);
      final rec = notifier
          .stateFor('AST-01')
          .modules[ApoloModuleId.hidratacion]!
          .recommendations
          .firstWhere((r) => r.id == 'ana1');
      expect(rec.done, isTrue);

      // Submit sample clears due state
      expect(notifier.stateFor('AST-01').sampleSchedule.isDue, isTrue);
      final sample = notifier.submitSample(method: 'sensor');
      expect(sample.astronautId, 'AST-01');
      expect(notifier.stateFor('AST-01').samples.length, 41);
      expect(notifier.stateFor('AST-01').sampleSchedule.isDue, isFalse);

      // Show all / hide / reset / flags
      notifier.showAllOrbs();
      expect(notifier.stateFor('AST-01').visibleOrbs.length, 8);
      notifier.hideOrb(ApoloModuleId.metabolismo);
      expect(
        notifier.stateFor('AST-01').visibleOrbs,
        isNot(contains(ApoloModuleId.metabolismo)),
      );
      notifier.resetOrbsToUrgent();
      expect(
        notifier
            .stateFor('AST-01')
            .visibleOrbs
            .every(
              (id) =>
                  notifier.stateFor('AST-01').modules[id]!.severity !=
                  ApoloSeverity.ok,
            ),
        isTrue,
      );

      notifier.setHighContrast(true);
      notifier.setAutoTips(true);
      notifier.setSolarStorm(true);
      final flagged = notifier.stateFor('AST-01');
      expect(flagged.highContrast, isTrue);
      expect(flagged.autoTips, isTrue);
      expect(flagged.solarStormActive, isTrue);
      expect(
        flagged.modules[ApoloModuleId.radiacion]!.severity,
        ApoloSeverity.crit,
      );
    });
  });

  group('ApoloUrineSkill and apoloProviders', () {
    test('executes all 7 tools against apoloActionsProvider', () async {
      final container = ProviderContainer(overrides: apoloProviderOverrides);
      addTearDown(container.dispose);

      final skill = ApoloUrineSkill();
      expect(skill.id, 'apolo_urine_health');
      expect(skill.tools.length, 7);

      final ctx = _makeToolContext(container, astronautId: 'AST-01');
      final toolsByName = {for (final t in skill.tools) t.name: t};

      final modsRes = await toolsByName['get_apolo_modules']!.call(
        const {},
        ctx,
      );
      expect(modsRes.ok, isTrue);
      expect((modsRes.data['modules'] as List).length, 8);
      expect(modsRes.data['overall_severity'], 'warn');

      final detailRes = await toolsByName['get_apolo_biomarker_detail']!.call({
        'module_id': 'osea',
      }, ctx);
      expect(detailRes.ok, isTrue);
      expect(
        container.read(apoloActiveStateProvider).visibleOrbs,
        contains(ApoloModuleId.osea),
      );

      final waterRes = await toolsByName['log_water_intake']!.call({
        'ml': 500,
      }, ctx);
      expect(waterRes.ok, isTrue);
      expect(waterRes.data['water_ml_today'], 2200);
      expect(waterRes.data['remaining_ml'], 300);

      final badWaterRes = await toolsByName['log_water_intake']!.call({
        'ml': 10,
      }, ctx);
      expect(badWaterRes.ok, isFalse);

      final exRes = await toolsByName['log_exercise_minutes']!.call({
        'minutes': 25,
      }, ctx);
      expect(exRes.ok, isTrue);
      expect(exRes.data['exercise_min_today'], 70);

      final recRes = await toolsByName['complete_recommendation']!.call({
        'recommendation_id': 'ana1',
      }, ctx);
      expect(recRes.ok, isTrue);

      final orbsRes = await toolsByName['show_apolo_orbs']!.call({
        'all': true,
      }, ctx);
      expect(orbsRes.ok, isTrue);
      expect(container.read(apoloActiveStateProvider).visibleOrbs.length, 8);

      final sampleRes = await toolsByName['submit_urine_sample']!.call({
        'method': 'sensor',
      }, ctx);
      expect(sampleRes.ok, isTrue);
      expect(
        container.read(apoloActiveStateProvider).sampleSchedule.isDue,
        isFalse,
      );
    });

    test(
      'syncs apoloActiveStateProvider when selectedAstronautIdProvider changes',
      () {
        final container = ProviderContainer(overrides: apoloProviderOverrides);
        addTearDown(container.dispose);

        expect(container.read(apoloActiveStateProvider).astronautId, 'AST-01');
        container.read(selectedAstronautIdProvider.notifier).state = 'AST-03';
        expect(container.read(apoloActiveStateProvider).astronautId, 'AST-03');
        expect(
          container.read(apoloActiveStateProvider).overallSeverity,
          ApoloSeverity.crit,
        );
      },
    );

    test(
      'offline deterministic flow handles English and Spanish ask() rules',
      () async {
        final container = ProviderContainer(overrides: apoloProviderOverrides);
        addTearDown(container.dispose);

        final flow = ApoloUrineSkill().offlineFlow!;
        final ctx = _makeToolContext(container, astronautId: 'AST-01');

        final startStep = await flow.start(ctx);
        expect(startStep.prompt, isNotEmpty);

        final enWater = await flow.advance('I drank 500 ml', ctx);
        expect(enWater.prompt.toLowerCase(), contains('500'));
        expect(container.read(apoloActiveStateProvider).waterMlToday, 2200);

        final esWater = await flow.advance('tomé 300 ml', ctx);
        expect(esWater.prompt.toLowerCase(), contains('300'));
        expect(container.read(apoloActiveStateProvider).waterMlToday, 2500);

        final exStep = await flow.advance('30 min exercise', ctx);
        expect(exStep.prompt.toLowerCase(), contains('30'));
        expect(container.read(apoloActiveStateProvider).exerciseMinToday, 75);

        final showAllStep = await flow.advance('show all', ctx);
        expect(showAllStep.prompt, isNotEmpty);
        expect(container.read(apoloActiveStateProvider).visibleOrbs.length, 8);

        final urgentStep = await flow.advance('urgent only', ctx);
        expect(urgentStep.prompt, isNotEmpty);
        expect(
          container.read(apoloActiveStateProvider).visibleOrbs.length,
          lessThan(8),
        );

        final modStep = await flow.advance('how are my kidneys?', ctx);
        expect(modStep.prompt.toLowerCase(), contains('renal'));
        expect(
          container.read(apoloActiveStateProvider).visibleOrbs,
          contains(ApoloModuleId.renal),
        );

        final sampleStep = await flow.advance('when is my next sample?', ctx);
        expect(sampleStep.prompt.toLowerCase(), contains('sample'));

        final summaryStep = await flow.advance('how am i', ctx);
        expect(summaryStep.prompt, isNotEmpty);
      },
    );

    test(
      'offline flow acts on the very first message (startWithQuery)',
      () async {
        final container = ProviderContainer(overrides: apoloProviderOverrides);
        addTearDown(container.dispose);

        final raw = ApoloUrineSkill().offlineFlow!;
        expect(raw, isA<QueryAwareDeterministicFlow>());
        final flow = raw as QueryAwareDeterministicFlow;
        final ctx = _makeToolContext(container, astronautId: 'AST-01');
        final before = container.read(apoloActiveStateProvider).waterMlToday;

        final step = await flow.startWithQuery('I drank 500 ml', ctx);
        expect(step.prompt.toLowerCase(), contains('500'));
        expect(
          container.read(apoloActiveStateProvider).waterMlToday,
          before + 500,
        );

        // Anything it does not recognise still greets the astronaut.
        final hello = await flow.startWithQuery('hola', ctx);
        expect(hello.prompt, isNotEmpty);
      },
    );
  });
}
