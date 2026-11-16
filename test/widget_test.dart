import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:astramed/features/apolo/presentation/apolo_home_screen.dart';
import 'package:astramed/features/apolo/presentation/apolo_crew_menu_dialog.dart';
import 'package:astramed/features/apolo/presentation/apolo_theme.dart';
import 'package:astramed/features/apolo/domain/apolo_models.dart';
import 'package:astramed/features/apolo/providers/apolo_providers.dart';
import 'package:astramed/features/apolo/providers/apolo_alert_state_provider.dart';
import 'package:astramed/features/crew/presentation/providers/crew_provider.dart';
import 'package:astramed/features/crew/presentation/widgets/crew_sidebar_drawer.dart';
import 'package:astramed/main.dart';
import 'package:astramed/features/agent/providers/agent_providers.dart';
import 'package:astramed/features/agent/domain/agent_contracts.dart';
import 'package:astramed/features/agent/domain/guided_assessment_catalog.dart';
import 'package:astramed/features/apolo/presentation/apolo_chat_orbs.dart';
import 'package:astramed/features/03_microgravity/presentation/cockpit_widgets/zero_g_horizon_card.dart';
import 'package:astramed/features/01_general_health/presentation/cockpit_widgets/vitals_cockpit_cards.dart';
import 'package:astramed/features/05_clinical_triage/presentation/cockpit_widgets/medical_procedures_card.dart';

Future<void> _pumpUi(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
}

