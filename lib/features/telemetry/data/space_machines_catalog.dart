import 'dart:math' as math;

import 'package:astramed/features/crew/models/astronaut_profile.dart';
import 'package:astramed/features/telemetry/models/telemetry_machine.dart';

/// Catálogo central de dispositivos de telemetría y sensores médicos espaciales
class SpaceMachinesCatalog {
  /// Lista estática base con la especificación técnica y clínica de las 7 máquinas certificadas
  static List<TelemetryMachine> getCatalogDefinitions() {
    return const [
      // 1. CHALECO BIOMÉTRICO CONTINUO
      TelemetryMachine(
        id: 'DEV-ASTROSKIN',
        name: 'Bio-Monitor Astroskin',
        code: 'ASTROSKIN-V3',
        category: MachineCategory.biometrics,
        protocol: 'ANT+ / BLE SpaceBus v3.2',
        measurementMethod:
            'ECG textil de 3 derivaciones, fotopletismografía óptica y pletismografía inductiva torácica',
        defaultActivityState: 'active_duty',
        defaultRecordType: 'instrumental',
        algorithm: 'NASA-HRP BioSignalKalman v3.2',
        criterionReference: 'NASA-STD-3001 Vol. 1 & Vol. 2 / MedicalThresholds',
        description:
            'Chaleco biométrico continuo con sensores textiles de ECG, frecuencia respiratoria, volumen corriente, acelerometría triaxial y temperatura cutánea.',
        supportedMetrics: [
          'heartRate',
          'respiratoryRate',
          'systolicBP',
          'diastolicBP',
          'bodyTemp',
          'spO2',
          'capillaryRefillSeconds',
        ],
        batteryPercent: 92,
        signalPercent: 98,
      ),

      // 2. DOSÍMETRO DE RADIACIÓN ACTIVA
      TelemetryMachine(
        id: 'DEV-HERA',
        name: 'HERA Radiation Assay',
        code: 'HERA-TPX3',
        category: MachineCategory.dosimetry,
        protocol: 'MIL-STD-1553B / Timepix bus',
        measurementMethod:
            'Espectrometría activa en silicio híbrido Timepix3 (LET)',
        defaultActivityState: 'active_duty',
        defaultRecordType: 'instrumental',
        algorithm: 'SRAG-LET-Dosimetry v2.4',
        criterionReference: 'NASA-STD-3001 Permissible Exposure Limits (PEL)',
        description:
            'Dosímetro personal y de área de silicio activo basado en tecnología Timepix. Mide tasa de dosis instantánea en microSieverts por hora y dosis acumulada de partículas pesadas y rayos cósmicos.',
        supportedMetrics: [
          'doseRateMicroSvPerHour',
          'cumulativeDoseMilliSv',
          'severity',
        ],
        batteryPercent: 88,
        signalPercent: 95,
      ),

      // 3. MÓDULO CARDIOVASCULAR Y HEMODINÁMICA
      TelemetryMachine(
        id: 'DEV-EPM',
        name: 'EPM Cardiocavity Module',
        code: 'EPM-HEMO-2',
        category: MachineCategory.hemodynamics,
        protocol: 'SpaceWire / ISS-LAN',
        measurementMethod:
            'Fotopletismografía arterial de dedo y tonometría cardiovascular no invasiva',
        defaultActivityState: 'resting',
        defaultRecordType: 'instrumental',
        algorithm: 'ESA-EPM HemodynamicPulseWave v2.0',
        criterionReference: 'NASA-STD-3001 Cardiovascular Health Monitoring',
        description:
            'Módulo de diagnóstico cardiovascular, ultrasonido vascular periférico y medición no invasiva de presión venosa central y gasto cardíaco.',
        supportedMetrics: [
          'systolicBP',
          'diastolicBP',
          'heartRate',
          'capillaryRefillSeconds',
        ],
        batteryPercent: 100,
        signalPercent: 99,
      ),

      // 4. MÁQUINA DE EJERCICIO RESISTIVO (ARED)
      TelemetryMachine(
        id: 'DEV-ARED',
        name: 'ARED Advanced Resistive Device',
        code: 'ARED-CYL-1',
        category: MachineCategory.countermeasure,
        protocol: 'CAN-Bus / Space Wireless',
        measurementMethod:
            'Dinamometría en cilindros de vacío y telemetría cinemática triaxial',
        defaultActivityState: 'exercise',
        defaultRecordType: 'estimación',
        algorithm: 'NASA-CountermeasureMetabolicKinematics v1.8',
        criterionReference:
            'NASA-STD-3001 Musculoskeletal Countermeasure Protocol',
        description:
            'Dispositivo de ejercicio resistivo avanzado con cilindros de vacío para emular cargas de hasta 270 kg. Registra repeticiones, fuerza de carga pico y gasto calórico.',
        supportedMetrics: [
          'deviceName',
          'durationMinutes',
          'caloriesBurned',
          'targetReached',
        ],
        batteryPercent: 94,
        signalPercent: 91,
      ),

      // 5. CICLOERGÓMETRO (CEVIS)
      TelemetryMachine(
        id: 'DEV-CEVIS',
        name: 'CEVIS Cycle Ergometer',
        code: 'CEVIS-ERG-4',
        category: MachineCategory.countermeasure,
        protocol: 'RS-422 / BLE 5.0',
        measurementMethod:
            'Ergometría electromagnética de cadencia/potencia y estimación de VO2',
        defaultActivityState: 'exercise',
        defaultRecordType: 'estimación',
        algorithm: 'NASA-CEVIS AerobicVO2Estimator v1.5',
        criterionReference: 'NASA-STD-3001 Aerobic Countermeasure Protocol',
        description:
            'Cicloergómetro con aislamiento de vibración para entrenamiento cardiovascular aeróbico en microgravedad. Registra potencia en vatios, cadencia y consumo energético.',
        supportedMetrics: [
          'deviceName',
          'durationMinutes',
          'caloriesBurned',
          'targetReached',
          'heartRate',
        ],
        batteryPercent: 85,
        signalPercent: 93,
      ),

      // 6. ANALIZADOR DE SANGRE PORTÁTIL
      TelemetryMachine(
        id: 'DEV-ISTAT',
        name: 'Abbott i-STAT 1 Analyzer',
        code: 'ISTAT-CHEM-8',
        category: MachineCategory.bloodLab,
        protocol: 'Infrared Data / USB Secure Bus',
        measurementMethod:
            'Electroquímica amperométrica/potenciométrica en cartucho capilar desechable',
        defaultActivityState: 'resting',
        defaultRecordType: 'instrumental',
        algorithm: 'PointOfCare-Chem8 CalibrationCurve v4.1',
        criterionReference: 'NASA-ISS CHeCS Clinical Blood Lab Standards',
        description:
            'Analizador de sangre clínico portátil de cartuchos micrométricos. Entrega electrolitos, gases en sangre, lactato, hematocrito y glucemia capilar en 2 minutos.',
        supportedMetrics: [
          'bloodGlucose',
          'spO2',
        ],
        batteryPercent: 78,
        signalPercent: 89,
      ),

      // 7. MONITOR CIRCADIANO Y DE SUEÑO
      TelemetryMachine(
        id: 'DEV-ACTIWATCH',
        name: 'Actiwatch Plus Circadian Sensor',
        code: 'ACTI-PLUS-7',
        category: MachineCategory.circadian,
        protocol: 'NFC / Optical Sync',
        measurementMethod:
            'Actigrafía triaxial de muñeca, fotometría ambiental y escala subjetiva matutina',
        defaultActivityState: 'sleep',
        defaultRecordType: 'instrumental',
        algorithm: 'BHP-CircadianColeKripke v2.1',
        criterionReference:
            'NASA-STD-3001 Behavioral Health & Circadian Standard',
        description:
            'Monitor de muñeca de espectro de luz y actigrafía multieje para seguimiento objetivo de ciclos sueño/vigilia, latencia y episodios de despertar en órbita.',
        supportedMetrics: [
          'sleepHours',
          'wakeEpisodes',
          'morningMood',
        ],
        batteryPercent: 96,
        signalPercent: 97,
      ),
    ];
  }

