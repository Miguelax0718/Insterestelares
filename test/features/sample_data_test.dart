import 'dart:convert';
import 'dart:io';

import 'package:astramed/core/data/sample_data.dart';
import 'package:astramed/features/01_general_health/data/vitals_sample_repository.dart';
import 'package:astramed/features/01_general_health/presentation/vitals_trend_card.dart';
import 'package:astramed/features/03_microgravity/data/microgravity_sample_repository.dart';
import 'package:astramed/features/03_microgravity/presentation/microgravity_trend_cards.dart';
import 'package:astramed/features/04_mental_health/data/sleep_sample_repository.dart';
import 'package:astramed/features/04_mental_health/presentation/sleep_trend_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Sirve los archivos reales de DB/samples/ como si fueran assets.
class _DiskBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async =>
      ByteData.sublistView(File(key).readAsBytesSync());

  @override
  Future<String> loadString(String key, {bool cache = true}) async =>
      utf8.decode(File(key).readAsBytesSync());
}

double _mean(Iterable<double> values) =>
    values.reduce((a, b) => a + b) / values.length;

void main() {
  final bundle = _DiskBundle();
  const crew = ['AST-01', 'AST-02', 'AST-03', 'AST-04', 'AST-05'];

  group('parseSampleCsv', () {
    test('rechaza columnas faltantes y filas incompletas', () {
      expect(
        () => parseSampleCsv('a,b\n1,2', columns: {'c'}),
        throwsFormatException,
      );
      expect(
        () => parseSampleCsv('a,b\n1', columns: {'a'}),
        throwsFormatException,
      );
      expect(() => parseSampleCsv('', columns: {'a'}), throwsFormatException);
    });

    test('valida números y acepta BOM y CRLF', () {
      final rows = parseSampleCsv('﻿a,b\r\n1,x\r\n', columns: {'a', 'b'});
      expect(rows.single.integer('a'), 1);
      expect(() => rows.single.number('b'), throwsFormatException);
    });
  });

  group('signos vitales', () {
    test('realista: la presión baja en vuelo y no hay emergencias', () async {
      final points = await VitalsSampleRepository(assetBundle: bundle)
          .load(SampleScenario.realistic);
      expect(points.map((p) => p.astronautId).toSet(), crew.toSet());
      expect(points.every((p) => p.event.isEmpty), isTrue);

      for (final id in crew) {
        final mine = points.where((p) => p.astronautId == id);
        final pre = _mean(
          mine.where((p) => p.phase == 'preflight').map((p) => p.systolicBP),
        );
        final inflight = _mean(
          mine
              .where((p) => p.phase == 'inflight' && p.missionDay > 14)
              .map((p) => p.systolicBP),
        );
        // Norsk 2015: −8 mmHg (con margen por el ruido de 3 mediciones).
        expect(pre - inflight, inInclusiveRange(2, 14), reason: id);
      }
      expect(points.where((p) => p.orthostaticIntolerance).length, 4);
    });

    test('extremo: incluye las emergencias hipotéticas', () async {
      final points = await VitalsSampleRepository(assetBundle: bundle)
          .load(SampleScenario.extreme);
      final hypoxia = points.singleWhere((p) => p.event == 'post_eva_hypoxia');
      expect(hypoxia.astronautId, 'AST-03');
      expect(hypoxia.spO2, lessThan(90));
    });
  });

  group('sueño', () {
    test('realista: media en vuelo cercana a 6,09 h (Barger 2014)', () async {
      final nights = await SleepSampleRepository(assetBundle: bundle)
          .load(SampleScenario.realistic);
      final inflight = nights.where((n) => n.phase == 'inflight');
      expect(inflight.length, 180 * crew.length);
      expect(_mean(inflight.map((n) => n.sleepHours)), closeTo(6.09, 0.4));
    });

    test('la media de 7 noches tiene un punto por noche', () async {
      final nights =
          (await SleepSampleRepository(assetBundle: bundle)
                  .load(SampleScenario.extreme))
              .where((n) => n.astronautId == 'AST-02' && n.phase == 'inflight')
              .toList();
      final avg = SleepTrendCard.weeklyAverage(nights);
      expect(avg.length, nights.length);
      // Insomnio hipotético de AST-02 entre las noches 100 y 130.
      expect(avg.firstWhere((s) => s.x == 120).y, lessThan(5));
    });
  });

  group('microgravedad', () {
    test('realista: pérdidas dentro de lo publicado', () async {
      final sample = await MicrogravitySampleRepository(assetBundle: bundle)
          .load(SampleScenario.realistic);
      for (final id in crew) {
        final hip = sample.bone.singleWhere(
          (b) =>
              b.astronautId == id &&
              b.site == 'total_hip' &&
              b.missionDay == 180,
        );
        // 1–1,5 %/mes durante ~5,9 meses.
        expect(hip.changePct, inInclusiveRange(-9.0, -5.8), reason: id);
        final calf = sample.muscle.singleWhere(
          (m) =>
              m.astronautId == id && m.region == 'calf' && m.missionDay == 180,
        );
        expect(calf.changePct, inInclusiveRange(-16.0, -10.0), reason: id);

        final weeks = sample.weeklyExerciseMinutes(id);
        expect(weeks.length, 26);
        expect(
          _mean(weeks.values.take(25).map((m) => m.toDouble())),
          inInclusiveRange(450, 720),
          reason: id,
        );
      }
    });

    test('extremo: sin ARED el ejercicio semanal cae', () async {
      final sample = await MicrogravitySampleRepository(assetBundle: bundle)
          .load(SampleScenario.extreme);
      final weeks = sample.weeklyExerciseMinutes('AST-01');
      expect(weeks[20]!, lessThan(weeks[5]!));
    });
  });

  for (final width in [380.0, 900.0]) {
    testWidgets('las tarjetas de tendencia cargan y cambian de escenario '
        '(ancho ${width.toInt()})', (tester) async {
      tester.view.physicalSize = Size(width, 5000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.runAsync(() async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [sampleAssetBundleProvider.overrideWithValue(bundle)],
            child: MaterialApp(
              theme: ThemeData.dark(),
              home: const Scaffold(
                body: SingleChildScrollView(
                  child: Column(
                    children: [
                      VitalsTrendCard(astronautId: 'AST-03'),
                      SleepTrendCard(astronautId: 'AST-03'),
                      MicrogravityTrendCards(astronautId: 'AST-03'),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 300));
        await tester.pump();
        expect(find.text('Sistólica'), findsOneWidget);
        expect(find.text('Media en vuelo'), findsOneWidget);
        expect(find.text('Pantorrilla'), findsOneWidget);
        expect(find.textContaining('hipoxia'), findsNothing);

        await tester.tap(find.text('Extremo').first);
        await tester.pump();
        await Future<void>.delayed(const Duration(milliseconds: 300));
        await tester.pump();
        expect(find.textContaining('hipoxia'), findsOneWidget);
        expect(find.textContaining('ARED fuera de servicio'), findsOneWidget);
      });
    });
  }
}
