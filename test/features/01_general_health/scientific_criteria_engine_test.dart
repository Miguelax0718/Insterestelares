import 'package:astramed/features/01_general_health/domain/scientific_criteria_engine.dart';
import 'package:astramed/features/01_general_health/domain/telemetry_ingestion_service.dart';
import 'package:astramed/features/01_general_health/domain/telemetry_view_contracts.dart';
import 'package:astramed/features/01_general_health/models/vitals_record.dart';
import 'package:flutter_test/flutter_test.dart';

VitalsRecord _nominalVitals({
  int missionDay = 18,
  double heartRate = 70.0,
  double respiratoryRate = 16.0,
  double spO2 = 98.0,
  double coreTempHeatFluxC = 36.6,
  double hydrationBioimpedanceIndex = 78.0,
  double pupilDiameterMm = 3.8,
  double pupillometryNpi = 4.2,
  double plrLatencyMs = 210.0,
  double passiveNearFocusCm = 30.0,
  double estimatedHyperopicShiftDiopters = 0.0,
  double passivePvtReactionMs = 255.0,
  int passivePvtLapsesCount = 0,
  double touchPointerAccuracyPercent = 96.5,
  double accelerometryRmsG = 0.024,
  double peakImpactG = 0.15,
  double muscleVolumeRetentionPercent = 94.0,
  double sleepEfficiencyPercent = 91.0,
  double sleepFragmentationIndex = 8.5,
  double sleepRegularityIndex = 88.0,
  double nocturnalHrvRmssdMs = 62.0,
  double nocturnalHrvSdnnMs = 74.0,
  double nocturnalHeartRateMeanBpm = 56.0,
  double nocturnalRespiratoryRateMeanRpm = 13.5,
  double nocturnalSpO2MeanPercent = 97.5,
  int nocturnalDesaturationEvents = 0,
  double localCo2MmHg = 2.2,
}) {
  return VitalsRecord(
    timestamp: DateTime.utc(2026, 11, 15, 12, 0),
    astronautId: 'AST-01',
    heartRate: heartRate,
    systolicBP: 118.0,
    diastolicBP: 76.0,
    spO2: spO2,
    bodyTemp: coreTempHeatFluxC,
    bloodGlucose: 92.0,
    respiratoryRate: respiratoryRate,
    missionDay: missionDay,
    coreTempHeatFluxC: coreTempHeatFluxC,
    hydrationBioimpedanceIndex: hydrationBioimpedanceIndex,
    pupilDiameterMm: pupilDiameterMm,
    pupillometryNpi: pupillometryNpi,
    plrLatencyMs: plrLatencyMs,
    passiveNearFocusCm: passiveNearFocusCm,
    estimatedHyperopicShiftDiopters: estimatedHyperopicShiftDiopters,
    passivePvtReactionMs: passivePvtReactionMs,
    passivePvtLapsesCount: passivePvtLapsesCount,
    touchPointerAccuracyPercent: touchPointerAccuracyPercent,
    accelerometryRmsG: accelerometryRmsG,
    peakImpactG: peakImpactG,
    muscleVolumeRetentionPercent: muscleVolumeRetentionPercent,
    sleepEfficiencyPercent: sleepEfficiencyPercent,
    sleepFragmentationIndex: sleepFragmentationIndex,
    sleepRegularityIndex: sleepRegularityIndex,
    nocturnalHrvRmssdMs: nocturnalHrvRmssdMs,
    nocturnalHrvSdnnMs: nocturnalHrvSdnnMs,
    nocturnalHeartRateMeanBpm: nocturnalHeartRateMeanBpm,
    nocturnalRespiratoryRateMeanRpm: nocturnalRespiratoryRateMeanRpm,
    nocturnalSpO2MeanPercent: nocturnalSpO2MeanPercent,
    nocturnalDesaturationEvents: nocturnalDesaturationEvents,
    localCo2MmHg: localCo2MmHg,
  );
}

