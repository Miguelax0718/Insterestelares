import 'package:astramed/features/01_general_health/presentation/cockpit_widgets/vitals_cockpit_cards.dart';
import 'package:astramed/features/crew/presentation/providers/crew_provider.dart';
import 'package:astramed/features/telemetry/presentation/providers/telemetry_provider.dart';
import 'package:astramed/features/agent/providers/agent_providers.dart';
import 'package:astramed/features/agent/domain/agent_exception.dart';
import 'package:astramed/features/agent/domain/agent_models.dart';
import 'package:astramed/features/agent/domain/agent_ports.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _OfflineChat implements AgentChatService {
  @override
  Future<AgentReply> send(List<ChatMessage> messages, {
    Map<String, dynamic>? context, List<ToolSpec>? tools,
    List<String>? skillInstructions,
  }) async => throw const AgentUnavailableException(message: 'offline');
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('manual guidance is a full-width first action at 360px', (tester) async {
    tester.view.physicalSize = const Size(360, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(ProviderScope(child: MaterialApp(home: Scaffold(
      body: SingleChildScrollView(child: ManualVitalsTapCard(
        onDismiss: () {}, onSubmit: (_) {},
      )),
    ))));
    final button = find.byKey(const ValueKey('manual_vitals_ask_apolo_button'));
    expect(tester.widget(button), isA<FilledButton>());
    expect(find.descendant(of: button, matching: find.byIcon(Icons.pets)), findsOneWidget);
    expect(find.text('Ask Apolo how to measure manually'), findsOneWidget);
    expect(
      find.text('Need guidance? Apolo explains pulse, breathing & capillary refill step by step.'),
      findsOneWidget,
    );
    final buttonRect = tester.getRect(button);
    final fieldRect = tester.getRect(find.byKey(const ValueKey('manual-heart-rate')));
    expect(buttonRect.left, fieldRect.left);
    expect(buttonRect.width, fieldRect.width);
    expect(buttonRect.bottom, lessThan(tester.getTopLeft(find.textContaining('Pulse: radial artery')).dy));
    expect(button.hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Ask Apolo dismisses manual vitals and replies with all measurements', (tester) async {
    tester.view.physicalSize = const Size(360, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final container = ProviderContainer(overrides: [
      agentChatServiceProvider.overrideWithValue(_OfflineChat()),
    ]);
    addTearDown(container.dispose);
    container.read(agentVoiceRepliesEnabledProvider.notifier).state = false;
    final before = container.read(selectedAstronautProvider).vitals;
    var dismissed = false;
    await tester.pumpWidget(UncontrolledProviderScope(container: container,
      child: MaterialApp(home: Scaffold(body: StatefulBuilder(
        builder: (context, setState) => dismissed ? const Text('Apolo chat')
          : SingleChildScrollView(child: ManualVitalsTapCard(
            onDismiss: () {
              expect(container.read(agentOrchestratorProvider).messages, isEmpty);
              setState(() => dismissed = true);
            },
            onSubmit: (_) => fail('Guidance must not save vitals'),
          )),
      )))));
    await tester.tap(find.byKey(const ValueKey('manual_vitals_ask_apolo_button')));
    await tester.pumpAndSettle();
    expect(dismissed, true);
    expect(find.text('Apolo chat'), findsOneWidget);
    final state = container.read(agentOrchestratorProvider);
    expect(state.messages.map((m) => m.content),
      contains('How do I measure vital signs manually without sensors?'));
    final reply = state.messages.last.content;
    for (final text in ['radial artery', '15 seconds', '×4', '30 seconds',
      '×2', 'nail bed', '< 2.0 seconds', 'thermometer', 'cuff at heart level']) {
      expect(reply, contains(text));
    }
    expect(state.activeComponents.map((c) => c.componentId),
      isNot(contains('manual_vitals')));
    expect(container.read(selectedAstronautProvider).vitals, same(before));
    expect(tester.takeException(), isNull);
  });
  testWidgets('live trend reacts to packets and filters the selected astronaut', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(container: container,
      child: MaterialApp(home: Scaffold(body: VitalsTrendCockpitCard(onDismiss: () {})))));
    final telemetry = container.read(telemetryProvider.notifier);
    telemetry.pullSingleMachine('AST-02', 'DEV-ASTROSKIN');
    telemetry.pullSingleMachine('AST-02', 'DEV-ASTROSKIN');
    await tester.pump();
    expect(find.textContaining('Baseline preview'), findsOneWidget);
    telemetry.pullSingleMachine('AST-01', 'DEV-ASTROSKIN');
    telemetry.pullSingleMachine('AST-01', 'DEV-ASTROSKIN');
    await tester.pump();
    expect(find.text('Live telemetry • 2 points'), findsOneWidget);
    final points = tester.widget<LineChart>(find.byType(LineChart)).data.lineBarsData.single.spots;
    expect(points, hasLength(2));
    final expected = container.read(telemetryProvider).recentLogs
      .where((p) => p.astronautId == 'AST-01').map((p) => p.metrics['heartRate']).toList().reversed;
    expect(points.map((p) => p.y), expected);
    container.read(selectedAstronautIdProvider.notifier).state = 'AST-03';
    await tester.pump();
    expect(find.textContaining('Baseline preview'), findsOneWidget);
  });
  testWidgets('trend offers six metrics and clearly marks baseline preview', (tester) async {
    await tester.pumpWidget(ProviderScope(child: MaterialApp(home: Scaffold(
      body: VitalsTrendCockpitCard(onDismiss: () {}),
    ))));
    expect(find.byType(ChoiceChip), findsNWidgets(6));
    expect(find.textContaining('Baseline preview'), findsOneWidget);
    await tester.tap(find.text('Blood Glucose'));
    await tester.pump();
    expect(find.textContaining('fasting reference'), findsOneWidget);
  });

  testWidgets('manual rejects nonfinite values, preserves other vitals and tags source', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final before = container.read(selectedAstronautProvider).vitals;
    Map<String, dynamic>? submitted;
    await tester.pumpWidget(UncontrolledProviderScope(container: container,
      child: MaterialApp(home: Scaffold(body: SingleChildScrollView(
        child: ManualVitalsTapCard(onDismiss: () {}, onSubmit: (value) => submitted = value),
      )))));
    for (final value in ['NaN', 'Infinity', '-1', 'abc', '221']) {
      await tester.enterText(find.byKey(const ValueKey('manual-heart-rate')), value);
      await tester.ensureVisible(find.text('Save Manual Vitals'));
      await tester.tap(find.text('Save Manual Vitals'));
      await tester.pump();
      expect(find.textContaining('Enter finite'), findsOneWidget);
      expect(container.read(selectedAstronautProvider).vitals, same(before));
      expect(submitted, isNull);
    }
    await tester.enterText(find.byKey(const ValueKey('manual-heart-rate')), '80');
    await tester.ensureVisible(find.text('Save Manual Vitals'));
    await tester.tap(find.text('Save Manual Vitals'));
    await tester.pump();
    final after = container.read(selectedAstronautProvider).vitals;
    expect(after.heartRate, 80);
    expect(after.systolicBP, before.systolicBP);
    expect(after.diastolicBP, before.diastolicBP);
    expect(after.spO2, before.spO2);
    expect(after.bloodGlucose, before.bloodGlucose);
    expect(after.source, 'manual');
    expect(after.deviceId, 'MANUAL-CREW-ASSESSMENT');
    expect(submitted!['completed'], true);
    expect(submitted!['astronaut_id'], after.astronautId);
  });

  testWidgets('pulse timer multiplies taps and cancels on dismissal', (tester) async {
    await tester.pumpWidget(ProviderScope(child: MaterialApp(home: Scaffold(
      body: SingleChildScrollView(child: ManualVitalsTapCard(
        onDismiss: () {}, onSubmit: (_) {},
      )),
    ))));
    await tester.tap(find.text('Start Pulse (15s)'));
    await tester.pump();
    for (var i = 0; i < 20; i++) {
      await tester.tap(find.text('Tap Pulse'));
    }
    await tester.pump(const Duration(seconds: 15));
    final field = tester.widget<TextField>(find.byKey(const ValueKey('manual-heart-rate')));
    expect(field.controller!.text, '80');
    await tester.tap(find.text('Start Pulse (15s)'));
    await tester.ensureVisible(find.text('Start Capillary Refill'));
    await tester.tap(find.text('Start Capillary Refill'));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 30));
    expect(tester.takeException(), isNull);
  });

  testWidgets('respiration multiplies taps and target switches reset unsaved form and timers', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(container: container,
      child: MaterialApp(home: Scaffold(body: SingleChildScrollView(
        child: ManualVitalsTapCard(onDismiss: () {}, onSubmit: (_) {}),
      )))));
    await tester.tap(find.text('Start Respiration (30s)'));
    await tester.pump();
    for (var i = 0; i < 8; i++) {
      await tester.tap(find.text('Tap Respiration'));
    }
    await tester.pump(const Duration(seconds: 30));
    expect(tester.widget<TextField>(find.byKey(const ValueKey('manual-respiratory-rate')))
      .controller!.text, '16');
    await tester.tap(find.text('Start Pulse (15s)'));
    await tester.pump();
    container.read(selectedAstronautIdProvider.notifier).state = 'AST-02';
    await tester.pump();
    await tester.pump(const Duration(seconds: 15));
    expect(find.textContaining('AST-02'), findsOneWidget);
    expect(tester.widget<TextField>(find.byKey(const ValueKey('manual-heart-rate')))
      .controller!.text, container.read(selectedAstronautProvider).vitals.heartRate.toString());
    expect(tester.takeException(), isNull);
  });
}
