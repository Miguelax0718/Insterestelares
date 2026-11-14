import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:astramed/features/01_general_health/domain/scientific_criteria_engine.dart';
import 'package:astramed/features/01_general_health/domain/telemetry_view_contracts.dart';
import 'package:astramed/features/crew/presentation/providers/crew_provider.dart';
import 'package:astramed/features/telemetry/models/telemetry_machine.dart';
import 'package:astramed/features/telemetry/presentation/providers/telemetry_provider.dart';

/// Mapea el `activityState` de telemetría hacia [ActivityContext] del motor científico.
ActivityContext mapActivityStateToContext(String activityState) {
  switch (activityState) {
    case 'sleep':
      return ActivityContext.sleep;
    case 'resting':
      return ActivityContext.rest;
    case 'exercise':
    case 'post_eva':
    case 'active_duty':
      return ActivityContext.physicalActivity;
    default:
      return ActivityContext.unknown;
  }
}

/// Extrae el porcentaje numérico de cadenas como `'optimal (98%)'` o `'good (89%)'`.
double? parseSignalQualityPercent(String signalQuality) {
  final match = RegExp(r'(\d+(?:\.\d+)?)\s*%').firstMatch(signalQuality);
  if (match == null) return null;
  return double.tryParse(match.group(1)!);
}

/// Contexto fisiológico seleccionado manualmente (si es `null`, se usa el
/// contexto reportado por `vitals.activityState` del astronauta activo).
final manualActivityContextOverrideProvider = StateProvider<ActivityContext?>((ref) {
  return null;
});

/// Snapshot de series temporales y disponibilidad de dispositivos conectado
/// al estado real de [telemetryProvider] y al astronauta activo.
final telemetrySeriesSnapshotProvider = Provider<TelemetrySeriesSnapshot>((ref) {
  final astronaut = ref.watch(selectedAstronautProvider);
  final telemetryState = ref.watch(telemetryProvider);

  final devices = telemetryState.machines.map((machine) {
    final machineStatus = machine.statusFor(astronaut.id);
    final DeviceAvailabilityStatus availability;
    switch (machineStatus) {
      case MachineConnectionStatus.connected:
      case MachineConnectionStatus.streaming:
        availability = DeviceAvailabilityStatus.connected;
      case MachineConnectionStatus.disconnected:
      case MachineConnectionStatus.connecting:
      case MachineConnectionStatus.error:
        availability = DeviceAvailabilityStatus.disconnected;
    }

    final lastPacket = machine.lastPacketByAstronaut[astronaut.id];
    final validPercent = lastPacket != null
        ? parseSignalQualityPercent(lastPacket.signalQuality)
        : null;

    return TelemetryDeviceInfo(
      name: machine.name,
      category: '${machine.code} • ${machine.protocol}',
      status: availability,
      variables: machine.supportedMetrics,
      validReadingsPercent: validPercent,
    );
  }).toList();

  final astronautPackets = telemetryState.recentLogs
      .where((p) => p.astronautId == astronaut.id)
      .toList()
      .reversed
      .toList();

  final hrSamples = <TelemetrySamplePoint>[];
  final rrSamples = <TelemetrySamplePoint>[];
  final spo2Samples = <TelemetrySamplePoint>[];

  for (final packet in astronautPackets) {
    final ctx = mapActivityStateToContext(packet.activityState);
    final quality = parseSignalQualityPercent(packet.signalQuality);
    final isValid = quality == null || quality >= 60.0;
    final sourceLabel = packet.device.isNotEmpty ? packet.device : packet.machineId;

    final hr = (packet.metrics['heartRate'] as num?)?.toDouble();
    if (hr != null) {
      hrSamples.add(TelemetrySamplePoint(
        timestamp: packet.timestamp,
        value: hr,
        context: ctx,
        isValid: isValid,
        source: sourceLabel,
        signalQualityPercent: quality,
      ));
    }

    final rr = (packet.metrics['respiratoryRate'] as num?)?.toDouble();
    if (rr != null) {
      rrSamples.add(TelemetrySamplePoint(
        timestamp: packet.timestamp,
        value: rr,
        context: ctx,
        isValid: isValid,
        source: sourceLabel,
        signalQualityPercent: quality,
      ));
    }

    final spo2 = (packet.metrics['spO2'] as num?)?.toDouble();
    if (spo2 != null) {
      spo2Samples.add(TelemetrySamplePoint(
        timestamp: packet.timestamp,
        value: spo2,
        context: ctx,
        isValid: isValid,
        source: sourceLabel,
        signalQualityPercent: quality,
      ));
    }
  }

  return TelemetrySeriesSnapshot(
    heartRateSamples: hrSamples,
    respiratoryRateSamples: rrSamples,
    spO2Samples: spo2Samples,
    devices: devices,
  );
});
