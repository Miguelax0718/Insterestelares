import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:astramed/features/03_microgravity/presentation/microgravity_view.dart';
import 'package:astramed/features/03_microgravity/sms/presentation/sms_suite_page.dart';

/// Tokens de fuga de simulador que NUNCA deben aparecer en la interfaz clínica.
const List<String> _forbiddenUiTokens = <String>[
  'simulador',
  'simulación',
  'simulacion',
  'simular',
  'simulated',
  'escenario biomédico',
  'escenario biomedico',
];

final RegExp _forbiddenWordPattern = RegExp(r'\bdemo\b', caseSensitive: false);

/// Recolecta todo el texto realmente renderizado en el árbol de widgets.
List<String> collectRenderedText(WidgetTester tester) {
  final texts = <String>[];
  for (final widget in tester.widgetList<Text>(find.byType(Text))) {
    final data = widget.data;
    if (data != null) texts.add(data);
    final span = widget.textSpan;
    if (span != null) texts.add(span.toPlainText());
  }
  for (final rich in tester.widgetList<RichText>(find.byType(RichText))) {
    texts.add(rich.text.toPlainText());
  }
  return texts;
}

void expectNoSimulatorLeakage(WidgetTester tester) {
  for (final text in collectRenderedText(tester)) {
    final lower = text.toLowerCase();
    for (final token in _forbiddenUiTokens) {
      expect(
        lower.contains(token),
        isFalse,
        reason: 'La interfaz no debe mostrar "$token" (texto: "$text")',
      );
    }
    expect(
      _forbiddenWordPattern.hasMatch(text),
      isFalse,
      reason: 'La interfaz no debe mostrar "Demo" (texto: "$text")',
    );
  }
}

