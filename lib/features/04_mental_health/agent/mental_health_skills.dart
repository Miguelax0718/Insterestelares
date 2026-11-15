import 'package:astramed/features/04_mental_health/agent/pvt_mpt_engine.dart';
import 'package:astramed/features/04_mental_health/agent/voice_diary_engine.dart';
import 'package:astramed/features/04_mental_health/models/sleep_record.dart';
import 'package:astramed/features/agent/domain/agent_contracts.dart';
import 'package:astramed/features/crew/models/astronaut_profile.dart';
import 'package:astramed/features/crew/presentation/providers/crew_provider.dart';

// ---------------------------------------------------------------------------
// Typed ViewModels (D4 / S7)
// ---------------------------------------------------------------------------

class PvtTestViewModel extends AgentViewModel {
  const PvtTestViewModel({
    required this.astronautId,
    this.trialCount = 10,
    this.minStimulusDelayMs = 2000,
    this.maxStimulusDelayMs = 10000,
    this.falseStartThresholdMs = PvtMptThresholds.falseStartThresholdMs,
    this.lapseThresholdMs = PvtMptThresholds.lapseThresholdMs,
    this.lastLrm50Ms,
    this.lastLapses,
    this.lastFatigueLevel,
    super.title = 'Psychomotor Vigilance Task (PVT)',
  }) : super(componentId: ComponentIds.pvtTest);

  factory PvtTestViewModel.fromProps(Map<String, dynamic> props) {
    final astronautId = props['astronaut_id'];
    if (astronautId is! String || astronautId.isEmpty) {
      throw const FormatException('pvt_test requires non-empty astronaut_id.');
    }
    final trialCount = (props['trial_count'] as num?)?.toInt() ?? 10;
    final minDelay = (props['min_stimulus_delay_ms'] as num?)?.toInt() ?? 2000;
    final maxDelay = (props['max_stimulus_delay_ms'] as num?)?.toInt() ?? 10000;
    if (trialCount <= 0 || minDelay < 0 || maxDelay < minDelay) {
      throw const FormatException('pvt_test has invalid trial or delay bounds.');
    }
    return PvtTestViewModel(
      astronautId: astronautId,
      trialCount: trialCount,
      minStimulusDelayMs: minDelay,
      maxStimulusDelayMs: maxDelay,
      falseStartThresholdMs:
          (props['false_start_threshold_ms'] as num?)?.toDouble() ??
          PvtMptThresholds.falseStartThresholdMs,
      lapseThresholdMs:
          (props['lapse_threshold_ms'] as num?)?.toDouble() ??
          PvtMptThresholds.lapseThresholdMs,
      lastLrm50Ms: (props['last_lrm50_ms'] as num?)?.toDouble(),
      lastLapses: (props['last_lapses'] as num?)?.toInt(),
      lastFatigueLevel: props['last_fatigue_level'] as String?,
      title: (props['title'] as String?) ?? 'Psychomotor Vigilance Task (PVT)',
    );
  }

  final String astronautId;
  final int trialCount;
  final int minStimulusDelayMs;
  final int maxStimulusDelayMs;
  final double falseStartThresholdMs;
  final double lapseThresholdMs;
  final double? lastLrm50Ms;
  final int? lastLapses;
  final String? lastFatigueLevel;

  @override
  Map<String, dynamic> toProps() => {
    'component_id': componentId,
    'title': title,
    'astronaut_id': astronautId,
    'trial_count': trialCount,
    'min_stimulus_delay_ms': minStimulusDelayMs,
    'max_stimulus_delay_ms': maxStimulusDelayMs,
    'false_start_threshold_ms': falseStartThresholdMs,
    'lapse_threshold_ms': lapseThresholdMs,
    if (lastLrm50Ms != null) 'last_lrm50_ms': lastLrm50Ms,
    if (lastLapses != null) 'last_lapses': lastLapses,
    if (lastFatigueLevel != null) 'last_fatigue_level': lastFatigueLevel,
  };
}

