import 'package:astramed/core/constants/medical_thresholds.dart';
import 'package:astramed/features/02_radiation/models/radiation_dose.dart';
import 'package:astramed/features/04_mental_health/models/sleep_record.dart';
import 'package:astramed/features/crew/models/astronaut_profile.dart';

enum CorrelationRiskLevel {
  nominal('nominal'),
  elevated('elevated'),
  high('high');

  const CorrelationRiskLevel(this.wireName);

  final String wireName;
}

class RenalStoneRiskAssessment {
  const RenalStoneRiskAssessment({
    required this.riskLevel,
    required this.contributingFactors,
    required this.hydrationTargetMl,
    required this.recommendRenalUltrasound,
    required this.recommendPotassiumCitrate,
    required this.summary,
  });

  final CorrelationRiskLevel riskLevel;
  final List<String> contributingFactors;
  final int hydrationTargetMl;
  final bool recommendRenalUltrasound;
  final bool recommendPotassiumCitrate;
  final String summary;

  Map<String, dynamic> toJson() => {
        'risk_level': riskLevel.wireName,
        'contributing_factors': contributingFactors,
        'hydration_target_ml': hydrationTargetMl,
        'recommend_renal_ultrasound': recommendRenalUltrasound,
        'recommend_potassium_citrate': recommendPotassiumCitrate,
        'summary': summary,
      };
}

class CardioVestibularFatigueAssessment {
  const CardioVestibularFatigueAssessment({
    required this.riskLevel,
    required this.contributingFactors,
    required this.recommendations,
    required this.summary,
  });

  final CorrelationRiskLevel riskLevel;
  final List<String> contributingFactors;
  final List<String> recommendations;
  final String summary;

  Map<String, dynamic> toJson() => {
        'risk_level': riskLevel.wireName,
        'contributing_factors': contributingFactors,
        'recommendations': recommendations,
        'summary': summary,
      };
}

class SubsystemCorrelationReport {
  const SubsystemCorrelationReport({
    required this.astronautId,
    required this.overallRiskLevel,
    required this.renalStoneRisk,
    required this.cardioVestibularFatigue,
    required this.activeCrossSubsystemAlerts,
    required this.recommendations,
  });

  final String astronautId;
  final CorrelationRiskLevel overallRiskLevel;
  final RenalStoneRiskAssessment renalStoneRisk;
  final CardioVestibularFatigueAssessment cardioVestibularFatigue;
  final List<String> activeCrossSubsystemAlerts;
  final List<String> recommendations;

  Map<String, dynamic> toJson() => {
        'astronaut_id': astronautId,
        'overall_risk_level': overallRiskLevel.wireName,
        'renal_stone_risk': renalStoneRisk.toJson(),
        'cardio_vestibular_fatigue': cardioVestibularFatigue.toJson(),
        'active_cross_subsystem_alerts': activeCrossSubsystemAlerts,
        'recommendations': recommendations,
      };
}

/// Deterministic cross-subsystem clinical correlation engine detecting
/// cascading risks across general vitals, microgravity, radiation, and sleep.
class CrossCorrelationEngine {
  const CrossCorrelationEngine();

  /// Minimum daily fluid intake (mL/day) below which urinary supersaturation
  /// risk rises in microgravity.
  static const double minAdequateHydrationMlPerDay = 1800.0;

  /// Severe dehydration threshold (mL/day).
  static const double severeLowHydrationMlPerDay = 1400.0;

  /// Urinary calcium threshold (mg/day) indicating elevated microgravity
  /// bone resorption / hypercalciuria.
  static const double hypercalciuriaThresholdMgPerDay = 250.0;

  /// Bone density loss threshold (%) indicating significant resorption.
  static const double significantBoneLossPercent = 1.0;

  /// Standard and high-risk hydration targets (mL/day).
  static const int nominalHydrationTargetMl = 2200;
  static const int elevatedHydrationTargetMl = 2500;
  static const int highRiskHydrationTargetMl = 3000;

  /// Graybiel vestibular score >= 3 indicates slight-to-frank space motion sickness.
  static const int vestibularSymptomaticGraybiel = 3;

