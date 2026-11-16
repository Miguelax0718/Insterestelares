import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../constants/medical_thresholds.dart';
import '../../storage/hive_bootstrap.dart';

/// Parámetros de calibración óptica y antropométrica del astronauta y la pantalla.
///
/// Resuelve las limitaciones físicas de medición en dispositivos heterogéneos:
/// - `pixelsPerMm`: calibrado con una tarjeta estándar ID-1 (85.60 x 53.98 mm).
/// - `focalLengthPx`: longitud focal equivalente en píxeles de la cámara frontal.
/// - `crewIpdMm`: distancia interpupilar basal del astronauta (medida en pre-vuelo).
/// - `baselineNearPointCm`: punto cercano basal del astronauta antes de la misión.
class DeviceCalibration {
  static const double id1CardWidthMm = 85.60;
  static const double id1CardHeightMm = 53.98;

  final double pixelsPerMm;
  final double focalLengthPx;
  final double crewIpdMm;
  final double baselineNearPointCm;
  final double baselineGreenRedRatio;

  const DeviceCalibration({
    this.pixelsPerMm = 6.3, // ~160 DPI lógico por defecto
    this.focalLengthPx = 580.0, // Cámara frontal estándar a 640x480
    this.crewIpdMm = MedicalThresholds.defaultCrewIpdMm,
    this.baselineNearPointCm = MedicalThresholds.defaultNearPointBaselineCm,
    this.baselineGreenRedRatio = 0.88,
  });

  /// Calcula `pixelsPerMm` a partir del ancho en píxeles lógicos que el usuario
  /// ajustó en pantalla para igualar una tarjeta estándar ID-1 (85.60 mm).
  factory DeviceCalibration.fromId1CardWidthPx({
    required double cardWidthLogicalPx,
    required DeviceCalibration current,
  }) {
    final computedPxPerMm = (cardWidthLogicalPx / id1CardWidthMm).clamp(2.0, 20.0);
    return current.copyWith(pixelsPerMm: computedPxPerMm);
  }

  /// Calibra la longitud focal en píxeles (`f_px = ipd_px * d_mm / ipd_mm`)
  /// cuando el astronauta sostiene el dispositivo a una distancia conocida (ej. 2 tarjetas = 171.2 mm o 300 mm).
  DeviceCalibration calibrateFocalLength({
    required double measuredIpdPx,
    required double knownDistanceCm,
  }) {
    if (measuredIpdPx <= 0 || knownDistanceCm <= 0) return this;
    final distanceMm = knownDistanceCm * 10.0;
    final fPx = (measuredIpdPx * distanceMm / crewIpdMm).clamp(200.0, 2500.0);
    return copyWith(focalLengthPx: fPx);
  }

  DeviceCalibration copyWith({
    double? pixelsPerMm,
    double? focalLengthPx,
    double? crewIpdMm,
    double? baselineNearPointCm,
    double? baselineGreenRedRatio,
  }) {
    return DeviceCalibration(
      pixelsPerMm: pixelsPerMm ?? this.pixelsPerMm,
      focalLengthPx: focalLengthPx ?? this.focalLengthPx,
      crewIpdMm: crewIpdMm ?? this.crewIpdMm,
      baselineNearPointCm: baselineNearPointCm ?? this.baselineNearPointCm,
      baselineGreenRedRatio: baselineGreenRedRatio ?? this.baselineGreenRedRatio,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'pixelsPerMm': pixelsPerMm,
      'focalLengthPx': focalLengthPx,
      'crewIpdMm': crewIpdMm,
      'baselineNearPointCm': baselineNearPointCm,
      'baselineGreenRedRatio': baselineGreenRedRatio,
    };
  }

  factory DeviceCalibration.fromMap(Map<dynamic, dynamic> map) {
    return DeviceCalibration(
      pixelsPerMm: (map['pixelsPerMm'] as num?)?.toDouble() ?? 6.3,
      focalLengthPx: (map['focalLengthPx'] as num?)?.toDouble() ?? 580.0,
      crewIpdMm: (map['crewIpdMm'] as num?)?.toDouble() ??
          MedicalThresholds.defaultCrewIpdMm,
      baselineNearPointCm: (map['baselineNearPointCm'] as num?)?.toDouble() ??
          MedicalThresholds.defaultNearPointBaselineCm,
      baselineGreenRedRatio:
          (map['baselineGreenRedRatio'] as num?)?.toDouble() ?? 0.88,
    );
  }
}

class DeviceCalibrationNotifier extends StateNotifier<DeviceCalibration> {
  static const String _recordKey = 'active_crew_calibration';

  DeviceCalibrationNotifier() : super(const DeviceCalibration()) {
    _loadFromHive();
  }

  void _loadFromHive() {
    if (!Hive.isBoxOpen(HiveBoxNames.deviceCalibration)) return;
    final box = HiveBootstrap.box(HiveBoxNames.deviceCalibration);
    final saved = box.get(_recordKey);
    if (saved != null) {
      state = DeviceCalibration.fromMap(saved);
    }
  }

  Future<void> updateCalibration(DeviceCalibration updated) async {
    state = updated;
    if (!Hive.isBoxOpen(HiveBoxNames.deviceCalibration)) return;
    final box = HiveBootstrap.box(HiveBoxNames.deviceCalibration);
    await box.put(_recordKey, updated.toMap());
  }
}

final deviceCalibrationProvider =
    StateNotifierProvider<DeviceCalibrationNotifier, DeviceCalibration>((ref) {
  return DeviceCalibrationNotifier();
});
