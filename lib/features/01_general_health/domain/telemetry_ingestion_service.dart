import 'package:astramed/features/01_general_health/models/vitals_record.dart';
import 'package:astramed/features/telemetry/models/telemetry_machine.dart';

/// Flujo 1 (Sección 2.1.1): Telemetría Automática Permanente (Wearables / Multi-entorno).
class ContinuousWearableStreamRecord {
  final DateTime timestamp;
  final String astronautId;
  final int missionDay;
  final double heartRateBpm;
  final double respiratoryRateRpm;
  final double spo2Percent;
  final double bodyTempCelsius;
  final double calibratedHydrationIndex;
  final double accelerometryRmsG;
  final double hrvRmssdMs;
  final double localCo2MmHg;
  final double localO2Percent;
  final double localCh4Ppm;
  final double cabinPressureKPa;

  const ContinuousWearableStreamRecord({
    required this.timestamp,
    required this.astronautId,
    required this.missionDay,
    required this.heartRateBpm,
    required this.respiratoryRateRpm,
    required this.spo2Percent,
    required this.bodyTempCelsius,
    required this.calibratedHydrationIndex,
    required this.accelerometryRmsG,
    required this.hrvRmssdMs,
    required this.localCo2MmHg,
    required this.localO2Percent,
    required this.localCh4Ppm,
    required this.cabinPressureKPa,
  });

  factory ContinuousWearableStreamRecord.fromVitals(VitalsRecord vitals) {
    return ContinuousWearableStreamRecord(
      timestamp: vitals.timestamp,
      astronautId: vitals.astronautId,
      missionDay: vitals.missionDay,
      heartRateBpm: vitals.heartRate,
      respiratoryRateRpm: vitals.respiratoryRate,
      spo2Percent: vitals.spO2,
      bodyTempCelsius: vitals.bodyTemp,
      calibratedHydrationIndex: vitals.calibratedHydrationIndex,
      accelerometryRmsG: vitals.accelerometryRmsG,
      hrvRmssdMs: vitals.hrvRmssdMs,
      localCo2MmHg: vitals.localCo2MmHg,
      localO2Percent: vitals.localO2Percent,
      localCh4Ppm: vitals.localCh4Ppm,
      cabinPressureKPa: vitals.cabinPressureKPa,
    );
  }
}

/// Flujo 2 (Sección 2.1.2): Telemetría Automática Restringida a Estación o Base Principal.
class StationFixedTelemetryRecord {
  final DateTime timestamp;
  final String machineId;
  final String deviceName;
  final Map<String, dynamic> metrics;

  const StationFixedTelemetryRecord({
    required this.timestamp,
    required this.machineId,
    required this.deviceName,
    required this.metrics,
  });
}

/// Flujo 3 (Sección 2.2.1): Datos Manuales Periódicos y de Rutina Preventiva (POCT, QUS, SANS/PVT).
class PeriodicManualAssessmentRecord {
  final DateTime timestamp;
  final String sourceLabel;
  final double? bloodGlucoseMgDl;
  final double? capillaryRefillSeconds;
  final Map<String, dynamic> extraMetrics;

  const PeriodicManualAssessmentRecord({
    required this.timestamp,
    required this.sourceLabel,
    this.bloodGlucoseMgDl,
    this.capillaryRefillSeconds,
    this.extraMetrics = const {},
  });
}

/// Resumen estructurado de los 3 flujos de ingesta para Salud General.
class TelemetryIngestionSummary {
  final ContinuousWearableStreamRecord wearableStream;
  final List<StationFixedTelemetryRecord> stationFixedRecords;
  final List<PeriodicManualAssessmentRecord> periodicManualRecords;

  const TelemetryIngestionSummary({
    required this.wearableStream,
    required this.stationFixedRecords,
    required this.periodicManualRecords,
  });
}

/// Servicio desacoplado que separa la ingesta de Salud General en sus 3 flujos
/// arquitectónicos sin mezclar datos de sensores continuos con pruebas discretas.
class TelemetryIngestionService {
  static const Set<String> _stationFixedMachines = {
    'DEV-ARED',
    'DEV-CEVIS',
    'DEV-EPM',
    'DEV-HERA',
  };

  static const Set<String> _periodicMachines = {
    'DEV-ISTAT',
  };

  static TelemetryIngestionSummary classifyAndSummarize({
    required VitalsRecord currentVitals,
    required List<TelemetryPacket> recentPackets,
  }) {
    final wearable = ContinuousWearableStreamRecord.fromVitals(currentVitals);
    final stationList = <StationFixedTelemetryRecord>[];
    final periodicList = <PeriodicManualAssessmentRecord>[];

    if (currentVitals.source == 'manual') {
      periodicList.add(
        PeriodicManualAssessmentRecord(
          timestamp: currentVitals.timestamp,
          sourceLabel: currentVitals.device,
          bloodGlucoseMgDl: currentVitals.bloodGlucose,
          capillaryRefillSeconds: currentVitals.capillaryRefillSeconds,
        ),
      );
    }

    for (final packet in recentPackets) {
      if (packet.astronautId != currentVitals.astronautId) continue;
      if (_stationFixedMachines.contains(packet.machineId)) {
        stationList.add(
          StationFixedTelemetryRecord(
            timestamp: packet.timestamp,
            machineId: packet.machineId,
            deviceName: packet.device.isNotEmpty ? packet.device : packet.machineId,
            metrics: packet.metrics,
          ),
        );
      } else if (_periodicMachines.contains(packet.machineId) ||
          packet.source == 'manual') {
        periodicList.add(
          PeriodicManualAssessmentRecord(
            timestamp: packet.timestamp,
            sourceLabel: packet.device.isNotEmpty ? packet.device : packet.machineId,
            bloodGlucoseMgDl: (packet.metrics['bloodGlucose'] as num?)?.toDouble(),
            extraMetrics: packet.metrics,
          ),
        );
      }
    }

    return TelemetryIngestionSummary(
      wearableStream: wearable,
      stationFixedRecords: stationList,
      periodicManualRecords: periodicList,
    );
  }
}
