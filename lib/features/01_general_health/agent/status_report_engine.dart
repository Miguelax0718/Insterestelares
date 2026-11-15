import 'package:astramed/core/constants/medical_thresholds.dart';
import 'package:astramed/features/crew/models/astronaut_profile.dart';

/// Structured cross-subsystem status report synthesized from [AstronautProfile]
/// and persisted agent flags, reusing [CrewRiskLevel] and [MedicalThresholds].
class StatusReport {
  const StatusReport({
    required this.astronautId,
    required this.astronautName,
    required this.callsign,
    required this.role,
    required this.currentZone,
    required this.riskLevel,
    required this.riskTitle,
    required this.riskDescription,
    required this.activeAlerts,
    required this.activeFlags,
    required this.subsystems,
    required this.summary,
    required this.generatedAt,
  });

  final String astronautId;
  final String astronautName;
  final String callsign;
  final String role;
  final String currentZone;
  final CrewRiskLevel riskLevel;
  final String riskTitle;
  final String riskDescription;
  final List<String> activeAlerts;
  final Map<String, Map<String, dynamic>> activeFlags;
  final Map<String, Map<String, dynamic>> subsystems;
  final String summary;
  final DateTime generatedAt;

  Map<String, dynamic> toJson() => {
        'astronaut_id': astronautId,
        'astronaut_name': astronautName,
        'callsign': callsign,
        'role': role,
        'current_zone': currentZone,
        'risk_level': riskLevel.name,
        'risk_title': riskTitle,
        'risk_description': riskDescription,
        'active_alerts': activeAlerts,
        'active_flags': activeFlags,
        'subsystems': subsystems,
        'summary': summary,
        'generated_at': generatedAt.toUtc().toIso8601String(),
      };
}

/// Pure deterministic engine that synthesizes a cross-subsystem status report
/// directly from the active [AstronautProfile] and active astronaut flags.
class StatusReportEngine {
  const StatusReportEngine();

  StatusReport build({
    required AstronautProfile profile,
    Map<String, Map<String, dynamic>> activeFlags = const {},
    DateTime? now,
  }) {
    final timestamp = (now ?? DateTime.now()).toUtc();
    final v = profile.vitals;
    final r = profile.radiation;
    final s = profile.sleep;
    final e = profile.exercise;

    final vitalsWithinThresholds =
        v.heartRate >= MedicalThresholds.minHeartRate &&
            v.heartRate <= MedicalThresholds.maxHeartRate &&
            v.systolicBP >= MedicalThresholds.minSystolicBP &&
            v.systolicBP <= MedicalThresholds.maxSystolicBP &&
            v.spO2 >= MedicalThresholds.minSpO2;

    final sleepDeficitHours =
        s.sleepHours < MedicalThresholds.minRecommendedSleepHours
            ? double.parse(
                (MedicalThresholds.minRecommendedSleepHours - s.sleepHours)
                    .toStringAsFixed(1),
              )
            : 0.0;

    final careerLimitPct = double.parse(
      ((r.cumulativeDoseMilliSv / MedicalThresholds.radiationCareerLimitMax) *
              100.0)
          .toStringAsFixed(1),
    );

    final subsystems = <String, Map<String, dynamic>>{
      'vitals': {
        'heart_rate_bpm': v.heartRate,
        'systolic_bp_mmhg': v.systolicBP,
        'diastolic_bp_mmhg': v.diastolicBP,
        'spo2_percent': v.spO2,
        'body_temp_c': v.bodyTemp,
        'blood_glucose_mg_dl': v.bloodGlucose,
        'respiratory_rate_rpm': v.respiratoryRate,
        'capillary_refill_s': v.capillaryRefillSeconds,
        'activity_state': v.activityState,
        'signal_quality': v.signalQuality,
        'source': v.source,
        'within_baseline_thresholds': vitalsWithinThresholds,
      },
      'radiation': {
        'dose_rate_usv_h': r.doseRateMicroSvPerHour,
        'cumulative_dose_msv': r.cumulativeDoseMilliSv,
        'career_limit_percent': careerLimitPct,
        'severity': r.severity.name,
      },
      'sleep': {
        'sleep_hours': s.sleepHours,
        'wake_episodes': s.wakeEpisodes,
        'morning_mood': s.morningMood.name,
        'recommended_min_hours': MedicalThresholds.minRecommendedSleepHours,
        'deficit_hours': sleepDeficitHours,
      },
      'exercise': {
        'device_name': e.deviceName,
        'duration_minutes': e.durationMinutes,
        'calories_burned': e.caloriesBurned,
        'target_reached': e.targetReached,
      },
    };

    final alertsPart = profile.activeAlerts.isEmpty
        ? 'No active clinical alerts.'
        : '${profile.activeAlerts.length} active alert(s): ${profile.activeAlerts.join('; ')}.';
    final flagsPart = activeFlags.isEmpty
        ? ''
        : ' Active flags: ${activeFlags.keys.join(', ')}.';

    final summary =
        '${profile.name} (${profile.callsign}, ${profile.currentZone}): '
        'status ${profile.riskLevel.name} — '
        'HR ${v.heartRate.toStringAsFixed(0)} bpm, '
        'BP ${v.systolicBP.toStringAsFixed(0)}/${v.diastolicBP.toStringAsFixed(0)} mmHg, '
        'SpO2 ${v.spO2.toStringAsFixed(0)}%, '
        'sleep ${s.sleepHours.toStringAsFixed(1)} h, '
        'radiation ${r.doseRateMicroSvPerHour.toStringAsFixed(1)} uSv/h. '
        '$alertsPart$flagsPart';

    return StatusReport(
      astronautId: profile.id,
      astronautName: profile.name,
      callsign: profile.callsign,
      role: profile.role,
      currentZone: profile.currentZone,
      riskLevel: profile.riskLevel,
      riskTitle: profile.riskTitle,
      riskDescription: profile.riskDescription,
      activeAlerts: List<String>.unmodifiable(profile.activeAlerts),
      activeFlags: Map<String, Map<String, dynamic>>.unmodifiable(activeFlags),
      subsystems: subsystems,
      summary: summary.trim(),
      generatedAt: timestamp,
    );
  }
}
