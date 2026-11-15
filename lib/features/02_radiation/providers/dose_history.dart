import '../models/daily_radiation_record.dart';
import 'career_dose_calculator.dart';

class DoseHistoryPoint {
  const DoseHistoryPoint(this.missionDay, this.careerDoseMsv);

  final int missionDay;
  final double careerDoseMsv;
}

/// Day zero is the prior career dose. Future records and other crew are excluded.
List<DoseHistoryPoint> calculateDoseHistory({
  required String astronautId,
  required int missionDay,
  required double priorCareerDoseMsv,
  required Iterable<DailyRadiationRecord> records,
}) {
  if (astronautId.trim().isEmpty || missionDay < 1) {
    throw ArgumentError('A crew ID and a positive mission day are required.');
  }
  var total = calculateCareerDose(
    priorCareerDoseMsv: priorCareerDoseMsv,
    dailyDosesMsv: const [],
  ).totalMsv;
  final selected =
      records
          .where(
            (record) =>
                record.astronautId == astronautId &&
                record.missionDay <= missionDay,
          )
          .toList()
        ..sort((a, b) => a.missionDay.compareTo(b.missionDay));
  final points = <DoseHistoryPoint>[DoseHistoryPoint(0, total)];
  var previousDay = 0;
  for (final record in selected) {
    if (record.missionDay <= previousDay) {
      throw ArgumentError('Invalid or duplicate mission day in dose history.');
    }
    total = calculateCareerDose(
      priorCareerDoseMsv: total,
      dailyDosesMsv: [record.effectiveDoseMsv],
    ).totalMsv;
    points.add(DoseHistoryPoint(record.missionDay, total));
    previousDay = record.missionDay;
  }
  if (previousDay != missionDay) {
    throw ArgumentError('No dose record found for the selected day.');
  }
  return List.unmodifiable(points);
}
