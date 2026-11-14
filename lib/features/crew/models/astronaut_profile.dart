import 'package:astramed/features/01_general_health/models/vitals_record.dart';
import 'package:astramed/features/02_radiation/models/radiation_dose.dart';
import 'package:astramed/features/03_microgravity/models/microgravity_data.dart';
import 'package:astramed/features/04_mental_health/models/sleep_record.dart';

/// Nivel de riesgo médico y operacional para cada astronauta
enum CrewRiskLevel {
  nominal,   // 🟢 Estable / Sin alertas
  warning,   // 🟡 Precaución / Parámetros limítrofes o fatiga
  critical,  // 🔴 Emergencia Crítica / Requiere intervención inmediata
}

/// Modelo de perfil individual para un miembro de la tripulación
class AstronautProfile {
  final String id;
  final String name;
  final String role;
  final String rank;
  final String callsign;
  final String avatarInitials;
  final int age;
  final String bloodType;
  final String currentZone; // p.ej. 'Módulo Hábitat', 'Esclusa EVA', 'Cúpula'

  // Registros clínicos individuales
  final VitalsRecord vitals;
  final RadiationDose radiation;
  final SleepRecord sleep;
  final ExerciseSession exercise;

  // Estado de alerta y triage
  final CrewRiskLevel riskLevel;
  final String riskTitle;
  final String riskDescription;
  final List<String> activeAlerts;

  // Máquinas de telemetría vinculadas y última sincronización
  final List<String> linkedMachineIds;
  final DateTime? lastTelemetrySync;

  const AstronautProfile({
    required this.id,
    required this.name,
    required this.role,
    required this.rank,
    required this.callsign,
    required this.avatarInitials,
    required this.age,
    required this.bloodType,
    required this.currentZone,
    required this.vitals,
    required this.radiation,
    required this.sleep,
    required this.exercise,
    required this.riskLevel,
    required this.riskTitle,
    required this.riskDescription,
    required this.activeAlerts,
    this.linkedMachineIds = const [],
    this.lastTelemetrySync,
  });

  AstronautProfile copyWith({
    String? id,
    String? name,
    String? role,
    String? rank,
    String? callsign,
    String? avatarInitials,
    int? age,
    String? bloodType,
    String? currentZone,
    VitalsRecord? vitals,
    RadiationDose? radiation,
    SleepRecord? sleep,
    ExerciseSession? exercise,
    CrewRiskLevel? riskLevel,
    String? riskTitle,
    String? riskDescription,
    List<String>? activeAlerts,
    List<String>? linkedMachineIds,
    DateTime? lastTelemetrySync,
  }) {
    return AstronautProfile(
      id: id ?? this.id,
      name: name ?? this.name,
      role: role ?? this.role,
      rank: rank ?? this.rank,
      callsign: callsign ?? this.callsign,
      avatarInitials: avatarInitials ?? this.avatarInitials,
      age: age ?? this.age,
      bloodType: bloodType ?? this.bloodType,
      currentZone: currentZone ?? this.currentZone,
      vitals: vitals ?? this.vitals,
      radiation: radiation ?? this.radiation,
      sleep: sleep ?? this.sleep,
      exercise: exercise ?? this.exercise,
      riskLevel: riskLevel ?? this.riskLevel,
      riskTitle: riskTitle ?? this.riskTitle,
      riskDescription: riskDescription ?? this.riskDescription,
      activeAlerts: activeAlerts ?? this.activeAlerts,
      linkedMachineIds: linkedMachineIds ?? this.linkedMachineIds,
      lastTelemetrySync: lastTelemetrySync ?? this.lastTelemetrySync,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'role': role,
      'rank': rank,
      'callsign': callsign,
      'avatarInitials': avatarInitials,
      'age': age,
      'bloodType': bloodType,
      'currentZone': currentZone,
      'vitals': vitals.toJson(),
      'radiation': radiation.toJson(),
      'sleep': sleep.toJson(),
      'exercise': exercise.toJson(),
      'riskLevel': riskLevel.name,
      'riskTitle': riskTitle,
      'riskDescription': riskDescription,
      'activeAlerts': activeAlerts,
      'linkedMachineIds': linkedMachineIds,
      if (lastTelemetrySync != null) ...{
        'lastTelemetrySync': lastTelemetrySync!.toIso8601String(),
        'lastUpdated': lastTelemetrySync!.toIso8601String(),
      },
    };
  }

