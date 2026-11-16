import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Escenario de las muestras de `DB/samples/`.
enum SampleScenario {
  realistic('realistic', 'Realista'),
  extreme('extreme', 'Extremo');

  const SampleScenario(this.fileSuffix, this.label);
  final String fileSuffix;
  final String label;
}

/// Escenario que muestran las tendencias de misión (por defecto, el realista).
final sampleScenarioProvider =
    StateProvider<SampleScenario>((ref) => SampleScenario.realistic);

/// Bundle de assets; se reemplaza en las pruebas.
final sampleAssetBundleProvider = Provider<AssetBundle>((ref) => rootBundle);

/// Una fila de un CSV de muestra, con lectura validada por nombre de columna.
class SampleRow {
  SampleRow(this._values, this._line);
  final Map<String, String> _values;
  final int _line;

  String text(String column) {
    final value = _values[column];
    if (value == null) {
      throw FormatException('Falta la columna $column (línea $_line).');
    }
    return value;
  }

  int integer(String column) {
    final value = int.tryParse(text(column));
    if (value == null) {
      throw FormatException('$column no es un entero (línea $_line).');
    }
    return value;
  }

  double number(String column) {
    final value = double.tryParse(text(column));
    if (value == null || !value.isFinite) {
      throw FormatException('$column no es un número (línea $_line).');
    }
    return value;
  }

  bool flag(String column) => text(column).toLowerCase() == 'true';
}

/// Lee un CSV simple (sin comillas ni comas dentro de los campos, como los
/// que escriben los generadores de `DB/samples/`).
List<SampleRow> parseSampleCsv(String csv, {required Set<String> columns}) {
  final lines = csv
      .replaceAll('﻿', '')
      .split(RegExp(r'\r?\n'))
      .where((l) => l.trim().isNotEmpty)
      .toList();
  if (lines.isEmpty) throw const FormatException('El CSV está vacío.');

  final header = lines.first.split(',').map((h) => h.trim()).toList();
  final missing = columns.difference(header.toSet());
  if (missing.isNotEmpty) {
    throw FormatException('Faltan columnas: ${missing.join(', ')}.');
  }

  final rows = <SampleRow>[];
  for (var i = 1; i < lines.length; i++) {
    final cells = lines[i].split(',');
    if (cells.length != header.length) {
      throw FormatException(
        'La línea ${i + 1} tiene ${cells.length} campos y se esperaban '
        '${header.length}.',
      );
    }
    rows.add(SampleRow({
      for (var c = 0; c < header.length; c++) header[c]: cells[c].trim(),
    }, i + 1));
  }
  return rows;
}