class MptTestViewModel extends AgentViewModel {
  const MptTestViewModel({
    required this.astronautId,
    this.targetCount = 20,
    this.toleranceMm = PvtMptThresholds.mptNominalMaxDeviationMm,
    this.lastHitAccuracyPercent,
    this.lastPathDeviationMm,
    this.lastMotorStatus,
    super.title = 'Motor Precision Task (MPT)',
  }) : super(componentId: ComponentIds.mptTest);

  factory MptTestViewModel.fromProps(Map<String, dynamic> props) {
    final astronautId = props['astronaut_id'];
    if (astronautId is! String || astronautId.isEmpty) {
      throw const FormatException('mpt_test requires non-empty astronaut_id.');
    }
    final targetCount = (props['target_count'] as num?)?.toInt() ?? 20;
    final toleranceMm =
        (props['tolerance_mm'] as num?)?.toDouble() ??
        PvtMptThresholds.mptNominalMaxDeviationMm;
    if (targetCount <= 0 || toleranceMm <= 0) {
      throw const FormatException('mpt_test requires positive target_count and tolerance_mm.');
    }
    return MptTestViewModel(
      astronautId: astronautId,
      targetCount: targetCount,
      toleranceMm: toleranceMm,
      lastHitAccuracyPercent:
          (props['last_hit_accuracy_percent'] as num?)?.toDouble(),
      lastPathDeviationMm:
          (props['last_path_deviation_mm'] as num?)?.toDouble(),
      lastMotorStatus: props['last_motor_status'] as String?,
      title: (props['title'] as String?) ?? 'Motor Precision Task (MPT)',
    );
  }

  final String astronautId;
  final int targetCount;
  final double toleranceMm;
  final double? lastHitAccuracyPercent;
  final double? lastPathDeviationMm;
  final String? lastMotorStatus;

  @override
  Map<String, dynamic> toProps() => {
    'component_id': componentId,
    'title': title,
    'astronaut_id': astronautId,
    'target_count': targetCount,
    'tolerance_mm': toleranceMm,
    if (lastHitAccuracyPercent != null)
      'last_hit_accuracy_percent': lastHitAccuracyPercent,
    if (lastPathDeviationMm != null)
      'last_path_deviation_mm': lastPathDeviationMm,
    if (lastMotorStatus != null) 'last_motor_status': lastMotorStatus,
  };
}

class DiaryRecorderViewModel extends AgentViewModel {
  const DiaryRecorderViewModel({
    required this.astronautId,
    required this.prompts,
    this.maxDurationSeconds = 90,
    this.sleepHoursLastNight,
    this.morningMood,
    super.title = 'Daily Voice Diary',
  }) : super(componentId: ComponentIds.diaryRecorder);

  factory DiaryRecorderViewModel.fromProps(Map<String, dynamic> props) {
    final astronautId = props['astronaut_id'];
    if (astronautId is! String || astronautId.isEmpty) {
      throw const FormatException('diary_recorder requires non-empty astronaut_id.');
    }
    final rawPrompts = props['prompts'];
    if (rawPrompts is! List || rawPrompts.isEmpty) {
      throw const FormatException('diary_recorder requires a non-empty prompts list.');
    }
    final prompts = rawPrompts.map((e) => e.toString()).toList();
    final maxDuration = (props['max_duration_seconds'] as num?)?.toInt() ?? 90;
    if (maxDuration <= 0) {
      throw const FormatException('diary_recorder max_duration_seconds must be positive.');
    }
    return DiaryRecorderViewModel(
      astronautId: astronautId,
      prompts: prompts,
      maxDurationSeconds: maxDuration,
      sleepHoursLastNight:
          (props['sleep_hours_last_night'] as num?)?.toDouble(),
      morningMood: props['morning_mood'] as String?,
      title: (props['title'] as String?) ?? 'Daily Voice Diary',
    );
  }

  final String astronautId;
  final List<String> prompts;
  final int maxDurationSeconds;
  final double? sleepHoursLastNight;
  final String? morningMood;

  @override
  Map<String, dynamic> toProps() => {
    'component_id': componentId,
    'title': title,
    'astronaut_id': astronautId,
    'prompts': prompts,
    'max_duration_seconds': maxDurationSeconds,
    if (sleepHoursLastNight != null)
      'sleep_hours_last_night': sleepHoursLastNight,
    if (morningMood != null) 'morning_mood': morningMood,
  };
}

