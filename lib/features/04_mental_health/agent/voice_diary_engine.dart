import 'dart:math' as math;

import 'package:astramed/core/constants/medical_thresholds.dart';
import 'package:astramed/features/04_mental_health/models/sleep_record.dart';
import 'package:astramed/features/agent/domain/agent_contracts.dart';

/// Thresholds for acoustic speech cadence and sleep-debt fatigue correlation.
abstract final class VoiceDiaryThresholds {
  static const double lowWpmThreshold = 105.0;
  static const double severeLowWpmThreshold = 90.0;
  static const double highPauseRatioThreshold = 0.30;
  static const double highMeanPauseMsThreshold = 650.0;
  static const double highPitchMonotonyThreshold = 0.70;

  static const double minRecommendedSleepHours =
      MedicalThresholds.minRecommendedSleepHours;
  static const double optimalSleepHours = MedicalThresholds.optimalSleepHours;
  static const double severeSleepHours = 5.5;
}

enum SemanticMarkerCategory {
  stress('stress'),
  isolation('isolation'),
  interpersonalConflict('interpersonal_conflict'),
  sopiteSyndrome('sopite_syndrome');

  const SemanticMarkerCategory(this.wireName);

  final String wireName;

  static SemanticMarkerCategory? tryFromWire(String value) {
    for (final item in SemanticMarkerCategory.values) {
      if (item.wireName == value) return item;
    }
    return null;
  }
}

class SpeechCadenceMetrics {
  const SpeechCadenceMetrics({
    required this.wordsPerMinute,
    required this.pauseRatio,
    required this.meanPauseMs,
    required this.pitchMonotony,
  });

  final double wordsPerMinute;
  final double pauseRatio;
  final double meanPauseMs;
  final double pitchMonotony;

  Map<String, dynamic> toJson() => {
    'words_per_minute': wordsPerMinute,
    'pause_ratio': pauseRatio,
    'mean_pause_ms': meanPauseMs,
    'pitch_monotony': pitchMonotony,
  };
}

class DiaryRecommendation {
  const DiaryRecommendation({
    required this.category,
    required this.title,
    required this.action,
    required this.rationale,
    required this.priority,
  });

  factory DiaryRecommendation.fromJson(Map<String, dynamic> json) {
    final category = json['category'] as String?;
    final title = json['title'] as String?;
    final action = json['action'] as String?;
    final rationale = json['rationale'] as String?;
    final priority = json['priority'] as String?;
    if (category == null ||
        title == null ||
        action == null ||
        rationale == null ||
        priority == null) {
      throw const FormatException('Invalid DiaryRecommendation payload.');
    }
    return DiaryRecommendation(
      category: category,
      title: title,
      action: action,
      rationale: rationale,
      priority: priority,
    );
  }

  /// One of: `sleep_schedule`, `nap_window`, `nutrition_hydration`, `disconnection_social`.
  final String category;
  final String title;
  final String action;
  final String rationale;
  final String priority;

  Map<String, dynamic> toJson() => {
    'category': category,
    'title': title,
    'action': action,
    'rationale': rationale,
    'priority': priority,
  };
}

class VoiceDiaryAnalysisResult {
  const VoiceDiaryAnalysisResult({
    required this.semanticMarkers,
    required this.matchedPhrases,
    required this.cadenceFlags,
    required this.centralFatigueDetected,
    required this.centralFatigueScore,
    required this.sleepHours,
    required this.sleepDebtHours,
    required this.hasSleepDebt,
    required this.riskLevel,
    required this.recommendations,
  });

  final Set<SemanticMarkerCategory> semanticMarkers;
  final Map<String, List<String>> matchedPhrases;
  final List<String> cadenceFlags;
  final bool centralFatigueDetected;
  final double centralFatigueScore;
  final double sleepHours;
  final double sleepDebtHours;
  final bool hasSleepDebt;
  final String riskLevel;
  final List<DiaryRecommendation> recommendations;

