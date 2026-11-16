import '../models/vitals_record.dart';
import 'scientific_criteria_engine.dart';

/// Disponibilidad del hardware biométrico o sensor pasivo en el entorno de misión.
enum DeviceAvailabilityStatus {
  connected('Conectado / Adquisición continua'),
  intermittent('Señal intermitente / Interferencia'),
  disconnected('Desconectado'),
  notAvailable('No disponible / Modo offline'),
  disabledByCrew('Deshabilitado por tripulación');

  final String label;
  const DeviceAvailabilityStatus(this.label);
}

/// Entorno operacional donde se captura la telemetría del astronauta.
enum SpaceOperationalEnvironment {
  spacecraftTransit('Nave espacial en tránsito (0 g)'),
  spaceStation('Estación Espacial (ISS / Orbital)'),
  planetarySurfaceBase('Base Planetaria / Lunar (gravedad parcial)'),
  pressurizedRover('Rover Presurizado de Exploración'),
  extravehicularSuit('Traje Presurizado EVA');

  final String label;
  const SpaceOperationalEnvironment(this.label);

  bool get isMicrogravity =>
      this == SpaceOperationalEnvironment.spacecraftTransit ||
      this == SpaceOperationalEnvironment.spaceStation;

  static SpaceOperationalEnvironment fromString(String raw) {
    final norm = raw.trim().toLowerCase();
    switch (norm) {
      case 'spacecraft_transit':
      case 'transit':
      case 'nave':
        return SpaceOperationalEnvironment.spacecraftTransit;
      case 'planetary_base':
      case 'planetary_surface_base':
      case 'lunar':
      case 'mars':
      case 'base':
        return SpaceOperationalEnvironment.planetarySurfaceBase;
      case 'rover':
      case 'pressurized_rover':
        return SpaceOperationalEnvironment.pressurizedRover;
      case 'eva':
      case 'extravehicular_suit':
        return SpaceOperationalEnvironment.extravehicularSuit;
      case 'space_station':
      case 'iss':
      default:
        return SpaceOperationalEnvironment.spaceStation;
    }
  }
}

/// Ficha técnica de un sensor biométrico portátil o fijo integrado en AstraMed.
class TelemetryDeviceInfo {
  final String deviceId;
  final String name;
  final PassiveHealthDimension dimension;
  final String hardwareReference;
  final String samplingFrequency;
  final String accuracyEstimate;
  final DeviceAvailabilityStatus status;

  const TelemetryDeviceInfo({
    required this.deviceId,
    required this.name,
    required this.dimension,
    required this.hardwareReference,
    required this.samplingFrequency,
    required this.accuracyEstimate,
    required this.status,
  });

  Map<String, dynamic> toJson() => {
        'device_id': deviceId,
        'name': name,
        'dimension': dimension.id,
        'hardware_reference': hardwareReference,
        'sampling_frequency': samplingFrequency,
        'accuracy_estimate': accuracyEstimate,
        'status': status.name,
      };
}

/// Punto individual de una serie temporal de telemetría.
class TelemetrySamplePoint {
  final DateTime timestamp;
  final double value;
  final String unit;
  final ActivityContext context;
  final double signalQualityPercent;

  const TelemetrySamplePoint({
    required this.timestamp,
    required this.value,
    required this.unit,
    required this.context,
    this.signalQualityPercent = 97.0,
  });

  Map<String, dynamic> toJson() => {
        'timestamp': timestamp.toIso8601String(),
        'value': value,
        'unit': unit,
        'context': context.name,
        'signal_quality_percent': signalQualityPercent,
      };
}

/// Instantánea estadística de una serie temporal biométrica.
class TelemetrySeriesSnapshot {
  final String metricKey;
  final String unit;
  final double latestValue;
  final double meanValue;
  final double minValue;
  final double maxValue;
  final int sampleCount;
  final double meanSignalQualityPercent;

  const TelemetrySeriesSnapshot({
    required this.metricKey,
    required this.unit,
    required this.latestValue,
    required this.meanValue,
    required this.minValue,
    required this.maxValue,
    required this.sampleCount,
    required this.meanSignalQualityPercent,
  });

