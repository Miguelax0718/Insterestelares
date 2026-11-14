/// Registro de sesión de contramedidas físicas en microgravedad con metadatos completos de telemetría
class ExerciseSession {
  final DateTime date;
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
  final String deviceName; // ARED (Resistencia), T2 (Cinta), CEVIS (Bicicleta)
  final int durationMinutes;
  final double caloriesBurned;
  final bool targetReached;

  const ExerciseSession({
    required this.date,
    this.astronautId = 'AST-01',
    this.source = 'telemetry',
    this.deviceId = 'DEV-ARED',
    this.device = 'ARED Advanced Resistive Device',
    this.protocol = 'CAN-Bus / Space Wireless',
    this.measurementMethod =
        'Dinamometría en cilindros de vacío y telemetría cinemática triaxial',
    this.activityState = 'exercise',
    this.signalQuality = 'optimal (94%)',
    this.recordType = 'estimación',
    this.algorithm = 'NASA-CountermeasureMetabolicKinematics v1.8',
    this.criterionReference =
        'NASA-STD-3001 Musculoskeletal Countermeasure Protocol',
    required this.deviceName,
    required this.durationMinutes,
    required this.caloriesBurned,
    required this.targetReached,
  });

  ExerciseSession copyWith({
    DateTime? date,
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
    String? deviceName,
    int? durationMinutes,
    double? caloriesBurned,
    bool? targetReached,
  }) {
    return ExerciseSession(
      date: date ?? this.date,
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
      deviceName: deviceName ?? this.deviceName,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      caloriesBurned: caloriesBurned ?? this.caloriesBurned,
      targetReached: targetReached ?? this.targetReached,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'date': date.toIso8601String(),
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
      'deviceName': deviceName,
      'durationMinutes': durationMinutes,
      'caloriesBurned': caloriesBurned,
      'targetReached': targetReached,
    };
  }

  factory ExerciseSession.fromJson(Map<String, dynamic> json) {
    final parsedDeviceName = json['deviceName']?.toString() ?? 'ARED';
    return ExerciseSession(
      date: DateTime.tryParse(json['date']?.toString() ?? '') ?? DateTime.now(),
      astronautId: json['astronautId']?.toString() ?? 'AST-01',
      source: json['source']?.toString() ?? 'telemetry',
      deviceId: json['deviceId']?.toString() ?? 'DEV-ARED',
      device: json['device']?.toString() ?? parsedDeviceName,
      protocol: json['protocol']?.toString() ?? 'CAN-Bus / Space Wireless',
      measurementMethod: json['measurementMethod']?.toString() ??
          'Dinamometría en cilindros de vacío y telemetría cinemática triaxial',
      activityState: json['activityState']?.toString() ?? 'exercise',
      signalQuality: json['signalQuality']?.toString() ?? 'optimal (94%)',
      recordType: json['recordType']?.toString() ?? 'estimación',
      algorithm: json['algorithm']?.toString() ??
          'NASA-CountermeasureMetabolicKinematics v1.8',
      criterionReference: json['criterionReference']?.toString() ??
          'NASA-STD-3001 Musculoskeletal Countermeasure Protocol',
      deviceName: parsedDeviceName,
      durationMinutes: (json['durationMinutes'] as num?)?.toInt() ?? 30,
      caloriesBurned: (json['caloriesBurned'] as num?)?.toDouble() ?? 250.0,
      targetReached: json['targetReached'] as bool? ?? true,
    );
  }
}
