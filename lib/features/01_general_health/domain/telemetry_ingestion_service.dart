import 'scientific_criteria_engine.dart';
import 'telemetry_view_contracts.dart';

/// Resumen unificado de ingesta y clasificación multi-fuente (wearable pasivo,
/// estación fija y evaluación periódica manual) listo para consumo por Apolo.
class TelemetryIngestionSummary {
  final DateTime generatedAt;
  final String astronautId;
  final SpaceOperationalEnvironment environment;
  final PassiveDimensionEvaluation passiveEvaluation;
  final List<TelemetryDeviceInfo> activeDevices;
  final Map<String, TelemetrySeriesSnapshot> seriesSnapshots;
  final List<String> environmentalFlags;
  final int criticalAlertCount;
  final int contextualWarningCount;

  const TelemetryIngestionSummary({
    required this.generatedAt,
    required this.astronautId,
    required this.environment,
    required this.passiveEvaluation,
    required this.activeDevices,
    required this.seriesSnapshots,
    required this.environmentalFlags,
    required this.criticalAlertCount,
    required this.contextualWarningCount,
  });

  Map<String, dynamic> toJson() => {
        'generated_at': generatedAt.toIso8601String(),
        'astronaut_id': astronautId,
        'environment': environment.name,
        'critical_alert_count': criticalAlertCount,
        'contextual_warning_count': contextualWarningCount,
        'environmental_flags': environmentalFlags,
        'active_devices': activeDevices.map((d) => d.toJson()).toList(),
        'series_snapshots': seriesSnapshots.map((k, v) => MapEntry(k, v.toJson())),
        'passive_evaluation': passiveEvaluation.toJson(),
      };
}

/// Servicio de clasificación y agregación Offline-First de flujos biométricos
/// permanentes across las 4 dimensiones fisiológicas.
class TelemetryIngestionService {
  final ScientificCriteriaEngine criteriaEngine;

  const TelemetryIngestionService({
    this.criteriaEngine = const ScientificCriteriaEngine(),
  });

  static const List<TelemetryDeviceInfo> defaultWearableCatalog = [
    TelemetryDeviceInfo(
      deviceId: 'DEV-BIOMONITOR',
      name: 'Bio-Monitor (CSA) / CARDIOBREATH',
      dimension: PassiveHealthDimension.cardiorespiratoryMetabolic,
      hardwareReference: 'ECG parches secos, PPG multi-longitud y bandas torácicas inductivas',
      samplingFrequency: '250 Hz ECG / 50 Hz Respiración',
      accuracyEstimate: '95%-98% reposo / 88%-92% ejercicio',
      status: DeviceAvailabilityStatus.connected,
    ),
    TelemetryDeviceInfo(
      deviceId: 'DEV-DRAEGER-HF',
      name: 'Draeger Double Sensor (Heat-Flux)',
      dimension: PassiveHealthDimension.cardiorespiratoryMetabolic,
      hardwareReference: 'Sensor no invasivo de flujo de calor cutáneo frontal (DLR/NASA)',
      samplingFrequency: '1 Hz continuo',
      accuracyEstimate: '96%-98% (error < ±0.2 °C)',
      status: DeviceAvailabilityStatus.connected,
    ),
    TelemetryDeviceInfo(
      deviceId: 'DEV-BODYSTAT-BIS',
      name: 'Parches BIS Multifrecuencia (Bodystat)',
      dimension: PassiveHealthDimension.cardiorespiratoryMetabolic,
      hardwareReference: 'Espectroscopia de bioimpedancia corporal total y muscular localizada',
      samplingFrequency: 'Cada 15 min pasivo',
      accuracyEstimate: '90%-94% TBW / 93%-96% volumen muscular',
      status: DeviceAvailabilityStatus.connected,
    ),
    TelemetryDeviceInfo(
      deviceId: 'DEV-NEURO-EYE',
      name: 'Tobii Pro / NeurOptics VIP-200 + Sensor ToF',
      dimension: PassiveHealthDimension.neurologicalSensory,
      hardwareReference: 'Pupilometría IR pasiva + Sensor óptico Time-of-Flight + PVT-B OS',
      samplingFrequency: '60-120 Hz ocular / fondo SO continuo',
      accuracyEstimate: '96%-98% pupila / 95%-99% ToF (+0.50 a +1.75 D) / >95% PVT-B',
      status: DeviceAvailabilityStatus.connected,
    ),
    TelemetryDeviceInfo(
      deviceId: 'DEV-IMU-MUSCLE',
      name: 'Sensores IMU Triaxiales + Bioimpedancia Cuádriceps',
      dimension: PassiveHealthDimension.musculoskeletal,
      hardwareReference: 'IMU pulsera/tobillo/traje EVA + parches dermales cuádriceps/gastrocnemio',
      samplingFrequency: '100 Hz triaxial / cada 30 min BIS muscular',
      accuracyEstimate: '95%-98% actividad e impacto / 93%-96% atrofia',
      status: DeviceAvailabilityStatus.connected,
    ),
    TelemetryDeviceInfo(
      deviceId: 'DEV-ACTIGRAPH-SLEEP',
      name: 'Actígrafo Médico + Holter Nocturno Integrado',
      dimension: PassiveHealthDimension.circadianPsychoemotional,
      hardwareReference: 'Actigrafía muñeca + ECG/SpO2/Banda respiratoria en ventana nocturna',
      samplingFrequency: '30 s épocas actigráficas / continuo nocturno',
      accuracyEstimate: '90%-95% vs. PSG en duración/fragmentación / 95%-98% HRV nocturna',
      status: DeviceAvailabilityStatus.connected,
    ),
  ];

