import 'dart:math' as math;

import '../../agent/domain/agent_contracts.dart';
import '../domain/apolo_models.dart';
import '../providers/apolo_contract_providers.dart';

class ApoloUrineSkill extends AgentSkill {
  ApoloUrineSkill()
    : super(
        id: 'apolo_urine_health',
        instructions:
            'You are APOLO, the crew\'s space-health assistant dog for urine biomarkers and daily wellness. '
            'Keep a calm, playful, lightly teasing Navi-and-TARS tone—gently nudging hydration, workouts, and due samples in short, plain-text TTS sentences, never preachy or robotic. '
            'On any critical (crit) module or emergency, drop all jokes immediately (zero humor) and give clear, direct guidance first. '
            'Use get_apolo_modules for an overview of all 8 health circles, '
            'get_apolo_biomarker_detail to inspect biomarkers and reveal a circle, '
            'log_water_intake (50-2000 ml) when the astronaut reports drinking water, '
            'log_exercise_minutes (1-300 min) when reporting exercise, '
            'submit_urine_sample when a new urine sample is taken, '
            'complete_recommendation to check off an action item, and '
            'show_apolo_orbs to control which circles appear on stage. '
            'Relay exact metrics and recommendations concisely without inventing thresholds.',
        tools: const [
          GetApoloModulesTool(),
          GetApoloBiomarkerDetailTool(),
          LogWaterIntakeTool(),
          LogExerciseMinutesTool(),
          SubmitUrineSampleTool(),
          CompleteRecommendationTool(),
          ShowApoloOrbsTool(),
        ],
        triggers: const [
          'apolo',
          'checkup',
          'status',
          'alerts',
          'critical',
          'water',
          'agua',
          'hydration',
          'hidratacion',
          'drink',
          'drank',
          'tome',
          'bebi',
          'ml',
          'kidney',
          'kidneys',
          'renal',
          'rinon',
          'stone',
          'stones',
          'calcium',
          'oxalate',
          'citrate',
          'bone',
          'bones',
          'osea',
          'hueso',
          'ntx',
          'ctx',
          'resorption',
          'exercise',
          'ejercicio',
          'workout',
          'urine',
          'orina',
          'sample',
          'muestra',
          'biomarker',
          'biomarkers',
          'radiation',
          'radiacion',
          '8-ohdg',
          'ohdg',
          'isoprostanes',
          'immunity',
          'inmunidad',
          'immune',
          'infection',
          'leukocytes',
          'nitrites',
          'cardio',
          'heart',
          'sodium',
          'potassium',
          'na/k',
          'stress',
          'sleep',
          'sueno',
          'cortisol',
          'melatonin',
          'metabolism',
          'metabolismo',
          'ketones',
          'protein',
          'glucose',
          'urea',
          'how am i',
          'como estoy',
          'summary',
          'resumen',
          'show all',
          'urgent',
          'circles',
          'orbs',
        ],
        offlineFlow: const ApoloUrineOfflineFlow(),
      );
}

ApoloStateActions _readActions(ToolContext ctx) =>
    ctx.read<ApoloStateActions>(apoloActionsProvider);

String _targetAstronautId(Map<String, dynamic> args, ToolContext ctx) {
  final raw = args['astronaut_id'] as String?;
  if (raw != null && raw.trim().isNotEmpty) {
    return raw.trim();
  }
  return ctx.astronautId;
}

class GetApoloModulesTool extends AgentTool {
  const GetApoloModulesTool();

  @override
  String get name => 'get_apolo_modules';

  @override
  String get description =>
      'Returns overall severity, urine sample schedule, hydration/exercise progress, and all 8 APOLO health modules for the astronaut.';

  @override
  ToolEffect get effect => ToolEffect.read;

  @override
  Map<String, dynamic> get parameters => const {
    'type': 'object',
    'properties': {
      'astronaut_id': {
        'type': 'string',
        'description': 'Optional astronaut ID (AST-01..AST-05 or alias).',
      },
    },
  };