  factory AstronautProfile.fromJson(Map<String, dynamic> json) {
    final riskStr = json['riskLevel']?.toString().toLowerCase();
    final parsedRisk = CrewRiskLevel.values.firstWhere(
      (e) => e.name.toLowerCase() == riskStr,
      orElse: () => CrewRiskLevel.nominal,
    );
    final astronautId = json['id']?.toString() ?? '';

    VitalsRecord parsedVitals;
    if (json['vitals'] != null) {
      parsedVitals =
          VitalsRecord.fromJson(Map<String, dynamic>.from(json['vitals'] as Map));
      if (astronautId.isNotEmpty) {
        parsedVitals = parsedVitals.copyWith(astronautId: astronautId);
      }
    } else {
      parsedVitals = VitalsRecord(
        timestamp: DateTime.now(),
        astronautId: astronautId.isNotEmpty ? astronautId : 'AST-01',
        heartRate: 70,
        systolicBP: 120,
        diastolicBP: 80,
        spO2: 98,
        bodyTemp: 36.5,
        bloodGlucose: 90,
      );
    }

    RadiationDose parsedRadiation;
    if (json['radiation'] != null) {
      parsedRadiation = RadiationDose.fromJson(
          Map<String, dynamic>.from(json['radiation'] as Map));
      if (astronautId.isNotEmpty) {
        parsedRadiation = parsedRadiation.copyWith(astronautId: astronautId);
      }
    } else {
      parsedRadiation = RadiationDose(
        timestamp: DateTime.now(),
        astronautId: astronautId.isNotEmpty ? astronautId : 'AST-01',
        doseRateMicroSvPerHour: 50.0,
        cumulativeDoseMilliSv: 15.0,
        severity: RadiationSeverity.normal,
      );
    }

    SleepRecord parsedSleep;
    if (json['sleep'] != null) {
      parsedSleep =
          SleepRecord.fromJson(Map<String, dynamic>.from(json['sleep'] as Map));
      if (astronautId.isNotEmpty) {
        parsedSleep = parsedSleep.copyWith(astronautId: astronautId);
      }
    } else {
      parsedSleep = SleepRecord(
        date: DateTime.now(),
        astronautId: astronautId.isNotEmpty ? astronautId : 'AST-01',
        sleepHours: 7.0,
        wakeEpisodes: 0,
        morningMood: MoodLevel.good,
      );
    }

    ExerciseSession parsedExercise;
    if (json['exercise'] != null) {
      parsedExercise = ExerciseSession.fromJson(
          Map<String, dynamic>.from(json['exercise'] as Map));
      if (astronautId.isNotEmpty) {
        parsedExercise = parsedExercise.copyWith(astronautId: astronautId);
      }
    } else {
      parsedExercise = ExerciseSession(
        date: DateTime.now(),
        astronautId: astronautId.isNotEmpty ? astronautId : 'AST-01',
        deviceName: 'ARED',
        durationMinutes: 30,
        caloriesBurned: 300,
        targetReached: true,
      );
    }

    final syncRaw = json['lastTelemetrySync'] ?? json['lastUpdated'];

    return AstronautProfile(
      id: astronautId,
      name: json['name']?.toString() ?? '',
      role: json['role']?.toString() ?? '',
      rank: json['rank']?.toString() ?? '',
      callsign: json['callsign']?.toString() ?? '',
      avatarInitials: json['avatarInitials']?.toString() ?? '',
      age: (json['age'] as num?)?.toInt() ?? 35,
      bloodType: json['bloodType']?.toString() ?? 'O+',
      currentZone: json['currentZone']?.toString() ?? 'Módulo Central',
      vitals: parsedVitals,
      radiation: parsedRadiation,
      sleep: parsedSleep,
      exercise: parsedExercise,
      riskLevel: parsedRisk,
      riskTitle: json['riskTitle']?.toString() ?? 'Estado Nominal',
      riskDescription:
          json['riskDescription']?.toString() ?? 'Sin alertas registradas.',
      activeAlerts:
          (json['activeAlerts'] as List?)?.map((e) => e.toString()).toList() ??
              const [],
      linkedMachineIds: (json['linkedMachineIds'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      lastTelemetrySync:
          syncRaw != null ? DateTime.tryParse(syncRaw.toString()) : null,
    );
  }
}
