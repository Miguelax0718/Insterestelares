import 'dart:io';

import 'package:astramed/features/02_radiation/data/radiation_csv_parser.dart';
import 'package:astramed/features/02_radiation/providers/dose_history.dart';
import 'package:astramed/features/02_radiation/providers/career_dose_calculator.dart';
import 'package:astramed/features/02_radiation/widgets/cumulative_dose_chart.dart';
import 'package:astramed/features/02_radiation/widgets/shelter_drill_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final records = RadiationCsvParser.parseDosimetry(
    File('DB/samples/radiation/dosimetry_daily.csv').readAsStringSync(),
  );

  test('History agrees with career totals and counts the SPE only once', () {
    final selected = records.where((r) => r.astronautId == 'AST-01').toList();
    final points = calculateDoseHistory(
      astronautId: 'AST-01',
      missionDay: 95,
      priorCareerDoseMsv: 40,
      records: records.reversed,
    );
    final expected = calculateCareerDose(
      priorCareerDoseMsv: 40,
      dailyDosesMsv: selected
          .where((r) => r.missionDay <= 95)
          .map((r) => r.effectiveDoseMsv),
    );
    expect(points.length, 96);
    expect(points.first.careerDoseMsv, 40);
    expect(points.last.missionDay, 95);
    expect(points.last.careerDoseMsv, closeTo(expected.totalMsv, 1e-9));
    expect(
      points.last.careerDoseMsv - points[94].careerDoseMsv,
      closeTo(
        selected.singleWhere((r) => r.missionDay == 95).effectiveDoseMsv,
        1e-9,
      ),
    );
    final otherCrew = calculateDoseHistory(
      astronautId: 'AST-02',
      missionDay: 1,
      priorCareerDoseMsv: 120,
      records: records,
    );
    expect(otherCrew.length, 2);
    expect(
      otherCrew.last.careerDoseMsv,
      closeTo(
        120 +
            records
                .singleWhere(
                  (r) => r.astronautId == 'AST-02' && r.missionDay == 1,
                )
                .effectiveDoseMsv,
        1e-9,
      ),
    );
  });

  test(
    'History rejects duplicate days, missing selected day and invalid doses',
    () {
      final first = records.first;
      expect(
        () => calculateDoseHistory(
          astronautId: first.astronautId,
          missionDay: 1,
          priorCareerDoseMsv: 40,
          records: [first, first],
        ),
        throwsArgumentError,
      );
      expect(
        () => calculateDoseHistory(
          astronautId: first.astronautId,
          missionDay: 2,
          priorCareerDoseMsv: 40,
          records: [first],
        ),
        throwsArgumentError,
      );
      expect(
        () => calculateDoseHistory(
          astronautId: first.astronautId,
          missionDay: 1,
          priorCareerDoseMsv: double.nan,
          records: [first],
        ),
        throwsArgumentError,
      );
    },
  );

  testWidgets(
    'Chart fits narrow and wide screens including a limit exceedance',
    (tester) async {
      for (final width in [320.0, 1000.0]) {
        tester.view.reset();
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: CumulativeDoseChart(
                points: [DoseHistoryPoint(0, 300), DoseHistoryPoint(180, 700)],
              ),
            ),
          ),
        );
        expect(find.text('Day 180: 700.0 mSv career total'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
      addTearDown(tester.view.reset);
    },
  );

  testWidgets('Drill uses its deadline, pauses, expires, resets and disposes', (
    tester,
  ) async {
    var now = DateTime.utc(2026, 11, 14);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ShelterDrillCard(
            duration: const Duration(seconds: 5),
            now: () => now,
          ),
        ),
      ),
    );
    await tester.tap(find.text('Start / resume drill'));
    now = now.add(const Duration(seconds: 2));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('00:00:03'), findsOneWidget);
    await tester.tap(find.text('Pause drill'));
    now = now.add(const Duration(minutes: 10));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('00:00:03'), findsOneWidget);
    await tester.tap(find.text('Start / resume drill'));
    now = now.add(const Duration(seconds: 20));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('00:00:00'), findsOneWidget);
    expect(
      find.text('Drill time elapsed. Shelter arrival is unconfirmed.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Reset drill'));
    await tester.pump();
    expect(find.text('00:00:05'), findsOneWidget);
    await tester.tap(find.text('Mark shelter reached'));
    await tester.pump();
    expect(
      find.text('Shelter arrival recorded for this drill.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Reset drill'));
    await tester.tap(find.text('Start / resume drill'));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 10));
    expect(tester.takeException(), isNull);
  });
}
