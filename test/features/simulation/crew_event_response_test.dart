import 'package:astramed/features/agent/domain/agent_contracts.dart';
import 'package:astramed/features/apolo/providers/apolo_providers.dart';
import 'package:astramed/features/crew/presentation/providers/crew_provider.dart';
import 'package:astramed/features/simulation/agent/mission_simulator_skill.dart';
import 'package:astramed/features/simulation/presentation/providers/mission_simulator_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Unused implements ConfirmationGate, AuditLog, MemoryStore, AgentFlagsStore, MedicationSafety {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Ui implements AgentUiSink {
  @override
  void emit(AgentComponentEvent event) {}
  @override
  void submit(String componentId, Map<String, dynamic> result) {}
}

const _crew = [
  CrewSnapshot(id: 'AST-01', age: 46, zone: 'Command Module (Destiny)', sleepHours: 7.4,
      cumulativeDoseMsv: 12, exerciseTargetReached: true),
  CrewSnapshot(id: 'AST-02', age: 38, zone: 'Medical Bay / Harmony Module', sleepHours: 7.5,
      cumulativeDoseMsv: 12, exerciseTargetReached: true),
  CrewSnapshot(id: 'AST-03', age: 34, zone: 'Quest Airlock (Post-EVA)', sleepHours: 7.6,
      cumulativeDoseMsv: 12, exerciseTargetReached: true),
  CrewSnapshot(id: 'AST-04', age: 31, zone: 'Columbus Laboratory', sleepHours: 7.7,
      cumulativeDoseMsv: 12, exerciseTargetReached: true),
  CrewSnapshot(id: 'AST-05', age: 36, zone: 'Kibo Module / Observation Cupola', sleepHours: 7.8,
      cumulativeDoseMsv: 12, exerciseTargetReached: true),
];

List<CrewEventResponse> _run(SimulationEvent e, {int seed = CrewEventResponseModel.defaultSeed, int day = 1,
        List<CrewSnapshot> crew = _crew}) =>
    CrewEventResponseModel.evaluate(event: e, exposed: crew, missionDay: day, wholeCrew: true, seed: seed);

String _signature(List<CrewEventResponse> r) => r
    .map((x) => '${x.astronautId}:${x.exposure.toStringAsFixed(6)}:'
        '${x.episodes.map((e) => '${e.kind.name}@${e.severity.toStringAsFixed(6)}').join(',')}')
    .join('|');

