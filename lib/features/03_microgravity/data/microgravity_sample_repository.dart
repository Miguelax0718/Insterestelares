import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/sample_data.dart';

/// Densidad mineral ósea de una zona en un día de la misión.
class BoneDensityPoint {
  const BoneDensityPoint({
    required this.missionDay,
    required this.astronautId,
    required this.site,
    required this.bmdGCm2,
    required this.changePct,
    required this.measurementType,
  });
  final int missionDay;
  final String astronautId;
  final String site; // lumbar_spine | femoral_neck | trochanter | total_hip
  final double bmdGCm2;
  final double changePct;
  final String measurementType; // dxa | model_estimate
}

/// Cambio de volumen de un grupo muscular en un día de la misión.
class MuscleVolumePoint {
  const MuscleVolumePoint({
    required this.missionDay,
    required this.astronautId,
    required this.region,
    required this.changePct,
  });
  final int missionDay;
  final String astronautId;
  final String region; // calf | thigh | upper_arm
  final double changePct;
}

/// Una sesión de ejercicio de contramedidas.
class ExerciseSamplePoint {
  const ExerciseSamplePoint({
    required this.missionDay,
    required this.astronautId,
    required this.deviceName,
    required this.durationMinutes,
    required this.targetMinutes,
    required this.event,
  });
  final int missionDay;
  final String astronautId;
  final String deviceName; // ARED | T2 | CEVIS
  final int durationMinutes;
  final int targetMinutes;
  final String event;
}

class MicrogravitySample {
  MicrogravitySample({
    required List<BoneDensityPoint> bone,
    required List<MuscleVolumePoint> muscle,
    required List<ExerciseSamplePoint> exercise,
  })  : bone = List.unmodifiable(bone),
        muscle = List.unmodifiable(muscle),
        exercise = List.unmodifiable(exercise);

  final List<BoneDensityPoint> bone;
  final List<MuscleVolumePoint> muscle;
  final List<ExerciseSamplePoint> exercise;

  /// Minutos de ejercicio por semana de misión (semana 1 = días 1–7).
  Map<int, int> weeklyExerciseMinutes(String astronautId) {
    final weeks = <int, int>{};
    for (final e in exercise.where((e) => e.astronautId == astronautId)) {
      final week = (e.missionDay - 1) ~/ 7 + 1;
      weeks[week] = (weeks[week] ?? 0) + e.durationMinutes;
    }
    return weeks;
  }
}

/// Lee las muestras de microgravedad del bundle local (offline).
class MicrogravitySampleRepository {
  MicrogravitySampleRepository({AssetBundle? assetBundle})
      : _bundle = assetBundle ?? rootBundle;
  final AssetBundle _bundle;

  static String assetPath(String file, SampleScenario scenario) =>
      'DB/samples/microgravity/${file}_${scenario.fileSuffix}.csv';

  Future<MicrogravitySample> load(SampleScenario scenario) async {
    final csv = await Future.wait([
      _bundle.loadString(assetPath('bone_density', scenario)),
      _bundle.loadString(assetPath('muscle_volume', scenario)),
      _bundle.loadString(assetPath('exercise_sessions', scenario)),
    ]);
    return MicrogravitySample(
      bone: parseBone(csv[0]),
      muscle: parseMuscle(csv[1]),
      exercise: parseExercise(csv[2]),
    );
  }

  static List<BoneDensityPoint> parseBone(String csv) => [
        for (final r in parseSampleCsv(csv, columns: const {
          'mission_day',
          'astronaut_id',
          'site',
          'bmd_g_cm2',
          'change_from_baseline_pct',
          'measurement_type',
        }))
          BoneDensityPoint(
            missionDay: r.integer('mission_day'),
            astronautId: r.text('astronaut_id'),
            site: r.text('site'),
            bmdGCm2: r.number('bmd_g_cm2'),
            changePct: r.number('change_from_baseline_pct'),
            measurementType: r.text('measurement_type'),
          ),
      ];

  static List<MuscleVolumePoint> parseMuscle(String csv) => [
        for (final r in parseSampleCsv(csv, columns: const {
          'mission_day',
          'astronaut_id',
          'region',
          'volume_change_pct',
        }))
          MuscleVolumePoint(
            missionDay: r.integer('mission_day'),
            astronautId: r.text('astronaut_id'),
            region: r.text('region'),
            changePct: r.number('volume_change_pct'),
          ),
      ];

  static List<ExerciseSamplePoint> parseExercise(String csv) => [
        for (final r in parseSampleCsv(csv, columns: const {
          'mission_day',
          'astronaut_id',
          'device_name',
          'duration_minutes',
          'target_minutes',
          'event',
        }))
          ExerciseSamplePoint(
            missionDay: r.integer('mission_day'),
            astronautId: r.text('astronaut_id'),
            deviceName: r.text('device_name'),
            durationMinutes: r.integer('duration_minutes'),
            targetMinutes: r.integer('target_minutes'),
            event: r.text('event'),
          ),
      ];
}

/// Muestra de microgravedad del escenario elegido.
final microgravitySampleProvider = FutureProvider<MicrogravitySample>((ref) {
  return MicrogravitySampleRepository(
    assetBundle: ref.watch(sampleAssetBundleProvider),
  ).load(ref.watch(sampleScenarioProvider));
});