  Map<String, dynamic> toJson() => {
    'semantic_markers': semanticMarkers.map((e) => e.wireName).toList(),
    'matched_phrases': matchedPhrases,
    'cadence_flags': cadenceFlags,
    'central_fatigue_detected': centralFatigueDetected,
    'central_fatigue_score': centralFatigueScore,
    'sleep_hours': sleepHours,
    'sleep_debt_hours': sleepDebtHours,
    'has_sleep_debt': hasSleepDebt,
    'risk_level': riskLevel,
    'recommendations': recommendations.map((r) => r.toJson()).toList(),
  };
}

abstract final class VoiceDiaryEngine {
  static const Map<SemanticMarkerCategory, List<String>> _markerLexicon = {
    SemanticMarkerCategory.stress: [
      // English
      'stress',
      'stressed',
      'overwhelmed',
      'anxious',
      'anxiety',
      'pressure',
      'burnout',
      'panic',
      'tense',
      'worried',
      'overload',
      // Spanish (normalized)
      'estres',
      'estresado',
      'estresada',
      'agobiado',
      'agobiada',
      'ansioso',
      'ansiosa',
      'ansiedad',
      'presion',
      'sobrecarga',
      'tenso',
      'tensa',
      'preocupado',
      'preocupada',
      'abrumado',
      'abrumada',
    ],
    SemanticMarkerCategory.isolation: [
      // English
      'isolated',
      'isolation',
      'lonely',
      'loneliness',
      'alone',
      'disconnected',
      'homesick',
      'miss home',
      'miss my family',
      'cut off',
      'confined',
      // Spanish (normalized)
      'aislado',
      'aislada',
      'aislamiento',
      'soledad',
      'me siento solo',
      'me siento sola',
      'estoy solo',
      'estoy sola',
      'desconectado',
      'desconectada',
      'confinamiento',
      'encerrado',
      'encerrada',
      'extrano mi familia',
      'extrano casa',
    ],
    SemanticMarkerCategory.interpersonalConflict: [
      // English
      'conflict',
      'argument',
      'argued',
      'crew tension',
      'tension with',
      'frustrated with',
      'annoyed with',
      'irritable',
      'snapped at',
      'disagreement',
      'fight',
      // Spanish (normalized)
      'conflicto',
      'discusion',
      'discutimos',
      'peleamos',
      'pelea',
      'tension con',
      'frustrado con',
      'frustrada con',
      'molesto con',
      'molesta con',
      'enojado con',
      'enojada con',
      'roce',
      'malentendido',
      'irritable',
    ],
    SemanticMarkerCategory.sopiteSyndrome: [
      // English
      'sopite',
      'apathy',
      'apathetic',
      'yawn',
      'yawning',
      'withdrawal',
      'withdrawn',
      'drowsiness',
      'drowsy',
      'without nausea',
      'no nausea',
      'lethargy',
      'lethargic',
      'sluggish',
      'unmotivated',
      'tired all day',
      'no energy',
      // Spanish (normalized)
      'apatia',
      'apatico',
      'apatica',
      'bostezo',
      'bostezos',
      'bostezando',
      'retraimiento',
      'retraido',
      'retraida',
      'somnolencia',
      'somnoliento',
      'somnolienta',
      'sin nauseas',
      'sin ganas',
      'desganado',
      'desganada',
      'cansado todo el dia',
      'cansada todo el dia',
      'letargo',
      'sin energia',
      'sin motivacion',
    ],
  };

