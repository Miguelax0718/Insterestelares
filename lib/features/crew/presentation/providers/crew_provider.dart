import 'package:astramed/core/constants/medical_thresholds.dart';
import 'package:astramed/core/storage/crew_database_service.dart';
import 'package:astramed/features/01_general_health/models/vitals_record.dart';
import 'package:astramed/features/02_radiation/models/radiation_dose.dart';
import 'package:astramed/features/03_microgravity/models/microgravity_data.dart';
import 'package:astramed/features/04_mental_health/models/sleep_record.dart';
import 'package:astramed/features/crew/data/mock_crew_data.dart';
import 'package:astramed/features/crew/models/astronaut_profile.dart';
import 'package:astramed/features/telemetry/models/telemetry_machine.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Notifier que administra el estado de los 5 astronautas de la tripulación
class CrewNotifier extends StateNotifier<List<AstronautProfile>> {
  final CrewDatabaseService _dbService;

  CrewNotifier([CrewDatabaseService? dbService])
      : _dbService = dbService ?? CrewDatabaseService(),
        super(MockCrewData.getInitialCrew());

  /// Inicializa la tripulación cargando datos desde la base de datos `DB/Users/`
  Future<void> initializeFromDatabase() async {
    final loadedCrew = await _dbService.loadCrewFromDbUsers();
    state = loadedCrew;
  }

  /// Vincula un sensor o máquina al perfil del astronauta
  void linkMachine(String astronautId, String machineId) {
    state = [
      for (final profile in state)
        if (profile.id == astronautId)
          profile.copyWith(
            linkedMachineIds: profile.linkedMachineIds.contains(machineId)
                ? profile.linkedMachineIds
                : [...profile.linkedMachineIds, machineId],
          )
        else
          profile,
    ];
  }

  /// Desvincula una máquina del perfil del astronauta
  void unlinkMachine(String astronautId, String machineId) {
    state = [
      for (final profile in state)
        if (profile.id == astronautId)
          profile.copyWith(
            linkedMachineIds: profile.linkedMachineIds
                .where((id) => id != machineId)
                .toList(),
          )
        else
          profile,
    ];
  }

  /// Aplica un paquete de telemetría médica en tiempo real,
  /// actualiza los subsistemas con trazabilidad completa (`astronautId`, `source`, `device`, `protocol`)
  /// y reevalúa automáticamente el triage
  void applyTelemetryPacket(String astronautId, TelemetryPacket packet) {
    final m = packet.metrics;

    state = [
      for (final profile in state)
        if (profile.id == astronautId)
          _processPacketForAstronaut(profile, packet, m)
        else
          profile,
    ];
  }

