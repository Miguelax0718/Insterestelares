import 'package:astramed/features/01_general_health/domain/scientific_criteria_engine.dart';

/// Estado operativo de un dispositivo de telemetría médica.
enum DeviceAvailabilityStatus {
  connected('Conectado'),
  disconnected('Desconectado'),
  pendingIntegration('Pendiente de integración');

  final String label;
  const DeviceAvailabilityStatus(this.label);
}

/// Información descriptiva de un sensor o equipo de monitoreo.
class TelemetryDeviceInfo {
  final String name;
  final String category;
  final DeviceAvailabilityStatus status;
  final List<String> variables;
  final double? validReadingsPercent;
  final bool isSimulated;

  const TelemetryDeviceInfo({
    required this.name,
    required this.category,
    required this.status,
    required this.variables,
    this.validReadingsPercent,
    this.isSimulated = false,
  });
}

/// Punto de serie temporal para visualización desacoplada de telemetría.
class TelemetrySamplePoint {
  final DateTime timestamp;
  final double? value;
  final ActivityContext context;
  final bool isValid;
  final String source;
  final double? signalQualityPercent;

  const TelemetrySamplePoint({
    required this.timestamp,
    required this.value,
    required this.context,
    this.isValid = true,
    required this.source,
    this.signalQualityPercent,
  });
}

/// Contrato de lectura para el panel de gráficas y disponibilidad.
///
/// Se mantiene desacoplado de la capa de ingesta/telemetría para integrarse
/// sin conflictos con el módulo de adquisición en desarrollo.
class TelemetrySeriesSnapshot {
  final List<TelemetrySamplePoint> heartRateSamples;
  final List<TelemetrySamplePoint> respiratoryRateSamples;
  final List<TelemetrySamplePoint> spO2Samples;
  final double? individualHrBaselineBpm;
  final double? individualRrBaselineRpm;
  final double? individualSpo2BaselinePercent;
  final List<TelemetryDeviceInfo> devices;

  const TelemetrySeriesSnapshot({
    required this.heartRateSamples,
    required this.respiratoryRateSamples,
    required this.spO2Samples,
    this.individualHrBaselineBpm,
    this.individualRrBaselineRpm,
    this.individualSpo2BaselinePercent,
    required this.devices,
  });

  factory TelemetrySeriesSnapshot.empty() {
    return const TelemetrySeriesSnapshot(
      heartRateSamples: [],
      respiratoryRateSamples: [],
      spO2Samples: [],
      devices: [
        TelemetryDeviceInfo(
          name: 'Bio-Monitor / AstroSkin',
          category: 'Prenda inteligente ISS (ECG, respiración, acelerometría)',
          status: DeviceAvailabilityStatus.pendingIntegration,
          variables: ['FC', 'FR', 'Actividad'],
        ),
        TelemetryDeviceInfo(
          name: 'Banda ECG / Sensor PPG',
          category: 'Alternativa de monitoreo cardíaco',
          status: DeviceAvailabilityStatus.pendingIntegration,
          variables: ['FC'],
        ),
        TelemetryDeviceInfo(
          name: 'Banda Respiratoria Torácica',
          category: 'Alternativa de ciclos respiratorios',
          status: DeviceAvailabilityStatus.pendingIntegration,
          variables: ['FR'],
        ),
        TelemetryDeviceInfo(
          name: 'Pulsioxímetro Validado',
          category: 'Oximetría de pulso (SpO₂)',
          status: DeviceAvailabilityStatus.pendingIntegration,
          variables: ['SpO₂'],
        ),
      ],
    );
  }
}