class RecommendationsViewModel extends AgentViewModel {
  const RecommendationsViewModel({
    required this.astronautId,
    required this.riskLevel,
    required this.centralFatigueDetected,
    required this.detectedMarkers,
    required this.sleepHours,
    required this.recommendations,
    required this.summary,
    super.title = 'Adaptive Behavioral Recommendations',
  }) : super(componentId: ComponentIds.recommendations);

  factory RecommendationsViewModel.fromProps(Map<String, dynamic> props) {
    final astronautId = props['astronaut_id'];
    final riskLevel = props['risk_level'];
    final centralFatigue = props['central_fatigue_detected'];
    final sleepHours = props['sleep_hours'];
    final summary = props['summary'];
    final rawRecs = props['recommendations'];

    if (astronautId is! String ||
        astronautId.isEmpty ||
        riskLevel is! String ||
        centralFatigue is! bool ||
        sleepHours is! num ||
        summary is! String ||
        rawRecs is! List) {
      throw const FormatException('Invalid recommendations component props.');
    }

    final markers = (props['detected_markers'] as List<dynamic>? ?? const [])
        .map((e) => e.toString())
        .toList();
    final recs = rawRecs
        .whereType<Map<String, dynamic>>()
        .map(DiaryRecommendation.fromJson)
        .toList();
    if (recs.length != rawRecs.length) {
      throw const FormatException('Invalid recommendation item in props.');
    }

    return RecommendationsViewModel(
      astronautId: astronautId,
      riskLevel: riskLevel,
      centralFatigueDetected: centralFatigue,
      detectedMarkers: markers,
      sleepHours: sleepHours.toDouble(),
      recommendations: recs,
      summary: summary,
      title: (props['title'] as String?) ?? 'Adaptive Behavioral Recommendations',
    );
  }

  final String astronautId;
  final String riskLevel;
  final bool centralFatigueDetected;
  final List<String> detectedMarkers;
  final double sleepHours;
  final List<DiaryRecommendation> recommendations;
  final String summary;

  @override
  Map<String, dynamic> toProps() => {
    'component_id': componentId,
    'title': title,
    'astronaut_id': astronautId,
    'risk_level': riskLevel,
    'central_fatigue_detected': centralFatigueDetected,
    'detected_markers': detectedMarkers,
    'sleep_hours': sleepHours,
    'recommendations': recommendations.map((r) => r.toJson()).toList(),
    'summary': summary,
  };
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

SleepRecord _resolveSleepRecord(
  ToolContext ctx, {
  double? sleepHoursOverride,
  int? wakeEpisodesOverride,
  MoodLevel? moodOverride,
}) {
  SleepRecord base = SleepRecord(
    date: ctx.now,
    astronautId: ctx.astronautId,
    sleepHours: 7.0,
    wakeEpisodes: 0,
    morningMood: MoodLevel.neutral,
  );

  try {
    final crew = ctx.read<List<AstronautProfile>>(crewMembersProvider);
    for (final member in crew) {
      if (member.id == ctx.astronautId) {
        base = member.sleep;
        break;
      }
    }
  } catch (_) {
    // Fallback when crewMembersProvider is not bound in isolated unit tests.
  }

  return base.copyWith(
    sleepHours: sleepHoursOverride,
    wakeEpisodes: wakeEpisodesOverride,
    morningMood: moodOverride,
  );
}

ToolResult _emitAndReturn(
  ToolContext ctx,
  AgentComponentEvent event,
  Map<String, dynamic> data,
) {
  ctx.ui.emit(event);
  return ToolResult.ok(data, uiEvents: [event]);
}

// ---------------------------------------------------------------------------
// Cognition Skill Tools
// ---------------------------------------------------------------------------

class StartPvtTool extends AgentTool {
  const StartPvtTool();

  @override
  String get name => 'start_pvt';

  @override
  String get description =>
      'Launch the interactive Psychomotor Vigilance Task (PVT) UI component to measure reaction times and LRM-50.';

  @override
  ToolEffect get effect => ToolEffect.ui;

  @override
  Map<String, dynamic> get parameters => const {
    'type': 'object',
    'properties': {
      'trial_count': {
        'type': 'integer',
        'description': 'Number of PVT stimulus trials (default 10).',
      },
    },
  };

