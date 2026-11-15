import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

/// Nombres de las cajas locales (100% Offline-First)
class HiveBoxNames {
  static const String smsAssessments = 'sms_assessments';
  static const String sansAssessments = 'sans_assessments';
  static const String lbnpSessions = 'lbnp_sessions';
  static const String deviceCalibration = 'device_calibration';
  static const String syncQueue = 'telemetry_sync_queue';

  static const List<String> allBoxes = [
    smsAssessments,
    sansAssessments,
    lbnpSessions,
    deviceCalibration,
    syncQueue,
  ];
}

/// Inicializador y fachada de almacenamiento local Hive con cola de sincronización
/// diferida para espacio profundo (AGENTS.md 6.3B).
class HiveBootstrap {
  static bool _initialized = false;

  static bool get isInitialized => _initialized;

  /// Inicializa Hive en entorno Flutter.
  static Future<void> initFlutterStorage() async {
    if (_initialized) return;
    await Hive.initFlutter();
    await _openAllBoxes();
    _initialized = true;
  }

  /// Inicializa Hive en un directorio temporal (para pruebas unitarias sin canal nativo).
  static Future<void> initForTest(String tempPath) async {
    if (_initialized) return;
    final dir = Directory(tempPath);
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    Hive.init(tempPath);
    await _openAllBoxes();
    _initialized = true;
  }

  static Future<void> _openAllBoxes() async {
    for (final name in HiveBoxNames.allBoxes) {
      if (!Hive.isBoxOpen(name)) {
        await Hive.openBox<Map<dynamic, dynamic>>(name);
      }
    }
  }

  static Box<Map<dynamic, dynamic>> box(String name) {
    return Hive.box<Map<dynamic, dynamic>>(name);
  }

  /// Encola un registro médico para sincronización diferida con Control de Misión en Tierra.
  static Future<void> enqueueForEarthSync({
    required String category,
    required String recordId,
    required Map<String, dynamic> payload,
  }) async {
    if (!Hive.isBoxOpen(HiveBoxNames.syncQueue)) return;
    final queueBox = Hive.box<Map<dynamic, dynamic>>(HiveBoxNames.syncQueue);
    await queueBox.put(recordId, {
      'id': recordId,
      'category': category,
      'queuedAtIso': DateTime.now().toUtc().toIso8601String(),
      'synced': false,
      'payload': payload,
    });
  }

  /// Cantidad de paquetes de telemetría pendientes de sincronización con Tierra.
  static int pendingSyncCount() {
    if (!Hive.isBoxOpen(HiveBoxNames.syncQueue)) return 0;
    final queueBox = Hive.box<Map<dynamic, dynamic>>(HiveBoxNames.syncQueue);
    return queueBox.values.where((item) => item['synced'] != true).length;
  }
}

final pendingSyncCountProvider = StateProvider<int>((ref) {
  return HiveBootstrap.pendingSyncCount();
});
