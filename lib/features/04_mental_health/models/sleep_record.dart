enum MoodLevel { great, good, neutral, fatigued, stressed }

class SleepRecord {
  final DateTime date;
  final double sleepHours;
  final int wakeEpisodes;
  final MoodLevel morningMood;

  const SleepRecord({
    required this.date,
    required this.sleepHours,
    required this.wakeEpisodes,
    required this.morningMood,
  });
}
