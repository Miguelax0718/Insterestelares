import 'dart:math' as math;
import 'package:astramed/features/agent/domain/agent_contracts.dart';

enum GraybielSymptom {
  nausea(
    wireName: 'nausea',
    label: 'Nausea syndrome',
    questionPrompt:
        'Rate nausea syndrome (none, minimal, minor, moderate, severe, or emesis).',
  ),
  pallor(
    wireName: 'pallor',
    label: 'Skin pallor',
    questionPrompt: 'Rate skin pallor (none, minimal, minor, moderate, severe).',
  ),
  coldSweating(
    wireName: 'cold_sweating',
    label: 'Cold sweating',
    questionPrompt:
        'Rate cold sweating (none, minimal, minor, moderate, severe).',
  ),
  salivation(
    wireName: 'salivation',
    label: 'Increased salivation',
    questionPrompt:
        'Rate increased salivation (none, minimal, minor, moderate, severe).',
  ),
  drowsiness(
    wireName: 'drowsiness',
    label: 'Drowsiness',
    questionPrompt: 'Rate drowsiness (none, minimal, minor, moderate, severe).',
  ),
  headache(
    wireName: 'headache',
    label: 'Pain / headache',
    questionPrompt:
        'Rate pain or headache (none, minimal, minor, moderate, severe).',
  ),
  dizziness(
    wireName: 'dizziness',
    label: 'Dizziness / vertigo',
    questionPrompt:
        'Rate dizziness or vertigo (none, minimal, minor, moderate, severe).',
  );

  const GraybielSymptom({
    required this.wireName,
    required this.label,
    required this.questionPrompt,
  });

  final String wireName;
  final String label;
  final String questionPrompt;

  static GraybielSymptom? tryParse(String raw) {
    final normalized = raw.trim().toLowerCase().replaceAll('-', '_');
    return switch (normalized) {
      'nausea' || 'nausea_syndrome' || 'stomach' => GraybielSymptom.nausea,
      'pallor' || 'skin_color' || 'skin_pallor' => GraybielSymptom.pallor,
      'cold_sweating' || 'sweating' || 'sweat' => GraybielSymptom.coldSweating,
      'salivation' || 'increased_salivation' => GraybielSymptom.salivation,
      'drowsiness' || 'fatigue' => GraybielSymptom.drowsiness,
      'headache' || 'pain' || 'pain_headache' => GraybielSymptom.headache,
      'dizziness' || 'vertigo' || 'dizziness_vertigo' =>
        GraybielSymptom.dizziness,
      _ => null,
    };
  }
}

enum GraybielLevel {
  none('none'),
  minimal('minimal'),
  minor('minor'),
  moderate('moderate'),
  severe('severe');

  const GraybielLevel(this.wireName);

  final String wireName;

  static GraybielLevel? tryParse(String raw) {
    final normalized = raw.trim().toLowerCase();
    return switch (normalized) {
      'none' || '0' || 'no' || 'ninguno' => GraybielLevel.none,
      'minimal' || '1' || 'minimo' || 'mínimo' => GraybielLevel.minimal,
      'minor' || '2' || 'mild' || 'leve' => GraybielLevel.minor,
      'moderate' || '3' || 'moderado' => GraybielLevel.moderate,
      'severe' || '4' || 'severo' || 'emesis' || 'vomiting' || 'vomit' =>
        GraybielLevel.severe,
      _ => null,
    };
  }
}

enum GraybielCategory {
  none('none'),
  minimal('minimal'),
  slight('slight'),
  moderateMalaise('moderate_malaise'),
  severeMalaise('severe_malaise'),
  frankSickness('frank_sickness');

  const GraybielCategory(this.wireName);

  final String wireName;
}

class GraybielEvaluation {
  const GraybielEvaluation({
    required this.responses,
    required this.emesis,
    required this.totalScore,
    required this.category,
    required this.evaBlockedRecommended,
    required this.gastricStasisSuspected,
    required this.recommendedRoute,
    required this.recommendedAction,
  });

  final Map<GraybielSymptom, GraybielLevel> responses;
  final bool emesis;
  final int totalScore;
  final GraybielCategory category;
  final bool evaBlockedRecommended;
  final bool gastricStasisSuspected;
  final String recommendedRoute;
  final String recommendedAction;