  Map<String, dynamic> toJson() => {
        'metric_key': metricKey,
        'unit': unit,
        'latest_value': latestValue,
        'mean_value': meanValue,
        'min_value': minValue,
        'max_value': maxValue,
        'sample_count': sampleCount,
        'mean_signal_quality_percent': meanSignalQualityPercent,
      };
}

/// Flujo continuo automático permanente emitido por sensores portátiles/vestibles
/// a través de las 4 dimensiones fisiológicas.
class ContinuousWearableStreamRecord {
  final DateTime timestamp;
  final String astronautId;
  final SpaceOperationalEnvironment environment;
  final ActivityContext activityContext;
  final double signalQualityPercent;

  // Dimensión 1: Cardiorrespiratoria y Metabólica
  final double heartRateBpm;
  final double hrvRmssdMs;
  final double hrvSdnnMs;
  final double respiratoryRateRpm;
  final double spo2Percent;
  final double coreTempHeatFluxC;
  final double rawHydrationBisPercent;
  final int missionDay;

  // Dimensión 2: Neurológica y Sensorial
  final double pupilDiameterMm;
  final double pupillometryNpi;
  final double plrLatencyMs;
  final double blinkRatePerMin;
  final double microsaccadeVelocityDegPerSec;
  final double passiveNearFocusCm;
  final double estimatedHyperopicShiftDiopters;
  final double passivePvtReactionMs;
  final int passivePvtLapsesCount;
  final double touchPointerAccuracyPercent;

  // Dimensión 3: Musculoesquelética
  final double accelerometryRmsG;
  final double peakImpactG;
  final double strideCadenceStepsPerMin;
  final double muscleVolumeRetentionPercent;
  final double pennationAngleDeg;

  // Dimensión 4: Circadiana y Psicoemocional Nocturna
  final double sleepDurationHours;
  final double sleepEfficiencyPercent;
  final double sleepFragmentationIndex;
  final double sleepRegularityIndex;
  final double nocturnalHrvRmssdMs;
  final double nocturnalHrvSdnnMs;
  final double nocturnalHeartRateMeanBpm;
  final double nocturnalRespiratoryRateMeanRpm;
  final double nocturnalSpO2MeanPercent;
  final int nocturnalDesaturationEvents;

  const ContinuousWearableStreamRecord({
    required this.timestamp,
    required this.astronautId,
    required this.environment,
    required this.activityContext,
    this.signalQualityPercent = 97.0,
    required this.heartRateBpm,
    required this.hrvRmssdMs,
    this.hrvSdnnMs = 68.0,
    required this.respiratoryRateRpm,
    required this.spo2Percent,
    this.coreTempHeatFluxC = 36.6,
    this.rawHydrationBisPercent = 78.0,
    this.missionDay = 18,
    this.pupilDiameterMm = 3.8,
    this.pupillometryNpi = 4.2,
    this.plrLatencyMs = 210.0,
    this.blinkRatePerMin = 15.0,
    this.microsaccadeVelocityDegPerSec = 42.0,
    this.passiveNearFocusCm = 30.0,
    this.estimatedHyperopicShiftDiopters = 0.0,
    this.passivePvtReactionMs = 255.0,
    this.passivePvtLapsesCount = 0,
    this.touchPointerAccuracyPercent = 96.5,
    this.accelerometryRmsG = 0.024,
    this.peakImpactG = 0.15,
    this.strideCadenceStepsPerMin = 0.0,
    this.muscleVolumeRetentionPercent = 94.0,
    this.pennationAngleDeg = 14.5,
    this.sleepDurationHours = 7.5,
    this.sleepEfficiencyPercent = 91.0,
    this.sleepFragmentationIndex = 8.5,
    this.sleepRegularityIndex = 88.0,
    this.nocturnalHrvRmssdMs = 62.0,
    this.nocturnalHrvSdnnMs = 74.0,
    this.nocturnalHeartRateMeanBpm = 56.0,
    this.nocturnalRespiratoryRateMeanRpm = 13.5,
    this.nocturnalSpO2MeanPercent = 97.5,
    this.nocturnalDesaturationEvents = 0,
  });

