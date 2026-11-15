import 'package:astramed/features/agent/domain/agent_contracts.dart';

/// Clinical thresholds and pharmacological calibration constants for PVT/MPT.
///
/// Thresholds follow clinical assumption D6-A1 and are isolated here for review.
abstract final class PvtMptThresholds {
  static const double falseStartThresholdMs = 100.0;
  static const double lapseThresholdMs = 500.0;

  static const double nominalMaxLrm50Ms = 260.0;
  static const int nominalMaxLapses = 1;

  static const double mildMaxLrm50Ms = 300.0;
  static const int mildMaxLapses = 2;

  static const double significantMinLrm50Ms = 300.0;
  static const int significantMinLapses = 3;

  static const double mptNominalMinAccuracyPercent = 85.0;
  static const double mptDegradedMinAccuracyPercent = 70.0;
  static const double mptNominalMaxDeviationMm = 3.0;
  static const double mptDegradedMaxDeviationMm = 6.0;

  static const String stimulantDefaultMedication = 'modafinil';
  static const double stimulantDefaultDoseMg = 100.0;

  static const String hypnoticDefaultMedication = 'zolpidem';
  static const double hypnoticDefaultDoseMg = 5.0;
  static const int hypnoticWindowHours = 8;

  static const int sedativeLookbackHours = 24;

  static const String flagRecentSedativeUse = 'recent_sedative_use';
  static const String flagStimulantAuthorized =
      'stimulant_compensation_authorized';
  static const String flagLastHypnoticDose = 'last_hypnotic_dose';

  static const Set<String> recognizedSedatives = {
    'promethazine',
    'diphenhydramine',
    'meclizine',
    'dimenhydrinate',
    'chlorpheniramine',
    'hydroxyzine',
    'antihistamine',
    'antiemetic',
    'sedative',
  };
}

enum FatigueLevel {
  nominal('nominal'),
  mildFatigue('mild_fatigue'),
  significantFatigue('significant_fatigue');

  const FatigueLevel(this.wireName);

  final String wireName;

  static FatigueLevel fromWire(String value) {
    return FatigueLevel.values.firstWhere(
      (level) => level.wireName == value,
      orElse: () => FatigueLevel.nominal,
    );
  }
}

enum MotorStatus {
  nominal('nominal'),
  degraded('degraded'),
  impaired('impaired');

  const MotorStatus(this.wireName);

  final String wireName;

  static MotorStatus fromWire(String value) {
    return MotorStatus.values.firstWhere(
      (status) => status.wireName == value,
      orElse: () => MotorStatus.nominal,
    );
  }
}

class PvtResult {
  const PvtResult({
    required this.lrm50Ms,
    required this.validTrialCount,
    required this.falseStarts,
    required this.lapses,
    required this.fatigueLevel,
  });

  final double lrm50Ms;
  final int validTrialCount;
  final int falseStarts;
  final int lapses;
  final FatigueLevel fatigueLevel;

  Map<String, dynamic> toJson() => {
    'lrm50_ms': lrm50Ms,
    'valid_trial_count': validTrialCount,
    'false_starts': falseStarts,
    'lapses': lapses,
    'fatigue_level': fatigueLevel.wireName,
  };
}

class MptResult {
  const MptResult({
    required this.targetsHit,
    required this.totalTargets,
    required this.hitAccuracyPercent,
    required this.pathDeviationMm,
    required this.motorStatus,
  });

  final int targetsHit;
  final int totalTargets;
  final double hitAccuracyPercent;
  final double pathDeviationMm;
  final MotorStatus motorStatus;

  Map<String, dynamic> toJson() => {
    'targets_hit': targetsHit,
    'total_targets': totalTargets,
    'hit_accuracy_percent': hitAccuracyPercent,
    'path_deviation_mm': pathDeviationMm,
    'motor_status': motorStatus.wireName,
  };
}

class StimulantCalibrationResult {
  const StimulantCalibrationResult({
    required this.authorized,
    required this.medication,
    required this.doseMg,
    required this.route,
    required this.fatigueLevel,
    required this.lrm50Ms,
    required this.lapses,
    required this.hasRecentSedativeUse,
    this.sedativeSource,
    this.medicationCheck,
    this.confirmationDecision,
    this.reasons = const [],
  });

  final bool authorized;
  final String medication;
  final double doseMg;
  final String route;
  final FatigueLevel fatigueLevel;
  final double lrm50Ms;
  final int lapses;
  final bool hasRecentSedativeUse;
  final String? sedativeSource;
  final MedicationCheck? medicationCheck;
  final ConfirmationDecision? confirmationDecision;
  final List<String> reasons;

