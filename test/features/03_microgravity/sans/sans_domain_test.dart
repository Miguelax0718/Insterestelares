import 'package:astramed/core/calibration/domain/device_calibration.dart';
import 'package:astramed/core/constants/medical_thresholds.dart';
import 'package:astramed/core/sensing/domain/sensing_ports.dart';
import 'package:astramed/features/03_microgravity/sans/data/sans_repository.dart';
import 'package:astramed/features/03_microgravity/sans/domain/sans_models_and_analyzers.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('S5: NearPointDiopterCalculator (IPD Trigonometry & Hyperopic Shift)', () {
    const calibration = DeviceCalibration(
      pixelsPerMm: 6.3,
      focalLengthPx: 580.0,
      crewIpdMm: 63.0,
      baselineNearPointCm: 25.0,
    );

    test('computes exact eye-to-screen distance in cm from camera IPD pixels', () {
      // Para d = 36.54 cm -> ipd_px = (580 * 63) / (10 * 36.54) = 100.0 px
      final distanceCm = NearPointDiopterCalculator.computeEyeToScreenDistanceCm(
        ipdPixels: 100.0,
        calibration: calibration,
      );
      expect(distanceCm, closeTo(36.54, 0.01));
    });

    test('25.0 cm baseline to 44.4 cm yields ~+1.75 D and recommends Pair #3 (+1.75 D)', () {
      final estimate = NearPointDiopterCalculator.evaluateFromDistanceCm(
        currentNearPointCm: 44.4,
        baselineNearPointCm: 25.0,
      );

      expect(estimate.hyperopicShiftDiopters, closeTo(1.75, 0.01));
      expect(
        estimate.recommendedGlassesTier,
        SpaceAnticipationGlassesTier.pair3Plus175D,
      );
      expect(estimate.requiresFlightSurgeonAlert, isTrue);
      expect(estimate.clinicalSummaryEs, contains('Par #3'));
    });

    test('25.0 cm baseline to 36.3 cm yields ~+1.25 D (±0.22 D) and recommends Pair #2 (+1.25 D)', () {
      final estimate = NearPointDiopterCalculator.evaluateFromDistanceCm(
        currentNearPointCm: 36.3,
        baselineNearPointCm: 25.0,
      );

      expect(estimate.hyperopicShiftDiopters, closeTo(1.25, 0.02));
      expect(estimate.confidenceIntervalDiopters, closeTo(0.22, 0.02));
      expect(
        estimate.recommendedGlassesTier,
        SpaceAnticipationGlassesTier.pair2Plus125D,
      );
      expect(estimate.requiresFlightSurgeonAlert, isTrue);
      expect(
        estimate.clinicalSummaryEs,
        contains('Gafas de Anticipación Par #2 y reporte al Cirujano de Vuelo'),
      );
    });

    test('25.0 cm baseline to 30.8 cm yields ~+0.75 D and recommends Pair #1 (+0.75 D)', () {
      final estimate = NearPointDiopterCalculator.evaluateFromDistanceCm(
        currentNearPointCm: 30.8,
        baselineNearPointCm: 25.0,
      );

      expect(estimate.hyperopicShiftDiopters, closeTo(0.75, 0.02));
      expect(
        estimate.recommendedGlassesTier,
        SpaceAnticipationGlassesTier.pair1Plus075D,
      );
      expect(estimate.requiresFlightSurgeonAlert, isFalse);
      expect(estimate.clinicalSummaryEs, contains('Par #1'));
    });

    test('25.0 cm baseline to 26.0 cm (< 0.50 D) requires no glasses', () {
      final estimate = NearPointDiopterCalculator.evaluateFromDistanceCm(
        currentNearPointCm: 26.0,
        baselineNearPointCm: 25.0,
      );

      expect(estimate.hyperopicShiftDiopters, lessThan(0.50));
      expect(
        estimate.recommendedGlassesTier,
        SpaceAnticipationGlassesTier.none,
      );
      expect(estimate.requiresFlightSurgeonAlert, isFalse);
    });
  });

  group('S6: StarfieldDistortionAnalyzer (TechPort 97109 Psychophysical Screening)', () {
    FaceSample buildGazeSample(double gazeOffsetDeg) {
      return FaceSample(
        timestamp: DateTime.utc(2026, 11, 14),
        headYawDeg: 0.0,
        headPitchDeg: 0.0,
        headRollDeg: 0.0,
        gazeOffsetDeg: gazeOffsetDeg,
        ipdPixels: 120.0,
        cheekRedMean: 170.0,
        cheekGreenMean: 150.0,
        cheekBlueMean: 135.0,
      );
    }

    test('classifies nominal when line is straightened, all flashes seen, and fixation kept', () {
      final stimuli = StarfieldDistortionAnalyzer.buildStandardStimuli(
        eye: OcularEye.odRight,
        defaultDetected: true,
      );
      final samples = List.generate(10, (_) => buildGazeSample(1.2));

      final result = StarfieldDistortionAnalyzer.evaluate(
        evaluatedEye: OcularEye.odRight,
        injectedWaveAmplitude: 0.50,
        userStraighteningSlider: 0.45, // residual = 0.05 < 0.18
        stimuli: stimuli,
        fixationSamples: samples,
      );

      expect(result.residualMetamorphopsiaIndex, closeTo(0.05, 0.001));
      expect(result.contrastSensitivityScore, equals(1.0));
      expect(result.blindSpotEnlargementDetected, isFalse);
      expect(result.centralFixationScore, equals(1.0));
      expect(result.isFixationReliable, isTrue);
      expect(result.riskTier, SansFunctionalRiskTier.nominal);
      expect(result.shouldLaunchLbnpCountermeasure, isFalse);
      expect(result.clinicalNoteEs, contains('Frisén'));
    });

    test('detects peripapillary scotoma enlargement (~15 deg) and triggers LBNP recommendation', () {
      final stimuli = StarfieldDistortionAnalyzer.buildStandardStimuli(
        eye: OcularEye.osLeft,
        defaultDetected: true,
      ).map((s) {
        // Simula pérdida de sensibilidad en anillo peripapilar temporal (~15°)
        if (s.isPeripapillaryZone) {
          return s.copyWith(detectedByUser: false);
        }
        return s;
      }).toList();

      final result = StarfieldDistortionAnalyzer.evaluate(
        evaluatedEye: OcularEye.osLeft,
        injectedWaveAmplitude: 0.50,
        userStraighteningSlider: 0.40, // residual = 0.10
        stimuli: stimuli,
      );

      expect(result.peripapillaryMissedCount, equals(3));
      expect(result.blindSpotEnlargementDetected, isTrue);
      expect(result.riskTier, SansFunctionalRiskTier.moderateFoldsOrScotoma);
      expect(result.shouldLaunchLbnpCountermeasure, isTrue);
    });

    test('penalizes central fixation when gaze deviates > 3.0 deg and detects severe metamorphopsia', () {
      final stimuli = StarfieldDistortionAnalyzer.buildStandardStimuli(
        eye: OcularEye.odRight,
        defaultDetected: true,
      );
      // 4 de 10 muestras desvían la mirada fuera del planeta central (> 3.0°)
      final samples = [
        for (int i = 0; i < 6; i++) buildGazeSample(1.5),
        for (int i = 0; i < 4; i++) buildGazeSample(6.2),
      ];

      final result = StarfieldDistortionAnalyzer.evaluate(
        evaluatedEye: OcularEye.odRight,
        injectedWaveAmplitude: 0.55,
        userStraighteningSlider: -0.20, // residual = 0.75 >= 0.60
        stimuli: stimuli,
        fixationSamples: samples,
      );

      expect(result.centralFixationScore, closeTo(0.60, 0.001));
      expect(result.isFixationReliable, isFalse);
      expect(result.riskTier, SansFunctionalRiskTier.criticalNotifyFlightSurgeon);
      expect(result.shouldLaunchLbnpCountermeasure, isTrue);
    });
  });

  group('S7: LbnpProtocolMachine (-20 mmHg & Mandatory Gradual Decompression Invariant)', () {
    test('enforces mandatoryGradualDecompression when stopping from -20 mmHg and blocks immediate release', () {
      final machine = LbnpProtocolMachine();

      // 1. Inicia sesión -> rampDown (-5 mmHg)
      var state = machine.startSession(
        sessionId: 'lbnp_test_1',
        targetHoldDurationSeconds: 60,
        requiredDecompressionSeconds:
            MedicalThresholds.lbnpMinDecompressionSeconds,
      );
      expect(state.phase, LbnpPhase.rampDown);
      expect(state.currentPressureMmHg, equals(-5.0));
      expect(state.hemodynamicSafetyLockActive, isTrue);

      // 2. Avanza 3 segundos para llegar a -20.0 mmHg (activeHoldMinus20)
      state = machine.tick(deltaSeconds: 3);
      expect(state.phase, LbnpPhase.activeHoldMinus20);
      expect(
        state.currentPressureMmHg,
        equals(MedicalThresholds.lbnpTargetPressureMmHg),
      );

      // 3. El astronauta solicita detener/finalizar la sesión en pleno -20 mmHg
      state = machine.requestStopOrRelease();
      expect(state.phase, LbnpPhase.mandatoryGradualDecompression);
      expect(state.decompressionElapsedSeconds, equals(0));
      expect(state.hemodynamicSafetyLockActive, isTrue);
      expect(state.currentPressureMmHg, lessThan(0.0));
      expect(state.warningBannerEs, isNotNull);

      // 4. Incluso si intenta reiniciar o volver a liberar a mitad de descompresión (ej. t = 7 s),
      // sigue bloqueado y escalonando la presión (-20 -> -15 -> -10 -> -5 mmHg)
      state = machine.tick(deltaSeconds: 7);
      expect(state.phase, LbnpPhase.mandatoryGradualDecompression);
      expect(state.currentPressureMmHg, equals(-15.0));
      expect(state.hemodynamicSafetyLockActive, isTrue);

      state = machine.resetIfSafe();
      expect(state.phase, LbnpPhase.mandatoryGradualDecompression);
      expect(state.hemodynamicSafetyLockActive, isTrue);

      // 5. Avanza hasta los 12 s de los 15 s obligatorios -> escalón -5.0 mmHg
      state = machine.tick(deltaSeconds: 5);
      expect(state.phase, LbnpPhase.mandatoryGradualDecompression);
      expect(state.decompressionElapsedSeconds, equals(12));
      expect(state.currentPressureMmHg, equals(-5.0));

      // 6. Completa los 3 segundos restantes (total 15 s) -> liberación segura a 0.0 mmHg
      state = machine.tick(deltaSeconds: 3);
      expect(state.phase, LbnpPhase.completed);
      expect(state.currentPressureMmHg, equals(0.0));
      expect(state.hemodynamicSafetyLockActive, isFalse);
      expect(state.completedAt, isNotNull);
    });

    test('repository stores and loads SANS assessments and LBNP sessions in-memory without Hive init', () async {
      final repo = SansRepository();
      final near = NearPointDiopterCalculator.evaluateFromDistanceCm(
        currentNearPointCm: 36.36,
        baselineNearPointCm: 25.0,
      );
      final starfield = StarfieldDistortionAnalyzer.evaluate(
        evaluatedEye: OcularEye.odRight,
        injectedWaveAmplitude: 0.45,
        userStraighteningSlider: 0.10,
        stimuli: StarfieldDistortionAnalyzer.buildStandardStimuli(
          eye: OcularEye.odRight,
        ),
      );
      final assessment = SansComprehensiveAssessment(
        id: 'sans_unit_1',
        recordedAt: DateTime.utc(2026, 11, 14, 20, 30),
        nearPoint: near,
        starfield: starfield,
      );

      await repo.saveAssessment(assessment);
      final loaded = repo.loadAssessments();
      expect(loaded, hasLength(1));
      expect(loaded.first.id, equals('sans_unit_1'));
      expect(
        loaded.first.nearPoint.recommendedGlassesTier,
        SpaceAnticipationGlassesTier.pair2Plus125D,
      );
    });
  });
}