  /// Procesa los datos del paquete, propaga metadatos y recalcula riesgo clínico
  AstronautProfile _processPacketForAstronaut(
    AstronautProfile profile,
    TelemetryPacket packet,
    Map<String, dynamic> m,
  ) {
    final deviceLabel =
        packet.device.isNotEmpty ? packet.device : packet.machineId;

    // 1. Actualización de Signos Vitales
    VitalsRecord updatedVitals = profile.vitals;
    if (m.containsKey('heartRate') ||
        m.containsKey('systolicBP') ||
        m.containsKey('diastolicBP') ||
        m.containsKey('spO2') ||
        m.containsKey('bodyTemp') ||
        m.containsKey('bloodGlucose') ||
        m.containsKey('respiratoryRate') ||
        m.containsKey('capillaryRefillSeconds')) {
      updatedVitals = profile.vitals.copyWith(
        timestamp: packet.timestamp,
        astronautId: profile.id,
        source: packet.source,
        deviceId: packet.machineId,
        device: deviceLabel,
        protocol: packet.protocol,
        measurementMethod: packet.measurementMethod,
        activityState: packet.activityState,
        signalQuality: packet.signalQuality,
        recordType: packet.recordType,
        algorithm: packet.algorithm,
        criterionReference: packet.criterionReference,
        heartRate:
            (m['heartRate'] as num?)?.toDouble() ?? profile.vitals.heartRate,
        systolicBP:
            (m['systolicBP'] as num?)?.toDouble() ?? profile.vitals.systolicBP,
        diastolicBP: (m['diastolicBP'] as num?)?.toDouble() ??
            profile.vitals.diastolicBP,
        spO2: (m['spO2'] as num?)?.toDouble() ?? profile.vitals.spO2,
        bodyTemp:
            (m['bodyTemp'] as num?)?.toDouble() ?? profile.vitals.bodyTemp,
        bloodGlucose: (m['bloodGlucose'] as num?)?.toDouble() ??
            profile.vitals.bloodGlucose,
        respiratoryRate: (m['respiratoryRate'] as num?)?.toDouble() ??
            profile.vitals.respiratoryRate,
        capillaryRefillSeconds:
            (m['capillaryRefillSeconds'] as num?)?.toDouble() ??
                profile.vitals.capillaryRefillSeconds,
      );
    }

    // 2. Actualización de Dosimetría de Radiación
    RadiationDose updatedRadiation = profile.radiation;
    if (m.containsKey('doseRateMicroSvPerHour') ||
        m.containsKey('cumulativeDoseMilliSv') ||
        m.containsKey('severity')) {
      RadiationSeverity? sev;
      if (m['severity'] != null) {
        final sStr = m['severity'].toString().toLowerCase();
        sev = RadiationSeverity.values.firstWhere(
          (e) => e.name.toLowerCase() == sStr,
          orElse: () => profile.radiation.severity,
        );
      }

      updatedRadiation = profile.radiation.copyWith(
        timestamp: packet.timestamp,
        astronautId: profile.id,
        source: packet.source,
        deviceId: packet.machineId,
        device: deviceLabel,
        protocol: packet.protocol,
        measurementMethod: packet.measurementMethod,
        activityState: packet.activityState,
        signalQuality: packet.signalQuality,
        recordType: packet.recordType,
        algorithm: packet.algorithm,
        criterionReference: packet.criterionReference,
        doseRateMicroSvPerHour:
            (m['doseRateMicroSvPerHour'] as num?)?.toDouble() ??
                profile.radiation.doseRateMicroSvPerHour,
        cumulativeDoseMilliSv:
            (m['cumulativeDoseMilliSv'] as num?)?.toDouble() ??
                profile.radiation.cumulativeDoseMilliSv,
        severity: sev ?? profile.radiation.severity,
      );
    }

    // 3. Actualización de Contramedidas / Ejercicio
    ExerciseSession updatedExercise = profile.exercise;
    if (m.containsKey('durationMinutes') ||
        m.containsKey('caloriesBurned') ||
        m.containsKey('targetReached') ||
        m.containsKey('deviceName')) {
      updatedExercise = profile.exercise.copyWith(
        date: packet.timestamp,
        astronautId: profile.id,
        source: packet.source,
        deviceId: packet.machineId,
        device: deviceLabel,
        protocol: packet.protocol,
        measurementMethod: packet.measurementMethod,
        activityState: packet.activityState,
        signalQuality: packet.signalQuality,
        recordType: packet.recordType,
        algorithm: packet.algorithm,
        criterionReference: packet.criterionReference,
        deviceName: m['deviceName']?.toString() ?? profile.exercise.deviceName,
        durationMinutes: (m['durationMinutes'] as num?)?.toInt() ??
            profile.exercise.durationMinutes,
        caloriesBurned: (m['caloriesBurned'] as num?)?.toDouble() ??
            profile.exercise.caloriesBurned,
        targetReached:
            m['targetReached'] as bool? ?? profile.exercise.targetReached,
      );
    }

    // 4. Actualización de Sueño y Ritmos Circadianos
    SleepRecord updatedSleep = profile.sleep;
    if (m.containsKey('sleepHours') ||
        m.containsKey('wakeEpisodes') ||
        m.containsKey('morningMood')) {
      MoodLevel? mood;
      if (m['morningMood'] != null) {
        final mdStr = m['morningMood'].toString().toLowerCase();
        mood = MoodLevel.values.firstWhere(
          (e) => e.name.toLowerCase() == mdStr,
          orElse: () => profile.sleep.morningMood,
        );
      }

      updatedSleep = profile.sleep.copyWith(
        date: packet.timestamp,
        astronautId: profile.id,
        source: packet.source,
        deviceId: packet.machineId,
        device: deviceLabel,
        protocol: packet.protocol,
        measurementMethod: packet.measurementMethod,
        activityState: packet.activityState,
        signalQuality: packet.signalQuality,
        recordType: packet.recordType,
        algorithm: packet.algorithm,
        criterionReference: packet.criterionReference,
        sleepHours:
            (m['sleepHours'] as num?)?.toDouble() ?? profile.sleep.sleepHours,
        wakeEpisodes: (m['wakeEpisodes'] as num?)?.toInt() ??
            profile.sleep.wakeEpisodes,
        morningMood: mood ?? profile.sleep.morningMood,
      );
    }

    final updatedProfile = _evaluateClinicalTriage(
      profile: profile,
      vitals: updatedVitals,
      radiation: updatedRadiation,
      exercise: updatedExercise,
      sleep: updatedSleep,
      syncTimestamp: packet.timestamp,
      sourceLabel: packet.source == 'manual' ? 'evaluación manual' : 'telemetría',
    );

    _dbService.saveAstronautProfile(updatedProfile);
    return updatedProfile;
  }

