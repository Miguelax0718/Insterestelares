import '../radiation_organ.dart';
import '../../providers/radiation_summary_calculator.dart';
import '../../providers/spe_detector.dart';

/// Physical-layer contract using the same crew ID and date as BioSummary.
class DoseSummary {
  DoseSummary.fromDaily(RadiationDailySummary daily, {required this.date})
    : astronautId = daily.astronautId,
      organLimitUse = Map.unmodifiable(
        daily.organDoseUse.map(
          (organ, use) => MapEntry(organ, use.highestFractionUsed),
        ),
      ),
      careerEffectiveDoseMsv = daily.careerEffectiveDoseMsv,
      remainingCareerDoseMsv = daily.remainingCareerDoseMsv,
      speStatus = daily.speStatus;

  final String astronautId;
  final DateTime date;
  final Map<RadiationOrgan, double> organLimitUse;
  final double careerEffectiveDoseMsv;
  final double remainingCareerDoseMsv;
  final SpeStatus speStatus;
}
