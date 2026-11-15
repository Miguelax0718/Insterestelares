import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:astramed/main.dart';

void main() {
  testWidgets('AstraMedApp loads dashboard and opens telemetry config modal',
      (WidgetTester tester) async {
    await tester.pumpWidget(const AstraMedApp());
    await tester.pumpAndSettle();

    expect(find.text('Monitor de Salud General'), findsOneWidget);
    expect(find.text('Configurar Sensores'), findsOneWidget);
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
    expect(
      find.text('Inyector de Escenarios de Simulación (Fuera de UI de Uso)'),
      findsOneWidget,
    );

    await tester.drag(find.byType(ListView).last, const Offset(0, -600));
    await tester.pumpAndSettle();

    expect(find.text('Bio-Monitor Astroskin'), findsOneWidget);

    // Cerrar y verificar apertura desde el botón de GeneralHealthView
    await tester.tap(find.byTooltip('Cerrar'));
    await tester.pumpAndSettle();

    // Verificar ausencia de filtro manual y presencia de panel de entorno + gamificación adaptativa
    expect(find.text('Contexto manual:'), findsNothing);
    expect(find.text('Entorno Operacional: Condiciones y Riesgos'), findsOneWidget);

    await tester.tap(find.text('Rover (EVA)'));
    await tester.pumpAndSettle();
    expect(find.text('Condiciones Físicas Vigiladas'), findsOneWidget);
    expect(find.text('Riesgos Clínicos Monitoreados'), findsOneWidget);

    final questBtn = find.text('Completar Cuestionario Periódico de Control (+35 XP)');
    await tester.scrollUntilVisible(
      questBtn,
      200.0,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(questBtn);
    await tester.pumpAndSettle();
    expect(find.text('PREVENCIÓN NOMINAL'), findsOneWidget);

    // Completar cuestionario adaptativo de 3 pasos y verificar persistencia en Bitácora
    await tester.tap(questBtn);
    await tester.pumpAndSettle();
    expect(find.text('Cuestionario Adaptativo • Paso 1/3'), findsOneWidget);

    await tester.tap(find.text('Siguiente'));
    await tester.pumpAndSettle();
    expect(find.text('Cuestionario Adaptativo • Paso 2/3'), findsOneWidget);

    await tester.tap(find.text('Siguiente'));
    await tester.pumpAndSettle();
    expect(find.text('Cuestionario Adaptativo • Paso 3/3'), findsOneWidget);

    await tester.tap(find.text('Finalizar y Guardar (+35 XP)'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Cuestionario Completado y Archivado'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Bitácora de Evaluaciones Registradas'),
      300.0,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Bitácora de Evaluaciones Registradas'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Configurar Sensores'),
      -300.0,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text('Configurar Sensores'));
    await tester.tap(find.text('Configurar Sensores'));
    await tester.pumpAndSettle();

    expect(find.text('Configuración de Telemetría y Máquinas'), findsOneWidget);

    // Cerrar modal y navegar al detalle de Presión Arterial en Salud General
    await tester.tap(find.byTooltip('Cerrar'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Presión Arterial'),
      300.0,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text('Presión Arterial'));
    await tester.tap(find.text('Presión Arterial'));
    await tester.pumpAndSettle();

    expect(find.text('Misión: Autoconocimiento Vital'), findsOneWidget);
    expect(find.text('Valores Medios por Contexto Fisiológico'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Misión (18 días)'),
      250.0,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Misión (18 días)'), findsOneWidget);
    expect(find.text('Últimas 24h'), findsOneWidget);
    expect(find.text('Últimos 7 días'), findsOneWidget);

    // Verificar diálogo de autochequeo educativo para completar revisión vital en VitalDetailFullScreenView
    await tester.scrollUntilVisible(
      find.text('Completar Revisión de Misión'),
      -250.0,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text('Completar Revisión de Misión'));
    await tester.tap(find.text('Completar Revisión de Misión'));
    await tester.pumpAndSettle();
    expect(find.text('Autochequeo Educativo: Presión Arterial'), findsOneWidget);
    expect(find.text('Cápsula de Salud: Monitoreo Contextual de Presión Arterial'), findsOneWidget);
    await tester.tap(find.text(
        'Registro consistente con mi estado de reposo / actividad actual'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Guardar Autochequeo (+50 XP)'));
    await tester.pumpAndSettle();
    expect(find.text('+50 XP Cumplido'), findsOneWidget);

    // Navegar de regreso y probar la pestaña de Triaje Autónomo con APOLO
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Triage'));
    await tester.pumpAndSettle();

    expect(find.text('APOLO • Asistente Médico de Triaje'), findsOneWidget);
    expect(find.textContaining('Soy APOLO'), findsOneWidget);

    // Enviar preset clínico de SANS y verificar respuesta contextual
    await tester.tap(find.text('Cefalea / Visión borrosa (SANS)'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Evaluando sospecha de Síndrome Neuro-Ocular'), findsOneWidget);
    expect(find.textContaining('Tableta con ToF'), findsOneWidget);
  });
}
