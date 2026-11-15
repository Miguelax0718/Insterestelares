import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../crew/data/mock_crew_data.dart';
import '../domain/apolo_biomarker_engine.dart';
import '../domain/apolo_models.dart';

class _ApoloCrewPreset {
  const _ApoloCrewPreset({
    required this.astronautId,
    required this.apoloKey,
    required this.colorHex,
    required this.doseMsv,
    required this.waterMlToday,
    required this.waterGoalMl,
    required this.sleepHours,
    required this.resistanceSessionsWeek,
    required this.exerciseMinToday,
    required this.exerciseGoalMin,
    required this.targetValues,
    required this.recommendations,
  });

  final String astronautId;
  final String apoloKey;
  final int colorHex;
  final double doseMsv;
  final int waterMlToday;
  final int waterGoalMl;
  final double sleepHours;
  final int resistanceSessionsWeek;
  final int exerciseMinToday;
  final int exerciseGoalMin;
  final Map<String, double> targetValues;
  final List<ApoloRecommendation> recommendations;
}

class ApoloRepository {
  ApoloRepository({DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  static const String defaultMissionName = 'Artemis Gateway';
  static const int defaultMissionDay = 142;
  static const int defaultTotalMissionDays = 180;
  static const double defaultDoseLimitMsv = 600.0;

  static const Map<String, String> aliasToAstronautId = {
    'ana': 'AST-01',
    'sami': 'AST-02',
    'mateo': 'AST-03',
    'yuki': 'AST-04',
    'leo': 'AST-05',
  };

  static final List<_ApoloCrewPreset> _presets = [
    _ApoloCrewPreset(
      astronautId: 'AST-01',
      apoloKey: 'ana',
      colorHex: 0xFFB3E9C7,
      doseMsv: 142,
      waterMlToday: 1700,
      waterGoalMl: 2500,
      sleepHours: 7.3,
      resistanceSessionsWeek: 3,
      exerciseMinToday: 45,
      exerciseGoalMin: 90,
      targetValues: const {
        'vol': 1.4,
        'dens': 1.028,
        'osm': 890,
        'color': 5,
        'ca': 290,
        'ox': 42,
        'cit': 380,
        'ph': 5.9,
      },
      recommendations: const [
        ApoloRecommendation(
          id: 'ana1',
          moduleId: ApoloModuleId.hidratacion,
          priority: 'High',
          text: 'Drink 500 ml of water in the next 2 hours',
          why: 'Your urine specific gravity is 1.028, above your personal range (1.005-1.025).',
        ),
        ApoloRecommendation(
          id: 'ana2',
          moduleId: ApoloModuleId.renal,
          priority: 'High',
          text: 'Raise your fluid goal to 2.5 L today',
          why: 'High urinary calcium with low urine volume increases calcium oxalate saturation.',
        ),
        ApoloRecommendation(
          id: 'ana3',
          moduleId: ApoloModuleId.osea,
          priority: 'Medium',
          text: 'Complete your pending resistance session',
          why: 'You have completed 3 of 4 sessions this week. Resistive exercise slows bone resorption.',
        ),
        ApoloRecommendation(
          id: 'ana4',
          moduleId: ApoloModuleId.radiacion,
          priority: 'Low',
          text: 'Include berries or tomatoes at dinner',
          why: 'Antioxidants help keep your oxidative damage marker stable.',
        ),
        ApoloRecommendation(
          id: 'ana5',
          moduleId: ApoloModuleId.cardio,
          priority: 'Low',
          text: 'Choose low-sodium rations today',
          why: 'Keeping sodium in range protects your fluid balance.',
          done: true,
        ),
      ],
    ),
    _ApoloCrewPreset(
      astronautId: 'AST-02',
      apoloKey: 'sami',
      colorHex: 0xFFFFD23F,
      doseMsv: 140,
      waterMlToday: 2200,
      waterGoalMl: 2500,
      sleepHours: 5.1,
      resistanceSessionsWeek: 4,
      exerciseMinToday: 60,
      exerciseGoalMin: 90,
      targetValues: const {'cort': 92, 'mel': 7},
      recommendations: const [
        ApoloRecommendation(
          id: 'sami1',
          moduleId: ApoloModuleId.estres,
          priority: 'High',
          text: 'Turn off screens one hour before sleep',
          why: 'Your melatonin dropped to 7 ug/day and you slept 5 h 06 min last night.',
        ),
        ApoloRecommendation(
          id: 'sami2',
          moduleId: ApoloModuleId.estres,
          priority: 'High',
          text: 'Do 5 minutes of guided breathing now',
          why: 'Your free cortisol is 92 ug/day, above your personal range (20-70).',
        ),
        ApoloRecommendation(
          id: 'sami3',
          moduleId: ApoloModuleId.estres,
          priority: 'Medium',
          text: 'Schedule a call with your family',
          why: 'Contact with loved ones reduces isolation stress.',
        ),
        ApoloRecommendation(
          id: 'sami4',
          moduleId: ApoloModuleId.inmunidad,
          priority: 'Low',
          text: 'Ask the commander to adjust tomorrow\'s shift',
          why: 'Sustained stress weakens immune defenses; rest helps prevent illness.',
        ),
      ],
    ),
    _ApoloCrewPreset(
      astronautId: 'AST-03',
      apoloKey: 'mateo',
      colorHex: 0xFF8367C7,
      doseMsv: 188,
      waterMlToday: 2400,
      waterGoalMl: 2600,
      sleepHours: 6.8,
      resistanceSessionsWeek: 4,
      exerciseMinToday: 75,
      exerciseGoalMin: 90,
      targetValues: const {'ohdg': 11.2, 'iso': 1.6},
      recommendations: const [
        ApoloRecommendation(
          id: 'mateo1',
          moduleId: ApoloModuleId.radiacion,
          priority: 'High',
          text: 'Stay in the shielded zone for the next 12 hours',
          why: 'Your 8-OHdG rose to 11.2, the highest in the crew, after your latest EVA.',
        ),
        ApoloRecommendation(
          id: 'mateo2',
          moduleId: ApoloModuleId.radiacion,
          priority: 'High',
          text: 'Postpone your next spacewalk (EVA)',
          why: 'Your cumulative dose is 188 mSv; your body needs time to repair oxidative damage.',
        ),
        ApoloRecommendation(
          id: 'mateo3',
          moduleId: ApoloModuleId.radiacion,
          priority: 'Medium',
          text: 'Increase antioxidants: berries and tomatoes',
          why: 'Your isoprostanes (1.6) indicate elevated oxidative stress.',
        ),
      ],
    ),
    _ApoloCrewPreset(
      astronautId: 'AST-04',
      apoloKey: 'yuki',
      colorHex: 0xFFC2F8CB,
      doseMsv: 141,
      waterMlToday: 1900,
      waterGoalMl: 2400,
      sleepHours: 6.9,
      resistanceSessionsWeek: 3,
      exerciseMinToday: 50,
      exerciseGoalMin: 90,
      targetValues: const {'leu': 6, 'nit': 1},
      recommendations: const [
        ApoloRecommendation(
          id: 'yuki1',
          moduleId: ApoloModuleId.inmunidad,
          priority: 'High',
          text: 'Collect a follow-up sample tomorrow at 07:00',
          why: 'Positive nitrites and 6 leukocytes per HPF may indicate a urinary tract infection.',
        ),
        ApoloRecommendation(
          id: 'yuki2',
          moduleId: ApoloModuleId.inmunidad,
          priority: 'High',
          text: 'Notify the Chief Medical Officer',
          why: 'An infection is treated more effectively when detected early.',
        ),
        ApoloRecommendation(
          id: 'yuki3',
          moduleId: ApoloModuleId.hidratacion,
          priority: 'Medium',
          text: 'Drink an extra 500 ml today',
          why: 'Higher urine output helps flush bacteria.',
        ),
      ],
    ),
    _ApoloCrewPreset(
      astronautId: 'AST-05',
      apoloKey: 'leo',
      colorHex: 0xFFA994E0,
      doseMsv: 139,
      waterMlToday: 2300,
      waterGoalMl: 2700,
      sleepHours: 7.0,
      resistanceSessionsWeek: 1,
      exerciseMinToday: 20,
      exerciseGoalMin: 90,
      targetValues: const {'ntx': 64, 'ctx': 530},
      recommendations: const [
        ApoloRecommendation(
          id: 'leo1',
          moduleId: ApoloModuleId.osea,
          priority: 'High',
          text: 'Complete 2 resistance sessions before Sunday',
          why: 'Your NTx rose to 64, above your range (20-60): your bones are losing mineral faster.',
        ),
        ApoloRecommendation(
          id: 'leo2',
          moduleId: ApoloModuleId.osea,
          priority: 'Medium',
          text: 'Take your vitamin D supplement with lunch',
          why: 'Vitamin D helps fix calcium in bone tissue.',
        ),
        ApoloRecommendation(
          id: 'leo3',
          moduleId: ApoloModuleId.metabolismo,
          priority: 'Medium',
          text: 'Add a serving of protein at dinner',
          why: 'Your protein intake is 45% below goal and muscle helps protect bone.',
        ),
        ApoloRecommendation(
          id: 'leo4',
          moduleId: ApoloModuleId.hidratacion,
          priority: 'Low',
          text: 'Maintain 2.7 L of water per day',
          why: 'Calcium lost from bone exits in urine; water keeps it diluted.',
        ),
      ],
    ),
  ];

  final DateTime Function() _clock;

  static String resolveAstronautId(String rawId) {
    final trimmed = rawId.trim();
    if (trimmed.isEmpty) return 'AST-01';
    final lower = trimmed.toLowerCase();
    return aliasToAstronautId[lower] ?? trimmed;
  }

  Map<String, ApoloAstronautState> buildInitialStates({
    bool highContrast = false,
    bool autoTips = false,
    bool solarStormActive = false,
  }) {
    final now = _clock();
    final crewProfiles = {
      for (final p in MockCrewData.getInitialCrew()) p.id: p,
    };

    final result = <String, ApoloAstronautState>{};
    for (final preset in _presets) {
      final profile = crewProfiles[preset.astronautId];
      final samples = generateMockSamples(
        apoloKey: preset.apoloKey,
        astronautId: preset.astronautId,
        targetValues: preset.targetValues,
      );
      result[preset.astronautId] = _assembleState(
        astronautId: preset.astronautId,
        apoloCrewKey: preset.apoloKey,
        name: profile?.name ?? preset.apoloKey,
        role: profile?.role ?? 'Crew Member',
        initials: profile?.avatarInitials ?? _initialsOf(preset.apoloKey),
        colorHex: preset.colorHex,
        doseMsv: preset.doseMsv,
        waterMlToday: preset.waterMlToday,
        waterGoalMl: preset.waterGoalMl,
        exerciseMinToday: preset.exerciseMinToday,
        exerciseGoalMin: preset.exerciseGoalMin,
        sleepHours: preset.sleepHours,
        resistanceSessionsWeek: preset.resistanceSessionsWeek,
        samples: samples,
        recommendations: preset.recommendations,
        now: now,
        highContrast: highContrast,
        autoTips: autoTips,
        solarStormActive: solarStormActive,
      );
    }
    return result;
  }

  ApoloAstronautState buildCustomState(
    String astronautId, {
    String? name,
    String? role,
    int colorHex = 0xFF9FD8FF,
    bool highContrast = false,
    bool autoTips = false,
    bool solarStormActive = false,
  }) {
    final resolvedId = resolveAstronautId(astronautId);
    final displayName = (name != null && name.trim().isNotEmpty)
        ? name.trim()
        : resolvedId;
    return _assembleState(
      astronautId: resolvedId,
      apoloCrewKey: resolvedId.toLowerCase(),
      name: displayName,
      role: (role != null && role.trim().isNotEmpty)
          ? role.trim()
          : 'Crew Member',
      initials: _initialsOf(displayName),
      colorHex: colorHex,
      doseMsv: 0,
      waterMlToday: 0,
      waterGoalMl: 2500,
      exerciseMinToday: 0,
      exerciseGoalMin: 90,
      sleepHours: 7.0,
      resistanceSessionsWeek: 0,
      samples: const [],
      recommendations: const [],
      now: _clock(),
      highContrast: highContrast,
      autoTips: autoTips,
      solarStormActive: solarStormActive,
    );
  }

  static List<ApoloUrineSample> generateMockSamples({
    required String apoloKey,
    required String astronautId,
    required Map<String, double> targetValues,
    int count = 40,
    int currentMissionDay = defaultMissionDay,
  }) {
    final r = _createSeededPrng(apoloKey);
    final base = <String, double>{};
    for (final entry in ApoloBiomarkerEngine.catalog.entries) {
      final b = entry.value;
      if (!b.isBoolean && !b.isDerived) {
        base[entry.key] = b.lo + (b.hi - b.lo) * (0.35 + 0.3 * r());
      }
    }

    const methods = ['sensor', 'sensor', 'strip', 'sensor', 'manual'];
    final startMission = DateTime.utc(2026, 6, 26, 7, 30);
    final samples = <ApoloUrineSample>[];

    for (var i = 0; i < count; i++) {
      final day = currentMissionDay - (count - 1 - i);
      final t = math.max(0.0, (i - (count - 6)) / 5.0);
      final e = t * t * t;
      final values = <String, double>{};

      for (final entry in ApoloBiomarkerEngine.catalog.entries) {
        final k = entry.key;
        final b = entry.value;
        if (b.isDerived) continue;
        if (b.isBoolean) {
          final hasTarget = (targetValues[k] ?? 0) != 0;
          values[k] = (hasTarget && i == count - 1) ? 1.0 : 0.0;
          continue;
        }
        var x = base[k]! + (r() - 0.5) * (b.hi - b.lo) * 0.06;
        final target = targetValues[k];
        if (target != null) {
          x = x + (target - x) * e;
        }
        values[k] = double.parse(x.toStringAsFixed(b.decimals));
      }

      samples.add(
        ApoloUrineSample(
          id: '$apoloKey-$day',
          astronautId: astronautId,
          missionDay: day,
          takenAt: startMission.add(Duration(days: day - 1)),
          method: methods[i % methods.length],
          values: Map<String, double>.unmodifiable(values),
        ),
      );
    }

    return List<ApoloUrineSample>.unmodifiable(samples);
  }

  static ApoloUrineSample generateNewSample({
    required String astronautId,
    required String apoloCrewKey,
    required int missionDay,
    required DateTime takenAt,
    required int sequenceIndex,
    String method = 'sensor',
    int? waterMlToday,
  }) {
    final seedKey =
        '$apoloCrewKey-${takenAt.millisecondsSinceEpoch}-$sequenceIndex';
    final r = _createSeededPrng(seedKey);
    final values = <String, double>{};
    for (final entry in ApoloBiomarkerEngine.catalog.entries) {
      final b = entry.value;
      if (b.isDerived) continue;
      if (b.isBoolean) {
        values[entry.key] = 0.0;
        continue;
      }
      final x = b.lo + (b.hi - b.lo) * (0.35 + 0.3 * r());
      values[entry.key] = double.parse(x.toStringAsFixed(b.decimals));
    }
    if (waterMlToday != null && waterMlToday > 0) {
      final adjustedVol = (1.2 + waterMlToday / 1000.0).clamp(1.0, 3.0);
      values['vol'] = double.parse(adjustedVol.toStringAsFixed(2));
    }
    return ApoloUrineSample(
      id: '$apoloCrewKey-${takenAt.millisecondsSinceEpoch}',
      astronautId: astronautId,
      missionDay: missionDay,
      takenAt: takenAt,
      method: method,
      values: Map<String, double>.unmodifiable(values),
    );
  }

  static ApoloAstronautState rebuildState(
    ApoloAstronautState current, {
    required DateTime now,
    int? waterMlToday,
    int? exerciseMinToday,
    int? resistanceSessionsWeek,
    List<ApoloUrineSample>? samples,
    List<ApoloRecommendation>? recommendations,
    List<ApoloModuleId>? visibleOrbs,
    ApoloModuleId? openModuleId,
    bool clearOpenModuleId = false,
    DateTime? lastSubmittedAt,
    bool? highContrast,
    bool? autoTips,
    bool? solarStormActive,
  }) {
    final nextSamples = samples ?? current.samples;
    final nextWater = waterMlToday ?? current.waterMlToday;
    final nextEx = exerciseMinToday ?? current.exerciseMinToday;
    final nextSessions =
        resistanceSessionsWeek ?? current.resistanceSessionsWeek;
    final nextHc = highContrast ?? current.highContrast;
    final nextTips = autoTips ?? current.autoTips;
    final nextStorm = solarStormActive ?? current.solarStormActive;

    final nextRecs =
        recommendations ??
        [for (final mod in current.modules.values) ...mod.recommendations];

    final nextModules = ApoloBiomarkerEngine.buildModules(
      samples: nextSamples,
      waterMlToday: nextWater,
      waterGoalMl: current.waterGoalMl,
      doseMsv: current.doseMsv,
      doseLimitMsv: current.doseLimitMsv,
      sleepHours: current.sleepHours,
      solarStormActive: nextStorm,
      recommendations: nextRecs,
    );

    final nextOverall = ApoloBiomarkerEngine.overallSeverity(nextModules);
    final nextSchedule = ApoloBiomarkerEngine.sampleSchedule(
      now,
      samples: nextSamples,
      lastSubmittedAt: lastSubmittedAt,
    );

    return ApoloAstronautState(
      astronautId: current.astronautId,
      apoloCrewKey: current.apoloCrewKey,
      name: current.name,
      role: current.role,
      initials: current.initials,
      colorHex: current.colorHex,
      missionName: current.missionName,
      missionDay: current.missionDay,
      totalMissionDays: current.totalMissionDays,
      doseMsv: current.doseMsv,
      doseLimitMsv: current.doseLimitMsv,
      waterMlToday: nextWater,
      waterGoalMl: current.waterGoalMl,
      exerciseMinToday: nextEx,
      exerciseGoalMin: current.exerciseGoalMin,
      sleepHours: current.sleepHours,
      resistanceSessionsWeek: nextSessions,
      overallSeverity: nextOverall,
      modules: nextModules,
      visibleOrbs: List<ApoloModuleId>.unmodifiable(
        visibleOrbs ?? current.visibleOrbs,
      ),
      openModuleId: clearOpenModuleId
          ? null
          : (openModuleId ?? current.openModuleId),
      sampleSchedule: nextSchedule,
      samples: List<ApoloUrineSample>.unmodifiable(nextSamples),
      highContrast: nextHc,
      autoTips: nextTips,
      solarStormActive: nextStorm,
    );
  }

  static ApoloAstronautState _assembleState({
    required String astronautId,
    required String apoloCrewKey,
    required String name,
    required String role,
    required String initials,
    required int colorHex,
    required double doseMsv,
    required int waterMlToday,
    required int waterGoalMl,
    required int exerciseMinToday,
    required int exerciseGoalMin,
    required double sleepHours,
    required int resistanceSessionsWeek,
    required List<ApoloUrineSample> samples,
    required List<ApoloRecommendation> recommendations,
    required DateTime now,
    required bool highContrast,
    required bool autoTips,
    required bool solarStormActive,
  }) {
    final modules = ApoloBiomarkerEngine.buildModules(
      samples: samples,
      waterMlToday: waterMlToday,
      waterGoalMl: waterGoalMl,
      doseMsv: doseMsv,
      doseLimitMsv: defaultDoseLimitMsv,
      sleepHours: sleepHours,
      solarStormActive: solarStormActive,
      recommendations: recommendations,
    );
    final overall = ApoloBiomarkerEngine.overallSeverity(modules);
    final schedule = ApoloBiomarkerEngine.sampleSchedule(now, samples: samples);

    final initialDraft = ApoloAstronautState(
      astronautId: astronautId,
      apoloCrewKey: apoloCrewKey,
      name: name,
      role: role,
      initials: initials,
      colorHex: colorHex,
      missionName: defaultMissionName,
      missionDay: defaultMissionDay,
      totalMissionDays: defaultTotalMissionDays,
      doseMsv: doseMsv,
      doseLimitMsv: defaultDoseLimitMsv,
      waterMlToday: waterMlToday,
      waterGoalMl: waterGoalMl,
      exerciseMinToday: exerciseMinToday,
      exerciseGoalMin: exerciseGoalMin,
      sleepHours: sleepHours,
      resistanceSessionsWeek: resistanceSessionsWeek,
      overallSeverity: overall,
      modules: modules,
      visibleOrbs: const [],
      openModuleId: null,
      sampleSchedule: schedule,
      samples: List<ApoloUrineSample>.unmodifiable(samples),
      highContrast: highContrast,
      autoTips: autoTips,
      solarStormActive: solarStormActive,
    );

    final urgentOrbs = initialDraft.rankedModules
        .where((m) => m.severity != ApoloSeverity.ok)
        .take(4)
        .map((m) => m.id)
        .toList(growable: false);

    return ApoloAstronautState(
      astronautId: initialDraft.astronautId,
      apoloCrewKey: initialDraft.apoloCrewKey,
      name: initialDraft.name,
      role: initialDraft.role,
      initials: initialDraft.initials,
      colorHex: initialDraft.colorHex,
      missionName: initialDraft.missionName,
      missionDay: initialDraft.missionDay,
      totalMissionDays: initialDraft.totalMissionDays,
      doseMsv: initialDraft.doseMsv,
      doseLimitMsv: initialDraft.doseLimitMsv,
      waterMlToday: initialDraft.waterMlToday,
      waterGoalMl: initialDraft.waterGoalMl,
      exerciseMinToday: initialDraft.exerciseMinToday,
      exerciseGoalMin: initialDraft.exerciseGoalMin,
      sleepHours: initialDraft.sleepHours,
      resistanceSessionsWeek: initialDraft.resistanceSessionsWeek,
      overallSeverity: initialDraft.overallSeverity,
      modules: initialDraft.modules,
      visibleOrbs: List<ApoloModuleId>.unmodifiable(urgentOrbs),
      openModuleId: null,
      sampleSchedule: initialDraft.sampleSchedule,
      samples: initialDraft.samples,
      highContrast: highContrast,
      autoTips: autoTips,
      solarStormActive: solarStormActive,
    );
  }

  static String _initialsOf(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      return parts.first
          .substring(0, math.min(2, parts.first.length))
          .toUpperCase();
    }
    return '${parts.first[0]}${parts[1][0]}'.toUpperCase();
  }

  /// Cross-platform 32-bit unsigned multiply matching JS `Math.imul`.
  static int _imul32(int a, int b) {
    final ah = (a >>> 16) & 0xFFFF;
    final al = a & 0xFFFF;
    final bh = (b >>> 16) & 0xFFFF;
    final bl = b & 0xFFFF;
    return ((al * bl) + ((((ah * bl) + (al * bh)) & 0xFFFF) << 16)) &
        0xFFFFFFFF;
  }

  static double Function() _createSeededPrng(String s) {
    var h = (1779033703 ^ s.length) & 0xFFFFFFFF;
    for (var i = 0; i < s.length; i++) {
      h = _imul32(h ^ s.codeUnitAt(i), 3432918353);
      h = ((h << 13) | (h >>> 19)) & 0xFFFFFFFF;
    }
    return () {
      h = _imul32(h ^ (h >>> 16), 2246822507);
      h = _imul32(h ^ (h >>> 13), 3266489909);
      h = (h ^ (h >>> 16)) & 0xFFFFFFFF;
      return h / 4294967296.0;
    };
  }
}

class ApoloStateNotifier extends StateNotifier<Map<String, ApoloAstronautState>>
    implements ApoloStateActions {
  ApoloStateNotifier({
    ApoloRepository? repository,
    String initialAstronautId = 'AST-01',
    DateTime Function()? clock,
  }) : _repository = repository ?? ApoloRepository(clock: clock),
       _clock = clock ?? DateTime.now,
       _activeAstronautId = ApoloRepository.resolveAstronautId(
         initialAstronautId,
       ),
       super(
         (repository ?? ApoloRepository(clock: clock)).buildInitialStates(),
       );

  final ApoloRepository _repository;
  final DateTime Function() _clock;
  final Map<String, DateTime> _lastSubmittedAtByAstronaut = {};

  String _activeAstronautId;
  bool _highContrast = false;
  bool _autoTips = false;
  bool _solarStormActive = false;

  String get activeAstronautId => _activeAstronautId;

  void setActiveAstronautId(String astronautId) {
    _activeAstronautId = ApoloRepository.resolveAstronautId(astronautId);
  }

  ApoloAstronautState addCrewMember({
    required String name,
    required String role,
    String? id,
    int? colorHex,
  }) {
    final normalizedId =
        id ??
        name
            .trim()
            .toLowerCase()
            .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
            .replaceAll(RegExp(r'^-|-$'), '');
    final finalId = normalizedId.isEmpty
        ? 'crew-${state.length + 1}'
        : normalizedId;
    const palette = [
      0xFFB3E9C7,
      0xFFA994E0,
      0xFFFFD9A0,
      0xFF9FD8FF,
      0xFFF5B8D0,
    ];
    final created = _repository.buildCustomState(
      finalId,
      name: name,
      role: role,
      colorHex: colorHex ?? palette[state.length % palette.length],
      highContrast: _highContrast,
      autoTips: _autoTips,
      solarStormActive: _solarStormActive,
    );
    state = {...state, finalId: created};
    return created;
  }

  @override
  ApoloAstronautState stateFor(String astronautId) {
    final resolvedId = ApoloRepository.resolveAstronautId(astronautId);
    final existing = state[resolvedId];
    if (existing != null) return existing;
    return _repository.buildCustomState(
      resolvedId,
      highContrast: _highContrast,
      autoTips: _autoTips,
      solarStormActive: _solarStormActive,
    );
  }

  ApoloAstronautState _ensureEntry(String astronautId) {
    final resolvedId = ApoloRepository.resolveAstronautId(astronautId);
    final existing = state[resolvedId];
    if (existing != null) return existing;
    final created = _repository.buildCustomState(
      resolvedId,
      highContrast: _highContrast,
      autoTips: _autoTips,
      solarStormActive: _solarStormActive,
    );
    state = {...state, resolvedId: created};
    return created;
  }

  void _putState(ApoloAstronautState updated) {
    state = {...state, updated.astronautId: updated};
  }

  List<ApoloModuleId> _mergeVisibleOrbs(
    ApoloAstronautState current,
    Iterable<ApoloModuleId> ids, {
    int maxOrbs = 8,
  }) {
    final idList = ids.toList(growable: false);
    final keep = idList.toSet();
    final vis = List<ApoloModuleId>.from(current.visibleOrbs);
    for (final id in idList) {
      if (!vis.contains(id)) {
        vis.add(id);
      }
    }
    while (vis.length > maxOrbs) {
      var idx = vis.indexWhere(
        (id) =>
            !keep.contains(id) &&
            current.modules[id]?.severity == ApoloSeverity.ok,
      );
      if (idx < 0) {
        idx = vis.indexWhere((id) => !keep.contains(id));
      }
      if (idx < 0) idx = 0;
      vis.removeAt(idx);
    }
    return vis;
  }

  @override
  void showOrbs(Iterable<ApoloModuleId> ids, {int maxOrbs = 8}) {
    final current = _ensureEntry(_activeAstronautId);
    final nextVis = _mergeVisibleOrbs(current, ids, maxOrbs: maxOrbs);
    _putState(
      ApoloRepository.rebuildState(
        current,
        now: _clock(),
        lastSubmittedAt: _lastSubmittedAtByAstronaut[current.astronautId],
        visibleOrbs: nextVis,
      ),
    );
  }

  @override
  void resetOrbsToUrgent() {
    final current = _ensureEntry(_activeAstronautId);
    final urgent = current.rankedModules
        .where((m) => m.severity != ApoloSeverity.ok)
        .take(4)
        .map((m) => m.id)
        .toList(growable: false);
    _putState(
      ApoloRepository.rebuildState(
        current,
        now: _clock(),
        lastSubmittedAt: _lastSubmittedAtByAstronaut[current.astronautId],
        visibleOrbs: urgent,
      ),
    );
  }

  @override
  void showAllOrbs({int maxOrbs = 8}) {
    final current = _ensureEntry(_activeAstronautId);
    final rankedIds = current.rankedModules
        .map((m) => m.id)
        .take(maxOrbs)
        .toList(growable: false);
    final nextVis = _mergeVisibleOrbs(current, rankedIds, maxOrbs: maxOrbs);
    _putState(
      ApoloRepository.rebuildState(
        current,
        now: _clock(),
        lastSubmittedAt: _lastSubmittedAtByAstronaut[current.astronautId],
        visibleOrbs: nextVis,
      ),
    );
  }

  @override
  void hideOrb(ApoloModuleId id) {
    final current = _ensureEntry(_activeAstronautId);
    final nextVis = current.visibleOrbs
        .where((orb) => orb != id)
        .toList(growable: false);
    _putState(
      ApoloRepository.rebuildState(
        current,
        now: _clock(),
        lastSubmittedAt: _lastSubmittedAtByAstronaut[current.astronautId],
        visibleOrbs: nextVis,
        clearOpenModuleId: current.openModuleId == id,
      ),
    );
  }

  @override
  void openDetail(ApoloModuleId? id) {
    final current = _ensureEntry(_activeAstronautId);
    _putState(
      ApoloRepository.rebuildState(
        current,
        now: _clock(),
        lastSubmittedAt: _lastSubmittedAtByAstronaut[current.astronautId],
        openModuleId: id,
        clearOpenModuleId: id == null,
      ),
    );
  }

  @override
  bool addWater(int ml, {String? astronautId}) {
    if (ml < 50 || ml > 2000) return false;
    final targetId = astronautId ?? _activeAstronautId;
    final current = _ensureEntry(targetId);
    final nextVis = _mergeVisibleOrbs(current, const [
      ApoloModuleId.hidratacion,
    ]);
    _putState(
      ApoloRepository.rebuildState(
        current,
        now: _clock(),
        lastSubmittedAt: _lastSubmittedAtByAstronaut[current.astronautId],
        waterMlToday: current.waterMlToday + ml,
        visibleOrbs: nextVis,
      ),
    );
    return true;
  }

  @override
  bool addExercise(int minutes, {String? astronautId}) {
    if (minutes < 1 || minutes > 300) return false;
    final targetId = astronautId ?? _activeAstronautId;
    final current = _ensureEntry(targetId);
    final nextVis = _mergeVisibleOrbs(current, const [ApoloModuleId.osea]);
    _putState(
      ApoloRepository.rebuildState(
        current,
        now: _clock(),
        lastSubmittedAt: _lastSubmittedAtByAstronaut[current.astronautId],
        exerciseMinToday: current.exerciseMinToday + minutes,
        resistanceSessionsWeek: current.resistanceSessionsWeek + 1,
        visibleOrbs: nextVis,
      ),
    );
    return true;
  }

  @override
  void toggleRecommendation(String recId, bool done, {String? astronautId}) {
    final targetId = astronautId ?? _activeAstronautId;
    final current = _ensureEntry(targetId);
    final updatedRecs = <ApoloRecommendation>[
      for (final mod in current.modules.values)
        for (final rec in mod.recommendations)
          rec.id == recId ? rec.copyWith(done: done) : rec,
    ];
    _putState(
      ApoloRepository.rebuildState(
        current,
        now: _clock(),
        lastSubmittedAt: _lastSubmittedAtByAstronaut[current.astronautId],
        recommendations: updatedRecs,
      ),
    );
  }

  @override
  ApoloUrineSample submitSample({
    String method = 'sensor',
    String? astronautId,
  }) {
    final targetId = astronautId ?? _activeAstronautId;
    final current = _ensureEntry(targetId);
    final now = _clock();
    final sample = ApoloRepository.generateNewSample(
      astronautId: current.astronautId,
      apoloCrewKey: current.apoloCrewKey,
      missionDay: current.missionDay,
      takenAt: now,
      sequenceIndex: current.samples.length,
      method: method,
      waterMlToday: current.waterMlToday,
    );
    _lastSubmittedAtByAstronaut[current.astronautId] = now;
    final nextSamples = [...current.samples, sample];
    final draft = ApoloRepository.rebuildState(
      current,
      now: now,
      lastSubmittedAt: now,
      samples: nextSamples,
    );
    final urgentOrbs = draft.rankedModules
        .where((m) => m.severity != ApoloSeverity.ok)
        .take(4)
        .map((m) => m.id)
        .toList(growable: false);
    _putState(
      ApoloRepository.rebuildState(
        draft,
        now: now,
        lastSubmittedAt: now,
        visibleOrbs: urgentOrbs,
      ),
    );
    return sample;
  }

  @override
  void setHighContrast(bool enabled) {
    _highContrast = enabled;
    final now = _clock();
    state = {
      for (final entry in state.entries)
        entry.key: ApoloRepository.rebuildState(
          entry.value,
          now: now,
          lastSubmittedAt: _lastSubmittedAtByAstronaut[entry.key],
          highContrast: enabled,
        ),
    };
  }

  @override
  void setAutoTips(bool enabled) {
    _autoTips = enabled;
    final now = _clock();
    state = {
      for (final entry in state.entries)
        entry.key: ApoloRepository.rebuildState(
          entry.value,
          now: now,
          lastSubmittedAt: _lastSubmittedAtByAstronaut[entry.key],
          autoTips: enabled,
        ),
    };
  }

  @override
  void setSolarStorm(bool active) {
    _solarStormActive = active;
    final now = _clock();
    state = {
      for (final entry in state.entries)
        entry.key: ApoloRepository.rebuildState(
          entry.value,
          now: now,
          lastSubmittedAt: _lastSubmittedAtByAstronaut[entry.key],
          solarStormActive: active,
        ),
    };
  }
}