  /// Inicializa las 7 máquinas enlazadas con los astronautas según sus linkedMachineIds
  static List<TelemetryMachine> getInitialMachines(List<AstronautProfile> crew) {
    final baseDefinitions = getCatalogDefinitions();
    final initializedMachines = <TelemetryMachine>[];

    for (final def in baseDefinitions) {
      final statusMap = <String, MachineConnectionStatus>{};
      final packetMap = <String, TelemetryPacket>{};

      for (final astronaut in crew) {
        final isLinked = astronaut.linkedMachineIds.contains(def.id);
        if (isLinked) {
          statusMap[astronaut.id] = MachineConnectionStatus.streaming;
          packetMap[astronaut.id] = generateTelemetryPacket(def, astronaut, tick: 0);
        } else {
          statusMap[astronaut.id] = MachineConnectionStatus.disconnected;
        }
      }

      initializedMachines.add(
        def.copyWith(
          statusByAstronaut: statusMap,
          lastPacketByAstronaut: packetMap,
        ),
      );
    }

    return initializedMachines;
  }

  /// Genera un paquete de telemetría médica coherente y realista con los 9 metadatos exigidos
  static TelemetryPacket generateTelemetryPacket(
    TelemetryMachine machine,
    AstronautProfile astronaut, {
    int tick = 0,
  }) {
    final now = DateTime.now();
    final metrics = <String, dynamic>{};

    switch (machine.id) {
      case 'DEV-ASTROSKIN':
        final hrDelta = (math.sin(tick * 0.5) * 1.5).roundToDouble();
        final finalHr = (astronaut.vitals.heartRate + hrDelta).clamp(40.0, 180.0);

        final sysDelta = (math.sin(tick * 0.3) * 1.2).roundToDouble();
        final diaDelta = (math.cos(tick * 0.3) * 0.8).roundToDouble();
        final finalSys = (astronaut.vitals.systolicBP + sysDelta).clamp(70.0, 200.0);
        final finalDia = (astronaut.vitals.diastolicBP + diaDelta).clamp(40.0, 130.0);

        double finalSpO2;
        if (astronaut.vitals.spO2 < 92.0) {
          finalSpO2 =
              (astronaut.vitals.spO2 + (math.sin(tick * 0.4) * 0.6)).clamp(85.0, 91.0);
        } else {
          finalSpO2 =
              (astronaut.vitals.spO2 + (math.sin(tick * 0.2) * 0.3)).clamp(94.0, 100.0);
        }

        final tempDelta = math.sin(tick * 0.1) * 0.04;
        final finalTemp =
            double.parse((astronaut.vitals.bodyTemp + tempDelta).toStringAsFixed(1));

        final respDelta = (math.sin(tick * 0.4) * 0.8).roundToDouble();
        final finalResp =
            (astronaut.vitals.respiratoryRate + respDelta).clamp(8.0, 40.0);

        metrics['heartRate'] = finalHr;
        metrics['systolicBP'] = finalSys;
        metrics['diastolicBP'] = finalDia;
        metrics['spO2'] = double.parse(finalSpO2.toStringAsFixed(1));
        metrics['bodyTemp'] = finalTemp;
        metrics['respiratoryRate'] = finalResp;
        metrics['capillaryRefillSeconds'] = astronaut.vitals.capillaryRefillSeconds;
        break;

      case 'DEV-HERA':
        final rateDelta = math.sin(tick * 0.7) * 2.2;
        final finalRate =
            (astronaut.radiation.doseRateMicroSvPerHour + rateDelta).clamp(10.0, 800.0);
        final finalCumulative =
            astronaut.radiation.cumulativeDoseMilliSv + (tick * 0.0002);

        metrics['doseRateMicroSvPerHour'] =
            double.parse(finalRate.toStringAsFixed(1));
        metrics['cumulativeDoseMilliSv'] =
            double.parse(finalCumulative.toStringAsFixed(3));
        metrics['severity'] = astronaut.radiation.severity.name;
        break;

      case 'DEV-EPM':
        final sysDelta = (math.sin(tick * 0.4) * 1.5).roundToDouble();
        final diaDelta = (math.cos(tick * 0.4) * 1.0).roundToDouble();
        final hrDelta = (math.sin(tick * 0.5) * 1.0).roundToDouble();

        metrics['systolicBP'] =
            (astronaut.vitals.systolicBP + sysDelta).clamp(70.0, 200.0);
        metrics['diastolicBP'] =
            (astronaut.vitals.diastolicBP + diaDelta).clamp(40.0, 130.0);
        metrics['heartRate'] =
            (astronaut.vitals.heartRate + hrDelta).clamp(40.0, 180.0);
        metrics['capillaryRefillSeconds'] = astronaut.vitals.capillaryRefillSeconds;
        break;

      case 'DEV-ARED':
        final calBonus = ((tick % 6) * 1.5).roundToDouble();
        metrics['deviceName'] = 'ARED (Resistencia)';
        metrics['durationMinutes'] = astronaut.exercise.durationMinutes;
        metrics['caloriesBurned'] = astronaut.exercise.caloriesBurned + calBonus;
        metrics['targetReached'] = astronaut.exercise.targetReached;
        break;

      case 'DEV-CEVIS':
        final calBonus = ((tick % 5) * 2.0).roundToDouble();
        metrics['deviceName'] = 'CEVIS (Bicicleta)';
        metrics['durationMinutes'] = astronaut.exercise.durationMinutes;
        metrics['caloriesBurned'] = astronaut.exercise.caloriesBurned + calBonus;
        metrics['targetReached'] = astronaut.exercise.targetReached;
        metrics['heartRate'] = astronaut.vitals.heartRate + 2.0;
        break;

      case 'DEV-ISTAT':
        final gluDelta = math.sin(tick * 0.3) * 1.2;
        final finalGlu =
            (astronaut.vitals.bloodGlucose + gluDelta).clamp(50.0, 300.0);
        metrics['bloodGlucose'] = double.parse(finalGlu.toStringAsFixed(1));
        metrics['spO2'] = astronaut.vitals.spO2;
        break;

      case 'DEV-ACTIWATCH':
        metrics['sleepHours'] = astronaut.sleep.sleepHours;
        metrics['wakeEpisodes'] = astronaut.sleep.wakeEpisodes;
        metrics['morningMood'] = astronaut.sleep.morningMood.name;
        break;

      default:
        metrics['status'] = 'nominal';
        break;
    }

    final resolvedSignalQuality = machine.signalPercent >= 90
        ? 'optimal (${machine.signalPercent}%)'
        : (machine.signalPercent >= 75
            ? 'good (${machine.signalPercent}%)'
            : 'degraded (${machine.signalPercent}%)');

    final resolvedActivityState =
        astronaut.currentZone.toLowerCase().contains('eva') &&
                machine.defaultActivityState == 'active_duty'
            ? 'post_eva'
            : machine.defaultActivityState;

    return TelemetryPacket(
      timestamp: now,
      machineId: machine.id,
      astronautId: astronaut.id,
      source: 'telemetry',
      device: machine.name,
      protocol: machine.protocol,
      measurementMethod: machine.measurementMethod,
      activityState: resolvedActivityState,
      signalQuality: resolvedSignalQuality,
      recordType: machine.defaultRecordType,
      algorithm: machine.algorithm,
      criterionReference: machine.criterionReference,
      metrics: metrics,
    );
  }
}