  RenalStoneRiskAssessment assessRenalStoneRisk({
    required AstronautProfile profile,
    int emesisEpisodes = 0,
    double? hydrationMlPerDay,
    bool lowUrineOutput = false,
    double? urinaryCalciumMgPerDay,
    bool boneResorptionElevated = false,
    double? boneLossPercent,
  }) {
    final factors = <String>[];

    final hasEmesis = emesisEpisodes > 0;
    if (hasEmesis) {
      factors.add(
        'Space motion sickness emesis ($emesisEpisodes episode(s)) increasing fluid/electrolyte loss.',
      );
    }

    final hasLowIntake =
        hydrationMlPerDay != null && hydrationMlPerDay < minAdequateHydrationMlPerDay;
    final hasLowHydration = hasLowIntake || lowUrineOutput;
    if (hasLowIntake) {
      factors.add(
        'Low daily fluid intake (${hydrationMlPerDay.toStringAsFixed(0)} mL/day < ${minAdequateHydrationMlPerDay.toStringAsFixed(0)} mL).',
      );
    }
    if (lowUrineOutput) {
      factors.add('Low urine output concentrating urinary calcium and oxalate.');
    }

    final hasHypercalciuria = urinaryCalciumMgPerDay != null &&
        urinaryCalciumMgPerDay > hypercalciuriaThresholdMgPerDay;
    final hasBoneLoss =
        boneLossPercent != null && boneLossPercent >= significantBoneLossPercent;
    final missedResistiveTarget = !profile.exercise.targetReached;
    final hasBoneResorption = boneResorptionElevated ||
        hasHypercalciuria ||
        hasBoneLoss ||
        (missedResistiveTarget && (hasEmesis || hasLowHydration));

    if (boneResorptionElevated) {
      factors.add('Elevated microgravity bone resorption markers.');
    }
    if (hasHypercalciuria) {
      factors.add(
        'Elevated urinary calcium (${urinaryCalciumMgPerDay.toStringAsFixed(0)} mg/day > ${hypercalciuriaThresholdMgPerDay.toStringAsFixed(0)} mg/day).',
      );
    }
    if (hasBoneLoss) {
      factors.add(
        'Bone mineral loss (${boneLossPercent.toStringAsFixed(1)}%) accelerating calciuria.',
      );
    }
    if (missedResistiveTarget && (hasEmesis || hasLowHydration)) {
      factors.add(
        'Missed musculoskeletal exercise target (${profile.exercise.deviceName}) compounding unloading resorption.',
      );
    }

    final activePillars =
        (hasEmesis ? 1 : 0) + (hasLowHydration ? 1 : 0) + (hasBoneResorption ? 1 : 0);

    final isSevereDepletion =
        (hydrationMlPerDay != null && hydrationMlPerDay < severeLowHydrationMlPerDay) &&
            emesisEpisodes >= 2;

    final CorrelationRiskLevel level;
    if (activePillars >= 3 || (activePillars == 2 && isSevereDepletion)) {
      level = CorrelationRiskLevel.high;
    } else if (activePillars >= 1) {
      level = CorrelationRiskLevel.elevated;
    } else {
      level = CorrelationRiskLevel.nominal;
    }

    final int hydrationTargetMl = switch (level) {
      CorrelationRiskLevel.high => highRiskHydrationTargetMl,
      CorrelationRiskLevel.elevated => elevatedHydrationTargetMl,
      CorrelationRiskLevel.nominal => nominalHydrationTargetMl,
    };

    final recommendUltrasound = level == CorrelationRiskLevel.high;
    final recommendCitrate =
        level == CorrelationRiskLevel.high || hasBoneResorption;

    final summary = switch (level) {
      CorrelationRiskLevel.high =>
        'High nephrolithiasis cascade risk: increase hydration to $hydrationTargetMl mL/day, initiate potassium citrate prophylaxis, and perform autonomous renal/bladder ultrasound.',
      CorrelationRiskLevel.elevated =>
        'Elevated renal stone risk: target $hydrationTargetMl mL/day hydration${recommendCitrate ? ' and consider potassium citrate' : ''}.',
      CorrelationRiskLevel.nominal =>
        'Nominal renal stone risk: maintain $hydrationTargetMl mL/day hydration and routine exercise countermeasures.',
    };

    return RenalStoneRiskAssessment(
      riskLevel: level,
      contributingFactors: List<String>.unmodifiable(factors),
      hydrationTargetMl: hydrationTargetMl,
      recommendRenalUltrasound: recommendUltrasound,
      recommendPotassiumCitrate: recommendCitrate,
      summary: summary,
    );
  }