  Map<String, dynamic> toJson() => {
    'responses': {
      for (final symptom in GraybielSymptom.values)
        symptom.wireName: (responses[symptom] ?? GraybielLevel.none).wireName,
    },
    'emesis': emesis,
    'total_score': totalScore,
    'category': category.wireName,
    'eva_blocked_recommended': evaBlockedRecommended,
    'gastric_stasis_suspected': gastricStasisSuspected,
    'recommended_route': recommendedRoute,
    'recommended_action': recommendedAction,
  };
}

class GraybielEngine {
  GraybielEngine._();

  // D6 A2: Graybiel diagnostic point scale constants isolated for clinical review.
  static const int evaBlockScoreThreshold = 5;
  static const int gastricStasisScoreThreshold = 8;
  static const int frankSicknessThreshold = 16;
  static const int emesisPoints = 16;

  static const Map<GraybielLevel, int> _majorSymptomPoints = {
    GraybielLevel.none: 0,
    GraybielLevel.minimal: 1,
    GraybielLevel.minor: 2,
    GraybielLevel.moderate: 4,
    GraybielLevel.severe: 8,
  };

  static const Map<GraybielLevel, int> _aqsSymptomPoints = {
    GraybielLevel.none: 0,
    GraybielLevel.minimal: 1,
    GraybielLevel.minor: 1,
    GraybielLevel.moderate: 2,
    GraybielLevel.severe: 2,
  };

  static int pointsFor(
    GraybielSymptom symptom,
    GraybielLevel level, {
    bool emesis = false,
  }) {
    if (symptom == GraybielSymptom.nausea && emesis) {
      return emesisPoints;
    }
    return switch (symptom) {
      GraybielSymptom.headache ||
      GraybielSymptom.dizziness =>
        _aqsSymptomPoints[level] ?? 0,
      _ => _majorSymptomPoints[level] ?? 0,
    };
  }

  static GraybielCategory categorize(int score) {
    if (score >= frankSicknessThreshold) {
      return GraybielCategory.frankSickness;
    }
    if (score >= gastricStasisScoreThreshold) {
      return GraybielCategory.severeMalaise;
    }
    if (score >= evaBlockScoreThreshold) {
      return GraybielCategory.moderateMalaise;
    }
    if (score >= 3) {
      return GraybielCategory.slight;
    }
    if (score >= 1) {
      return GraybielCategory.minimal;
    }
    return GraybielCategory.none;
  }

  static GraybielEvaluation evaluate(
    Map<GraybielSymptom, GraybielLevel> responses, {
    bool emesis = false,
  }) {
    final normalized = <GraybielSymptom, GraybielLevel>{
      for (final symptom in GraybielSymptom.values)
        symptom: responses[symptom] ?? GraybielLevel.none,
    };
    if (emesis) {
      normalized[GraybielSymptom.nausea] = GraybielLevel.severe;
    }

    var total = 0;
    for (final symptom in GraybielSymptom.values) {
      total += pointsFor(
        symptom,
        normalized[symptom] ?? GraybielLevel.none,
        emesis: emesis && symptom == GraybielSymptom.nausea,
      );
    }

    final category = categorize(total);
    final evaBlocked = total >= evaBlockScoreThreshold;
    final severeNausea = normalized[GraybielSymptom.nausea] == GraybielLevel.severe;
    final gastricStasis =
        total >= gastricStasisScoreThreshold || emesis || severeNausea;
    final recommendedRoute = gastricStasis ? 'intranasal' : 'oral';

    final String action;
    if (gastricStasis) {
      action =
          'Block EVA and switch antiemetic administration to $recommendedRoute '
          '(suspected gastric stasis).';
    } else if (evaBlocked) {
      action =
          'Recommend EVA hold due to moderate space motion sickness (score $total).';
    } else if (total > 0) {
      action = 'Monitor vestibular symptoms and re-evaluate before EVA.';
    } else {
      action = 'No space motion sickness detected.';
    }

    return GraybielEvaluation(
      responses: Map.unmodifiable(normalized),
      emesis: emesis,
      totalScore: total,
      category: category,
      evaBlockedRecommended: evaBlocked,
      gastricStasisSuspected: gastricStasis,
      recommendedRoute: recommendedRoute,
      recommendedAction: action,
    );
  }
}

