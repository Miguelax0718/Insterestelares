import 'package:astramed/features/03_microgravity/agent/exercise_guidance_engine.dart';
import 'package:astramed/features/03_microgravity/agent/graybiel_engine.dart';
import 'package:astramed/features/03_microgravity/agent/procedures_engine.dart';
import 'package:astramed/features/03_microgravity/agent/sans_engine.dart';
import 'package:astramed/features/agent/domain/agent_contracts.dart';
import 'package:astramed/features/crew/models/astronaut_profile.dart';
import 'package:astramed/features/crew/presentation/providers/crew_provider.dart';

class MicrogravitySkillState {
  final Map<String, GraybielSession> graybielSessions = {};
  final Map<String, SansEvaluation> sansEvaluations = {};
  final Map<String, LbnpState> lbnpStates = {};
  final Map<String, UltrasoundEvaluation> ultrasoundStates = {};

  GraybielSession graybielFor(String astronautId) =>
      graybielSessions.putIfAbsent(astronautId, GraybielSession.new);
}

List<AgentSkill> microgravitySkills([MicrogravitySkillState? sharedState]) {
  final state = sharedState ?? MicrogravitySkillState();
  return [
    AgentSkill(
      id: 'graybiel',
      instructions:
          'Guide the Graybiel space motion sickness questionnaire briefly and naturally. '
          'Never skip confirmation before changing medication route or blocking EVA.',
      tools: [
        _StartGraybielTool(state),
        _RecordGraybielAnswerTool(state),
        _ScoreGraybielTool(state),
        _ChangeMedicationRouteTool(state),
      ],
      componentIds: const [ComponentIds.graybielQuestionnaire],
      triggers: const [
        'graybiel',
        'motion sickness',
        'mareo',
        'nausea',
        'vestibular',
        'emesis',
        'vomiting',
        'stasis',
      ],
      offlineFlow: GraybielOfflineFlow(state.graybielSessions),
    ),
    AgentSkill(
      id: 'sans',
      instructions:
          'Run SANS ocular evaluations (Amsler grid, contrast sensitivity, near focus). '
          'Require crew confirmation before assigning preventive corrective goggles.',
      tools: [
        _StartSansTestTool(),
        _ClassifySansTool(state),
        _AssignGogglesTool(),
      ],
      componentIds: const [
        ComponentIds.sansGrid,
        ComponentIds.sansContrast,
        ComponentIds.sansFocus,
      ],
      triggers: const [
        'sans',
        'vision',
        'ocular',
        'eye',
        'amsler',
        'contrast',
        'focus',
        'goggles',
        'hyperopic',
      ],
    ),
    AgentSkill(
      id: 'exercise',
      instructions:
          'Evaluate current microgravity exercise countermeasures against live astronaut vitals '
          'and flag unsafe SpO2, heart rate, or blood pressure immediately.',
      tools: [_GetExerciseGuidanceTool()],
      componentIds: const [ComponentIds.exerciseMonitor],
      triggers: const [
        'exercise',
        'ared',
        't2',
        'treadmill',
        'cevis',
        'resistive',
        'workout',
        'motor coordination',
      ],
    ),
    AgentSkill(
      id: 'procedures',
      instructions:
          'Guide autonomous LBNP (-20 mmHg with mandatory gradual decompression via -10 mmHg) '
          'and renal/bladder ultrasound steps concisely.',
      tools: [
        _StartLbnpTool(state),
        _AdvanceLbnpTool(state),
        _AbortLbnpTool(state),
        _StartUltrasoundGuideTool(state),
      ],
      componentIds: const [
        ComponentIds.lbnpRamp,
        ComponentIds.ultrasoundGuide,
      ],
      triggers: const [
        'lbnp',
        'decompression',
        'ultrasound',
        'renal',
        'kidney',
        'bladder',
        'procedure',
      ],
    ),
  ];
}