  Map<String, dynamic> toJson() => {
    'authorized': authorized,
    'medication': medication,
    'dose_mg': doseMg,
    'route': route,
    'fatigue_level': fatigueLevel.wireName,
    'lrm50_ms': lrm50Ms,
    'lapses': lapses,
    'has_recent_sedative_use': hasRecentSedativeUse,
    if (sedativeSource != null) 'sedative_source': sedativeSource,
    if (medicationCheck != null) 'medication_check': medicationCheck!.toJson(),
    if (confirmationDecision != null)
      'confirmation_decision': confirmationDecision!.wireName,
    'reasons': reasons,
  };
}

class HypnoticCalibrationResult {
  const HypnoticCalibrationResult({
    required this.authorized,
    required this.secondNightDoseBlocked,
    required this.medication,
    required this.doseMg,
    required this.route,
    this.medicationCheck,
    this.confirmationDecision,
    this.previousDoseAt,
    this.reasons = const [],
  });

  final bool authorized;
  final bool secondNightDoseBlocked;
  final String medication;
  final double doseMg;
  final String route;
  final MedicationCheck? medicationCheck;
  final ConfirmationDecision? confirmationDecision;
  final DateTime? previousDoseAt;
  final List<String> reasons;

  Map<String, dynamic> toJson() => {
    'authorized': authorized,
    'secondNightDoseBlocked': secondNightDoseBlocked,
    'medication': medication,
    'dose_mg': doseMg,
    'route': route,
    if (medicationCheck != null) 'medication_check': medicationCheck!.toJson(),
    if (confirmationDecision != null)
      'confirmation_decision': confirmationDecision!.wireName,
    if (previousDoseAt != null)
      'previous_dose_at': previousDoseAt!.toUtc().toIso8601String(),
    'reasons': reasons,
  };
}

abstract final class PvtMptEngine {
  /// Evaluates raw PVT reaction times (ms) using D6-A1 LRM-50 rules.
  ///
  /// Trials `< 100 ms` are counted as false starts and excluded from the median.
  /// Valid trials `>= 100 ms` determine LRM-50 (median); trials `> 500 ms` are
  /// also counted separately as lapses.
  static PvtResult evaluatePvt(List<num> reactionTimesMs) {
    if (reactionTimesMs.isEmpty) {
      throw ArgumentError.value(
        reactionTimesMs,
        'reactionTimesMs',
        'At least one PVT trial is required.',
      );
    }

    var falseStarts = 0;
    var lapses = 0;
    final valid = <double>[];

    for (final raw in reactionTimesMs) {
      final value = raw.toDouble();
      if (value.isNaN || value.isInfinite || value < 0) {
        throw ArgumentError.value(
          raw,
          'reactionTimesMs',
          'Reaction times must be finite non-negative numbers.',
        );
      }
      if (value < PvtMptThresholds.falseStartThresholdMs) {
        falseStarts++;
        continue;
      }
      valid.add(value);
      if (value > PvtMptThresholds.lapseThresholdMs) {
        lapses++;
      }
    }

    if (valid.isEmpty) {
      throw ArgumentError.value(
        reactionTimesMs,
        'reactionTimesMs',
        'No valid PVT trials (>= 100 ms) found.',
      );
    }

    valid.sort();
    final mid = valid.length ~/ 2;
    final lrm50Ms = valid.length.isOdd
        ? valid[mid]
        : (valid[mid - 1] + valid[mid]) / 2.0;

    return PvtResult(
      lrm50Ms: lrm50Ms,
      validTrialCount: valid.length,
      falseStarts: falseStarts,
      lapses: lapses,
      fatigueLevel: classifyFatigue(lrm50Ms: lrm50Ms, lapses: lapses),
    );
  }

  static FatigueLevel classifyFatigue({
    required double lrm50Ms,
    int lapses = 0,
  }) {
    if (lrm50Ms > PvtMptThresholds.significantMinLrm50Ms ||
        lapses >= PvtMptThresholds.significantMinLapses) {
      return FatigueLevel.significantFatigue;
    }
    if (lrm50Ms > PvtMptThresholds.nominalMaxLrm50Ms ||
        lapses == PvtMptThresholds.mildMaxLapses) {
      return FatigueLevel.mildFatigue;
    }
    return FatigueLevel.nominal;
  }

