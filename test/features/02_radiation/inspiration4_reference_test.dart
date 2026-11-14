import 'dart:io';

import 'package:astramed/features/02_radiation/data/inspiration4_reference.dart';
import 'package:flutter_test/flutter_test.dart';

/// Comprueba que los valores copiados en el código coinciden con el archivo
/// real de la NASA guardado en DB/real/inspiration4/.
void main() {
  const csvPath =
      'DB/real/inspiration4/LSDS-7_Complete_Blood_Count_CBC.upload_SUBMITTED.csv';

  Map<String, double> readAnalyte(String analyte) {
    final lines = File(csvPath).readAsLinesSync();
    final header = lines.first.replaceAll('﻿', '').split(',');
    final out = <String, double>{};
    for (final line in lines.skip(1)) {
      final r = Map.fromIterables(header, line.split(','));
      if (r['ANALYTE'] == analyte) {
        out['${r['SUBJECT_ID']}|${r['TEST_DATE']}'] = double.parse(r['VALUE']!);
      }
    }
    return out;
  }

  test('los valores del código son los del archivo de la NASA', () {
    final lymph = readAnalyte('ABSOLUTE LYMPHOCYTES');
    final neut = readAnalyte('ABSOLUTE NEUTROPHILS');
    for (final s in Inspiration4Reference.subjects) {
      for (final v in [...s.preflight, s.returnDay1]) {
        if (s.id == 'C003' && v.timepoint == 'L-92') continue; // corregido
        final key = '${s.id}|${v.timepoint}';
        expect(v.lymphocytes10e9PerL * 1000, closeTo(lymph[key]!, 0.5), reason: key);
        expect(v.neutrophils10e9PerL * 1000, closeTo(neut[key]!, 0.5), reason: key);
      }
    }
  });

  test('corrección de C003 L-92: leucocitos × porcentaje', () {
    final wbc = readAnalyte('WHITE BLOOD CELL COUNT')['C003|L-92']!; // mil/µL
    final pctLymph = readAnalyte('LYMPHOCYTES')['C003|L-92']!;
    final pctNeut = readAnalyte('NEUTROPHILS')['C003|L-92']!;
    final c003 = Inspiration4Reference.subjects.firstWhere((s) => s.id == 'C003');
    expect(c003.preflight.first.lymphocytes10e9PerL, closeTo(wbc * pctLymph / 100, 0.01));
    expect(c003.preflight.first.neutrophils10e9PerL, closeTo(wbc * pctNeut / 100, 0.01));
  });

  test('variación entre visitas y cambio al regresar (valores reales)', () {
    double cv(List<double> xs) {
      final m = xs.reduce((a, b) => a + b) / xs.length;
      final v = xs.map((x) => (x - m) * (x - m)).reduce((a, b) => a + b) / (xs.length - 1);
      return (v < 0 ? 0 : _sqrt(v)) / m;
    }

    final subjects = Inspiration4Reference.subjects;
    final lymphCv = subjects
            .map((s) => cv(s.preflight.map((v) => v.lymphocytes10e9PerL).toList()))
            .reduce((a, b) => a + b) /
        subjects.length;
    final neutCv = subjects
            .map((s) => cv(s.preflight.map((v) => v.neutrophils10e9PerL).toList()))
            .reduce((a, b) => a + b) /
        subjects.length;
    expect(lymphCv, closeTo(Inspiration4Reference.lymphocyteWithinPersonCv, 0.01));
    expect(neutCv, closeTo(Inspiration4Reference.neutrophilWithinPersonCv, 0.01));

    // Al día siguiente del regreso los linfocitos bajaron en promedio ~18 %
    // (Inspiration4 recibió solo unos mSv: no es efecto de la radiación).
    final meanReturn =
        subjects.map((s) => s.returnLymphocyteChange).reduce((a, b) => a + b) /
            subjects.length;
    expect(meanReturn, closeTo(-0.18, 0.02));
  });
}

double _sqrt(double x) {
  var g = x;
  for (var i = 0; i < 40; i++) {
    g = 0.5 * (g + x / g);
  }
  return g;
}