  @override
  Future<ToolResult> call(Map<String, dynamic> args, ToolContext ctx) async {
    final actions = _readActions(ctx);
    final state = actions.stateFor(_targetAstronautId(args, ctx));
    final modules = [
      for (final mod in state.rankedModules)
        {
          'id': mod.id.name,
          'title': mod.title,
          'short_label': mod.shortLabel,
          'severity': mod.severity.wire,
          'key_metric': mod.keyMetric,
          'sub_metric': mod.subMetric,
        },
    ];

    return ToolResult.ok({
      'astronaut_id': state.astronautId,
      'name': state.name,
      'mission_day': state.missionDay,
      'overall_severity': state.overallSeverity.wire,
      'water_ml_today': state.waterMlToday,
      'water_goal_ml': state.waterGoalMl,
      'exercise_min_today': state.exerciseMinToday,
      'exercise_goal_min': state.exerciseGoalMin,
      'sample_schedule': {
        'is_due': state.sampleSchedule.isDue,
        'short_label': state.sampleSchedule.shortLabel,
        'title': state.sampleSchedule.title,
        'subtitle': state.sampleSchedule.subtitle,
      },
      'visible_orbs': [for (final id in state.visibleOrbs) id.name],
      'modules': modules,
    });
  }
}

class GetApoloBiomarkerDetailTool extends AgentTool {
  const GetApoloBiomarkerDetailTool();

  @override
  String get name => 'get_apolo_biomarker_detail';

  @override
  String get description =>
      'Reveals the requested APOLO module orb on stage and returns its biomarkers, recommendations, and whyItMatters explanation.';

  @override
  ToolEffect get effect => ToolEffect.ui;

  @override
  Map<String, dynamic> get parameters => const {
    'type': 'object',
    'required': ['module_id'],
    'properties': {
      'module_id': {
        'type': 'string',
        'enum': [
          'hidratacion',
          'renal',
          'osea',
          'radiacion',
          'inmunidad',
          'cardio',
          'estres',
          'metabolismo',
        ],
        'description': 'Target APOLO module ID.',
      },
      'astronaut_id': {'type': 'string'},
    },
  };

  @override
  Future<ToolResult> call(Map<String, dynamic> args, ToolContext ctx) async {
    final rawModule = args['module_id'] as String? ?? '';
    final modId = ApoloModuleId.tryParse(rawModule);
    if (modId == null) {
      return ToolResult.fail(
        'Invalid module_id "$rawModule". Expected one of: '
        '${ApoloModuleId.values.map((m) => m.name).join(', ')}.',
      );
    }

    final actions = _readActions(ctx);
    final targetId = _targetAstronautId(args, ctx);
    actions.showOrbs([modId]);
    final state = actions.stateFor(targetId);
    final snap = state.modules[modId]!;

    return ToolResult.ok({
      'astronaut_id': state.astronautId,
      'module_id': snap.id.name,
      'title': snap.title,
      'severity': snap.severity.wire,
      'key_metric': snap.keyMetric,
      'sub_metric': snap.subMetric,
      'measures': snap.measures,
      'why_it_matters': snap.whyItMatters,
      'biomarkers': [
        for (final b in snap.biomarkers)
          {
            'id': b.def.id,
            'name': b.def.name,
            'value': b.def.isBoolean ? (b.value > 0) : b.value,
            'unit': b.def.unit,
            'formatted': b.formattedValue,
            'severity': b.severity.wire,
            if (!b.def.isBoolean) 'lo': b.personalLo,
            if (!b.def.isBoolean) 'hi': b.personalHi,
          },
      ],
      'recommendations': [
        for (final r in snap.recommendations)
          {
            'id': r.id,
            'priority': r.priority,
            'text': r.text,
            'why': r.why,
            'done': r.done,
          },
      ],
    });
  }
}

class LogWaterIntakeTool extends AgentTool {
  const LogWaterIntakeTool();

  @override
  String get name => 'log_water_intake';

  @override
  String get description =>
      'Logs water intake in milliliters (50-2000 ml), reveals the hydration orb, and returns updated daily hydration totals.';

