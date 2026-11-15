import 'package:astramed/core/theme/space_theme.dart';
import 'package:astramed/features/agent/application/component_registry.dart';
import 'package:astramed/features/agent/domain/agent_contracts.dart';
import 'package:astramed/features/agent/domain/agent_models.dart';
import 'package:astramed/features/agent/domain/agent_ports.dart';
import 'package:astramed/features/agent/presentation/agent_canvas_view.dart';
import 'package:astramed/features/agent/presentation/component_widget_registry.dart';
import 'package:astramed/features/agent/providers/agent_providers.dart';
import 'package:astramed/features/crew/presentation/providers/crew_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeChatService implements AgentChatService {
  _FakeChatService(this._handler);

  final Future<AgentReply> Function(
    List<ChatMessage> messages,
    Map<String, dynamic>? context,
    List<ToolSpec>? tools,
    List<String>? skillInstructions,
  ) _handler;

  @override
  Future<AgentReply> send(
    List<ChatMessage> messages, {
    Map<String, dynamic>? context,
    List<ToolSpec>? tools,
    List<String>? skillInstructions,
  }) =>
      _handler(messages, context, tools, skillInstructions);

  @override
  Stream<AgentStreamEvent> stream(
    List<ChatMessage> messages, {
    Map<String, dynamic>? context,
    List<ToolSpec>? tools,
    List<String>? skillInstructions,
  }) =>
      const Stream.empty();
}

class _FakeSpeechToTextService implements SpeechToTextService {
  @override
  Future<void> cancel() async {}

  @override
  Future<void> dispose() async {}

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<String> listen({
    String language = 'es',
    Duration maxDuration = const Duration(seconds: 15),
  }) async =>
      'Status check';

  @override
  Future<void> startListening({String language = 'es'}) async {}

  @override
  Future<String> stopListening() async => 'Status check';
}

class _FakeTextToSpeechService implements TextToSpeechService {
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

class _FakeMemoryStore implements MemoryStore {
  final List<MemoryEntry> entries = [];

  @override
  Future<List<MemoryEntry>> recall(
    String astronautId, {
    String? query,
    Set<MemoryKind>? kinds,
    int limit = 10,
  }) async =>
      entries.where((e) => e.astronautId == astronautId).take(limit).toList();

  @override
  Future<List<MemoryEntry>> recentForPrompt(
    String astronautId, {
    int limit = 8,
  }) async =>
      entries.where((e) => e.astronautId == astronautId).take(limit).toList();

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
  Future<List<AuditEntry>> list({String? astronautId, int limit = 50}) async =>
      entries;
}

class _FakeFlagsStore implements AgentFlagsStore {
  final Map<String, Map<String, Map<String, dynamic>>> _flags = {};

  @override
  Future<Map<String, Map<String, dynamic>>> allForAstronaut(
    String astronautId,
  ) async =>
      Map<String, Map<String, dynamic>>.from(
        _flags[astronautId] ?? const {},
      );

  @override
  Future<Map<String, dynamic>?> getFlag(String astronautId, String key) async =>
      _flags[astronautId]?[key];

  @override
  Future<void> setFlag(
    String astronautId,
    String key,
    Map<String, dynamic> value,
  ) async {
    _flags.putIfAbsent(astronautId, () => {})[key] = value;
  }
}

class _FakeMedicationSafety implements MedicationSafety {
  @override
  Future<MedicationCheck> validate(MedicationRequest request) async =>
      const MedicationCheck(allowed: true, reasons: ['ok']);
}

class _FakeConfirmationGate implements ConfirmationGate {
  ConsequentialAction? _pending;
  Future<Map<String, dynamic>> Function()? _onConfirmed;
  final List<(String, ConfirmationDecision, String?)> resolutions = [];

  @override
  ConsequentialAction? get pending => _pending;

  void setPending(ConsequentialAction action) {
    _pending = action;
  }

  @override
  Future<ConfirmationDecision> request(
    ConsequentialAction action, {
    required Future<Map<String, dynamic>> Function() onConfirmed,
  }) async {
    _pending = action;
    _onConfirmed = onConfirmed;
    return ConfirmationDecision.confirmed;
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

Widget _buildTestApp({
  required List<Override> overrides,
  Size surfaceSize = const Size(1280, 800),
}) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      theme: SpaceTheme.darkTheme,
      home: MediaQuery(
        data: MediaQueryData(size: surfaceSize),
        child: const AgentCanvasView(),
      ),
    ),
  );
}