  /// Evalúa los umbrales clínicos y genera alertas y triage de manera unificada
  AstronautProfile _evaluateClinicalTriage({
    required AstronautProfile profile,
    required VitalsRecord vitals,
    required RadiationDose radiation,
    required ExerciseSession exercise,
    required SleepRecord sleep,
    required DateTime syncTimestamp,
    required String sourceLabel,
  }) {
    final alerts = <String>[];
    bool isCritical = false;
    bool isWarning = false;

    // SpO2
    if (vitals.spO2 < 90.0) {
      alerts.add('SpO2 Crítico: ${vitals.spO2}% (Hipoxia aguda)');
      isCritical = true;
    } else if (vitals.spO2 < MedicalThresholds.minSpO2) {
      alerts.add('SpO2 Bajo: ${vitals.spO2}% (<${MedicalThresholds.minSpO2}%)');
      isWarning = true;
    }

    // Frecuencia Cardíaca
    if (vitals.heartRate > 115.0) {
      alerts.add(
          'FC Elevada: ${vitals.heartRate.toStringAsFixed(0)} bpm (Taquicardia)');
      isCritical = true;
    } else if (vitals.heartRate > MedicalThresholds.maxHeartRate) {
      alerts.add(
          'FC Elevada: ${vitals.heartRate.toStringAsFixed(0)} bpm (Taquicardia)');
      isWarning = true;
    } else if (vitals.heartRate < 45.0) {
      alerts.add(
          'FC Crítica: ${vitals.heartRate.toStringAsFixed(0)} bpm (Bradicardia severa)');
      isCritical = true;
    } else if (vitals.heartRate < MedicalThresholds.minHeartRate) {
      alerts.add(
          'FC Baja: ${vitals.heartRate.toStringAsFixed(0)} bpm (Bradicardia)');
      isWarning = true;
    }

    // Presión Arterial
    if (vitals.systolicBP < 85.0 || vitals.systolicBP > 160.0) {
      alerts.add(
          'Presión Arterial Crítica: ${vitals.systolicBP.toStringAsFixed(0)}/${vitals.diastolicBP.toStringAsFixed(0)} mmHg');
      isCritical = true;
    } else if (vitals.systolicBP < MedicalThresholds.minSystolicBP) {
      alerts.add(
          'Presión Arterial Baja: ${vitals.systolicBP.toStringAsFixed(0)}/${vitals.diastolicBP.toStringAsFixed(0)} mmHg');
      isWarning = true;
    } else if (vitals.systolicBP > MedicalThresholds.maxSystolicBP ||
        vitals.diastolicBP > 89.0) {
      alerts.add(
          'Presión Arterial: ${vitals.systolicBP.toStringAsFixed(0)}/${vitals.diastolicBP.toStringAsFixed(0)} mmHg');
      isWarning = true;
    }

    // Frecuencia Respiratoria
    if (vitals.respiratoryRate >= 26.0) {
      alerts.add(
          'Frec. Resp: ${vitals.respiratoryRate.toStringAsFixed(0)} rpm (Polipnea)');
      isCritical = true;
    } else if (vitals.respiratoryRate > 22.0) {
      alerts.add(
          'Frec. Resp: ${vitals.respiratoryRate.toStringAsFixed(0)} rpm (Polipnea)');
      isWarning = true;
    }

    // Llenado Capilar
    if (vitals.capillaryRefillSeconds > 2.5) {
      alerts.add(
          'Llenado Capilar: ${vitals.capillaryRefillSeconds}s (Mala perfusión)');
      isCritical = true;
    } else if (vitals.capillaryRefillSeconds > 2.0) {
      alerts.add('Llenado Capilar: ${vitals.capillaryRefillSeconds}s');
      isWarning = true;
    }

    // Temperatura
    if (vitals.bodyTemp > 38.0) {
      alerts.add('Fiebre Alta: ${vitals.bodyTemp} °C');
      isCritical = true;
    } else if (vitals.bodyTemp > 37.3) {
      alerts.add('Temperatura limítrofe: ${vitals.bodyTemp} °C');
      isWarning = true;
    }

    // Radiación
    if (radiation.doseRateMicroSvPerHour > 160.0 ||
        radiation.severity == RadiationSeverity.critical) {
      alerts.add(
          'Tasa de Dosis Crítica: ${radiation.doseRateMicroSvPerHour} uSv/h');
      isCritical = true;
    } else if (radiation.doseRateMicroSvPerHour > 100.0 ||
        radiation.severity == RadiationSeverity.warning) {
      alerts.add('Tasa de Dosis: ${radiation.doseRateMicroSvPerHour} uSv/h');
      isWarning = true;
    }

    // Sueño y descanso
    if (sleep.sleepHours < 5.0) {
      alerts.add('Déficit de descanso severo: ${sleep.sleepHours} hrs');
      isWarning = true;
    } else if (sleep.sleepHours < MedicalThresholds.minRecommendedSleepHours) {
      alerts.add('Déficit de descanso (${sleep.sleepHours} hrs)');
      isWarning = true;
    }

    // Meta física
    if (!exercise.targetReached) {
      alerts.add('Meta física incompleta');
      isWarning = true;
    }

    final CrewRiskLevel riskLevel;
    final String riskTitle;
    final String riskDescription;

    if (isCritical) {
      riskLevel = CrewRiskLevel.critical;
      riskTitle = alerts.isNotEmpty
          ? 'ALERTA CRÍTICA: ${alerts.first.split(':').first}'
          : 'ALERTA CRÍTICA: Emergencia Médica';
      riskDescription =
          'Parámetros vitales fuera de rango seguro para la misión. Se requiere intervención y protocolo inmediato.';
    } else if (isWarning) {
      riskLevel = CrewRiskLevel.warning;
      riskTitle = alerts.isNotEmpty
          ? 'Precaución: ${alerts.first.split(':').first}'
          : 'Precaución: Parámetros Limítrofes';
      riskDescription =
          'Parámetros médicos limítrofes detectados por $sourceLabel. Monitorear evolución y descanso.';
    } else {
      riskLevel = CrewRiskLevel.nominal;
      riskTitle = 'Estado Nominal';
      riskDescription =
          'Biomarcadores estables y adaptación adecuada al vuelo espacial.';
    }

    return profile.copyWith(
      vitals: vitals,
      radiation: radiation,
      exercise: exercise,
      sleep: sleep,
      riskLevel: riskLevel,
      riskTitle: riskTitle,
      riskDescription: riskDescription,
      activeAlerts: alerts,
      lastTelemetrySync: syncTimestamp,
    );
  }

