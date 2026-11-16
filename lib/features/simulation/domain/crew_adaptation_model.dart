import 'dart:math' as math;

import 'crew_event_response_model.dart';
import 'mission_simulator_state.dart';

/// Event-free state of one crew member at the start of the simulation.
class CrewBaseline {
  const CrewBaseline({
    required this.id,
    required this.heartRate,
    required this.systolicBP,
    required this.diastolicBP,
    required this.sleepHours,
    required this.doseRate,
    required this.waterGoalMl,
  });

  final String id;
  final double heartRate;
  final double systolicBP;
  final double diastolicBP;
  final double sleepHours;
  final double doseRate;
  final int waterGoalMl;
}

/// Background (event-free) values of one crew member on a mission day.
class CrewBackground {
  const CrewBackground({
    required this.heartRate,
    required this.systolicBP,
    required this.diastolicBP,
    required this.sleepHours,
    required this.doseRate,
    required this.waterMl,
    required this.exerciseTargetReached,
  });

  final double heartRate;
  final double systolicBP;
  final double diastolicBP;
  final double sleepHours;

  /// µSv/h.
  final double doseRate;
  final double waterMl;
  final bool exerciseTargetReached;

  /// Daily cumulative dose produced by this background dose rate, in mSv.
  double get dailyDoseMsv => doseRate * 24 / 1000;

  /// Change from [previous] to this day, keyed like [SimVar].
  Map<String, double> deltaFrom(CrewBackground previous) => {
        SimVar.heartRate: heartRate - previous.heartRate,
        SimVar.systolicBP: systolicBP - previous.systolicBP,
        SimVar.diastolicBP: diastolicBP - previous.diastolicBP,
        SimVar.sleepHours: sleepHours - previous.sleepHours,
        SimVar.doseRate: doseRate - previous.doseRate,
        SimVar.waterMl: waterMl - previous.waterMl,
      };
}

/// Bounded, individual adaptation to spaceflight without events.
///
/// Replaces the original fixed daily deterioration, which pushed every crew
/// member past the critical thresholds on almost the same day. Sources and
/// estimates are documented in `sources/medical/crew_adaptation.md`.
abstract final class CrewAdaptationModel {
  /// In-flight sleep on the ISS, 6.09 ± 0.67 h (Barger 2014).
  static const double sleepMeanHours = 6.09;
  static const double sleepSdHours = 0.67;

  /// 24-h blood pressure −8/−9 mmHg in flight, heart rate unchanged (Norsk 2015).
  static const double systolicDrop = 8.0;
  static const double diastolicDrop = 9.0;

  /// Time constants of adaptation, in days (team estimate).
  static const double fluidShiftTauDays = 7.0;
  static const double sleepTauDays = 10.0;

  /// Background dose rate by mission type, in µSv/h.
  /// Transit and surface follow the NASA-STD-3001 GCR design requirements
  /// (1.3 and 0.9 mSv/day); orbital and lunar are team estimates.
  static double doseRateFor(MissionType type) => switch (type) {
        MissionType.orbital => 24.0, // ≈0.58 mSv/day, estimate
        MissionType.lunar => 40.0, // ≈0.96 mSv/day, estimate (nominal baseline)
        MissionType.transit => 54.0, // 1.3 mSv/day
        MissionType.surface => 37.5, // 0.9 mSv/day
      };

  /// Stable, per-mission traits of one crew member.
  static ({double sleepTarget, double exerciseMissChance}) traits(int seed, String id) {
    final rng = SeededRng.of([seed, id, 'adaptation']);
    final sleepTarget =
        (sleepMeanHours + sleepSdHours * rng.gaussian()).clamp(4.8, 7.8).toDouble();
    return (sleepTarget: sleepTarget, exerciseMissChance: rng.range(0.03, 0.10));
  }

  /// Background values of [b] on [missionDay] (day 1 = baseline).
  static CrewBackground on({
    required CrewBaseline b,
    required int missionDay,
    required MissionType type,
    int seed = CrewEventResponseModel.defaultSeed,
  }) {
    if (missionDay <= 1) {
      return CrewBackground(
        heartRate: b.heartRate,
        systolicBP: b.systolicBP,
        diastolicBP: b.diastolicBP,
        sleepHours: b.sleepHours,
        doseRate: b.doseRate,
        waterMl: b.waterGoalMl.toDouble(),
        exerciseTargetReached: true,
      );
    }
    final t = (missionDay - 1).toDouble();
    final tr = traits(seed, b.id);
    final rng = SeededRng.of([seed, b.id, 'day', missionDay]);
    final fluid = 1 - math.exp(-t / fluidShiftTauDays);
    final sleepConv = 1 - math.exp(-t / sleepTauDays);
    return CrewBackground(
      // No trend; small day-to-day variation (estimate).
      heartRate: b.heartRate + 1.5 * rng.gaussian(),
      systolicBP: b.systolicBP - systolicDrop * fluid + 2.0 * rng.gaussian(),
      diastolicBP: b.diastolicBP - diastolicDrop * fluid + 1.5 * rng.gaussian(),
      sleepHours: b.sleepHours + (tr.sleepTarget - b.sleepHours) * sleepConv + 0.25 * rng.gaussian(),
      doseRate: doseRateFor(type),
      waterMl: b.waterGoalMl * rng.range(0.85, 1.05),
      exerciseTargetReached: rng.next() >= tr.exerciseMissChance,
    );
  }
}