  @override
  Future<ToolResult> call(Map<String, dynamic> args, ToolContext ctx) async {
    final trialCount = (args['trial_count'] as num?)?.toInt() ?? 10;
    final vm = PvtTestViewModel(
      astronautId: ctx.astronautId,
      trialCount: trialCount > 0 ? trialCount : 10,
    );
    final event = AgentComponentEvent.show(ComponentIds.pvtTest, vm.toProps());
    return _emitAndReturn(ctx, event, {
      'component': ComponentIds.pvtTest,
      'trial_count': vm.trialCount,
    });
  }
}

class StartMptTool extends AgentTool {
  const StartMptTool();

  @override
  String get name => 'start_mpt';

  @override
  String get description =>
      'Launch the Motor Precision Task (MPT) UI component to measure hit accuracy and path deviation.';

  @override
  ToolEffect get effect => ToolEffect.ui;

  @override
  Map<String, dynamic> get parameters => const {
    'type': 'object',
    'properties': {
      'target_count': {
        'type': 'integer',
        'description': 'Number of motor precision targets (default 20).',
      },
    },
  };

  @override
  Future<ToolResult> call(Map<String, dynamic> args, ToolContext ctx) async {
    final targetCount = (args['target_count'] as num?)?.toInt() ?? 20;
    final vm = MptTestViewModel(
      astronautId: ctx.astronautId,
      targetCount: targetCount > 0 ? targetCount : 20,
    );
    final event = AgentComponentEvent.show(ComponentIds.mptTest, vm.toProps());
    return _emitAndReturn(ctx, event, {
      'component': ComponentIds.mptTest,
      'target_count': vm.targetCount,
    });
  }
}

class ComputeLrm50Tool extends AgentTool {
  const ComputeLrm50Tool();

  @override
  String get name => 'compute_lrm50';

  @override
  String get description =>
      'Compute LRM-50 median reaction time, false starts, lapses, and fatigue level from PVT trials (and optional MPT metrics).';

  @override
  ToolEffect get effect => ToolEffect.read;

  @override
  Map<String, dynamic> get parameters => const {
    'type': 'object',
    'properties': {
      'reaction_times_ms': {
        'type': 'array',
        'items': {'type': 'number'},
        'description': 'PVT reaction time trials in milliseconds.',
      },
      'targets_hit': {'type': 'integer'},
      'total_targets': {'type': 'integer'},
      'path_deviations_mm': {
        'type': 'array',
        'items': {'type': 'number'},
      },
    },
    'required': ['reaction_times_ms'],
  };

  @override
  Future<ToolResult> call(Map<String, dynamic> args, ToolContext ctx) async {
    final rawTrials = args['reaction_times_ms'];
    if (rawTrials is! List || rawTrials.isEmpty) {
      return const ToolResult.fail(
        'reaction_times_ms must be a non-empty list of numbers.',
      );
    }

    try {
      final trials = rawTrials.cast<num>();
      final pvt = PvtMptEngine.evaluatePvt(trials);
      final data = <String, dynamic>{...pvt.toJson()};

      final targetsHit = (args['targets_hit'] as num?)?.toInt();
      final totalTargets = (args['total_targets'] as num?)?.toInt();
      if (targetsHit != null && totalTargets != null) {
        final rawDev = args['path_deviations_mm'] as List<dynamic>? ?? const [];
        final mpt = PvtMptEngine.evaluateMpt(
          targetsHit: targetsHit,
          totalTargets: totalTargets,
          pathDeviationsMm: rawDev.whereType<num>().toList(),
        );
        data['mpt'] = mpt.toJson();
      }

      return ToolResult.ok(data);
    } on Object catch (e) {
      return ToolResult.fail(e.toString());
    }
  }
}

class CheckStimulantDoseTool extends AgentTool {
  const CheckStimulantDoseTool();

  @override
  String get name => 'check_stimulant_dose';

  @override
  String get description =>
      'Evaluate whether a compensatory stimulant dose (e.g. modafinil 100 mg) is authorized after sedative use and elevated LRM-50; requires medication safety and crew confirmation.';