  factory ContinuousWearableStreamRecord.fromVitals(
    VitalsRecord vitals, {
    SpaceOperationalEnvironment environment = SpaceOperationalEnvironment.spaceStation,
    double sleepDurationHours = 7.5,
    double signalQualityPercent = 97.0,
  }) {
    return ContinuousWearableStreamRecord(
      timestamp: vitals.timestamp,
      astronautId: vitals.astronautId,
      environment: environment,
      activityContext: ActivityContext.fromString(vitals.activityState),
      signalQualityPercent: signalQualityPercent,
      heartRateBpm: vitals.heartRate,
      hrvRmssdMs: vitals.hrvRmssdMs,
      hrvSdnnMs: vitals.hrvSdnnMs,
      respiratoryRateRpm: vitals.respiratoryRate,
      spo2Percent: vitals.spO2,
      coreTempHeatFluxC: vitals.coreTempHeatFluxC,
      rawHydrationBisPercent: vitals.hydrationBioimpedanceIndex,
      missionDay: vitals.missionDay,
      pupilDiameterMm: vitals.pupilDiameterMm,
      pupillometryNpi: vitals.pupillometryNpi,
      plrLatencyMs: vitals.plrLatencyMs,
      blinkRatePerMin: vitals.blinkRatePerMin,
      microsaccadeVelocityDegPerSec: vitals.microsaccadeVelocityDegPerSec,
      passiveNearFocusCm: vitals.passiveNearFocusCm,
      estimatedHyperopicShiftDiopters: vitals.estimatedHyperopicShiftDiopters,
      passivePvtReactionMs: vitals.passivePvtReactionMs,
      passivePvtLapsesCount: vitals.passivePvtLapsesCount,
      touchPointerAccuracyPercent: vitals.touchPointerAccuracyPercent,
      accelerometryRmsG: vitals.accelerometryRmsG,
      peakImpactG: vitals.peakImpactG,
      strideCadenceStepsPerMin: vitals.strideCadenceStepsPerMin,
      muscleVolumeRetentionPercent: vitals.muscleVolumeRetentionPercent,
      pennationAngleDeg: vitals.pennationAngleDeg,
      sleepDurationHours: sleepDurationHours,
      sleepEfficiencyPercent: vitals.sleepEfficiencyPercent,
      sleepFragmentationIndex: vitals.sleepFragmentationIndex,
      sleepRegularityIndex: vitals.sleepRegularityIndex,
      nocturnalHrvRmssdMs: vitals.nocturnalHrvRmssdMs,
      nocturnalHrvSdnnMs: vitals.nocturnalHrvSdnnMs,
      nocturnalHeartRateMeanBpm: vitals.nocturnalHeartRateMeanBpm,
      nocturnalRespiratoryRateMeanRpm: vitals.nocturnalRespiratoryRateMeanRpm,
      nocturnalSpO2MeanPercent: vitals.nocturnalSpO2MeanPercent,
      nocturnalDesaturationEvents: vitals.nocturnalDesaturationEvents,
    );
  }