class _StartGraybielTool extends AgentTool {
  const _StartGraybielTool(this._state);

  final MicrogravitySkillState _state;

  @override
  String get name => 'start_graybiel';

  @override
  String get description =>
      'Start a new Graybiel space motion sickness questionnaire and display the checklist.';

  @override
  Map<String, dynamic> get parameters => const {
    'type': 'object',
    'properties': <String, dynamic>{},
  };

  @override
  ToolEffect get effect => ToolEffect.ui;

  @override
  Future<ToolResult> call(Map<String, dynamic> args, ToolContext ctx) async {
    _state.graybielFor(ctx.astronautId).reset();
    final first = GraybielSymptom.nausea;
    final vm = GraybielQuestionnaireViewModel(
      astronautId: ctx.astronautId,
      answeredCount: 0,
      totalSymptoms: GraybielSymptom.values.length,
      responses: const {},
      emesis: false,
      completed: false,
      currentSymptom: first,
      currentPrompt: first.questionPrompt,
    );
    final event = AgentComponentEvent.show(
      ComponentIds.graybielQuestionnaire,
      vm.toProps(),
    );
    ctx.ui.emit(event);
    return ToolResult.ok(
      {
        'astronaut_id': ctx.astronautId,
        'current_symptom': first.wireName,
        'prompt': first.questionPrompt,
        'options': GraybielOfflineFlow.levelOptions,
      },
      uiEvents: [event],
    );
  }
}

class _RecordGraybielAnswerTool extends AgentTool {
  const _RecordGraybielAnswerTool(this._state);

  final MicrogravitySkillState _state;

  @override
  String get name => 'record_graybiel_answer';

  @override
  String get description =>
      'Record one Graybiel symptom severity (none, minimal, minor, moderate, severe) and optional emesis.';

  @override
  Map<String, dynamic> get parameters => const {
    'type': 'object',
    'properties': {
      'symptom': {
        'type': 'string',
        'enum': [
          'nausea',
          'pallor',
          'cold_sweating',
          'salivation',
          'drowsiness',
          'headache',
          'dizziness',
        ],
      },
      'level': {
        'type': 'string',
        'enum': ['none', 'minimal', 'minor', 'moderate', 'severe'],
      },
      'emesis': {'type': 'boolean'},
    },
    'required': ['symptom', 'level'],
  };

  @override
  ToolEffect get effect => ToolEffect.ui;

  @override
  Future<ToolResult> call(Map<String, dynamic> args, ToolContext ctx) async {
    final symptomRaw = args['symptom']?.toString() ?? '';
    final levelRaw = args['level']?.toString() ?? '';
    final symptom = GraybielSymptom.tryParse(symptomRaw);
    final level = GraybielLevel.tryParse(levelRaw);
    if (symptom == null) {
      return ToolResult.fail('Unknown Graybiel symptom: $symptomRaw');
    }
    if (level == null) {
      return ToolResult.fail('Unknown Graybiel level: $levelRaw');
    }

    final emesis = args['emesis'] as bool? ?? false;
    final session = _state.graybielFor(ctx.astronautId);
    session.recordAnswer(symptom, level, hasEmesis: emesis);

    final nextSymptom = GraybielSymptom.values.cast<GraybielSymptom?>().firstWhere(
      (s) => !session.responses.containsKey(s),
      orElse: () => null,
    );
    final completed = nextSymptom == null;
    session.completed = completed;

    final vm = GraybielQuestionnaireViewModel(
      astronautId: ctx.astronautId,
      answeredCount: session.responses.length,
      totalSymptoms: GraybielSymptom.values.length,
      responses: Map.unmodifiable(session.responses),
      emesis: session.emesis,
      completed: completed,
      currentSymptom: nextSymptom,
      currentPrompt: nextSymptom?.questionPrompt,
      evaluation: session.lastEvaluation,
    );
    final event = AgentComponentEvent.show(
      ComponentIds.graybielQuestionnaire,
      vm.toProps(),
    );
    ctx.ui.emit(event);
    return ToolResult.ok(
      {
        'recorded': {
          'symptom': symptom.wireName,
          'level': level.wireName,
          'emesis': session.emesis,
        },
        'answered_count': session.responses.length,
        'total_symptoms': GraybielSymptom.values.length,
        if (nextSymptom != null) 'next_symptom': nextSymptom.wireName,
        'completed': completed,
      },
      uiEvents: [event],
    );
  }
}

