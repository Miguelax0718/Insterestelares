import 'radiation_organ.dart';

/// Parsed radiation dose record for one crewmember and one mission day.
class DailyRadiationRecord {
  const DailyRadiationRecord({
    required this.astronautId,
    required this.missionDay,
    required this.module,
    required this.effectiveDoseMsv,
    required this.organDoses,
    required this.speEventDoseMsv,
    required this.dataType,
  });

  final String astronautId;
  final int missionDay;
  final String module;

  /// Daily effective dose in mSv, including any SPE contribution.
  final double effectiveDoseMsv;

  /// Organ doses in mGy-Eq, except centralNervousSystem, which is in mGy.
  final Map<RadiationOrgan, double> organDoses;

  /// SPE contribution in mSv; do not add this again to effectiveDoseMsv.
  final double speEventDoseMsv;
  final String dataType;
}
