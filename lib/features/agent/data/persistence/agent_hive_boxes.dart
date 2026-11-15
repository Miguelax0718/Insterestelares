import 'dart:convert';

import 'package:hive/hive.dart';

/// Opens and provides the Hive boxes used for on-device agent persistence.
class AgentHiveBoxes {
  AgentHiveBoxes({
    required this.memoryBox,
    required this.auditBox,
    required this.flagsBox,
  });

  static const String memoryBoxName = 'agent_memory';
  static const String auditBoxName = 'agent_audit';
  static const String flagsBoxName = 'agent_flags';

  final Box<dynamic> memoryBox;
  final Box<dynamic> auditBox;
  final Box<dynamic> flagsBox;

  /// Opens all agent persistence boxes.
  ///
  /// When [directoryPath] is provided (for example a temporary directory in
  /// unit tests or non-Flutter environments), [Hive.init] is called with that
  /// path before opening boxes. Otherwise uses the already-initialized Hive
  /// instance.
  static Future<AgentHiveBoxes> open({
    String? directoryPath,
    String memoryBox = memoryBoxName,
    String auditBox = auditBoxName,
    String flagsBox = flagsBoxName,
  }) async {
    if (directoryPath != null) {
      Hive.init(directoryPath);
    }
    final memory = await Hive.openBox<dynamic>(memoryBox);
    final audit = await Hive.openBox<dynamic>(auditBox);
    final flags = await Hive.openBox<dynamic>(flagsBox);
    return AgentHiveBoxes(memoryBox: memory, auditBox: audit, flagsBox: flags);
  }

  /// Closes all opened boxes.
  Future<void> close() async {
    if (memoryBox.isOpen) {
      await memoryBox.close();
    }
    if (auditBox.isOpen) {
      await auditBox.close();
    }
    if (flagsBox.isOpen) {
      await flagsBox.close();
    }
  }
}

/// Decodes a JSON string or Hive-deserialized dynamic map into a normalized
/// `Map<String, dynamic>`.
Map<String, dynamic> decodeHiveJsonMap(dynamic raw) {
  if (raw is String) {
    final decoded = jsonDecode(raw);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    if (decoded is Map) {
      return normalizeJsonMap(decoded);
    }
  } else if (raw is Map) {
    return normalizeJsonMap(raw);
  }
  throw FormatException(
    'Expected JSON string or Map in Hive box, got ${raw.runtimeType}.',
  );
}

/// Recursively normalizes dynamic maps and lists into `Map<String, dynamic>`.
Map<String, dynamic> normalizeJsonMap(Map<dynamic, dynamic> source) {
  return <String, dynamic>{
    for (final entry in source.entries)
      entry.key.toString(): _normalizeJsonValue(entry.value),
  };
}

dynamic _normalizeJsonValue(dynamic value) {
  if (value is Map) {
    return normalizeJsonMap(value);
  }
  if (value is List) {
    return value.map(_normalizeJsonValue).toList(growable: false);
  }
  return value;
}