class _ScoreGraybielTool extends AgentTool {
  const _ScoreGraybielTool(this._state);

  final MicrogravitySkillState _state;

  @override
  String get name => 'score_graybiel';

  @override
  String get description =>
      'Compute the deterministic Graybiel score, category, EVA block recommendation, and gastric stasis status.';

  @override
  Map<String, dynamic> get parameters => const {
    'type': 'object',
    'properties': {
      'responses': {
        'type': 'object',
        'description':
            'Optional map of symptom wireName to level to score directly.',
      },
      'emesis': {'type': 'boolean'},
    },
  };

  @override
  Future<ToolResult> call(Map<String, dynamic> args, ToolContext ctx) async {
    final session = _state.graybielFor(ctx.astronautId);
    final rawResponses = args['responses'];
    final emesis = args['emesis'] as bool? ?? session.emesis;

    final map = <GraybielSymptom, GraybielLevel>{...session.responses};
    if (rawResponses is Map) {
      for (final entry in rawResponses.entries) {
        final s = GraybielSymptom.tryParse(entry.key.toString());
        final l = GraybielLevel.tryParse(entry.value.toString());
        if (s != null && l != null) {
          map[s] = l;
        }
      }
    }

    final evaluation = GraybielEngine.evaluate(map, emesis: emesis);
    session.lastEvaluation = evaluation;
    session.completed = true;

    final vm = GraybielQuestionnaireViewModel(
      astronautId: ctx.astronautId,
      answeredCount: map.length,
      totalSymptoms: GraybielSymptom.values.length,
      responses: evaluation.responses,
      emesis: evaluation.emesis,
      completed: true,
      evaluation: evaluation,
    );
    final event = AgentComponentEvent.show(
      ComponentIds.graybielQuestionnaire,
      vm.toProps(),
    );
    ctx.ui.emit(event);
    return ToolResult.ok(evaluation.toJson(), uiEvents: [event]);
  }
}

class _ChangeMedicationRouteTool extends AgentTool {
  const _ChangeMedicationRouteTool(this._state);

  final MicrogravitySkillState _state;

  @override
  String get name => 'change_medication_route';

  @override
  String get description =>
      'Validate medication safety and request crew confirmation to switch away from oral route due to suspected gastric stasis.';

  @override
  Map<String, dynamic> get parameters => const {
    'type': 'object',
    'properties': {
      'medication': {'type': 'string'},
      'dose_mg': {'type': 'number'},
      'route': {
        'type': 'string',
        'enum': ['intranasal', 'intramuscular', 'parenteral'],
      },
      'indication': {'type': 'string'},
      'block_eva': {'type': 'boolean'},
    },
    'required': ['medication', 'dose_mg', 'route'],
  };

  @override
  ToolEffect get effect => ToolEffect.consequential;

