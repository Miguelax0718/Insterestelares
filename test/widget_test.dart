import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:astramed/features/apolo/presentation/apolo_home_screen.dart';
import 'package:astramed/features/crew/presentation/providers/crew_provider.dart';
import 'package:astramed/features/crew/presentation/widgets/crew_sidebar_drawer.dart';
import 'package:astramed/main.dart';

Future<void> _pumpUi(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
}

void main() {
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

      await tester.tap(find.byTooltip('Close'));
      await _pumpUi(tester);

      // Re-open Crew Sidebar Drawer -> open Telemetry Config modal.
      await tester.tap(find.byKey(const ValueKey('apolo_sidebar_button')));
      await _pumpUi(tester);
      await tester.tap(
        find.byKey(const ValueKey('sidebar_telemetry_config_button')),
      );
      await _pumpUi(tester);

      expect(find.text('Configuración de Telemetría y Máquinas'), findsOneWidget);
      expect(find.textContaining('astronautId'), findsWidgets);
    },
  );
}