  @override
  ToolEffect get effect => ToolEffect.consequential;

  @override
  Map<String, dynamic> get parameters => const {
    'type': 'object',
    'properties': {
      'lrm50_ms': {
        'type': 'number',
        'description': 'Measured LRM-50 reaction time median in ms.',
      },
      'lapses': {
        'type': 'integer',
        'description': 'Number of PVT lapses (>500 ms).',
      },
      'medication': {
        'type': 'string',
        'description': 'Stimulant name (default modafinil).',
      },
      'dose_mg': {
        'type': 'number',
        'description': 'Requested dose in mg (default 100).',
      },
      'route': {
        'type': 'string',
        'description': 'Administration route (default oral).',
      },
      'recent_sedative': {
        'type': 'string',
        'description': 'Optional recent antihistamine/antiemetic name if reported.',
      },
    },
    'required': ['lrm50_ms'],
  };

  @override
  Future<ToolResult> call(Map<String, dynamic> args, ToolContext ctx) async {
    final lrm50 = (args['lrm50_ms'] as num?)?.toDouble();
    if (lrm50 == null || lrm50 < 0) {
      return const ToolResult.fail('lrm50_ms must be a non-negative number.');
    }
    final lapses = (args['lapses'] as num?)?.toInt() ?? 0;
    final medication =
        (args['medication'] as String?)?.trim().isNotEmpty == true
        ? (args['medication'] as String).trim()
        : PvtMptThresholds.stimulantDefaultMedication;
    final doseMg =
        (args['dose_mg'] as num?)?.toDouble() ??
        PvtMptThresholds.stimulantDefaultDoseMg;
    final route = (args['route'] as String?)?.trim().isNotEmpty == true
        ? (args['route'] as String).trim()
        : 'oral';
    final recentSedative = args['recent_sedative'] as String?;

    final result = await PvtMptEngine.evaluateStimulantCompensation(
      ctx: ctx,
      lrm50Ms: lrm50,
      lapses: lapses,
      medication: medication,
      doseMg: doseMg,
      route: route,
      recentSedativeName: recentSedative,
    );

    final event = AgentComponentEvent.show(
      ComponentIds.medicationCheck,
      result.toJson(),
    );
    return _emitAndReturn(ctx, event, result.toJson());
  }
}

class CheckHypnoticDoseTool extends AgentTool {
  const CheckHypnoticDoseTool();

  @override
  String get name => 'check_hypnotic_dose';

  @override
  String get description =>
      'Check and authorize a nocturnal hypnotic dose (e.g. zolpidem). Deterministically blocks a second nighttime dose within 8 hours.';

  @override
  ToolEffect get effect => ToolEffect.consequential;

  @override
  Map<String, dynamic> get parameters => const {
    'type': 'object',
    'properties': {
      'medication': {
        'type': 'string',
        'description': 'Hypnotic medication name (default zolpidem).',
      },
      'dose_mg': {
        'type': 'number',
        'description': 'Requested dose in mg (default 5).',
      },
      'route': {
        'type': 'string',
        'description': 'Administration route (default oral).',
      },
      'sleep_window_id': {
        'type': 'string',
        'description': 'Optional sleep window identifier.',
      },
    },
  };

  @override
  Future<ToolResult> call(Map<String, dynamic> args, ToolContext ctx) async {
    final medication =
        (args['medication'] as String?)?.trim().isNotEmpty == true
        ? (args['medication'] as String).trim()
        : PvtMptThresholds.hypnoticDefaultMedication;
    final doseMg =
        (args['dose_mg'] as num?)?.toDouble() ??
        PvtMptThresholds.hypnoticDefaultDoseMg;
    final route = (args['route'] as String?)?.trim().isNotEmpty == true
        ? (args['route'] as String).trim()
        : 'oral';
    final sleepWindowId = args['sleep_window_id'] as String?;

    final result = await PvtMptEngine.evaluateHypnoticDose(
      ctx: ctx,
      medication: medication,
      doseMg: doseMg,
      route: route,
      sleepWindowId: sleepWindowId,
    );

    final event = AgentComponentEvent.show(
      ComponentIds.medicationCheck,
      result.toJson(),
    );
    return _emitAndReturn(ctx, event, result.toJson());
  }
}

// ---------------------------------------------------------------------------
// Diary Skill Tools
// ---------------------------------------------------------------------------

class StartDiaryTool extends AgentTool {
  const StartDiaryTool();

