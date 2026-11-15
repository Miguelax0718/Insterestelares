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
  final int missionDay; // Día de misión para calibrar adaptación en 0g
  final double accelerometryRmsG; // Micro-movimiento RMS en g (nunca 0 absoluto por balistocardiografía)
  final double hrvRmssdMs; // Variabilidad cardíaca RMSSD (ms)
  final double hydrationBioimpedanceIndex; // Índice crudo de hidratación por bioimpedancia (0-100)
  final double localCo2MmHg; // Presión parcial local de CO2 en cabina (mmHg)
  final double localO2Percent; // Porcentaje de O2 en cabina (%)
  final double localCh4Ppm; // Trazas de metano/propelente (ppm)
  final double cabinPressureKPa; // Presión barométrica de cabina (kPa)

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
    this.accelerometryRmsG = 0.024,
    this.hrvRmssdMs = 56.0,
    this.hydrationBioimpedanceIndex = 78.0,
    this.localCo2MmHg = 2.2,
    this.localO2Percent = 20.9,
    this.localCh4Ppm = 0.0,
    this.cabinPressureKPa = 101.3,
  });

  /// Índice de hidratación ajustado ante el desplazamiento cefálico de fluidos
  /// y diuresis compensatoria durante los primeros días en microgravedad.
  double get calibratedHydrationIndex {
    final int mDay = (missionDay as int?) ?? 18;
    final double hIndex = (hydrationBioimpedanceIndex as double?) ?? 78.0;
    final double fluidShiftOffset =
        mDay <= 3 ? -6.5 : (mDay <= 7 ? -3.0 : 0.0);
    return (hIndex + fluidShiftOffset).clamp(0.0, 100.0);
  }

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
    double? accelerometryRmsG,
    double? hrvRmssdMs,
    double? hydrationBioimpedanceIndex,
    double? localCo2MmHg,
    double? localO2Percent,
    double? localCh4Ppm,
    double? cabinPressureKPa,
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
      missionDay: missionDay ?? (this.missionDay as int? ?? 18),
      accelerometryRmsG:
          accelerometryRmsG ?? (this.accelerometryRmsG as double? ?? 0.024),
      hrvRmssdMs: hrvRmssdMs ?? (this.hrvRmssdMs as double? ?? 56.0),
      hydrationBioimpedanceIndex: hydrationBioimpedanceIndex ??
          (this.hydrationBioimpedanceIndex as double? ?? 78.0),
      localCo2MmHg: localCo2MmHg ?? (this.localCo2MmHg as double? ?? 2.2),
      localO2Percent: localO2Percent ?? (this.localO2Percent as double? ?? 20.9),
      localCh4Ppm: localCh4Ppm ?? (this.localCh4Ppm as double? ?? 0.0),
      cabinPressureKPa:
          cabinPressureKPa ?? (this.cabinPressureKPa as double? ?? 101.3),
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
      'accelerometryRmsG': accelerometryRmsG,
      'hrvRmssdMs': hrvRmssdMs,
      'hydrationBioimpedanceIndex': hydrationBioimpedanceIndex,
      'localCo2MmHg': localCo2MmHg,
      'localO2Percent': localO2Percent,
      'localCh4Ppm': localCh4Ppm,
      'cabinPressureKPa': cabinPressureKPa,
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
      accelerometryRmsG: (json['accelerometryRmsG'] as num?)?.toDouble() ?? 0.024,
      hrvRmssdMs: (json['hrvRmssdMs'] as num?)?.toDouble() ?? 56.0,
      hydrationBioimpedanceIndex:
          (json['hydrationBioimpedanceIndex'] as num?)?.toDouble() ?? 78.0,
      localCo2MmHg: (json['localCo2MmHg'] as num?)?.toDouble() ?? 2.2,
      localO2Percent: (json['localO2Percent'] as num?)?.toDouble() ?? 20.9,
      localCh4Ppm: (json['localCh4Ppm'] as num?)?.toDouble() ?? 0.0,
      cabinPressureKPa: (json['cabinPressureKPa'] as num?)?.toDouble() ?? 101.3,
    );
  }
}