void main() {
  const engine = ScientificCriteriaEngine();

  group('VitalsRecord passive serialization', () {
    test('round-trips all 4 passive dimension fields and applies fluid-shift calibration', () {
      final record = _nominalVitals(
        missionDay: 10,
        hydrationBioimpedanceIndex: 75.0,
        pupillometryNpi: 3.9,
        passiveNearFocusCm: 33.5,
        passivePvtReactionMs: 280.0,
        peakImpactG: 0.4,
        nocturnalHrvRmssdMs: 54.0,
      );

      expect(record.calibratedHydrationIndex, closeTo(71.5, 0.01));

      final json = record.toJson();
      final decoded = VitalsRecord.fromJson(json);

      expect(decoded.missionDay, 10);
      expect(decoded.pupillometryNpi, closeTo(3.9, 0.001));
      expect(decoded.passiveNearFocusCm, closeTo(33.5, 0.001));
      expect(decoded.passivePvtReactionMs, closeTo(280.0, 0.001));
      expect(decoded.peakImpactG, closeTo(0.4, 0.001));
      expect(decoded.nocturnalHrvRmssdMs, closeTo(54.0, 0.001));
      expect(decoded.calibratedHydrationIndex, closeTo(71.5, 0.01));
    });
  });

  group('Dimension 1: Cardiorespiratory & Metabolic', () {
    test('allows +3.44 bpm microgravity offset in rest and ignores resting HR limits during exercise', () {
      final orbitalTolerance = engine.evaluateHeartRate(
        bpm: 102.5,
        context: ActivityContext.rest,
        inMicrogravity: true,
      );
      expect(orbitalTolerance.severity, EvaluationSeverity.normal);

      final exercise = engine.evaluateHeartRate(
        bpm: 148.0,
        context: ActivityContext.physicalActivity,
      );
      expect(exercise.severity, EvaluationSeverity.notApplicable);

      final poorSignal = engine.evaluateHeartRate(
        bpm: 130.0,
        context: ActivityContext.rest,
        signalQualityPercent: 65.0,
      );
      expect(poorSignal.severity, EvaluationSeverity.notApplicable);
    });

    test('evaluates SpO2, Draeger heat-flux temperature, and BIS hydration fluid-shift', () {
      expect(engine.evaluateSpO2(spo2Percent: 97.0).severity, EvaluationSeverity.normal);
      expect(engine.evaluateSpO2(spo2Percent: 93.0).severity, EvaluationSeverity.contextualWarning);
      expect(engine.evaluateSpO2(spo2Percent: 89.0).severity, EvaluationSeverity.clinicalAttention);

      expect(
        engine.evaluateCoreTemperatureHeatFlux(
          tempCelsius: 38.0,
          context: ActivityContext.physicalActivity,
        ).severity,
        EvaluationSeverity.normal,
      );
      expect(
        engine.evaluateCoreTemperatureHeatFlux(
          tempCelsius: 38.0,
          context: ActivityContext.rest,
        ).severity,
        EvaluationSeverity.contextualWarning,
      );

      // Raw 71.0% - 3.5% microgravity fluid-shift compensation = 67.5% -> warning (< 70%)
      final bisWarning = engine.evaluateHydrationBioimpedance(
        rawIndexPercent: 71.0,
        missionDay: 5,
        inMicrogravity: true,
      );
      expect(bisWarning.measuredValue, closeTo(67.5, 0.01));
      expect(bisWarning.severity, EvaluationSeverity.contextualWarning);
    });
  });

  group('Dimension 2: Neurological & Sensory', () {
    test('flags abnormal IR pupillometry NPi/PLR, ToF hyperopic shift, and passive PVT-B fatigue', () {
      expect(
        engine.evaluatePassivePupillometry(
          pupilDiameterMm: 3.6,
          npi: 4.1,
          plrLatencyMs: 215.0,
        ).severity,
        EvaluationSeverity.normal,
      );
      expect(
        engine.evaluatePassivePupillometry(
          pupilDiameterMm: 4.2,
          npi: 2.3,
          plrLatencyMs: 350.0,
        ).severity,
        EvaluationSeverity.clinicalAttention,
      );

      expect(
        engine.evaluatePassiveHyperopicShiftToF(
          nearFocusCm: 38.0,
          estimatedShiftDiopters: 0.75,
        ).severity,
        EvaluationSeverity.contextualWarning,
      );
      expect(
        engine.evaluatePassiveHyperopicShiftToF(
          nearFocusCm: 45.0,
          estimatedShiftDiopters: 1.50,
        ).severity,
        EvaluationSeverity.clinicalAttention,
      );

      expect(
        engine.evaluatePassiveBackgroundPvt(
          reactionMs: 390.0,
          lapsesCount: 4,
          pointerAccuracyPercent: 88.0,
        ).severity,
        EvaluationSeverity.contextualWarning,
      );
      expect(
        engine.evaluatePassiveBackgroundPvt(
          reactionMs: 460.0,
          lapsesCount: 6,
          pointerAccuracyPercent: 79.0,
        ).severity,
        EvaluationSeverity.clinicalAttention,
      );
    });
  });

  group('Dimension 3: Musculoskeletal', () {
    test('detects IMU impact >= 2.5g and localized muscle BIS atrophy', () {
      final impact = engine.evaluateInertialBiomechanics(
        rmsG: 0.45,
        peakImpactG: 2.8,
        strideCadenceStepsPerMin: 0.0,
        context: ActivityContext.eva,
      );
      expect(impact.severity, EvaluationSeverity.clinicalAttention);

      final muscleWarning = engine.evaluateLocalizedMuscleBioimpedance(
        volumeRetentionPercent: 78.0,
        pennationAngleDeg: 13.0,
        calibratedHydrationIndex: 74.0,
      );
      expect(muscleWarning.severity, EvaluationSeverity.contextualWarning);

      final nonComparableStrength = engine.evaluateMuscleStrength(
        retentionPercent: 74.0,
        comparableBaselineProtocol: false,
      );
      expect(nonComparableStrength.severity, EvaluationSeverity.notApplicable);
    });
  });

  group('Dimension 4 & Bimodal Actigraphy + TelemetryIngestionService', () {
    test('blocks autonomic HRV warning during physical activity and detects nocturnal anomalies', () {
      final activeBimodal = engine.evaluateActigraphyBimodal(
        hrvRmssdMs: 18.0,
        hrvSdnnMs: 25.0,
        actigraphyAxisG: 0.35,
        context: ActivityContext.physicalActivity,
      );
      expect(activeBimodal.hrvValidWindow, isFalse);
      expect(activeBimodal.severity, EvaluationSeverity.notApplicable);

      final restStress = engine.evaluateActigraphyBimodal(
        hrvRmssdMs: 22.0,
        hrvSdnnMs: 31.0,
        actigraphyAxisG: 0.015,
        context: ActivityContext.rest,
      );
      expect(restStress.hrvValidWindow, isTrue);
      expect(restStress.severity, EvaluationSeverity.contextualWarning);

      final nocturnalVitals = engine.evaluateNocturnalIntegratedVitals(
        nocturnalHrMeanBpm: 62.0,
        nocturnalRrMeanRpm: 16.0,
        nocturnalSpO2MeanPercent: 91.5,
        desaturationEvents: 3,
      );
      expect(nocturnalVitals.severity, EvaluationSeverity.clinicalAttention);
    });

    test('aggregates multi-source telemetry across all 4 dimensions with environmental flags', () {
      final vitals = _nominalVitals(
        passiveNearFocusCm: 39.0,
        estimatedHyperopicShiftDiopters: 0.75,
        localCo2MmHg: 3.6,
      );
      final stream = [
        ContinuousWearableStreamRecord.fromVitals(
          vitals,
          environment: SpaceOperationalEnvironment.spaceStation,
          sleepDurationHours: 7.4,
        ),
      ];
      final fixed = StationFixedTelemetryRecord(
        timestamp: DateTime.utc(2026, 11, 15, 12, 0),
        moduleId: 'Columbus',
        ppCo2MmHg: 3.6,
        o2Percent: 20.8,
        cabinPressureKPa: 101.2,
        ambientTempC: 22.1,
        radiationRateMSvPerHour: 0.08,
      );
      final periodic = PeriodicManualAssessmentRecord(
        timestamp: DateTime.utc(2026, 11, 15, 12, 0),
        astronautId: 'AST-01',
        systolicBP: 118.0,
        diastolicBP: 76.0,
        bloodGlucoseMgDl: 92.0,
        muscleStrengthRetentionPercent: 91.0,
        opticNerveSheathDiameterMm: 5.8,
      );

      const ingestion = TelemetryIngestionService();
      final summary = ingestion.classifyAndSummarize(
        wearableStream: stream,
        fixedTelemetry: fixed,
        periodicAssessment: periodic,
      );

      expect(summary.activeDevices.length, 6);
      expect(summary.environmentalFlags.length, 2); // CO2 >= 3.0 and ONSD >= 5.5
      expect(
        summary.passiveEvaluation.dimensionSeverities['neurological_sensory'],
        EvaluationSeverity.contextualWarning,
      );
      expect(summary.seriesSnapshots.containsKey('pupillometry_npi'), isTrue);
      expect(summary.seriesSnapshots.containsKey('nocturnal_hrv_rmssd'), isTrue);
    });
  });
}