  @override
  ToolEffect get effect => ToolEffect.ui;

  @override
  Map<String, dynamic> get parameters => const {
    'type': 'object',
    'required': ['ml'],
    'properties': {
      'ml': {
        'type': 'integer',
        'minimum': 50,
        'maximum': 2000,
        'description': 'Water volume in milliliters (50 to 2000).',
      },
      'astronaut_id': {'type': 'string'},
    },
  };

  @override
  Future<ToolResult> call(Map<String, dynamic> args, ToolContext ctx) async {
    final rawMl = args['ml'];
    final ml = rawMl is num ? rawMl.round() : int.tryParse('$rawMl');
    if (ml == null || ml < 50 || ml > 2000) {
      return const ToolResult.fail(
        'Water intake must be between 50 and 2000 ml.',
      );
    }

    final actions = _readActions(ctx);
    final targetId = _targetAstronautId(args, ctx);
    final ok = actions.addWater(ml, astronautId: targetId);
    if (!ok) {
      return const ToolResult.fail(
        'Water intake must be between 50 and 2000 ml.',
      );
    }

    final state = actions.stateFor(targetId);
    final remaining = math.max(0, state.waterGoalMl - state.waterMlToday);

    return ToolResult.ok({
      'astronaut_id': state.astronautId,
      'logged_ml': ml,
      'water_ml_today': state.waterMlToday,
      'water_goal_ml': state.waterGoalMl,
      'remaining_ml': remaining,
      'goal_reached': remaining == 0,
      'hydration_severity':
          state.modules[ApoloModuleId.hidratacion]!.severity.wire,
    });
  }
}

class LogExerciseMinutesTool extends AgentTool {
  const LogExerciseMinutesTool();

  @override
  String get name => 'log_exercise_minutes';

  @override
  String get description =>
      'Logs exercise duration in minutes (1-300), increments weekly resistance sessions, reveals the bone orb, and returns updated totals.';

  @override
  ToolEffect get effect => ToolEffect.ui;

  @override
  Map<String, dynamic> get parameters => const {
    'type': 'object',
    'required': ['minutes'],
    'properties': {
      'minutes': {
        'type': 'integer',
        'minimum': 1,
        'maximum': 300,
        'description': 'Exercise duration in minutes (1 to 300).',
      },
      'astronaut_id': {'type': 'string'},
    },
  };

  @override
  Future<ToolResult> call(Map<String, dynamic> args, ToolContext ctx) async {
    final rawMin = args['minutes'];
    final minutes = rawMin is num ? rawMin.round() : int.tryParse('$rawMin');
    if (minutes == null || minutes < 1 || minutes > 300) {
      return const ToolResult.fail(
        'Exercise duration must be between 1 and 300 minutes.',
      );
    }

    final actions = _readActions(ctx);
    final targetId = _targetAstronautId(args, ctx);
    final ok = actions.addExercise(minutes, astronautId: targetId);
    if (!ok) {
      return const ToolResult.fail(
        'Exercise duration must be between 1 and 300 minutes.',
      );
    }

    final state = actions.stateFor(targetId);
    final remaining = math.max(
      0,
      state.exerciseGoalMin - state.exerciseMinToday,
    );

    return ToolResult.ok({
      'astronaut_id': state.astronautId,
      'logged_minutes': minutes,
      'exercise_min_today': state.exerciseMinToday,
      'exercise_goal_min': state.exerciseGoalMin,
      'remaining_minutes': remaining,
      'resistance_sessions_week': state.resistanceSessionsWeek,
      'bone_severity': state.modules[ApoloModuleId.osea]!.severity.wire,
    });
  }
}

class SubmitUrineSampleTool extends AgentTool {
  const SubmitUrineSampleTool();

  @override
  String get name => 'submit_urine_sample';

  @override
  String get description =>
      'Records a new urine biomarker sample and resets the sample countdown schedule.';

  @override
  ToolEffect get effect => ToolEffect.ui;

