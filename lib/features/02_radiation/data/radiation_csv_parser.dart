import '../models/daily_radiation_record.dart';
import '../models/radiation_organ.dart';
import '../models/space_weather_reading.dart';

/// Parses the feature's local CSV datasets without external packages.
class RadiationCsvParser {
  static const _dosimetryColumns = <String>{
    'mission_day',
    'astronaut_id',
    'module',
    'effective_dose_msv',
    'skin_mgy_eq',
    'blood_forming_organs_mgy_eq',
    'lens_mgy_eq',
    'circulatory_system_mgy_eq',
    'central_nervous_system_mgy',
    'spe_event_dose_msv',
    'data_type',
  };

  static const _spaceWeatherColumns = <String>{
    'mission_day',
    'proton_flux_pfu',
    'alert_level',
    'event_spe',
    'data_type',
  };

  /// Converts daily dosimetry CSV text into validated typed records.
  static List<DailyRadiationRecord> parseDosimetry(String csv) {
    final table = _parseTable(csv, _dosimetryColumns);
    final column = table.columnIndexes;
    return table.rows.map((row) {
      final doses = <RadiationOrgan, double>{
        RadiationOrgan.skin: _readDouble(row, column, 'skin_mgy_eq'),
        RadiationOrgan.bloodFormingOrgans:
            _readDouble(row, column, 'blood_forming_organs_mgy_eq'),
        RadiationOrgan.lens: _readDouble(row, column, 'lens_mgy_eq'),
        RadiationOrgan.circulatorySystem:
            _readDouble(row, column, 'circulatory_system_mgy_eq'),
        RadiationOrgan.centralNervousSystem:
            _readDouble(row, column, 'central_nervous_system_mgy'),
      };

      return DailyRadiationRecord(
        astronautId: _readText(row, column, 'astronaut_id'),
        missionDay: _readInt(row, column, 'mission_day'),
        module: _readText(row, column, 'module'),
        effectiveDoseMsv: _readDouble(row, column, 'effective_dose_msv'),
        organDoses: doses,
        speEventDoseMsv: _readDouble(row, column, 'spe_event_dose_msv'),
        dataType: _readText(row, column, 'data_type'),
      );
    }).toList(growable: false);
  }

  /// Converts space-weather CSV text into validated typed records.
  static List<SpaceWeatherReading> parseSpaceWeather(String csv) {
    final table = _parseTable(csv, _spaceWeatherColumns);
    final column = table.columnIndexes;
    return table.rows.map((row) {
      final eventValue = _readText(row, column, 'event_spe').toLowerCase();
      if (eventValue != 'true' && eventValue != 'false') {
        throw FormatException('Column event_spe must be true or false.');
      }
      return SpaceWeatherReading(
        missionDay: _readInt(row, column, 'mission_day'),
        protonFluxPfu: _readDouble(row, column, 'proton_flux_pfu'),
        alertLevel: _readText(row, column, 'alert_level'),
        eventSpe: eventValue == 'true',
        dataType: _readText(row, column, 'data_type'),
      );
    }).toList(growable: false);
  }
}

class _ParsedTable {
  const _ParsedTable(this.columnIndexes, this.rows);

  final Map<String, int> columnIndexes;
  final List<List<String>> rows;
}

_ParsedTable _parseTable(String csv, Set<String> requiredColumns) {
  var normalized = csv.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  if (normalized.startsWith('\uFEFF')) {
    normalized = normalized.substring(1);
  }
  final lines = normalized.split('\n');
  final nonBlankLines = <({int lineNumber, String text})>[];
  for (var index = 0; index < lines.length; index++) {
    if (lines[index].trim().isNotEmpty) {
      nonBlankLines.add((lineNumber: index + 1, text: lines[index]));
    }
  }
  if (nonBlankLines.isEmpty) {
    throw const FormatException('CSV is empty.');
  }

  final header = _parseCsvLine(nonBlankLines.first.text, nonBlankLines.first.lineNumber)
      .map((value) => value.trim().toLowerCase())
      .toList(growable: false);
  final indexes = <String, int>{};
  for (var index = 0; index < header.length; index++) {
    if (header[index].isEmpty || indexes.containsKey(header[index])) {
      throw const FormatException('CSV header contains a blank or duplicate column.');
    }
    indexes[header[index]] = index;
  }
  final missing = requiredColumns.difference(indexes.keys.toSet());
  if (missing.isNotEmpty) {
    throw FormatException('CSV is missing required columns: ${missing.join(', ')}.');
  }

  final rows = <List<String>>[];
  for (final line in nonBlankLines.skip(1)) {
    final row = _parseCsvLine(line.text, line.lineNumber);
    if (row.length != header.length) {
      throw FormatException(
        'CSV line ${line.lineNumber} has ${row.length} values; expected ${header.length}.',
      );
    }
    rows.add(row);
  }
  return _ParsedTable(indexes, rows);
}

List<String> _parseCsvLine(String line, int lineNumber) {
  final fields = <String>[];
  var field = StringBuffer();
  var insideQuotes = false;

  for (var index = 0; index < line.length; index++) {
    final character = line[index];
    if (character == '"') {
      if (insideQuotes && index + 1 < line.length && line[index + 1] == '"') {
        field.write('"');
        index++;
      } else {
        insideQuotes = !insideQuotes;
      }
    } else if (character == ',' && !insideQuotes) {
      fields.add(field.toString().trim());
      field = StringBuffer();
    } else {
      field.write(character);
    }
  }

  if (insideQuotes) {
    throw FormatException('CSV line $lineNumber has an unclosed quoted value.');
  }
  fields.add(field.toString().trim());
  return fields;
}

String _readText(List<String> row, Map<String, int> columns, String name) {
  final value = row[columns[name]!].trim();
  if (value.isEmpty) {
    throw FormatException('Column $name must not be empty.');
  }
  return value;
}

int _readInt(List<String> row, Map<String, int> columns, String name) {
  final value = int.tryParse(_readText(row, columns, name));
  if (value == null || value < 1) {
    throw FormatException('Column $name must contain a positive integer.');
  }
  return value;
}

double _readDouble(List<String> row, Map<String, int> columns, String name) {
  final value = double.tryParse(_readText(row, columns, name));
  if (value == null || !value.isFinite || value < 0) {
    throw FormatException('Column $name must contain a finite, non-negative number.');
  }
  return value;
}
