import 'package:astramed/features/02_radiation/presentation/radiation_view.dart';
import 'package:astramed/features/02_radiation/providers/biomarker_providers.dart';
import 'package:astramed/features/02_radiation/widgets/biomarker_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<ProviderContainer> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: Scaffold(body: RadiationView())),
      ),
    );
    return ProviderScope.containerOf(tester.element(find.byType(BiomarkerPanel)));
  }

  testWidgets('la pantalla de radiación muestra el panel de biomarcadores',
      (tester) async {
    await pump(tester);
    expect(find.text('Dosímetro de Radiación Espacial'), findsOneWidget);
    expect(find.text('Biomarcadores de orina y sangre'), findsOneWidget);
    expect(find.text('AST-01'), findsOneWidget);
    expect(find.byKey(const Key('bioScoreText')), findsOneWidget);
  });

  testWidgets('cambiar de astronauta y al escenario extremo', (tester) async {
    final c = await pump(tester);
    await tester.tap(find.text('AST-03'));
    await tester.pump();
    expect(c.read(selectedAstronautProvider), 'AST-03');

    final before = c.read(selectedBioSummaryProvider).score;
    await tester.tap(find.byKey(const Key('extremeScenarioSwitch')));
    await tester.pump();
    final after = c.read(selectedBioSummaryProvider).score;
    expect(after, greaterThan(before));
    expect(BioLevel.of(after), BioLevel.alert);
  });

  test('semáforo', () {
    expect(BioLevel.of(0.05), BioLevel.normal);
    expect(BioLevel.of(0.15), BioLevel.watch);
    expect(BioLevel.of(0.30), BioLevel.alert);
  });
}