  @override
  Future<ToolResult> call(Map<String, dynamic> args, ToolContext ctx) async {
    final medication = args['medication']?.toString().trim() ?? '';
    final doseMg = (args['dose_mg'] as num?)?.toDouble();
    final route = args['route']?.toString().trim().toLowerCase() ?? '';
    if (medication.isEmpty || doseMg == null || doseMg <= 0) {
      return const ToolResult.fail(
        'Valid medication name and positive dose_mg are required.',
      );
    }
    if (route != 'intranasal' &&
        route != 'intramuscular' &&
        route != 'parenteral') {
      return ToolResult.fail(
        'Non-oral route required for gastric stasis (intranasal, intramuscular, or parenteral).',
      );
    }

    final check = await ctx.medication.validate(
      MedicationRequest(
        astronautId: ctx.astronautId,
        medication: medication,
        doseMg: doseMg,
        route: route,
        indication: args['indication']?.toString() ?? 'space_motion_sickness',
      ),
    );
    if (!check.allowed) {
      return ToolResult.fail(
        'Medication validation failed: ${check.reasons.join('; ')}',
        data: check.toJson(),
      );
    }

    final session = _state.graybielFor(ctx.astronautId);
    final eval =
        session.lastEvaluation ??
        GraybielEngine.evaluate(session.responses, emesis: session.emesis);
    final shouldBlockEva =
        (args['block_eva'] as bool?) ?? eval.evaBlockedRecommended;
    final actionId =
        'graybiel-route-${ctx.astronautId}-${ctx.now.millisecondsSinceEpoch}';

    final decision = await ctx.confirm.request(
      ConsequentialAction(
        id: actionId,
        astronautId: ctx.astronautId,
        actionType: 'change_medication_route',
        description:
            'Switch $medication ${doseMg.toStringAsFixed(1)} mg to $route route '
            'and record gastric stasis${shouldBlockEva ? ' + EVA block' : ''}.',
        payload: {
          'medication': medication,
          'dose_mg': doseMg,
          'route': route,
          'graybiel_score': eval.totalScore,
          'block_eva': shouldBlockEva,
        },
      ),
      onConfirmed: () async {
        final ts = ctx.now.toUtc().toIso8601String();
        await ctx.flags.setFlag(ctx.astronautId, 'medication_route_override', {
          'medication': medication,
          'dose_mg': doseMg,
          'route': route,
          if (check.batchId != null) 'batch_id': check.batchId,
          'updated_at': ts,
        });
        await ctx.flags.setFlag(ctx.astronautId, 'eva_gastric_stasis', {
          'suspected': true,
          'graybiel_score': eval.totalScore,
          'updated_at': ts,
        });
        if (medication.toLowerCase().contains('promethazine')) {
          await ctx.flags.setFlag(ctx.astronautId, 'recent_sedative_use', {
            'medication': medication,
            'dose_mg': doseMg,
            'route': route,
            'administered_at': ts,
          });
        }
        if (shouldBlockEva) {
          await ctx.flags.setFlag(ctx.astronautId, 'eva_blocked_by_graybiel', {
            'blocked': true,
            'graybiel_score': eval.totalScore,
            'category': eval.category.wireName,
            'updated_at': ts,
          });
        }
        return {
          'route': route,
          'gastric_stasis': true,
          'eva_blocked': shouldBlockEva,
        };
      },
    );

    if (decision != ConfirmationDecision.confirmed) {
      return ToolResult.ok({
        'confirmed': false,
        'decision': decision.wireName,
        'applied': false,
        'medication': medication,
        'route': route,
      });
    }

    return ToolResult.ok({
      'confirmed': true,
      'decision': decision.wireName,
      'medication': medication,
      'dose_mg': doseMg,
      'route': route,
      'gastric_stasis': true,
      'eva_blocked': shouldBlockEva,
      if (check.batchId != null) 'batch_id': check.batchId,
    });
  }
}

class _StartSansTestTool extends AgentTool {
  const _StartSansTestTool();

  @override
  String get name => 'start_sans_test';

  @override
  String get description =>
      'Display an interactive SANS ocular screening test (sans_grid, sans_contrast, or sans_focus).';

  @override
  Map<String, dynamic> get parameters => const {
    'type': 'object',
    'properties': {
      'test': {
        'type': 'string',
        'enum': ['sans_grid', 'sans_contrast', 'sans_focus'],
      },
    },
    'required': ['test'],
  };