/// Experimental relative chromaticity screening, not a perfusion diagnosis.
enum ChromaticityStatus { nominal, elevated, critical }

/// Pure symptom assessment adapter; the established clinical scale stays authoritative.
class GraybielSymptomAssessment {
  const GraybielSymptomAssessment({this.responses = const {}, this.emesis = false});
  final Map<GraybielSymptom, GraybielLevel> responses;
  final bool emesis;
  GraybielEvaluation get evaluation => GraybielEngine.evaluate(responses, emesis: emesis);
  int get totalScore => evaluation.totalScore;
  bool get triggersEvaRestriction => evaluation.evaBlockedRecommended;
}

class FacialGreennessResult {
  const FacialGreennessResult(this.deltaGR, this.status);
  final double deltaGR;
  final ChromaticityStatus status;
}

abstract final class FacialGreennessAnalyzer {
  static FacialGreennessResult analyze({
    required double baselineGR,
    required double currentGR,
  }) {
    if (!baselineGR.isFinite || baselineGR <= 0 ||
        !currentGR.isFinite || currentGR < 0) {
      throw ArgumentError('Green/red ratios must be finite with a positive baseline.');
    }
    final delta = currentGR - baselineGR;
    return FacialGreennessResult(delta,
        delta >= .06 ? ChromaticityStatus.critical :
        delta >= .03 ? ChromaticityStatus.elevated : ChromaticityStatus.nominal);
  }
}

class GazeStabilityResult {
  const GazeStabilityResult(this.optotypeAccuracy, this.compositeScore, this.isStable);
  final double optotypeAccuracy;
  final double compositeScore;
  final bool isStable;
}

/// Touch answers and self-reported fixation only; does not measure clinical VOR.
abstract final class GazeStabilityAnalyzer {
  static GazeStabilityResult analyze({
    required int correctCount,
    required int total,
    required double fixationRatio,
    double rhythmHz = 1,
  }) {
    if (total < 0 || correctCount < 0 || correctCount > total ||
        !fixationRatio.isFinite || fixationRatio < 0 || fixationRatio > 1 ||
        !rhythmHz.isFinite || rhythmHz < 0) {
      throw ArgumentError('Invalid DVA counts, fixation, or rhythm.');
    }
    if (total == 0) return const GazeStabilityResult(0, 0, false);
    final accuracy = correctCount / total;
    final rhythm = (1 - (rhythmHz - 1).abs() / .8).clamp(0.0, 1.0);
    final score = .6 * fixationRatio + .25 * accuracy + .15 * rhythm;
    return GazeStabilityResult(accuracy, score, score >= .8 && fixationRatio >= .8);
  }
}

class ZeroGHorizonResult {
  const ZeroGHorizonResult(this.rmsErrorDeg, this.alignmentPct);
  final double rmsErrorDeg;
  final double alignmentPct;
  bool get severeDrift => alignmentPct < 70;
  String get driftRating => severeDrift ? 'Severe drift' : 'Aligned';
}

abstract final class ZeroGHorizonScorer {
  static ZeroGHorizonResult evaluate({
    required double pitch, required double roll, required double yaw,
  }) {
    if (![pitch, roll, yaw].every((v) => v.isFinite)) {
      throw ArgumentError('Axis errors must be finite.');
    }
    double wrap(double v) => ((v + 180) % 360 - 180).abs();
    final errors = [pitch, roll, yaw].map(wrap);
    final rms = math.sqrt(errors.fold<double>(0, (sum, v) => sum + v * v) / 3);
    return ZeroGHorizonResult(rms, ((1 - rms / 30) * 100).clamp(0.0, 100.0));
  }
}

class EvaSafetyAdvisory {
  const EvaSafetyAdvisory(this.evaNoGoRecommended);
  final bool evaNoGoRecommended;
  static EvaSafetyAdvisory evaluate({
    required int graybielScore, ZeroGHorizonResult? horizon,
  }) => EvaSafetyAdvisory(
    graybielScore >= GraybielEngine.evaBlockScoreThreshold ||
      (horizon?.severeDrift ?? false));
}

