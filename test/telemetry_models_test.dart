import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:astramed/features/apolo/data/apolo_repository.dart';
import 'package:astramed/features/apolo/providers/apolo_providers.dart';
import 'package:astramed/features/apolo/presentation/apolo_theme.dart';
import 'package:astramed/features/telemetry/presentation/widgets/telemetry_config_modal.dart';
import 'package:astramed/features/telemetry/presentation/providers/telemetry_provider.dart';
import 'package:astramed/core/storage/crew_database_service.dart';
import 'package:astramed/features/01_general_health/models/vitals_record.dart';
import 'package:astramed/features/02_radiation/models/radiation_dose.dart';
import 'package:astramed/features/03_microgravity/models/microgravity_data.dart';
import 'package:astramed/features/04_mental_health/models/sleep_record.dart';
import 'package:astramed/features/05_clinical_triage/data/medical_procedures_data.dart';
import 'package:astramed/features/05_clinical_triage/models/triage_decision.dart';
import 'package:astramed/features/crew/data/mock_crew_data.dart';
import 'package:astramed/features/crew/models/astronaut_profile.dart';
import 'package:astramed/features/crew/presentation/providers/crew_provider.dart';
import 'package:astramed/features/telemetry/data/space_machines_catalog.dart';
import 'package:astramed/features/telemetry/models/telemetry_machine.dart';

