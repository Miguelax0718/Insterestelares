enum MoodLevel { great, good, neutral, fatigued, stressed }

/// Registro circadiano y de higiene del sueño con metadatos completos de telemetría
class SleepRecord {
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
  final double sleepHours;
  final int wakeEpisodes;
  final MoodLevel morningMood;

  const SleepRecord({
    required this.date,
    this.astronautId = 'AST-01',
    this.source = 'telemetry',
    this.deviceId = 'DEV-ACTIWATCH',
    this.device = 'Actiwatch Plus Circadian Sensor',
    this.protocol = 'NFC / Optical Sync',
    this.measurementMethod =
        'Actigrafía triaxial de muñeca, fotometría ambiental y escala subjetiva matutina',
    this.activityState = 'sleep',
    this.signalQuality = 'optimal (97%)',
    this.recordType = 'instrumental',
    this.algorithm = 'BHP-CircadianColeKripke v2.1',
    this.criterionReference =
        'NASA-STD-3001 Behavioral Health & Circadian Standard',
    required this.sleepHours,
    required this.wakeEpisodes,
    required this.morningMood,
  });

  SleepRecord copyWith({
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
    double? sleepHours,
    int? wakeEpisodes,
    MoodLevel? morningMood,
  }) {
    return SleepRecord(
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
      sleepHours: sleepHours ?? this.sleepHours,
      wakeEpisodes: wakeEpisodes ?? this.wakeEpisodes,
      morningMood: morningMood ?? this.morningMood,
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
      'sleepHours': sleepHours,
      'wakeEpisodes': wakeEpisodes,
      'morningMood': morningMood.name,
    };
  }

  factory SleepRecord.fromJson(Map<String, dynamic> json) {
    final moodStr = json['morningMood']?.toString().toLowerCase();
    final parsedMood = MoodLevel.values.firstWhere(
      (e) => e.name.toLowerCase() == moodStr,
      orElse: () => MoodLevel.good,
    );

    return SleepRecord(
      date: DateTime.tryParse(json['date']?.toString() ?? '') ?? DateTime.now(),
      astronautId: json['astronautId']?.toString() ?? 'AST-01',
      source: json['source']?.toString() ?? 'telemetry',
      deviceId: json['deviceId']?.toString() ?? 'DEV-ACTIWATCH',
      device: json['device']?.toString() ?? 'Actiwatch Plus Circadian Sensor',
      protocol: json['protocol']?.toString() ?? 'NFC / Optical Sync',
      measurementMethod: json['measurementMethod']?.toString() ??
          'Actigrafía triaxial de muñeca, fotometría ambiental y escala subjetiva matutina',
      activityState: json['activityState']?.toString() ?? 'sleep',
      signalQuality: json['signalQuality']?.toString() ?? 'optimal (97%)',
      recordType: json['recordType']?.toString() ?? 'instrumental',
      algorithm: json['algorithm']?.toString() ?? 'BHP-CircadianColeKripke v2.1',
      criterionReference: json['criterionReference']?.toString() ??
          'NASA-STD-3001 Behavioral Health & Circadian Standard',
      sleepHours: (json['sleepHours'] as num?)?.toDouble() ?? 7.0,
      wakeEpisodes: (json['wakeEpisodes'] as num?)?.toInt() ?? 0,
      morningMood: parsedMood,
    );
  }
}