class GraybielSession {
  GraybielSession();

  final Map<GraybielSymptom, GraybielLevel> responses = {};
  bool emesis = false;
  int currentStepIndex = 0;
  bool completed = false;
  GraybielEvaluation? lastEvaluation;

  void reset() {
    responses.clear();
    emesis = false;
    currentStepIndex = 0;
    completed = false;
    lastEvaluation = null;
  }

  GraybielSymptom? get currentSymptom {
    if (currentStepIndex < 0 ||
        currentStepIndex >= GraybielSymptom.values.length) {
      return null;
    }
    return GraybielSymptom.values[currentStepIndex];
  }

  void recordAnswer(
    GraybielSymptom symptom,
    GraybielLevel level, {
    bool hasEmesis = false,
  }) {
    responses[symptom] = level;
    if (hasEmesis) {
      emesis = true;
      responses[GraybielSymptom.nausea] = GraybielLevel.severe;
    }
    lastEvaluation = GraybielEngine.evaluate(responses, emesis: emesis);
  }
}

class GraybielQuestionnaireViewModel extends AgentViewModel {
  const GraybielQuestionnaireViewModel({
    required this.astronautId,
    required this.answeredCount,
    required this.totalSymptoms,
    required this.responses,
    required this.emesis,
    required this.completed,
    this.currentSymptom,
    this.currentPrompt,
    this.evaluation,
  }) : super(
         componentId: ComponentIds.graybielQuestionnaire,
         title: 'Graybiel Motion Sickness Assessment',
       );

  factory GraybielQuestionnaireViewModel.fromProps(Map<String, dynamic> props) {
    final rawResponses =
        props['responses'] as Map<String, dynamic>? ?? const {};
    final parsedResponses = <GraybielSymptom, GraybielLevel>{};
    for (final entry in rawResponses.entries) {
      final symptom = GraybielSymptom.tryParse(entry.key);
      final level = GraybielLevel.tryParse(entry.value.toString());
      if (symptom != null && level != null) {
        parsedResponses[symptom] = level;
      }
    }
    final emesis = props['emesis'] as bool? ?? false;
    final completed = props['completed'] as bool? ?? false;
    final currentSymptomRaw = props['current_symptom'] as String?;
    return GraybielQuestionnaireViewModel(
      astronautId: props['astronaut_id'] as String? ?? 'AST-01',
      answeredCount:
          (props['answered_count'] as num?)?.toInt() ?? parsedResponses.length,
      totalSymptoms:
          (props['total_symptoms'] as num?)?.toInt() ??
          GraybielSymptom.values.length,
      responses: parsedResponses,
      emesis: emesis,
      completed: completed,
      currentSymptom: currentSymptomRaw == null
          ? null
          : GraybielSymptom.tryParse(currentSymptomRaw),
      currentPrompt: props['current_prompt'] as String?,
      evaluation: completed
          ? GraybielEngine.evaluate(parsedResponses, emesis: emesis)
          : null,
    );
  }

  final String astronautId;
  final GraybielSymptom? currentSymptom;
  final String? currentPrompt;
  final int answeredCount;
  final int totalSymptoms;
  final Map<GraybielSymptom, GraybielLevel> responses;
  final bool emesis;
  final bool completed;
  final GraybielEvaluation? evaluation;

  @override
  Map<String, dynamic> toProps() => {
    'component_id': componentId,
    'title': title,
    'astronaut_id': astronautId,
    if (currentSymptom != null) 'current_symptom': currentSymptom!.wireName,
    if (currentPrompt != null) 'current_prompt': currentPrompt,
    'answered_count': answeredCount,
    'total_symptoms': totalSymptoms,
    'responses': {
      for (final entry in responses.entries)
        entry.key.wireName: entry.value.wireName,
    },
    'emesis': emesis,
    'completed': completed,
    if (evaluation != null) 'evaluation': evaluation!.toJson(),
  };
}

