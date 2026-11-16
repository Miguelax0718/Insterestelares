import 'package:astramed/features/crew/models/astronaut_profile.dart';
import 'package:astramed/features/crew/presentation/providers/crew_provider.dart';
import 'package:astramed/features/simulation/presentation/providers/mission_simulator_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const crew = ['AST-01', 'AST-02', 'AST-03', 'AST-04', 'AST-05'];

  ProviderContainer create() {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    c.read(missionSimulatorProvider.notifier).initializeNominal();
    return c;
  }

  AstronautProfile member(ProviderContainer c, String id) =>
      c.read(crewMembersProvider).firstWhere((p) => p.id == id);

  test('el calendario es determinista y cada tripulante tiene episodios', () {
    for (final id in crew) {
      final starts = [
        for (var day = 2; day <= 180; day++)
          if (MissionEpisodes.startingOn(id, day) != null) day,
      ];
      expect(starts, isNotEmpty, reason: id);
      // Aislados: unos pocos por misión, no todas las semanas.
      expect(starts.length, lessThanOrEqualTo(12), reason: id);
      for (final day in starts) {
        expect(MissionEpisodes.startingOn(id, day),
            MissionEpisodes.startingOn(id, day));
      }
    }
  });

  test('mareo espacial: 3 de 5 en los días 2–4 y se resuelve solo', () {
    final c = create();
    final simulator = c.read(missionSimulatorProvider.notifier);
    final baselineHr = member(c, 'AST-01').vitals.heartRate;

    simulator.advanceDays(); // día 2
    final sick = c
        .read(crewMembersProvider)
        .where((p) => p.riskLevel == CrewRiskLevel.warning)
        .map((p) => p.id);
    expect(sick, ['AST-01', 'AST-03', 'AST-04']);
    expect(member(c, 'AST-01').exercise.targetReached, isFalse);
    expect(member(c, 'AST-01').vitals.heartRate, baselineHr + 8);
    expect(member(c, 'AST-02').riskLevel, CrewRiskLevel.nominal);

    simulator.advanceDays(3); // día 5
    expect(member(c, 'AST-01').vitals.heartRate, baselineHr);
    expect(member(c, 'AST-01').exercise.targetReached, isTrue);
    expect(
      c.read(crewMembersProvider).every(
            (p) => p.riskLevel == CrewRiskLevel.nominal,
          ),
      isTrue,
    );
    expect(
      c.read(missionSimulatorProvider).log.any((l) => l.contains('resolved')),
      isTrue,
    );
  });

  test('180 días: los episodios nunca llevan a estado crítico y se recuperan',
      () {
    final c = create();
    final simulator = c.read(missionSimulatorProvider.notifier);
    final start = {
      for (final p in c.read(crewMembersProvider)) p.id: p.vitals,
    };
    for (var day = 2; day <= 180; day++) {
      simulator.advanceDays();
      for (final p in c.read(crewMembersProvider)) {
        expect(p.riskLevel, isNot(CrewRiskLevel.critical),
            reason: '${p.id} día $day');
      }
    }
    for (final p in c.read(crewMembersProvider)) {
      if (MissionEpisodes.activeOn(p.id, 180) != null) continue;
      expect(p.vitals.heartRate, closeTo(start[p.id]!.heartRate, 1e-6));
      expect(p.vitals.bodyTemp, closeTo(start[p.id]!.bodyTemp, 1e-6));
      expect(p.exercise.targetReached, isTrue);
    }
  });

  test('reiniciar la misión borra los episodios activos', () {
    final c = create();
    final simulator = c.read(missionSimulatorProvider.notifier);
    simulator.advanceDays(); // AST-01 con mareo espacial
    simulator.resetNominal();
    expect(
      c.read(crewMembersProvider).every(
            (p) => p.riskLevel == CrewRiskLevel.nominal,
          ),
      isTrue,
    );
    simulator.advanceDays(4); // día 5, sin restos del episodio anterior
    expect(member(c, 'AST-01').vitals.heartRate,
        create().read(crewMembersProvider).first.vitals.heartRate);
  });
}