void main() {
  group('S8: MicrogravityView — telemetría clínica real sin controles falsos', () {
    Future<void> pumpHub(WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(body: MicrogravityView()),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 50));
    }

    testWidgets(
      'renders the clinical optical & biometric telemetry banner with all live channels',
      (tester) async {
        await pumpHub(tester);

        expect(
          find.text('Telemetría Clínica Óptica & Biométrica'),
          findsOneWidget,
        );
        expect(
          find.textContaining('Cámara Óptica Frontal RGB/IPD'),
          findsOneWidget,
        );
        expect(
          find.textContaining('Giroscopio Vestibular 3-Ejes'),
          findsOneWidget,
        );
        expect(
          find.textContaining('Telemetría del Tripulante Activo'),
          findsOneWidget,
        );
        // El tripulante activo alimenta el canal biométrico.
        expect(find.textContaining('Alex Vance'), findsWidgets);
      },
    );

    testWidgets('exposes the Calibrar Óptica action for optical calibration', (
      tester,
    ) async {
      await pumpHub(tester);

      expect(find.text('Calibrar Óptica'), findsOneWidget);

      await tester.tap(find.text('Calibrar Óptica'));
      await tester.pumpAndSettle();

      expect(
        find.text('Calibración Óptica & Biométrica Basal'),
        findsOneWidget,
      );
    });

    testWidgets('has no simulation profile ChoiceChips and no simulator labels', (
      tester,
    ) async {
      await pumpHub(tester);

      expect(find.byType(ChoiceChip), findsNothing);
      expect(find.textContaining('Perfil de Telemetría'), findsNothing);
      expect(find.textContaining('Astronauta Nominal'), findsNothing);
      expectNoSimulatorLeakage(tester);
    });
  });

  group('S8: SmsSuitePage — escaneo espectral real, actitud por telemetría', () {
    Future<void> pumpSms(WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: SmsSuitePage()),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }

    Future<void> openTab(WidgetTester tester, String label) async {
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
    }

    Future<void> scrollTo(WidgetTester tester, Finder target) async {
      await tester.dragUntilVisible(
        target,
        find.byType(ListView).first,
        const Offset(0, -260),
      );
      await tester.pumpAndSettle();
    }

    testWidgets(
      'tab 1 shows the live optical viewport and only the real 15 s spectral scan',
      (tester) async {
        await pumpSms(tester);

        expect(
          find.textContaining('VISOR ÓPTICO FRONTAL EN VIVO'),
          findsOneWidget,
        );
        expect(
          find.text('PASO 1 · ESCANEO ESPECTRAL Δ(G/R) (15 s)'),
          findsOneWidget,
        );
        expect(
          find.text('Iniciar Escaneo Espectral (15 s)'),
          findsOneWidget,
        );
        expect(find.textContaining('Escaneo Rápido'), findsNothing);
        expect(find.textContaining('Escenario Biomédico'), findsNothing);
        expectNoSimulatorLeakage(tester);
      },
    );

    testWidgets(
      'tab 1 step CTA navigates cleanly to Zero-G Horizon (tab 2)',
      (tester) async {
        await pumpSms(tester);

        await scrollTo(
          tester,
          find.text('Continuar a Zero-G Horizon (Paso 2)'),
        );
        await tester.tap(find.text('Continuar a Zero-G Horizon (Paso 2)'));
        await tester.pumpAndSettle();

        expect(
          find.text('PASO 4 · ACOPLAMIENTO 3-EJES (45 s · OBJETIVO ≥ 70%)'),
          findsOneWidget,
        );
        expectNoSimulatorLeakage(tester);
      },
    );

    testWidgets(
      'tab 2 drives attitude from telemetry with vernier thrusters instead of fake sliders',
      (tester) async {
        await pumpSms(tester);
        await openTab(tester, '2. Zero-G Horizon (45s)');

        // Telemetría de actitud real de cabina.
        expect(
          find.text('TELEMETRÍA DE ACTITUD DE LA NAVE (INSTRUMENTACIÓN DE CABINA)'),
          findsOneWidget,
        );
        expect(find.text('Roll'), findsOneWidget);
        expect(find.text('Pitch'), findsOneWidget);
        expect(find.text('Yaw'), findsOneWidget);
        expect(find.text('Angular Rate'), findsOneWidget);

        // Propulsores vernier táctiles (control real del astronauta).
        expect(
          find.text('PROPULSORES VERNIER DE ACTITUD (RCS)'),
          findsOneWidget,
        );
        expect(find.text('Centrar Vernier'), findsOneWidget);

        // Sin botones de resultado instantáneo ni piloto automático.
        expect(find.textContaining('Simular 45s'), findsNothing);
        expect(find.textContaining('Asistencia de Estabilización'), findsNothing);
        expect(find.textContaining('Seguimiento Giroscópico Automático'), findsNothing);
        expectNoSimulatorLeakage(tester);
      },
    );

    testWidgets(
      'tab 3 keeps the Graybiel clinical symptom registry framed as vestibular telemetry',
      (tester) async {
        await pumpSms(tester);
        await openTab(tester, '3. Dictamen EVA & Cola');

        await scrollTo(
          tester,
          find.textContaining('RESUMEN DE TELEMETRÍA VESTIBULAR Y AUTONÓMICA'),
        );

        expect(
          find.textContaining('RESUMEN DE TELEMETRÍA VESTIBULAR Y AUTONÓMICA'),
          findsOneWidget,
        );
        expectNoSimulatorLeakage(tester);
      },
    );

    testWidgets(
      'PRESERVE: Graybiel symptom slider still updates the clinical score chip',
      (tester) async {
        await pumpSms(tester);

        await scrollTo(
          tester,
          find.textContaining('REGISTRO CLÍNICO DE SÍNTOMAS VESTIBULARES'),
        );

        expect(
          find.textContaining('REGISTRO CLÍNICO DE SÍNTOMAS VESTIBULARES'),
          findsOneWidget,
        );
        expect(find.text('Puntaje: 0 pts'), findsOneWidget);

        // Primer deslizador = Conciencia / Malestar Epigástrico (0..2).
        final slider = find.byType(Slider).first;
        await tester.drag(slider, const Offset(200, 0));
        await tester.pumpAndSettle();

        expect(find.text('Puntaje: 0 pts'), findsNothing);
        expect(find.textContaining('Puntaje: '), findsWidgets);
      },
    );
  });
}
