import 'package:astramed/features/apolo/data/apolo_repository.dart';
import 'package:astramed/features/apolo/domain/apolo_models.dart';
import 'package:astramed/features/apolo/providers/apolo_providers.dart';
import 'package:astramed/features/crew/data/mock_crew_data.dart';
import 'package:astramed/features/crew/models/astronaut_profile.dart';
import 'package:astramed/features/crew/presentation/providers/crew_provider.dart';
import 'package:astramed/features/simulation/presentation/providers/mission_simulator_provider.dart';
import 'package:astramed/features/simulation/presentation/mission_simulator_card.dart';
import 'package:astramed/features/simulation/agent/mission_simulator_skill.dart';
import 'package:astramed/features/agent/domain/agent_contracts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _UnusedServices implements ConfirmationGate, AuditLog, MemoryStore, AgentFlagsStore, MedicationSafety {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Ui implements AgentUiSink {
  final events = <AgentComponentEvent>[];
  @override
  void emit(AgentComponentEvent event) => events.add(event);
  @override
  void submit(String componentId, Map<String, dynamic> result) {}
}

ToolContext _contextFor(ProviderContainer c, _Ui ui) {
  final unused = _UnusedServices();
  return ToolContext(astronautId: 'AST-01',
    read: <T>(p) => c.read(p as ProviderListenable<T>),
    ui: ui, confirm: unused, audit: unused, memory: unused, flags: unused, medication: unused);
}

