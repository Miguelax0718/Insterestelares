import 'dart:convert';

import 'package:astramed/features/agent/application/agent_conversation_controller.dart';
import 'package:astramed/features/agent/application/component_registry.dart';
import 'package:astramed/features/agent/application/context_builder.dart';
import 'package:astramed/features/agent/application/core_tools.dart';
import 'package:astramed/features/agent/application/skill_registry.dart';
import 'package:astramed/features/agent/domain/agent_contracts.dart';
import 'package:astramed/features/agent/domain/agent_exception.dart';
import 'package:astramed/features/agent/domain/agent_models.dart';
import 'package:astramed/features/agent/domain/agent_ports.dart';
import 'package:astramed/features/crew/models/astronaut_profile.dart';
import 'package:astramed/features/crew/presentation/providers/crew_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeTool extends AgentTool {
  _FakeTool(this.toolName);

  final String toolName;

  @override
  String get name => toolName;

  @override
  String get description => 'Fake tool $toolName';

  @override
  Map<String, dynamic> get parameters => const {
        'type': 'object',
        'properties': <String, dynamic>{},
      };

  @override
  Future<ToolResult> call(Map<String, dynamic> args, ToolContext ctx) async {
    return ToolResult.ok({'tool': toolName});
  }
}

class _FakeUiSink implements AgentUiSink {
  final List<AgentComponentEvent> emitted = [];
  final List<(String, Map<String, dynamic>)> submitted = [];

  @override
  void emit(AgentComponentEvent event) {
    emitted.add(event);
  }

  @override
  void submit(String componentId, Map<String, dynamic> result) {
    submitted.add((componentId, result));
  }
}

class _FakeMemoryStore implements MemoryStore {
  final List<MemoryEntry> entries = [];

  @override
  Future<List<MemoryEntry>> recall(
    String astronautId, {
    String? query,
    Set<MemoryKind>? kinds,
    int limit = 10,
  }) async {
    final normalized = query?.trim().toLowerCase();
    return entries
        .where((e) => e.astronautId == astronautId)
        .where((e) => kinds == null || kinds.contains(e.kind))
        .where(
          (e) =>
              normalized == null ||
              normalized.isEmpty ||
              e.summary.toLowerCase().contains(normalized),
        )
        .take(limit)
        .toList();
  }

  @override
  Future<List<MemoryEntry>> recentForPrompt(
    String astronautId, {
    int limit = 8,
  }) async {
    return entries
        .where((e) => e.astronautId == astronautId)
        .take(limit)
        .toList();
  }

  @override
  Future<MemoryEntry> save(MemoryEntry entry) async {
    entries.add(entry);
    return entry;
  }
}

class _FakeAuditLog implements AuditLog {
  final List<AuditEntry> entries = [];

  @override
  Future<void> append(AuditEntry entry) async {
    entries.add(entry);
  }

  @override
  Future<List<AuditEntry>> list({String? astronautId, int limit = 50}) async {
    return entries
        .where((e) => astronautId == null || e.astronautId == astronautId)
        .take(limit)
        .toList();
  }
}

class _FakeConfirmationGate implements ConfirmationGate {
  ConsequentialAction? _pending;
  Future<Map<String, dynamic>> Function()? _onConfirmed;
  final List<(String, ConfirmationDecision, String?)> resolutions = [];

  @override
  ConsequentialAction? get pending => _pending;

  @override
  Future<ConfirmationDecision> request(
    ConsequentialAction action, {
    required Future<Map<String, dynamic>> Function() onConfirmed,
  }) async {
    _pending = action;
    _onConfirmed = onConfirmed;
    return ConfirmationDecision.confirmed;
  }

  void setPending(ConsequentialAction action) {
    _pending = action;
  }

  @override
  Future<Map<String, dynamic>?> resolve(
    String actionId,
    ConfirmationDecision decision, {
    String? reason,
  }) async {
    resolutions.add((actionId, decision, reason));
    if (_pending?.id == actionId) {
      _pending = null;
    }
    if (decision == ConfirmationDecision.confirmed && _onConfirmed != null) {
      return _onConfirmed!();
    }
    return {'decision': decision.wireName};
  }
}

