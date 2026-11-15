import 'dart:convert';

import 'package:hive/hive.dart';

import '../../domain/agent_contracts.dart';
import 'agent_hive_boxes.dart';

/// Hive-backed per-astronaut [AgentFlagsStore] storing plain JSON records
/// without TypeAdapters.
class HiveFlagsStore implements AgentFlagsStore {
  HiveFlagsStore(this._box);

  final Box<dynamic> _box;

  String _keyFor(String astronautId, String key) =>
      jsonEncode(<String>[astronautId, key]);

  @override
  Future<void> setFlag(
    String astronautId,
    String key,
    Map<String, dynamic> value,
  ) async {
    if (astronautId.trim().isEmpty) {
      throw ArgumentError.value(
        astronautId,
        'astronautId',
        'Flag astronautId must not be empty.',
      );
    }
    if (key.trim().isEmpty) {
      throw ArgumentError.value(key, 'key', 'Flag key must not be empty.');
    }
    await _box.put(
      _keyFor(astronautId, key),
      jsonEncode(<String, dynamic>{
        'astronaut_id': astronautId,
        'key': key,
        'value': value,
      }),
    );
  }

  @override
  Future<Map<String, dynamic>?> getFlag(String astronautId, String key) async {
    final raw = _box.get(_keyFor(astronautId, key));
    if (raw == null) {
      return null;
    }
    final record = decodeHiveJsonMap(raw);
    final value = record['value'];
    if (value is Map<String, dynamic>) {
      return Map<String, dynamic>.from(value);
    }
    if (value is Map) {
      return normalizeJsonMap(value);
    }
    return null;
  }

  @override
  Future<Map<String, Map<String, dynamic>>> allForAstronaut(
    String astronautId,
  ) async {
    final result = <String, Map<String, dynamic>>{};
    for (final raw in _box.values) {
      final record = decodeHiveJsonMap(raw);
      if (record['astronaut_id'] != astronautId) {
        continue;
      }
      final key = record['key'] as String?;
      final value = record['value'];
      if (key == null) {
        continue;
      }
      if (value is Map<String, dynamic>) {
        result[key] = Map<String, dynamic>.from(value);
      } else if (value is Map) {
        result[key] = normalizeJsonMap(value);
      }
    }
    return result;
  }
}