  TelemetryIngestionSummary classifyAndSummarize({
    required List<ContinuousWearableStreamRecord> wearableStream,
    StationFixedTelemetryRecord? fixedTelemetry,
    PeriodicManualAssessmentRecord? periodicAssessment,
  }) {
    if (wearableStream.isEmpty) {
      throw ArgumentError('wearableStream no puede estar vacío.');
    }

    final latest = wearableStream.last;
    final vitals = latest.toVitalsRecord(
      systolicBP: periodicAssessment?.systolicBP ?? 118.0,
      diastolicBP: periodicAssessment?.diastolicBP ?? 76.0,
      bloodGlucose: periodicAssessment?.bloodGlucoseMgDl ?? 92.0,
    );

    final passiveEval = criteriaEngine.evaluateAllPassiveDimensions(
      vitals: vitals,
      sleepHours: latest.sleepDurationHours,
      context: latest.activityContext,
      inMicrogravity: latest.environment.isMicrogravity,
      signalQualityPercent: latest.signalQualityPercent,
      muscleStrengthRetentionPercent:
          periodicAssessment?.muscleStrengthRetentionPercent ?? 92.0,
    );

    final envFlags = <String>[];
    if (fixedTelemetry != null) {
      if (fixedTelemetry.co2Warning) {
        envFlags.add(
          'PPCO2 elevado en ${fixedTelemetry.moduleId}: ${fixedTelemetry.ppCo2MmHg.toStringAsFixed(2)} mmHg (>= 3.0 mmHg)',
        );
      }
      if (fixedTelemetry.o2Warning) {
        envFlags.add(
          'O2 fuera de banda nominal en ${fixedTelemetry.moduleId}: ${fixedTelemetry.o2Percent.toStringAsFixed(1)}%',
        );
      }
      if (fixedTelemetry.pressureWarning) {
        envFlags.add(
          'Presión de cabina atípica en ${fixedTelemetry.moduleId}: ${fixedTelemetry.cabinPressureKPa.toStringAsFixed(1)} kPa',
        );
      }
      if (fixedTelemetry.radiationRateMSvPerHour >= 1.0) {
        envFlags.add(
          'Tasa de radiación espacial elevada en ${fixedTelemetry.moduleId}: ${fixedTelemetry.radiationRateMSvPerHour.toStringAsFixed(2)} mSv/h',
        );
      }
    }

    if (periodicAssessment != null &&
        periodicAssessment.opticNerveSheathDiameterMm >= 5.5) {
      envFlags.add(
        'Ecografía ONSD elevada (${periodicAssessment.opticNerveSheathDiameterMm.toStringAsFixed(1)} mm >= 5.5 mm): sospecha de hipertensión intracraneal / SANS',
      );
    }

    final series = <String, TelemetrySeriesSnapshot>{
      'heart_rate': _buildSnapshot(
        'heart_rate',
        'lpm',
        wearableStream,
        (r) => r.heartRateBpm,
      ),
      'hrv_rmssd': _buildSnapshot(
        'hrv_rmssd',
        'ms',
        wearableStream,
        (r) => r.hrvRmssdMs,
      ),
      'spo2': _buildSnapshot(
        'spo2',
        '%',
        wearableStream,
        (r) => r.spo2Percent,
      ),
      'core_temp_heat_flux': _buildSnapshot(
        'core_temp_heat_flux',
        '°C',
        wearableStream,
        (r) => r.coreTempHeatFluxC,
      ),
      'pupillometry_npi': _buildSnapshot(
        'pupillometry_npi',
        'NPi',
        wearableStream,
        (r) => r.pupillometryNpi,
      ),
      'passive_pvt_reaction_ms': _buildSnapshot(
        'passive_pvt_reaction_ms',
        'ms',
        wearableStream,
        (r) => r.passivePvtReactionMs,
      ),
      'peak_impact_g': _buildSnapshot(
        'peak_impact_g',
        'g',
        wearableStream,
        (r) => r.peakImpactG,
      ),
      'nocturnal_hrv_rmssd': _buildSnapshot(
        'nocturnal_hrv_rmssd',
        'ms',
        wearableStream,
        (r) => r.nocturnalHrvRmssdMs,
      ),
    };

    final criticalCount = passiveEval.results
        .where((r) => r.severity == EvaluationSeverity.clinicalAttention)
        .length;
    final warningCount = passiveEval.results
        .where((r) => r.severity == EvaluationSeverity.contextualWarning)
        .length;

    return TelemetryIngestionSummary(
      generatedAt: DateTime.now().toUtc(),
      astronautId: latest.astronautId,
      environment: latest.environment,
      passiveEvaluation: passiveEval,
      activeDevices: defaultWearableCatalog,
      seriesSnapshots: series,
      environmentalFlags: envFlags,
      criticalAlertCount: criticalCount,
      contextualWarningCount: warningCount,
    );
  }

  TelemetrySeriesSnapshot _buildSnapshot(
    String key,
    String unit,
    List<ContinuousWearableStreamRecord> stream,
    double Function(ContinuousWearableStreamRecord) selector,
  ) {
    double sum = 0.0;
    double qSum = 0.0;
    double minVal = double.infinity;
    double maxVal = double.negativeInfinity;

    for (final item in stream) {
      final v = selector(item);
      sum += v;
      qSum += item.signalQualityPercent;
      if (v < minVal) minVal = v;
      if (v > maxVal) maxVal = v;
    }

    return TelemetrySeriesSnapshot(
      metricKey: key,
      unit: unit,
      latestValue: selector(stream.last),
      meanValue: sum / stream.length,
      minValue: minVal,
      maxValue: maxVal,
      sampleCount: stream.length,
      meanSignalQualityPercent: qSum / stream.length,
    );
  }
}
