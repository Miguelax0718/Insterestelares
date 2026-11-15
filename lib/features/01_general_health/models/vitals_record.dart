/// Registro clínico de signos vitales con metadatos completos de procedencia,
/// método de medición, calidad de señal, algoritmo y criterio de referencia NASA.
class VitalsRecord {
  final DateTime timestamp;
  final String astronautId;
  final String source; // 'telemetry' | 'manual'
  final String deviceId;
  final String device;
  final String protocol;
  final String measurementMethod;
  final String activityState; // 'active_duty' | 'resting' | 'post_eva' | 'exercise' | 'sleep' | 'emergency_triage'
  final String signalQuality; // e.g. 'optimal (98%)', 'good (89%)', 'manual_verified'
  final String recordType; // 'instrumental' | 'estimación' | 'manual' | 'subjetiva'
  final String algorithm;
  final String criterionReference;
  final double heartRate; // bpm
  final double systolicBP; // mmHg
  final double diastolicBP; // mmHg
  final double spO2; // %
  final double bodyTemp; // °C
  final double bloodGlucose; // mg/dL
  final double respiratoryRate; // rpm (frecuencia respiratoria)
  final double capillaryRefillSeconds; // segundos de llenado capilar

  // Dimensión 1: Cardiorrespiratoria, Metabólica y Entorno Presurizado (Medición Pasiva Continua)
  final int missionDay;
  final double hrvRmssdMs; // HRV dominio tiempo RMSSD (ms) - Bio-Monitor / CARDIOBREATH
  final double hrvSdnnMs; // HRV dominio tiempo SDNN (ms)
  final double coreTempHeatFluxC; // Temperatura central por flujo de calor - Draeger Double Sensor
  final double hydrationBioimpedanceIndex; // TBW por BIS (%) - Bodystat
  final double localCo2MmHg; // Presión parcial de CO2 en cabina (mmHg)
  final double localO2Percent; // Concentración O2 ambiental (%)
  final double localCh4Ppm; // Traza de metano (ppm)
  final double cabinPressureKPa; // Presión total de cabina (kPa)

  // Dimensión 2: Neurológica y Sensorial (Medición Pasiva Continua)
  final double pupilDiameterMm; // Diámetro pupilar infrarrojo (mm)
  final double pupillometryNpi; // Índice Pupilar Neurológico (NPi 0-5)
  final double plrLatencyMs; // Latencia de Reflejo Pupilar a la Luz (ms)
  final double blinkRatePerMin; // Frecuencia de parpadeo (parpadeos/min)
  final double microsaccadeVelocityDegPerSec; // Velocidad micro-sacádica (°/s)
  final double passiveNearFocusCm; // Distancia de enfoque pasiva por ToF (cm)
  final double estimatedHyperopicShiftDiopters; // Desplazamiento hiperópico estimado (+D) por SANS
  final double passivePvtReactionMs; // Tiempo de reacción pasivo de fondo (ms) - NASA PVT-B
  final int passivePvtLapsesCount; // Lapsos > 500 ms en uso habitual de tableta
  final double touchPointerAccuracyPercent; // Precisión del puntero táctil (%)

  // Dimensión 3: Musculoesquelética (Acelerometría y Bioimpedancia Localizada)
  final double accelerometryRmsG; // Acelerometría triaxial RMS (g)
  final double peakImpactG; // Pico inercial para detección automática de caídas/impactos (g)
  final double strideCadenceStepsPerMin; // Cadencia de marcha/ejercicio (pasos/min)
  final double muscleVolumeRetentionPercent; // Volumen muscular cuádriceps/gastrocnemio (% basal)
  final double pennationAngleDeg; // Ángulo de pennación muscular estimado (°)

  // Dimensión 4: Circadiana y Psicoemocional Nocturna (Actigrafía + HRV + Vitales Nocturnos)
  final double sleepEfficiencyPercent; // Eficiencia del sueño nocturno (%)
  final double sleepFragmentationIndex; // Índice de fragmentación (%)
  final double sleepRegularityIndex; // Índice de regularidad horaria SRI (0-100)
  final double nocturnalHrvRmssdMs; // HRV nocturna RMSSD (ms)
  final double nocturnalHrvSdnnMs; // HRV nocturna SDNN (ms)
  final double nocturnalHeartRateMeanBpm; // FC promedio nocturna (lpm)
  final double nocturnalRespiratoryRateMeanRpm; // FR promedio nocturna (rpm)
  final double nocturnalSpO2MeanPercent; // SpO2 promedio nocturna (%)
  final int nocturnalDesaturationEvents; // Eventos de desaturación nocturna

