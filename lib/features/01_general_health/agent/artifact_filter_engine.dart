import 'package:astramed/core/constants/medical_thresholds.dart';
import 'package:astramed/features/01_general_health/models/vitals_record.dart';
import 'package:astramed/features/03_microgravity/models/microgravity_data.dart';

/// Classification produced by crossing biometric alarms with accelerometry
/// and optical signal quality.
enum ArtifactClassification {
  nominal('nominal'),
  kineticMotionArtifact('kinetic_motion_artifact'),
  physiologicalExerciseResponse('physiological_exercise_response'),
  trueClinicalAlert('true_clinical_alert');

  const ArtifactClassification(this.wireName);

  final String wireName;
}

class ArtifactFilterResult {
  const ArtifactFilterResult({
    required this.classification,
    required this.suppressAlarm,
    required this.recommendedAction,
    required this.reasons,
    required this.metricsSnapshot,
  });

  final ArtifactClassification classification;
  final bool suppressAlarm;
  final String recommendedAction;
  final List<String> reasons;
  final Map<String, dynamic> metricsSnapshot;

  Map<String, dynamic> toJson() => {
        'classification': classification.wireName,
        'suppress_alarm': suppressAlarm,
        'recommended_action': recommendedAction,
        'reasons': reasons,
        'metrics': metricsSnapshot,
      };
}

/// Deterministic biometric artifact filter crossing SpO2/HR alarms against
/// triaxial accelerometry (`accelerationRmsG`), exercise state, and optical
/// signal quality.
class ArtifactFilterEngine {
  const ArtifactFilterEngine();

  /// Minimum triaxial RMS acceleration (g) indicating high kinetic motion.
  static const double highMotionRmsThresholdG = 0.35;

  /// Hard lower SpO2 bound below which true hypoxia is never suppressed.
  static const double severeHypoxiaFloorSpO2 = 88.0;

  /// Upper physiological heart rate bound for workload-proportional exercise.
  static const double maxExercisePhysiologicalHr = 165.0;

  /// Optical signal percentage below which PPG/pulse-ox readings are degraded.
  static const double goodSignalMinPercent = 75.0;

  /// Motion artifact index (0..1) above which optical signal is considered noisy.
  static const double highMotionArtifactIndex = 0.5;

  /// Respiratory rate threshold indicating true tachypnea (>= 26 rpm).
  static const double severeTachypneaThresholdRpm = 26.0;

  /// Upper normal respiratory rate bound for dismissing motion artifacts.
  static const double normalRespiratoryUpperRpm = 24.0;

  /// Capillary refill threshold indicating impaired peripheral perfusion.
  static const double prolongedCapillaryRefillSeconds = 2.5;