  /// Guarda el perfil actualizado en el almacenamiento local (`DB/Users/` en caché)
  Future<void> saveProfileToDb(String astronautId) async {
    final profile = state.firstWhere(
      (p) => p.id == astronautId,
      orElse: () => state.first,
    );
    await _dbService.saveAstronautProfile(profile);
  }

  /// Exporta el JSON completo de un astronauta listo para `DB/Users/`
  String exportProfileToDbJson(String astronautId) {
    final profile = state.firstWhere(
      (p) => p.id == astronautId,
      orElse: () => state.first,
    );
    return _dbService.exportAstronautJson(profile);
  }

  /// Registra una medición manual de emergencia (ej. sin sensores) con trazabilidad `source: 'manual'`
  void updateVitals(String astronautId, VitalsRecord newVitals) {
    state = [
      for (final profile in state)
        if (profile.id == astronautId)
          () {
            final taggedVitals = newVitals.copyWith(astronautId: astronautId);
            final evaluated = _evaluateClinicalTriage(
              profile: profile,
              vitals: taggedVitals,
              radiation: profile.radiation,
              exercise: profile.exercise,
              sleep: profile.sleep,
              syncTimestamp: taggedVitals.timestamp,
              sourceLabel: taggedVitals.source == 'manual'
                  ? 'evaluación manual'
                  : 'telemetría',
            );
            _dbService.saveAstronautProfile(evaluated);
            return evaluated;
          }()
        else
          profile,
    ];
  }

