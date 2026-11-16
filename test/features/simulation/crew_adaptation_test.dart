import 'package:astramed/features/crew/models/astronaut_profile.dart';
import 'package:astramed/features/crew/presentation/providers/crew_provider.dart';
import 'package:astramed/features/simulation/presentation/providers/mission_simulator_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

ProviderContainer _create([MissionType type = MissionType.lunar]) {
  final c = ProviderContainer();
  addTearDown(c.dispose);
  final n = c.read(missionSimulatorProvider.notifier)..initializeNominal();
  n.setMissionType(type);
  return c;
}

void main() {
  for (final type in MissionType.values) {
    test('${type.name}: 180 routine days never make anyone critical', () {
      final c = _create(type);
      final n = c.read(missionSimulatorProvider.notifier);
      final start = {for (final p in c.read(crewMembersProvider)) p.id: p};
      for (var d = 0; d < 180; d++) {
        n.advanceDays();
        for (final p in c.read(crewMembersProvider)) {
          expect(p.riskLevel, isNot(CrewRiskLevel.critical), reason: '${p.id} day ${d + 2}: ${p.activeAlerts}');
          expect((p.vitals.heartRate - start[p.id]!.vitals.heartRate).abs(), lessThan(8));
          expect(p.sleep.sleepHours, inInclusiveRange(4.0, 8.5));
          expect(p.radiation.doseRateMicroSvPerHour, CrewAdaptationModel.doseRateFor(type));
        }
      }
    });
  }

  test('only the cumulative dose grows, at the background dose rate', () {
    final c = _create(MissionType.transit);
    final before = c.read(crewMembersProvider).first.radiation.cumulativeDoseMilliSv;
    c.read(missionSimulatorProvider.notifier).advanceDays(10);
    final after = c.read(crewMembersProvider).first.radiation.cumulativeDoseMilliSv;
    expect(after - before, closeTo(10 * 54.0 * 24 / 1000, 1e-6));
  });

  test('crew members adapt differently and do not switch status together', () {
    final c = _create();
    final n = c.read(missionSimulatorProvider.notifier);
    final sleep = <String>{};
    var mixedDays = 0;
    for (var d = 0; d < 60; d++) {
      n.advanceDays();
      final levels = c.read(crewMembersProvider).map((p) => p.riskLevel).toSet();
      if (levels.length > 1) mixedDays++;
    }
    sleep.addAll(c.read(crewMembersProvider).map((p) => p.sleep.sleepHours.toStringAsFixed(2)));
    expect(sleep.length, 5);
    expect(mixedDays, greaterThan(20));
  });

  test('solar particle event is critical only in thinly shielded modules', () {
    final c = _create();
    c.read(missionSimulatorProvider.notifier).triggerEvent(SimulationEvent.solarParticleEvent);
    final crew = {for (final p in c.read(crewMembersProvider)) p.id: p};
    // Destiny, Harmony and Columbus shelter the crew: warning, not critical.
    for (final id in ['AST-01', 'AST-02', 'AST-04']) {
      expect(crew[id]!.riskLevel, CrewRiskLevel.warning, reason: id);
    }
    // The Cupola keeps the original 180 µSv/h reference reading.
    expect(crew['AST-05']!.radiation.doseRateMicroSvPerHour, greaterThan(160));
    expect(crew['AST-05']!.riskLevel, CrewRiskLevel.critical);
  });
}
