import '../../01_general_health/models/vitals_record.dart';
import '../../02_radiation/models/radiation_dose.dart';
import '../../03_microgravity/models/microgravity_data.dart';
import '../../04_mental_health/models/sleep_record.dart';

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
    );
  }
}