  @override
  Map<String, dynamic> get parameters => const {
    'type': 'object',
    'properties': {
      'method': {
        'type': 'string',
        'description': 'Collection method (e.g. sensor, strip, manual).',
      },
      'astronaut_id': {'type': 'string'},
    },
  };

  @override
  Future<ToolResult> call(Map<String, dynamic> args, ToolContext ctx) async {
    final rawMethod = args['method'] as String?;
    final method = (rawMethod != null && rawMethod.trim().isNotEmpty)
        ? rawMethod.trim()
        : 'sensor';
    final actions = _readActions(ctx);
    final targetId = _targetAstronautId(args, ctx);
    final sample = actions.submitSample(method: method, astronautId: targetId);
    final state = actions.stateFor(targetId);

    return ToolResult.ok({
      'astronaut_id': state.astronautId,
      'sample_id': sample.id,
      'method': sample.method,
      'mission_day': sample.missionDay,
      'taken_at': sample.takenAt.toUtc().toIso8601String(),
      'overall_severity': state.overallSeverity.wire,
      'sample_schedule': {
        'is_due': state.sampleSchedule.isDue,
        'short_label': state.sampleSchedule.shortLabel,
        'title': state.sampleSchedule.title,
        'subtitle': state.sampleSchedule.subtitle,
        'next_slot': state.sampleSchedule.nextSlot.toUtc().toIso8601String(),
      },
    });
  }
}

class CompleteRecommendationTool extends AgentTool {
  const CompleteRecommendationTool();

  @override
  String get name => 'complete_recommendation';

  @override
  String get description =>
      'Marks an APOLO recommendation as done (or undone) for the astronaut.';

  @override
  ToolEffect get effect => ToolEffect.ui;

  @override
  Map<String, dynamic> get parameters => const {
    'type': 'object',
    'required': ['recommendation_id'],
    'properties': {
      'recommendation_id': {
        'type': 'string',
        'description': 'ID of the recommendation to mark complete.',
      },
      'done': {
        'type': 'boolean',
        'description': 'Completion state; defaults to true.',
      },
      'astronaut_id': {'type': 'string'},
    },
  };

  @override
  Future<ToolResult> call(Map<String, dynamic> args, ToolContext ctx) async {
    final recId = (args['recommendation_id'] as String? ?? '').trim();
    if (recId.isEmpty) {
      return const ToolResult.fail('recommendation_id is required.');
    }
    final done = args['done'] as bool? ?? true;
    final actions = _readActions(ctx);
    final targetId = _targetAstronautId(args, ctx);
    final before = actions.stateFor(targetId);

    ApoloRecommendation? found;
    for (final mod in before.modules.values) {
      for (final rec in mod.recommendations) {
        if (rec.id == recId) {
          found = rec;
          break;
        }
      }
      if (found != null) break;
    }
    if (found == null) {
      return ToolResult.fail('Recommendation "$recId" not found.');
    }

    actions.toggleRecommendation(recId, done, astronautId: targetId);
    return ToolResult.ok({
      'astronaut_id': before.astronautId,
      'recommendation_id': recId,
      'module_id': found.moduleId.name,
      'text': found.text,
      'done': done,
    });
  }
}

class ShowApoloOrbsTool extends AgentTool {
  const ShowApoloOrbsTool();

  @override
  String get name => 'show_apolo_orbs';

  @override
  String get description =>
      'Updates which APOLO health orbs are visible on stage: pass module_ids, all=true, urgent_only=true, or hide_module_id.';

  @override
  ToolEffect get effect => ToolEffect.ui;

  @override
  Map<String, dynamic> get parameters => const {
    'type': 'object',
    'properties': {
      'module_ids': {
        'type': 'array',
        'items': {'type': 'string'},
        'description': 'List of module IDs to display on stage.',
      },
      'all': {
        'type': 'boolean',
        'description': 'Set true to display all 8 health orbs.',
      },
      'urgent_only': {
        'type': 'boolean',
        'description': 'Set true to show only non-ok alert orbs.',
      },
      'hide_module_id': {
        'type': 'string',
        'description': 'Optional module ID to hide from stage.',
      },
      'astronaut_id': {'type': 'string'},
    },
  };