  @override
  ToolEffect get effect => ToolEffect.ui;

  @override
  Future<ToolResult> call(Map<String, dynamic> args, ToolContext ctx) async {
    final testId = args['test']?.toString() ?? ComponentIds.sansGrid;
    final AgentViewModel vm;
    switch (testId) {
      case ComponentIds.sansGrid:
        vm = SansGridViewModel(
          astronautId: ctx.astronautId,
          instruction:
              'Fixate on the center dot of the Amsler grid at 30 cm and report wavy lines or blind spots.',
        );
      case ComponentIds.sansContrast:
        vm = SansContrastViewModel(
          astronautId: ctx.astronautId,
          instruction:
              'Read the faintest letter triplet visible to determine contrast logCS.',
        );
      case ComponentIds.sansFocus:
        vm = SansFocusViewModel(
          astronautId: ctx.astronautId,
          instruction:
              'Move the near acuity target toward the eye until blur begins and record distance in cm.',
        );
      default:
        return ToolResult.fail('Unknown SANS test component: $testId');
    }

    final event = AgentComponentEvent.show(vm.componentId, vm.toProps());
    ctx.ui.emit(event);
    return ToolResult.ok(
      {
        'test': vm.componentId,
        'astronaut_id': ctx.astronautId,
        'props': vm.toProps(),
      },
      uiEvents: [event],
    );
  }
}

class _ClassifySansTool extends AgentTool {
  const _ClassifySansTool(this._state);

  final MicrogravitySkillState _state;

  @override
  String get name => 'classify_sans';

  @override
  String get description =>
      'Evaluate Amsler grid, contrast sensitivity, and near focus distance to compute hyperopic shift, SANS grade, and corrective goggles pair.';

  @override
  Map<String, dynamic> get parameters => const {
    'type': 'object',
    'properties': {
      'near_focus_cm': {'type': 'number'},
      'grid_metamorphopsia': {'type': 'boolean'},
      'grid_scotoma': {'type': 'boolean'},
      'contrast_log_cs': {'type': 'number'},
      'contrast_loss': {'type': 'boolean'},
    },
    'required': ['near_focus_cm'],
  };

  @override
  Future<ToolResult> call(Map<String, dynamic> args, ToolContext ctx) async {
    final nearFocusCm = (args['near_focus_cm'] as num?)?.toDouble();
    if (nearFocusCm == null || nearFocusCm <= 0) {
      return const ToolResult.fail('near_focus_cm must be a positive number.');
    }

    final evaluation = SansEngine.evaluate(
      nearFocusCm: nearFocusCm,
      gridMetamorphopsia: args['grid_metamorphopsia'] as bool? ?? false,
      gridScotoma: args['grid_scotoma'] as bool? ?? false,
      contrastLogCs: (args['contrast_log_cs'] as num?)?.toDouble() ?? 1.80,
      contrastLoss: args['contrast_loss'] as bool?,
    );
    _state.sansEvaluations[ctx.astronautId] = evaluation;

    final focusVm = SansFocusViewModel(
      astronautId: ctx.astronautId,
      instruction: evaluation.summary,
      nearFocusCm: evaluation.nearFocusCm,
      estimatedDiopters: evaluation.hyperopicShiftDiopters,
    );
    final event = AgentComponentEvent.show(
      ComponentIds.sansFocus,
      focusVm.toProps(),
    );
    ctx.ui.emit(event);
    return ToolResult.ok(evaluation.toJson(), uiEvents: [event]);
  }
}

class _AssignGogglesTool extends AgentTool {
  const _AssignGogglesTool();

  @override
  String get name => 'assign_goggles';

  @override
  String get description =>
      'Request crew confirmation to assign preventive corrective SANS goggles (PAIR-A +0.75D, PAIR-B +1.25D, or PAIR-C +1.75D).';