  /// Performs deterministic semantic and speech-cadence analysis over a daily
  /// voice diary transcript and correlates findings with [SleepRecord].
  static VoiceDiaryAnalysisResult analyze({
    required String transcript,
    SpeechCadenceMetrics? cadence,
    required SleepRecord sleepRecord,
  }) {
    final normalized = _normalize(transcript);
    final semanticMarkers = <SemanticMarkerCategory>{};
    final matchedPhrases = <String, List<String>>{};

    for (final entry in _markerLexicon.entries) {
      final matches = <String>[];
      for (final phrase in entry.value) {
        if (_containsPhrase(normalized, phrase)) {
          matches.add(phrase);
        }
      }
      if (matches.isNotEmpty) {
        semanticMarkers.add(entry.key);
        matchedPhrases[entry.key.wireName] = matches;
      }
    }

    final cadenceFlags = <String>[];
    var cadencePoints = 0.0;

    if (cadence != null) {
      if (cadence.wordsPerMinute < VoiceDiaryThresholds.lowWpmThreshold) {
        cadenceFlags.add('low_speech_rate');
        cadencePoints +=
            cadence.wordsPerMinute < VoiceDiaryThresholds.severeLowWpmThreshold
            ? 0.30
            : 0.22;
      }
      if (cadence.pauseRatio >= VoiceDiaryThresholds.highPauseRatioThreshold) {
        cadenceFlags.add('high_pause_ratio');
        cadencePoints += 0.25;
      }
      if (cadence.meanPauseMs >= VoiceDiaryThresholds.highMeanPauseMsThreshold) {
        cadenceFlags.add('prolonged_pauses');
        cadencePoints += 0.20;
      }
      if (cadence.pitchMonotony >=
          VoiceDiaryThresholds.highPitchMonotonyThreshold) {
        cadenceFlags.add('pitch_monotony');
        cadencePoints += 0.25;
      }
    }

    final sleepHours = sleepRecord.sleepHours.clamp(0.0, 24.0);
    final sleepDebtHours = math.max(
      0.0,
      VoiceDiaryThresholds.optimalSleepHours - sleepHours,
    );
    final hasSleepDebt =
        sleepHours < VoiceDiaryThresholds.minRecommendedSleepHours;

    var sleepPoints = 0.0;
    if (sleepHours < VoiceDiaryThresholds.severeSleepHours) {
      sleepPoints = 0.35;
    } else if (hasSleepDebt) {
      sleepPoints = 0.22;
    } else if (sleepRecord.wakeEpisodes >= 3) {
      sleepPoints = 0.12;
    }

    final sopiteBonus =
        semanticMarkers.contains(SemanticMarkerCategory.sopiteSyndrome)
        ? 0.12
        : 0.0;
    final centralFatigueScore = (cadencePoints + sleepPoints + sopiteBonus)
        .clamp(0.0, 1.0);

    final centralFatigueDetected =
        cadenceFlags.length >= 2 ||
        (cadenceFlags.isNotEmpty && hasSleepDebt) ||
        centralFatigueScore >= 0.50;

    final String riskLevel;
    if (centralFatigueDetected &&
        (semanticMarkers.length >= 2 ||
            sleepHours < VoiceDiaryThresholds.severeSleepHours)) {
      riskLevel = 'elevated';
    } else if (centralFatigueDetected ||
        semanticMarkers.isNotEmpty ||
        hasSleepDebt) {
      riskLevel = 'caution';
    } else {
      riskLevel = 'nominal';
    }

    final recommendations = generateRecommendations(
      markers: semanticMarkers,
      centralFatigueDetected: centralFatigueDetected,
      sleepHours: sleepHours,
      wakeEpisodes: sleepRecord.wakeEpisodes,
      morningMood: sleepRecord.morningMood,
    );

    return VoiceDiaryAnalysisResult(
      semanticMarkers: semanticMarkers,
      matchedPhrases: matchedPhrases,
      cadenceFlags: cadenceFlags,
      centralFatigueDetected: centralFatigueDetected,
      centralFatigueScore: centralFatigueScore,
      sleepHours: sleepHours,
      sleepDebtHours: sleepDebtHours,
      hasSleepDebt: hasSleepDebt,
      riskLevel: riskLevel,
      recommendations: recommendations,
    );
  }

