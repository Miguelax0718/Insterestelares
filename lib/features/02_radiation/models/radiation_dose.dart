enum RadiationSeverity { normal, warning, critical }

/// Registro dosimétrico de radiación espacial con metadatos completos de telemetría
class RadiationDose {
  final DateTime timestamp;
  final String astronautId;
  final String source; // 'telemetry' | 'manual'
  final String deviceId;
  final String device;
  final String protocol;
  final String measurementMethod;
  final String activityState;
  final String signalQuality;
  final String recordType; // 'instrumental' | 'estimación' | 'manual' | 'subjetiva'
  final String algorithm;
  final String criterionReference;
  final double doseRateMicroSvPerHour; // uSv/h
  final double cumulativeDoseMilliSv; // mSv
  final RadiationSeverity severity;

  const RadiationDose({
    required this.timestamp,
    this.astronautId = 'AST-01',
    this.source = 'telemetry',
    this.deviceId = 'DEV-HERA',
    this.device = 'HERA Radiation Assay',
    this.protocol = 'MIL-STD-1553B / Timepix bus',
    this.measurementMethod =
        'Espectrometría activa en silicio híbrido Timepix3 (LET)',
    this.activityState = 'active_duty',
    this.signalQuality = 'optimal (95%)',
    this.recordType = 'instrumental',
    this.algorithm = 'SRAG-LET-Dosimetry v2.4',
    this.criterionReference = 'NASA-STD-3001 Permissible Exposure Limits (PEL)',
    required this.doseRateMicroSvPerHour,
    required this.cumulativeDoseMilliSv,
    required this.severity,
  });

  RadiationDose copyWith({
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
    double? doseRateMicroSvPerHour,
    double? cumulativeDoseMilliSv,
    RadiationSeverity? severity,
  }) {
    return RadiationDose(
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
      doseRateMicroSvPerHour: doseRateMicroSvPerHour ?? this.doseRateMicroSvPerHour,
      cumulativeDoseMilliSv: cumulativeDoseMilliSv ?? this.cumulativeDoseMilliSv,
      severity: severity ?? this.severity,
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
      'doseRateMicroSvPerHour': doseRateMicroSvPerHour,
      'cumulativeDoseMilliSv': cumulativeDoseMilliSv,
      'severity': severity.name,
    };
  }

  factory RadiationDose.fromJson(Map<String, dynamic> json) {
    final severityStr = json['severity']?.toString().toLowerCase();
    final parsedSeverity = RadiationSeverity.values.firstWhere(
      (e) => e.name.toLowerCase() == severityStr,
      orElse: () => RadiationSeverity.normal,
    );

    return RadiationDose(
      timestamp: DateTime.tryParse(json['timestamp']?.toString() ?? '') ?? DateTime.now(),
      astronautId: json['astronautId']?.toString() ?? 'AST-01',
      source: json['source']?.toString() ?? 'telemetry',
      deviceId: json['deviceId']?.toString() ?? 'DEV-HERA',
      device: json['device']?.toString() ?? 'HERA Radiation Assay',
      protocol: json['protocol']?.toString() ?? 'MIL-STD-1553B / Timepix bus',
      measurementMethod: json['measurementMethod']?.toString() ??
          'Espectrometría activa en silicio híbrido Timepix3 (LET)',
      activityState: json['activityState']?.toString() ?? 'active_duty',
      signalQuality: json['signalQuality']?.toString() ?? 'optimal (95%)',
      recordType: json['recordType']?.toString() ?? 'instrumental',
      algorithm: json['algorithm']?.toString() ?? 'SRAG-LET-Dosimetry v2.4',
      criterionReference: json['criterionReference']?.toString() ??
          'NASA-STD-3001 Permissible Exposure Limits (PEL)',
      doseRateMicroSvPerHour: (json['doseRateMicroSvPerHour'] as num?)?.toDouble() ?? 50.0,
      cumulativeDoseMilliSv: (json['cumulativeDoseMilliSv'] as num?)?.toDouble() ?? 10.0,
      severity: parsedSeverity,
    );
  }
}
