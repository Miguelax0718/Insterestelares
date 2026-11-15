import 'package:astramed/features/02_radiation/data/biomarker_repository.dart';
import 'package:astramed/features/02_radiation/data/biomarker_simulator.dart';
import 'package:astramed/features/02_radiation/data/example_mission.dart';
import 'package:astramed/features/02_radiation/providers/biomarker_score_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final repo = MockBiomarkerRepository();

  test('tripulación y línea base de cada astronauta', () {
    expect(repo.crewIds(), BiomarkerSimulator.defaultCrew);
    expect(repo.baselineOf('AST-01').sampleCount, 3);
    expect(() => repo.baselineOf('X'), throwsArgumentError);
  });

  test('muestras ordenadas por fecha y solo del astronauta pedido', () {
    final urine = repo.urineSamples('AST-02');
    expect(urine, isNotEmpty);
    expect(urine.every((u) => u.astronautId == 'AST-02'), isTrue);
    for (var i = 1; i < urine.length; i++) {
      expect(urine[i].takenAt.isBefore(urine[i - 1].takenAt), isFalse);
    }
    expect(repo.bloodSamples('AST-02').first.takenAt,
        repo.dateOfMissionDay(-92).add(const Duration(hours: 7)));
  });

  test('tormenta solar: solo existe desde el día del SPE', () {
    expect(repo.lastSolarEventAt(repo.dateOfMissionDay(exampleSpeDay - 1)), isNull);
    expect(repo.lastSolarEventAt(repo.dateOfMissionDay(exampleSpeDay + 1)),
        repo.dateOfMissionDay(exampleSpeDay).add(const Duration(hours: 12)));
  });

  test('el puntaje B sale de los datos del repositorio (realista vs extremo)', () {
    const calc = BiomarkerScoreCalculator();
    double score(BiomarkerRepository r) {
      final date = r.dateOfMissionDay(exampleSpeDay + 1).add(const Duration(hours: 12));
      return calc
          .summarize(
            baseline: r.baselineOf('AST-01'),
            urineSamples: r.urineSamples('AST-01'),
            bloodSamples: r.bloodSamples('AST-01'),
            date: date,
            lastSolarEventAt: r.lastSolarEventAt(date),
          )
          .score;
    }

    final extreme =
        MockBiomarkerRepository(scenario: SimulationScenario.extremeHypothetical);
    expect(score(extreme), greaterThan(score(repo) + 0.15));
  });
}
