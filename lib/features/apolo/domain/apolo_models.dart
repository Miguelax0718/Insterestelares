import 'package:flutter/foundation.dart';

/// Severity code matching APOLO (`ok` = green, `warn` = yellow, `crit` = red).
enum ApoloSeverity {
  ok,
  warn,
  crit;

  String get wire => name;

  String get label => switch (this) {
    ApoloSeverity.ok => 'Stable',
    ApoloSeverity.warn => 'Attention',
    ApoloSeverity.crit => 'Critical',
  };

  int get rank => switch (this) {
    ApoloSeverity.crit => 0,
    ApoloSeverity.warn => 1,
    ApoloSeverity.ok => 2,
  };

  static ApoloSeverity worst(Iterable<ApoloSeverity> values) {
    var result = ApoloSeverity.ok;
    for (final v in values) {
      if (v.rank < result.rank) {
        result = v;
      }
    }
    return result;
  }
}

/// The 8 APOLO health circles.
enum ApoloModuleId {
  hidratacion,
  renal,
  osea,
  radiacion,
  inmunidad,
  cardio,
  estres,
  metabolismo;

  static ApoloModuleId? tryParse(String raw) {
    final clean = raw.trim().toLowerCase();
    for (final m in ApoloModuleId.values) {
      if (m.name == clean) return m;
    }
    return null;
  }

  String get shortLabel => switch (this) {
    ApoloModuleId.hidratacion => 'Water',
    ApoloModuleId.renal => 'Kidneys',
    ApoloModuleId.osea => 'Bones',
    ApoloModuleId.radiacion => 'Radiation',
    ApoloModuleId.inmunidad => 'Immunity',
    ApoloModuleId.cardio => 'Heart',
    ApoloModuleId.estres => 'Sleep',
    ApoloModuleId.metabolismo => 'Energy',
  };

  String get title => switch (this) {
    ApoloModuleId.hidratacion => 'Hydration',
    ApoloModuleId.renal => 'Renal risk',
    ApoloModuleId.osea => 'Bone health',
    ApoloModuleId.radiacion => 'Radiation',
    ApoloModuleId.inmunidad => 'Immunity',
    ApoloModuleId.cardio => 'Cardiovascular',
    ApoloModuleId.estres => 'Stress & sleep',
    ApoloModuleId.metabolismo => 'Metabolism',
  };
}

@immutable
class ApoloBiomarkerDef {
  const ApoloBiomarkerDef({
    required this.id,
    required this.name,
    this.unit = '',
    this.decimals = 0,
    this.min = 0,
    this.max = 1,
    this.lo = 0,
    this.hi = 1,
    this.isBoolean = false,
    this.isDerived = false,
  });

  final String id;
  final String name;
  final String unit;
  final int decimals;
  final double min;
  final double max;
  final double lo;
  final double hi;
  final bool isBoolean;
  final bool isDerived;
}

@immutable
class ApoloBiomarkerReading {
  const ApoloBiomarkerReading({
    required this.def,
    required this.value,
    required this.personalLo,
    required this.personalHi,
    required this.severity,
    required this.formattedValue,
    this.previousValue,
  });

  final ApoloBiomarkerDef def;
  final double value;
  final double personalLo;
  final double personalHi;
  final ApoloSeverity severity;
  final String formattedValue;
  final double? previousValue;

  double get normalizedPosition {
    if (def.isBoolean) return value > 0 ? 1.0 : 0.0;
    final span = def.max - def.min;
    if (span <= 0) return 0.5;
    return ((value - def.min) / span).clamp(0.0, 1.0);
  }

  double get normalizedBandStart {
    final span = def.max - def.min;
    if (span <= 0) return 0.0;
    return ((personalLo - def.min) / span).clamp(0.0, 1.0);
  }

  double get normalizedBandWidth {
    final span = def.max - def.min;
    if (span <= 0) return 1.0;
    return ((personalHi - personalLo) / span).clamp(0.0, 1.0);
  }
}

@immutable
class ApoloRecommendation {
  const ApoloRecommendation({
    required this.id,
    required this.moduleId,
    required this.priority,
    required this.text,
    required this.why,
    this.done = false,
  });

  final String id;
  final ApoloModuleId moduleId;
  final String priority; // 'High' | 'Medium' | 'Low'
  final String text;
  final String why;
  final bool done;

  ApoloRecommendation copyWith({bool? done}) => ApoloRecommendation(
    id: id,
    moduleId: moduleId,
    priority: priority,
    text: text,
    why: why,
    done: done ?? this.done,
  );
}

@immutable
class ApoloUrineSample {
  const ApoloUrineSample({
    required this.id,
    required this.astronautId,
    required this.missionDay,
    required this.takenAt,
    required this.method,
    required this.values,
  });