  /// Evaluates Motor Precision Task (MPT) hit accuracy % and path deviation mm.
  static MptResult evaluateMpt({
    required int targetsHit,
    required int totalTargets,
    List<num> pathDeviationsMm = const [],
    double? meanPathDeviationMm,
  }) {
    if (totalTargets <= 0) {
      throw ArgumentError.value(
        totalTargets,
        'totalTargets',
        'totalTargets must be greater than zero.',
      );
    }
    if (targetsHit < 0 || targetsHit > totalTargets) {
      throw ArgumentError.value(
        targetsHit,
        'targetsHit',
        'targetsHit must be between 0 and totalTargets.',
      );
    }

    final double deviation;
    if (meanPathDeviationMm != null) {
      if (meanPathDeviationMm.isNaN ||
          meanPathDeviationMm.isInfinite ||
          meanPathDeviationMm < 0) {
        throw ArgumentError.value(
          meanPathDeviationMm,
          'meanPathDeviationMm',
          'meanPathDeviationMm must be finite and non-negative.',
        );
      }
      deviation = meanPathDeviationMm;
    } else if (pathDeviationsMm.isEmpty) {
      deviation = 0.0;
    } else {
      var sum = 0.0;
      for (final d in pathDeviationsMm) {
        final v = d.toDouble();
        if (v.isNaN || v.isInfinite || v < 0) {
          throw ArgumentError.value(
            d,
            'pathDeviationsMm',
            'Path deviations must be finite non-negative numbers.',
          );
        }
        sum += v;
      }
      deviation = sum / pathDeviationsMm.length;
    }

    final accuracy = (targetsHit / totalTargets) * 100.0;
    final MotorStatus status;
    if (accuracy >= PvtMptThresholds.mptNominalMinAccuracyPercent &&
        deviation <= PvtMptThresholds.mptNominalMaxDeviationMm) {
      status = MotorStatus.nominal;
    } else if (accuracy >= PvtMptThresholds.mptDegradedMinAccuracyPercent &&
        deviation <= PvtMptThresholds.mptDegradedMaxDeviationMm) {
      status = MotorStatus.degraded;
    } else {
      status = MotorStatus.impaired;
    }

    return MptResult(
      targetsHit: targetsHit,
      totalTargets: totalTargets,
      hitAccuracyPercent: accuracy,
      pathDeviationMm: deviation,
      motorStatus: status,
    );
  }

  /// Authorizes a compensatory stimulant dose (e.g., modafinil 100 mg) ONLY when:
  /// 1) recent antihistamine/antiemetic sedative use is documented,
  /// 2) fatigue is significant (`lrm50Ms > 300` or `lapses >= 3`),
  /// 3) [MedicationSafety.validate] approves the request, and
  /// 4) crew confirmation succeeds via [ConfirmationGate].
  static Future<StimulantCalibrationResult> evaluateStimulantCompensation({
    required ToolContext ctx,
    required double lrm50Ms,
    int lapses = 0,
    String medication = PvtMptThresholds.stimulantDefaultMedication,
    double doseMg = PvtMptThresholds.stimulantDefaultDoseMg,
    String route = 'oral',
    String? recentSedativeName,
    DateTime? sedativeTimestamp,
  }) async {
    final fatigueLevel = classifyFatigue(lrm50Ms: lrm50Ms, lapses: lapses);
    final sedativeSource = await _resolveRecentSedativeSource(
      ctx,
      recentSedativeName: recentSedativeName,
      sedativeTimestamp: sedativeTimestamp,
    );
    final hasSedative = sedativeSource != null;

    if (fatigueLevel != FatigueLevel.significantFatigue || !hasSedative) {
      final reasons = <String>[
        if (fatigueLevel != FatigueLevel.significantFatigue)
          'LRM-50 (${lrm50Ms.toStringAsFixed(1)} ms, $lapses lapses) does not meet significant fatigue threshold (>300 ms or >=3 lapses).',
        if (!hasSedative)
          'No documented recent antihistamine or antiemetic sedative use within ${PvtMptThresholds.sedativeLookbackHours}h.',
      ];
      return StimulantCalibrationResult(
        authorized: false,
        medication: medication,
        doseMg: doseMg,
        route: route,
        fatigueLevel: fatigueLevel,
        lrm50Ms: lrm50Ms,
        lapses: lapses,
        hasRecentSedativeUse: hasSedative,
        sedativeSource: sedativeSource,
        reasons: reasons,
      );
    }

    final medCheck = await ctx.medication.validate(
      MedicationRequest(
        astronautId: ctx.astronautId,
        medication: medication,
        doseMg: doseMg,
        route: route,
        indication:
            'Compensatory stimulant for post-sedative neurocognitive fatigue (LRM-50 ${lrm50Ms.toStringAsFixed(0)} ms)',
      ),
    );

    if (!medCheck.allowed) {
      return StimulantCalibrationResult(
        authorized: false,
        medication: medication,
        doseMg: doseMg,
        route: route,
        fatigueLevel: fatigueLevel,
        lrm50Ms: lrm50Ms,
        lapses: lapses,
        hasRecentSedativeUse: true,
        sedativeSource: sedativeSource,
        medicationCheck: medCheck,
        reasons: medCheck.reasons.isNotEmpty
            ? medCheck.reasons
            : const ['Medication safety validation rejected the request.'],
      );
    }

    final action = ConsequentialAction(
      id: 'stimulant-${ctx.astronautId}-${ctx.now.millisecondsSinceEpoch}',
      astronautId: ctx.astronautId,
      actionType: 'check_stimulant_dose',
      description:
          'Authorize compensatory $medication ${doseMg.toStringAsFixed(0)} mg ($route) after $sedativeSource with LRM-50 ${lrm50Ms.toStringAsFixed(0)} ms.',
      payload: {
        'medication': medication,
        'dose_mg': doseMg,
        'route': route,
        'lrm50_ms': lrm50Ms,
        'lapses': lapses,
        'sedative_source': sedativeSource,
        if (medCheck.batchId != null) 'batch_id': medCheck.batchId,
      },
    );

    final decision = await ctx.confirm.request(
      action,
      onConfirmed: () async {
        final payload = {
          'medication': medication,
          'dose_mg': doseMg,
          'route': route,
          'lrm50_ms': lrm50Ms,
          'lapses': lapses,
          'sedative_source': sedativeSource,
          'authorized_at': ctx.now.toUtc().toIso8601String(),
        };
        await ctx.flags.setFlag(
          ctx.astronautId,
          PvtMptThresholds.flagStimulantAuthorized,
          payload,
        );
        return payload;
      },
    );

    final authorized = decision == ConfirmationDecision.confirmed;
    return StimulantCalibrationResult(
      authorized: authorized,
      medication: medication,
      doseMg: doseMg,
      route: route,
      fatigueLevel: fatigueLevel,
      lrm50Ms: lrm50Ms,
      lapses: lapses,
      hasRecentSedativeUse: true,
      sedativeSource: sedativeSource,
      medicationCheck: medCheck,
      confirmationDecision: decision,
      reasons: authorized
          ? const ['Compensatory stimulant dose confirmed by crew.']
          : ['Crew confirmation decision: ${decision.wireName}.'],
    );
  }

