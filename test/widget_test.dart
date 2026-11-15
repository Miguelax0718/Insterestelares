import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:astramed/main.dart';

void main() {
  testWidgets('APOLO is the home screen and opens the clinical dashboard', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const ApoloApp());
    await tester.pump(const Duration(milliseconds: 400));

    // APOLO is the app entry point and the mascot is on stage.
    expect(find.text('APOLO'), findsWidgets);
    expect(find.byKey(const Key('apolo_dog_widget')), findsOneWidget);
    expect(find.byKey(const Key('apolo_ask_input')), findsOneWidget);

    // The legacy 5-tab clinical modules dashboard stays reachable.
    await tester.tap(find.byKey(const Key('apolo_modules_button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Monitor de Salud General'), findsOneWidget);
    expect(find.text('Configurar Máquinas'), findsOneWidget);
    expect(
      find.byTooltip('Configurar Máquinas de Telemetría (ARES-1)'),
      findsOneWidget,
    );

    // Abrir modal desde el botón del AppBar
    await tester.tap(
      find.byTooltip('Configurar Máquinas de Telemetría (ARES-1)'),
    );
    await tester.pumpAndSettle();

    expect(find.text('Configuración de Telemetría y Máquinas'), findsOneWidget);
    expect(find.textContaining('astronautId'), findsWidgets);

    await tester.drag(find.byType(ListView).last, const Offset(0, -320));
    await tester.pumpAndSettle();

    expect(find.text('Bio-Monitor Astroskin'), findsOneWidget);

    // Cerrar y verificar apertura desde el botón de GeneralHealthView
    await tester.tap(find.byTooltip('Cerrar'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Configurar Máquinas'));
    await tester.pumpAndSettle();

    expect(find.text('Configuración de Telemetría y Máquinas'), findsOneWidget);
  });
}
