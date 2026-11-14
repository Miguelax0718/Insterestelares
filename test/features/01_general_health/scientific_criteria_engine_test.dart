import 'package:astramed/core/constants/medical_thresholds.dart';
import 'package:astramed/features/01_general_health/domain/scientific_criteria_engine.dart';
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
  });
}