  /// Deterministically blocks a second nocturnal hypnotic dose within the same
  /// sleep window / last 8 hours and logs the block to [AuditLog].
  ///
  /// The first dose in the window proceeds through [MedicationSafety.validate]
  /// and [ConfirmationGate], recording its timestamp in [AgentFlagsStore].
  static Future<HypnoticCalibrationResult> evaluateHypnoticDose({
    required ToolContext ctx,
    String medication = PvtMptThresholds.hypnoticDefaultMedication,
    double doseMg = PvtMptThresholds.hypnoticDefaultDoseMg,
    String route = 'oral',
    String? sleepWindowId,
  }) async {
    final existing = await ctx.flags.getFlag(
      ctx.astronautId,
      PvtMptThresholds.flagLastHypnoticDose,
    );

    if (existing != null) {
      final previousAt = DateTime.tryParse(
        existing['timestamp']?.toString() ?? '',
      );
      final previousWindow = existing['sleep_window_id']?.toString();
      final sameWindow =
          sleepWindowId != null &&
          sleepWindowId.isNotEmpty &&
          previousWindow == sleepWindowId;
      final withinEightHours =
          previousAt != null &&
          !ctx.now.toUtc().isBefore(previousAt.toUtc()) &&
          ctx.now.toUtc().difference(previousAt.toUtc()) <
              const Duration(hours: PvtMptThresholds.hypnoticWindowHours);

      if (sameWindow || withinEightHours) {
        const blockReason =
            'Second nocturnal hypnotic dose deterministically blocked within 8-hour sleep window.';
        await ctx.audit.append(
          AuditEntry(
            id: 'hypnotic-block-${ctx.astronautId}-${ctx.now.millisecondsSinceEpoch}',
            astronautId: ctx.astronautId,
            actionType: 'check_hypnotic_dose',
            description:
                'Blocked second nocturnal hypnotic dose ($medication ${doseMg.toStringAsFixed(0)} mg).',
            payload: {
              'medication': medication,
              'dose_mg': doseMg,
              'route': route,
              'secondNightDoseBlocked': true,
              'previous_dose_at': ?previousAt?.toUtc().toIso8601String(),
              'sleep_window_id': ?sleepWindowId,
            },
            decision: ConfirmationDecision.rejected,
            timestamp: ctx.now.toUtc(),
            reason: blockReason,
          ),
        );

        return HypnoticCalibrationResult(
          authorized: false,
          secondNightDoseBlocked: true,
          medication: medication,
          doseMg: doseMg,
          route: route,
          previousDoseAt: previousAt,
          reasons: const [blockReason],
        );
      }
    }

    final medCheck = await ctx.medication.validate(
      MedicationRequest(
        astronautId: ctx.astronautId,
        medication: medication,
        doseMg: doseMg,
        route: route,
        indication: 'First nocturnal hypnotic dose for sleep window',
      ),
    );

    if (!medCheck.allowed) {
      return HypnoticCalibrationResult(
        authorized: false,
        secondNightDoseBlocked: false,
        medication: medication,
        doseMg: doseMg,
        route: route,
        medicationCheck: medCheck,
        reasons: medCheck.reasons.isNotEmpty
            ? medCheck.reasons
            : const ['Medication safety validation rejected hypnotic request.'],
      );
    }

    final action = ConsequentialAction(
      id: 'hypnotic-${ctx.astronautId}-${ctx.now.millisecondsSinceEpoch}',
      astronautId: ctx.astronautId,
      actionType: 'check_hypnotic_dose',
      description:
          'Authorize nocturnal hypnotic $medication ${doseMg.toStringAsFixed(0)} mg ($route).',
      payload: {
        'medication': medication,
        'dose_mg': doseMg,
        'route': route,
        'sleep_window_id': ?sleepWindowId,
        'batch_id': ?medCheck.batchId,
      },
    );

    final decision = await ctx.confirm.request(
      action,
      onConfirmed: () async {
        final payload = {
          'medication': medication,
          'dose_mg': doseMg,
          'route': route,
          'timestamp': ctx.now.toUtc().toIso8601String(),
          if (sleepWindowId != null && sleepWindowId.isNotEmpty)
            'sleep_window_id': sleepWindowId,
        };
        await ctx.flags.setFlag(
          ctx.astronautId,
          PvtMptThresholds.flagLastHypnoticDose,
          payload,
        );
        return payload;
      },
    );

    final authorized = decision == ConfirmationDecision.confirmed;
    return HypnoticCalibrationResult(
      authorized: authorized,
      secondNightDoseBlocked: false,
      medication: medication,
      doseMg: doseMg,
      route: route,
      medicationCheck: medCheck,
      confirmationDecision: decision,
      reasons: authorized
          ? const ['Nocturnal hypnotic dose confirmed and timestamp recorded.']
          : ['Crew confirmation decision: ${decision.wireName}.'],
    );
  }

