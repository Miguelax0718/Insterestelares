import 'package:flutter_test/flutter_test.dart';

import 'package:astramed/core/storage/crew_database_service.dart';
import 'package:astramed/features/01_general_health/models/vitals_record.dart';
import 'package:astramed/features/02_radiation/models/radiation_dose.dart';
import 'package:astramed/features/03_microgravity/models/microgravity_data.dart';
import 'package:astramed/features/04_mental_health/models/sleep_record.dart';
import 'package:astramed/features/05_clinical_triage/models/triage_decision.dart';
import 'package:astramed/features/crew/data/mock_crew_data.dart';
import 'package:astramed/features/crew/models/astronaut_profile.dart';
import 'package:astramed/features/crew/presentation/providers/crew_provider.dart';
import 'package:astramed/features/telemetry/data/space_machines_catalog.dart';
import 'package:astramed/features/telemetry/models/telemetry_machine.dart';

void main() {
  test('Domain models preserve and round-trip all 9 telemetry and clinical metadata fields', () {
    final vitals = VitalsRecord(
      timestamp: DateTime.parse('2026-11-14T12:00:00Z'),
      astronautId: 'AST-02',
      source: 'telemetry',
      deviceId: 'DEV-ASTROSKIN',
      device: 'Bio-Monitor Astroskin',
      protocol: 'ANT+ / BLE SpaceBus v3.2',
      measurementMethod:
          'ECG textil de 3 derivaciones, fotopletismografía óptica y pletismografía inductiva torácica',
      activityState: 'active_duty',
      signalQuality: 'optimal (98%)',
      recordType: 'instrumental',
      algorithm: 'NASA-HRP BioSignalKalman v3.2',
      criterionReference: 'NASA-STD-3001 Vol. 1 & Vol. 2 / MedicalThresholds',
      heartRate: 75.0,
      systolicBP: 120.0,
      diastolicBP: 80.0,
      spO2: 98.0,
      bodyTemp: 36.6,
      bloodGlucose: 92.0,
      respiratoryRate: 16.0,
      capillaryRefillSeconds: 1.5,
    );
    final vitalsFromJson = VitalsRecord.fromJson(vitals.toJson());
    expect(vitalsFromJson.astronautId, 'AST-02');
    expect(vitalsFromJson.source, 'telemetry');
    expect(vitalsFromJson.deviceId, 'DEV-ASTROSKIN');
    expect(vitalsFromJson.device, 'Bio-Monitor Astroskin');
    expect(
      vitalsFromJson.measurementMethod,
      contains('ECG textil de 3 derivaciones'),
    );
    expect(vitalsFromJson.activityState, 'active_duty');
    expect(vitalsFromJson.signalQuality, 'optimal (98%)');
    expect(vitalsFromJson.recordType, 'instrumental');
    expect(vitalsFromJson.algorithm, 'NASA-HRP BioSignalKalman v3.2');
    expect(
      vitalsFromJson.criterionReference,
      'NASA-STD-3001 Vol. 1 & Vol. 2 / MedicalThresholds',
    );
    expect(vitalsFromJson.heartRate, 75.0);

    final rad = RadiationDose(
      timestamp: DateTime.parse('2026-11-14T12:00:00Z'),
      astronautId: 'AST-03',
      source: 'telemetry',
      deviceId: 'DEV-HERA',
      device: 'HERA Radiation Assay',
      protocol: 'MIL-STD-1553B / Timepix bus',
      measurementMethod: 'Espectrometría activa en silicio híbrido Timepix3 (LET)',
      activityState: 'post_eva',
      signalQuality: 'optimal (95%)',
      recordType: 'instrumental',
      algorithm: 'SRAG-LET-Dosimetry v2.4',
      criterionReference: 'NASA-STD-3001 Permissible Exposure Limits (PEL)',
      doseRateMicroSvPerHour: 60.0,
      cumulativeDoseMilliSv: 20.0,
      severity: RadiationSeverity.normal,
    );
    final radFromJson = RadiationDose.fromJson(rad.toJson());
    expect(radFromJson.astronautId, 'AST-03');
    expect(radFromJson.source, 'telemetry');
    expect(radFromJson.device, 'HERA Radiation Assay');
    expect(radFromJson.deviceId, 'DEV-HERA');
    expect(radFromJson.measurementMethod, contains('Timepix3'));
    expect(radFromJson.activityState, 'post_eva');
    expect(radFromJson.signalQuality, 'optimal (95%)');
    expect(radFromJson.recordType, 'instrumental');
    expect(radFromJson.algorithm, 'SRAG-LET-Dosimetry v2.4');
    expect(
      radFromJson.criterionReference,
      'NASA-STD-3001 Permissible Exposure Limits (PEL)',
    );
    expect(radFromJson.severity, RadiationSeverity.normal);

    final ex = ExerciseSession(
      date: DateTime.parse('2026-11-14T12:00:00Z'),
      astronautId: 'AST-01',
      source: 'telemetry',
      deviceId: 'DEV-ARED',
      device: 'ARED Advanced Resistive Device',
      protocol: 'CAN-Bus / Space Wireless',
      measurementMethod: 'Dinamometría en cilindros de vacío y telemetría cinemática triaxial',
      activityState: 'exercise',
      signalQuality: 'optimal (94%)',
      recordType: 'estimación',
      algorithm: 'NASA-CountermeasureMetabolicKinematics v1.8',
      criterionReference: 'NASA-STD-3001 Musculoskeletal Countermeasure Protocol',
      deviceName: 'ARED',
      durationMinutes: 45,
      caloriesBurned: 400.0,
      targetReached: true,
    );
    final exFromJson = ExerciseSession.fromJson(ex.toJson());
    expect(exFromJson.astronautId, 'AST-01');
    expect(exFromJson.source, 'telemetry');
    expect(exFromJson.device, 'ARED Advanced Resistive Device');
    expect(exFromJson.deviceId, 'DEV-ARED');
    expect(exFromJson.measurementMethod, contains('Dinamometría'));
    expect(exFromJson.activityState, 'exercise');
    expect(exFromJson.signalQuality, 'optimal (94%)');
    expect(exFromJson.recordType, 'estimación');
    expect(
      exFromJson.algorithm,
      'NASA-CountermeasureMetabolicKinematics v1.8',
    );
    expect(
      exFromJson.criterionReference,
      'NASA-STD-3001 Musculoskeletal Countermeasure Protocol',
    );
    expect(exFromJson.durationMinutes, 45);

    final sleep = SleepRecord(
      date: DateTime.parse('2026-11-14T12:00:00Z'),
      astronautId: 'AST-04',
      source: 'manual',
      deviceId: 'MANUAL-SLEEP-LOG',
      device: 'Registro Diario de Sueño',
      protocol: 'Registro Manual Tripulación',
      measurementMethod: 'Bitácora de autopercepción de descanso y estado de ánimo matutino',
      activityState: 'sleep',
      signalQuality: 'manual_verified',
      recordType: 'subjetiva',
      algorithm: 'BHP-SubjectiveSleepDiary v1.2',
      criterionReference: 'NASA-STD-3001 Behavioral Health & Circadian Standard',
      sleepHours: 7.5,
      wakeEpisodes: 0,
      morningMood: MoodLevel.great,
    );
    final sleepFromJson = SleepRecord.fromJson(sleep.toJson());
    expect(sleepFromJson.astronautId, 'AST-04');
    expect(sleepFromJson.source, 'manual');
    expect(sleepFromJson.device, 'Registro Diario de Sueño');
    expect(sleepFromJson.measurementMethod, contains('autopercepción'));
    expect(sleepFromJson.activityState, 'sleep');
    expect(sleepFromJson.signalQuality, 'manual_verified');
    expect(sleepFromJson.recordType, 'subjetiva');
    expect(sleepFromJson.algorithm, 'BHP-SubjectiveSleepDiary v1.2');
    expect(
      sleepFromJson.criterionReference,
      'NASA-STD-3001 Behavioral Health & Circadian Standard',
    );

    const triage = TriageResult(
      conditionName: 'Hipoxia Aguda Post-EVA',
      priority: TriagePriority.red,
      immediateActions: ['Administrar O2 al 100%'],
      requiredSupplies: ['Mascarilla de O2'],
    );
    expect(triage.algorithm, 'DeterministicClinicalDecisionTree v1.0');
    expect(
      triage.criterionReference,
      'NASA-STD-3001 Space Medicine Emergency Protocol',
    );
  });

  test('CrewNotifier applies telemetry and manual records with full provenance', () {
    final dbService = CrewDatabaseService();
    final crewNotifier = CrewNotifier(dbService);
    final crew = MockCrewData.getInitialCrew();
    expect(crew.length, 5);

    final machines = SpaceMachinesCatalog.getInitialMachines(crew);
    expect(machines.length, 7);

    final packet = SpaceMachinesCatalog.generateTelemetryPacket(
      machines.first,
      crew[0],
      tick: 1,
    );
    expect(packet.astronautId, 'AST-01');
    expect(packet.source, 'telemetry');
    expect(packet.device, 'Bio-Monitor Astroskin');
    expect(packet.measurementMethod, contains('ECG textil'));
    expect(packet.activityState, 'active_duty');
    expect(packet.signalQuality, contains('98%'));
    expect(packet.recordType, 'instrumental');
    expect(packet.algorithm, 'NASA-HRP BioSignalKalman v3.2');
    expect(
      packet.criterionReference,
      'NASA-STD-3001 Vol. 1 & Vol. 2 / MedicalThresholds',
    );

    final evaPacket = SpaceMachinesCatalog.generateTelemetryPacket(
      machines.first,
      crew[2], // AST-03 en Esclusa Quest (Post-EVA)
      tick: 1,
    );
    expect(evaPacket.activityState, 'post_eva');

    final recoveryPacket = TelemetryPacket(
      timestamp: DateTime.now(),
      machineId: 'DEV-ASTROSKIN',
      astronautId: 'AST-03',
      source: 'telemetry',
      device: 'Bio-Monitor Astroskin',
      protocol: 'ANT+ / BLE SpaceBus v3.2',
      measurementMethod:
          'ECG textil de 3 derivaciones, fotopletismografía óptica y pletismografía inductiva torácica',
      activityState: 'resting',
      signalQuality: 'optimal (98%)',
      recordType: 'instrumental',
      algorithm: 'NASA-HRP BioSignalKalman v3.2',
      criterionReference: 'NASA-STD-3001 Vol. 1 & Vol. 2 / MedicalThresholds',
      metrics: const {
        'heartRate': 72.0,
        'systolicBP': 118.0,
        'diastolicBP': 78.0,
        'spO2': 98.5,
        'bodyTemp': 36.6,
        'respiratoryRate': 15.0,
        'capillaryRefillSeconds': 1.4,
      },
    );

    crewNotifier.applyTelemetryPacket('AST-03', recoveryPacket);
    final ast3AfterVitals =
        crewNotifier.state.firstWhere((a) => a.id == 'AST-03');
    expect(ast3AfterVitals.vitals.spO2, 98.5);
    expect(ast3AfterVitals.vitals.astronautId, 'AST-03');
    expect(ast3AfterVitals.vitals.source, 'telemetry');
    expect(ast3AfterVitals.vitals.device, 'Bio-Monitor Astroskin');
    expect(ast3AfterVitals.vitals.activityState, 'resting');
    expect(ast3AfterVitals.vitals.signalQuality, 'optimal (98%)');
    expect(ast3AfterVitals.vitals.recordType, 'instrumental');
    expect(ast3AfterVitals.vitals.algorithm, 'NASA-HRP BioSignalKalman v3.2');
    expect(
      ast3AfterVitals.vitals.criterionReference,
      'NASA-STD-3001 Vol. 1 & Vol. 2 / MedicalThresholds',
    );
    expect(
      ast3AfterVitals.activeAlerts.any((a) => a.contains('SpO2 Crítico')),
      isFalse,
    );

    // También normalizar dosimetría HERA para salir de estado crítico radiológico
    final heraRecoveryPacket = TelemetryPacket(
      timestamp: DateTime.now(),
      machineId: 'DEV-HERA',
      astronautId: 'AST-03',
      source: 'telemetry',
      device: 'HERA Radiation Assay',
      protocol: 'MIL-STD-1553B / Timepix bus',
      measurementMethod: 'Espectrometría activa en silicio híbrido Timepix3 (LET)',
      activityState: 'resting',
      signalQuality: 'optimal (95%)',
      recordType: 'instrumental',
      algorithm: 'SRAG-LET-Dosimetry v2.4',
      criterionReference: 'NASA-STD-3001 Permissible Exposure Limits (PEL)',
      metrics: const {
        'doseRateMicroSvPerHour': 55.0,
        'cumulativeDoseMilliSv': 64.2,
        'severity': 'normal',
      },
    );
    crewNotifier.applyTelemetryPacket('AST-03', heraRecoveryPacket);
    final ast3Updated =
        crewNotifier.state.firstWhere((a) => a.id == 'AST-03');
    expect(ast3Updated.radiation.deviceId, 'DEV-HERA');
    expect(ast3Updated.radiation.algorithm, 'SRAG-LET-Dosimetry v2.4');
    expect(ast3Updated.riskLevel, isNot(CrewRiskLevel.critical));

    // Verificar registro manual explícito por tripulante
    final manualRecord = VitalsRecord(
      timestamp: DateTime.now(),
      astronautId: 'AST-01',
      source: 'manual',
      deviceId: 'MANUAL-CREW-ASSESSMENT',
      device: 'Evaluación Manual de Tripulación',
      protocol: 'Ingreso Manual Offline',
      measurementMethod:
          'Registro manual por tripulante (pulsioxímetro / baumanómetro / termómetro)',
      activityState: 'emergency_triage',
      signalQuality: 'manual_verified',
      recordType: 'manual',
      algorithm: 'DirectCrewEntry v1.0',
      criterionReference: 'NASA-STD-3001 Vol.2 Vital Limits',
      heartRate: 74.0,
      systolicBP: 120.0,
      diastolicBP: 78.0,
      spO2: 98.0,
      bodyTemp: 36.7,
      bloodGlucose: 96.0,
      respiratoryRate: 15.0,
      capillaryRefillSeconds: 1.5,
    );
    crewNotifier.updateVitals('AST-01', manualRecord);
    final ast1Manual =
        crewNotifier.state.firstWhere((a) => a.id == 'AST-01');
    expect(ast1Manual.vitals.source, 'manual');
    expect(ast1Manual.vitals.recordType, 'manual');
    expect(ast1Manual.vitals.activityState, 'emergency_triage');
    expect(ast1Manual.vitals.signalQuality, 'manual_verified');
    expect(ast1Manual.vitals.algorithm, 'DirectCrewEntry v1.0');
    expect(ast1Manual.vitals.criterionReference, 'NASA-STD-3001 Vol.2 Vital Limits');

    crewNotifier.unlinkMachine('AST-01', 'DEV-ASTROSKIN');
    expect(
      crewNotifier.state
          .firstWhere((a) => a.id == 'AST-01')
          .linkedMachineIds
          .contains('DEV-ASTROSKIN'),
      isFalse,
    );
    crewNotifier.linkMachine('AST-01', 'DEV-ASTROSKIN');
    expect(
      crewNotifier.state
          .firstWhere((a) => a.id == 'AST-01')
          .linkedMachineIds
          .contains('DEV-ASTROSKIN'),
      isTrue,
    );
  });
}
