import 'package:astramed/core/theme/space_theme.dart';
import 'package:astramed/features/agent/application/agent_conversation_controller.dart';
import 'package:astramed/features/agent/application/component_registry.dart';
import 'package:astramed/features/agent/application/skill_registry.dart';
import 'package:astramed/features/agent/domain/agent_contracts.dart';
import 'package:astramed/features/agent/domain/agent_exception.dart';
import 'package:astramed/features/agent/domain/agent_models.dart';
import 'package:astramed/features/agent/domain/agent_ports.dart';
import 'package:astramed/features/apolo/domain/apolo_models.dart';
import 'package:astramed/features/apolo/presentation/apolo_chat_orbs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ApoloChatOrbData.fromSession', () {
    const messages = [
      ChatMessage(role: ChatRole.user, content: 'How am I?'),
      ChatMessage(role: ChatRole.assistant, content: 'First answer here.'),
      ChatMessage(role: ChatRole.user, content: 'And my kidneys?'),
      ChatMessage(role: ChatRole.assistant, content: ''),
      ChatMessage(role: ChatRole.assistant, content: 'Second answer.'),
      ChatMessage(role: ChatRole.tool, content: '{"ok":true}'),
    ];

    test('turns each non-empty assistant reply into a circle, newest first', () {
      final orbs = ApoloChatOrbData.fromSession(
        messages: messages, components: const [],
      );
      expect(orbs.map((o) => o.key), ['reply_4', 'reply_1']);
      expect(orbs.first.isLatest, isTrue);
      expect(orbs.last.isLatest, isFalse);
      expect(orbs.every((o) => o.kind == ApoloChatOrbKind.reply), isTrue);
    });

    test('respects hidden replies and the reply limit', () {
      final hidden = ApoloChatOrbData.fromSession(
        messages: messages, components: const [], hiddenReplyIndexes: {4},
      );
      expect(hidden.map((o) => o.key), ['reply_1']);
      final limited = ApoloChatOrbData.fromSession(
        messages: messages, components: const [], maxReplies: 1,
      );
      expect(limited.map((o) => o.key), ['reply_4']);
    });

    test('injected components come first, with icon, severity and input flag', () {
      final orbs = ApoloChatOrbData.fromSession(
        messages: messages,
        components: [
          GenericComponentViewModel(
            componentId: ComponentIds.alertBanner, title: 'Solar storm',
            props: const {'severity': 'critical', 'message': 'Go to shelter now'},
          ),
          GenericComponentViewModel(
            componentId: ComponentIds.pvtTest, title: 'Reaction test',
          ),
        ],
      );
      expect(orbs.first.key, 'component_${ComponentIds.alertBanner}');
      expect(orbs.first.severity, ApoloSeverity.crit);
      expect(orbs.first.interactive, isFalse);
      expect(orbs.first.preview, 'Go to shelter now');
      expect(orbs[1].interactive, isTrue);
      expect(orbs[1].preview, 'Tap to start');
      expect(orbs[1].icon, ApoloChatOrbData.componentIcon(ComponentIds.pvtTest));
      expect(orbs.length, 4);
    });

    test('previewOf keeps only the first words', () {
      expect(ApoloChatOrbData.previewOf('one two'), 'one two');
      expect(ApoloChatOrbData.previewOf('one   two three four five six'),
          'one two three four…');
      expect(ApoloChatOrbData.humanize('graybiel_questionnaire'),
          'Graybiel questionnaire');
    });

    test('every core component has an explicit icon', () {
      for (final id in ComponentIds.all) {
        expect(ApoloChatOrbData.componentIcon(id),
            isNot(Icons.medical_services_outlined), reason: id);
      }
    });
  });

  testWidgets('chat circle shows the reply preview and reacts to taps', (tester) async {
    var taps = 0;
    final data = ApoloChatOrbData.fromSession(
      messages: const [ChatMessage(role: ChatRole.assistant,
          content: 'Drink 500 ml of water in the next two hours please')],
      components: const [],
    ).single;
    await tester.pumpWidget(MaterialApp(home: MediaQuery(
      data: const MediaQueryData(disableAnimations: true),
      child: Scaffold(body: Center(
        child: ApoloChatOrbWidget(data: data, onTap: () => taps++),
      )),
    )));
    await tester.pumpAndSettle();
    expect(find.text('Drink 500 ml of…'), findsOneWidget);
    expect(find.text('Apolo · new'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('apolo_chat_orb_reply_0')));
    expect(taps, 1);
  });

  const extraIcons = {
    'zero_g_horizon': Icons.explore_outlined,
    'dva_gaze': Icons.remove_red_eye_outlined,
    'mission_simulator': Icons.rocket_launch_outlined,
    'manual_vitals': Icons.touch_app_outlined,
    'medical_procedures': Icons.medical_services_outlined,
  };
  for (final entry in extraIcons.entries) {
    testWidgets('${entry.key} is interactive and opens a readable sheet', (tester) async {
      final data = ApoloChatOrbData.fromSession(
        messages: const [],
        components: [GenericComponentViewModel(
          componentId: entry.key, title: entry.key,
        )],
      ).single;
      expect(data.interactive, isTrue);
      expect(data.preview, 'Tap to start');
      expect(data.icon, entry.value);
      var opened = false;
      var closed = false;
      ThemeData? bodyTheme;
      await tester.pumpWidget(MaterialApp(home: MediaQuery(
        data: const MediaQueryData(size: Size(800, 600), disableAnimations: true),
        child: Scaffold(body: StatefulBuilder(builder: (context, setState) {
          return Stack(fit: StackFit.expand, children: [
            ApoloChatOrbWidget(data: data,
                onTap: () => setState(() => opened = true)),
            if (opened) ApoloChatSheet(
              data: data, highContrast: false,
              onClose: () => setState(() { opened = false; closed = true; }),
              componentBody: Builder(builder: (context) {
                bodyTheme = Theme.of(context);
                return const Text('Interactive cockpit content');
              }),
            ),
          ]);
        })),
      )));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey('apolo_chat_orb_component_${entry.key}')));
      await tester.pumpAndSettle();
      expect(find.byType(ApoloChatSheet), findsOneWidget);
      expect(find.text('Interactive cockpit content'), findsOneWidget);
      expect(bodyTheme!.brightness, Brightness.dark);
      expect(bodyTheme!.colorScheme, SpaceTheme.darkTheme.colorScheme);
      await tester.tap(find.byKey(const ValueKey('apolo_chat_sheet_close')));
      await tester.pumpAndSettle();
      expect(closed, isTrue);
      expect(find.byType(ApoloChatSheet), findsNothing);
    });
  }

  testWidgets('sheet preserves an existing dark cockpit theme', (tester) async {
    final theme = SpaceTheme.darkTheme.copyWith(
      colorScheme: SpaceTheme.darkTheme.colorScheme.copyWith(primary: Colors.pink),
    );
    ThemeData? actual;
    final data = ApoloChatOrbData.fromSession(messages: const [],
        components: [GenericComponentViewModel(
          componentId: ComponentIds.pvtTest, title: 'Reaction test',
        )]).single;
    await tester.pumpWidget(MaterialApp(theme: theme, home: Scaffold(
      body: Stack(children: [ApoloChatSheet(
        data: data, highContrast: false, onClose: () {},
        componentBody: Builder(builder: (context) {
          actual = Theme.of(context);
          return const Text('Test body');
        }),
      )]),
    )));
    expect(actual!.colorScheme, theme.colorScheme);
    expect(tester.takeException(), isNull);
  });

  for (final speakReply in [false, true]) {
    test('offline flow emits reply and components with speakReply=$speakReply', () async {
      final services = _ContextServices();
      final tts = _RecordingTts();
      final states = <AgentSessionState>[];
      final orchestrator = AgentConversationOrchestrator(
        chat: _OfflineChat(), tts: tts,
        skillRegistry: SkillRegistry([AgentSkill(
          id: 'test_flow', instructions: 'Offline test',
          triggers: const ['test'], tools: const [], offlineFlow: _OfflineFlow(),
        )]),
        componentRegistry: ComponentRegistry(),
        onStateChanged: states.add,
        contextFactory: (id, ui) => ToolContext(
          astronautId: id, read: <T>(_) => throw UnsupportedError('No providers'),
          ui: ui, confirm: services, audit: services, memory: services,
          flags: services, medication: services,
        ),
      );
      addTearDown(orchestrator.dispose);
      final result = await orchestrator.sendUserMessage('test', speakReply: speakReply);
      expect(result.messages.map((m) => m.content), ['test', 'Offline reply']);
      expect(result.activeComponents.single.componentId, ComponentIds.pvtTest);
      expect(result.offlineMode, isTrue);
      expect(result.busy, isFalse);
      expect(result.lastError, isNull);
      expect(states.last, same(result));
      expect(tts.spoken, speakReply ? ['Offline reply'] : isEmpty);
    });
  }
}

