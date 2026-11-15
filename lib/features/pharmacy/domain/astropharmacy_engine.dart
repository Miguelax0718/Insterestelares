import 'dart:math' as math;

import 'medication_batch.dart';

class BatchRadiationAssessment {
  const BatchRadiationAssessment({
    required this.batch,
    required this.deltaPct,
    required this.projectedDegradationPct,
    required this.compromised,
  });

  final MedicationBatch batch;
  final double deltaPct;
  final double projectedDegradationPct;
  final bool compromised;

  Map<String, dynamic> toJson() => {
    'batch_id': batch.batchId,
    'medication': batch.medication,
    'route': batch.route,
    'storage_location': batch.storageLocation,
    'units_remaining': batch.unitsRemaining,
    'degradation_pct': double.parse(projectedDegradationPct.toStringAsFixed(2)),
    'delta_pct': double.parse(deltaPct.toStringAsFixed(2)),
    'flagged': batch.flagged,
    'compromised': compromised,
  };
}

class AstropharmacyAssessment {
  const AstropharmacyAssessment({
    required this.eventClass,
    required this.sepFluxPfu,
    required this.durationHours,
    required this.doseEquivalentMsv,
    required this.batchAssessments,
    required this.compromisedBatches,
    required this.ramanVerificationRequired,
    required this.leukocyteCheckTimes,
    required this.summary,
  });

  final String eventClass;
  final double sepFluxPfu;
  final double durationHours;
  final double doseEquivalentMsv;
  final List<BatchRadiationAssessment> batchAssessments;
  final List<MedicationBatch> compromisedBatches;
  final bool ramanVerificationRequired;
  final List<DateTime> leukocyteCheckTimes;
  final String summary;
}

class AstropharmacyEngine {
  const AstropharmacyEngine();

  /// Calibration constants (D6): isolated named constants for clinical review.
  static const double baseFactor = 0.50;
  static const double degradationThresholdPct =
      MedicationBatch.degradationThresholdPct;
  static const double ramanDoseThresholdMsv = 25.0;
  static const List<int> postStormLeukocyteHours = [24, 72];

  double computeDoseEquivalentMsv({
    required double sepFluxPfu,
    required double durationHours,
    required String eventClass,
  }) {
    if (sepFluxPfu <= 0 || durationHours <= 0) {
      return 0.0;
    }
    final normalizedClass = eventClass.trim().toUpperCase();
    final double classMultiplier;
    if (normalizedClass.startsWith('X')) {
      classMultiplier = 1.5;
    } else if (normalizedClass.startsWith('M')) {
      classMultiplier = 1.15;
    } else {
      classMultiplier = 1.0;
    }
    final logFlux = math.log(1.0 + sepFluxPfu / 10.0) / math.ln10;
    return logFlux * (durationHours / 12.0) * classMultiplier * 10.0;
  }

  AstropharmacyAssessment assessStorm({
    required List<MedicationBatch> batches,
    required double sepFluxPfu,
    required double durationHours,
    required String eventClass,
    DateTime? peakTime,
  }) {
    final peak = (peakTime ?? DateTime.now()).toUtc();
    final doseEquivalent = computeDoseEquivalentMsv(
      sepFluxPfu: sepFluxPfu,
      durationHours: durationHours,
      eventClass: eventClass,
    );

    final assessments = <BatchRadiationAssessment>[];
    final compromised = <MedicationBatch>[];

    for (final batch in batches) {
      final deltaPct =
          baseFactor *
          batch.radiationSensitivity *
          (1.0 - batch.shieldingFactor) *
          doseEquivalent;
      final projected = (batch.degradationPct + deltaPct).clamp(0.0, 100.0);
      final isCompromised =
          batch.flagged || projected >= degradationThresholdPct;

      assessments.add(
        BatchRadiationAssessment(
          batch: batch,
          deltaPct: deltaPct,
          projectedDegradationPct: projected,
          compromised: isCompromised,
        ),
      );
      if (isCompromised) {
        compromised.add(batch);
      }
    }

    final ramanRequired =
        compromised.isNotEmpty || doseEquivalent >= ramanDoseThresholdMsv;
    final leukocyteTimes = postStormLeukocyteHours
        .map((h) => peak.add(Duration(hours: h)))
        .toList(growable: false);

    final summary = compromised.isEmpty
        ? 'All ${batches.length} pharmacy batches remain within safe degradation limits (<15%) for $eventClass (${doseEquivalent.toStringAsFixed(1)} mSv).'
        : '${compromised.length} of ${batches.length} pharmacy batches projected >=15% degradation during $eventClass (${doseEquivalent.toStringAsFixed(1)} mSv); Raman verification required.';

    return AstropharmacyAssessment(
      eventClass: eventClass,
      sepFluxPfu: sepFluxPfu,
      durationHours: durationHours,
      doseEquivalentMsv: doseEquivalent,
      batchAssessments: List.unmodifiable(assessments),
      compromisedBatches: List.unmodifiable(compromised),
      ramanVerificationRequired: ramanRequired,
      leukocyteCheckTimes: List.unmodifiable(leukocyteTimes),
      summary: summary,
    );
  }
}