class GraybielOfflineFlow implements DeterministicFlow {
  GraybielOfflineFlow([Map<String, GraybielSession>? sessions])
    : _sessions = sessions ?? {};

  static const List<String> levelOptions = [
    'none',
    'minimal',
    'minor',
    'moderate',
    'severe',
  ];

  final Map<String, GraybielSession> _sessions;

  GraybielSession _sessionFor(String astronautId) {
    return _sessions.putIfAbsent(astronautId, GraybielSession.new);
  }

  @override
  String get skillId => 'graybiel';

  @override
  Future<DeterministicStep> start(ToolContext ctx) async {
    final session = _sessionFor(ctx.astronautId)..reset();
    final symptom = session.currentSymptom!;
    final vm = GraybielQuestionnaireViewModel(
      astronautId: ctx.astronautId,
      answeredCount: 0,
      totalSymptoms: GraybielSymptom.values.length,
      responses: const {},
      emesis: false,
      completed: false,
      currentSymptom: symptom,
      currentPrompt: symptom.questionPrompt,
    );
    final event = AgentComponentEvent.show(
      ComponentIds.graybielQuestionnaire,
      vm.toProps(),
    );
    ctx.ui.emit(event);
    return DeterministicStep(
      prompt: 'Graybiel step 1/${GraybielSymptom.values.length}: '
          '${symptom.questionPrompt}',
      options: levelOptions,
      uiEvents: [event],
    );
  }

  @override
  Future<DeterministicStep> advance(String userInput, ToolContext ctx) async {
    final session = _sessionFor(ctx.astronautId);
    if (session.completed) {
      return start(ctx);
    }

    final current = session.currentSymptom ?? GraybielSymptom.nausea;
    final lower = userInput.trim().toLowerCase();
    final isEmesis =
        lower.contains('emesis') ||
        lower.contains('vomit') ||
        lower.contains('retching');
    final parsedLevel =
        isEmesis ? GraybielLevel.severe : GraybielLevel.tryParse(userInput);

    if (parsedLevel == null) {
      return DeterministicStep(
        prompt: 'Please answer with one of: none, minimal, minor, moderate, '
            'or severe. ${current.questionPrompt}',
        options: levelOptions,
      );
    }

    session.recordAnswer(
      current,
      parsedLevel,
      hasEmesis: current == GraybielSymptom.nausea && isEmesis,
    );
    session.currentStepIndex++;

    final next = session.currentSymptom;
    if (next == null) {
      session.completed = true;
      final evaluation = GraybielEngine.evaluate(
        session.responses,
        emesis: session.emesis,
      );
      session.lastEvaluation = evaluation;
      final vm = GraybielQuestionnaireViewModel(
        astronautId: ctx.astronautId,
        answeredCount: GraybielSymptom.values.length,
        totalSymptoms: GraybielSymptom.values.length,
        responses: Map.unmodifiable(session.responses),
        emesis: session.emesis,
        completed: true,
        evaluation: evaluation,
      );
      final event = AgentComponentEvent.show(
        ComponentIds.graybielQuestionnaire,
        vm.toProps(),
      );
      ctx.ui.emit(event);
      return DeterministicStep(
        prompt:
            'Graybiel score ${evaluation.totalScore} (${evaluation.category.wireName}). '
            '${evaluation.recommendedAction}',
        uiEvents: [event],
        isTerminal: true,
        verdict: evaluation.toJson(),
      );
    }

    final vm = GraybielQuestionnaireViewModel(
      astronautId: ctx.astronautId,
      answeredCount: session.currentStepIndex,
      totalSymptoms: GraybielSymptom.values.length,
      responses: Map.unmodifiable(session.responses),
      emesis: session.emesis,
      completed: false,
      currentSymptom: next,
      currentPrompt: next.questionPrompt,
    );
    final event = AgentComponentEvent.show(
      ComponentIds.graybielQuestionnaire,
      vm.toProps(),
    );
    ctx.ui.emit(event);
    return DeterministicStep(
      prompt:
          'Graybiel step ${session.currentStepIndex + 1}/${GraybielSymptom.values.length}: '
          '${next.questionPrompt}',
      options: levelOptions,
      uiEvents: [event],
    );
  }
}