class _FakeFlagsStore implements AgentFlagsStore {
  final Map<String, Map<String, Map<String, dynamic>>> store = {};

  @override
  Future<Map<String, Map<String, dynamic>>> allForAstronaut(
    String astronautId,
  ) async {
    return Map<String, Map<String, dynamic>>.from(
      store[astronautId] ?? const {},
    );
  }

  @override
  Future<Map<String, dynamic>?> getFlag(String astronautId, String key) async {
    return store[astronautId]?[key];
  }

  @override
  Future<void> setFlag(
    String astronautId,
    String key,
    Map<String, dynamic> value,
  ) async {
    store.putIfAbsent(astronautId, () => {})[key] = value;
  }
}

class _FakeMedicationSafety implements MedicationSafety {
  @override
  Future<MedicationCheck> validate(MedicationRequest request) async {
    return const MedicationCheck(allowed: true, reasons: []);
  }
}

class _FakeChatService implements AgentChatService {
  _FakeChatService(this._handler);

  final Future<AgentReply> Function(
    List<ChatMessage> messages,
    Map<String, dynamic>? context,
    List<ToolSpec>? tools,
    List<String>? skillInstructions,
  ) _handler;

  final List<
      ({
        List<ChatMessage> messages,
        Map<String, dynamic>? context,
        List<ToolSpec>? tools,
        List<String>? skillInstructions,
      })> calls = [];

  @override
  Future<AgentReply> send(
    List<ChatMessage> messages, {
    Map<String, dynamic>? context,
    List<ToolSpec>? tools,
    List<String>? skillInstructions,
  }) async {
    calls.add((
      messages: List<ChatMessage>.from(messages),
      context: context,
      tools: tools,
      skillInstructions: skillInstructions,
    ));
    return _handler(messages, context, tools, skillInstructions);
  }

  @override
  Stream<AgentStreamEvent> stream(
    List<ChatMessage> messages, {
    Map<String, dynamic>? context,
    List<ToolSpec>? tools,
    List<String>? skillInstructions,
  }) =>
      const Stream.empty();
}

class _FakeTtsService implements TextToSpeechService {
  final List<String> spoken = [];
  bool stopped = false;

  @override
  Future<void> dispose() async {}

  @override
  Future<void> speak(
    String text, {
    String? voice,
    String language = 'es-ES',
  }) async {
    spoken.add(text);
  }

  @override
  Future<void> stop() async {
    stopped = true;
  }
}

class _FakeGraybielFlow implements DeterministicFlow {
  int step = 0;

  @override
  String get skillId => 'graybiel';

  @override
  Future<DeterministicStep> start(ToolContext ctx) async {
    step = 1;
    return const DeterministicStep(
      prompt: 'Step 1: Rate nausea from 0 to 16.',
      options: ['0', '4', '8', '16'],
      uiEvents: [
        ShowComponentEvent(ComponentIds.graybielQuestionnaire, {'step': 1}),
      ],
    );
  }

  @override
  Future<DeterministicStep> advance(String userInput, ToolContext ctx) async {
    step = 2;
    return DeterministicStep(
      prompt: 'Graybiel recorded ($userInput): slight malaise.',
      isTerminal: true,
      verdict: {'input': userInput, 'category': 'slight'},
      uiEvents: const [
        ShowComponentEvent(ComponentIds.graybielQuestionnaire, {'done': true}),
      ],
    );
  }
}

class _CustomVitalsVm extends AgentViewModel {
  const _CustomVitalsVm({
    required super.componentId,
    required super.title,
    required this.heartRate,
  });

  final double heartRate;

  @override
  Map<String, dynamic> toProps() => {'heart_rate': heartRate};
}

