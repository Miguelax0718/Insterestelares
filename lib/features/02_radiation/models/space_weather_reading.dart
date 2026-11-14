/// Parsed space-weather feed record for one mission day.
class SpaceWeatherReading {
  const SpaceWeatherReading({
    required this.missionDay,
    required this.protonFluxPfu,
    required this.alertLevel,
    required this.eventSpe,
    required this.dataType,
  });

  final int missionDay;
  final double protonFluxPfu;
  final String alertLevel;
  final bool eventSpe;
  final String dataType;
}
