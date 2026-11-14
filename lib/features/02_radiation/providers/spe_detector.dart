/// Availability-aware result for the SPE feed on a mission day.
enum SpeStatus {
  active,
  inactive,
  unknown,
}

/// Space-weather feed record for one mission day.
class SpaceWeatherReading {
  const SpaceWeatherReading({
    required this.missionDay,
    required this.protonFluxPfu,
    required this.alertLevel,
    required this.eventSpe,
  });

  final int missionDay;
  final double protonFluxPfu;
  final String alertLevel;
  final bool eventSpe;
}

/// Returns the SPE feed status for [missionDay].
///
/// Missing feed data is reported as unknown rather than as no event.
/// The explicit `eventSpe` flag is used; proton flux alone does not classify
/// an SPE in this prototype.
SpeStatus speStatusForDay({
  required Iterable<SpaceWeatherReading> readings,
  required int missionDay,
}) {
  if (missionDay < 1) {
    throw ArgumentError.value(missionDay, 'missionDay', 'Must be at least 1.');
  }

  final dayReadings = readings
      .where((reading) => reading.missionDay == missionDay)
      .toList();

  if (dayReadings.isEmpty) {
    return SpeStatus.unknown;
  }
  if (dayReadings.length > 1) {
    throw ArgumentError('Multiple space-weather readings found for mission day $missionDay.');
  }

  return dayReadings.single.eventSpe ? SpeStatus.active : SpeStatus.inactive;
}