  VitalsRecord toVitalsRecord({
    double systolicBP = 118.0,
    double diastolicBP = 76.0,
    double bloodGlucose = 92.0,
  }) {
    return VitalsRecord(
      timestamp: timestamp,
      astronautId: astronautId,
      heartRate: heartRateBpm,
      systolicBP: systolicBP,
      diastolicBP: diastolicBP,
      spO2: spo2Percent,
      bodyTemp: coreTempHeatFluxC,
      bloodGlucose: bloodGlucose,
      respiratoryRate: respiratoryRateRpm,
      activityState: activityContext.name,
      signalQuality: 'optimal (${signalQualityPercent.toStringAsFixed(0)}%)',
      missionDay: missionDay,
      hrvRmssdMs: hrvRmssdMs,
      hrvSdnnMs: hrvSdnnMs,
      coreTempHeatFluxC: coreTempHeatFluxC,
      hydrationBioimpedanceIndex: rawHydrationBisPercent,
      pupilDiameterMm: pupilDiameterMm,
      pupillometryNpi: pupillometryNpi,
      plrLatencyMs: plrLatencyMs,
      blinkRatePerMin: blinkRatePerMin,
      microsaccadeVelocityDegPerSec: microsaccadeVelocityDegPerSec,
      passiveNearFocusCm: passiveNearFocusCm,
      estimatedHyperopicShiftDiopters: estimatedHyperopicShiftDiopters,
      passivePvtReactionMs: passivePvtReactionMs,
      passivePvtLapsesCount: passivePvtLapsesCount,
      touchPointerAccuracyPercent: touchPointerAccuracyPercent,
      accelerometryRmsG: accelerometryRmsG,
      peakImpactG: peakImpactG,
      strideCadenceStepsPerMin: strideCadenceStepsPerMin,
      muscleVolumeRetentionPercent: muscleVolumeRetentionPercent,
      pennationAngleDeg: pennationAngleDeg,
      sleepEfficiencyPercent: sleepEfficiencyPercent,
      sleepFragmentationIndex: sleepFragmentationIndex,
      sleepRegularityIndex: sleepRegularityIndex,
      nocturnalHrvRmssdMs: nocturnalHrvRmssdMs,
      nocturnalHrvSdnnMs: nocturnalHrvSdnnMs,
      nocturnalHeartRateMeanBpm: nocturnalHeartRateMeanBpm,
      nocturnalRespiratoryRateMeanRpm: nocturnalRespiratoryRateMeanRpm,
      nocturnalSpO2MeanPercent: nocturnalSpO2MeanPercent,
      nocturnalDesaturationEvents: nocturnalDesaturationEvents,
    );
  }
}

/// Telemetría fija ambiental de módulo / nave / rover / base presurizada.
class StationFixedTelemetryRecord {
  final DateTime timestamp;
  final String moduleId;
  final double ppCo2MmHg;
  final double o2Percent;
  final double cabinPressureKPa;
  final double ambientTempC;
  final double radiationRateMSvPerHour;

  const StationFixedTelemetryRecord({
    required this.timestamp,
    required this.moduleId,
    required this.ppCo2MmHg,
    required this.o2Percent,
    required this.cabinPressureKPa,
    required this.ambientTempC,
    required this.radiationRateMSvPerHour,
  });

  bool get co2Warning => ppCo2MmHg >= 3.0;
  bool get o2Warning => o2Percent < 19.5 || o2Percent > 23.5;
  bool get pressureWarning => cabinPressureKPa < 96.0 || cabinPressureKPa > 104.0;

  Map<String, dynamic> toJson() => {
        'timestamp': timestamp.toIso8601String(),
        'module_id': moduleId,
        'pp_co2_mmhg': ppCo2MmHg,
        'o2_percent': o2Percent,
        'cabin_pressure_kpa': cabinPressureKPa,
        'ambient_temp_c': ambientTempC,
        'radiation_rate_msv_h': radiationRateMSvPerHour,
        'co2_warning': co2Warning,
        'o2_warning': o2Warning,
        'pressure_warning': pressureWarning,
      };
}

/// Evaluaciones periódicas manuales o semiautomáticas (SANS ultrasonido, dinamometría, presión arterial).
class PeriodicManualAssessmentRecord {
  final DateTime timestamp;
  final String astronautId;
  final double systolicBP;
  final double diastolicBP;
  final double bloodGlucoseMgDl;
  final double muscleStrengthRetentionPercent;
  final double opticNerveSheathDiameterMm;
  final bool comparableBaselineProtocol;

  const PeriodicManualAssessmentRecord({
    required this.timestamp,
    required this.astronautId,
    required this.systolicBP,
    required this.diastolicBP,
    required this.bloodGlucoseMgDl,
    required this.muscleStrengthRetentionPercent,
    this.opticNerveSheathDiameterMm = 4.6,
    this.comparableBaselineProtocol = true,
  });

  Map<String, dynamic> toJson() => {
        'timestamp': timestamp.toIso8601String(),
        'astronaut_id': astronautId,
        'systolic_bp': systolicBP,
        'diastolic_bp': diastolicBP,
        'blood_glucose_mg_dl': bloodGlucoseMgDl,
        'muscle_strength_retention_percent': muscleStrengthRetentionPercent,
        'optic_nerve_sheath_diameter_mm': opticNerveSheathDiameterMm,
        'comparable_baseline_protocol': comparableBaselineProtocol,
      };
}
