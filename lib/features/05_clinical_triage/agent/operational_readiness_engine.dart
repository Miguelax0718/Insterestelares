import 'package:astramed/features/02_radiation/models/radiation_dose.dart';
import 'package:astramed/features/04_mental_health/agent/pvt_mpt_engine.dart';
import 'package:astramed/features/05_clinical_triage/models/triage_decision.dart';
import 'package:astramed/features/crew/models/astronaut_profile.dart';

/// Deterministic clinical thresholds for Pre-EVA and Planetary Landing readiness.
///
/// Thresholds follow `Plan de Arquitectura Agente.md` §3 and D6 clinical constants.
abstract final class OperationalReadinessThresholds {
  static const int maxGraybielScoreExclusive = 5;
  static const int cautionGraybielScoreMin = 3;

  static const double maxLrm50Ms = PvtMptThresholds.significantMinLrm50Ms;
  static const double cautionLrm50Ms = PvtMptThresholds.nominalMaxLrm50Ms;
  static const int maxPvtLapsesExclusive = PvtMptThresholds.significantMinLapses;

  static const double minSleepHours = 6.0;
  static const double cautionSleepHours = 6.5;

  static const double minSystolicBp = 90.0;
  static const double maxSystolicBp = 150.0;
  static const double cautionMaxSystolicBp = 130.0;

  static const double minHeartRate = 50.0;
  static const double maxHeartRate = 110.0;
  static const double cautionMaxHeartRate = 100.0;

  static const double minSpO2 = 94.0;
  static const double maxRespiratoryRateExclusive = 24.0;
  static const double cautionRespiratoryRate = 22.0;

  static const double maxBodyTempC = 37.8;
  static const double cautionBodyTempC = 37.3;

  static const double criticalRadiationDoseRateMicroSvPerHour = 160.0;
  static const double cautionRadiationDoseRateMicroSvPerHour = 100.0;

  static const int sedativeLookbackHours =
      PvtMptThresholds.sedativeLookbackHours;
}

class OperationalReadinessVerdict {
  const OperationalReadinessVerdict({
    required this.astronautId,
    required this.activityType,
    required this.authorized,
    required this.priority,
    required this.blockingReasons,
    required this.cautionReasons,
    required this.immediateActions,
    required this.requiredSupplies,
    required this.evaluatedAt,
    this.metricsSnapshot = const {},
  });

  final String astronautId;
  final String activityType; // 'pre_eva' | 'landing'
  final bool authorized;
  final TriagePriority priority;
  final List<String> blockingReasons;
  final List<String> cautionReasons;
  final List<String> immediateActions;
  final List<String> requiredSupplies;
  final DateTime evaluatedAt;
  final Map<String, dynamic> metricsSnapshot;

  String get activityLabel =>
      activityType == 'landing' ? 'Planetary Landing' : 'Pre-EVA';

  TriageResult toTriageResult() {
    return TriageResult(
      conditionName: '$activityLabel Operational Readiness',
      priority: priority,
      immediateActions: immediateActions,
      requiredSupplies: requiredSupplies,
      algorithm: 'OperationalReadinessEngine v1.0',
    );
  }

  Map<String, dynamic> toJson() => {
        'astronaut_id': astronautId,
        'activity_type': activityType,
        'authorized': authorized,
        'priority': priority.name,
        'blocking_reasons': blockingReasons,
        'caution_reasons': cautionReasons,
        'immediate_actions': immediateActions,
        'required_supplies': requiredSupplies,
        'evaluated_at': evaluatedAt.toUtc().toIso8601String(),
        'metrics': metricsSnapshot,
      };
}

class OperationalReadinessEngine {
  const OperationalReadinessEngine();

  static String normalizeActivityType(String raw) {
    final normalized = raw.trim().toLowerCase().replaceAll('-', '_');
    return switch (normalized) {
      'pre_eva' || 'eva' || 'preeva' => 'pre_eva',
      'landing' || 'planetary_landing' => 'landing',
      _ => throw ArgumentError.value(
          raw,
          'activityType',
          'activityType must be "pre_eva" or "landing".',
        ),
    };
  }