  @override
  Future<ToolResult> call(Map<String, dynamic> args, ToolContext ctx) async {
    final actions = _readActions(ctx);
    final targetId = _targetAstronautId(args, ctx);
    final showAll = args['all'] == true;
    final urgentOnly = args['urgent_only'] == true;
    final hideRaw = args['hide_module_id'] as String?;
    final rawIds = args['module_ids'];

    if (showAll) {
      actions.showAllOrbs();
    } else if (urgentOnly) {
      actions.resetOrbsToUrgent();
    } else if (hideRaw != null && hideRaw.trim().isNotEmpty) {
      final hideId = ApoloModuleId.tryParse(hideRaw);
      if (hideId == null) {
        return ToolResult.fail('Invalid hide_module_id "$hideRaw".');
      }
      actions.hideOrb(hideId);
    } else if (rawIds is List) {
      final parsed = <ApoloModuleId>[];
      for (final item in rawIds) {
        final mod = ApoloModuleId.tryParse(item.toString());
        if (mod != null) parsed.add(mod);
      }
      if (parsed.isEmpty) {
        return const ToolResult.fail(
          'No valid module IDs provided in module_ids.',
        );
      }
      actions.showOrbs(parsed);
    } else {
      return const ToolResult.fail(
        'Provide module_ids, all=true, urgent_only=true, or hide_module_id.',
      );
    }

    final updated = actions.stateFor(targetId);
    return ToolResult.ok({
      'astronaut_id': updated.astronautId,
      'visible_orbs': [for (final id in updated.visibleOrbs) id.name],
    });
  }
}

class ApoloUrineOfflineFlow implements QueryAwareDeterministicFlow {
  const ApoloUrineOfflineFlow();

  /// The first offline message is answered directly ("I drank 500 ml" logs
  /// the water right away); [advance] falls back to the greeting for
  /// anything it does not recognise.
  @override
  Future<DeterministicStep> startWithQuery(String query, ToolContext ctx) =>
      advance(query, ctx);

  static final Map<ApoloModuleId, RegExp> _modulePatterns = {
    ApoloModuleId.hidratacion: RegExp(
      r'water|hydrat|thirst|drink|agua|hidrat|sed|beb|liquid',
    ),
    ApoloModuleId.renal: RegExp(
      r'kidney|renal|stone|calcul|calcium|oxalat|citrat|rinon|piedra',
    ),
    ApoloModuleId.osea: RegExp(r'bone|osea|ntx|ctx|fractur|resorp|hueso'),
    ApoloModuleId.radiacion: RegExp(
      r'radiat|radiac|solar|storm|tormenta|dose|dosis|msv|eva|ohdg|iso',
    ),
    ApoloModuleId.inmunidad: RegExp(
      r'infect|inmun|defens|immun|nitrit|leukocyt|leucocit',
    ),
    ApoloModuleId.cardio: RegExp(
      r'heart|cardio|sodium|potassium|sodio|potasio|corazon|presion|\bsalt\b',
    ),
    ApoloModuleId.estres: RegExp(
      r'stress|sleep|cortisol|melatonin|tired|estres|sueno|dorm|cansad',
    ),
    ApoloModuleId.metabolismo: RegExp(
      r'metab|energ|ketone|protein|glucose|urea|comida|ceton|proteina|hambre',
    ),
  };

  @override
  String get skillId => 'apolo_urine_health';