  /// Actualiza el estado de riesgo y alertas de un astronauta
  void updateRiskStatus({
    required String astronautId,
    required CrewRiskLevel riskLevel,
    required String riskTitle,
    required String riskDescription,
    required List<String> activeAlerts,
  }) {
    state = [
      for (final profile in state)
        if (profile.id == astronautId)
          profile.copyWith(
            riskLevel: riskLevel,
            riskTitle: riskTitle,
            riskDescription: riskDescription,
            activeAlerts: activeAlerts,
          )
        else
          profile,
    ];
  }

  /// Restablece la tripulación a su estado inicial simulado
  void resetToInitial() {
    state = MockCrewData.getInitialCrew();
  }
}

/// Provider de la base de datos de tripulantes
final crewDatabaseServiceProvider = Provider<CrewDatabaseService>((ref) {
  return CrewDatabaseService();
});

/// Provider de la lista de perfiles de la tripulación
final crewMembersProvider =
    StateNotifierProvider<CrewNotifier, List<AstronautProfile>>((ref) {
  final dbService = ref.watch(crewDatabaseServiceProvider);
  return CrewNotifier(dbService);
});

/// Provider que almacena el ID del astronauta actualmente activo/seleccionado
final selectedAstronautIdProvider = StateProvider<String>((ref) {
  return 'AST-01'; // Por defecto inicia con el Comandante Alex Vance
});

/// Provider derivado que expone el objeto completo del astronauta seleccionado
final selectedAstronautProvider = Provider<AstronautProfile>((ref) {
  final crew = ref.watch(crewMembersProvider);
  final selectedId = ref.watch(selectedAstronautIdProvider);

  return crew.firstWhere(
    (profile) => profile.id == selectedId,
    orElse: () => crew.first,
  );
});

/// Contador de astronautas en estado CRÍTICO
final criticalCrewCountProvider = Provider<int>((ref) {
  final crew = ref.watch(crewMembersProvider);
  return crew.where((a) => a.riskLevel == CrewRiskLevel.critical).length;
});

/// Contador de astronautas en estado de PRECAUCIÓN
final warningCrewCountProvider = Provider<int>((ref) {
  final crew = ref.watch(crewMembersProvider);
  return crew.where((a) => a.riskLevel == CrewRiskLevel.warning).length;
});

/// Contador de astronautas en estado NOMINAL
final nominalCrewCountProvider = Provider<int>((ref) {
  final crew = ref.watch(crewMembersProvider);
  return crew.where((a) => a.riskLevel == CrewRiskLevel.nominal).length;
});
