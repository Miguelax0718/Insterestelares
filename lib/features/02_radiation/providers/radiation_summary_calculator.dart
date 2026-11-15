import '../models/daily_radiation_record.dart';
import '../models/radiation_organ.dart';
import '../models/space_weather_reading.dart';
import 'career_dose_calculator.dart';
import 'organ_dose_calculator.dart';
import 'spe_detector.dart';

/// Combined physical-dose summary for one crewmember on one mission day.
class RadiationDailySummary {
  const RadiationDailySummary({
    required this.astronautId,
    required this.missionDay,
    required this.careerEffectiveDoseMsv,
    required this.remainingCareerDoseMsv,
    required this.careerLimitReached,
    required this.organDoseUse,
    required this.speStatus,
    required this.speEventDoseMsv,
  });

  final String astronautId;
  final int missionDay;
  final double careerEffectiveDoseMsv;
  final double remainingCareerDoseMsv;
  final bool careerLimitReached;
  final Map<RadiationOrgan, OrganDoseUse> organDoseUse;
  final SpeStatus speStatus;

  /// SPE contribution for this day; already included in the effective dose.
  final double speEventDoseMsv;
}

/// Builds a daily summary by combining parsed mission and space-weather data.
///
/// The career total includes the profile's prior effective dose and mission
/// doses through [missionDay]. Prior organ-specific doses are not available, so
/// organ career-limit use reflects this mission only.
RadiationDailySummary calculateRadiationDailySummary({
  required String astronautId,
  required int missionDay,
  required double priorCareerDoseMsv,
  required Iterable<DailyRadiationRecord> dosimetry,
  required Iterable<SpaceWeatherReading> spaceWeather,
}) {
  if (astronautId.trim().isEmpty) {
    throw ArgumentError.value(astronautId, 'astronautId', 'Must not be empty.');
  }
  if (missionDay < 1) {
    throw ArgumentError.value(missionDay, 'missionDay', 'Must be at least 1.');
  }

  final crewRecords = dosimetry
      .where((record) =>
          record.astronautId == astronautId && record.missionDay <= missionDay)
      .toList(growable: false);
  final currentDayRecords = crewRecords
      .where((record) => record.missionDay == missionDay)
      .toList(growable: false);

  if (currentDayRecords.isEmpty) {
    throw ArgumentError('No dosimetry record found for $astronautId on day $missionDay.');
  }
  if (currentDayRecords.length > 1) {
    throw ArgumentError('Multiple dosimetry records found for $astronautId on day $missionDay.');
  }

  final careerDose = calculateCareerDose(
    priorCareerDoseMsv: priorCareerDoseMsv,
    dailyDosesMsv: crewRecords.map((record) => record.effectiveDoseMsv),
  );
  final organUse = calculateOrganDoseUse(
    astronautId: astronautId,
    asOfMissionDay: missionDay,
    dailyDoses: crewRecords,
  );
  final speStatus = speStatusForDay(
    readings: spaceWeather,
    missionDay: missionDay,
  );
  final currentDay = currentDayRecords.single;

  return RadiationDailySummary(
    astronautId: astronautId,
    missionDay: missionDay,
    careerEffectiveDoseMsv: careerDose.totalMsv,
    remainingCareerDoseMsv: careerDose.remainingMsv,
    careerLimitReached: careerDose.limitReached,
    organDoseUse: organUse,
    speStatus: speStatus,
    speEventDoseMsv: currentDay.speEventDoseMsv,
  );
}