  @override
  String get name => 'start_diary';

  @override
  String get description =>
      'Launch the structured daily voice diary recorder UI component.';

  @override
  ToolEffect get effect => ToolEffect.ui;

  @override
  Map<String, dynamic> get parameters => const {
    'type': 'object',
    'properties': {
      'max_duration_seconds': {
        'type': 'integer',
        'description': 'Maximum recording length in seconds (default 90).',
      },
    },
  };

  @override
  Future<ToolResult> call(Map<String, dynamic> args, ToolContext ctx) async {
    final sleep = _resolveSleepRecord(ctx);
    final maxDuration = (args['max_duration_seconds'] as num?)?.toInt() ?? 90;
    final vm = DiaryRecorderViewModel(
      astronautId: ctx.astronautId,
      prompts: const [
        'How did you sleep and how is your energy right now?',
        'Any stress, isolation, crew friction, or drowsiness today?',
        'Any operational events affecting your rest?',
      ],
      maxDurationSeconds: maxDuration > 0 ? maxDuration : 90,
      sleepHoursLastNight: sleep.sleepHours,
      morningMood: sleep.morningMood.name,
    );
    final event = AgentComponentEvent.show(
      ComponentIds.diaryRecorder,
      vm.toProps(),
    );
    return _emitAndReturn(ctx, event, {
      'component': ComponentIds.diaryRecorder,
      'sleep_hours_last_night': sleep.sleepHours,
      'morning_mood': sleep.morningMood.name,
    });
  }
}

class AnalyzeDiaryTool extends AgentTool {
  const AnalyzeDiaryTool();

  @override
  String get name => 'analyze_diary';

  @override
  String get description =>
      'Analyze daily voice diary transcript (EN/ES markers for stress, isolation, conflict, Sopite) and acoustic cadence with sleep history, saving a clinical event.';

  @override
  ToolEffect get effect => ToolEffect.read;

  @override
  Map<String, dynamic> get parameters => const {
    'type': 'object',
    'properties': {
      'transcript': {
        'type': 'string',
        'description': 'Voice diary transcript text.',
      },
      'words_per_minute': {'type': 'number'},
      'pause_ratio': {'type': 'number'},
      'mean_pause_ms': {'type': 'number'},
      'pitch_monotony': {'type': 'number'},
      'sleep_hours': {'type': 'number'},
      'wake_episodes': {'type': 'integer'},
    },
    'required': ['transcript'],
  };

  @override
  Future<ToolResult> call(Map<String, dynamic> args, ToolContext ctx) async {
    final transcript = args['transcript'];
    if (transcript is! String || transcript.trim().isEmpty) {
      return const ToolResult.fail('transcript must be a non-empty string.');
    }

    final wpm = (args['words_per_minute'] as num?)?.toDouble();
    final pauseRatio = (args['pause_ratio'] as num?)?.toDouble();
    final meanPauseMs = (args['mean_pause_ms'] as num?)?.toDouble();
    final pitchMonotony = (args['pitch_monotony'] as num?)?.toDouble();

    final SpeechCadenceMetrics? cadence =
        (wpm != null ||
            pauseRatio != null ||
            meanPauseMs != null ||
            pitchMonotony != null)
        ? SpeechCadenceMetrics(
            wordsPerMinute: wpm ?? 130.0,
            pauseRatio: pauseRatio ?? 0.18,
            meanPauseMs: meanPauseMs ?? 380.0,
            pitchMonotony: pitchMonotony ?? 0.35,
          )
        : null;

    final sleep = _resolveSleepRecord(
      ctx,
      sleepHoursOverride: (args['sleep_hours'] as num?)?.toDouble(),
      wakeEpisodesOverride: (args['wake_episodes'] as num?)?.toInt(),
    );

    final result = await VoiceDiaryEngine.analyzeAndPersist(
      ctx: ctx,
      transcript: transcript,
      cadence: cadence,
      sleepRecord: sleep,
    );

    return ToolResult.ok(result.toJson());
  }
}

class GetRecommendationsTool extends AgentTool {
  const GetRecommendationsTool();