void main() {
  group('SkillRegistry', () {
    test('always includes alwaysOn, matches triggers, caps non-alwaysOn, and deduplicates tools', () {
      final registry = SkillRegistry([
        AgentSkill(
          id: 'core',
          instructions: 'Core',
          tools: [_FakeTool('shared_tool'), _FakeTool('core_only')],
          alwaysOn: true,
        ),
        AgentSkill(
          id: 's1',
          instructions: 'S1',
          triggers: const ['vitals', 'heart'],
          tools: [_FakeTool('shared_tool'), _FakeTool('tool_s1')],
        ),
        AgentSkill(
          id: 's2',
          instructions: 'S2',
          triggers: const ['vitals'],
          tools: [_FakeTool('tool_s2')],
        ),
        AgentSkill(
          id: 's3',
          instructions: 'S3',
          triggers: const ['vitals'],
          tools: [_FakeTool('tool_s3')],
        ),
        AgentSkill(
          id: 's4',
          instructions: 'S4',
          triggers: const ['radiation'],
          tools: [_FakeTool('tool_s4')],
        ),
      ]);

      final selected = registry.select(
        query: 'Check VITALS and heart rate',
        forcedSkillId: 's4',
        maxSkills: 2,
      );

      expect(selected.first.id, 'core');
      // alwaysOn + at most 2 non-alwaysOn
      expect(selected.where((s) => !s.alwaysOn).length, 2);
      expect(selected.map((s) => s.id), contains('s4'));
      expect(selected.map((s) => s.id), contains('s1'));

      final toolNames = selected.expand((s) => s.tools).map((t) => t.name).toList();
      expect(toolNames.where((n) => n == 'shared_tool').length, 1);
      expect(toolNames, containsAll(['shared_tool', 'core_only', 'tool_s1', 'tool_s4']));
    });

    test('findOfflineFlow returns matched skill deterministic flow or null', () {
      final flow = _FakeGraybielFlow();
      final registry = SkillRegistry([
        AgentSkill(
          id: 'core',
          instructions: 'Core',
          tools: const [],
          alwaysOn: true,
        ),
        AgentSkill(
          id: 'graybiel',
          instructions: 'Graybiel',
          triggers: const ['nausea', 'graybiel', 'motion sickness'],
          tools: const [],
          offlineFlow: flow,
        ),
      ]);

      expect(registry.findOfflineFlow('I feel motion sickness'), same(flow));
      expect(registry.findOfflineFlow('unrelated query'), isNull);
    });
  });

  group('ComponentRegistry', () {
    test('pre-registers every id in ComponentIds.all, validates required props, throws FormatException on unknown id, and allows custom spec override', () {
      final registry = ComponentRegistry();
      for (final id in ComponentIds.all) {
        expect(registry.has(id), isTrue, reason: 'Missing component id: $id');
      }

      expect(
        () => registry.resolve('non_existent_widget', const {}),
        throwsFormatException,
      );

      expect(
        () => registry.resolve(ComponentIds.vitalsCard, const {}),
        throwsFormatException,
      );

      final vm = registry.resolve(ComponentIds.vitalsCard, const {
        'astronaut_id': 'AST-01',
        'vitals': {'heart_rate': 72},
      });
      expect(vm.componentId, ComponentIds.vitalsCard);
      expect(vm, isA<GenericComponentViewModel>());

      registry.register(
        ComponentSpec<_CustomVitalsVm>(
          id: ComponentIds.vitalsCard,
          fromProps: (props) {
            final hr = props['heart_rate'];
            if (hr is! num) {
              throw const FormatException('heart_rate is required');
            }
            return _CustomVitalsVm(
              componentId: ComponentIds.vitalsCard,
              title: 'Custom Vitals',
              heartRate: hr.toDouble(),
            );
          },
        ),
      );

      final custom = registry.resolve(ComponentIds.vitalsCard, const {
        'heart_rate': 88,
      });
      expect(custom, isA<_CustomVitalsVm>());
      expect((custom as _CustomVitalsVm).heartRate, 88.0);
    });
  });

  group('coreSkill tools', () {
    late ProviderContainer container;
    late _FakeMemoryStore memory;
    late _FakeUiSink ui;
    late ToolContext ctx;
    late Map<String, AgentTool> tools;

    setUp(() {
      container = ProviderContainer();
      memory = _FakeMemoryStore();
      ui = _FakeUiSink();
      ctx = ToolContext(
        astronautId: 'AST-01',
        read: <T>(provider) => container.read(provider as ProviderListenable<T>),
        ui: ui,
        confirm: _FakeConfirmationGate(),
        audit: _FakeAuditLog(),
        memory: memory,
        flags: _FakeFlagsStore(),
        medication: _FakeMedicationSafety(),
        now: DateTime.utc(2026, 11, 14, 10, 0),
      );
      final skill = coreSkill();
      expect(skill.id, 'core');
      expect(skill.alwaysOn, isTrue);
      tools = {for (final t in skill.tools) t.name: t};
      expect(tools.keys, hasLength(7));
    });

    tearDown(() => container.dispose());

    test('get_crew_overview and get_vitals read crewMembersProvider without mutating it and emit UI events', () async {
      final beforeCrew = List<AstronautProfile>.from(
        container.read(crewMembersProvider),
      );

      final overviewResult = await tools['get_crew_overview']!.call(const {}, ctx);
      expect(overviewResult.ok, isTrue);
      expect(overviewResult.data['count'], beforeCrew.length);
      expect(ui.emitted.last, isA<ShowComponentEvent>());
      expect((ui.emitted.last as ShowComponentEvent).id, ComponentIds.crewStatus);

      final vitalsResult = await tools['get_vitals']!.call(
        const {'astronaut_id': 'AST-03'},
        ctx,
      );
      expect(vitalsResult.ok, isTrue);
      expect(vitalsResult.data['astronaut_id'], 'AST-03');
      expect(vitalsResult.data['active_alerts'], isNotEmpty);
      expect((ui.emitted.last as ShowComponentEvent).id, ComponentIds.vitalsCard);

      final afterCrew = container.read(crewMembersProvider);
      expect(afterCrew.length, beforeCrew.length);
      for (var i = 0; i < beforeCrew.length; i++) {
        expect(afterCrew[i].vitals.heartRate, beforeCrew[i].vitals.heartRate);
      }
    });

    test('get_telemetry_series reads telemetryProvider and emits telemetryChart', () async {
      final res = await tools['get_telemetry_series']!.call(const {}, ctx);
      expect(res.ok, isTrue);
      expect(res.data['machines'], isA<List>());
      expect(res.data['metrics'], isA<Map>());
      expect((ui.emitted.last as ShowComponentEvent).id, ComponentIds.telemetryChart);
    });

    test('save_memory, recall_memory, show_component, and hide_component work and validate ids', () async {
      final saveRes = await tools['save_memory']!.call(
        const {
          'summary': 'Crew reports mild headache after EVA',
          'kind': 'clinical_event',
          'tags': ['eva', 'headache'],
        },
        ctx,
      );
      expect(saveRes.ok, isTrue);

      final recallRes = await tools['recall_memory']!.call(
        const {'query': 'headache'},
        ctx,
      );
      expect(recallRes.ok, isTrue);
      expect(recallRes.data['count'], 1);

      final badShow = await tools['show_component']!.call(
        const {'id': 'unknown_card', 'props': <String, dynamic>{}},
        ctx,
      );
      expect(badShow.ok, isFalse);

      final goodShow = await tools['show_component']!.call(
        const {
          'id': ComponentIds.alertBanner,
          'props': {'message': 'Check O2 levels'},
        },
        ctx,
      );
      expect(goodShow.ok, isTrue);
      expect((ui.emitted.last as ShowComponentEvent).id, ComponentIds.alertBanner);

      final hideRes = await tools['hide_component']!.call(
        const {'id': ComponentIds.alertBanner},
        ctx,
      );
      expect(hideRes.ok, isTrue);
      expect(ui.emitted.last, isA<HideComponentEvent>());
      expect((ui.emitted.last as HideComponentEvent).id, ComponentIds.alertBanner);
    });
  });

  group('ContextBuilder', () {
    test('builds <= 16KB context map including live snapshot, memory, components, and flags', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final crew = container.read(crewMembersProvider);
      final memory = _FakeMemoryStore();
      final flags = _FakeFlagsStore();

      for (var i = 0; i < 40; i++) {
        await memory.save(
          MemoryEntry(
            id: 'm$i',
            astronautId: 'AST-01',
            kind: MemoryKind.fact,
            summary: 'Long clinical observation $i ${'x' * 500}',
            createdAt: DateTime.utc(2026, 11, 14),
          ),
        );
      }
      await flags.setFlag('AST-01', 'eva_blocked', {'blocked': true});

      final built = await const AgentContextBuilder().build(
        astronaut: crew.first,
        memory: memory,
        flags: flags,
        activeComponentIds: const [ComponentIds.vitalsCard],
        missionDay: 42,
      );

      expect(built['live'], isA<Map>());
      expect((built['live'] as Map)['mission_day'], 42);
      expect(built['active_components'], [ComponentIds.vitalsCard]);
      expect((built['flags'] as Map).containsKey('eva_blocked'), isTrue);
      expect(
        utf8.encode(jsonEncode(built)).length,
        lessThanOrEqualTo(AgentContextBuilder.maxBytes),
      );
    });
  });

  group('AgentConversationOrchestrator', () {
    late ProviderContainer container;
    late _FakeMemoryStore memory;
    late _FakeConfirmationGate confirm;
    late _FakeAuditLog audit;
    late _FakeFlagsStore flags;
    late SkillRegistry skillRegistry;
    late ComponentRegistry componentRegistry;

    ToolContext buildCtx(String astronautId, AgentUiSink ui) {
      return ToolContext(
        astronautId: astronautId,
        read: <T>(provider) => container.read(provider as ProviderListenable<T>),
        ui: ui,
        confirm: confirm,
        audit: audit,
        memory: memory,
        flags: flags,
        medication: _FakeMedicationSafety(),
        now: DateTime.utc(2026, 11, 14, 12),
      );
    }

    setUp(() {
      container = ProviderContainer();
      memory = _FakeMemoryStore();
      confirm = _FakeConfirmationGate();
      audit = _FakeAuditLog();
      flags = _FakeFlagsStore();
      skillRegistry = SkillRegistry([
        coreSkill(),
        AgentSkill(
          id: 'graybiel',
          instructions: 'Run Graybiel protocol.',
          triggers: const ['nausea', 'graybiel'],
          tools: const [],
          offlineFlow: _FakeGraybielFlow(),
        ),
      ]);
      componentRegistry = ComponentRegistry();
    });

    tearDown(() => container.dispose());

    test('multi-round tool loop executes tools, updates activeComponents, and appends final reply', () async {
      var round = 0;
      final chat = _FakeChatService((messages, context, tools, instructions) async {
        round++;
        if (round == 1) {
          return const AgentReply(
            reply: '',
            model: 'm1',
            toolCalls: [
              ToolCall(
                id: 'c1',
                name: 'get_vitals',
                arguments: {'astronaut_id': 'AST-01'},
              ),
            ],
          );
        }
        if (round == 2) {
          return const AgentReply(
            reply: '',
            model: 'm1',
            toolCalls: [
              ToolCall(
                id: 'c2',
                name: 'hide_component',
                arguments: {'id': ComponentIds.vitalsCard},
              ),
            ],
          );
        }
        return const AgentReply(
          reply: 'Vitals are nominal.',
          model: 'm1',
        );
      });

      final tts = _FakeTtsService();
      final orchestrator = AgentConversationOrchestrator(
        chat: chat,
        tts: tts,
        skillRegistry: skillRegistry,
        componentRegistry: componentRegistry,
        contextFactory: buildCtx,
      );

      final state = await orchestrator.sendUserMessage(
        'Check my vitals',
        speakReply: true,
      );

      expect(round, 3);
      expect(state.messages.last.role, ChatRole.assistant);
      expect(state.messages.last.content, 'Vitals are nominal.');
      expect(
        state.messages.where((m) => m.role == ChatRole.tool).length,
        2,
      );
      expect(state.activeComponents, isEmpty);
      expect(tts.spoken, ['Vitals are nominal.']);
    });

    test('6-round cap stops looping and requests final reply without tools', () async {
      var round = 0;
      final chat = _FakeChatService((messages, context, tools, instructions) async {
        round++;
        if (round <= 6) {
          expect(tools, isNotEmpty);
          return AgentReply(
            reply: '',
            model: 'm1',
            toolCalls: [
              ToolCall(
                id: 'c$round',
                name: 'get_crew_overview',
                arguments: const {},
              ),
            ],
          );
        }
        expect(tools, isEmpty);
        return const AgentReply(
          reply: 'Summary after tool limit.',
          model: 'm1',
        );
      });

      final orchestrator = AgentConversationOrchestrator(
        chat: chat,
        skillRegistry: skillRegistry,
        componentRegistry: componentRegistry,
        contextFactory: buildCtx,
      );

      final state = await orchestrator.sendUserMessage('Check crew');
      expect(round, 7);
      expect(state.messages.last.content, 'Summary after tool limit.');
      expect(state.activeComponents.map((c) => c.componentId), [ComponentIds.crewStatus]);
    });

    test('reports invalidArguments and unknown tools back as tool error messages without crashing', () async {
      var round = 0;
      final chat = _FakeChatService((messages, context, tools, instructions) async {
        round++;
        if (round == 1) {
          return const AgentReply(
            reply: '',
            model: 'm1',
            toolCalls: [
              ToolCall(
                id: 'bad_args',
                name: 'get_vitals',
                arguments: {},
                invalidArguments: true,
              ),
              ToolCall(
                id: 'unknown',
                name: 'does_not_exist',
                arguments: {},
              ),
            ],
          );
        }
        return const AgentReply(reply: 'Recovered.', model: 'm1');
      });

      final orchestrator = AgentConversationOrchestrator(
        chat: chat,
        skillRegistry: skillRegistry,
        componentRegistry: componentRegistry,
        contextFactory: buildCtx,
      );

      final state = await orchestrator.sendUserMessage('Test errors');
      final toolMessages =
          state.messages.where((m) => m.role == ChatRole.tool).toList();
      expect(toolMessages, hasLength(2));
      expect(jsonDecode(toolMessages[0].content)['ok'], isFalse);
      expect(
        jsonDecode(toolMessages[0].content)['error'],
        contains('Invalid JSON arguments'),
      );
      expect(jsonDecode(toolMessages[1].content)['ok'], isFalse);
      expect(
        jsonDecode(toolMessages[1].content)['error'],
        contains('Unknown tool: does_not_exist'),
      );
      expect(state.messages.last.content, 'Recovered.');
    });

    test('offline fallback runs deterministic flow when matched and reports unavailable for free chat', () async {
      final chat = _FakeChatService((_, _, _, _) async {
        throw const AgentUnavailableException();
      });
      final tts = _FakeTtsService();
      final orchestrator = AgentConversationOrchestrator(
        chat: chat,
        tts: tts,
        skillRegistry: skillRegistry,
        componentRegistry: componentRegistry,
        contextFactory: buildCtx,
      );

      final freeChatState = await orchestrator.sendUserMessage('Tell me a joke');
      expect(freeChatState.offlineMode, isTrue);
      expect(
        freeChatState.messages.last.content.toLowerCase(),
        contains('offline'),
      );
      expect(freeChatState.activeOfflineFlowSkillId, isNull);

      final flowStartState = await orchestrator.sendUserMessage(
        'I have nausea',
        speakReply: true,
      );
      expect(flowStartState.offlineMode, isTrue);
      expect(flowStartState.activeOfflineFlowSkillId, 'graybiel');
      expect(flowStartState.messages.last.content, contains('Step 1'));
      expect(
        flowStartState.activeComponents.map((c) => c.componentId),
        [ComponentIds.graybielQuestionnaire],
      );
      expect(tts.spoken, contains('Step 1: Rate nausea from 0 to 16.'));

      final flowEndState = await orchestrator.sendUserMessage('4', speakReply: true);
      expect(flowEndState.activeOfflineFlowSkillId, isNull);
      expect(flowEndState.messages.last.content, contains('slight malaise'));
    });

    test('critical proactive event speaks immediately even when gateway throws AgentUnavailableException', () async {
      final chat = _FakeChatService((_, _, _, _) async {
        throw const AgentUnavailableException();
      });
      final tts = _FakeTtsService();
      final orchestrator = AgentConversationOrchestrator(
        chat: chat,
        tts: tts,
        skillRegistry: skillRegistry,
        componentRegistry: componentRegistry,
        contextFactory: buildCtx,
      );

      final state = await orchestrator.handleProactiveEvent(
        ProactiveEvent(
          id: 'ev1',
          astronautId: 'AST-01',
          severity: ProactiveSeverity.critical,
          kind: 'hypoxia',
          spokenMessage: 'Critical hypoxia detected: SpO2 88 percent.',
          createdAt: DateTime.utc(2026, 11, 14, 12),
          uiEvents: const [
            ShowComponentEvent(ComponentIds.alertBanner, {
              'message': 'SpO2 88%',
              'severity': 'critical',
            }),
          ],
        ),
      );

      expect(chat.calls, isEmpty);
      expect(tts.spoken, ['Critical hypoxia detected: SpO2 88 percent.']);
      expect(
        state.messages.last.content,
        'Critical hypoxia detected: SpO2 88 percent.',
      );
      expect(
        state.activeComponents.map((c) => c.componentId),
        [ComponentIds.alertBanner],
      );
    });

    test('warning proactive event triggers agent turn when online and falls back to spokenMessage when offline', () async {
      final onlineChat = _FakeChatService((messages, _, _, _) async {
        expect(messages.last.content, contains('fatigue'));
        return const AgentReply(reply: 'Schedule rest cycle soon.', model: 'm1');
      });
      final onlineTts = _FakeTtsService();
      final onlineOrchestrator = AgentConversationOrchestrator(
        chat: onlineChat,
        tts: onlineTts,
        skillRegistry: skillRegistry,
        componentRegistry: componentRegistry,
        contextFactory: buildCtx,
      );

      final warningEvent = ProactiveEvent(
        id: 'ev-warn',
        astronautId: 'AST-01',
        severity: ProactiveSeverity.warning,
        kind: 'fatigue',
        spokenMessage: 'Sleep deficit detected.',
        createdAt: DateTime.utc(2026, 11, 14, 12),
      );

      final onlineState = await onlineOrchestrator.handleProactiveEvent(warningEvent);
      expect(onlineChat.calls, hasLength(1));
      expect(onlineState.messages.last.content, 'Schedule rest cycle soon.');
      expect(onlineTts.spoken, ['Schedule rest cycle soon.']);

      final offlineChat = _FakeChatService((_, _, _, _) async {
        throw const AgentUnavailableException();
      });
      final offlineTts = _FakeTtsService();
      final offlineOrchestrator = AgentConversationOrchestrator(
        chat: offlineChat,
        tts: offlineTts,
        skillRegistry: skillRegistry,
        componentRegistry: componentRegistry,
        contextFactory: buildCtx,
      );

      final offlineState = await offlineOrchestrator.handleProactiveEvent(warningEvent);
      expect(offlineState.offlineMode, isTrue);
      expect(offlineState.messages.last.content, 'Sleep deficit detected.');
      expect(offlineTts.spoken, ['Sleep deficit detected.']);
    });

    test('resolveConfirmation and switchAstronaut preserve per-astronaut state', () async {
      final chat = _FakeChatService((messages, _, _, _) async {
        return AgentReply(
          reply: 'Reply for ${messages.last.content}',
          model: 'm1',
        );
      });
      final orchestrator = AgentConversationOrchestrator(
        chat: chat,
        skillRegistry: skillRegistry,
        componentRegistry: componentRegistry,
        contextFactory: buildCtx,
      );

      await orchestrator.sendUserMessage('Hello AST-01');
      confirm.setPending(
        const ConsequentialAction(
          id: 'act-1',
          astronautId: 'AST-01',
          actionType: 'block_eva',
          description: 'Block EVA for 24h',
          payload: {'hours': 24},
        ),
      );
      orchestrator.syncPendingAction(confirm.pending);
      final afterConfirm = await orchestrator.resolveConfirmation(
        ConfirmationDecision.confirmed,
        reason: 'Crew approved',
      );
      expect(confirm.resolutions, [('act-1', ConfirmationDecision.confirmed, 'Crew approved')]);
      expect(afterConfirm.pendingAction, isNull);
      expect(afterConfirm.messages.last.content.toLowerCase(), contains('confirmed'));

      final ast2State = orchestrator.switchAstronaut('AST-02');
      expect(ast2State.astronautId, 'AST-02');
      expect(ast2State.messages, isEmpty);
      await orchestrator.sendUserMessage('Hello AST-02');

      final backToAst1 = orchestrator.switchAstronaut('AST-01');
      expect(backToAst1.astronautId, 'AST-01');
      expect(
        backToAst1.messages.any((m) => m.content == 'Hello AST-01'),
        isTrue,
      );
      expect(
        backToAst1.messages.any((m) => m.content == 'Hello AST-02'),
        isFalse,
      );
    });
  });
}