  final String id;
  final String astronautId;
  final int missionDay;
  final DateTime takenAt;
  final String method;
  final Map<String, double> values;
}

@immutable
class ApoloModuleSnapshot {
  const ApoloModuleSnapshot({
    required this.id,
    required this.title,
    required this.shortLabel,
    required this.measures,
    required this.whyItMatters,
    required this.severity,
    required this.keyMetric,
    required this.subMetric,
    required this.primaryBiomarkerId,
    required this.primaryBiomarkerName,
    required this.biomarkers,
    required this.trendValues,
    required this.recommendations,
    required this.relatedModules,
  });

  final ApoloModuleId id;
  final String title;
  final String shortLabel;
  final String measures;
  final String whyItMatters;
  final ApoloSeverity severity;
  final String keyMetric;
  final String subMetric;
  final String primaryBiomarkerId;
  final String primaryBiomarkerName;
  final List<ApoloBiomarkerReading> biomarkers;
  final List<double> trendValues;
  final List<ApoloRecommendation> recommendations;
  final List<ApoloModuleId> relatedModules;
}

@immutable
class ApoloSampleScheduleState {
  const ApoloSampleScheduleState({
    required this.isDue,
    required this.isFirstSample,
    required this.previousSlot,
    required this.nextSlot,
    required this.progress,
    required this.shortLabel,
    required this.title,
    required this.subtitle,
  });

  final bool isDue;
  final bool isFirstSample;
  final DateTime previousSlot;
  final DateTime nextSlot;
  final double progress;
  final String shortLabel;
  final String title;
  final String subtitle;
}

@immutable
class ApoloAstronautState {
  const ApoloAstronautState({
    required this.astronautId,
    required this.apoloCrewKey,
    required this.name,
    required this.role,
    required this.initials,
    required this.colorHex,
    required this.missionName,
    required this.missionDay,
    required this.totalMissionDays,
    required this.doseMsv,
    required this.doseLimitMsv,
    required this.waterMlToday,
    required this.waterGoalMl,
    required this.exerciseMinToday,
    required this.exerciseGoalMin,
    required this.sleepHours,
    required this.resistanceSessionsWeek,
    required this.overallSeverity,
    required this.modules,
    required this.visibleOrbs,
    required this.openModuleId,
    required this.sampleSchedule,
    required this.samples,
    this.highContrast = false,
    this.autoTips = false,
    this.solarStormActive = false,
  });

  final String astronautId;
  final String apoloCrewKey;
  final String name;
  final String role;
  final String initials;
  final int colorHex;
  final String missionName;
  final int missionDay;
  final int totalMissionDays;
  final double doseMsv;
  final double doseLimitMsv;
  final int waterMlToday;
  final int waterGoalMl;
  final int exerciseMinToday;
  final int exerciseGoalMin;
  final double sleepHours;
  final int resistanceSessionsWeek;
  final ApoloSeverity overallSeverity;
  final Map<ApoloModuleId, ApoloModuleSnapshot> modules;
  final List<ApoloModuleId> visibleOrbs;
  final ApoloModuleId? openModuleId;
  final ApoloSampleScheduleState sampleSchedule;
  final List<ApoloUrineSample> samples;
  final bool highContrast;
  final bool autoTips;
  final bool solarStormActive;

  String get firstName => name.split(' ').first;

  List<ApoloModuleSnapshot> get rankedModules {
    const baseOrder = [
      ApoloModuleId.radiacion,
      ApoloModuleId.renal,
      ApoloModuleId.hidratacion,
      ApoloModuleId.inmunidad,
      ApoloModuleId.osea,
      ApoloModuleId.estres,
      ApoloModuleId.cardio,
      ApoloModuleId.metabolismo,
    ];
    final list = modules.values.toList();
    list.sort((a, b) {
      final c = a.severity.rank.compareTo(b.severity.rank);
      if (c != 0) return c;
      return baseOrder.indexOf(a.id).compareTo(baseOrder.indexOf(b.id));
    });
    return list;
  }
}

/// Controller interface consumed by `ApoloHomeScreen` and `ApoloUrineSkill` tools.
abstract interface class ApoloStateActions {
  ApoloAstronautState stateFor(String astronautId);

  void showOrbs(Iterable<ApoloModuleId> ids, {int maxOrbs = 8});

  void resetOrbsToUrgent();

  void showAllOrbs({int maxOrbs = 8});

  void hideOrb(ApoloModuleId id);

  void openDetail(ApoloModuleId? id);

  bool addWater(int ml, {String? astronautId});

  bool addExercise(int minutes, {String? astronautId});

  void toggleRecommendation(String recId, bool done, {String? astronautId});

  ApoloUrineSample submitSample({String method = 'sensor', String? astronautId});

  void setHighContrast(bool enabled);

  void setAutoTips(bool enabled);

  void setSolarStorm(bool active);
}