  /// Índice de hidratación calibrado por software para compensar la sobreestimación
  /// torácica por desplazamiento cefálico de fluidos en microgravedad (>= día 2).
  double get calibratedHydrationIndex =>
      (hydrationBioimpedanceIndex - (missionDay >= 2 ? 3.5 : 0.0)).clamp(0.0, 100.0);

  const VitalsRecord({
    required this.timestamp,
    this.astronautId = 'AST-01',
    this.source = 'telemetry',
    this.deviceId = 'DEV-ASTROSKIN',
    this.device = 'Bio-Monitor Astroskin',
    this.protocol = 'ANT+ / BLE SpaceBus v3.2',
    this.measurementMethod =
        'ECG textil de 3 derivaciones, fotopletismografía óptica y pletismografía inductiva torácica',
    this.activityState = 'active_duty',
    this.signalQuality = 'optimal (98%)',
    this.recordType = 'instrumental',
    this.algorithm = 'NASA-HRP BioSignalKalman v3.2',
    this.criterionReference = 'NASA-STD-3001 Vol. 1 & Vol. 2 / MedicalThresholds',
    required this.heartRate,
    required this.systolicBP,
    required this.diastolicBP,
    required this.spO2,
    required this.bodyTemp,
    required this.bloodGlucose,
    this.respiratoryRate = 16.0,
    this.capillaryRefillSeconds = 1.5,
    this.missionDay = 18,
    this.hrvRmssdMs = 56.0,
    this.hrvSdnnMs = 68.0,
    this.coreTempHeatFluxC = 36.6,
    this.hydrationBioimpedanceIndex = 78.0,
    this.localCo2MmHg = 2.2,
    this.localO2Percent = 20.9,
    this.localCh4Ppm = 0.0,
    this.cabinPressureKPa = 101.3,
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

  VitalsRecord copyWith({
    DateTime? timestamp,
    String? astronautId,
    String? source,
    String? deviceId,
    String? device,
    String? protocol,
    String? measurementMethod,
    String? activityState,
    String? signalQuality,
    String? recordType,
    String? algorithm,
    String? criterionReference,
    double? heartRate,
    double? systolicBP,
    double? diastolicBP,
    double? spO2,
    double? bodyTemp,
    double? bloodGlucose,
    double? respiratoryRate,
    double? capillaryRefillSeconds,
    int? missionDay,
    double? hrvRmssdMs,
    double? hrvSdnnMs,
    double? coreTempHeatFluxC,
    double? hydrationBioimpedanceIndex,
    double? localCo2MmHg,
    double? localO2Percent,
    double? localCh4Ppm,
    double? cabinPressureKPa,
    double? pupilDiameterMm,
    double? pupillometryNpi,
    double? plrLatencyMs,
    double? blinkRatePerMin,
    double? microsaccadeVelocityDegPerSec,
    double? passiveNearFocusCm,
    double? estimatedHyperopicShiftDiopters,
    double? passivePvtReactionMs,
    int? passivePvtLapsesCount,
    double? touchPointerAccuracyPercent,
    double? accelerometryRmsG,
    double? peakImpactG,
    double? strideCadenceStepsPerMin,
    double? muscleVolumeRetentionPercent,
    double? pennationAngleDeg,
    double? sleepEfficiencyPercent,
    double? sleepFragmentationIndex,
    double? sleepRegularityIndex,
    double? nocturnalHrvRmssdMs,
    double? nocturnalHrvSdnnMs,
    double? nocturnalHeartRateMeanBpm,
    double? nocturnalRespiratoryRateMeanRpm,
    double? nocturnalSpO2MeanPercent,
    int? nocturnalDesaturationEvents,
  }) {
    return VitalsRecord(
      timestamp: timestamp ?? this.timestamp,
      astronautId: astronautId ?? this.astronautId,
      source: source ?? this.source,
      deviceId: deviceId ?? this.deviceId,
      device: device ?? this.device,
      protocol: protocol ?? this.protocol,
      measurementMethod: measurementMethod ?? this.measurementMethod,
      activityState: activityState ?? this.activityState,
      signalQuality: signalQuality ?? this.signalQuality,
      recordType: recordType ?? this.recordType,
      algorithm: algorithm ?? this.algorithm,
      criterionReference: criterionReference ?? this.criterionReference,
      heartRate: heartRate ?? this.heartRate,
      systolicBP: systolicBP ?? this.systolicBP,
      diastolicBP: diastolicBP ?? this.diastolicBP,
      spO2: spO2 ?? this.spO2,
      bodyTemp: bodyTemp ?? this.bodyTemp,
      bloodGlucose: bloodGlucose ?? this.bloodGlucose,
      respiratoryRate: respiratoryRate ?? this.respiratoryRate,
      capillaryRefillSeconds: capillaryRefillSeconds ?? this.capillaryRefillSeconds,
      missionDay: missionDay ?? this.missionDay,
      hrvRmssdMs: hrvRmssdMs ?? this.hrvRmssdMs,
      hrvSdnnMs: hrvSdnnMs ?? this.hrvSdnnMs,
      coreTempHeatFluxC: coreTempHeatFluxC ?? this.coreTempHeatFluxC,
      hydrationBioimpedanceIndex:
          hydrationBioimpedanceIndex ?? this.hydrationBioimpedanceIndex,
      localCo2MmHg: localCo2MmHg ?? this.localCo2MmHg,
      localO2Percent: localO2Percent ?? this.localO2Percent,
      localCh4Ppm: localCh4Ppm ?? this.localCh4Ppm,
      cabinPressureKPa: cabinPressureKPa ?? this.cabinPressureKPa,
      pupilDiameterMm: pupilDiameterMm ?? this.pupilDiameterMm,
      pupillometryNpi: pupillometryNpi ?? this.pupillometryNpi,
      plrLatencyMs: plrLatencyMs ?? this.plrLatencyMs,
      blinkRatePerMin: blinkRatePerMin ?? this.blinkRatePerMin,
      microsaccadeVelocityDegPerSec:
          microsaccadeVelocityDegPerSec ?? this.microsaccadeVelocityDegPerSec,
      passiveNearFocusCm: passiveNearFocusCm ?? this.passiveNearFocusCm,
      estimatedHyperopicShiftDiopters:
          estimatedHyperopicShiftDiopters ?? this.estimatedHyperopicShiftDiopters,
      passivePvtReactionMs: passivePvtReactionMs ?? this.passivePvtReactionMs,
      passivePvtLapsesCount: passivePvtLapsesCount ?? this.passivePvtLapsesCount,
      touchPointerAccuracyPercent:
          touchPointerAccuracyPercent ?? this.touchPointerAccuracyPercent,
      accelerometryRmsG: accelerometryRmsG ?? this.accelerometryRmsG,
      peakImpactG: peakImpactG ?? this.peakImpactG,
      strideCadenceStepsPerMin:
          strideCadenceStepsPerMin ?? this.strideCadenceStepsPerMin,
      muscleVolumeRetentionPercent:
          muscleVolumeRetentionPercent ?? this.muscleVolumeRetentionPercent,
      pennationAngleDeg: pennationAngleDeg ?? this.pennationAngleDeg,
      sleepEfficiencyPercent: sleepEfficiencyPercent ?? this.sleepEfficiencyPercent,
      sleepFragmentationIndex:
          sleepFragmentationIndex ?? this.sleepFragmentationIndex,
      sleepRegularityIndex: sleepRegularityIndex ?? this.sleepRegularityIndex,
      nocturnalHrvRmssdMs: nocturnalHrvRmssdMs ?? this.nocturnalHrvRmssdMs,
      nocturnalHrvSdnnMs: nocturnalHrvSdnnMs ?? this.nocturnalHrvSdnnMs,
      nocturnalHeartRateMeanBpm:
          nocturnalHeartRateMeanBpm ?? this.nocturnalHeartRateMeanBpm,
      nocturnalRespiratoryRateMeanRpm:
          nocturnalRespiratoryRateMeanRpm ?? this.nocturnalRespiratoryRateMeanRpm,
      nocturnalSpO2MeanPercent:
          nocturnalSpO2MeanPercent ?? this.nocturnalSpO2MeanPercent,
      nocturnalDesaturationEvents:
          nocturnalDesaturationEvents ?? this.nocturnalDesaturationEvents,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'astronautId': astronautId,
      'source': source,
      'deviceId': deviceId,
      'device': device,
      'protocol': protocol,
      'measurementMethod': measurementMethod,
      'activityState': activityState,
      'signalQuality': signalQuality,
      'recordType': recordType,
      'algorithm': algorithm,
      'criterionReference': criterionReference,
      'heartRate': heartRate,
      'systolicBP': systolicBP,
      'diastolicBP': diastolicBP,
      'spO2': spO2,
      'bodyTemp': bodyTemp,
      'bloodGlucose': bloodGlucose,
      'respiratoryRate': respiratoryRate,
      'capillaryRefillSeconds': capillaryRefillSeconds,
      'missionDay': missionDay,
      'hrvRmssdMs': hrvRmssdMs,
      'hrvSdnnMs': hrvSdnnMs,
      'coreTempHeatFluxC': coreTempHeatFluxC,
      'hydrationBioimpedanceIndex': hydrationBioimpedanceIndex,
      'calibratedHydrationIndex': calibratedHydrationIndex,
      'localCo2MmHg': localCo2MmHg,
      'localO2Percent': localO2Percent,
      'localCh4Ppm': localCh4Ppm,
      'cabinPressureKPa': cabinPressureKPa,
      'pupilDiameterMm': pupilDiameterMm,
      'pupillometryNpi': pupillometryNpi,
      'plrLatencyMs': plrLatencyMs,
      'blinkRatePerMin': blinkRatePerMin,
      'microsaccadeVelocityDegPerSec': microsaccadeVelocityDegPerSec,
      'passiveNearFocusCm': passiveNearFocusCm,
      'estimatedHyperopicShiftDiopters': estimatedHyperopicShiftDiopters,
      'passivePvtReactionMs': passivePvtReactionMs,
      'passivePvtLapsesCount': passivePvtLapsesCount,
      'touchPointerAccuracyPercent': touchPointerAccuracyPercent,
      'accelerometryRmsG': accelerometryRmsG,
      'peakImpactG': peakImpactG,
      'strideCadenceStepsPerMin': strideCadenceStepsPerMin,
      'muscleVolumeRetentionPercent': muscleVolumeRetentionPercent,
      'pennationAngleDeg': pennationAngleDeg,
      'sleepEfficiencyPercent': sleepEfficiencyPercent,
      'sleepFragmentationIndex': sleepFragmentationIndex,
      'sleepRegularityIndex': sleepRegularityIndex,
      'nocturnalHrvRmssdMs': nocturnalHrvRmssdMs,
      'nocturnalHrvSdnnMs': nocturnalHrvSdnnMs,
      'nocturnalHeartRateMeanBpm': nocturnalHeartRateMeanBpm,
      'nocturnalRespiratoryRateMeanRpm': nocturnalRespiratoryRateMeanRpm,
      'nocturnalSpO2MeanPercent': nocturnalSpO2MeanPercent,
      'nocturnalDesaturationEvents': nocturnalDesaturationEvents,
    };
  }

  factory VitalsRecord.fromJson(Map<String, dynamic> json) {
    return VitalsRecord(
      timestamp: DateTime.tryParse(json['timestamp']?.toString() ?? '') ?? DateTime.now(),
      astronautId: json['astronautId']?.toString() ?? 'AST-01',
      source: json['source']?.toString() ?? 'telemetry',
      deviceId: json['deviceId']?.toString() ?? 'DEV-ASTROSKIN',
      device: json['device']?.toString() ?? 'Bio-Monitor Astroskin',
      protocol: json['protocol']?.toString() ?? 'ANT+ / BLE SpaceBus v3.2',
      measurementMethod: json['measurementMethod']?.toString() ??
          'ECG textil de 3 derivaciones, fotopletismografía óptica y pletismografía inductiva torácica',
      activityState: json['activityState']?.toString() ?? 'active_duty',
      signalQuality: json['signalQuality']?.toString() ?? 'optimal (98%)',
      recordType: json['recordType']?.toString() ?? 'instrumental',
      algorithm: json['algorithm']?.toString() ?? 'NASA-HRP BioSignalKalman v3.2',
      criterionReference: json['criterionReference']?.toString() ??
          'NASA-STD-3001 Vol. 1 & Vol. 2 / MedicalThresholds',
      heartRate: (json['heartRate'] as num?)?.toDouble() ?? 70.0,
      systolicBP: (json['systolicBP'] as num?)?.toDouble() ?? 120.0,
      diastolicBP: (json['diastolicBP'] as num?)?.toDouble() ?? 80.0,
      spO2: (json['spO2'] as num?)?.toDouble() ?? 98.0,
      bodyTemp: (json['bodyTemp'] as num?)?.toDouble() ?? 36.5,
      bloodGlucose: (json['bloodGlucose'] as num?)?.toDouble() ?? 90.0,
      respiratoryRate: (json['respiratoryRate'] as num?)?.toDouble() ?? 16.0,
      capillaryRefillSeconds: (json['capillaryRefillSeconds'] as num?)?.toDouble() ?? 1.5,
      missionDay: (json['missionDay'] as num?)?.toInt() ?? 18,
      hrvRmssdMs: (json['hrvRmssdMs'] as num?)?.toDouble() ?? 56.0,
      hrvSdnnMs: (json['hrvSdnnMs'] as num?)?.toDouble() ?? 68.0,
      coreTempHeatFluxC: (json['coreTempHeatFluxC'] as num?)?.toDouble() ?? 36.6,
      hydrationBioimpedanceIndex:
          (json['hydrationBioimpedanceIndex'] as num?)?.toDouble() ?? 78.0,
      localCo2MmHg: (json['localCo2MmHg'] as num?)?.toDouble() ?? 2.2,
      localO2Percent: (json['localO2Percent'] as num?)?.toDouble() ?? 20.9,
      localCh4Ppm: (json['localCh4Ppm'] as num?)?.toDouble() ?? 0.0,
      cabinPressureKPa: (json['cabinPressureKPa'] as num?)?.toDouble() ?? 101.3,
      pupilDiameterMm: (json['pupilDiameterMm'] as num?)?.toDouble() ?? 3.8,
      pupillometryNpi: (json['pupillometryNpi'] as num?)?.toDouble() ?? 4.2,
      plrLatencyMs: (json['plrLatencyMs'] as num?)?.toDouble() ?? 210.0,
      blinkRatePerMin: (json['blinkRatePerMin'] as num?)?.toDouble() ?? 15.0,
      microsaccadeVelocityDegPerSec:
          (json['microsaccadeVelocityDegPerSec'] as num?)?.toDouble() ?? 42.0,
      passiveNearFocusCm: (json['passiveNearFocusCm'] as num?)?.toDouble() ?? 30.0,
      estimatedHyperopicShiftDiopters:
          (json['estimatedHyperopicShiftDiopters'] as num?)?.toDouble() ?? 0.0,
      passivePvtReactionMs: (json['passivePvtReactionMs'] as num?)?.toDouble() ?? 255.0,
      passivePvtLapsesCount: (json['passivePvtLapsesCount'] as num?)?.toInt() ?? 0,
      touchPointerAccuracyPercent:
          (json['touchPointerAccuracyPercent'] as num?)?.toDouble() ?? 96.5,
      accelerometryRmsG: (json['accelerometryRmsG'] as num?)?.toDouble() ?? 0.024,
      peakImpactG: (json['peakImpactG'] as num?)?.toDouble() ?? 0.15,
      strideCadenceStepsPerMin:
          (json['strideCadenceStepsPerMin'] as num?)?.toDouble() ?? 0.0,
      muscleVolumeRetentionPercent:
          (json['muscleVolumeRetentionPercent'] as num?)?.toDouble() ?? 94.0,
      pennationAngleDeg: (json['pennationAngleDeg'] as num?)?.toDouble() ?? 14.5,
      sleepEfficiencyPercent:
          (json['sleepEfficiencyPercent'] as num?)?.toDouble() ?? 91.0,
      sleepFragmentationIndex:
          (json['sleepFragmentationIndex'] as num?)?.toDouble() ?? 8.5,
      sleepRegularityIndex:
          (json['sleepRegularityIndex'] as num?)?.toDouble() ?? 88.0,
      nocturnalHrvRmssdMs: (json['nocturnalHrvRmssdMs'] as num?)?.toDouble() ?? 62.0,
      nocturnalHrvSdnnMs: (json['nocturnalHrvSdnnMs'] as num?)?.toDouble() ?? 74.0,
      nocturnalHeartRateMeanBpm:
          (json['nocturnalHeartRateMeanBpm'] as num?)?.toDouble() ?? 56.0,
      nocturnalRespiratoryRateMeanRpm:
          (json['nocturnalRespiratoryRateMeanRpm'] as num?)?.toDouble() ?? 13.5,
      nocturnalSpO2MeanPercent:
          (json['nocturnalSpO2MeanPercent'] as num?)?.toDouble() ?? 97.5,
      nocturnalDesaturationEvents:
          (json['nocturnalDesaturationEvents'] as num?)?.toInt() ?? 0,
    );
  }
}
