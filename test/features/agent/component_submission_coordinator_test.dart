import 'package:astramed/features/agent/application/component_submission_coordinator.dart';
import 'package:astramed/features/agent/application/agent_conversation_controller.dart';
import 'package:astramed/features/agent/application/skill_registry.dart';
import 'package:astramed/features/agent/domain/agent_contracts.dart';
import 'package:astramed/features/agent/domain/guided_assessment_catalog.dart';
import 'package:astramed/features/agent/providers/agent_providers.dart';
import 'package:astramed/features/03_microgravity/agent/microgravity_skills.dart';
import 'package:astramed/features/apolo/domain/apolo_models.dart';
import 'package:astramed/features/apolo/providers/apolo_contract_providers.dart';
import 'package:astramed/features/agent/domain/agent_exception.dart';
import 'package:astramed/features/agent/domain/agent_models.dart';
import 'package:astramed/features/agent/domain/agent_ports.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Unused implements AgentUiSink, ConfirmationGate, AuditLog, MedicationSafety {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Offline implements AgentChatService {
  @override
  Future<AgentReply> send(List<ChatMessage> messages, {
    Map<String, dynamic>? context, List<ToolSpec>? tools,
    List<String>? skillInstructions,
  }) async => throw const AgentUnavailableException(message: 'offline');
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Actions implements ApoloStateActions {
  int minutes = 0;
  String? astronaut;
  @override
  bool addExercise(int minutes, {String? astronautId}) {
    this.minutes += minutes;
    astronaut = astronautId;
    return true;
  }
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late ProviderContainer container;
  late MicrogravitySkillState shared;
  late ComponentSubmissionCoordinator coordinator;
  late ToolContext ctx;
  late _Actions actions;
  setUp(() {
    actions = _Actions();
    container = ProviderContainer(overrides: [
      apoloActionsProvider.overrideWithValue(actions),
      agentChatServiceProvider.overrideWithValue(_Offline()),
    ]);
    shared = MicrogravitySkillState();
    coordinator = ComponentSubmissionCoordinator(shared);
    final unused = _Unused();
    ctx = ToolContext(
      astronautId: 'AST-01',
      read: <T>(provider) => container.read(provider as ProviderListenable<T>),
      ui: unused, confirm: unused, audit: unused, medication: unused,
      flags: container.read(agentFlagsStoreProvider),
      memory: container.read(agentMemoryStoreProvider),
    );
  });
  tearDown(() => container.dispose());

  Future<void> expectCritical(String id, Map<String, dynamic> input, String flag) async {
    final result = await coordinator.submit(id, input, ctx);
    expect(result.proactiveEvent?.severity, ProactiveSeverity.critical);
    expect(result.uiEvents.whereType<ShowComponentEvent>().any(
      (e) => e.id == ComponentIds.alertBanner && e.props['severity'] == 'critical',
    ), isTrue);
    expect(await ctx.flags.getFlag(ctx.astronautId, flag), isNotNull);
    expect((await ctx.flags.getFlag(ctx.astronautId, 'eva_blocked'))?['blocked'], true);
    expect((await ctx.memory.recall(ctx.astronautId)).single.kind, MemoryKind.clinicalEvent);
    expect(result.summary, isNotEmpty);
  }

  test('Graybiel score five blocks EVA and shares completed session', () async {
    await expectCritical(ComponentIds.graybielQuestionnaire, {
      'responses': {'nausea': 'moderate', 'pallor': 'minimal'},
    }, 'graybiel_latest');
    expect(shared.graybielFor('AST-01').lastEvaluation?.totalScore, 5);
    expect(shared.graybielFor('AST-01').completed, true);
  });
  test('emesis blocks EVA', () async {
    await expectCritical(ComponentIds.graybielQuestionnaire, {
      'responses': <String, dynamic>{}, 'emesis': true,
    }, 'graybiel_latest');
  });
  test('SANS Grade 2 blocks EVA', () async {
    await expectCritical(ComponentIds.sansGrid, {'grid_scotoma': true}, 'sans_latest');
    expect(shared.sansEvaluations['AST-01']?.grade.wireName, 'grade_2');
  });
  test('LBNP emergency release blocks EVA', () async {
    await expectCritical(ComponentIds.lbnpRamp, {'emergency_release': true}, 'lbnp_latest');
    expect(shared.lbnpStates['AST-01']?.pressureMmHg, 0);
  });
  test('unsafe exercise blocks EVA', () async {
    await expectCritical(ComponentIds.exerciseMonitor, {'unsafe_vitals': true}, 'exercise_latest');
    expect(actions.minutes, 0);
  });
  for (final entry in {
    ComponentIds.pvtTest: {'reaction_ms': 450, 'lapses': 3},
    ComponentIds.mptTest: {'reaction_ms': 700, 'lapses': 0},
    ComponentIds.diaryRecorder: {'sleep_hours': 7, 'mood': 4, 'stress': 2},
    MicrogravityCockpitIds.zeroGHorizon: {'rms_error': 12, 'alignment_pct': 54},
    MicrogravityCockpitIds.dvaGaze: {'accuracy_pct': 80, 'gaze_stability_pct': 90},
    ComponentIds.ultrasoundGuide: {'completed_steps': ['setup', 'scan']},
  }.entries) {
    test('${entry.key} saves structured results and memory', () async {
      final result = await coordinator.submit(entry.key, entry.value, ctx);
      final key = switch (entry.key) {
        ComponentIds.pvtTest || ComponentIds.mptTest => 'pvt_latest',
        ComponentIds.diaryRecorder => 'diary_latest',
        _ => '${entry.key}_latest',
      };
      expect(await ctx.flags.getFlag('AST-01', key), isNotNull);
      expect(await ctx.memory.recall('AST-01'), hasLength(1));
      expect(result.summary, isNotEmpty);
      if (entry.key == MicrogravityCockpitIds.zeroGHorizon) {
        expect(result.summary, contains('habituation'));
      }
    });
  }
  test('workout minutes use APOLO actions for the submitting astronaut', () async {
    await coordinator.submit(ComponentIds.exerciseMonitor, {'duration_minutes': 20}, ctx);
    expect(actions.minutes, 20);
    expect(actions.astronaut, 'AST-01');
  });
  test('rejected Graybiel input leaves flags, memory and sessions unchanged', () async {
    await expectLater(coordinator.submit(ComponentIds.graybielQuestionnaire, {
      'responses': {'nausea': 'invalid'},
    }, ctx), throwsFormatException);
    expect(await ctx.flags.allForAstronaut('AST-01'), isEmpty);
    expect(await ctx.memory.recall('AST-01'), isEmpty);
    expect(shared.graybielSessions, isEmpty);
  });
  test('nominal assessment never clears an existing EVA hold', () async {
    await ctx.flags.setFlag('AST-01', 'eva_blocked', {'blocked': true, 'reason': 'existing'});
    final result = await coordinator.submit(ComponentIds.graybielQuestionnaire, {
      'responses': {'nausea': 'none'},
    }, ctx);
    expect(result.proactiveEvent, isNull);
    expect((await ctx.flags.getFlag('AST-01', 'eva_blocked'))?['reason'], 'existing');
  });
  test('LBNP controlled abort keeps mandatory minus-ten decompression', () async {
    for (var i = 0; i < 2; i++) {
      await coordinator.submit(ComponentIds.lbnpRamp, {'seal_checked': true}, ctx);
    }
    final aborted = await coordinator.submit(ComponentIds.lbnpRamp, {'action': 'abort'}, ctx);
    expect(aborted.data['pressure_mmhg'], -10);
    expect(aborted.proactiveEvent, isNull);
    final released = await coordinator.submit(ComponentIds.lbnpRamp, {'action': 'advance'}, ctx);
    expect(released.data['pressure_mmhg'], 0);
    expect(released.data['phase'], 'aborted');
  });
  test('SANS diopter safety boundary blocks EVA', () async {
    await expectCritical(ComponentIds.sansFocus, {
      'near_focus_cm': 40, 'delta_diopters': 1.5,
    }, 'sans_latest');
  });
  test('reaction thresholds distinguish nominal, warning and critical fatigue', () async {
    for (final (ms, lapses, severity) in [
      (449, 2, 'nominal'), (450, 2, 'warning'),
      (300, 3, 'warning'), (700, 0, 'critical'),
    ]) {
      final result = await coordinator.submit(ComponentIds.pvtTest, {
        'reaction_ms': ms, 'lapses': lapses,
      }, ctx);
      expect(result.data['severity'], severity);
    }
  });
  test('legacy callback remains supported without a coordinator', () async {
    String? submitted;
    final orchestrator = AgentConversationOrchestrator(
      chat: _Offline(), skillRegistry: SkillRegistry([]),
      componentRegistry: container.read(componentRegistryProvider),
      contextFactory: (_, _) => ctx,
      onComponentSubmitted: (id, _) => submitted = id,
    );
    addTearDown(orchestrator.dispose);
    orchestrator.submitComponentResult('legacy', {'value': 1});
    expect(submitted, 'legacy');
    expect(orchestrator.state.messages, isEmpty);
  });
  test('critical submission immediately updates active alert and written reply offline', () async {
    final orchestrator = AgentConversationOrchestrator(
      chat: _Offline(), skillRegistry: SkillRegistry([]),
      componentRegistry: container.read(componentRegistryProvider),
      contextFactory: (_, _) => ctx,
      submissionCoordinator: coordinator,
    );
    addTearDown(orchestrator.dispose);
    final submitted = await orchestrator.submitInteractiveResult(
      ComponentIds.graybielQuestionnaire,
      {'responses': {'nausea': 'moderate', 'pallor': 'minimal'}},
    );
    expect(submitted.messages.last.content, contains('NO-GO EVA'));
    expect(submitted.activeComponents.any((c) =>
      c.componentId == ComponentIds.alertBanner &&
      c.toProps()['severity'] == 'critical'), true);
    expect(submitted.activeComponents.any((c) => c.componentId == ComponentIds.graybielQuestionnaire), true);
  });
  test('launcher and submission produce offline guidance and active cards', () async {
    final controller = container.read(agentOrchestratorProvider.notifier);
    final launched = await controller.launchGuidedAssessment(GuidedAssessmentCatalog.all.first);
    expect(launched.activeComponents.any((e) => e.componentId == 'zero_g_horizon'), true);
    expect(launched.messages.last.content, contains('Step'));
    final submitted = await controller.submitInteractiveResult('zero_g_horizon', {
      'rms_error': 12, 'alignment_pct': 54,
    });
    expect(submitted.messages.last.content, contains('habituation'));
  });
}