  static Future<String?> _resolveRecentSedativeSource(
    ToolContext ctx, {
    String? recentSedativeName,
    DateTime? sedativeTimestamp,
  }) async {
    final nowUtc = ctx.now.toUtc();
    const lookback = Duration(hours: PvtMptThresholds.sedativeLookbackHours);

    bool isWithinWindow(DateTime? ts) {
      if (ts == null) return true;
      final utc = ts.toUtc();
      return !nowUtc.isBefore(utc) && nowUtc.difference(utc) <= lookback;
    }

    if (recentSedativeName != null && recentSedativeName.trim().isNotEmpty) {
      final normalized = recentSedativeName.trim().toLowerCase();
      final recognized = PvtMptThresholds.recognizedSedatives.any(
        normalized.contains,
      );
      if (recognized && isWithinWindow(sedativeTimestamp)) {
        return 'arg:$normalized';
      }
    }

    final flag = await ctx.flags.getFlag(
      ctx.astronautId,
      PvtMptThresholds.flagRecentSedativeUse,
    );
    if (flag != null) {
      final ts = DateTime.tryParse(flag['timestamp']?.toString() ?? '');
      final med = flag['medication']?.toString() ?? 'sedative';
      if (isWithinWindow(ts)) {
        return 'flag:$med';
      }
    }

    final memories = await ctx.memory.recall(
      ctx.astronautId,
      kinds: const {MemoryKind.clinicalEvent, MemoryKind.fact},
      limit: 20,
    );
    for (final entry in memories) {
      if (!isWithinWindow(entry.createdAt)) continue;
      final haystack =
          '${entry.summary} ${entry.tags.join(' ')}'.toLowerCase();
      for (final sedative in PvtMptThresholds.recognizedSedatives) {
        if (haystack.contains(sedative)) {
          return 'memory:$sedative';
        }
      }
    }

    return null;
  }
}
