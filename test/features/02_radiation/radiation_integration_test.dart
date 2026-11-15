import 'package:astramed/features/02_radiation/data/biomarker_simulator.dart';
import 'package:astramed/features/02_radiation/data/dose_linked_biomarker_repository.dart';
import 'package:astramed/features/02_radiation/data/radiation_sample_repository.dart';
import 'package:astramed/features/02_radiation/models/space_weather_reading.dart';
import 'package:astramed/features/02_radiation/models/daily_radiation_record.dart';
import 'package:astramed/features/02_radiation/presentation/radiation_view.dart';
import 'package:astramed/features/02_radiation/providers/biomarker_providers.dart';
import 'package:astramed/features/02_radiation/providers/radiation_data_provider.dart';
import 'package:astramed/features/02_radiation/providers/radiation_integration_provider.dart';
import 'package:astramed/features/02_radiation/widgets/biomarker_panel.dart';
import 'package:astramed/features/02_radiation/widgets/cumulative_dose_chart.dart';
import 'package:astramed/features/crew/presentation/providers/crew_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'radiation_test_data.dart';

void main() {
  final mission = loadRadiationTestMission();

  Future<ProviderContainer> containerForMission() async {
    final c = ProviderContainer(
      overrides: [
        ...radiationIntegrationOverrides,
        radiationMissionDataProvider.overrideWith((ref) async => mission),
      ],
    );
    addTearDown(c.dispose);
    await c.read(radiationMissionDataProvider.future);
    return c;
  }

  test(
    'Adapter uses measured SPE inputs and preserves the biological algorithm',
    () {
      final repo = DoseLinkedBiomarkerRepository(
        mission: mission,
        crewIds: ['AST-01', 'AST-02', 'AST-03', 'AST-04', 'AST-05'],
        scenario: SimulationScenario.realistic,
      );
      final doses = {
        for (final r in mission.dosimetry.where((r) => r.missionDay == 95))
          r.astronautId: r.speEventDoseMsv,
      };
      expect(repo.eventDoseMsv, doses);
      expect(repo.eventDoseMsv.containsKey('AST-05'), isFalse);
      expect(repo.crewIds().last, 'AST-05');
      expect(repo.baselineOf('AST-05').astronautId, 'AST-05');
      final expected = BiomarkerSimulator().simulate(
        crewIds: repo.crewIds(),
        missionDays: 180,
        speDay: 95,
        speDoseMsv: doses,
        sheltered: {'AST-02', 'AST-04'},
      );
      expect(
        repo.bloodSamples('AST-02').map((b) => b.lymphocytes10e9PerL).toList(),
        expected.blood
            .where((b) => b.sample.astronautId == 'AST-02')
            .map((b) => b.sample.lymphocytes10e9PerL)
            .toList(),
      );
    },
  );

  test(
    'Physical and biological contracts follow the same person and date',
    () async {
      final c = await containerForMission();
      expect(c.read(selectedMissionDayProvider), 1);
      c.read(selectedMissionDayProvider.notifier).state = 96;
      c.read(selectedAstronautIdProvider.notifier).state = 'AST-03';
      final dose = c.read(selectedDoseSummaryProvider)!;
      final bio = c.read(selectedBioSummaryProvider);
      expect(dose.astronautId, bio.astronautId);
      expect(dose.date, bio.date);
      expect(
        c.read(biomarkerRepositoryProvider),
        isA<DoseLinkedBiomarkerRepository>(),
      );
      final total = dose.careerEffectiveDoseMsv;
      c.read(biomarkerScenarioProvider.notifier).state =
          SimulationScenario.extremeHypothetical;
      expect(
        c.read(selectedDoseSummaryProvider)!.careerEffectiveDoseMsv,
        total,
      );
      expect(c.read(selectedBioSummaryProvider).score, greaterThan(bio.score));
      c.read(selectedAstronautIdProvider.notifier).state = 'AST-05';
      expect(c.read(selectedDoseSummaryProvider), isNull);
      expect(c.read(selectedBioSummaryProvider).astronautId, 'AST-05');
      c.read(selectedAstronautIdProvider.notifier).state = 'AST-01';
      c.read(selectedMissionDayProvider.notifier).state = 181;
      expect(c.read(selectedDoseSummaryProvider), isNull);
      expect(c.read(selectedBioSummaryProvider).date.day, isNotNull);
    },
  );

  test(
    'Longer missions propagate to biology; multiple SPEs fail explicitly',
    () {
      final longer = RadiationMissionData(
        crewProfiles: mission.crewProfiles,
        dosimetry: mission.dosimetry
            .map(
              (r) => r.missionDay == 180
                  ? DailyRadiationRecord(
                      astronautId: r.astronautId,
                      missionDay: 365,
                      module: r.module,
                      effectiveDoseMsv: r.effectiveDoseMsv,
                      organDoses: r.organDoses,
                      speEventDoseMsv: r.speEventDoseMsv,
                      dataType: r.dataType,
                    )
                  : r,
            )
            .toList(),
        spaceWeather: mission.spaceWeather,
      );
      final repo = DoseLinkedBiomarkerRepository(
        mission: longer,
        crewIds: ['AST-01'],
        scenario: SimulationScenario.realistic,
      );
      expect(repo.missionDays, 365);
      final invalid = RadiationMissionData(
        crewProfiles: mission.crewProfiles,
        dosimetry: mission.dosimetry,
        spaceWeather: [
          ...mission.spaceWeather,
          const SpaceWeatherReading(
            missionDay: 100,
            protonFluxPfu: 1,
            alertLevel: 'alert',
            eventSpe: true,
            dataType: 'synthetic_demo',
          ),
        ],
      );
      expect(
        () => DoseLinkedBiomarkerRepository(
          mission: invalid,
          crewIds: ['AST-01'],
          scenario: SimulationScenario.realistic,
        ),
        throwsUnsupportedError,
      );
    },
  );

  testWidgets(
    'Combined screen shares day/crew and handles missing and return-day doses',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 6000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final c = await containerForMission();
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: c,
          child: const MaterialApp(home: Scaffold(body: RadiationView())),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(BiomarkerPanel), findsOneWidget);
      expect(find.byType(Slider), findsOneWidget);
      expect(find.byType(CumulativeDoseChart), findsOneWidget);
      final slider = tester.widget<Slider>(
        find.byKey(const Key('radiationMissionDaySlider')),
      );
      slider.onChanged!(96);
      await tester.pumpAndSettle();
      expect(find.text('Día de misión: 96 de 180'), findsOneWidget);
      expect(find.byType(Slider), findsOneWidget);
      expect(
        c.read(selectedBioSummaryProvider).date,
        c.read(selectedDoseSummaryProvider)!.date,
      );
      c.read(selectedAstronautIdProvider.notifier).state = 'AST-05';
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('missingDosimetry')), findsOneWidget);
      expect(find.byType(CumulativeDoseChart), findsNothing);
      expect(find.textContaining('Astronauta: AST-05'), findsOneWidget);
      c.read(selectedAstronautIdProvider.notifier).state = 'AST-01';
      c.read(selectedMissionDayProvider.notifier).state = 181;
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('missingDailyDose')), findsOneWidget);
      expect(find.text('Día de misión: 181 de 180 (regreso)'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