  @override
  Map<String, dynamic> get parameters => const {
    'type': 'object',
    'properties': {
      'pair': {
        'type': 'string',
        'enum': ['PAIR-A +0.75D', 'PAIR-B +1.25D', 'PAIR-C +1.75D'],
      },
    },
    'required': ['pair'],
  };

  @override
  ToolEffect get effect => ToolEffect.consequential;

  @override
  Future<ToolResult> call(Map<String, dynamic> args, ToolContext ctx) async {
    final rawPair = args['pair']?.toString() ?? '';
    final pair = SansGogglePair.parse(rawPair);
    if (pair == null) {
      return ToolResult.fail('Unknown SANS goggle pair: $rawPair');
    }

    final actionId =
        'sans-goggles-${ctx.astronautId}-${ctx.now.millisecondsSinceEpoch}';
    final decision = await ctx.confirm.request(
      ConsequentialAction(
        id: actionId,
        astronautId: ctx.astronautId,
        actionType: 'assign_goggles',
        description: 'Assign preventive SANS goggles ${pair.label}.',
        payload: pair.toJson(),
      ),
      onConfirmed: () async {
        await ctx.flags.setFlag(ctx.astronautId, 'assigned_goggles', {
          'pair': pair.label,
          'pair_id': pair.id,
          'diopters': pair.diopters,
          'assigned_at': ctx.now.toUtc().toIso8601String(),
        });
        return {'pair': pair.label, 'diopters': pair.diopters};
      },
    );

    if (decision != ConfirmationDecision.confirmed) {
      return ToolResult.ok({
        'confirmed': false,
        'decision': decision.wireName,
        'applied': false,
        'pair': pair.label,
      });
    }

    return ToolResult.ok({
      'confirmed': true,
      'decision': decision.wireName,
      'assigned_goggles': pair.label,
      'diopters': pair.diopters,
    });
  }
}

class _GetExerciseGuidanceTool extends AgentTool {
  const _GetExerciseGuidanceTool();

  @override
  String get name => 'get_exercise_guidance';

  @override
  String get description =>
      'Read astronaut live vitals and ExerciseSession to evaluate resistive load / motor coordination safety and guidance.';

  @override
  Map<String, dynamic> get parameters => const {
    'type': 'object',
    'properties': {
      'modality': {
        'type': 'string',
        'enum': [
          'resistive_load',
          'locomotor',
          'ergometer',
          'motor_coordination',
        ],
      },
    },
  };

  @override
  Future<ToolResult> call(Map<String, dynamic> args, ToolContext ctx) async {
    final profile = _resolveProfile(ctx);
    if (profile == null) {
      return ToolResult.fail(
        'Astronaut ${ctx.astronautId} not found in crew state.',
      );
    }

    final result = ExerciseGuidanceEngine.evaluate(
      profile: profile,
      modalityOverride: args['modality']?.toString(),
    );
    final vm = ExerciseMonitorViewModel(result: result);
    final event = AgentComponentEvent.show(
      ComponentIds.exerciseMonitor,
      vm.toProps(),
    );
    ctx.ui.emit(event);
    return ToolResult.ok(result.toJson(), uiEvents: [event]);
  }

  AstronautProfile? _resolveProfile(ToolContext ctx) {
    try {
      final crew = ctx.read<List<AstronautProfile>>(crewMembersProvider);
      for (final member in crew) {
        if (member.id == ctx.astronautId) {
          return member;
        }
      }
      if (crew.isNotEmpty) {
        return crew.first;
      }
    } catch (_) {
      // Fallback to selectedAstronautProvider if crewMembersProvider is unavailable.
    }
    try {
      return ctx.read<AstronautProfile>(selectedAstronautProvider);
    } catch (_) {
      return null;
    }
  }
}

class _StartLbnpTool extends AgentTool {
  const _StartLbnpTool(this._state);

  final MicrogravitySkillState _state;

  @override
  String get name => 'start_lbnp';