  @override
  String get name => 'get_recommendations';

  @override
  String get description =>
      'Generate and display adaptive sleep, nap, nutrition/hydration, and disconnection/social recommendations.';

  @override
  ToolEffect get effect => ToolEffect.ui;

  @override
  Map<String, dynamic> get parameters => const {
    'type': 'object',
    'properties': {
      'semantic_markers': {
        'type': 'array',
        'items': {'type': 'string'},
      },
      'central_fatigue_detected': {'type': 'boolean'},
      'sleep_hours': {'type': 'number'},
      'wake_episodes': {'type': 'integer'},
    },
  };

  @override
  Future<ToolResult> call(Map<String, dynamic> args, ToolContext ctx) async {
    final sleep = _resolveSleepRecord(
      ctx,
      sleepHoursOverride: (args['sleep_hours'] as num?)?.toDouble(),
      wakeEpisodesOverride: (args['wake_episodes'] as num?)?.toInt(),
    );

    final rawMarkers = args['semantic_markers'] as List<dynamic>? ?? const [];
    final markers = <SemanticMarkerCategory>{};
    for (final raw in rawMarkers) {
      final parsed = SemanticMarkerCategory.tryFromWire(raw.toString());
      if (parsed != null) markers.add(parsed);
    }

    final centralFatigue = args['central_fatigue_detected'] as bool? ?? false;
    final recommendations = VoiceDiaryEngine.generateRecommendations(
      markers: markers,
      centralFatigueDetected: centralFatigue,
      sleepHours: sleep.sleepHours,
      wakeEpisodes: sleep.wakeEpisodes,
      morningMood: sleep.morningMood,
    );

    final riskLevel = centralFatigue || markers.length >= 2
        ? 'elevated'
        : (markers.isNotEmpty ||
                  sleep.sleepHours < VoiceDiaryThresholds.minRecommendedSleepHours)
              ? 'caution'
              : 'nominal';

    final vm = RecommendationsViewModel(
      astronautId: ctx.astronautId,
      riskLevel: riskLevel,
      centralFatigueDetected: centralFatigue,
      detectedMarkers: markers.map((m) => m.wireName).toList(),
      sleepHours: sleep.sleepHours,
      recommendations: recommendations,
      summary:
          'Adaptive countermeasures for ${sleep.sleepHours.toStringAsFixed(1)}h sleep ($riskLevel).',
    );

    final event = AgentComponentEvent.show(
      ComponentIds.recommendations,
      vm.toProps(),
    );
    return _emitAndReturn(ctx, event, vm.toProps());
  }
}

// ---------------------------------------------------------------------------
// Offline Deterministic Flow (S9)
// ---------------------------------------------------------------------------

class DailyDiaryOfflineFlow implements DeterministicFlow {
  int _step = 0;
  String _transcript = '';

  @override
  String get skillId => 'diary';

  @override
  Future<DeterministicStep> start(ToolContext ctx) async {
    _step = 1;
    _transcript = '';
    final sleep = _resolveSleepRecord(ctx);
    final vm = DiaryRecorderViewModel(
      astronautId: ctx.astronautId,
      prompts: const [
        'Describe your energy, mood, rest quality, and any crew or mission stress today.',
      ],
      sleepHoursLastNight: sleep.sleepHours,
      morningMood: sleep.morningMood.name,
    );
    final event = AgentComponentEvent.show(
      ComponentIds.diaryRecorder,
      vm.toProps(),
    );
    ctx.ui.emit(event);
    return DeterministicStep(
      prompt:
          'Daily check-in: how do you feel today? Report energy, rest, stress, isolation, or drowsiness.',
      options: const [
        'Rested and nominal',
        'Fatigued, yawning, low drive',
        'Stressed or isolated',
        'Crew friction today',
      ],
      uiEvents: [event],
    );
  }