void main() {
  testWidgets('radiation updates crew card, totals and crew menu without abnormal vitals',
      (tester) async {
    tester.view.physicalSize = const Size(1440, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const ApoloApp());
    await _pumpUi(tester);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(ApoloHomeScreen)),
    );
    expect(container.read(crewMembersProvider).first.riskLevel.name, 'nominal');
    container.read(apoloStateNotifierProvider.notifier).setSolarStorm(true);
    await tester.tap(find.byKey(const ValueKey('apolo_sidebar_button')));
    await _pumpUi(tester);
    final drawer = find.byType(CrewSidebarDrawer);
    expect(find.descendant(of: drawer, matching: find.text('0 Nominal')), findsOneWidget);
    expect(find.descendant(of: drawer, matching: find.text(
      '${container.read(effectiveCriticalCrewCountProvider)} Critical',
    )), findsOneWidget);
    expect(find.descendant(of: drawer, matching: find.text(
      '${container.read(effectiveWarningCrewCountProvider)} Attention',
    )), findsOneWidget);
    expect(find.descendant(of: drawer, matching: find.textContaining('Radiation:')), findsWidgets);
    final alex = find.byKey(const ValueKey('crew_status_AST-01'));
    expect(tester.widget<ApoloStatusChip>(find.descendant(
      of: alex, matching: find.byType(ApoloStatusChip),
    )).severity, isNot(ApoloSeverity.ok));
    // Switching away must not clear Alex's radiation status.
    container.read(selectedAstronautIdProvider.notifier).state = 'AST-02';
    await _pumpUi(tester);
    expect(tester.widget<ApoloStatusChip>(find.descendant(
      of: alex, matching: find.byType(ApoloStatusChip),
    )).severity, isNot(ApoloSeverity.ok));
    expect(tester.widgetList<ApoloStatusChip>(
      find.descendant(of: drawer, matching: find.byType(ApoloStatusChip)),
    ).every((chip) => chip.severity != ApoloSeverity.ok), isTrue);
    Navigator.of(tester.element(drawer)).pop();
    await _pumpUi(tester);
    ApoloCrewMenuDialog.show(tester.element(find.byType(ApoloHomeScreen)));
    await _pumpUi(tester);
    expect(tester.widgetList<ApoloStatusChip>(
      find.descendant(of: find.byType(ApoloCrewMenuDialog),
        matching: find.byType(ApoloStatusChip)),
    ).every((chip) => chip.severity != ApoloSeverity.ok), isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
    await _pumpUi(tester);
  });

  testWidgets(
    'APOLO starts all crew nominal on Day 1 without legacy Modules, and sidebar exposes Mission Simulator & Telemetry Config',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const ApoloApp());
      await _pumpUi(tester);

      // APOLO is the sole home screen and legacy Modules button is gone.
      expect(find.text('APOLO'), findsWidgets);
      expect(find.textContaining('Day 1 · Artemis Gateway'), findsOneWidget);
      expect(find.byKey(const Key('apolo_dog_widget')), findsOneWidget);
      expect(find.byKey(const Key('apolo_ask_input')), findsOneWidget);
      expect(find.byKey(const ValueKey('apolo_modules_button')), findsNothing);
      expect(find.byKey(const Key('apolo_red_alert_banner')), findsNothing);

      final container = ProviderScope.containerOf(
        tester.element(find.byType(ApoloHomeScreen)),
      );
      expect(container.read(nominalCrewCountProvider), 5);
      expect(container.read(warningCrewCountProvider), 0);
      expect(container.read(criticalCrewCountProvider), 0);
      expect(container.read(agentOrchestratorProvider).activeComponents, isEmpty);
      expect(container.read(agentNotifierProvider).notifications, isEmpty);

      await tester.tap(find.byKey(const ValueKey('apolo_sidebar_button')));
      await _pumpUi(tester);
      await tester.tap(find.byKey(const ValueKey('sidebar_assessments_button')));
      await _pumpUi(tester);
      await tester.tap(find.text('Start').first);
      await _pumpUi(tester);
      expect(find.byType(ApoloChatSheet), findsOneWidget);
      expect(find.byType(ZeroGHorizonCard), findsOneWidget);
      final orchestrator = container.read(agentOrchestratorProvider.notifier);
      final firstNonce = container.read(agentOrchestratorProvider).lastLaunchedNonce;
      await orchestrator.launchCockpitComponent('manual_vitals');
      await _pumpUi(tester);
      expect(find.byType(ManualVitalsTapCard), findsOneWidget);
      expect(find.byType(ZeroGHorizonCard), findsNothing);
      await orchestrator.launchGuidedAssessment(GuidedAssessmentCatalog.all.first);
      await _pumpUi(tester);
      expect(find.byType(ZeroGHorizonCard), findsOneWidget);
      expect(container.read(agentOrchestratorProvider).lastLaunchedNonce,
          firstNonce + 2);
      await tester.tap(find.byTooltip('Close'));
      await _pumpUi(tester);

      for (final action in <String, Type>{
        'sidebar_manual_vitals_button': ManualVitalsTapCard,
        'sidebar_procedures_button': MedicalProceduresCockpitCard,
        'sidebar_vitals_chart_button': VitalsTrendCockpitCard,
      }.entries) {
        await tester.tap(find.byKey(const ValueKey('apolo_sidebar_button')));
        await _pumpUi(tester);
        await tester.tap(find.byKey(ValueKey(action.key)));
        await _pumpUi(tester);
        expect(find.byType(action.value), findsOneWidget);
        await tester.tap(find.byTooltip('Dismiss'));
        await _pumpUi(tester);
        expect(find.byType(action.value), findsNothing);
      }

      // Open Crew Sidebar Drawer -> trigger Solar particle event via Mission Simulator.
      await tester.tap(find.byKey(const ValueKey('apolo_sidebar_button')));
      await _pumpUi(tester);
      expect(find.byType(CrewSidebarDrawer), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey('sidebar_mission_simulator_button')),
      );
      await _pumpUi(tester);
      expect(find.textContaining('Mission Simulator · Day 1'), findsOneWidget);

      await tester.tap(find.text('Solar particle event'));
      await _pumpUi(tester);
      expect(container.read(criticalCrewCountProvider), greaterThanOrEqualTo(1));

      // Reset nominal clears critical state back to Day 1 nominal.
      await tester.tap(find.text('Reset Nominal'));
      await _pumpUi(tester);
      expect(container.read(nominalCrewCountProvider), 5);
      expect(container.read(criticalCrewCountProvider), 0);
      expect(container.read(effectiveNominalCrewCountProvider), 5);
      expect(container.read(effectiveCriticalCrewCountProvider), 0);
      expect(find.byKey(const Key('apolo_red_alert_banner')), findsNothing);
      expect(container.read(agentNotifierProvider).notifications, isEmpty);
      expect(container.read(agentOrchestratorProvider).activeComponents.where(
        (component) => {
          ComponentIds.alertBanner,
          ComponentIds.spaceWeatherAlert,
          ComponentIds.evaReadiness,
        }.contains(component.componentId),
      ), isEmpty);

      await tester.tap(find.byTooltip('Close'));
      await _pumpUi(tester);

      // Re-open Crew Sidebar Drawer -> open Telemetry Config modal.
      await tester.tap(find.byKey(const ValueKey('apolo_sidebar_button')));
      await _pumpUi(tester);
      await tester.tap(
        find.byKey(const ValueKey('sidebar_telemetry_config_button')),
      );
      await _pumpUi(tester);

      expect(find.text('Telemetry & Hardware Configuration'), findsOneWidget);
      expect(find.textContaining('astronautId'), findsWidgets);
    },
  );
}
