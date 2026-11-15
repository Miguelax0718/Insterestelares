import 'dart:convert';

import 'package:hive/hive.dart';

import '../../domain/agent_contracts.dart';
import 'agent_hive_boxes.dart';

/// Append-only Hive-backed [AuditLog] storing JSON-encoded [AuditEntry]
/// records without TypeAdapters.
class HiveAuditLog implements AuditLog {
  HiveAuditLog(this._box);

  final Box<dynamic> _box;

  @override
  Future<void> append(AuditEntry entry) async {
    if (entry.id.trim().isEmpty) {
      throw ArgumentError.value(
        entry.id,
        'id',
        'AuditEntry id must not be empty.',
      );
    }
    if (_box.containsKey(entry.id)) {
      throw StateError(
        'AuditEntry "${entry.id}" already exists; audit log is append-only.',
      );
    }
    await _box.put(entry.id, jsonEncode(entry.toJson()));
  }

  @override
  Future<List<AuditEntry>> list({String? astronautId, int limit = 50}) async {
    if (limit <= 0) {
      return const [];
    }
    final indexed = <(int index, AuditEntry entry)>[];
    var index = 0;
    for (final raw in _box.values) {
      final entry = AuditEntry.fromJson(decodeHiveJsonMap(raw));
      if (astronautId == null || entry.astronautId == astronautId) {
        indexed.add((index, entry));
      }
      index++;
    }

    indexed.sort((a, b) {
      final byTimestamp = b.$2.timestamp.compareTo(a.$2.timestamp);
      if (byTimestamp != 0) {
        return byTimestamp;
      }
      return b.$1.compareTo(a.$1);
    });

    return indexed.take(limit).map((item) => item.$2).toList(growable: false);
  }
}
