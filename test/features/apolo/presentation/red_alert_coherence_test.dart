import 'package:astramed/features/agent/providers/agent_providers.dart';
import 'package:astramed/features/apolo/domain/apolo_models.dart';
import 'package:astramed/features/apolo/presentation/apolo_assessment_launcher_sheet.dart';
import 'package:astramed/features/apolo/presentation/apolo_dog_widget.dart';
import 'package:astramed/features/apolo/presentation/apolo_home_screen.dart';
import 'package:astramed/features/apolo/presentation/apolo_sky_background.dart';
import 'package:astramed/features/apolo/providers/apolo_alert_state_provider.dart';
import 'package:astramed/features/apolo/providers/apolo_contract_providers.dart';
import 'package:astramed/features/apolo/providers/apolo_providers.dart';
import 'package:astramed/features/crew/presentation/providers/crew_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _causes = ['SpO2 89%', 'Radiation 8-OHdG 11.2'];

Future<ProviderContainer> _mount(
  WidgetTester tester, {
  bool disableAnimations = true,
  bool highContrast = false,
}) async {
  tester.view.physicalSize = const Size(1280, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final container = ProviderContainer(
    overrides: [
      ...apoloProviderOverrides,
      selectedAstronautIdProvider.overrideWith((ref) => 'AST-03'),
      agentVoiceRepliesEnabledProvider.overrideWith((ref) => false),
      apoloGlobalAlertStateProvider.overrideWith((ref) {
        final critical = ref.watch(selectedAstronautIdProvider) == 'AST-03';
        return ApoloGlobalAlertState(
          severity: critical ? ApoloSeverity.crit : ApoloSeverity.warn,
          isRedAlert: critical,
          evaBlocked: critical,
          reasons: critical ? _causes : const [],
        );
      }),
    ],
  );
  addTearDown(container.dispose);
  container.read(apoloActionsProvider).setHighContrast(highContrast);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            size: const Size(1280, 900),
            disableAnimations: disableAnimations,
          ),
          child: const ApoloHomeScreen(),
        ),
      ),
    ),
  );
  await tester.pump();
  return container;
}

void main() {
  testWidgets('AST-03 critical causes agree across banner, greeting, sky and dog',
      (tester) async {
    await _mount(tester);
    expect(find.byKey(const Key('apolo_red_alert_banner')), findsOneWidget);
    expect(find.textContaining('CRITICAL RED ALERT'), findsOneWidget);
    expect(find.textContaining('NO-GO EVA'), findsWidgets);
    final bubble = find.byKey(const Key('apolo_speech_bubble'));
    for (final cause in _causes) {
      expect(
        find.descendant(of: bubble, matching: find.textContaining(cause)),
        findsOneWidget,
      );
    }
    expect(find.descendant(of: bubble, matching: find.textContaining('Woof')),
        findsNothing);
    expect(tester.widget<ApoloDogWidget>(find.byType(ApoloDogWidget)).severity,
        ApoloSeverity.crit);
    final sky =
        tester.widget<ApoloSkyBackground>(find.byType(ApoloSkyBackground));
    expect(sky.isRedAlert, isTrue);
    final decoration =
        tester.widget<Container>(bubble).decoration! as BoxDecoration;
    expect((decoration.border! as Border).top.width, 2.2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('crew switch clears stale local text and resets red sky and banner',
      (tester) async {
    final container = await _mount(tester);
    await tester.tap(find.byKey(const Key('apolo_chip_give_tip')));
    await tester.pump();
    container.read(selectedAstronautIdProvider.notifier).state = 'AST-01';
    await tester.pump();
    expect(find.byKey(const Key('apolo_red_alert_banner')), findsNothing);
    final sky =
        tester.widget<ApoloSkyBackground>(find.byType(ApoloSkyBackground));
    expect(sky.isRedAlert, isFalse);
    container.read(selectedAstronautIdProvider.notifier).state = 'AST-03';
    await tester.pump();
    for (final cause in _causes) {
      expect(
        find.descendant(
          of: find.byKey(const Key('apolo_speech_bubble')),
          matching: find.textContaining(cause),
        ),
        findsOneWidget,
      );
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('Tests & Exercises opens the assessment launcher', (tester) async {
    await _mount(tester);
    await tester.tap(find.byKey(const Key('apolo_chip_assessments')));
    await tester.pumpAndSettle();
    expect(find.byType(ApoloAssessmentLauncherSheet), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final highContrast in [false, true]) {
    testWidgets('reduced-motion red alert renders safely, contrast=$highContrast',
        (tester) async {
      await _mount(tester, highContrast: highContrast);
      await tester.pump(const Duration(seconds: 1));
      expect(find.byKey(const Key('apolo_red_alert_banner')), findsOneWidget);
      expect(tester.hasRunningAnimations, isFalse);
      expect(tester.takeException(), isNull);
    });
  }
}