  CardioVestibularFatigueAssessment assessCardioVestibularFatigue({
    required AstronautProfile profile,
    bool orthostaticIntolerance = false,
    int? graybielScore,
    int emesisEpisodes = 0,
    double? hydrationMlPerDay,
  }) {
    final factors = <String>[];
    final recommendations = <String>[];

    final v = profile.vitals;
    final s = profile.sleep;
    final r = profile.radiation;

    final hasOrthostaticOrCardioStrain = orthostaticIntolerance ||
        v.systolicBP < MedicalThresholds.minSystolicBP ||
        v.heartRate > MedicalThresholds.maxHeartRate ||
        v.capillaryRefillSeconds > 2.0;

    if (hasOrthostaticOrCardioStrain) {
      factors.add(
        'Cardiovascular/orthostatic strain (BP ${v.systolicBP.toStringAsFixed(0)}/${v.diastolicBP.toStringAsFixed(0)} mmHg, HR ${v.heartRate.toStringAsFixed(0)} bpm${orthostaticIntolerance ? ', orthostatic intolerance' : ''}).',
      );
    }

    final hasVestibularLoad =
        (graybielScore != null && graybielScore >= vestibularSymptomaticGraybiel) ||
            emesisEpisodes > 0;
    if (hasVestibularLoad) {
      factors.add(
        'Vestibular dysfunction (${graybielScore != null ? 'Graybiel $graybielScore' : 'emesis $emesisEpisodes'}).',
      );
    }

    final hasSleepDebt =
        s.sleepHours < MedicalThresholds.minRecommendedSleepHours ||
            s.morningMood == MoodLevel.fatigued ||
            s.morningMood == MoodLevel.stressed;
    if (hasSleepDebt) {
      factors.add(
        'Sleep debt (${s.sleepHours.toStringAsFixed(1)} h < ${MedicalThresholds.minRecommendedSleepHours} h, mood ${s.morningMood.name}).',
      );
    }

    final hasRadiationOrDehydration = r.severity != RadiationSeverity.normal ||
        r.doseRateMicroSvPerHour > 100.0 ||
        (hydrationMlPerDay != null && hydrationMlPerDay < minAdequateHydrationMlPerDay);
    if (hasRadiationOrDehydration) {
      factors.add(
        'Compound stressor: radiation ${r.doseRateMicroSvPerHour.toStringAsFixed(1)} uSv/h (${r.severity.name})${hydrationMlPerDay != null && hydrationMlPerDay < minAdequateHydrationMlPerDay ? ', low hydration (${hydrationMlPerDay.toStringAsFixed(0)} mL/day)' : ''}.',
      );
    }

    final activeDomains = (hasOrthostaticOrCardioStrain ? 1 : 0) +
        (hasVestibularLoad ? 1 : 0) +
        (hasSleepDebt ? 1 : 0) +
        (hasRadiationOrDehydration ? 1 : 0);

    final CorrelationRiskLevel level;
    if (activeDomains >= 3) {
      level = CorrelationRiskLevel.high;
    } else if (activeDomains >= 2 ||
        (hasOrthostaticOrCardioStrain && v.systolicBP < 85.0)) {
      level = CorrelationRiskLevel.elevated;
    } else {
      level = CorrelationRiskLevel.nominal;
    }

    if (hasOrthostaticOrCardioStrain) {
      recommendations.add('Evaluate LBNP countermeasure or fluid loading.');
    }
    if (hasVestibularLoad) {
      recommendations.add('Defer EVA and run Graybiel vestibular recheck.');
    }
    if (hasSleepDebt) {
      recommendations.add('Schedule circadian recovery block and PVT check.');
    }
    if (hasRadiationOrDehydration) {
      recommendations.add('Increase fluid intake and monitor radiation sheltering.');
    }

    final summary = switch (level) {
      CorrelationRiskLevel.high =>
        'High cardiovascular-vestibular-fatigue cascade risk across $activeDomains subsystems.',
      CorrelationRiskLevel.elevated =>
        'Elevated cross-subsystem strain across $activeDomains domains.',
      CorrelationRiskLevel.nominal =>
        'No active cardiovascular-vestibular-fatigue cascade detected.',
    };

    return CardioVestibularFatigueAssessment(
      riskLevel: level,
      contributingFactors: List<String>.unmodifiable(factors),
      recommendations: List<String>.unmodifiable(recommendations),
      summary: summary,
    );
  }