class _OfflineChat implements AgentChatService {
  @override
  Future<AgentReply> send(List<ChatMessage> messages, {
    Map<String, dynamic>? context, List<ToolSpec>? tools,
    List<String>? skillInstructions,
  }) async => throw const AgentUnavailableException(message: 'offline');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _RecordingTts implements TextToSpeechService {
  final spoken = <String>[];
  @override
  Future<void> speak(String text, {String? voice, String language = 'en-US'}) async {
    spoken.add(text);
  }
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ContextServices implements MemoryStore, AgentFlagsStore,
    ConfirmationGate, AuditLog, MedicationSafety {
  @override
  Future<List<MemoryEntry>> recentForPrompt(String astronautId, {int limit = 8}) async => [];
  @override
  Future<Map<String, Map<String, dynamic>>> allForAstronaut(String astronautId) async => {};
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _OfflineFlow implements DeterministicFlow {
  @override
  String get skillId => 'test_flow';
  @override
  Future<DeterministicStep> start(ToolContext ctx) async => const DeterministicStep(
    prompt: 'Offline reply', isTerminal: true,
    uiEvents: [ShowComponentEvent(ComponentIds.pvtTest)],
  );
  @override
  Future<DeterministicStep> advance(String userInput, ToolContext ctx) => start(ctx);
}