  @override
  Future<DeterministicStep> start(ToolContext ctx) async {
    final actions = _readActions(ctx);
    final state = actions.stateFor(ctx.astronautId);
    final ranked = state.rankedModules;
    final bad = ranked.where((m) => m.severity != ApoloSeverity.ok).toList();
    final isCrit = bad.isNotEmpty && bad.first.severity == ApoloSeverity.crit;

    final buffer = StringBuffer('Hi, ${state.firstName}! ');
    if (state.samples.isEmpty) {
      buffer.write(
        'I do not have any urine samples yet. Submit your first sample so I can build your baseline.',
      );
    } else if (isCrit) {
      buffer.write(
        'Something needs urgent attention: ${bad.first.title} is critical (${bad.first.keyMetric}).',
      );
    } else if (bad.isNotEmpty) {
      final names = bad.map((m) => m.title.toLowerCase()).join(' and ');
      buffer.write(
        'Hey, listen—almost everything looks steady, though ${bad.length == 1 ? 'one area needs' : '${bad.length} areas need'} attention: $names.',
      );
    } else {
      buffer.write(
        'All eight circles look steady today. Ask me about any circle—I am keeping an ear up.',
      );
    }

    if (state.sampleSchedule.isDue && state.samples.isNotEmpty) {
      buffer.write(
        isCrit
            ? ' Also, your urine sample is due now.'
            : ' Also, your urine sample is due now—just a friendly nudge.',
      );
    }

    return DeterministicStep(
      prompt: buffer.toString(),
      options: const [
        'How am I?',
        'Show all',
        'Urgent only',
        'What should I do today?',
      ],
    );
  }

