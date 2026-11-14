import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:astramed/features/crew/presentation/providers/crew_provider.dart';

import '../data/biomarker_repository.dart';
import '../data/biomarker_simulator.dart';
import '../data/example_mission.dart';
import '../models/contracts/bio_summary.dart';
import 'biomarker_score_calculator.dart';

/// Escenario de la demo: realista (por defecto) o extremo hipotético.
final biomarkerScenarioProvider =
    StateProvider<SimulationScenario>((ref) => SimulationScenario.realistic);

/// Fuente de datos de biomarcadores. Hoy es el repositorio MOCK; para usar
/// datos reales basta con devolver otra implementación de
/// [BiomarkerRepository] aquí.
///
/// Simula a los mismos astronautas de la tripulación de la app (menú de
/// tripulación, `crewMembersProvider`).
final biomarkerRepositoryProvider = Provider<BiomarkerRepository>((ref) {
  final ids = ref.watch(
    crewMembersProvider.select((crew) => crew.map((p) => p.id).join(',')),
  );
  return MockBiomarkerRepository(
    scenario: ref.watch(biomarkerScenarioProvider),
    crewIds: ids.isEmpty ? BiomarkerSimulator.defaultCrew : ids.split(','),
  );
});

/// Astronauta cuyos biomarcadores se muestran: el mismo que está
/// seleccionado en el menú de tripulación de la app. Si no tiene datos de
/// biomarcadores, se usa el primero que sí tenga.
final biomarkerAstronautProvider = Provider<String>((ref) {
  final ids = ref.watch(biomarkerRepositoryProvider).crewIds();
  final selected = ref.watch(selectedAstronautIdProvider);
  return ids.contains(selected) ? selected : ids.first;
});

/// Día de misión que se está mirando (por defecto, el día después del SPE).
final selectedMissionDayProvider = StateProvider<int>((ref) => exampleSpeDay + 1);

final biomarkerScoreCalculatorProvider =
    Provider<BiomarkerScoreCalculator>((ref) => const BiomarkerScoreCalculator());

/// Resumen biológico (puntaje B y cambios vs. línea base) de un astronauta
/// al final de un día de misión.
final bioSummaryProvider =
    Provider.family<BioSummary, ({String astronautId, int missionDay})>(
  (ref, args) {
    final repo = ref.watch(biomarkerRepositoryProvider);
    final calc = ref.watch(biomarkerScoreCalculatorProvider);
    final date = repo
        .dateOfMissionDay(args.missionDay)
        .add(const Duration(hours: 23, minutes: 59));
    return calc.summarize(
      baseline: repo.baselineOf(args.astronautId),
      urineSamples: repo.urineSamples(args.astronautId),
      bloodSamples: repo.bloodSamples(args.astronautId),
      date: date,
      lastSolarEventAt: repo.lastSolarEventAt(date),
    );
  },
);

/// Resumen del astronauta y día seleccionados en la pantalla.
final selectedBioSummaryProvider = Provider<BioSummary>((ref) {
  return ref.watch(bioSummaryProvider((
    astronautId: ref.watch(biomarkerAstronautProvider),
    missionDay: ref.watch(selectedMissionDayProvider),
  )));
});