  @override
  String get description =>
      'Start the autonomous -20 mmHg LBNP protocol at prep_sealCheck.';

  @override
  Map<String, dynamic> get parameters => const {
    'type': 'object',
    'properties': <String, dynamic>{},
  };

  @override
  ToolEffect get effect => ToolEffect.ui;

  @override
  Future<ToolResult> call(Map<String, dynamic> args, ToolContext ctx) async {
    final lbnp = LbnpEngine.start();
    _state.lbnpStates[ctx.astronautId] = lbnp;
    final vm = LbnpRampViewModel(astronautId: ctx.astronautId, state: lbnp);
    final event = AgentComponentEvent.show(ComponentIds.lbnpRamp, vm.toProps());
    ctx.ui.emit(event);
    return ToolResult.ok(lbnp.toJson(), uiEvents: [event]);
  }
}

class _AdvanceLbnpTool extends AgentTool {
  const _AdvanceLbnpTool(this._state);

  final MicrogravitySkillState _state;

  @override
  String get name => 'advance_lbnp';

  @override
  String get description =>
      'Advance the LBNP protocol to the next sequential phase while enforcing gradual decompression and hypotension/syncope safety checks.';

  @override
  Map<String, dynamic> get parameters => const {
    'type': 'object',
    'properties': {
      'seal_checked': {'type': 'boolean'},
      'systolic_bp': {'type': 'number'},
      'hr_drop_bpm': {'type': 'number'},
      'emergency_syncope': {'type': 'boolean'},
      'target_pressure_mmhg': {'type': 'integer'},
      'target_phase': {'type': 'string'},
    },
  };

  @override
  ToolEffect get effect => ToolEffect.ui;

  @override
  Future<ToolResult> call(Map<String, dynamic> args, ToolContext ctx) async {
    final current = _state.lbnpStates[ctx.astronautId] ?? LbnpEngine.start();
    final targetPhaseRaw = args['target_phase']?.toString();
    final transition = LbnpEngine.advance(
      current,
      sealChecked: args['seal_checked'] as bool? ?? true,
      systolicBP: (args['systolic_bp'] as num?)?.toDouble(),
      hrDropBpm: (args['hr_drop_bpm'] as num?)?.toDouble(),
      emergencySyncope: args['emergency_syncope'] as bool? ?? false,
      requestedTargetPressureMmHg:
          (args['target_pressure_mmhg'] as num?)?.toInt(),
      requestedPhase:
          targetPhaseRaw == null ? null : LbnpPhase.tryParse(targetPhaseRaw),
    );
    _state.lbnpStates[ctx.astronautId] = transition.state;

    if (!transition.ok) {
      return ToolResult.fail(
        transition.error ?? 'LBNP phase transition rejected.',
        data: transition.state.toJson(),
      );
    }

    final vm = LbnpRampViewModel(
      astronautId: ctx.astronautId,
      state: transition.state,
    );
    final event = AgentComponentEvent.show(ComponentIds.lbnpRamp, vm.toProps());
    ctx.ui.emit(event);
    return ToolResult.ok(transition.state.toJson(), uiEvents: [event]);
  }
}

class _AbortLbnpTool extends AgentTool {
  const _AbortLbnpTool(this._state);

  final MicrogravitySkillState _state;

  @override
  String get name => 'abort_lbnp';

  @override
  String get description =>
      'Abort LBNP safely: immediate release + supine fluid load alert on hypotension/syncope, otherwise mandatory gradual decompression through -10 mmHg.';

  @override
  Map<String, dynamic> get parameters => const {
    'type': 'object',
    'properties': {
      'systolic_bp': {'type': 'number'},
      'hr_drop_bpm': {'type': 'number'},
      'emergency_syncope': {'type': 'boolean'},
      'reason': {'type': 'string'},
    },
  };

  @override
  ToolEffect get effect => ToolEffect.ui;

