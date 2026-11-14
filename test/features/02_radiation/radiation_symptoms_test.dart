import 'package:astramed/features/02_radiation/models/radiation_symptom.dart';
import 'package:astramed/features/02_radiation/presentation/radiation_view.dart';
import 'package:astramed/features/02_radiation/providers/symptom_providers.dart';
import 'package:astramed/features/02_radiation/widgets/biomarker_panel.dart';
import 'package:astramed/features/02_radiation/widgets/biomarker_trend_chart.dart';
import 'package:astramed/features/02_radiation/widgets/radiation_symptoms_card.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RadiationSymptom', () {
    test('worstOf devuelve el nivel más alto o null', () {
      expect(RadiationSymptom.worstOf(const []), isNull);
      expect(RadiationSymptom.worstOf([RadiationSymptom.lightFlashes]),
          SymptomLevel.info);
      expect(
        RadiationSymptom.worstOf(
            [RadiationSymptom.fatigue, RadiationSymptom.lightFlashes]),
        SymptomLevel.watch,
      );
      expect(
        RadiationSymptom.worstOf(
            [RadiationSymptom.fatigue, RadiationSymptom.vomiting]),
        SymptomLevel.urgent,
      );
    });

    test('cada síntoma tiene textos de ayuda', () {
      for (final s in RadiationSymptom.values) {
        expect(s.label, isNotEmpty);
        expect(s.when, isNotEmpty);
        expect(s.why, isNotEmpty);
        expect(s.action, isNotEmpty);
      }
    });
  });

  group('BiomarkerTrendChart', () {
    BiomarkerTrendChart chart({required bool lowerIsWorse, int day = 50}) =>
        BiomarkerTrendChart(
          title: 't',
          meaning: 'm',
          spots: const [FlSpot(10, 5), FlSpot(40, 30), FlSpot(70, -30)],
          lowerIsWorse: lowerIsWorse,
          missionDays: 180,
          selectedDay: day,
        );

    test('el nivel depende de la dirección mala del marcador', () {
      final up = chart(lowerIsWorse: false);
      expect(up.levelOf(5), BioLevel.normal);
      expect(up.levelOf(15), BioLevel.watch);
      expect(up.levelOf(30), BioLevel.alert);
      expect(up.levelOf(-30), BioLevel.normal);

      final down = chart(lowerIsWorse: true);
      expect(down.levelOf(30), BioLevel.normal);
      expect(down.levelOf(-15), BioLevel.watch);
      expect(down.levelOf(-30), BioLevel.alert);
    });

    test('la lectura usa la última muestra hasta el día elegido', () {
      expect(chart(lowerIsWorse: false, day: 50).latestUpToSelected!.x, 40);
      expect(chart(lowerIsWorse: false, day: 5).latestUpToSelected, isNull);
    });
  });

  group('pantalla', () {
    Future<ProviderContainer> pump(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 6000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: Scaffold(body: RadiationView())),
        ),
      );
      return ProviderScope.containerOf(
          tester.element(find.byType(RadiationSymptomsCard)));
    }

    testWidgets('muestra una gráfica por marcador con su lectura', (tester) async {
      await pump(tester);
      expect(find.byType(BiomarkerTrendChart), findsNWidgets(2));
      expect(find.textContaining('vs. tu normal ·'), findsNWidgets(2));
    });

    testWidgets('marcar vómito pide avisar al cirujano de vuelo', (tester) async {
      final c = await pump(tester);
      expect(find.text('Sin síntomas marcados.'), findsOneWidget);

      await tester.ensureVisible(find.byKey(const Key('symptomCheck_fatigue')));
      await tester.tap(find.byKey(const Key('symptomCheck_fatigue')));
      await tester.pump();
      expect(find.text('Repórtalo en el próximo chequeo médico.'), findsOneWidget);

      await tester.ensureVisible(find.byKey(const Key('symptomCheck_vomiting')));
      await tester.tap(find.byKey(const Key('symptomCheck_vomiting')));
      await tester.pump();
      expect(find.text('Avisa al cirujano de vuelo ahora.'), findsOneWidget);
      expect(c.read(reportedSymptomsProvider('AST-01')),
          {RadiationSymptom.fatigue, RadiationSymptom.vomiting});
    });

    testWidgets('al tocar un síntoma se ve cuándo aparece y qué hacer',
        (tester) async {
      await pump(tester);
      final title = find.text(RadiationSymptom.vomiting.label);
      await tester.ensureVisible(title);
      await tester.tap(title);
      await tester.pumpAndSettle();
      expect(find.textContaining(RadiationSymptom.vomiting.action, findRichText: true),
          findsOneWidget);
    });
  });
}