void main() {
  ProviderContainer create() {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    c.read(missionSimulatorProvider.notifier).initializeNominal();
    return c;
  }

  test('nominal factories preserve historical scenarios', () {
    expect(MockCrewData.getInitialCrew().any((p) => p.riskLevel != CrewRiskLevel.nominal), isTrue);
    expect(ApoloRepository().buildInitialStates()['AST-01']!.missionDay, 142);
    final c = create();
    expect(c.read(crewMembersProvider), hasLength(5));
    expect(c.read(crewMembersProvider).every((p) => p.riskLevel == CrewRiskLevel.nominal && p.activeAlerts.isEmpty), isTrue);
    for (final s in c.read(apoloStateNotifierProvider).values) {
      expect(s.overallSeverity, ApoloSeverity.ok);
      expect(s.visibleOrbs, isEmpty);
      expect(s.samples, hasLength(1));
      expect(s.samples.single.missionDay, 1);
      expect(s.waterMlToday, s.waterGoalMl);
    }
  });

  test('batch progress equals individual days; routine days stay bounded without events', () {
    final a = create();
    final b = create();
    a.read(missionSimulatorProvider.notifier).advanceDays(5);
    for (var i = 0; i < 5; i++) {
      b.read(missionSimulatorProvider.notifier).advanceDays();
    }
    expect(a.read(missionSimulatorProvider).missionDay, 6);
    expect(a.read(crewMembersProvider).first.vitals.heartRate, b.read(crewMembersProvider).first.vitals.heartRate);
    expect(a.read(apoloStateNotifierProvider)['AST-01']!.samples.last.values, b.read(apoloStateNotifierProvider)['AST-01']!.samples.last.values);
    expect(a.read(crewMembersProvider).any((p) => p.riskLevel == CrewRiskLevel.warning), isTrue);
    // Without events nobody becomes critical: serious cases come from events.
    a.read(missionSimulatorProvider.notifier).advanceDays(30);
    expect(a.read(crewMembersProvider).any((p) => p.riskLevel == CrewRiskLevel.critical), isFalse);
  });

  test('mission environments produce different deterministic drift', () {
    final a = create();
    final b = create();
    a.read(missionSimulatorProvider.notifier).setMissionType(MissionType.orbital);
    b.read(missionSimulatorProvider.notifier).setMissionType(MissionType.transit);
    a.read(missionSimulatorProvider.notifier).advanceDays();
    b.read(missionSimulatorProvider.notifier).advanceDays();
    expect(a.read(crewMembersProvider).every((p) => p.riskLevel == CrewRiskLevel.nominal), isTrue);
    expect(b.read(crewMembersProvider).first.radiation.cumulativeDoseMilliSv,
      greaterThan(a.read(crewMembersProvider).first.radiation.cumulativeDoseMilliSv));
  });

  test('tools strictly reject invalid inputs without state or UI mutation', () async {
    final c = create();
    final ui = _Ui();
    final ctx = _contextFor(c, ui);
    final skill = MissionSimulatorSkill();
    expect(skill.alwaysOn, isTrue);
    final control = skill.tools.singleWhere((t) => t.name == 'control_mission_simulation');
    final event = skill.tools.singleWhere((t) => t.name == 'trigger_simulation_event');
    final before = c.read(missionSimulatorProvider);
    final crew = c.read(crewMembersProvider);
    final apolo = c.read(apoloStateNotifierProvider);
    for (final args in [
      <String, dynamic>{},
      {'action': 'bad'},
      {'action': 'advance_day', 'days': 0},
      {'action': 'advance_day', 'days': 366},
      {'action': 'advance_day', 'days': 1.5},
      {'action': 'advance_day', 'days': '5'},
      {'action': 'start', 'days': 2},
      {'action': 'set_mission_type', 'mission_type': 'mars'},
      {'action': 'start', 'mission_type': 'lunar'},
    ]) {
      expect((await control.call(args, ctx)).ok, isFalse);
    }
    for (final args in [
      {'event': 'unknown'}, {'event': 'sleep_loss', 'astronaut_id': 'bad'},
      {'event': 'workload', 'astronaut_id': 5}, {'event': 'workload', 'astronaut_id': null},
    ]) {
      expect((await event.call(args, ctx)).ok, isFalse);
    }
    expect(identical(c.read(missionSimulatorProvider), before), isTrue);
    expect(identical(c.read(crewMembersProvider), crew), isTrue);
    expect(identical(c.read(apoloStateNotifierProvider), apolo), isTrue);
    expect(ui.events, isEmpty);
    final status = await skill.tools.first.call({}, ctx);
    expect(status.ok, isTrue);
    expect((ui.events.single as ShowComponentEvent).id, 'mission_simulator');
    expect(status.data['nominal'], 5);
    expect((await control.call({'action': 'advance_day', 'days': 5}, ctx)).data['mission_day'], 6);
    expect((await control.call({'action': 'set_mission_type', 'mission_type': 'surface'}, ctx)).data['mission_type'], 'surface');
    expect((await control.call({'action': 'start'}, ctx)).data['is_running'], isTrue);
    expect((await control.call({'action': 'pause'}, ctx)).data['is_running'], isFalse);
    expect((await event.call({'event': 'solar_particle_event', 'astronaut_id': 'AST-02'}, ctx)).ok, isTrue);
    expect((await control.call({'action': 'reset_nominal'}, ctx)).data['nominal'], 5);
  });

  test('offline flow responds to Spanish and English commands immediately', () async {
    final c = create();
    final ui = _Ui();
    final ctx = _contextFor(c, ui);
    final flow = MissionSimulatorOfflineFlow();
    expect((await flow.startWithQuery('avanza 5 días', ctx)).verdict!['mission_day'], 6);
    expect((await flow.startWithQuery('pause simulation', ctx)).verdict!['is_running'], isFalse);
    await flow.startWithQuery('evento de partículas solares', ctx);
    expect(c.read(apoloStateNotifierProvider)['AST-01']!.solarStormActive, isTrue);
    await flow.startWithQuery('reset nominal simulation', ctx);
    await flow.startWithQuery('sleep loss', ctx);
    // Individual response: ~3 h lost around the original 4.5 h reference.
    expect(c.read(crewMembersProvider).first.sleep.sleepHours, inInclusiveRange(3.9, 4.9));
    expect((await flow.startWithQuery('show simulator', ctx)).uiEvents, hasLength(1));
  });

  for (final event in SimulationEvent.values) {
    test('${event.name} targets selected astronaut and reset clears event', () {
      final c = create();
      c.read(selectedAstronautIdProvider.notifier).state = 'AST-03';
      c.read(missionSimulatorProvider.notifier).triggerEvent(event);
      expect(c.read(crewMembersProvider)[2].riskLevel, isNot(CrewRiskLevel.nominal));
      final s = c.read(apoloStateNotifierProvider)['AST-03']!;
      if (event == SimulationEvent.solarParticleEvent) {
        // A solar particle event is environmental: it reaches the whole crew,
        // with a dose that depends on each module's shielding.
        expect(c.read(crewMembersProvider).every((p) => p.riskLevel != CrewRiskLevel.nominal), isTrue);
        expect(s.solarStormActive, isTrue);
        expect(s.modules[ApoloModuleId.radiacion]!.severity, ApoloSeverity.crit);
      } else {
        expect(c.read(crewMembersProvider).first.riskLevel, CrewRiskLevel.nominal);
      }
      c.read(missionSimulatorProvider.notifier).resetNominal();
      expect(c.read(missionSimulatorProvider).missionDay, 1);
      expect(c.read(missionSimulatorProvider).isRunning, isFalse);
      expect(c.read(apoloStateNotifierProvider).values.every((s) => !s.solarStormActive && s.visibleOrbs.isEmpty), isTrue);
    });
  }

  testWidgets('timer has one ticker and pause/dispose cancel it', (tester) async {
    final c = ProviderContainer();
    final n = c.read(missionSimulatorProvider.notifier);
    n.initializeNominal();
    n.setRunning(true);
    n.setRunning(true);
    await tester.pump(const Duration(seconds: 3));
    expect(c.read(missionSimulatorProvider).missionDay, 2);
    n.setRunning(false);
    await tester.pump(const Duration(seconds: 6));
    expect(c.read(missionSimulatorProvider).missionDay, 2);
    n.setRunning(true);
    c.dispose();
    await tester.pump(const Duration(seconds: 6));
  });

  test('reset retains display preferences and clears submitted-sample state', () {
    final c = create();
    final n = c.read(apoloStateNotifierProvider.notifier);
    n.setHighContrast(true);
    n.setAutoTips(true);
    n.submitSample();
    n.setSolarStorm(true);
    c.read(missionSimulatorProvider.notifier).resetNominal();
    for (final s in c.read(apoloStateNotifierProvider).values) {
      expect(s.highContrast, isTrue);
      expect(s.autoTips, isTrue);
      expect(s.solarStormActive, isFalse);
      expect(s.samples, hasLength(1));
      expect(s.missionDay, 1);
    }
  });

  testWidgets('card fits a narrow sheet and advances mission', (tester) async {
    final c = create();
    await tester.pumpWidget(UncontrolledProviderScope(container: c, child: const MaterialApp(home: Scaffold(body: SizedBox(width: 360, child: MissionSimulatorCard())))));
    await tester.tap(find.text('+1d'));
    await tester.pump();
    expect(c.read(missionSimulatorProvider).missionDay, 2);
    expect(tester.takeException(), isNull);
  });
}
