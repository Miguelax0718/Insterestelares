import 'package:astramed/features/agent/domain/agent_contracts.dart';
import 'package:astramed/features/crew/models/astronaut_profile.dart';

enum ExerciseSafetyStatus {
  nominalActive('nominal_active'),
  targetCompleted('target_completed'),
  unsafeAbort('unsafe_abort');

  const ExerciseSafetyStatus(this.wireName);

  final String wireName;
}

class ExerciseGuidanceResult {
  const ExerciseGuidanceResult({
    required this.astronautId,
    required this.deviceName,
    required this.modality,
    required this.durationMinutes,
    required this.caloriesBurned,
    required this.targetReached,
    required this.heartRate,
    required this.systolicBP,
    required this.spO2,
    required this.status,
    required this.unsafeVitals,
    required this.alerts,
    required this.guidance,
  });

  final String astronautId;
  final String deviceName;
  final String modality;
  final int durationMinutes;
  final double caloriesBurned;
  final bool targetReached;
  final double heartRate;
  final double systolicBP;
  final double spO2;
  final ExerciseSafetyStatus status;
  final bool unsafeVitals;
  final List<String> alerts;
  final String guidance;

  Map<String, dynamic> toJson() => {
    'astronaut_id': astronautId,
    'device_name': deviceName,
    'modality': modality,
    'duration_minutes': durationMinutes,
    'calories_burned': caloriesBurned,
    'target_reached': targetReached,
    'heart_rate': heartRate,
    'systolic_bp': systolicBP,
    'spo2': spO2,
    'status': status.wireName,
    'unsafe_vitals': unsafeVitals,
    'alerts': alerts,
    'guidance': guidance,
  };
}

class ExerciseGuidanceEngine {
  ExerciseGuidanceEngine._();

  static const double minSafeSpO2 = 92.0;
  static const double maxSafeHeartRate = 175.0;
  static const double maxSafeSystolicBP = 180.0;
  static const int weeklyTargetMinutes = 150;

  static String inferModality(String deviceName) {
    final lower = deviceName.toLowerCase();
    if (lower.contains('ared') || lower.contains('resist')) {
      return 'resistive_load';
    }
    if (lower.contains('t2') ||
        lower.contains('treadmill') ||
        lower.contains('cinta')) {
      return 'locomotor';
    }
    if (lower.contains('cevis') || lower.contains('cycle')) {
      return 'ergometer';
    }
    if (lower.contains('motor') || lower.contains('coord')) {
      return 'motor_coordination';
    }
    return 'resistive_load';
  }

  static ExerciseGuidanceResult evaluate({
    required AstronautProfile profile,
    String? modalityOverride,
  }) {
    final vitals = profile.vitals;
    final exercise = profile.exercise;
    final modality = modalityOverride ?? inferModality(exercise.deviceName);

    final alerts = <String>[];
    if (vitals.spO2 < minSafeSpO2) {
      alerts.add(
        'Hypoxia alert during exercise: SpO2 ${vitals.spO2.toStringAsFixed(0)}% (< 92%).',
      );
    }
    if (vitals.heartRate > maxSafeHeartRate) {
      alerts.add(
        'Excessive tachycardia: HR ${vitals.heartRate.toStringAsFixed(0)} bpm (> 175 bpm).',
      );
    }
    if (vitals.systolicBP > maxSafeSystolicBP) {
      alerts.add(
        'Hypertensive response: SBP ${vitals.systolicBP.toStringAsFixed(0)} mmHg (> 180 mmHg).',
      );
    }

    final unsafe = alerts.isNotEmpty;
    final status = unsafe
        ? ExerciseSafetyStatus.unsafeAbort
        : (exercise.targetReached
              ? ExerciseSafetyStatus.targetCompleted
              : ExerciseSafetyStatus.nominalActive);

    final String guidance;
    if (unsafe) {
      guidance =
          'Stop ${exercise.deviceName} session immediately, unload restraint harness, '
          'hydrate, and monitor vitals to recovery.';
    } else if (exercise.targetReached) {
      guidance =
          '${exercise.deviceName} session target reached (${exercise.durationMinutes} min); '
          'begin 5-minute low-load cooldown.';
    } else if (modality == 'motor_coordination') {
      guidance =
          'Motor coordination vitals nominal; maintain controlled head-trunk alignment '
          'and steady visual fixation.';
    } else {
      final remaining = (weeklyTargetMinutes - exercise.durationMinutes).clamp(
        0,
        weeklyTargetMinutes,
      );
      guidance =
          'Vitals nominal on ${exercise.deviceName} ($modality). '
          'Maintain prescribed load; $remaining min remaining toward $weeklyTargetMinutes-min target.';
    }

    return ExerciseGuidanceResult(
      astronautId: profile.id,
      deviceName: exercise.deviceName,
      modality: modality,
      durationMinutes: exercise.durationMinutes,
      caloriesBurned: exercise.caloriesBurned,
      targetReached: exercise.targetReached,
      heartRate: vitals.heartRate,
      systolicBP: vitals.systolicBP,
      spO2: vitals.spO2,
      status: status,
      unsafeVitals: unsafe,
      alerts: List.unmodifiable(alerts),
      guidance: guidance,
    );
  }
}

class ExerciseMonitorViewModel extends AgentViewModel {
  const ExerciseMonitorViewModel({
    required this.result,
  }) : super(
         componentId: ComponentIds.exerciseMonitor,
         title: 'Microgravity Exercise Monitor',
       );

  factory ExerciseMonitorViewModel.fromProps(Map<String, dynamic> props) {
    final statusRaw = props['status'] as String? ?? 'nominal_active';
    final status = ExerciseSafetyStatus.values.firstWhere(
      (s) => s.wireName == statusRaw,
      orElse: () => ExerciseSafetyStatus.nominalActive,
    );
    return ExerciseMonitorViewModel(
      result: ExerciseGuidanceResult(
        astronautId: props['astronaut_id'] as String? ?? 'AST-01',
        deviceName: props['device_name'] as String? ?? 'ARED',
        modality: props['modality'] as String? ?? 'resistive_load',
        durationMinutes: (props['duration_minutes'] as num?)?.toInt() ?? 0,
        caloriesBurned: (props['calories_burned'] as num?)?.toDouble() ?? 0.0,
        targetReached: props['target_reached'] as bool? ?? false,
        heartRate: (props['heart_rate'] as num?)?.toDouble() ?? 70.0,
        systolicBP: (props['systolic_bp'] as num?)?.toDouble() ?? 120.0,
        spO2: (props['spo2'] as num?)?.toDouble() ?? 98.0,
        status: status,
        unsafeVitals: props['unsafe_vitals'] as bool? ?? false,
        alerts: (props['alerts'] as List<dynamic>? ?? const []).cast<String>(),
        guidance: props['guidance'] as String? ?? '',
      ),
    );
  }

  final ExerciseGuidanceResult result;

  @override
  Map<String, dynamic> toProps() => {
    'component_id': componentId,
    'title': title,
    ...result.toJson(),
  };
}
