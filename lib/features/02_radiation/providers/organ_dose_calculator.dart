/// Organs represented in the current daily-dosimetry dataset.
enum RadiationOrgan {
  lens,
  skin,
  bloodFormingOrgans,
  circulatorySystem,
  centralNervousSystem,
}

/// Time windows used to compare dose with NASA organ-dose limits.
enum DoseWindow {
  last30Days,
  last365Days,
  thisMissionAgainstCareerLimit,
}

/// One crewmember's organ doses for a single mission day.
///
/// Values are mGy-Eq except centralNervousSystem, which is in mGy.
class DailyOrganDose {
  const DailyOrganDose({
    required this.astronautId,
    required this.missionDay,
    required this.dosesByOrgan,
  });

  final String astronautId;
  final int missionDay;
  final Map<RadiationOrgan, double> dosesByOrgan;
}

/// Dose and applicable limit for one organ and one time window.
class DoseWindowUse {
  const DoseWindowUse({
    required this.measuredDose,
    required this.limitDose,
  });

  final double measuredDose;
  final double limitDose;

  /// Fraction of the limit used. Values above 1.0 mean the limit was exceeded.
  double get fractionUsed => measuredDose / limitDose;
}

/// Window comparisons for one organ.
class OrganDoseUse {
  const OrganDoseUse({
    required this.organ,
    required this.windows,
  });

  final RadiationOrgan organ;
  final Map<DoseWindow, DoseWindowUse> windows;

  /// The largest available fraction across this organ's applicable windows.
  double get highestFractionUsed =>
      windows.values.map((window) => window.fractionUsed).reduce(
            (current, next) => current > next ? current : next,
          );
}

/// NASA non-cancer dose limits from NASA-STD-3001 Vol. 1 Rev. C, Table 4.8-1.
const Map<RadiationOrgan, _OrganDoseLimits> _organDoseLimits = {
  RadiationOrgan.lens: _OrganDoseLimits(1000, 2000, 4000),
  RadiationOrgan.skin: _OrganDoseLimits(1500, 3000, 6000),
  RadiationOrgan.bloodFormingOrgans: _OrganDoseLimits(250, 500, null),
  RadiationOrgan.circulatorySystem: _OrganDoseLimits(250, 500, 1000),
  RadiationOrgan.centralNervousSystem: _OrganDoseLimits(500, 1000, 1500),
};

/// Calculates organ-limit use through [asOfMissionDay] for one crewmember.
///
/// The mission-total dose is compared with the career organ limit, but it does
/// not include prior missions because the current crew profile has no prior
/// organ-specific dose history. The CNS heavy-ion limit is omitted because the
/// input dataset does not identify heavy-ion dose separately.
Map<RadiationOrgan, OrganDoseUse> calculateOrganDoseUse({
  required String astronautId,
  required int asOfMissionDay,
  required Iterable<DailyOrganDose> dailyDoses,
}) {
  if (astronautId.trim().isEmpty) {
    throw ArgumentError.value(astronautId, 'astronautId', 'Must not be empty.');
  }
  if (asOfMissionDay < 1) {
    throw ArgumentError.value(asOfMissionDay, 'asOfMissionDay', 'Must be at least 1.');
  }

  final crewDoses = dailyDoses
      .where((record) =>
          record.astronautId == astronautId &&
          record.missionDay <= asOfMissionDay)
      .toList()
    ..sort((left, right) => left.missionDay.compareTo(right.missionDay));

  if (crewDoses.isEmpty) {
    throw ArgumentError('No dose records found for $astronautId through day $asOfMissionDay.');
  }

  final seenDays = <int>{};
  for (final record in crewDoses) {
    if (record.missionDay < 1 || !seenDays.add(record.missionDay)) {
      throw ArgumentError('Invalid or duplicate mission day ${record.missionDay} for $astronautId.');
    }
    for (final organ in RadiationOrgan.values) {
      final dose = record.dosesByOrgan[organ];
      if (dose == null || !dose.isFinite || dose < 0) {
        throw ArgumentError('Missing or invalid $organ dose on mission day ${record.missionDay}.');
      }
    }
  }

  final result = <RadiationOrgan, OrganDoseUse>{};
  for (final entry in _organDoseLimits.entries) {
    final organ = entry.key;
    final limits = entry.value;
    final organWindows = <DoseWindow, DoseWindowUse>{
      DoseWindow.last30Days: DoseWindowUse(
        measuredDose: _sumDose(
          crewDoses,
          organ,
          firstDayExclusive: asOfMissionDay - 30,
        ),
        limitDose: limits.last30Days,
      ),
      DoseWindow.last365Days: DoseWindowUse(
        measuredDose: _sumDose(
          crewDoses,
          organ,
          firstDayExclusive: asOfMissionDay - 365,
        ),
        limitDose: limits.last365Days,
      ),
    };

    final careerLimit = limits.career;
    if (careerLimit != null) {
      organWindows[DoseWindow.thisMissionAgainstCareerLimit] = DoseWindowUse(
        measuredDose: _sumDose(crewDoses, organ),
        limitDose: careerLimit,
      );
    }

    result[organ] = OrganDoseUse(organ: organ, windows: organWindows);
  }
  return result;
}

double _sumDose(
  List<DailyOrganDose> records,
  RadiationOrgan organ, {
  int? firstDayExclusive,
}) {
  var total = 0.0;
  for (final record in records) {
    if (firstDayExclusive == null || record.missionDay > firstDayExclusive) {
      total += record.dosesByOrgan[organ]!;
    }
  }
  return total;
}

class _OrganDoseLimits {
  const _OrganDoseLimits(this.last30Days, this.last365Days, this.career);

  final double last30Days;
  final double last365Days;
  final double? career;
}