  OperationalReadinessVerdict evaluate({
    required AstronautProfile profile,
    String activityType = 'pre_eva',
    int? graybielScore,
    double? lrm50Ms,
    int? pvtLapses,
    double? sleepHoursOverride,
    bool? hasUncompensatedSedative,
    bool? spaceWeatherCritical,
    String? spaceWeatherAlertLevel,
    Map<String, Map<String, dynamic>> activeFlags = const {},
    DateTime? now,
  }) {
    final activity = normalizeActivityType(activityType);
    final evaluatedAt = (now ?? DateTime.now()).toUtc();
    final activityLabel =
        activity == 'landing' ? 'Planetary Landing' : 'Pre-EVA';

    final blockingReasons = <String>[];
    final cautionReasons = <String>[];
    final immediateActions = <String>{};
    final requiredSupplies = <String>{};

    final v = profile.vitals;
    final r = profile.radiation;
    final sleepHours = sleepHoursOverride ?? profile.sleep.sleepHours;

    // 1. Space motion sickness & active EVA block flags.
    final graybielBlockFlag = activeFlags['eva_blocked_by_graybiel'];
    final evaBlockedFlag = activeFlags['eva_blocked'];

    final effectiveGraybielScore = graybielScore ??
        (graybielBlockFlag?['graybiel_score'] as num?)?.toInt() ??
        (activeFlags['graybiel']?['score'] as num?)?.toInt();

    if (effectiveGraybielScore != null) {
      if (effectiveGraybielScore >=
          OperationalReadinessThresholds.maxGraybielScoreExclusive) {
        blockingReasons.add(
          'Moderate/severe space motion sickness (Graybiel score $effectiveGraybielScore >= ${OperationalReadinessThresholds.maxGraybielScoreExclusive}).',
        );
        immediateActions.add(
          'Hold $activityLabel and evaluate non-oral antiemetic protocol.',
        );
        requiredSupplies.addAll(['Intranasal/IM Antiemetic', 'Emesis Bag']);
      } else if (effectiveGraybielScore >=
          OperationalReadinessThresholds.cautionGraybielScoreMin) {
        cautionReasons.add(
          'Mild vestibular symptoms (Graybiel score $effectiveGraybielScore); monitor before $activityLabel.',
        );
        immediateActions.add('Repeat Graybiel check prior to hatch/deorbit.');
      }
    }

    if (graybielBlockFlag != null && graybielBlockFlag['blocked'] != false) {
      final scoreInfo = graybielBlockFlag['graybiel_score'];
      blockingReasons.add(
        'Active eva_blocked_by_graybiel hold${scoreInfo != null ? ' (Graybiel $scoreInfo)' : ''}.',
      );
      immediateActions.add(
        'Maintain $activityLabel hold until vestibular symptoms resolve.',
      );
      requiredSupplies.add('Intranasal/IM Antiemetic');
    }

    if (evaBlockedFlag != null && _isEvaBlockActive(evaBlockedFlag, evaluatedAt)) {
      final flagActivity = evaBlockedFlag['activity_type']?.toString();
      final reason = evaBlockedFlag['reason']?.toString();
      final matchesActivity = flagActivity == null ||
          flagActivity.isEmpty ||
          flagActivity == 'all' ||
          flagActivity == activity;
      if (matchesActivity) {
        blockingReasons.add(
          'Active eva_blocked flag${reason != null && reason.isNotEmpty ? ': $reason' : '.'}',
        );
        immediateActions.add(
          'Respect active $activityLabel block until cleared by crew medical review.',
        );
      } else {
        cautionReasons.add(
          'EVA block flag active for $flagActivity${reason != null && reason.isNotEmpty ? ': $reason' : '.'}',
        );
      }
    }

    // 2. Cognitive alertness (LRM-50, PVT lapses, sleep, uncompensated sedative).
    final pvtFlag = activeFlags['last_pvt'] ?? activeFlags['pvt'];
    final effectiveLrm50 =
        lrm50Ms ?? (pvtFlag?['lrm50_ms'] as num?)?.toDouble();
    final effectiveLapses =
        pvtLapses ?? (pvtFlag?['lapses'] as num?)?.toInt();

    if (effectiveLrm50 != null) {
      if (effectiveLrm50 > OperationalReadinessThresholds.maxLrm50Ms) {
        blockingReasons.add(
          'Elevated cognitive reaction time (LRM-50 ${effectiveLrm50.toStringAsFixed(0)} ms > ${OperationalReadinessThresholds.maxLrm50Ms.toStringAsFixed(0)} ms).',
        );
        immediateActions.add(
          'Defer $activityLabel and schedule restorative sleep or fatigue countermeasure review.',
        );
      } else if (effectiveLrm50 >
          OperationalReadinessThresholds.cautionLrm50Ms) {
        cautionReasons.add(
          'Mild reaction-time slowing (LRM-50 ${effectiveLrm50.toStringAsFixed(0)} ms).',
        );
      }
    }

    if (effectiveLapses != null) {
      if (effectiveLapses >=
          OperationalReadinessThresholds.maxPvtLapsesExclusive) {
        blockingReasons.add(
          'Excessive PVT attention lapses ($effectiveLapses >= ${OperationalReadinessThresholds.maxPvtLapsesExclusive}).',
        );
        immediateActions.add(
          'Hold $activityLabel due to psychomotor vigilance lapses.',
        );
      } else if (effectiveLapses == 2) {
        cautionReasons.add('Borderline PVT lapses ($effectiveLapses).');
      }
    }

    if (sleepHours < OperationalReadinessThresholds.minSleepHours) {
      blockingReasons.add(
        'Insufficient sleep (${sleepHours.toStringAsFixed(1)} h < ${OperationalReadinessThresholds.minSleepHours.toStringAsFixed(1)} h).',
      );
      immediateActions.add(
        'Enforce sleep recovery window before $activityLabel.',
      );
    } else if (sleepHours < OperationalReadinessThresholds.cautionSleepHours) {
      cautionReasons.add(
        'Borderline sleep duration (${sleepHours.toStringAsFixed(1)} h < ${OperationalReadinessThresholds.cautionSleepHours.toStringAsFixed(1)} h).',
      );
    }

    final sedativeStatus = _evaluateSedativeStatus(
      activeFlags: activeFlags,
      now: evaluatedAt,
      explicitUncompensated: hasUncompensatedSedative,
    );
    if (sedativeStatus.uncompensated) {
      blockingReasons.add(sedativeStatus.message!);
      immediateActions.add(
        'Hold $activityLabel while uncompensated sedative effect remains within 24h window.',
      );
    } else if (sedativeStatus.message != null) {
      cautionReasons.add(sedativeStatus.message!);
    }

    // 3. Cardiovascular, respiratory, temperature, and radiation stability.
    if (v.systolicBP < OperationalReadinessThresholds.minSystolicBp ||
        v.systolicBP > OperationalReadinessThresholds.maxSystolicBp) {
      blockingReasons.add(
        'Systolic BP out of operational range (${v.systolicBP.toStringAsFixed(0)} mmHg; required ${OperationalReadinessThresholds.minSystolicBp.toStringAsFixed(0)}-${OperationalReadinessThresholds.maxSystolicBp.toStringAsFixed(0)} mmHg).',
      );
      immediateActions.add(
        'Stabilize hemodynamics, recheck cuff BP, and evaluate fluid/LBNP status.',
      );
      requiredSupplies.addAll(['Blood Pressure Cuff', 'Oral Rehydration Salts']);
    } else if (v.systolicBP >
        OperationalReadinessThresholds.cautionMaxSystolicBp) {
      cautionReasons.add(
        'Mildly elevated systolic BP (${v.systolicBP.toStringAsFixed(0)} mmHg).',
      );
    }

    if (v.heartRate < OperationalReadinessThresholds.minHeartRate ||
        v.heartRate > OperationalReadinessThresholds.maxHeartRate) {
      blockingReasons.add(
        'Heart rate out of operational range (${v.heartRate.toStringAsFixed(0)} bpm; required ${OperationalReadinessThresholds.minHeartRate.toStringAsFixed(0)}-${OperationalReadinessThresholds.maxHeartRate.toStringAsFixed(0)} bpm).',
      );
      immediateActions.add(
        'Monitor 3-lead ECG and repeat resting heart rate assessment.',
      );
      requiredSupplies.add('3-Lead ECG / Bio-Monitor');
    } else if (v.heartRate > OperationalReadinessThresholds.cautionMaxHeartRate) {
      cautionReasons.add(
        'Borderline tachycardia (${v.heartRate.toStringAsFixed(0)} bpm).',
      );
    }

    if (v.spO2 < OperationalReadinessThresholds.minSpO2) {
      blockingReasons.add(
        'Low oxygen saturation (SpO2 ${v.spO2.toStringAsFixed(0)}% < ${OperationalReadinessThresholds.minSpO2.toStringAsFixed(0)}%).',
      );
      immediateActions.add(
        'Administer supplemental O2 and verify airway and cabin/suit pO2.',
      );
      requiredSupplies.addAll(['Oxygen Mask & Cylinder', 'Pulse Oximeter']);
    }

    if (v.respiratoryRate >=
        OperationalReadinessThresholds.maxRespiratoryRateExclusive) {
      blockingReasons.add(
        'Elevated respiratory rate (RR ${v.respiratoryRate.toStringAsFixed(0)} rpm >= ${OperationalReadinessThresholds.maxRespiratoryRateExclusive.toStringAsFixed(0)} rpm).',
      );
      immediateActions.add(
        'Assess airway, CO2 partial pressure, and respiratory distress.',
      );
      requiredSupplies.add('Pulse Oximeter');
    } else if (v.respiratoryRate >
        OperationalReadinessThresholds.cautionRespiratoryRate) {
      cautionReasons.add(
        'Borderline respiratory rate (${v.respiratoryRate.toStringAsFixed(0)} rpm).',
      );
    }

    if (v.bodyTemp > OperationalReadinessThresholds.maxBodyTempC) {
      blockingReasons.add(
        'Elevated body temperature (${v.bodyTemp.toStringAsFixed(1)} C > ${OperationalReadinessThresholds.maxBodyTempC.toStringAsFixed(1)} C).',
      );
      immediateActions.add(
        'Evaluate febrile/inflammatory cause and initiate cooling/hydration.',
      );
      requiredSupplies.add('Digital Thermometer');
    } else if (v.bodyTemp > OperationalReadinessThresholds.cautionBodyTempC) {
      cautionReasons.add(
        'Borderline body temperature (${v.bodyTemp.toStringAsFixed(1)} C).',
      );
    }

    final normalizedWeatherAlert =
        spaceWeatherAlertLevel?.trim().toLowerCase() ?? '';
    final isRadiationCritical =
        r.severity == RadiationSeverity.critical ||
        r.doseRateMicroSvPerHour >
            OperationalReadinessThresholds
                .criticalRadiationDoseRateMicroSvPerHour ||
        spaceWeatherCritical == true ||
        normalizedWeatherAlert == 'critical';

    final isRadiationWarning =
        r.severity == RadiationSeverity.warning ||
        r.doseRateMicroSvPerHour >
            OperationalReadinessThresholds
                .cautionRadiationDoseRateMicroSvPerHour ||
        normalizedWeatherAlert == 'warning';

    if (isRadiationCritical) {
      blockingReasons.add(
        'Critical radiation alert (${r.doseRateMicroSvPerHour.toStringAsFixed(1)} uSv/h, ${r.severity.name}).',
      );
      immediateActions.add(
        'Cancel EVA/external exposure and shelter crew in shielded module.',
      );
      requiredSupplies.add('Personal Dosimeter');
    } else if (isRadiationWarning) {
      cautionReasons.add(
        'Elevated radiation environment (${r.doseRateMicroSvPerHour.toStringAsFixed(1)} uSv/h).',
      );
    }

    final TriagePriority priority;
    final bool authorized;
    if (blockingReasons.isNotEmpty) {
      priority = TriagePriority.red;
      authorized = false;
    } else if (cautionReasons.isNotEmpty) {
      priority = TriagePriority.yellow;
      authorized = true;
      immediateActions.add(
        'Proceed with $activityLabel under heightened biometric monitoring.',
      );
    } else {
      priority = TriagePriority.green;
      authorized = true;
      immediateActions.add(
        'Cleared for $activityLabel; maintain standard suit/cabin telemetry.',
      );
    }

    return OperationalReadinessVerdict(
      astronautId: profile.id,
      activityType: activity,
      authorized: authorized,
      priority: priority,
      blockingReasons: List<String>.unmodifiable(blockingReasons),
      cautionReasons: List<String>.unmodifiable(cautionReasons),
      immediateActions: List<String>.unmodifiable(immediateActions),
      requiredSupplies: List<String>.unmodifiable(requiredSupplies),
      evaluatedAt: evaluatedAt,
      metricsSnapshot: {
        'graybiel_score': ?effectiveGraybielScore,
        'lrm50_ms': ?effectiveLrm50,
        'pvt_lapses': ?effectiveLapses,
        'sleep_hours': sleepHours,
        'systolic_bp': v.systolicBP,
        'heart_rate': v.heartRate,
        'spo2': v.spO2,
        'respiratory_rate': v.respiratoryRate,
        'body_temp': v.bodyTemp,
        'radiation_dose_rate_usv_h': r.doseRateMicroSvPerHour,
        'radiation_severity': r.severity.name,
      },
    );
  }

