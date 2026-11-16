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
import 'package:astramed/features/apolo/presentation/apolo_orb_widget.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final highContrast in [false, true]) {
    for (final kind in ['health', 'reply', 'component']) {
      testWidgets('$kind hover floats without resizing (contrast=$highContrast)', (tester) async {
        const reply = 'Drink water regularly and keep tracking your hydration throughout the mission. Continue recording each measurement in your local log and review the complete history before the next scheduled check-in.';
        const snapshot = ApoloModuleSnapshot(
          id: ApoloModuleId.renal, title: 'Kidney health', shortLabel: 'Renal',
          measures: 'Tracks kidney function and hydration.',
          whyItMatters: '', severity: ApoloSeverity.warn,
          keyMetric: 'Normal', subMetric: 'Latest kidney reading',
          primaryBiomarkerId: '', primaryBiomarkerName: '',
          biomarkers: [], trendValues: [], recommendations: [], relatedModules: [],
        );
        var taps = 0;
        final data = ApoloChatOrbData(
          key: kind, kind: kind == 'reply' ? ApoloChatOrbKind.reply : ApoloChatOrbKind.component,
          title: 'Mission health information', preview: 'Short preview',
          icon: Icons.monitor_heart, interactive: kind == 'component',
          message: const ChatMessage(role: ChatRole.assistant, content: reply),
        );
        await tester.pumpWidget(MaterialApp(home: Scaffold(body: Center(
          child: SizedBox(width: 220, child: Wrap(children: [
            if (kind == 'health') ApoloOrbWidget(snapshot: snapshot,
              highContrast: highContrast, onTap: () => taps++)
            else ApoloChatOrbWidget(data: data,
              highContrast: highContrast, onTap: () => taps++),
          ])),
        ))));
        await tester.pump(const Duration(seconds: 1));
        final target = find.byKey(ValueKey(kind == 'health'
          ? 'apolo_orb_renal' : 'apolo_chat_orb_$kind'));
        final before = tester.getSize(target);
        final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
        await mouse.addPointer(location: Offset.zero);
        await mouse.moveTo(tester.getCenter(target));
        await tester.pump();
        // Inspect an intermediate frame as well as the final expanded layout.
        await tester.pump(const Duration(milliseconds: 100));
        expect(tester.takeException(), isNull);
        await tester.pump(const Duration(milliseconds: 400));
        final window = find.byKey(ValueKey(kind == 'health'
          ? 'apolo_orb_hover_window_renal' : 'apolo_chat_orb_hover_window_$kind'));
        expect(window, findsOneWidget);
        expect(tester.getSize(window), Size.square(before.width * 2));
        final decoration =
            tester.widget<Container>(window).decoration! as BoxDecoration;
        expect(decoration.shape, BoxShape.circle);
        final ignored = find.ancestor(of: window, matching: find.byType(IgnorePointer));
        expect(ignored, findsWidgets);
        expect(tester.widget<IgnorePointer>(ignored.first).ignoring, isTrue);
        final scale = tester.widget<AnimatedScale>(
          find.ancestor(of: target, matching: find.byType(AnimatedScale)).first);
        expect(scale.scale, 2.0);
        expect(tester.getSize(target), before);
        expect(before, Size.square(kind == 'health' ? 144 : kind == 'reply' ? 112 : 136));
        final bounds = tester.getRect(window);
        expect(bounds.left, greaterThanOrEqualTo(16));
        expect(bounds.top, greaterThanOrEqualTo(16));
        expect(bounds.right, lessThanOrEqualTo(784));
        expect(bounds.bottom, lessThanOrEqualTo(584));
        expect(find.text(kind == 'health' ? snapshot.measures : kind == 'reply'
          ? reply : 'Click orb to interact'), findsOneWidget);
        if (kind == 'health') {
          expect(find.text(snapshot.subMetric), findsOneWidget);
          expect(find.text('Click orb for interactive actions'), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
        await mouse.moveTo(Offset.zero);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        expect(window, findsNothing);
        expect(tester.getSize(target), before);
        await mouse.moveTo(tester.getCenter(target));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(window, findsOneWidget);
        await tester.tap(target);
        expect(taps, 1);
        await tester.pump();
        await tester.pump();
        expect(window, findsNothing);
        await mouse.moveTo(Offset.zero);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        expect(tester.getSize(target), before);
        expect(window, findsNothing);
        expect(tester.takeException(), isNull);
        await mouse.removePointer();
      });
    }
  }
  testWidgets('hover preserves both columns of a narrow orb rail', (tester) async {
    final data = ApoloChatOrbData.fromSession(messages: const [],
      components: [GenericComponentViewModel(
        componentId: ComponentIds.pvtTest, title: 'Reaction time assessment',
      )]).single;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: Center(
      child: SizedBox(width: 230, child: SingleChildScrollView(
        child: Row(children: [
          for (var i = 0; i < 2; i++) Column(mainAxisSize: MainAxisSize.min, children: [
            ApoloChatOrbWidget(key: ValueKey(i), data: data,
              compactScale: 0.7, onTap: () {}),
          ]),
        ]),
      )),
    ))));
    await tester.pump(const Duration(seconds: 1));
    final orb = find.byKey(const ValueKey(0));
    final before = tester.getSize(orb);
    final siblingBefore = tester.getRect(find.byKey(const ValueKey(1)));
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(orb));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.getSize(orb), before);
    expect(tester.getRect(find.byKey(const ValueKey(1))).size, siblingBefore.size);
    expect(find.text('Click orb to interact'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await mouse.removePointer();
  });
  for (final alignment in [Alignment.topLeft, Alignment.bottomRight]) {
    testWidgets('highlighted health preview stays within a small screen at $alignment', (tester) async {
      tester.view.physicalSize = const Size(320, 360);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      const snapshot = ApoloModuleSnapshot(
        id: ApoloModuleId.renal, title: 'Kidney health', shortLabel: 'Renal',
        measures: 'Tracks kidney function and hydration.',
        whyItMatters: '', severity: ApoloSeverity.warn,
        keyMetric: 'Normal', subMetric: 'Latest kidney reading',
        primaryBiomarkerId: '', primaryBiomarkerName: '',
        biomarkers: [], trendValues: [], recommendations: [], relatedModules: [],
      );
      await tester.pumpWidget(MaterialApp(home: Scaffold(
        body: Align(alignment: alignment, child: ApoloOrbWidget(
          snapshot: snapshot, highlighted: true, onTap: () {},
        )),
      )));
      await tester.pump();
      final window = find.byKey(const ValueKey('apolo_orb_hover_window_renal'));
      expect(window, findsOneWidget);
      final rect = tester.getRect(window);
      expect(rect.size, const Size(288, 288));
      final decoration =
          tester.widget<Container>(window).decoration! as BoxDecoration;
      expect(decoration.shape, BoxShape.circle);
      expect(rect.left, greaterThanOrEqualTo(16));
      expect(rect.top, greaterThanOrEqualTo(16));
      expect(rect.right, lessThanOrEqualTo(304));
      expect(rect.bottom, lessThanOrEqualTo(344));
      expect(find.ancestor(of: window, matching: find.byType(IgnorePointer)), findsWidgets);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      expect(window, findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('hover gracefully works without an Overlay', (tester) async {
    const data = ApoloChatOrbData(
      key: 'standalone', kind: ApoloChatOrbKind.reply,
      title: 'Reply', preview: 'Drink water', icon: Icons.chat,
    );
    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: MediaQuery(data: const MediaQueryData(disableAnimations: true),
        child: Theme(data: ThemeData.dark(), child: Material(
          child: Center(child: ApoloChatOrbWidget(data: data, onTap: () {})),
        )),
      ),
    ));
    final target = find.byKey(const ValueKey('apolo_chat_orb_standalone'));
    final before = tester.getSize(target);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(target));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.getSize(target), before);
    expect(tester.takeException(), isNull);
    await mouse.removePointer();
  });

  testWidgets('health hover window renders whyItMatters and caps pending recommendations at 3', (tester) async {
    const snapshot = ApoloModuleSnapshot(
      id: ApoloModuleId.hidratacion,
      title: 'Hydration',
      shortLabel: 'Water',
      measures: 'Fluid intake vs daily target.',
      whyItMatters: 'Microgravity shifts body fluids upward and blunts thirst.',
      severity: ApoloSeverity.warn,
      keyMetric: '1.2 L',
      subMetric: 'of 2.5 L today',
      primaryBiomarkerId: 'vol',
      primaryBiomarkerName: 'Urine volume',
      biomarkers: [],
      trendValues: [],
      recommendations: [
        ApoloRecommendation(
          id: 'r0',
          moduleId: ApoloModuleId.hidratacion,
          priority: 'High',
          text: 'Completed step should be hidden',
          why: 'Already done.',
          done: true,
        ),
        ApoloRecommendation(
          id: 'r1',
          moduleId: ApoloModuleId.hidratacion,
          priority: 'High',
          text: 'Drink 500 ml of water now',
          why: 'Restores plasma volume.',
        ),
        ApoloRecommendation(
          id: 'r2',
          moduleId: ApoloModuleId.hidratacion,
          priority: 'Medium',
          text: 'Add electrolyte tablet',
          why: 'Supports sodium retention.',
        ),
        ApoloRecommendation(
          id: 'r3',
          moduleId: ApoloModuleId.hidratacion,
          priority: 'Low',
          text: 'Log next urine sample',
          why: 'Confirms hydration trend.',
        ),
        ApoloRecommendation(
          id: 'r4',
          moduleId: ApoloModuleId.hidratacion,
          priority: 'Low',
          text: 'Fourth pending action stays hidden',
          why: 'Only top 3 pending items fit.',
        ),
      ],
      relatedModules: [],
    );

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: ApoloOrbWidget(snapshot: snapshot, onTap: () {}),
        ),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 200));

    final target = find.byKey(const ValueKey('apolo_orb_hidratacion'));
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(target));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(const ValueKey('apolo_orb_hover_window_hidratacion')), findsOneWidget);
    expect(find.text(snapshot.whyItMatters), findsOneWidget);
    expect(find.text('Drink 500 ml of water now'), findsOneWidget);
    expect(find.text('Add electrolyte tablet'), findsOneWidget);
    expect(find.text('Log next urine sample'), findsOneWidget);
    expect(find.text('Completed step should be hidden'), findsNothing);
    expect(find.text('Fourth pending action stays hidden'), findsNothing);
    expect(find.text('Click orb for interactive actions'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await mouse.removePointer();
  });

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

  testWidgets('chat orb hover then tap opens ApoloChatSheet and closes hover overlay', (tester) async {
    const fullReply =
        'Hydration levels look slightly low. Drink 500 ml of water over the next hour and log your intake.';
    final data = ApoloChatOrbData.fromSession(
      messages: const [
        ChatMessage(role: ChatRole.assistant, content: fullReply),
      ],
      components: const [],
    ).single;
    var opened = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return Stack(
                fit: StackFit.expand,
                children: [
                  Center(
                    child: ApoloChatOrbWidget(
                      data: data,
                      onTap: () => setState(() => opened = true),
                    ),
                  ),
                  if (opened)
                    ApoloChatSheet(
                      data: data,
                      highContrast: false,
                      onClose: () => setState(() => opened = false),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 1));

    final target = find.byKey(const ValueKey('apolo_chat_orb_reply_0'));
    final window = find.byKey(const ValueKey('apolo_chat_orb_hover_window_reply_0'));
    final before = tester.getSize(target);
    expect(before, const Size.square(128));
    expect(window, findsNothing);
    expect(find.byType(ApoloChatSheet), findsNothing);

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(target));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(window, findsOneWidget);
    expect(tester.getSize(window), Size.square(before.width * 2));
    final decoration =
        tester.widget<Container>(window).decoration! as BoxDecoration;
    expect(decoration.shape, BoxShape.circle);
    final hoveredScale = tester.widget<AnimatedScale>(
      find.ancestor(of: target, matching: find.byType(AnimatedScale)).first,
    );
    expect(hoveredScale.scale, 2.0);
    expect(find.text(fullReply), findsOneWidget);
    expect(find.text('Click orb to interact'), findsOneWidget);
    expect(find.byType(ApoloChatSheet), findsNothing);

    await tester.tap(target);
    await tester.pump();
    await tester.pump();

    expect(opened, isTrue);
    expect(window, findsNothing);
    expect(find.byType(ApoloChatSheet), findsOneWidget);
    expect(find.byKey(const ValueKey('apolo_chat_sheet')), findsOneWidget);
    expect(find.text('Apolo says'), findsOneWidget);
    final sheetText = tester.widget<SelectableText>(
      find.byKey(const ValueKey('apolo_chat_sheet_text')),
    );
    expect(sheetText.data, fullReply);
    final settledScale = tester.widget<AnimatedScale>(
      find.ancestor(of: target, matching: find.byType(AnimatedScale)).first,
    );
    expect(settledScale.scale, 1.0);
    expect(tester.takeException(), isNull);
    await mouse.removePointer();
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
