import 'dart:io';

import 'package:astramed/features/02_radiation/data/biomarker_simulator.dart';
import 'package:astramed/features/02_radiation/data/generate_biomarker_sample.dart';
import 'package:astramed/features/02_radiation/data/inspiration4_reference.dart';
import 'package:astramed/features/02_radiation/models/biomarkers/biomarker_baseline.dart';
import 'package:astramed/features/02_radiation/providers/biomarker_score_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const speDay = 95;

  BiomarkerSimulation run(SimulationScenario s) => BiomarkerSimulator().simulate(
        speDay: speDay,
        speDoseMsv: exampleSpeDoseMsv,
        sheltered: exampleSheltered,
        scenario: s,
      );

  BiomarkerBaseline baselineOf(BiomarkerSimulation sim, String id) =>
      sim.baselines.firstWhere((b) => b.astronautId == id);

  double lymphChange(BiomarkerSimulation sim, String id, int day) =>
      BiomarkerScoreCalculator.relativeChange(
        sim.blood
            .firstWhere((b) => b.sample.astronautId == id && b.missionDay == day)
            .sample
            .lymphocytes10e9PerL,
        baselineOf(sim, id).of(Biomarker.bloodLymphocytes)!,
      );

  test('misma semilla, mismos datos (reproducible)', () {
    final a = run(SimulationScenario.realistic);
    final b = run(SimulationScenario.realistic);
    expect(a.urine.map((u) => u.sample.toJson()).toList(),
        b.urine.map((u) => u.sample.toJson()).toList());
    expect(a.blood.map((u) => u.sample.toJson()).toList(),
        b.blood.map((u) => u.sample.toJson()).toList());
  });

  test('funciona sin tormenta solar y sin datos externos', () {
    final sim = BiomarkerSimulator().simulate(missionDays: 30);
    expect(sim.baselines, hasLength(4));
    expect(sim.blood.where((b) => b.phase == MissionPhase.inflight).length, 4);
    expect(() => BiomarkerSimulator()
            .simulate(scenario: SimulationScenario.extremeHypothetical),
        throwsArgumentError);
  });

  test('la sangre previa al vuelo es la real de Inspiration4', () {
    final sim = run(SimulationScenario.realistic);
    for (var i = 0; i < 4; i++) {
      final id = BiomarkerSimulator.defaultCrew[i];
      final ref = Inspiration4Reference.subjects[i];
      final pre = sim.blood
          .where((b) => b.sample.astronautId == id && b.phase == MissionPhase.preflight)
          .toList();
      expect(pre.map((b) => b.missionDay), [-92, -44, -3]);
      expect(pre.every((b) => b.origin == BloodOrigin.realInspiration4), isTrue);
      expect(pre.map((b) => b.sample.lymphocytes10e9PerL),
          ref.preflight.map((v) => v.lymphocytes10e9PerL));
      expect(baselineOf(sim, id).of(Biomarker.bloodLymphocytes),
          closeTo(ref.preflightLymphocyteMean, 1e-9));
    }
  });

  test('línea base de 8-OHdG dentro del rango de adultos sanos (Graille 2020)', () {
    final sim = run(SimulationScenario.realistic);
    for (final b in sim.baselines) {
      expect(b.sampleCount, 3);
      expect(b.of(Biomarker.urineOhdg)!, inInclusiveRange(1.5, 12.0));
    }
  });

  test('calendario: orina semanal y sangre mensual, más tras el SPE y al regresar', () {
    final sim = run(SimulationScenario.realistic);
    List<int> days(Iterable<dynamic> xs) => [
          for (final x in xs)
            if (x.sample.astronautId == 'AST-01') x.missionDay as int
        ];
    expect(days(sim.urine), containsAll([-92, -44, -3, 7, 91, 96, 98, 175, 181]));
    expect(days(sim.blood), [-92, -44, -3, 30, 60, 90, 96, 98, 102, 120, 150, 180, 181]);
  });

  test('regreso (R+1): reproduce el cambio real de linfocitos de Inspiration4', () {
    final sim = run(SimulationScenario.realistic);
    for (var i = 0; i < 4; i++) {
      final id = BiomarkerSimulator.defaultCrew[i];
      expect(lymphChange(sim, id, 181),
          closeTo(Inspiration4Reference.subjects[i].returnLymphocyteChange, 0.01));
    }
  });

  test('realista: un SPE de 50 mSv casi no mueve los linfocitos (< 3 %)', () {
    final noSpe = BiomarkerSimulator().simulate(speDay: speDay);
    final withSpe = run(SimulationScenario.realistic);
    final a = noSpe.blood.firstWhere(
        (b) => b.sample.astronautId == 'AST-01' && b.missionDay == 96);
    final b = withSpe.blood.firstWhere(
        (b) => b.sample.astronautId == 'AST-01' && b.missionDay == 96);
    expect(b.sample.lymphocytes10e9PerL / a.sample.lymphocytes10e9PerL,
        inInclusiveRange(0.97, 1.0));
  });

  test('extremo: fuera del refugio caen mucho más que dentro', () {
    final ext = run(SimulationScenario.extremeHypothetical);
    final real = run(SimulationScenario.realistic);
    double ratio(String id) =>
        ext.blood
            .firstWhere((b) => b.sample.astronautId == id && b.missionDay == 96)
            .sample
            .lymphocytes10e9PerL /
        real.blood
            .firstWhere((b) => b.sample.astronautId == id && b.missionDay == 96)
            .sample
            .lymphocytes10e9PerL;
    expect(ratio('AST-01'), closeTo(0.5, 0.03)); // 1 Gy
    expect(ratio('AST-02'), closeTo(0.875, 0.03)); // 0,25 Gy en el refugio
    expect(ext.scenario.dataType, 'synthetic_hypothetical');
  });

  test('el puntaje B tras el SPE es mayor en el escenario extremo', () {
    const calc = BiomarkerScoreCalculator();
    double scoreAfterSpe(SimulationScenario s) {
      final sim = run(s);
      return calc
          .summarize(
            baseline: baselineOf(sim, 'AST-01'),
            urineSamples: sim.urine.map((u) => u.sample).toList(),
            bloodSamples: sim.blood.map((b) => b.sample).toList(),
            date: BiomarkerSimulator.defaultLaunch
                .add(const Duration(days: 96, hours: 12)),
          )
          .score;
    }

    expect(scoreAfterSpe(SimulationScenario.extremeHypothetical),
        greaterThan(scoreAfterSpe(SimulationScenario.realistic) + 0.15));
  });

  test('isoprostanos ~20 % más bajos en vuelo (patrón de Mir)', () {
    final sim = run(SimulationScenario.realistic);
    for (final id in BiomarkerSimulator.defaultCrew) {
      final base = baselineOf(sim, id).of(Biomarker.urineIsoprostane)!;
      final flight = sim.urine
          .where((u) =>
              u.sample.astronautId == id &&
              u.phase == MissionPhase.inflight &&
              u.confounder == 'none')
          .map((u) => u.sample.isoprostanePerCreatinine)
          .toList();
      final mean = flight.reduce((a, b) => a + b) / flight.length;
      expect(mean / base, inInclusiveRange(0.65, 0.95));
    }
  });

  test('escribe los CSV y el JSON de líneas base', () {
    final dir = Directory.systemTemp.createTempSync('rad_');
    addTearDown(() => dir.deleteSync(recursive: true));
    writeSimulation(dir, 'realistic', run(SimulationScenario.realistic));
    final urine = File('${dir.path}/urine_samples_realistic.csv').readAsLinesSync();
    expect(urine.first, startsWith('mission_day,phase,taken_at,astronaut_id,ohdg_ng_ml'));
    final blood = File('${dir.path}/blood_samples_realistic.csv').readAsLinesSync();
    expect(blood[1], contains('realInspiration4,C001'));
    expect(File('${dir.path}/biomarker_baselines_realistic.json').existsSync(), isTrue);
  });
}