void main() {
  testWidgets('Machine details are optional and readings stay understandable',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        crewMembersProvider.overrideWith(
          (ref) => CrewNotifier(null, MockCrewData.getNominalCrew()),
        ),
      ],
      child: MaterialApp(
        theme: buildApoloTheme(),
        home: const Scaffold(body: TelemetryConfigModal()),
      ),
    ));
    expect(find.textContaining('Algorithm:'), findsNothing);
    expect(find.textContaining('Protocol:'), findsNothing);
    expect(find.text(
      'Smart wearable vest that tracks your heart rate, breathing, blood pressure, blood oxygen, and skin temperature.',
    ), findsOneWidget);
    expect(find.text('Heart Rate'), findsWidgets);
    expect(find.text('heartRate'), findsNothing);
    final card = find.ancestor(
      of: find.text('Bio-Monitor Astroskin'),
      matching: find.byType(Card),
    );
    await tester.tap(find.descendant(
      of: card, matching: find.text('Capture Reading Now'),
    ));
    await tester.pump();
    expect(find.descendant(
      of: card, matching: find.textContaining('Last reading at '),
    ), findsOneWidget);
    expect(find.textContaining('astronautId='), findsNothing);
    final toggle = find.byKey(
      const ValueKey('machine_details_toggle_DEV-ASTROSKIN'),
    );
    await tester.tap(toggle);
    await tester.pump();
    expect(find.text('Hide details'), findsOneWidget);
    expect(find.text('Algorithm: NASA-HRP BioSignalKalman v3.2'), findsOneWidget);
    expect(find.text('Protocol: ANT+ / BLE SpaceBus v3.2'), findsOneWidget);
    expect(find.textContaining('astronautId=AST-01'), findsOneWidget);
    expect(find.textContaining('Raw metric keys: heartRate'), findsOneWidget);
    await tester.tap(toggle);
    await tester.pump();
    expect(find.textContaining('Algorithm:'), findsNothing);
    expect(find.textContaining('astronautId='), findsNothing);
    expect(find.descendant(
      of: card, matching: find.textContaining('Last reading at '),
    ), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('English telemetry modal preserves profile selection and hides DB JSON inspection',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        crewMembersProvider.overrideWith(
          (ref) => CrewNotifier(null, MockCrewData.getNominalCrew()),
        ),
      ],
      child: MaterialApp(
        theme: buildApoloTheme(),
        home: const Scaffold(body: TelemetryConfigModal()),
      ),
    ));
    expect(find.text('Telemetry & Hardware Configuration'), findsOneWidget);
    expect(find.text('Live Stream (3s)'), findsOneWidget);
    expect(find.text('Scan Space Bus'), findsOneWidget);
    expect(find.text('Read All (4)'), findsOneWidget);
    expect(find.text('Sync DB/Users'), findsOneWidget);
    expect(find.text('Inspect DB JSON'), findsNothing);
    await tester.tap(find.text('ATHENA (4)'));
    await tester.pump();
    expect(find.textContaining('Profile: Dra. Elena Ramos (AST-02)'), findsOneWidget);
    await tester.tap(find.text('Read All (4)'));
    await tester.pump();
    final container = ProviderScope.containerOf(
        tester.element(find.byType(TelemetryConfigModal)));
    expect(container.read(telemetryProvider).recentLogs, hasLength(4));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  test('Nominal constructors start healthy without replacing legacy defaults', () {
    final crew = CrewNotifier(null, MockCrewData.getNominalCrew());
    addTearDown(crew.dispose);
    expect(crew.state, hasLength(5));
    for (final member in crew.state) {
      expect(member.riskLevel, CrewRiskLevel.nominal);
      expect(member.riskTitle, 'Nominal Status');
      expect(member.activeAlerts, isEmpty);
    }
    final legacyCrew = CrewNotifier();
    addTearDown(legacyCrew.dispose);
    expect(legacyCrew.state[2].riskLevel, CrewRiskLevel.critical);

    final now = DateTime.utc(2026, 11, 15, 12);
    final repo = ApoloRepository(clock: () => now);
    final nominal = ApoloStateNotifier(repository: repo, initialNominal: true);
    addTearDown(nominal.dispose);
    for (final state in nominal.state.values) {
      expect(state.missionDay, 1);
      expect(state.samples, hasLength(1));
      expect(state.samples.single.takenAt, now.subtract(const Duration(hours: 2)));
      expect(state.sampleSchedule.isDue, isFalse);
    }
    final legacy = ApoloStateNotifier(repository: repo);
    addTearDown(legacy.dispose);
    expect(legacy.state['AST-01']!.missionDay, ApoloRepository.defaultMissionDay);

    final container = ProviderContainer(overrides: [
      apoloRepositoryProvider.overrideWithValue(repo),
      apoloStartNominalProvider.overrideWithValue(true),
    ]);
    addTearDown(container.dispose);
    expect(container.read(apoloStateNotifierProvider)['AST-01']!.missionDay, 1);
    final defaultContainer = ProviderContainer();
    addTearDown(defaultContainer.dispose);
    expect(defaultContainer.read(apoloStartNominalProvider), isFalse);
    expect(defaultContainer.read(apoloStateNotifierProvider)['AST-01']!.missionDay,
        ApoloRepository.defaultMissionDay);
  });

  test('Nominal reset refreshes sample schedule using the repository clock', () {
    final now = DateTime.utc(2026, 11, 15, 12);
    final notifier = ApoloStateNotifier(
      repository: ApoloRepository(clock: () => now),
    );
    addTearDown(notifier.dispose);
    notifier.resetAllNominal();
    for (final state in notifier.state.values) {
      expect(state.sampleSchedule.isDue, isFalse);
      expect(state.samples.single.takenAt, now.subtract(const Duration(hours: 2)));
    }
  });

  test('Historical sample dates remain unchanged without a fresh baseline', () {
    final samples = ApoloRepository.generateMockSamples(
      apoloKey: 'alex',
      astronautId: 'AST-01',
      targetValues: const {},
      count: 1,
      currentMissionDay: 1,
    );
    expect(samples.single.takenAt, DateTime.utc(2026, 6, 26, 7, 30));
    final crew = MockCrewData.getInitialCrew();
    expect(crew.map((p) => p.role), [
      'Mission Commander',
      'Chief Medical Officer (CMO)',
      'Flight / EVA Engineer',
      'Biochemistry & Payloads Specialist',
      'Robotics & Life Support (ECLSS)',
    ]);
    expect(crew.map((p) => p.callsign),
        ['ARES-1', 'ATHENA', 'SPARK', 'NOVA', 'TITAN']);
    expect(crew[2].riskTitle, 'CRITICAL ALERT: Post-EVA Hypoxia');
    expect(crew[2].vitals.spO2, 89.0);
  });

  test('Clinical telemetry emits English alerts and keeps nominal vitals quiet', () {
    final notifier = CrewNotifier(null, MockCrewData.getNominalCrew());
    addTearDown(notifier.dispose);
    final baseline = notifier.state.first;
    notifier.applyTelemetryPacket(baseline.id, TelemetryPacket(
      timestamp: DateTime.utc(2026, 11, 15),
      machineId: 'DEV-ASTROSKIN',
      astronautId: baseline.id,
      metrics: const {'spO2': 89.0},
    ));
    expect(notifier.state.first.riskLevel, CrewRiskLevel.critical);
    expect(notifier.state.first.activeAlerts,
        ['Critical SpO2: 89.0% (Acute hypoxia)']);
    expect(notifier.state.first.riskTitle, 'CRITICAL ALERT: Critical SpO2');
    notifier.applyTelemetryPacket(baseline.id, TelemetryPacket(
      timestamp: DateTime.utc(2026, 11, 15),
      machineId: 'DEV-ASTROSKIN',
      astronautId: baseline.id,
      metrics: const {'spO2': 99.0},
    ));
    expect(notifier.state.first.riskLevel, CrewRiskLevel.nominal);
    expect(notifier.state.first.activeAlerts, isEmpty);
    expect(notifier.state.first.riskTitle, 'Nominal Status');
    expect(notifier.state.skip(1).map((p) => p.id),
        MockCrewData.getNominalCrew().skip(1).map((p) => p.id));
  });

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
    expect(packet.measurementMethod, contains('textile ECG'));
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
      ast3AfterVitals.activeAlerts.any((a) => a.contains('Critical SpO2')),
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

  test('MedicalProceduresData suggests cardiac arrest RCP procedure on cardiac emergency or critical vitals', () {
    final procedures = MedicalProceduresData.getProcedures();
    final scenarios = MedicalProceduresData.getScenarios();

    expect(procedures.length, 10);
    expect(scenarios.length, 10);

    final cardiacProc = MedicalProceduresData.findById('PROC-CARDIAC-ARREST');
    expect(cardiacProc, isNotNull);
    expect(cardiacProc!.priority, TriagePriority.red);
    expect(cardiacProc.steps.length, greaterThanOrEqualTo(5));
    expect(
      cardiacProc.requiredSupplies.any((s) => s.itemId == 'AED-SPACE'),
      isTrue,
    );
    expect(
      cardiacProc.requiredSupplies.any((s) => s.itemId == 'CMRS-BOARD'),
      isTrue,
    );

    // Round-trip serialization check
    final roundTripProc = MedicalProcedure.fromJson(cardiacProc.toJson());
    expect(roundTripProc.id, 'PROC-CARDIAC-ARREST');
    expect(roundTripProc.steps.length, cardiacProc.steps.length);
    expect(
      roundTripProc.requiredSupplies.length,
      cardiacProc.requiredSupplies.length,
    );

    final crew = MockCrewData.getInitialCrew();
    final nominalAstro = crew.firstWhere((a) => a.id == 'AST-01');

    // Simulación explícita de paro cardíaco
    final simulatedSuggestions =
        MedicalProceduresData.suggestProceduresForAstronaut(
      nominalAstro,
      simulatedSituationId: 'SIT-CARDIAC-ARREST',
    );
    expect(simulatedSuggestions, isNotEmpty);
    expect(simulatedSuggestions.first.procedure.id, 'PROC-CARDIAC-ARREST');
    expect(simulatedSuggestions.first.isUrgent, isTrue);

    // Detección automática por signos vitales críticos de paro cardíaco
    final arrestAstronaut = nominalAstro.copyWith(
      vitals: nominalAstro.vitals.copyWith(
        heartRate: 0.0,
        systolicBP: 50.0,
        spO2: 78.0,
      ),
    );
    final autoArrestSuggestions =
        MedicalProceduresData.suggestProceduresForAstronaut(arrestAstronaut);
    expect(autoArrestSuggestions, isNotEmpty);
    expect(autoArrestSuggestions.first.procedure.id, 'PROC-CARDIAC-ARREST');
    expect(autoArrestSuggestions.first.isUrgent, isTrue);

    // Detección automática para AST-03 (hipoxia Post-EVA y radiación elevada)
    final ast3 = crew.firstWhere((a) => a.id == 'AST-03');
    final ast3Suggestions =
        MedicalProceduresData.suggestProceduresForAstronaut(ast3);
    expect(
      ast3Suggestions.any((s) => s.procedure.id == 'PROC-HYPOXIA-DECOMP'),
      isTrue,
    );
    expect(
      ast3Suggestions.any((s) => s.procedure.id == 'PROC-RADIATION-ARS'),
      isTrue,
    );
  });
}