  @override
  Future<DeterministicStep> advance(String userInput, ToolContext ctx) async {
    final actions = _readActions(ctx);
    final t = _normalize(userInput);

    // 1. Water logging ("I drank 500 ml", "tomé 500 ml", "2 glasses", "0.5 l")
    final waterMatch = RegExp(
      r'(\d+(?:[.,]\d+)?)\s*(ml|milliliters?|mililitros?|l\b|liters?|litros?|glass(?:es)?|vasos?)',
    ).firstMatch(t);
    if (waterMatch != null &&
        (RegExp(
              r'drank|drink|water|log|add|tome|bebi|tomo|bebo|agrega|anota|registra|suma|agua',
            ).hasMatch(t) ||
            waterMatch.group(2)!.startsWith('vaso') ||
            waterMatch.group(2)!.startsWith('glass') ||
            waterMatch.group(2) == 'ml')) {
      final rawNum = double.parse(waterMatch.group(1)!.replaceAll(',', '.'));
      final unit = waterMatch.group(2)!;
      final ml = (unit.startsWith('vaso') || unit.startsWith('glass'))
          ? (rawNum * 250).round()
          : unit.startsWith('l')
          ? (rawNum * 1000).round()
          : rawNum.round();

      if (!actions.addWater(ml, astronautId: ctx.astronautId)) {
        return const DeterministicStep(
          prompt: 'I can log between 50 and 2000 ml of water at a time.',
          options: ['How am I?', 'Show all'],
        );
      }
      final updated = actions.stateFor(ctx.astronautId);
      final left = math.max(0, updated.waterGoalMl - updated.waterMlToday);
      final leftMsg = left > 0
          ? '${(left / 1000).toStringAsFixed(1)} L remaining for today\'s goal${updated.overallSeverity == ApoloSeverity.crit ? '.' : '—yes, I am keeping count.'}'
          : 'You reached today\'s hydration goal! Nicely done.';
      return DeterministicStep(
        prompt: 'Logged +$ml ml of water. $leftMsg',
        options: const ['How am I?', 'What should I do today?'],
      );
    }

    // 2. Exercise logging ("30 min exercise", "hice 45 min ejercicio", "1 h workout")
    final exMatch = RegExp(r'(\d+)\s*(min|minutes?|minutos?|h\b|hours?|horas?)')
        .firstMatch(t);
    if (exMatch != null &&
        RegExp(
          r'exercis|workout|train|gym|run|bike|strength|resist|ejercicio|entren|hice|corri|bici|pesas|fuerza',
        ).hasMatch(t)) {
      final n = int.parse(exMatch.group(1)!);
      final unit = exMatch.group(2)!;
      final minutes = unit.startsWith('h') ? n * 60 : n;

      if (!actions.addExercise(minutes, astronautId: ctx.astronautId)) {
        return const DeterministicStep(
          prompt: 'I can log between 1 and 300 minutes of exercise.',
          options: ['How am I?', 'Bones'],
        );
      }
      final updated = actions.stateFor(ctx.astronautId);
      return DeterministicStep(
        prompt: updated.overallSeverity == ApoloSeverity.crit
            ? 'Logged $minutes min of exercise. You are at ${updated.exerciseMinToday} of ${updated.exerciseGoalMin} min today. Critical alerts still require attention.'
            : 'Nice work! Logged $minutes min of exercise. You are at ${updated.exerciseMinToday} of ${updated.exerciseGoalMin} min today—your bones owe you one.',
        options: const ['How are my bones?', 'How am I?'],
      );
    }

    // 3. Submit urine sample
    if (RegExp(
      r'submit sample|submitted sample|took sample|ya la tome|ya tome la muestra|log sample',
    ).hasMatch(t)) {
      actions.submitSample(astronautId: ctx.astronautId);
      final updated = actions.stateFor(ctx.astronautId);
      final suffix = updated.overallSeverity == ApoloSeverity.crit
          ? ''
          : ' That keeps me happy.';
      return DeterministicStep(
        prompt:
            'Sample received and analyzed. ${updated.sampleSchedule.title}.$suffix',
        options: const ['How am I?', 'Show all'],
      );
    }

    // 4. Thanks
    if (RegExp(r'thanks|thank you|gracias|genial|bien hecho|good boy')
        .hasMatch(t)) {
      final state = actions.stateFor(ctx.astronautId);
      return DeterministicStep(
        prompt: state.overallSeverity == ApoloSeverity.crit
            ? 'You are welcome, ${state.firstName}. Critical alerts still require attention.'
            : 'Woof! Anytime, ${state.firstName}. Just trying to keep you in one piece up here.',
        options: const ['How am I?', 'Show all'],
      );
    }

    // 5. Show all circles
    if (RegExp(
      r'show all|all circles|all my data|muestr?a(?:me)? todo|todos mis datos|ver todo',
    ).hasMatch(t)) {
      actions.showAllOrbs();
      final state = actions.stateFor(ctx.astronautId);
      return DeterministicStep(
        prompt:
            'Here are all ${state.visibleOrbs.length} health circles. Tap any circle for biomarker details.',
        options: const ['Urgent only', 'How am I?'],
      );
    }

    // 6. Urgent only / hide
    if (RegExp(
      r'urgent only|only urgent|solo lo urgente|hide|oculta|limpia|menos circulos',
    ).hasMatch(t)) {
      actions.resetOrbsToUrgent();
      return const DeterministicStep(
        prompt: 'Done, only urgent alerts remain visible.',
        options: ['Show all', 'How am I?'],
      );
    }

    // 7. Module queries (and "why does it matter")
    ApoloModuleId? matchedModule;
    for (final entry in _modulePatterns.entries) {
      if (entry.value.hasMatch(t)) {
        matchedModule = entry.key;
        break;
      }
    }

    if (RegExp(r'why|matter|importa|por que|porque|para que').hasMatch(t)) {
      final state = actions.stateFor(ctx.astronautId);
      final target = matchedModule ?? state.rankedModules.first.id;
      actions.showOrbs([target]);
      final snap = state.modules[target]!;
      return DeterministicStep(
        prompt: '${snap.title}: ${snap.whyItMatters}',
        options: const ['How am I?', 'What should I do today?'],
      );
    }

    if (matchedModule != null) {
      actions.showOrbs([matchedModule]);
      final state = actions.stateFor(ctx.astronautId);
      final snap = state.modules[matchedModule]!;
      final pendingRec = snap.recommendations.where((r) => !r.done).firstOrNull;
      final recNote = pendingRec != null
          ? ' Priority action: ${pendingRec.text}.'
          : (snap.severity == ApoloSeverity.ok ? ' Looking good!' : '');
      return DeterministicStep(
        prompt:
            '${snap.title} (${snap.severity.label}): ${snap.keyMetric}, ${snap.subMetric}.$recNote',
        options: const ['Why does it matter?', 'How am I?'],
      );
    }

    // 8. Sample status
    if (RegExp(r'sample|urine|when.*next|muestra|orina|cuando toca')
        .hasMatch(t)) {
      final state = actions.stateFor(ctx.astronautId);
      final sch = state.sampleSchedule;
      return DeterministicStep(
        prompt: '${sch.title}. ${sch.subtitle}.',
        options: const ['Submit sample', 'How am I?'],
      );
    }

    // 9. Summary / how am I
    if (RegExp(
      r'how am i|summary|status|overview|como estoy|resumen|estado|como voy|alerta',
    ).hasMatch(t)) {
      final state = actions.stateFor(ctx.astronautId);
      final ranked = state.rankedModules;
      final crit = ranked
          .where((m) => m.severity == ApoloSeverity.crit)
          .toList();
      final warn = ranked
          .where((m) => m.severity == ApoloSeverity.warn)
          .toList();
      final urgentIds = [...crit, ...warn].map((m) => m.id).toList();
      if (urgentIds.isNotEmpty) {
        actions.showOrbs(urgentIds);
      }

      if (state.samples.isEmpty) {
        return const DeterministicStep(
          prompt: 'I do not have any urine samples for you yet. Submit your first sample to build your baseline.',
          options: ['Submit sample'],
        );
      }
      if (crit.isEmpty && warn.isEmpty) {
        return const DeterministicStep(
          prompt:
              'All 8 health circles are stable. Great work—nothing for me to nag you about!',
          options: ['Show all', 'What should I do today?'],
        );
      }
      final parts = <String>[
        if (crit.isNotEmpty)
          '${crit.length} critical (${crit.map((m) => m.title).join(', ')})',
        if (warn.isNotEmpty)
          '${warn.length} needing attention (${warn.map((m) => m.title).join(', ')})',
      ];
      final suffix = crit.isEmpty
          ? ' Everything else is stable—consider this a gentle nudge.'
          : ' Everything else is stable.';
      return DeterministicStep(
        prompt: '${parts.join(' and ')}.$suffix',
        options: const ['What should I do today?', 'Show all'],
      );
    }

    // 10. Recommendations / tips / what to do
    if (RegExp(
      r'tip|advice|what should i do|recommend|consejo|que hago|recomend|hoy',
    ).hasMatch(t)) {
      final state = actions.stateFor(ctx.astronautId);
      final pending = [
        for (final mod in state.rankedModules)
          for (final rec in mod.recommendations)
            if (!rec.done) rec,
      ];
      if (pending.isNotEmpty) {
        final top = pending.first;
        actions.showOrbs([top.moduleId]);
        return DeterministicStep(
          prompt: '${top.text}. ${top.why}',
          options: const ['How am I?', 'Show all'],
        );
      }
      final waterLeft = math.max(0, state.waterGoalMl - state.waterMlToday);
      final waterNote = waterLeft > 0
          ? '${(waterLeft / 1000).toStringAsFixed(1)} L water remaining'
          : 'Hydration goal complete';
      return DeterministicStep(
        prompt:
            '$waterNote and ${state.exerciseMinToday} of ${state.exerciseGoalMin} min exercise logged today.',
        options: const ['I drank 250 ml', '30 min exercise'],
      );
    }

    // 11. Greeting
    if (RegExp(r'^(hi|hello|hey|hola|buen|que tal)\b').hasMatch(t)) {
      return start(ctx);
    }

    return const DeterministicStep(
      prompt: 'I can summarize your 8 health circles, inspect kidney/bone/hydration biomarkers, log water or exercise, or check your urine sample schedule.',
      options: ['How am I?', 'Show all', 'What should I do today?'],
    );
  }

  static String _normalize(String raw) {
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
    final lower = raw.toLowerCase().trim();
    final sb = StringBuffer();
    for (var i = 0; i < lower.length; i++) {
      final ch = lower[i];
      sb.write(replacements[ch] ?? ch);
    }
    return sb.toString();
  }
}