  SubsystemCorrelationReport correlateSubsystems({
    required AstronautProfile profile,
    int emesisEpisodes = 0,
    double? hydrationMlPerDay,
    bool lowUrineOutput = false,
    double? urinaryCalciumMgPerDay,
    bool boneResorptionElevated = false,
    double? boneLossPercent,
    bool orthostaticIntolerance = false,
    int? graybielScore,
    Map<String, Map<String, dynamic>> activeFlags = const {},
  }) {
    // Allow cross-module flags (e.g. from Graybiel or hydration logs) to inform inputs.
    final flagEmesis =
        (activeFlags['space_motion_sickness']?['emesis_episodes'] as num?)?.toInt() ??
            0;
    final flagGraybiel =
        (activeFlags['graybiel']?['score'] as num?)?.toInt();
    final effectiveEmesis = emesisEpisodes > 0 ? emesisEpisodes : flagEmesis;
    final effectiveGraybiel = graybielScore ?? flagGraybiel;

    final renal = assessRenalStoneRisk(
      profile: profile,
      emesisEpisodes: effectiveEmesis,
      hydrationMlPerDay: hydrationMlPerDay,
      lowUrineOutput: lowUrineOutput,
      urinaryCalciumMgPerDay: urinaryCalciumMgPerDay,
      boneResorptionElevated: boneResorptionElevated,
      boneLossPercent: boneLossPercent,
    );

    final cvf = assessCardioVestibularFatigue(
      profile: profile,
      orthostaticIntolerance: orthostaticIntolerance,
      graybielScore: effectiveGraybiel,
      emesisEpisodes: effectiveEmesis,
      hydrationMlPerDay: hydrationMlPerDay,
    );

    final overall = CorrelationRiskLevel.values[
        renal.riskLevel.index > cvf.riskLevel.index
            ? renal.riskLevel.index
            : cvf.riskLevel.index];

    final alerts = <String>[
      if (renal.riskLevel != CorrelationRiskLevel.nominal)
        'Renal stone risk (${renal.riskLevel.wireName}): ${renal.summary}',
      if (cvf.riskLevel != CorrelationRiskLevel.nominal)
        'Cardio-vestibular-fatigue (${cvf.riskLevel.wireName}): ${cvf.summary}',
    ];

    final recommendations = <String>{
      if (renal.recommendRenalUltrasound)
        'Perform autonomous renal and bladder ultrasound.',
      if (renal.recommendPotassiumCitrate)
        'Consider potassium citrate prophylaxis after medication safety check.',
      if (renal.riskLevel != CorrelationRiskLevel.nominal)
        'Target hydration >= ${renal.hydrationTargetMl} mL/day.',
      ...cvf.recommendations,
    }.toList(growable: false);

    return SubsystemCorrelationReport(
      astronautId: profile.id,
      overallRiskLevel: overall,
      renalStoneRisk: renal,
      cardioVestibularFatigue: cvf,
      activeCrossSubsystemAlerts: List<String>.unmodifiable(alerts),
      recommendations: List<String>.unmodifiable(recommendations),
    );
  }
}
