import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/sample_data.dart';

/// Una noche de sueño de `DB/samples/sleep/`.
class SleepSampleNight {
  const SleepSampleNight({
    required this.missionDay,
    required this.phase,
    required this.astronautId,
    required this.sleepHours,
    required this.wakeEpisodes,
    required this.morningMood,
    required this.sleepMedication,
    required this.preEvaNight,
    required this.event,
  });

  final int missionDay;
  final String phase; // preflight | inflight | postflight
  final String astronautId;
  final double sleepHours;
  final int wakeEpisodes;
  final String morningMood;
  final bool sleepMedication;
  final bool preEvaNight;
  final String event;
}

/// Lee las muestras de sueño del bundle local (offline).
class SleepSampleRepository {
  SleepSampleRepository({AssetBundle? assetBundle})
      : _bundle = assetBundle ?? rootBundle;
  final AssetBundle _bundle;

  static String assetPath(SampleScenario scenario) =>
      'DB/samples/sleep/sleep_nightly_${scenario.fileSuffix}.csv';

  Future<List<SleepSampleNight>> load(SampleScenario scenario) async =>
      parse(await _bundle.loadString(assetPath(scenario)));

  static List<SleepSampleNight> parse(String csv) {
    final rows = parseSampleCsv(csv, columns: const {
      'mission_day',
      'phase',
      'astronaut_id',
      'sleep_hours',
      'wake_episodes',
      'morning_mood',
      'sleep_medication',
      'pre_eva_night',
      'event',
    });
    return [
      for (final r in rows)
        SleepSampleNight(
          missionDay: r.integer('mission_day'),
          phase: r.text('phase'),
          astronautId: r.text('astronaut_id'),
          sleepHours: r.number('sleep_hours'),
          wakeEpisodes: r.integer('wake_episodes'),
          morningMood: r.text('morning_mood'),
          sleepMedication: r.flag('sleep_medication'),
          preEvaNight: r.flag('pre_eva_night'),
          event: r.text('event'),
        ),
    ];
  }
}

/// Muestra de sueño del escenario elegido.
final sleepSampleProvider = FutureProvider<List<SleepSampleNight>>((ref) {
  return SleepSampleRepository(
    assetBundle: ref.watch(sampleAssetBundleProvider),
  ).load(ref.watch(sampleScenarioProvider));
});