  @override
  Future<ToolResult> call(Map<String, dynamic> args, ToolContext ctx) async {
    final current = _state.lbnpStates[ctx.astronautId] ?? LbnpEngine.start();
    final transition = LbnpEngine.abort(
      current,
      systolicBP: (args['systolic_bp'] as num?)?.toDouble(),
      hrDropBpm: (args['hr_drop_bpm'] as num?)?.toDouble(),
      emergencySyncope: args['emergency_syncope'] as bool? ?? false,
      reason: args['reason']?.toString(),
    );
    _state.lbnpStates[ctx.astronautId] = transition.state;

    final vm = LbnpRampViewModel(
      astronautId: ctx.astronautId,
      state: transition.state,
    );
    final event = AgentComponentEvent.show(ComponentIds.lbnpRamp, vm.toProps());
    ctx.ui.emit(event);
    return ToolResult.ok(transition.state.toJson(), uiEvents: [event]);
  }
}

class _StartUltrasoundGuideTool extends AgentTool {
  const _StartUltrasoundGuideTool(this._state);

  final MicrogravitySkillState _state;

  @override
  String get name => 'start_ultrasound_guide';

  @override
  String get description =>
      'Start or step through the autonomous renal & bladder ultrasound guide including acoustic window, hydronephrosis/stone checklist, and bladder volume estimation.';

  @override
  Map<String, dynamic> get parameters => const {
    'type': 'object',
    'properties': {
      'step': {
        'type': 'string',
        'enum': [
          'prep_gel_and_probe',
          'right_kidney_window',
          'left_kidney_window',
          'hydronephrosis_stone_check',
          'bladder_volume_scan',
          'completed',
        ],
      },
      'acoustic_window_ok': {'type': 'boolean'},
      'hydronephrosis_present': {'type': 'boolean'},
      'stone_shadow_present': {'type': 'boolean'},
      'bladder_width_cm': {'type': 'number'},
      'bladder_height_cm': {'type': 'number'},
      'bladder_length_cm': {'type': 'number'},
    },
  };

  @override
  ToolEffect get effect => ToolEffect.ui;

  @override
  Future<ToolResult> call(Map<String, dynamic> args, ToolContext ctx) async {
    final rawStep = args['step']?.toString();
    final step = rawStep == null
        ? UltrasoundStep.prepGelAndProbe
        : UltrasoundStep.tryParse(rawStep);
    if (step == null) {
      return ToolResult.fail('Unknown ultrasound step: $rawStep');
    }

    final width = (args['bladder_width_cm'] as num?)?.toDouble();
    final height = (args['bladder_height_cm'] as num?)?.toDouble();
    final length = (args['bladder_length_cm'] as num?)?.toDouble();
    if ((width != null || height != null || length != null) &&
        (width == null ||
            height == null ||
            length == null ||
            width <= 0 ||
            height <= 0 ||
            length <= 0)) {
      return const ToolResult.fail(
        'Provide positive bladder_width_cm, bladder_height_cm, and bladder_length_cm to estimate volume.',
      );
    }

    final evaluation = UltrasoundEngine.evaluateStep(
      step: step,
      acousticWindowOk: args['acoustic_window_ok'] as bool? ?? true,
      hydronephrosisPresent: args['hydronephrosis_present'] as bool? ?? false,
      stoneShadowPresent: args['stone_shadow_present'] as bool? ?? false,
      bladderWidthCm: width,
      bladderHeightCm: height,
      bladderLengthCm: length,
    );
    _state.ultrasoundStates[ctx.astronautId] = evaluation;

    final vm = UltrasoundGuideViewModel(
      astronautId: ctx.astronautId,
      evaluation: evaluation,
    );
    final event = AgentComponentEvent.show(
      ComponentIds.ultrasoundGuide,
      vm.toProps(),
    );
    ctx.ui.emit(event);
    return ToolResult.ok(evaluation.toJson(), uiEvents: [event]);
  }
}
