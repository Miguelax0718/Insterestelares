import 'package:astramed/features/01_general_health/models/vitals_record.dart';
import 'package:astramed/features/02_radiation/models/radiation_dose.dart';
import 'package:astramed/features/03_microgravity/models/microgravity_data.dart';
import 'package:astramed/features/04_mental_health/models/sleep_record.dart';
import 'package:astramed/features/crew/models/astronaut_profile.dart';

/// Base de datos inicial con los 5 astronautas de la misión espacial
class MockCrewData {
  static List<AstronautProfile> getInitialCrew() {
    final now = DateTime.now();

    return [
      // 1. COMANDANTE DE MISIÓN (ESTABLE / NOMINAL)
      AstronautProfile(
        id: 'AST-01',
        name: 'Alex Vance',
        role: 'Comandante de Misión',
        rank: 'Cmdte. / Piloto Senior',
        callsign: 'ARES-1',
        avatarInitials: 'AV',
        age: 46,
        bloodType: 'O+',
        currentZone: 'Módulo de Comando (Destiny)',
        vitals: VitalsRecord(
          timestamp: now,
          heartRate: 68.0,
          systolicBP: 118.0,
          diastolicBP: 76.0,
          spO2: 99.0,
          bodyTemp: 36.6,
          bloodGlucose: 95.0,
          respiratoryRate: 14.0,
          capillaryRefillSeconds: 1.4,
        ),
        radiation: RadiationDose(
          timestamp: now,
          doseRateMicroSvPerHour: 58.2,
          cumulativeDoseMilliSv: 18.4,
          severity: RadiationSeverity.normal,
        ),
        sleep: SleepRecord(
          date: now,
          sleepHours: 7.5,
          wakeEpisodes: 0,
          morningMood: MoodLevel.great,
        ),
        exercise: ExerciseSession(
          date: now,
          deviceName: 'ARED (Resistencia muscular)',
          durationMinutes: 45,
          caloriesBurned: 420.0,
          targetReached: true,
        ),
        riskLevel: CrewRiskLevel.nominal,
        riskTitle: 'Estado Nominal',
        riskDescription: 'Biomarcadores estables y adaptación adecuada al vuelo espacial.',
        activeAlerts: const [],
      ),

      // 2. OFICIAL MÉDICO (PRECAUCIÓN / FATIGA)
      AstronautProfile(
        id: 'AST-02',
        name: 'Dra. Elena Ramos',
        role: 'Oficial Médico (CMO)',
        rank: 'Cirujana de Vuelo',
        callsign: 'ATHENA',
        avatarInitials: 'ER',
        age: 38,
        bloodType: 'A+',
        currentZone: 'Bahía Médica / Módulo Harmony',
        vitals: VitalsRecord(
          timestamp: now,
          heartRate: 88.0,
          systolicBP: 130.0,
          diastolicBP: 84.0,
          spO2: 96.0,
          bodyTemp: 37.4,
          bloodGlucose: 106.0,
          respiratoryRate: 18.0,
          capillaryRefillSeconds: 1.8,
        ),
        radiation: RadiationDose(
          timestamp: now,
          doseRateMicroSvPerHour: 74.0,
          cumulativeDoseMilliSv: 29.5,
          severity: RadiationSeverity.normal,
        ),
        sleep: SleepRecord(
          date: now,
          sleepHours: 5.1,
          wakeEpisodes: 2,
          morningMood: MoodLevel.fatigued,
        ),
        exercise: ExerciseSession(
          date: now,
          deviceName: 'CEVIS (Bicicleta ergométrica)',
          durationMinutes: 30,
          caloriesBurned: 280.0,
          targetReached: false,
        ),
        riskLevel: CrewRiskLevel.warning,
        riskTitle: 'Precaución: Fatiga y Febrícula',
        riskDescription: 'Déficit de sueño acumulado (<6h) y leve incremento térmico (37.4°C).',
        activeAlerts: const [
          'Déficit de descanso (5.1 hrs)',
          'Temperatura limítrofe (37.4 °C)',
          'Meta física incompleta',
        ],
      ),

      // 3. ESPECIALISTA EVA (EMERGENCIA CRÍTICA / HIPOXIA & TAQUICARDIA)
      AstronautProfile(
        id: 'AST-03',
        name: 'Ing. Mateo Torres',
        role: 'Ingeniero de Vuelo / EVA',
        rank: 'Especialista de Misión 1',
        callsign: 'SPARK',
        avatarInitials: 'MT',
        age: 34,
        bloodType: 'B+',
        currentZone: 'Esclusa Quest (Post-EVA)',
        vitals: VitalsRecord(
          timestamp: now,
          heartRate: 118.0, // Taquicardia
          systolicBP: 92.0,  // Hipotensión
          diastolicBP: 58.0,
          spO2: 89.0,        // Hipoxia aguda
          bodyTemp: 36.1,
          bloodGlucose: 82.0,
          respiratoryRate: 26.0, // Polipnea
          capillaryRefillSeconds: 2.8, // Llenado lento
        ),
        radiation: RadiationDose(
          timestamp: now,
          doseRateMicroSvPerHour: 185.0,
          cumulativeDoseMilliSv: 64.2,
          severity: RadiationSeverity.warning,
        ),
        sleep: SleepRecord(
          date: now,
          sleepHours: 4.5,
          wakeEpisodes: 3,
          morningMood: MoodLevel.stressed,
        ),
        exercise: ExerciseSession(
          date: now,
          deviceName: 'Caminata Espacial EVA 6.5h',
          durationMinutes: 390,
          caloriesBurned: 1850.0,
          targetReached: true,
        ),
        riskLevel: CrewRiskLevel.critical,
        riskTitle: 'ALERTA CRÍTICA: Hipoxia Post-EVA',
        riskDescription: 'Desaturación severa (SpO2 89%), taquicardia refleja y llenado capilar retardado. Protocolo O2 inmediato.',
        activeAlerts: const [
          'SpO2 Crítico: 89% (Hipoxia aguda)',
          'FC Elevada: 118 bpm (Taquicardia)',
          'Frec. Resp: 26 rpm (Polipnea)',
          'Llenado Capilar: 2.8s (Mala perfusión)',
        ],
      ),

      // 4. ESPECIALISTA EN CIENCIAS (ESTABLE / NOMINAL)
      AstronautProfile(
        id: 'AST-04',
        name: 'Dra. Sarah Chen',
        role: 'Bioquímica & Cargas Útiles',
        rank: 'Especialista de Misión 2',
        callsign: 'NOVA',
        avatarInitials: 'SC',
        age: 31,
        bloodType: 'O-',
        currentZone: 'Laboratorio Columbus',
        vitals: VitalsRecord(
          timestamp: now,
          heartRate: 72.0,
          systolicBP: 115.0,
          diastolicBP: 75.0,
          spO2: 98.0,
          bodyTemp: 36.7,
          bloodGlucose: 91.0,
          respiratoryRate: 15.0,
          capillaryRefillSeconds: 1.5,
        ),
        radiation: RadiationDose(
          timestamp: now,
          doseRateMicroSvPerHour: 61.5,
          cumulativeDoseMilliSv: 19.8,
          severity: RadiationSeverity.normal,
        ),
        sleep: SleepRecord(
          date: now,
          sleepHours: 7.2,
          wakeEpisodes: 1,
          morningMood: MoodLevel.good,
        ),
        exercise: ExerciseSession(
          date: now,
          deviceName: 'T2 (Cinta de correr con arnés)',
          durationMinutes: 40,
          caloriesBurned: 350.0,
          targetReached: true,
        ),
        riskLevel: CrewRiskLevel.nominal,
        riskTitle: 'Estado Nominal',
        riskDescription: 'Condición física óptima y parámetros biomédicos en balance.',
        activeAlerts: const [],
      ),

      // 5. TÉCNICO EN ROBÓTICA (PRECAUCIÓN / PREHIPERTENSIÓN & RADIACIÓN)
      AstronautProfile(
        id: 'AST-05',
        name: 'Téc. Leo Morales',
        role: 'Robótica & Soporte Vital (ECLSS)',
        rank: 'Especialista de Misión 3',
        callsign: 'TITAN',
        avatarInitials: 'LM',
        age: 36,
        bloodType: 'AB+',
        currentZone: 'Módulo Kibo / Cúpula de Observación',
        vitals: VitalsRecord(
          timestamp: now,
          heartRate: 94.0,
          systolicBP: 138.0, // Prehipertensión
          diastolicBP: 90.0,
          spO2: 95.0,
          bodyTemp: 36.9,
          bloodGlucose: 122.0,
          respiratoryRate: 19.0,
          capillaryRefillSeconds: 1.9,
        ),
        radiation: RadiationDose(
          timestamp: now,
          doseRateMicroSvPerHour: 112.0,
          cumulativeDoseMilliSv: 44.5,
          severity: RadiationSeverity.warning,
        ),
        sleep: SleepRecord(
          date: now,
          sleepHours: 6.0,
          wakeEpisodes: 2,
          morningMood: MoodLevel.neutral,
        ),
        exercise: ExerciseSession(
          date: now,
          deviceName: 'ARED (Resistencia)',
          durationMinutes: 35,
          caloriesBurned: 310.0,
          targetReached: true,
        ),
        riskLevel: CrewRiskLevel.warning,
        riskTitle: 'Precaución: Presión y Dosis Alta',
        riskDescription: 'Presión arterial limítrofe (138/90) y proximidad a áreas de mayor radiación.',
        activeAlerts: const [
          'Presión Arterial: 138/90 mmHg',
          'Tasa de Dosis: 112 uSv/h',
        ],
      ),
    ];
  }
}