  ArtifactFilterResult classify({
    required VitalsRecord vitals,
    double accelerationRmsG = 0.0,
    double? motionArtifactIndex,
    String? activityStateOverride,
    String? signalQualityOverride,
    ExerciseSession? exercise,
  }) {
    final activityState =
        (activityStateOverride ?? vitals.activityState).trim().toLowerCase();
    final signalQuality =
        (signalQualityOverride ?? vitals.signalQuality).trim();

    final isExerciseState = activityState == 'exercise' ||
        (exercise != null &&
            exercise.activityState.trim().toLowerCase() == 'exercise' &&
            activityState != 'resting' &&
            activityState != 'sleep');
    final isHighMotion = accelerationRmsG >= highMotionRmsThresholdG;
    final isActiveMotionOrExercise = isHighMotion || isExerciseState;

    final signalEval = _evaluateSignalQuality(
      signalQuality: signalQuality,
      motionArtifactIndex: motionArtifactIndex,
    );

    final spO2 = vitals.spO2;
    final hr = vitals.heartRate;
    final sbp = vitals.systolicBP;
    final rr = vitals.respiratoryRate;
    final capRefill = vitals.capillaryRefillSeconds;

    final isHypotensive = sbp < MedicalThresholds.minSystolicBP;
    final isSevereTachypnea = rr >= severeTachypneaThresholdRpm;
    final isRespiratoryElevated = rr >= normalRespiratoryUpperRpm;
    final isPoorPerfusion = capRefill > prolongedCapillaryRefillSeconds;

    final hasClinicalCompromise =
        isHypotensive || isSevereTachypnea || isPoorPerfusion;

    final snapshot = <String, dynamic>{
      'spo2_percent': spO2,
      'heart_rate_bpm': hr,
      'systolic_bp_mmhg': sbp,
      'respiratory_rate_rpm': rr,
      'capillary_refill_s': capRefill,
      'acceleration_rms_g': accelerationRmsG,
      'motion_artifact_index': ?motionArtifactIndex,
      'activity_state': activityState,
      'signal_quality': signalQuality,
      'signal_degraded': signalEval.isDegraded,
    };

    final hasLowSpO2 = spO2 < MedicalThresholds.minSpO2;
    final hasElevatedHr = hr > MedicalThresholds.maxHeartRate;

    // 1. Absolute clinical safety overrides.
    if (spO2 < severeHypoxiaFloorSpO2) {
      return ArtifactFilterResult(
        classification: ArtifactClassification.trueClinicalAlert,
        suppressAlarm: false,
        recommendedAction:
            'Severe hypoxia (SpO2 < 88%): initiate O2 emergency protocol immediately.',
        reasons: [
          'SpO2 ${spO2.toStringAsFixed(1)}% is below the $severeHypoxiaFloorSpO2% severe hypoxia floor.',
        ],
        metricsSnapshot: snapshot,
      );
    }

    if (hasClinicalCompromise && (hasLowSpO2 || hasElevatedHr)) {
      final compromiseReasons = <String>[
        if (isHypotensive)
          'Hypotension detected (SBP ${sbp.toStringAsFixed(0)} mmHg < ${MedicalThresholds.minSystolicBP.toStringAsFixed(0)}).',
        if (isSevereTachypnea)
          'Tachypnea detected (RR ${rr.toStringAsFixed(0)} rpm >= 26).',
        if (isPoorPerfusion)
          'Prolonged capillary refill (${capRefill.toStringAsFixed(1)} s > $prolongedCapillaryRefillSeconds s).',
      ];
      return ArtifactFilterResult(
        classification: ArtifactClassification.trueClinicalAlert,
        suppressAlarm: false,
        recommendedAction:
            'True clinical alert preserved — perform immediate clinical evaluation.',
        reasons: compromiseReasons,
        metricsSnapshot: snapshot,
      );
    }

    // 2. Apparent hypoxia (88% <= SpO2 < 94%).
    if (hasLowSpO2) {
      final canDismissAsMotionArtifact = isActiveMotionOrExercise &&
          signalEval.isDegraded &&
          !isRespiratoryElevated &&
          !isHypotensive &&
          !isPoorPerfusion;

      if (canDismissAsMotionArtifact) {
        return ArtifactFilterResult(
          classification: ArtifactClassification.kineticMotionArtifact,
          suppressAlarm: true,
          recommendedAction:
              'Hold hand still for 30 s and recheck pulse oximetry to confirm SpO2.',
          reasons: [
            'Transient SpO2 dip (${spO2.toStringAsFixed(1)}%) coincides with kinetic motion (${accelerationRmsG.toStringAsFixed(2)} g, $activityState) and degraded optical signal ($signalQuality).',
            'Respiratory rate (${rr.toStringAsFixed(0)} rpm), blood pressure (${sbp.toStringAsFixed(0)} mmHg), and capillary refill (${capRefill.toStringAsFixed(1)} s) remain normal.',
          ],
          metricsSnapshot: snapshot,
        );
      }

      final trueReasons = <String>[
        if (!isActiveMotionOrExercise)
          'Desaturation occurred at rest / low motion (${accelerationRmsG.toStringAsFixed(2)} g, $activityState).',
        if (!signalEval.isDegraded)
          'Optical signal quality is good ($signalQuality).',
        if (isRespiratoryElevated)
          'Respiratory rate is elevated (${rr.toStringAsFixed(0)} rpm >= 24).',
      ];
      return ArtifactFilterResult(
        classification: ArtifactClassification.trueClinicalAlert,
        suppressAlarm: false,
        recommendedAction:
            'True clinical alert preserved — verify airway, cabin O2, and recheck SpO2.',
        reasons: trueReasons,
        metricsSnapshot: snapshot,
      );
    }

    // 3. Elevated heart rate with normal SpO2 and normal hemodynamics.
    if (hasElevatedHr) {
      final isProportionalExerciseHr = isActiveMotionOrExercise &&
          hr <= maxExercisePhysiologicalHr &&
          spO2 >= MedicalThresholds.minSpO2 &&
          !isHypotensive &&
          !isSevereTachypnea &&
          !isPoorPerfusion;

      if (isProportionalExerciseHr) {
        return ArtifactFilterResult(
          classification: ArtifactClassification.physiologicalExerciseResponse,
          suppressAlarm: true,
          recommendedAction:
              'Expected exercise heart rate response; continue workload monitoring and verify recovery post-session.',
          reasons: [
            'HR ${hr.toStringAsFixed(0)} bpm is within workload ceiling (<= ${maxExercisePhysiologicalHr.toStringAsFixed(0)} bpm) during $activityState.',
            'SpO2 (${spO2.toStringAsFixed(1)}%), SBP (${sbp.toStringAsFixed(0)} mmHg), and perfusion (${capRefill.toStringAsFixed(1)} s) are normal.',
          ],
          metricsSnapshot: snapshot,
        );
      }

      return ArtifactFilterResult(
        classification: ArtifactClassification.trueClinicalAlert,
        suppressAlarm: false,
        recommendedAction:
            'Unexplained tachycardia preserved — evaluate hydration, fever, or cardiac strain.',
        reasons: [
          if (hr > maxExercisePhysiologicalHr)
            'Heart rate ${hr.toStringAsFixed(0)} bpm exceeds exercise ceiling (${maxExercisePhysiologicalHr.toStringAsFixed(0)} bpm).',
          if (!isActiveMotionOrExercise)
            'Elevated resting heart rate (${hr.toStringAsFixed(0)} bpm) during $activityState.',
        ],
        metricsSnapshot: snapshot,
      );
    }

    // 4. Other critical vitals even if SpO2 and HR are in range.
    if (hasClinicalCompromise) {
      return ArtifactFilterResult(
        classification: ArtifactClassification.trueClinicalAlert,
        suppressAlarm: false,
        recommendedAction:
            'Abnormal hemodynamic or respiratory marker detected — evaluate immediately.',
        reasons: [
          if (isHypotensive)
            'Hypotension (SBP ${sbp.toStringAsFixed(0)} mmHg).',
          if (isSevereTachypnea)
            'Tachypnea (RR ${rr.toStringAsFixed(0)} rpm).',
          if (isPoorPerfusion)
            'Prolonged capillary refill (${capRefill.toStringAsFixed(1)} s).',
        ],
        metricsSnapshot: snapshot,
      );
    }

    return ArtifactFilterResult(
      classification: ArtifactClassification.nominal,
      suppressAlarm: false,
      recommendedAction: 'No biometric alarm requires artifact filtering.',
      reasons: const ['SpO2 and heart rate are within nominal bounds.'],
      metricsSnapshot: snapshot,
    );
  }

