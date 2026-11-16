import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/sample_data.dart';

/// Una medición diaria de signos vitales de `DB/samples/vitals/`.
class VitalsSamplePoint {
  const VitalsSamplePoint({
    required this.missionDay,
    required this.phase,
    required this.astronautId,
    required this.heartRate,
    required this.systolicBP,
    required this.diastolicBP,
    required this.spO2,
    required this.bodyTemp,
    required this.bloodGlucose,
    required this.respiratoryRate,
    required this.orthostaticIntolerance,
    required this.event,
  });

  final int missionDay;
  final String phase; // preflight | inflight | postflight
  final String astronautId;
  final double heartRate;
  final double systolicBP;
  final double diastolicBP;
  final double spO2;
  final double bodyTemp;
  final double bloodGlucose;
  final double respiratoryRate;
  final bool orthostaticIntolerance;

  /// Emergencia hipotética del escenario extremo, o vacío.
  final String event;
}

/// Lee las muestras de signos vitales del bundle local (offline).
class VitalsSampleRepository {
  VitalsSampleRepository({AssetBundle? assetBundle})
      : _bundle = assetBundle ?? rootBundle;
  final AssetBundle _bundle;

  static String assetPath(SampleScenario scenario) =>
      'DB/samples/vitals/vitals_daily_${scenario.fileSuffix}.csv';

  Future<List<VitalsSamplePoint>> load(SampleScenario scenario) async =>
      parse(await _bundle.loadString(assetPath(scenario)));

  static List<VitalsSamplePoint> parse(String csv) {
    final rows = parseSampleCsv(csv, columns: const {
      'mission_day',
      'phase',
      'astronaut_id',
      'heart_rate_bpm',
      'systolic_bp_mmhg',
      'diastolic_bp_mmhg',
      'spo2_pct',
      'body_temp_c',
      'blood_glucose_mg_dl',
      'respiratory_rate_rpm',
      'orthostatic_intolerance',
      'event',
    });
    return [
      for (final r in rows)
        VitalsSamplePoint(
          missionDay: r.integer('mission_day'),
          phase: r.text('phase'),
          astronautId: r.text('astronaut_id'),
          heartRate: r.number('heart_rate_bpm'),
          systolicBP: r.number('systolic_bp_mmhg'),
          diastolicBP: r.number('diastolic_bp_mmhg'),
          spO2: r.number('spo2_pct'),
          bodyTemp: r.number('body_temp_c'),
          bloodGlucose: r.number('blood_glucose_mg_dl'),
          respiratoryRate: r.number('respiratory_rate_rpm'),
          orthostaticIntolerance: r.flag('orthostatic_intolerance'),
          event: r.text('event'),
        ),
    ];
  }
}

/// Muestra de signos vitales del escenario elegido.
final vitalsSampleProvider = FutureProvider<List<VitalsSamplePoint>>((ref) {
  return VitalsSampleRepository(
    assetBundle: ref.watch(sampleAssetBundleProvider),
  ).load(ref.watch(sampleScenarioProvider));
});
