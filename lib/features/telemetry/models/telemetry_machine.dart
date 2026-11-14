/// Categorías de instrumental médico y de telemetría espacial
enum MachineCategory {
  biometrics,
  dosimetry,
  hemodynamics,
  countermeasure,
  bloodLab,
  circadian,
}

/// Estado de conexión de una máquina con el bus telemétrico de un astronauta
enum MachineConnectionStatus {
  disconnected,
  connecting,
  connected,
  streaming,
  error,
}

/// Paquete discreto de datos de telemetría médica transmitido por un equipo
/// con trazabilidad clínica completa (astronautId, source, device, método,
/// estado de actividad, calidad de señal, recordType, algoritmo y criterio).
class TelemetryPacket {
  final DateTime timestamp;
  final String machineId;
  final String astronautId;
  final String source; // 'telemetry' | 'manual'
  final String device;
  final String protocol;
  final String measurementMethod;
  final String activityState;
  final String signalQuality;
  final String recordType; // 'instrumental' | 'estimación' | 'manual' | 'subjetiva'
  final String algorithm;
  final String criterionReference;
  final Map<String, dynamic> metrics;

  const TelemetryPacket({
    required this.timestamp,
    required this.machineId,
    required this.astronautId,
    this.source = 'telemetry',
    this.device = '',
    this.protocol = 'SpaceBus',
    this.measurementMethod = 'Adquisición telemétrica instrumental directa',
    this.activityState = 'active_duty',
    this.signalQuality = 'optimal (98%)',
    this.recordType = 'instrumental',
    this.algorithm = 'NASA-HRP BioSignalKalman v3.2',
    this.criterionReference = 'NASA-STD-3001 Vol. 1 & Vol. 2 / MedicalThresholds',
    required this.metrics,
  });

  TelemetryPacket copyWith({
    DateTime? timestamp,
    String? machineId,
    String? astronautId,
    String? source,
    String? device,
    String? protocol,
    String? measurementMethod,
    String? activityState,
    String? signalQuality,
    String? recordType,
    String? algorithm,
    String? criterionReference,
    Map<String, dynamic>? metrics,
  }) {
    return TelemetryPacket(
      timestamp: timestamp ?? this.timestamp,
      machineId: machineId ?? this.machineId,
      astronautId: astronautId ?? this.astronautId,
      source: source ?? this.source,
      device: device ?? this.device,
      protocol: protocol ?? this.protocol,
      measurementMethod: measurementMethod ?? this.measurementMethod,
      activityState: activityState ?? this.activityState,
      signalQuality: signalQuality ?? this.signalQuality,
      recordType: recordType ?? this.recordType,
      algorithm: algorithm ?? this.algorithm,
      criterionReference: criterionReference ?? this.criterionReference,
      metrics: metrics ?? this.metrics,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'machineId': machineId,
      'deviceId': machineId,
      'astronautId': astronautId,
      'source': source,
      'device': device,
      'protocol': protocol,
      'measurementMethod': measurementMethod,
      'activityState': activityState,
      'signalQuality': signalQuality,
      'recordType': recordType,
      'algorithm': algorithm,
      'criterionReference': criterionReference,
      'metrics': metrics,
    };
  }

  factory TelemetryPacket.fromJson(Map<String, dynamic> json) {
    final parsedMachineId =
        json['machineId']?.toString() ?? json['deviceId']?.toString() ?? '';
    return TelemetryPacket(
      timestamp:
          DateTime.tryParse(json['timestamp']?.toString() ?? '') ?? DateTime.now(),
      machineId: parsedMachineId,
      astronautId: json['astronautId']?.toString() ?? '',
      source: json['source']?.toString() ?? 'telemetry',
      device: json['device']?.toString() ?? parsedMachineId,
      protocol: json['protocol']?.toString() ?? 'SpaceBus',
      measurementMethod: json['measurementMethod']?.toString() ??
          'Adquisición telemétrica instrumental directa',
      activityState: json['activityState']?.toString() ?? 'active_duty',
      signalQuality: json['signalQuality']?.toString() ?? 'optimal (98%)',
      recordType: json['recordType']?.toString() ?? 'instrumental',
      algorithm: json['algorithm']?.toString() ?? 'NASA-HRP BioSignalKalman v3.2',
      criterionReference: json['criterionReference']?.toString() ??
          'NASA-STD-3001 Vol. 1 & Vol. 2 / MedicalThresholds',
      metrics: json['metrics'] is Map
          ? Map<String, dynamic>.from(json['metrics'] as Map)
          : {},
    );
  }
}

/// Representa una máquina médica o sensor telemétrico a bordo del hábitat espacial
class TelemetryMachine {
  final String id;
  final String name;
  final String code;
  final MachineCategory category;
  final String protocol;
  final String measurementMethod;
  final String defaultActivityState;
  final String defaultRecordType;
  final String algorithm;
  final String criterionReference;
  final String description;
  final List<String> supportedMetrics;
  final int batteryPercent;
  final int signalPercent;
  final Map<String, MachineConnectionStatus> statusByAstronaut;
  final Map<String, TelemetryPacket> lastPacketByAstronaut;