  _SignalEvaluation _evaluateSignalQuality({
    required String signalQuality,
    double? motionArtifactIndex,
  }) {
    final lower = signalQuality.toLowerCase();
    final percentMatch = RegExp(r'(\d+(?:\.\d+)?)\s*%').firstMatch(lower);
    final percent =
        percentMatch != null ? double.tryParse(percentMatch.group(1)!) : null;

    if (lower.contains('manual_verified')) {
      return const _SignalEvaluation(isDegraded: false);
    }
    if (lower.contains('degraded') ||
        lower.contains('poor') ||
        lower.contains('low') ||
        lower.contains('noisy') ||
        lower.contains('artifact')) {
      return const _SignalEvaluation(isDegraded: true);
    }
    if (percent != null) {
      return _SignalEvaluation(isDegraded: percent < goodSignalMinPercent);
    }
    if (lower.contains('optimal') || lower.contains('good')) {
      // Only treat as degraded if an explicit high motion artifact index is supplied
      // without a degraded label? No — spec requires good signal quality to preserve true alerts.
      return const _SignalEvaluation(isDegraded: false);
    }
    if (motionArtifactIndex != null &&
        motionArtifactIndex >= highMotionArtifactIndex) {
      return const _SignalEvaluation(isDegraded: true);
    }
    return const _SignalEvaluation(isDegraded: false);
  }
}

class _SignalEvaluation {
  const _SignalEvaluation({required this.isDegraded});

  final bool isDegraded;
}