void main() {
  group('AgentComponentWidgetRegistry', () {
    test('registers all 22 ComponentIds and supports designer overrides (S7)', () {
      final registry = AgentComponentWidgetRegistry();
      for (final id in ComponentIds.all) {
        expect(
          registry.has(id),
          isTrue,
          reason: 'Missing placeholder widget builder for $id',
        );
      }

      final customRegistry = registry.copyWithOverrides({
        ComponentIds.vitalsCard: (context, vm, onSubmit, onDismiss) =>
            Text('CUSTOM_DESIGNER_VITALS:${vm.title}'),
      });
      expect(customRegistry.has(ComponentIds.vitalsCard), isTrue);
      expect(registry.has(ComponentIds.vitalsCard), isTrue);
    });

    testWidgets(
      'renders all 22 placeholder components, interactive callbacks, and dismiss',
      (tester) async {
        final registry = AgentComponentWidgetRegistry();
        final submitted = <(String, Map<String, dynamic>)>[];
        final dismissed = <String>[];

        for (final id in ComponentIds.all) {
          final vm = GenericComponentViewModel(
            componentId: id,
            title: 'Test $id',
            props: const {
              'id': 'act-1',
              'description': 'Test confirmation',
              'prompts': ['How did you sleep?'],
              'crew': [
                {'name': 'Alex', 'risk_level': 'nominal', 'heart_rate': 70, 'spo2': 98},
              ],
            },
          );
          await tester.pumpWidget(
            MaterialApp(
              theme: SpaceTheme.darkTheme,
              home: Scaffold(
                body: SingleChildScrollView(
                  child: Builder(
                    builder: (ctx) => registry.build(
                      ctx,
                      vm,
                      onSubmit: (res) => submitted.add((id, res)),
                      onDismiss: () => dismissed.add(id),
                    ),
                  ),
                ),
              ),
            ),
          );
          expect(find.byKey(ValueKey('agent_component_$id')), findsOneWidget);
          await tester.tap(find.byKey(ValueKey('agent_component_dismiss_$id')));
          expect(dismissed.last, id);
        }

        // Verify interactive button submits for questionnaire & procedures.
        await tester.pumpWidget(
          MaterialApp(
            theme: SpaceTheme.darkTheme,
            home: Scaffold(
              body: Builder(
                builder: (ctx) => registry.build(
                  ctx,
                  GenericComponentViewModel(
                    componentId: ComponentIds.sansGrid,
                    title: 'SANS Grid',
                    props: const {'instruction': 'Check grid'},
                  ),
                  onSubmit: (res) => submitted.add((ComponentIds.sansGrid, res)),
                  onDismiss: () {},
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Wavy Lines'));
        expect(
          submitted.any(
            (e) =>
                e.$1 == ComponentIds.sansGrid &&
                e.$2['metamorphopsia_reported'] == true,
          ),
          isTrue,
        );
      },
    );
  });

  group('AgentCanvasView', () {
    late _FakeMemoryStore memory;
    late _FakeAuditLog audit;
    late _FakeFlagsStore flags;
    late _FakeConfirmationGate confirmGate;
    late _FakeTextToSpeechService tts;
    late _FakeSpeechToTextService stt;

    setUp(() {
      memory = _FakeMemoryStore();
      audit = _FakeAuditLog();
      flags = _FakeFlagsStore();
      confirmGate = _FakeConfirmationGate();
      tts = _FakeTextToSpeechService();
      stt = _FakeSpeechToTextService();
    });

    List<Override> baseOverrides({
      required AgentChatService chat,
      Map<String, AgentComponentWidgetBuilder> widgetOverrides = const {},
      List<AgentSkill> extraSkills = const [],
    }) {
      return [
        agentChatServiceProvider.overrideWithValue(chat),
        textToSpeechServiceProvider.overrideWithValue(tts),
        speechToTextServiceProvider.overrideWithValue(stt),
        agentMemoryStoreProvider.overrideWithValue(memory),
        agentAuditLogProvider.overrideWithValue(audit),
        agentFlagsStoreProvider.overrideWithValue(flags),
        agentConfirmationGateProvider.overrideWithValue(confirmGate),
        medicationSafetyProvider.overrideWithValue(_FakeMedicationSafety()),
        componentWidgetOverridesProvider.overrideWithValue(widgetOverrides),
        extraAgentSkillsProvider.overrideWithValue(extraSkills),
      ];
    }

    testWidgets(
      'visual silence when activeComponents is empty; shows on ShowComponentEvent and hides on HideComponentEvent or dismiss',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        var round = 0;
        final chat = _FakeChatService((messages, _, _, _) async {
          round++;
          final userMsg = messages.last.content;
          if (userMsg.contains('Show vitals') && round == 1) {
            return const AgentReply(
              reply: '',
              model: 'm1',
              toolCalls: [
                ToolCall(
                  id: 'call_show',
                  name: 'get_vitals',
                  arguments: {'astronaut_id': 'AST-01'},
                ),
              ],
            );
          }
          if (userMsg.contains('Hide vitals')) {
            return const AgentReply(
              reply: '',
              model: 'm1',
              toolCalls: [
                ToolCall(
                  id: 'call_hide',
                  name: 'hide_component',
                  arguments: {'id': ComponentIds.vitalsCard},
                ),
              ],
            );
          }
          return const AgentReply(reply: 'Done.', model: 'm1');
        });

        await tester.pumpWidget(_buildTestApp(overrides: baseOverrides(chat: chat)));
        await tester.pumpAndSettle();

        // Visual silence when activeComponents is empty.
        final injectionZone = find.byKey(AgentCanvasView.injectionZoneKey);
        expect(injectionZone, findsOneWidget);
        expect(
          find.descendant(
            of: injectionZone,
            matching: find.byType(Card),
          ),
          findsNothing,
        );

        // Emit ShowComponentEvent via controller turn.
        await tester.enterText(
          find.byKey(AgentCanvasView.textInputKey),
          'Show vitals',
        );
        await tester.tap(find.byKey(AgentCanvasView.sendButtonKey));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('agent_component_vitals_card')),
          findsOneWidget,
        );

        // Dismiss via UI dismiss button.
        await tester.tap(
          find.byKey(const ValueKey('agent_component_dismiss_vitals_card')),
        );
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('agent_component_vitals_card')),
          findsNothing,
        );

        // Emit ShowComponentEvent again, then HideComponentEvent.
        round = 0;
        await tester.enterText(
          find.byKey(AgentCanvasView.textInputKey),
          'Show vitals',
        );
        await tester.tap(find.byKey(AgentCanvasView.sendButtonKey));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('agent_component_vitals_card')),
          findsOneWidget,
        );

        await tester.enterText(
          find.byKey(AgentCanvasView.textInputKey),
          'Hide vitals',
        );
        await tester.tap(find.byKey(AgentCanvasView.sendButtonKey));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('agent_component_vitals_card')),
          findsNothing,
        );
      },
    );

    testWidgets(
      'registering a custom builder for vitals_card renders the custom widget without changing skill/controller code (S7)',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        var round = 0;
        final chat = _FakeChatService((messages, _, _, _) async {
          round++;
          if (round == 1) {
            return const AgentReply(
              reply: '',
              model: 'm1',
              toolCalls: [
                ToolCall(
                  id: 'call_vitals',
                  name: 'get_vitals',
                  arguments: {'astronaut_id': 'AST-01'},
                ),
              ],
            );
          }
          return const AgentReply(reply: 'Vitals shown.', model: 'm1');
        });

        await tester.pumpWidget(
          _buildTestApp(
            overrides: baseOverrides(
              chat: chat,
              widgetOverrides: {
                ComponentIds.vitalsCard: (context, vm, onSubmit, onDismiss) {
                  return Card(
                    key: const ValueKey('custom_designer_vitals_card'),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text('DESIGNER_VITALS:${vm.title}'),
                    ),
                  );
                },
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byKey(AgentCanvasView.textInputKey),
          'Vitals',
        );
        await tester.tap(find.byKey(AgentCanvasView.sendButtonKey));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('custom_designer_vitals_card')),
          findsOneWidget,
        );
        expect(find.textContaining('DESIGNER_VITALS:'), findsOneWidget);
      },
    );

    testWidgets(
      'confirm_action widget triggers ConfirmationDecision.confirmed and rejected on button tap',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final chat = _FakeChatService((messages, _, _, _) async {
          if (messages.last.role == ChatRole.tool) {
            return const AgentReply(reply: 'Handled.', model: 'm1');
          }
          return const AgentReply(
            reply: '',
            model: 'm1',
            toolCalls: [
              ToolCall(
                id: 'call_confirm',
                name: 'show_component',
                arguments: {
                  'id': ComponentIds.confirmAction,
                  'props': {
                    'id': 'act-confirm-ui-1',
                    'description': 'Block EVA for AST-01',
                  },
                },
              ),
            ],
          );
        });

        late ProviderContainer container;
        await tester.pumpWidget(
          ProviderScope(
            overrides: baseOverrides(chat: chat),
            child: Builder(
              builder: (context) {
                container = ProviderScope.containerOf(context);
                return MaterialApp(
                  theme: SpaceTheme.darkTheme,
                  home: const AgentCanvasView(),
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        const action1 = ConsequentialAction(
          id: 'act-confirm-ui-1',
          astronautId: 'AST-01',
          actionType: 'block_eva',
          description: 'Block EVA for AST-01',
          payload: {'hours': 24},
        );
        confirmGate.setPending(action1);
        container
            .read(agentOrchestratorProvider.notifier)
            .orchestrator
            .syncPendingAction(action1);

        await tester.enterText(
          find.byKey(AgentCanvasView.textInputKey),
          'Show confirm',
        );
        await tester.tap(find.byKey(AgentCanvasView.sendButtonKey));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('agent_component_confirm_action')),
          findsOneWidget,
        );

        await tester.tap(
          find.byKey(const ValueKey('confirm_action_confirm_button')),
        );
        await tester.pumpAndSettle();

        expect(confirmGate.resolutions, [
          ('act-confirm-ui-1', ConfirmationDecision.confirmed, null),
        ]);
        expect(container.read(agentOrchestratorProvider).pendingAction, isNull);

        // Now test reject path.
        const action2 = ConsequentialAction(
          id: 'act-confirm-ui-2',
          astronautId: 'AST-01',
          actionType: 'flag_batches',
          description: 'Flag batch B-09',
          payload: {'batch_id': 'B-09'},
        );
        confirmGate.setPending(action2);
        container
            .read(agentOrchestratorProvider.notifier)
            .orchestrator
            .syncPendingAction(action2);
        await tester.pumpAndSettle();

        await tester.tap(
          find.byKey(const ValueKey('confirm_action_reject_button')),
        );
        await tester.pumpAndSettle();

        expect(confirmGate.resolutions.last, (
          'act-confirm-ui-2',
          ConfirmationDecision.rejected,
          null,
        ));
      },
    );

    testWidgets(
      'selecting another crew member in the sidebar switches the active astronaut context',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final chat = _FakeChatService((_, _, _, _) async {
          return const AgentReply(reply: 'Nominal.', model: 'm1');
        });

        late ProviderContainer container;
        await tester.pumpWidget(
          ProviderScope(
            overrides: baseOverrides(chat: chat),
            child: Builder(
              builder: (context) {
                container = ProviderScope.containerOf(context);
                return MaterialApp(
                  theme: SpaceTheme.darkTheme,
                  home: const AgentCanvasView(),
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(container.read(selectedAstronautIdProvider), 'AST-01');
        expect(
          container.read(agentOrchestratorProvider).astronautId,
          'AST-01',
        );

        await tester.tap(find.byKey(const ValueKey('crew_sidebar_item_AST-02')));
        await tester.pumpAndSettle();

        expect(container.read(selectedAstronautIdProvider), 'AST-02');
        expect(
          container.read(agentOrchestratorProvider).astronautId,
          'AST-02',
        );
      },
    );

    test('providers wire SkillRegistry and ComponentRegistry cleanly', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final skills = container.read(skillRegistryProvider);
      expect(skills.byId('core'), isNotNull);
      expect(skills.byId('status_report'), isNotNull);
      expect(skills.byId('space_weather'), isNotNull);
      expect(skills.byId('graybiel'), isNotNull);
      expect(skills.byId('cognition'), isNotNull);

      final compReg = container.read(componentRegistryProvider);
      for (final id in ComponentIds.all) {
        expect(compReg.has(id), isTrue);
      }

      // Verify core get_vitals nested payload resolves to VitalsCardViewModel.
      final vitalsVm = compReg.resolve(ComponentIds.vitalsCard, const {
        'astronaut_id': 'AST-01',
        'name': 'Alex Vance',
        'vitals': {
          'heart_rate': 72,
          'systolic_bp': 118,
          'diastolic_bp': 76,
          'spo2': 98,
        },
      });
      expect(vitalsVm.componentId, ComponentIds.vitalsCard);
    });

    testWidgets(
      'compact screen opens crew sidebar as a drawer and switches astronaut',
      (tester) async {
        tester.view.physicalSize = const Size(480, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final chat = _FakeChatService((_, _, _, _) async {
          return const AgentReply(reply: 'Nominal.', model: 'm1');
        });

        late ProviderContainer container;
        await tester.pumpWidget(
          ProviderScope(
            overrides: baseOverrides(chat: chat),
            child: Builder(
              builder: (context) {
                container = ProviderScope.containerOf(context);
                return MaterialApp(
                  theme: SpaceTheme.darkTheme,
                  home: const AgentCanvasView(),
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(AgentCanvasView.crewSidebarKey), findsNothing);
        await tester.tap(find.byTooltip('Open Crew Sidebar'));
        await tester.pumpAndSettle();

        expect(find.byKey(AgentCanvasView.crewSidebarKey), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('crew_sidebar_item_AST-03')));
        await tester.pumpAndSettle();

        expect(container.read(selectedAstronautIdProvider), 'AST-03');
        expect(
          container.read(agentOrchestratorProvider).astronautId,
          'AST-03',
        );
      },
    );
  });
}