  const TelemetryMachine({
    required this.id,
    required this.name,
    required this.code,
    required this.category,
    required this.protocol,
    this.measurementMethod = 'Telemetría biomédica no invasiva',
    this.defaultActivityState = 'active_duty',
    this.defaultRecordType = 'instrumental',
    this.algorithm = 'NASA-HRP BioSignalKalman v3.2',
    this.criterionReference = 'NASA-STD-3001 Vol. 1 & Vol. 2 / MedicalThresholds',
    required this.description,
    required this.supportedMetrics,
    required this.batteryPercent,
    required this.signalPercent,
    this.statusByAstronaut = const {},
    this.lastPacketByAstronaut = const {},
  });

  /// Indica si el sensor está enlazado y transmitiendo o listo para el astronauta indicado
  bool isConnectedFor(String astronautId) {
    final status = statusByAstronaut[astronautId];
    return status == MachineConnectionStatus.connected ||
        status == MachineConnectionStatus.streaming;
  }

  /// Retorna el estado actual de enlace para un astronauta
  MachineConnectionStatus statusFor(String astronautId) {
    return statusByAstronaut[astronautId] ?? MachineConnectionStatus.disconnected;
  }

  /// Retorna el último paquete recibido para un astronauta dado
  TelemetryPacket? lastPacketFor(String astronautId) {
    return lastPacketByAstronaut[astronautId];
  }

  TelemetryMachine copyWith({
    String? id,
    String? name,
    String? code,
    MachineCategory? category,
    String? protocol,
    String? measurementMethod,
    String? defaultActivityState,
    String? defaultRecordType,
    String? algorithm,
    String? criterionReference,
    String? description,
    List<String>? supportedMetrics,
    int? batteryPercent,
    int? signalPercent,
    Map<String, MachineConnectionStatus>? statusByAstronaut,
    Map<String, TelemetryPacket>? lastPacketByAstronaut,
  }) {
    return TelemetryMachine(
      id: id ?? this.id,
      name: name ?? this.name,
      code: code ?? this.code,
      category: category ?? this.category,
      protocol: protocol ?? this.protocol,
      measurementMethod: measurementMethod ?? this.measurementMethod,
      defaultActivityState: defaultActivityState ?? this.defaultActivityState,
      defaultRecordType: defaultRecordType ?? this.defaultRecordType,
      algorithm: algorithm ?? this.algorithm,
      criterionReference: criterionReference ?? this.criterionReference,
      description: description ?? this.description,
      supportedMetrics: supportedMetrics ?? this.supportedMetrics,
      batteryPercent: batteryPercent ?? this.batteryPercent,
      signalPercent: signalPercent ?? this.signalPercent,
      statusByAstronaut: statusByAstronaut ?? this.statusByAstronaut,
      lastPacketByAstronaut: lastPacketByAstronaut ?? this.lastPacketByAstronaut,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'code': code,
      'category': category.name,
      'protocol': protocol,
      'measurementMethod': measurementMethod,
      'defaultActivityState': defaultActivityState,
      'defaultRecordType': defaultRecordType,
      'algorithm': algorithm,
      'criterionReference': criterionReference,
      'description': description,
      'supportedMetrics': supportedMetrics,
      'batteryPercent': batteryPercent,
      'signalPercent': signalPercent,
      'statusByAstronaut': statusByAstronaut.map(
        (key, value) => MapEntry(key, value.name),
      ),
      'lastPacketByAstronaut': lastPacketByAstronaut.map(
        (key, value) => MapEntry(key, value.toJson()),
      ),
    };
  }

  factory TelemetryMachine.fromJson(Map<String, dynamic> json) {
    final categoryStr = json['category']?.toString().toLowerCase();
    final parsedCategory = MachineCategory.values.firstWhere(
      (e) => e.name.toLowerCase() == categoryStr,
      orElse: () => MachineCategory.biometrics,
    );

    final statusMap = <String, MachineConnectionStatus>{};
    if (json['statusByAstronaut'] is Map) {
      (json['statusByAstronaut'] as Map).forEach((k, v) {
        final valStr = v?.toString().toLowerCase();
        statusMap[k.toString()] = MachineConnectionStatus.values.firstWhere(
          (e) => e.name.toLowerCase() == valStr,
          orElse: () => MachineConnectionStatus.disconnected,
        );
      });
    }

    final packetMap = <String, TelemetryPacket>{};
    if (json['lastPacketByAstronaut'] is Map) {
      (json['lastPacketByAstronaut'] as Map).forEach((k, v) {
        if (v is Map) {
          packetMap[k.toString()] = TelemetryPacket.fromJson(
            Map<String, dynamic>.from(v),
          );
        }
      });
    }

    return TelemetryMachine(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      code: json['code']?.toString() ?? '',
      category: parsedCategory,
      protocol: json['protocol']?.toString() ?? 'SpaceBus',
      measurementMethod: json['measurementMethod']?.toString() ??
          'Telemetría biomédica no invasiva',
      defaultActivityState:
          json['defaultActivityState']?.toString() ?? 'active_duty',
      defaultRecordType: json['defaultRecordType']?.toString() ?? 'instrumental',
      algorithm: json['algorithm']?.toString() ?? 'NASA-HRP BioSignalKalman v3.2',
      criterionReference: json['criterionReference']?.toString() ??
          'NASA-STD-3001 Vol. 1 & Vol. 2 / MedicalThresholds',
      description: json['description']?.toString() ?? '',
      supportedMetrics: (json['supportedMetrics'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      batteryPercent: (json['batteryPercent'] as num?)?.toInt() ?? 100,
      signalPercent: (json['signalPercent'] as num?)?.toInt() ?? 100,
      statusByAstronaut: statusMap,
      lastPacketByAstronaut: packetMap,
    );
  }
}
