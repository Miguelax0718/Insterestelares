import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:astramed/features/01_general_health/domain/scientific_criteria_engine.dart';
import 'package:astramed/features/01_general_health/domain/telemetry_view_contracts.dart';

/// Contexto fisiológico seleccionado para interpretar las lecturas en pantalla.
final activeActivityContextProvider = StateProvider<ActivityContext>((ref) {
  return ActivityContext.rest;
});

/// Snapshot de series temporales y disponibilidad de dispositivos.
///
/// Por defecto retorna [TelemetrySeriesSnapshot.empty] hasta que la rama de
/// telemetría conecte los flujos reales de sensores.
final telemetrySeriesSnapshotProvider = Provider<TelemetrySeriesSnapshot>((ref) {
  return TelemetrySeriesSnapshot.empty();
});
