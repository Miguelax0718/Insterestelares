import 'package:astramed/core/constants/medical_thresholds.dart';
import 'package:astramed/features/01_general_health/domain/scientific_criteria_engine.dart';
import 'package:astramed/features/01_general_health/domain/telemetry_ingestion_service.dart';
import 'package:astramed/features/01_general_health/models/vitals_record.dart';
import 'package:astramed/features/telemetry/models/telemetry_machine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ScientificCriteriaEngine', () {
    test('Devuelve Sin datos disponibles cuando no hay medición', () {
      final hr = ScientificCriteriaEngine.evaluateHeartRate(
        bpm: null,
        context: ActivityContext.rest,
      );
      final rr = ScientificCriteriaEngine.evaluateRespiratoryRate(
        rpm: null,
        context: ActivityContext.sleep,
      );
      final spo2 = ScientificCriteriaEngine.evaluateSpO2(
        percent: 98,
        context: ActivityContext.rest,
        isSignalValid: false,
      );

      expect(hr.severity, EvaluationSeverity.noData);
      expect(hr.summary, 'Sin datos disponibles');
      expect(rr.severity, EvaluationSeverity.noData);
      expect(spo2.severity, EvaluationSeverity.noData);
    });

    test('No aplica umbrales de reposo a frecuencia cardíaca durante ejercicio', () {
      final result = ScientificCriteriaEngine.evaluateHeartRate(
        bpm: 135,
        context: ActivityContext.physicalActivity,
      );

      expect(result.severity, EvaluationSeverity.descriptive);
      expect(result.appliedCriterion, isNull);
    });

    test('Prioriza referencia basal individual en reposo sobre referencia general', () {
      final result = ScientificCriteriaEngine.evaluateHeartRate(
        bpm: 56,
        context: ActivityContext.rest,
        individualBaselineBpm: 54,
      );

      expect(result.severity, EvaluationSeverity.descriptive);
      expect(result.appliedCriterion?.level, CriterionLevel.individualBaseline);
      expect(result.individualBaselineDelta, closeTo(2.0, 0.001));
    });

    test('Evalúa sueño según intervalo 7-9 h de Hirshkowitz/Watson', () {
      expect(MedicalThresholds.minRecommendedSleepHours, 7.0);

      final shortSleep = ScientificCriteriaEngine.evaluateSleepDuration(
        hours: 6.5,
        isSubjectiveManual: true,
      );
      final normalSleep = ScientificCriteriaEngine.evaluateSleepDuration(
        hours: 7.5,
        isSubjectiveManual: false,
      );

      expect(shortSleep.severity, EvaluationSeverity.informativeNotice);
      expect(shortSleep.summary, contains('Estimación subjetiva'));
      expect(normalSleep.severity, EvaluationSeverity.descriptive);
    });

    test('Aplica NASA-STD-3001 V1 4024 solo a mediciones instrumentales equivalentes', () {
      final nonComparable = ScientificCriteriaEngine.evaluateMuscleStrength(
        currentValue: 400,
        baselinePreMissionValue: 500,
        sameProtocol: false,
        isInstrumental: true,
      );
      final belowStandard = ScientificCriteriaEngine.evaluateMuscleStrength(
        currentValue: 380,
        baselinePreMissionValue: 500,
        sameProtocol: true,
        isInstrumental: true,
      );
      final meetsStandard = ScientificCriteriaEngine.evaluateMuscleStrength(
        currentValue: 420,
        baselinePreMissionValue: 500,
        sameProtocol: true,
        isInstrumental: true,
      );

      expect(nonComparable.severity, EvaluationSeverity.noData);
      expect(belowStandard.severity, EvaluationSeverity.operationalAlert);
      expect(belowStandard.value, closeTo(76.0, 0.01));
      expect(meetsStandard.severity, EvaluationSeverity.descriptive);
      expect(meetsStandard.value, closeTo(84.0, 0.01));
    });

    test('Fusión actigráfica bimodal valida sueño con acelerómetro bajo no-cero + descenso de FC', () {
      final sleepEval = ScientificCriteriaEngine.inferActivityAndValidateHrv(
        accelerometryRmsG: 0.018,
        heartRateBpm: 54.0,
        respiratoryRateRpm: 11.5,
        rawActivityState: 'active_duty',
        restingWakefulHrBaselineBpm: 68.0,
      );
      expect(sleepEval.inferredContext, ActivityContext.sleep);
      expect(sleepEval.isHrvValidForStress, isTrue);

      final exerciseEval = ScientificCriteriaEngine.inferActivityAndValidateHrv(
        accelerometryRmsG: 0.72,
        heartRateBpm: 152.0,
        respiratoryRateRpm: 28.0,
        rawActivityState: 'exercise',
        restingWakefulHrBaselineBpm: 68.0,
      );
      expect(exerciseEval.inferredContext, ActivityContext.physicalActivity);
      expect(exerciseEval.isHrvValidForStress, isFalse);
    });

    test('Detecta anomalía correlacionada con bolsillo focal de CO2 en reposo', () {
      final co2Alert = ScientificCriteriaEngine.evaluateHeartRate(
        bpm: 108.0,
        context: ActivityContext.rest,
        localCo2MmHg: 4.6,
        missionDay: 18,
      );
      expect(co2Alert.severity, EvaluationSeverity.operationalAlert);
      expect(co2Alert.summary, contains('CO₂'));
    });

    test('Calibra hidratación por fluid shift según missionDay y separa los 3 flujos de ingesta', () {
      final day2Vitals = VitalsRecord(
        timestamp: DateTime.now(),
        missionDay: 2,
        heartRate: 70,
        systolicBP: 120,
        diastolicBP: 78,
        spO2: 98,
        bodyTemp: 36.6,
        bloodGlucose: 92,
        hydrationBioimpedanceIndex: 76.0,
      );
      expect(day2Vitals.calibratedHydrationIndex, closeTo(69.5, 0.01));

      final summary = TelemetryIngestionService.classifyAndSummarize(
        currentVitals: day2Vitals,
        recentPackets: [
          TelemetryPacket(
            timestamp: DateTime.now(),
            machineId: 'DEV-ARED',
            astronautId: 'AST-01',
            metrics: const {'durationMinutes': 40},
          ),
          TelemetryPacket(
            timestamp: DateTime.now(),
            machineId: 'DEV-ISTAT',
            astronautId: 'AST-01',
            metrics: const {'bloodGlucose': 94.0},
          ),
        ],
      );
      expect(summary.wearableStream.missionDay, 2);
      expect(summary.stationFixedRecords.length, 1);
      expect(summary.periodicManualRecords.length, 1);
    });

    test('Evalúa presión arterial, llenado capilar y glucosa contextualmente', () {
      final bpExercise = ScientificCriteriaEngine.evaluateBloodPressureContextual(
        systolicMmHg: 162,
        diastolicMmHg: 84,
        context: ActivityContext.physicalActivity,
      );
      expect(bpExercise.severity, EvaluationSeverity.descriptive);
      expect(bpExercise.appliedCriterion?.id, 'bp_contextual_nasa_std_3001');

      final bpRestHigh = ScientificCriteriaEngine.evaluateBloodPressureContextual(
        systolicMmHg: 162,
        diastolicMmHg: 96,
        context: ActivityContext.rest,
      );
      expect(bpRestHigh.severity, EvaluationSeverity.informativeNotice);

      final capNominal =
          ScientificCriteriaEngine.evaluateCapillaryRefillContextual(
        seconds: 1.5,
        context: ActivityContext.rest,
      );
      final capSlow = ScientificCriteriaEngine.evaluateCapillaryRefillContextual(
        seconds: 3.4,
        context: ActivityContext.rest,
      );
      expect(capNominal.severity, EvaluationSeverity.descriptive);
      expect(capSlow.severity, EvaluationSeverity.operationalAlert);

      final glucoseLow = ScientificCriteriaEngine.evaluateBloodGlucoseContextual(
        mgDl: 64,
        context: ActivityContext.physicalActivity,
      );
      final glucoseExercise =
          ScientificCriteriaEngine.evaluateBloodGlucoseContextual(
        mgDl: 148,
        context: ActivityContext.physicalActivity,
      );
      expect(glucoseLow.severity, EvaluationSeverity.operationalAlert);
      expect(glucoseExercise.severity, EvaluationSeverity.descriptive);
    });
  });
}
