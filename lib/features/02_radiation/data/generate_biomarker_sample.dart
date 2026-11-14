import 'dart:convert';
import 'dart:io';

import 'biomarker_simulator.dart';
import 'example_mission.dart';

export 'example_mission.dart';

/// Genera las muestras de orina y sangre de ejemplo para la demo.
///
/// Uso (desde la raíz del repo):
///   dart run lib/features/02_radiation/data/generate_biomarker_sample.dart
///   dart run lib/features/02_radiation/data/generate_biomarker_sample.dart otra/carpeta
///
/// Escribe en DB/samples/biomarkers/ (o la carpeta indicada), para cada
/// escenario (realistic / extreme):
///   `biomarker_baselines_ESCENARIO.json`
///   `urine_samples_ESCENARIO.csv`
///   `blood_samples_ESCENARIO.csv`
void main(List<String> args) {
  final dir = Directory(args.isEmpty ? 'DB/samples/biomarkers' : args.first)
    ..createSync(recursive: true);

  for (final entry in {
    'realistic': SimulationScenario.realistic,
    'extreme': SimulationScenario.extremeHypothetical,
  }.entries) {
    final sim = BiomarkerSimulator().simulate(
      speDay: exampleSpeDay,
      speDoseMsv: exampleSpeDoseMsv,
      sheltered: exampleSheltered,
      scenario: entry.value,
    );
    writeSimulation(dir, entry.key, sim);
    stdout.writeln('Escenario ${entry.key}: ${sim.urine.length} muestras de '
        'orina y ${sim.blood.length} de sangre en ${dir.path}');
  }
}

void writeSimulation(Directory dir, String name, BiomarkerSimulation sim) {
  final type = sim.scenario.dataType;

  File('${dir.path}/biomarker_baselines_$name.json').writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert([
      for (final b in sim.baselines) {...b.toJson(), 'dataType': type},
    ]),
  );

  final urine = StringBuffer()
    ..writeln('mission_day,phase,taken_at,astronaut_id,ohdg_ng_ml,'
        'isoprostane_ng_ml,mda_umol_l,creatinine_mg_dl,'
        'ohdg_ng_mg_creatinine,confounder,data_type');
  for (final u in sim.urine) {
    final s = u.sample;
    urine.writeln([
      u.missionDay,
      u.phase.name,
      s.takenAt.toIso8601String(),
      s.astronautId,
      s.ohdgNgPerMl,
      s.isoprostaneNgPerMl,
      s.mdaUmolPerL,
      s.creatinineMgPerDl,
      s.ohdgPerCreatinine.toStringAsFixed(2),
      u.confounder,
      type,
    ].join(','));
  }
  File('${dir.path}/urine_samples_$name.csv').writeAsStringSync(urine.toString());

  final blood = StringBuffer()
    ..writeln('mission_day,phase,taken_at,astronaut_id,lymphocytes_10e9_l,'
        'neutrophils_10e9_l,crp_mg_l,origin,reference_subject,data_type');
  for (final b in sim.blood) {
    final s = b.sample;
    blood.writeln([
      b.missionDay,
      b.phase.name,
      s.takenAt.toIso8601String(),
      s.astronautId,
      s.lymphocytes10e9PerL,
      s.neutrophils10e9PerL,
      s.crpMgPerL,
      b.origin.name,
      b.referenceSubject,
      type,
    ].join(','));
  }
  File('${dir.path}/blood_samples_$name.csv').writeAsStringSync(blood.toString());
}
