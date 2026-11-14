import 'package:astramed/features/02_radiation/models/biomarkers/biomarker_baseline.dart';
import 'package:astramed/features/02_radiation/models/biomarkers/blood_sample.dart';
import 'package:astramed/features/02_radiation/models/biomarkers/urine_sample.dart';
import 'package:astramed/features/02_radiation/models/contracts/bio_summary.dart';
import 'package:astramed/features/02_radiation/providers/biomarker_score_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const calc = BiomarkerScoreCalculator();
  final day0 = DateTime.utc(2026, 1, 1);

  // Muestra de orina "normal": creatinina 100 mg/dL = 1 mg/mL, así el valor
  // normalizado es igual al crudo (fácil de razonar en las pruebas).
  UrineSample urine(DateTime at, {double ohdg = 5, double iso = 1, double mda = 2}) =>
      UrineSample(
        astronautId: 'A1',
        takenAt: at,
        ohdgNgPerMl: ohdg,
        isoprostaneNgPerMl: iso,
        mdaUmolPerL: mda,
        creatinineMgPerDl: 100,
      );

  BloodSample blood(DateTime at, {double lymph = 2, double neut = 4, double crp = 1}) =>
      BloodSample(
        astronautId: 'A1',
        takenAt: at,
        lymphocytes10e9PerL: lymph,
        neutrophils10e9PerL: neut,
        crpMgPerL: crp,
      );

  final baseline = BiomarkerBaseline(
    astronautId: 'A1',
    preflightMean: {
      Biomarker.urineOhdg: 5,
      Biomarker.urineIsoprostane: 1,
      Biomarker.urineMda: 2 / (100 * 10 / 1000), // = mdaPerCreatinine de 2 µmol/L
      Biomarker.bloodLymphocytes: 2,
      Biomarker.bloodNeutrophils: 4,
      Biomarker.bloodCrp: 1,
    },
    sampleCount: 3,
    measuredUntil: day0,
  );

  group('UrineSample', () {
    test('normaliza por creatinina', () {
      final s = UrineSample(
        astronautId: 'A1',
        takenAt: day0,
        ohdgNgPerMl: 10,
        isoprostaneNgPerMl: 2,
        mdaUmolPerL: 3,
        creatinineMgPerDl: 50, // 0.5 mg/mL
      );
      expect(s.ohdgPerCreatinine, closeTo(20, 1e-9));
      expect(s.isoprostanePerCreatinine, closeTo(4, 1e-9));
      expect(s.mdaPerCreatinine, closeTo(6, 1e-9)); // 3 / 0.5 g/L
    });

    test('rechaza creatinina en 0 y valores negativos', () {
      expect(() => urine(day0).copyWithCreatinine(0), throwsArgumentError);
      expect(() => urine(day0, ohdg: -1), throwsArgumentError);
    });

    test('ida y vuelta a JSON', () {
      final s = urine(day0, ohdg: 7.5);
      final back = UrineSample.fromJson(s.toJson());
      expect(back.ohdgNgPerMl, 7.5);
      expect(back.takenAt, day0);
    });
  });

  group('BiomarkerScoreCalculator', () {
    test('cambio relativo', () {
      expect(BiomarkerScoreCalculator.relativeChange(7, 5), closeTo(0.4, 1e-9));
      expect(BiomarkerScoreCalculator.relativeChange(1, 2), closeTo(-0.5, 1e-9));
      expect(() => BiomarkerScoreCalculator.relativeChange(1, 0), throwsArgumentError);
    });

    test('todo igual a la línea base da puntaje 0', () {
      final s = calc.summarize(
        baseline: baseline,
        urineSamples: [urine(day0)],
        bloodSamples: [blood(day0)],
        date: day0,
      );
      expect(s.score, closeTo(0, 1e-9));
      expect(s.changeFromBaseline.length, 6);
      expect(s.samplePending, isFalse);
    });

    test('8-OHdG +40 % sube el puntaje según su peso', () {
      final s = calc.summarize(
        baseline: baseline,
        urineSamples: [urine(day0, ohdg: 7)],
        bloodSamples: [blood(day0)],
        date: day0,
      );
      expect(s.changeOf(Biomarker.urineOhdg), closeTo(0.4, 1e-9));
      expect(s.score, closeTo(0.30 * 0.4, 1e-9));
    });

    test('bajada de linfocitos cuenta como daño (puntaje positivo)', () {
      final s = calc.summarize(
        baseline: baseline,
        urineSamples: [urine(day0)],
        bloodSamples: [blood(day0, lymph: 1)], // −50 %
        date: day0,
      );
      expect(s.changeOf(Biomarker.bloodLymphocytes), closeTo(-0.5, 1e-9));
      expect(s.score, closeTo(0.25 * 0.5, 1e-9));
    });

    test('solo orina: los pesos se reparten entre los marcadores presentes', () {
      final s = calc.summarize(
        baseline: baseline,
        urineSamples: [urine(day0, ohdg: 10)], // +100 %
        bloodSamples: const [],
        date: day0,
      );
      expect(s.changeFromBaseline.keys,
          containsAll([Biomarker.urineOhdg, Biomarker.urineIsoprostane, Biomarker.urineMda]));
      expect(s.changeOf(Biomarker.bloodLymphocytes), isNull);
      expect(s.score, closeTo(0.30 * 1.0 / 0.55, 1e-9));
    });

    test('usa la muestra más reciente y descarta otras personas y el futuro', () {
      final other = UrineSample(
        astronautId: 'B2',
        takenAt: day0.add(const Duration(days: 2)),
        ohdgNgPerMl: 50,
        isoprostaneNgPerMl: 1,
        mdaUmolPerL: 2,
        creatinineMgPerDl: 100,
      );
      final s = calc.summarize(
        baseline: baseline,
        urineSamples: [
          urine(day0, ohdg: 6),
          urine(day0.add(const Duration(days: 2)), ohdg: 7),
          urine(day0.add(const Duration(days: 9)), ohdg: 99), // futuro
          other,
        ],
        bloodSamples: const [],
        date: day0.add(const Duration(days: 3)),
      );
      expect(s.changeOf(Biomarker.urineOhdg), closeTo(0.4, 1e-9));
    });

    test('ignora muestras de más de 14 días', () {
      final s = calc.summarize(
        baseline: baseline,
        urineSamples: [urine(day0, ohdg: 10)],
        bloodSamples: const [],
        date: day0.add(const Duration(days: 20)),
      );
      expect(s.changeFromBaseline, isEmpty);
      expect(s.score, 0);
    });

    test('muestra pendiente: sin muestras, rutina semanal y tras tormenta solar', () {
      expect(
        calc.summarize(baseline: baseline, urineSamples: const [], bloodSamples: const [], date: day0).samplePending,
        isTrue,
      );
      expect(
        calc.summarize(
          baseline: baseline,
          urineSamples: [urine(day0)],
          bloodSamples: const [],
          date: day0.add(const Duration(days: 7)),
        ).samplePending,
        isTrue,
      );
      expect(
        calc.summarize(
          baseline: baseline,
          urineSamples: [urine(day0)],
          bloodSamples: const [],
          date: day0.add(const Duration(days: 2)),
          lastSolarEventAt: day0.add(const Duration(days: 1)),
        ).samplePending,
        isTrue,
      );
      expect(
        calc.summarize(
          baseline: baseline,
          urineSamples: [urine(day0.add(const Duration(days: 1, hours: 6)))],
          bloodSamples: const [],
          date: day0.add(const Duration(days: 2)),
          lastSolarEventAt: day0.add(const Duration(days: 1)),
        ).samplePending,
        isFalse,
      );
    });

    test('el resumen se puede guardar y leer en JSON', () {
      final s = calc.summarize(
        baseline: baseline,
        urineSamples: [urine(day0, ohdg: 7)],
        bloodSamples: [blood(day0)],
        date: day0,
      );
      final back = BioSummary.fromJson(s.toJson());
      expect(back.score, closeTo(s.score, 1e-12));
      expect(back.changeOf(Biomarker.urineOhdg), closeTo(0.4, 1e-9));
    });
  });
}

extension on UrineSample {
  UrineSample copyWithCreatinine(double creatinine) => UrineSample(
        astronautId: astronautId,
        takenAt: takenAt,
        ohdgNgPerMl: ohdgNgPerMl,
        isoprostaneNgPerMl: isoprostaneNgPerMl,
        mdaUmolPerL: mdaUmolPerL,
        creatinineMgPerDl: creatinine,
      );
}