void main() {
  test('same seed reproduces the demo; another seed changes it', () {
    for (final e in SimulationEvent.values) {
      expect(_signature(_run(e)), _signature(_run(e)));
      expect(_signature(_run(e, seed: 7)), isNot(_signature(_run(e))));
    }
  });

  test('crew-wide events reach people differently and not everyone is affected', () {
    var affected = 0;
    var resilient = 0;
    final kinds = <AffectionKind>{};
    for (final e in SimulationEvent.values) {
      final r = _run(e);
      expect(r.map((x) => x.exposure.toStringAsFixed(3)).toSet().length, greaterThan(1));
      affected += r.where((x) => x.affected).length;
      resilient += r.where((x) => !x.affected).length;
      kinds.addAll(r.expand((x) => x.conditions).map((c) => c.kind));
    }
    expect(affected, greaterThan(0));
    expect(resilient, greaterThan(0));
    expect(kinds.length, greaterThan(3));
  });

  test('solar dose follows module shielding', () {
    final r = {for (final x in _run(SimulationEvent.solarParticleEvent)) x.astronautId: x};
    // Cupola (thin shielding) receives more than the Harmony medical bay.
    expect(r['AST-05']!.exposure, greaterThan(r['AST-02']!.exposure));
    expect(r['AST-05']!.cumulativeDoseMsv, greaterThan(r['AST-02']!.cumulativeDoseMsv));
  });

  test('current sleep debt raises susceptibility to the next sleep loss', () {
    final rested = _run(SimulationEvent.sleepLoss, crew: [_crew.first]).single;
    final tired = _run(SimulationEvent.sleepLoss, crew: [
      const CrewSnapshot(id: 'AST-01', age: 46, zone: 'Command Module (Destiny)', sleepHours: 4.5,
          cumulativeDoseMsv: 12, exerciseTargetReached: true),
    ]).single;
    expect(tired.susceptibility, greaterThan(rested.susceptibility));
  });

  test('episodes peak, then fade with countermeasures; bone keeps a residual', () {
    const acute = AffectionEpisode(astronautId: 'A', event: SimulationEvent.sleepLoss,
        kind: AffectionKind.stressHormonal, onsetDay: 3, severity: 1, peakDeltas: {'cort': 40},
        halfLifeDays: 1.5, adherence: 1);
    expect(acute.shapeOn(2), 0);
    expect(acute.shapeOn(3), 1);
    expect(acute.shapeOn(5), lessThan(acute.shapeOn(4)));
    expect(acute.resolvedOn(15), isTrue);
    const bone = AffectionEpisode(astronautId: 'A', event: SimulationEvent.exerciseFailure,
        kind: AffectionKind.boneResorption, onsetDay: 1, severity: 1, peakDeltas: {'ntx': 20},
        halfLifeDays: 7, adherence: 1);
    expect(bone.shapeOn(2), lessThan(bone.shapeOn(3)));
    expect(bone.shapeOn(200), closeTo(0.25, 0.01));
    expect(bone.resolvedOn(200), isFalse);
  });

  test('simulator evolves conditions, ends the storm and reset clears episodes', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final n = c.read(missionSimulatorProvider.notifier)..initializeNominal();
    n.triggerEvent(SimulationEvent.solarParticleEvent);
    final peakRate = c.read(crewMembersProvider).map((p) => p.radiation.doseRateMicroSvPerHour).toList();
    expect(c.read(missionSimulatorProvider).episodes, isNotEmpty);
    expect(c.read(apoloStateNotifierProvider).values.every((s) => s.solarStormActive), isTrue);
    n.advanceDays(6);
    final later = c.read(crewMembersProvider).map((p) => p.radiation.doseRateMicroSvPerHour).toList();
    for (var i = 0; i < later.length; i++) {
      expect(later[i], lessThan(peakRate[i]));
    }
    expect(c.read(apoloStateNotifierProvider).values.any((s) => s.solarStormActive), isFalse);
    expect(c.read(missionSimulatorProvider).log.any((l) => l.contains('Countermeasure')), isTrue);
    n.resetNominal();
    expect(c.read(missionSimulatorProvider).episodes, isEmpty);
    expect(c.read(nominalCrewCountProvider), 5);
  });

  test('whole-crew toggle applies sleep loss to everyone with different results', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final n = c.read(missionSimulatorProvider.notifier)..initializeNominal();
    n.setWholeCrew(true);
    n.triggerEvent(SimulationEvent.sleepLoss);
    final hours = c.read(crewMembersProvider).map((p) => p.sleep.sleepHours.toStringAsFixed(2)).toSet();
    expect(hours.length, greaterThan(1));
    expect(c.read(missionSimulatorProvider).episodes.map((e) => e.astronautId).toSet(), hasLength(5));
  });

  test('trigger tool validates scope', () async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    c.read(missionSimulatorProvider.notifier).initializeNominal();
    final unused = _Unused();
    final ctx = ToolContext(astronautId: 'AST-01', read: <T>(p) => c.read(p as ProviderListenable<T>),
        ui: _Ui(), confirm: unused, audit: unused, memory: unused, flags: unused, medication: unused);
    const tool = TriggerSimulationEventTool();
    expect((await tool.call({'event': 'workload', 'scope': 'bad'}, ctx)).ok, isFalse);
    expect((await tool.call({'event': 'workload', 'scope': 'crew', 'astronaut_id': 'AST-01'}, ctx)).ok, isFalse);
    expect(c.read(missionSimulatorProvider).episodes, isEmpty);
    final ok = await tool.call({'event': 'workload', 'scope': 'crew'}, ctx);
    expect(ok.ok, isTrue);
    expect(c.read(missionSimulatorProvider).episodes.map((e) => e.astronautId).toSet(), hasLength(5));
  });
}
