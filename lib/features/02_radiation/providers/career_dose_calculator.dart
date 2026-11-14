/// NASA career effective-dose reference limit, in mSv.
const double careerDoseLimitMsv = 600.0;

/// Accumulated effective-dose summary for a crewmember.
class CareerDoseSummary {
  const CareerDoseSummary({
    required this.totalMsv,
    required this.remainingMsv,
    required this.limitReached,
  });

  /// Previous career dose plus mission dose through the requested day.
  final double totalMsv;

  /// Remaining budget, clamped to zero after reaching the limit.
  final double remainingMsv;

  /// The NASA requirement is strictly less than 600 mSv.
  final bool limitReached;
}

/// Calculates the career budget from previous dose and daily mission doses.
/// Each daily effective dose must already include any SPE contribution.
CareerDoseSummary calculateCareerDose({
  required double priorCareerDoseMsv,
  required Iterable<double> dailyDosesMsv,
}) {
  if (!priorCareerDoseMsv.isFinite || priorCareerDoseMsv < 0) {
    throw ArgumentError.value(
      priorCareerDoseMsv,
      'priorCareerDoseMsv',
      'Must be a finite, non-negative number.',
    );
  }

  var total = priorCareerDoseMsv;
  for (final dose in dailyDosesMsv) {
    if (!dose.isFinite || dose < 0) {
      throw ArgumentError.value(
        dose,
        'dailyDosesMsv',
        'Each daily dose must be finite and non-negative.',
      );
    }
    total += dose;
    if (!total.isFinite) {
      throw ArgumentError('Accumulated dose exceeds the valid numeric range.');
    }
  }

  final limitReached = total >= careerDoseLimitMsv;
  return CareerDoseSummary(
    totalMsv: total,
    remainingMsv: limitReached ? 0.0 : careerDoseLimitMsv - total,
    limitReached: limitReached,
  );
}
