import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:astramed/main.dart';

void main() {
  testWidgets('AstraMedApp loads dashboard and opens telemetry config modal',
      (WidgetTester tester) async {
    await tester.pumpWidget(const AstraMedApp());
    await tester.pumpAndSettle();

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