  static bool _isEvaBlockActive(Map<String, dynamic> flag, DateTime now) {
    if (flag['blocked'] == false) {
      return false;
    }
    final expiresAt = DateTime.tryParse(flag['expires_at']?.toString() ?? '');
    if (expiresAt != null && now.isAfter(expiresAt.toUtc())) {
      return false;
    }
    final ts = DateTime.tryParse(flag['timestamp']?.toString() ?? '');
    final durationHours = (flag['duration_hours'] as num?)?.toDouble();
    if (ts != null && durationHours != null && durationHours > 0) {
      final computedExpiry = ts.toUtc().add(
            Duration(minutes: (durationHours * 60).round()),
          );
      if (now.isAfter(computedExpiry)) {
        return false;
      }
    }
    return true;
  }

  static ({bool uncompensated, String? message}) _evaluateSedativeStatus({
    required Map<String, Map<String, dynamic>> activeFlags,
    required DateTime now,
    bool? explicitUncompensated,
  }) {
    if (explicitUncompensated == true) {
      return (
        uncompensated: true,
        message: 'Uncompensated recent sedative use reported.',
      );
    }

    final sedativeFlag = activeFlags[PvtMptThresholds.flagRecentSedativeUse];
    if (sedativeFlag == null) {
      return (uncompensated: false, message: null);
    }

    final lookback = const Duration(
      hours: OperationalReadinessThresholds.sedativeLookbackHours,
    );
    final sedativeTs = DateTime.tryParse(
      (sedativeFlag['timestamp'] ?? sedativeFlag['administered_at'])
              ?.toString() ??
          '',
    );
    final sedativeActive = sedativeTs == null ||
        (!now.isBefore(sedativeTs.toUtc()) &&
            now.difference(sedativeTs.toUtc()) <= lookback);
    if (!sedativeActive) {
      return (uncompensated: false, message: null);
    }

    final medName = sedativeFlag['medication']?.toString() ?? 'sedative';
    final stimFlag = activeFlags[PvtMptThresholds.flagStimulantAuthorized];
    var compensated = false;
    String? stimMed;
    if (stimFlag != null) {
      final stimTs = DateTime.tryParse(
        (stimFlag['authorized_at'] ?? stimFlag['timestamp'])?.toString() ?? '',
      );
      compensated = stimTs == null ||
          (!now.isBefore(stimTs.toUtc()) &&
              now.difference(stimTs.toUtc()) <= lookback);
      stimMed = stimFlag['medication']?.toString() ?? 'stimulant';
    }

    if (compensated) {
      return (
        uncompensated: false,
        message: 'Recent sedative ($medName) compensated with $stimMed.',
      );
    }

    return (
      uncompensated: true,
      message: 'Uncompensated recent sedative use ($medName within 24h).',
    );
  }
}