  @override
  Future<DeterministicStep> advance(String userInput, ToolContext ctx) async {
    if (_step <= 1) {
      _transcript = userInput.trim();
      _step = 2;
      return const DeterministicStep(
        prompt: 'How many hours did you sleep last night?',
        options: ['< 5.5 hours', '5.5 - 6.5 hours', '7+ hours'],
      );
    }

    final parsedHours = _parseSleepHours(userInput);
    final sleep = _resolveSleepRecord(ctx, sleepHoursOverride: parsedHours);

    final analysis = await VoiceDiaryEngine.analyzeAndPersist(
      ctx: ctx,
      transcript: _transcript.isEmpty ? userInput : _transcript,
      sleepRecord: sleep,
    );

    final vm = RecommendationsViewModel(
      astronautId: ctx.astronautId,
      riskLevel: analysis.riskLevel,
      centralFatigueDetected: analysis.centralFatigueDetected,
      detectedMarkers:
          analysis.semanticMarkers.map((m) => m.wireName).toList(),
      sleepHours: analysis.sleepHours,
      recommendations: analysis.recommendations,
      summary:
          'Offline diary check-in complete (${analysis.riskLevel}, ${analysis.sleepHours.toStringAsFixed(1)}h sleep).',
    );
    final recEvent = AgentComponentEvent.show(
      ComponentIds.recommendations,
      vm.toProps(),
    );
    ctx.ui.emit(recEvent);
    _step = 0;

    return DeterministicStep(
      prompt:
          'Check-in saved (${analysis.riskLevel}). Primary action: ${analysis.recommendations.first.title}.',
      uiEvents: [recEvent],
      isTerminal: true,
      verdict: analysis.toJson(),
    );
  }

  double? _parseSleepHours(String input) {
    final normalized = input.toLowerCase();
    if (normalized.contains('< 5.5')) return 5.0;
    if (normalized.contains('5.5 - 6.5')) return 6.0;
    if (normalized.contains('7+')) return 7.5;
    final match = RegExp(r'(\d+(?:\.\d+)?)').firstMatch(normalized);
    if (match != null) {
      return double.tryParse(match.group(1)!);
    }
    return null;
  }
}

// ---------------------------------------------------------------------------
// Skill Exports (D5)
// ---------------------------------------------------------------------------

List<AgentSkill> mentalHealthSkills() => [
  const AgentSkill(
    id: 'cognition',
    instructions:
        'Run PVT/MPT tests via start_pvt/start_mpt and score LRM-50 with compute_lrm50. '
        'Only consider compensatory stimulants via check_stimulant_dose after recent sedative use when LRM-50 > 300 ms or lapses >= 3. '
        'Never authorize a second nocturnal hypnotic dose within 8 hours; always validate via check_hypnotic_dose.',
    tools: [
      StartPvtTool(),
      StartMptTool(),
      ComputeLrm50Tool(),
      CheckStimulantDoseTool(),
      CheckHypnoticDoseTool(),
    ],
    componentIds: [
      ComponentIds.pvtTest,
      ComponentIds.mptTest,
      ComponentIds.medicationCheck,
    ],
    triggers: [
      'pvt',
      'mpt',
      'lrm-50',
      'lrm50',
      'reaction time',
      'fatigue',
      'fatiga',
      'stimulant',
      'modafinil',
      'hypnotic',
      'zolpidem',
      'sleep med',
      'somnifero',
      'cognitive',
      'cognitivo',
    ],
  ),
  AgentSkill(
    id: 'diary',
    instructions:
        'Guide the daily voice diary with start_diary, analyze transcripts and speech cadence with analyze_diary, '
        'and deliver tailored circadian/behavioral steps with get_recommendations. Keep prompts brief and natural.',
    tools: const [
      StartDiaryTool(),
      AnalyzeDiaryTool(),
      GetRecommendationsTool(),
    ],
    componentIds: const [
      ComponentIds.diaryRecorder,
      ComponentIds.recommendations,
    ],
    triggers: const [
      'diary',
      'bitacora',
      'bitácora',
      'journal',
      'voice diary',
      'mood',
      'animo',
      'ánimo',
      'stress',
      'estres',
      'estrés',
      'isolated',
      'aislado',
      'sopite',
      'recommendations',
      'recomendaciones',
      'sleep',
      'sueno',
      'sueño',
    ],
    offlineFlow: DailyDiaryOfflineFlow(),
  ),
];