  /// Generates adaptive behavioral, circadian, and nutritional recommendations
  /// tailored to detected diary markers and sleep metrics.
  static List<DiaryRecommendation> generateRecommendations({
    required Set<SemanticMarkerCategory> markers,
    required bool centralFatigueDetected,
    required double sleepHours,
    int wakeEpisodes = 0,
    MoodLevel? morningMood,
  }) {
    final hasSleepDebt =
        sleepHours < VoiceDiaryThresholds.minRecommendedSleepHours;
    final hasSopite = markers.contains(SemanticMarkerCategory.sopiteSyndrome);
    final hasStress = markers.contains(SemanticMarkerCategory.stress);
    final hasIsolation = markers.contains(SemanticMarkerCategory.isolation);
    final hasConflict = markers.contains(
      SemanticMarkerCategory.interpersonalConflict,
    );

    final recommendations = <DiaryRecommendation>[];

    // 1. Sleep schedule shift
    if (hasSleepDebt || centralFatigueDetected || wakeEpisodes >= 3) {
      final shiftMinutes = sleepHours < VoiceDiaryThresholds.severeSleepHours
          ? 60
          : 45;
      recommendations.add(
        DiaryRecommendation(
          category: 'sleep_schedule',
          title: 'Advance Sleep Window by $shiftMinutes Minutes',
          action:
              'Shift sleep onset $shiftMinutes min earlier tonight, dim cabin lighting to <10 lux 45 min prior, and block blue-spectrum screens.',
          rationale:
              'Sleep duration (${sleepHours.toStringAsFixed(1)}h, $wakeEpisodes wake episodes) and fatigue markers indicate circadian recovery need.',
          priority: 'high',
        ),
      );
    } else {
      recommendations.add(
        DiaryRecommendation(
          category: 'sleep_schedule',
          title: 'Maintain Fixed Circadian Sleep Schedule',
          action:
              'Keep current sleep-wake anchor (+/- 15 min) with morning bright-light exposure after wake.',
          rationale:
              'Sleep duration (${sleepHours.toStringAsFixed(1)}h) is within target operational range.',
          priority: 'low',
        ),
      );
    }

    // 2. Nap window
    if (centralFatigueDetected || hasSleepDebt || hasSopite) {
      final napMinutes = hasSopite || sleepHours < 5.5 ? 30 : 20;
      recommendations.add(
        DiaryRecommendation(
          category: 'nap_window',
          title: 'Scheduled $napMinutes-Minute Recovery Nap Window',
          action:
              'Schedule a $napMinutes-min controlled rest window during the mid-shift circadian dip, keeping >=6h clear before main sleep.',
          rationale: centralFatigueDetected
              ? 'Central fatigue cues and speech slowing warrant proactive alertness restoration.'
              : 'Vestibular apathy (Sopite) or sleep debt benefits from a brief restorative nap.',
          priority: centralFatigueDetected ? 'high' : 'medium',
        ),
      );
    } else {
      recommendations.add(
        const DiaryRecommendation(
          category: 'nap_window',
          title: 'Optional Micro-Break Rest Window',
          action:
              'Use a 10-min eyes-closed acoustic rest break mid-shift only if subjective drowsiness rises.',
          rationale:
              'No acute central fatigue detected; avoid long daytime naps that reduce nocturnal sleep pressure.',
          priority: 'low',
        ),
      );
    }

    // 3. Nutrition & hydration cues
    if (hasSopite || hasStress || centralFatigueDetected) {
      recommendations.add(
        DiaryRecommendation(
          category: 'nutrition_hydration',
          title: 'Targeted Hydration & Caffeine Cutoff',
          action:
              'Drink 300 mL electrolyte fluid every 2 hours, favor low-glycemic complex carbs + protein snacks, and enforce zero caffeine within 6h of sleep.',
          rationale: hasSopite
              ? 'Vestibular apathy (Sopite) and fatigue worsen with mild dehydration and glucose swings.'
              : 'Stabilizes alertness while protecting upcoming slow-wave sleep architecture.',
          priority: hasSopite || centralFatigueDetected ? 'high' : 'medium',
        ),
      );
    } else {
      recommendations.add(
        const DiaryRecommendation(
          category: 'nutrition_hydration',
          title: 'Baseline Hydration & Meal Timing',
          action:
              'Maintain 2.2-2.5 L/day fluid intake and finish the main evening meal >=2h before sleep window.',
          rationale:
              'Supports stable autonomic and circadian rhythm during nominal duty.',
          priority: 'low',
        ),
      );
    }

    // 4. Disconnection / social activities
    if (hasConflict || hasIsolation || hasStress) {
      final parts = <String>[];
      if (hasConflict) {
        parts.add(
          'run a structured 10-min crew debrief or rotate shared tasks for a cooling-off interval',
        );
      }
      if (hasIsolation) {
        parts.add(
          'schedule an Earth family video/audio message and join a shared crew meal',
        );
      }
      if (hasStress) {
        parts.add(
          'take a 20-min off-duty sensory disconnection block with paced breathing (4-7-8)',
        );
      }
      recommendations.add(
        DiaryRecommendation(
          category: 'disconnection_social',
          title: 'Behavioral Decompression & Crew Connection',
          action: '${parts.join('; ')}.',
          rationale:
              'Diary markers detected (${markers.map((m) => m.wireName).join(', ')}).',
          priority: 'high',
        ),
      );
    } else if (hasSopite || morningMood == MoodLevel.fatigued) {
      recommendations.add(
        const DiaryRecommendation(
          category: 'disconnection_social',
          title: 'Low-Load Social & Light-Exposure Break',
          action:
              'Engage in a 15-min social conversation in a brightly lit habitat module to counter vestibular withdrawal.',
          rationale:
              'Social engagement and bright illumination counteract Sopite-related withdrawal.',
          priority: 'medium',
        ),
      );
    } else {
      recommendations.add(
        const DiaryRecommendation(
          category: 'disconnection_social',
          title: 'Routine Off-Duty Disconnection',
          action:
              'Reserve 30 min post-shift for crew leisure, cupola observation, or personal music.',
          rationale:
              'Preserves behavioral resilience during prolonged confinement.',
          priority: 'low',
        ),
      );
    }

    return recommendations;
  }

