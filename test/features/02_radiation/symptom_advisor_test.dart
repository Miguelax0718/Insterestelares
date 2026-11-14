import 'package:astramed/features/02_radiation/models/biomarkers/biomarker_baseline.dart';
import 'package:astramed/features/02_radiation/models/contracts/bio_summary.dart';
import 'package:astramed/features/02_radiation/providers/symptom_advisor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const advisor = SymptomAdvisor();
  BioSummary summary(Map<Biomarker, double> changes) => BioSummary(
        astronautId: 'A',
        date: DateTime.utc(2027),
        changeFromBaseline: changes,
        score: 0,
        samplePending: false,
      );

  List<String> titles(List<PossibleSymptom> s) => s.map((x) => x.title).toList();

  test('todo normal: no se esperan síntomas', () {
    final s = advisor.evaluate(
        summary: summary({Biomarker.bloodLymphocytes: -0.1}), speDoseGy: 0.05);
    expect(titles(s), ['No se esperan síntomas por radiación']);
    expect(s.single.level, SymptomLevel.info);
  });

  test('dosis > 0,7 Gy en los 2 días siguientes: náuseas y vómito (CDC)', () {
    final s = advisor.evaluate(
        summary: summary({}), speDoseGy: 1.0, daysSinceSpe: 1);
    expect(s.first.title, contains('Náuseas, vómito'));
    expect(s.first.level, SymptomLevel.alert);
    // Pasada la fase inicial ya no se listan.
    final later = advisor.evaluate(
        summary: summary({}), speDoseGy: 1.0, daysSinceSpe: 10);
    expect(titles(later).join(), isNot(contains('Náuseas')));
  });

  test('entre 0,3 y 0,7 Gy: síntomas leves', () {
    final s = advisor.evaluate(
        summary: summary({}), speDoseGy: 0.4, daysSinceSpe: 0);
    expect(s.first.level, SymptomLevel.watch);
  });

  test('linfocitos −47 %: riesgo de infecciones', () {
    final s = advisor.evaluate(
        summary: summary({Biomarker.bloodLymphocytes: -0.47}), speDoseGy: 0);
    final inf = s.firstWhere((x) => x.title.contains('infecciones'));
    expect(inf.level, SymptomLevel.watch);
    expect(inf.detail, contains('47 %'));
  });

  test('estrés oxidativo sin dosis alta: probablemente hábitos', () {
    final s = advisor.evaluate(
        summary: summary({Biomarker.urineOhdg: 0.4}), speDoseGy: 0.01);
    expect(s.single.detail, contains('no la radiación'));
  });
}
