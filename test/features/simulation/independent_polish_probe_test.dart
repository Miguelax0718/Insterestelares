import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:astramed/features/02_radiation/providers/biomarker_providers.dart';
import 'package:astramed/features/apolo/providers/apolo_providers.dart';
import 'package:astramed/features/crew/presentation/providers/crew_provider.dart';
import 'package:astramed/features/simulation/presentation/providers/mission_simulator_provider.dart';

void main() {
  test('S1/S3: rejected day advances preserve crew and simulator state', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final simulator = container.read(missionSimulatorProvider.notifier);
    simulator.initializeNominal();

    final before = jsonEncode(
      container.read(crewMembersProvider).map((m) => m.toJson()).toList(),
    );
    final apoloBefore = container.read(apoloStateNotifierProvider);
    final simulatorBefore = container.read(missionSimulatorProvider);

    for (final days in [0, -1, 366]) {
      expect(() => simulator.advanceDays(days), throwsArgumentError);
      expect(
        jsonEncode(
          container.read(crewMembersProvider).map((m) => m.toJson()).toList(),
        ),
        before,
      );
      expect(container.read(apoloStateNotifierProvider), same(apoloBefore));
      expect(container.read(missionSimulatorProvider), same(simulatorBefore));
    }
  });

  test('S1/S3: every event can reset before synchronized progression', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final simulator = container.read(missionSimulatorProvider.notifier);

    for (final event in SimulationEvent.values) {
      simulator.initializeNominal();
      simulator.triggerEvent(event, astronautId: 'AST-02');
      simulator.resetNominal();

      expect(container.read(nominalCrewCountProvider), 5);
      expect(container.read(missionSimulatorProvider).missionDay, 1);

      for (var day = 2; day <= 8; day++) {
        simulator.advanceDays();
        expect(container.read(missionSimulatorProvider).missionDay, day);
        expect(container.read(selectedMissionDayProvider), day);
        expect(
          container.read(crewMembersProvider).every(
                (member) => member.vitals.missionDay == day,
              ),
          isTrue,
        );
        expect(
          container.read(apoloStateNotifierProvider).values.every(
                (state) => state.missionDay == day,
              ),
          isTrue,
        );
      }
    }
  });
}