  /// Runs diary analysis using [sleepRecord] (or live [SleepRecord] when
  /// provided) and persists a [MemoryKind.clinicalEvent] entry in [MemoryStore].
  static Future<VoiceDiaryAnalysisResult> analyzeAndPersist({
    required ToolContext ctx,
    required String transcript,
    SpeechCadenceMetrics? cadence,
    required SleepRecord sleepRecord,
  }) async {
    final result = analyze(
      transcript: transcript,
      cadence: cadence,
      sleepRecord: sleepRecord,
    );

    final markersList = result.semanticMarkers.map((m) => m.wireName).toList();
    final tags = <String>[
      'voice_diary',
      ...markersList,
      if (result.centralFatigueDetected) 'central_fatigue',
      if (result.hasSleepDebt) 'sleep_debt',
    ];

    final summaryParts = <String>[
      'Voice diary check-in (${result.riskLevel})',
      if (markersList.isNotEmpty) 'markers: ${markersList.join(', ')}',
      if (result.centralFatigueDetected) 'central fatigue detected',
      'sleep ${result.sleepHours.toStringAsFixed(1)}h',
    ];

    await ctx.memory.save(
      MemoryEntry(
        id: 'diary-${ctx.astronautId}-${ctx.now.millisecondsSinceEpoch}',
        astronautId: ctx.astronautId,
        kind: MemoryKind.clinicalEvent,
        summary: summaryParts.join(' | '),
        createdAt: ctx.now.toUtc(),
        tags: tags,
        data: result.toJson(),
      ),
    );

    return result;
  }

  static String _normalize(String input) {
    final lower = input.toLowerCase();
    const replacements = {
      'á': 'a',
      'à': 'a',
      'ä': 'a',
      'â': 'a',
      'é': 'e',
      'è': 'e',
      'ë': 'e',
      'ê': 'e',
      'í': 'i',
      'ì': 'i',
      'ï': 'i',
      'î': 'i',
      'ó': 'o',
      'ò': 'o',
      'ö': 'o',
      'ô': 'o',
      'ú': 'u',
      'ù': 'u',
      'ü': 'u',
      'û': 'u',
      'ñ': 'n',
    };
    final buffer = StringBuffer();
    for (var i = 0; i < lower.length; i++) {
      final ch = lower[i];
      buffer.write(replacements[ch] ?? ch);
    }
    return buffer.toString();
  }

  static bool _containsPhrase(String normalizedText, String phrase) {
    final escaped = RegExp.escape(phrase);
    final pattern = RegExp('(^|[^a-z0-9])$escaped([^a-z0-9]|\$)');
    return pattern.hasMatch(normalizedText);
  }
}
