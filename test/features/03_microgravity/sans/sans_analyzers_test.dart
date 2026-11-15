import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:astramed/core/calibration/domain/device_calibration.dart';
import 'package:astramed/features/03_microgravity/sans/domain/sans_models_and_analyzers.dart';
import 'package:astramed/features/03_microgravity/sans/presentation/sans_suite_page.dart';

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
  group('S8: SansSuitePage — telemetría óptica real sin controles falsos', () {
    Future<void> pumpSans(WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: SansSuitePage()),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }

    Future<void> openTab(WidgetTester tester, String label) async {
      // La TabBar es desplazable: asegura que la pestaña esté visible antes de tocarla.
      await tester.ensureVisible(find.text(label));
      await tester.pumpAndSettle();
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
    }

    Future<void> scrollTo(WidgetTester tester, Finder target) async {
      await tester.dragUntilVisible(
        target.first,
        find.byType(SingleChildScrollView).first,
        const Offset(0, -260),
      );
      await tester.pumpAndSettle();
    }

    testWidgets(
      'tab 1 shows the live IPD caliper viewport and the focus-lock action',
      (tester) async {
        await pumpSans(tester);

        expect(
          find.textContaining('VISOR ÓPTICO FRONTAL EN VIVO'),
          findsOneWidget,
        );
        expect(
          find.textContaining('CALIBRE INTERPUPILAR BILATERAL'),
          findsOneWidget,
        );
        expect(
          find.text('Confirmar Punto de Enfoque Nítido (Capturar ΔD)'),
          findsOneWidget,
        );

        // Sin deslizador de distancia falsa ni chips de presets.
        expect(find.textContaining('Alejar pantalla hasta ver nítido'), findsNothing);
        expect(find.textContaining('Basal 25.0 cm'), findsNothing);
        expect(find.textContaining('30.8 cm'), findsNothing);
        expect(find.textContaining('36.3 cm'), findsNothing);
        expect(find.textContaining('44.4 cm'), findsNothing);
        expectNoSimulatorLeakage(tester);
      },
    );

    testWidgets(
      'tab 1 distance is derived live from the pinhole IPD trigonometry, not a slider',
      (tester) async {
        await pumpSans(tester);

        // El valor de distancia proviene de la telemetría, no de un control manual.
        expect(find.text('Distancia Ojo-Pantalla (d)'), findsOneWidget);

        final calibration = const DeviceCalibration(
          focalLengthPx: 580.0,
          crewIpdMm: 63.0,
          baselineNearPointCm: 25.0,
        );
        // Con el IPD de respaldo de la calibración, la distancia debe coincidir
        // con el basal: d = (f_px · IPD_mm) / (10 · IPD_px).
        final fallbackIpdPx =
            calibration.focalLengthPx * calibration.crewIpdMm / 250.0;
        final expectedCm =
            NearPointDiopterCalculator.computeEyeToScreenDistanceCm(
          ipdPixels: fallbackIpdPx,
          calibration: calibration,
        );
        expect(expectedCm, closeTo(25.0, 0.5));
        expect(
          find.text('${expectedCm.toStringAsFixed(1)} cm'),
          findsWidgets,
        );
      },
    );

    testWidgets(
      'tab 2 embeds the fixation monitor and keeps only the real psychophysical tasks',
      (tester) async {
        await pumpSans(tester);
        await openTab(tester, '2. Starfield Distortion Hunter');

        expect(
          find.textContaining('MONITOR DE FIJACIÓN CENTRAL'),
          findsOneWidget,
        );
        expect(
          find.text('GUÍA RÁPIDA · STARFIELD DISTORTION HUNTER'),
          findsOneWidget,
        );
        expect(find.text('Restablecer Destellos'), findsOneWidget);
        expect(find.text('Ojo Derecho (OD)'), findsOneWidget);
        expect(find.text('Ojo Izquierdo (OI)'), findsOneWidget);
        expect(
          find.textContaining('Caza de Pliegues (Metamorfopsia)'),
          findsOneWidget,
        );

        // Sin botones de escotoma/metamorfopsia instantáneos.
        expect(find.textContaining('Simular Escotoma'), findsNothing);
        expect(find.textContaining('Simular Metamorfopsia'), findsNothing);
        expectNoSimulatorLeakage(tester);
      },
    );

    testWidgets(
      'tab 1 step CTA transitions smoothly to Starfield tab sharing the camera viewport',
      (tester) async {
        await pumpSans(tester);

        expect(
          find.text('GUÍA RÁPIDA · PUNTO CERCANO (ΔD)'),
          findsOneWidget,
        );
        await scrollTo(
          tester,
          find.text('Continuar a Starfield Hunter (Paso 2)'),
        );
        await tester.tap(find.text('Continuar a Starfield Hunter (Paso 2)'));
        await tester.pumpAndSettle();

        expect(
          find.textContaining('MONITOR DE FIJACIÓN CENTRAL'),
          findsOneWidget,
        );
        expectNoSimulatorLeakage(tester);
      },
    );

    testWidgets(
      'tab 3 labels real LBNP pressure telemetry and has no time-skip control',
      (tester) async {
        await pumpSans(tester);
        await openTab(tester, '3. Contramedida LBNP (-20 mmHg)');

        expect(
          find.text(
            'Telemetría de Presión LBNP (Chibis-M / Protocolo -20 mmHg)',
          ),
          findsOneWidget,
        );
        expect(
          find.text('Iniciar Sellado y Presurización'),
          findsOneWidget,
        );
        expect(
          find.text('Iniciar Descompresión Gradual (-20 → 0 mmHg)'),
          findsOneWidget,
        );
        expect(find.text('Parada de Emergencia'), findsOneWidget);

        // Sin avance manual de tiempo ni telemetría rotulada como simulada.
        expect(find.textContaining('Avanzar +5 s'), findsNothing);
        expect(find.textContaining('Telemetría de Hardware Simulada'), findsNothing);
        expectNoSimulatorLeakage(tester);
      },
    );

    testWidgets(
      'PRESERVE: monocular OD/OI selector still rebuilds the peripheral stimuli set',
      (tester) async {
        await pumpSans(tester);
        await openTab(tester, '2. Starfield Distortion Hunter');

        expect(find.text('Ojo Derecho (OD)'), findsOneWidget);

        await scrollTo(tester, find.text('Ojo Izquierdo (OI)'));
        await tester.tap(find.text('Ojo Izquierdo (OI)'));
        await tester.pumpAndSettle();

        // El resultado evaluado sigue mostrando el ojo seleccionado.
        await scrollTo(tester, find.textContaining('Sensibilidad al contraste'));
        expect(
          find.textContaining('Sensibilidad al contraste'),
          findsWidgets,
        );      },
    );

    testWidgets(
      'PRESERVE: metamorphopsia straightening slider still changes the residual index',
      (tester) async {
        await pumpSans(tester);
        await openTab(tester, '2. Starfield Distortion Hunter');

        await scrollTo(tester, find.textContaining('Residual: '));
        final before = tester
            .widgetList<Text>(find.textContaining('Residual: '))
            .first
            .data!;

        final slider = find.byType(Slider).first;
        await tester.drag(slider, const Offset(-120, 0));
        await tester.pumpAndSettle();

        final after = tester
            .widgetList<Text>(find.textContaining('Residual: '))
            .first
            .data!;
        expect(after, isNot(equals(before)));
      },
    );
  });
}
