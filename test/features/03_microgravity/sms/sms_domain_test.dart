import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:astramed/core/constants/medical_thresholds.dart';
import 'package:astramed/core/sensing/domain/sensing_ports.dart';
import 'package:astramed/features/03_microgravity/sms/data/sms_repository.dart';
import 'package:astramed/features/03_microgravity/sms/domain/sms_models_and_analyzers.dart';
import 'package:astramed/features/03_microgravity/sms/presentation/sms_suite_page.dart';

void main() {
  group('Graybiel 1968 Diagnostic Scale (S4)', () {
    test('classifies 0 as none and 1-4 below EVA restriction threshold', () {
      const zero = GraybielSymptomAssessment();
      expect(zero.totalScore, 0);
      expect(zero.category, GraybielCategory.none);
      expect(zero.triggersEvaRestriction, isFalse);

      // 2 pts (epigastric discomfort = 2) -> slightMalaise
      const slight = GraybielSymptomAssessment(epigastricLevel: 2);
      expect(slight.totalScore, 2);
      expect(slight.category, GraybielCategory.slightMalaise);
      expect(slight.triggersEvaRestriction, isFalse);

      // 4 pts (minimal nausea = 4) -> moderateMalaiseB
      const modB = GraybielSymptomAssessment(nauseaLevel: 1);
      expect(modB.totalScore, 4);
      expect(modB.category, GraybielCategory.moderateMalaiseB);
      expect(modB.triggersEvaRestriction, isFalse);
    });

    test('classifies >= 5 as Moderate Malaise A and >= 16 as Frank Sickness', () {
      // 5 pts (minimal nausea 4 + headache 1) -> moderateMalaiseA
      const modA = GraybielSymptomAssessment(
        nauseaLevel: 1,
        headacheLevel: 1,
      );
      expect(modA.totalScore, 5);
      expect(
        modA.totalScore,
        greaterThanOrEqualTo(MedicalThresholds.graybielModerateMalaiseThreshold),
      );
      expect(modA.category, GraybielCategory.moderateMalaiseA);
      expect(modA.triggersEvaRestriction, isTrue);

      // 10 pts (moderate nausea 8 + cold sweating moderate 2) -> severeMalaise
      const severe = GraybielSymptomAssessment(
        nauseaLevel: 2,
        coldSweatingLevel: 2,
      );
      expect(severe.totalScore, 10);
      expect(severe.category, GraybielCategory.severeMalaise);
      expect(severe.triggersEvaRestriction, isTrue);

      // >= 16 pts -> frankSickness
      const frank = GraybielSymptomAssessment(
        nauseaLevel: 3, // 16 pts
        vertigoLevel: 2, // 2 pts
      );
      expect(frank.totalScore, 18);
      expect(frank.category, GraybielCategory.frankSickness);
      expect(frank.triggersEvaRestriction, isTrue);
    });
  });

  group('FacialGreennessAnalyzer Δ(G/R) with White Reference Card (S1)', () {
    test('normalizes G/R by whiteReferenceLuminance and classifies nominal, elevated, and critical', () {
      const baseline = 0.88;
      final t0 = DateTime(2026, 11, 14, 12, 0, 0);

      // 1. Serie nominal (Δ(G/R) ~ 0.010 < 0.035) con luminancia 0.80
      final nominalSamples = List.generate(15, (i) {
        const lum = 0.80;
        const red = 170.0;
        // Para que normalizedGreenRedRatio = (green / red) / lum = 0.89
        final green = red * 0.89 * lum;
        return FaceSample(
          timestamp: t0.add(Duration(seconds: i)),
          headYawDeg: 0,
          headPitchDeg: 0,
          headRollDeg: 0,
          gazeOffsetDeg: 0.5,
          ipdPixels: 140,
          cheekRedMean: red,
          cheekGreenMean: green,
          cheekBlueMean: 130,
          whiteReferenceLuminance: lum,
        );
      });

      final nomResult = FacialGreennessAnalyzer.analyze(
        samples: nominalSamples,
        baselineGreenRedRatio: baseline,
      );
      expect(nomResult.deltaGreenRedRatio, closeTo(0.01, 0.002));
      expect(nomResult.status, ChromaticityStatus.nominal);
      expect(nomResult.scientificNote, contains('Bonnard'));

      // 2. Serie elevada (Δ(G/R) ~ 0.050 >= 0.035)
      final elevatedSamples = List.generate(15, (i) {
        final shift = (i >= 10) ? 0.050 : 0.005;
        return FaceSample(
          timestamp: t0.add(Duration(seconds: i)),
          headYawDeg: 0,
          headPitchDeg: 0,
          headRollDeg: 0,
          gazeOffsetDeg: 0.8,
          ipdPixels: 140,
          cheekRedMean: 170.0,
          cheekGreenMean: 170.0 * (baseline + shift),
          cheekBlueMean: 130,
          whiteReferenceLuminance: 1.0,
        );
      });

      final elevResult = FacialGreennessAnalyzer.analyze(
        samples: elevatedSamples,
        baselineGreenRedRatio: baseline,
      );
      expect(
        elevResult.deltaGreenRedRatio,
        greaterThanOrEqualTo(MedicalThresholds.facialGreennessWarningDeltaRatio),
      );
      expect(elevResult.status, ChromaticityStatus.elevated);

      // 3. Serie crítica (Δ(G/R) ~ 0.085 >= 0.070)
      final criticalSamples = List.generate(15, (i) {
        final shift = (i >= 10) ? 0.085 : 0.010;
        return FaceSample(
          timestamp: t0.add(Duration(seconds: i)),
          headYawDeg: 0,
          headPitchDeg: 0,
          headRollDeg: 0,
          gazeOffsetDeg: 1.2,
          ipdPixels: 140,
          cheekRedMean: 170.0,
          cheekGreenMean: 170.0 * (baseline + shift),
          cheekBlueMean: 130,
          whiteReferenceLuminance: 1.0,
        );
      });

      final critResult = FacialGreennessAnalyzer.analyze(
        samples: criticalSamples,
        baselineGreenRedRatio: baseline,
      );
      expect(
        critResult.deltaGreenRedRatio,
        greaterThanOrEqualTo(MedicalThresholds.facialGreennessCriticalDeltaRatio),
      );
      expect(critResult.status, ChromaticityStatus.critical);
    });
  });

  group('GazeStabilityAnalyzer 1 Hz Oscillation & Fixation Retention (S2)', () {
    test('computes ~1 Hz oscillation frequency and fixation retention ratio', () {
      final t0 = DateTime(2026, 11, 14, 12, 0, 0);
      // 10 segundos a 20 Hz = 200 muestras con oscilación de 1.0 Hz
      final stableSamples = List.generate(200, (i) {
        final tSec = i * 0.05;
        final yaw = 18.0 * math.sin(2 * math.pi * 1.0 * tSec);
        return FaceSample(
          timestamp: t0.add(Duration(milliseconds: i * 50)),
          headYawDeg: yaw,
          headPitchDeg: 0,
          headRollDeg: 0,
          gazeOffsetDeg: 1.1, // <= 2.5°
          ipdPixels: 140,
          cheekRedMean: 170,
          cheekGreenMean: 150,
          cheekBlueMean: 130,
        );
      });

      final stableRes = GazeStabilityAnalyzer.analyze(
        samples: stableSamples,
        optotypeAccuracy: 1.0,
      );
      expect(stableRes.fixationRetentionRatio, 1.0);
      expect(stableRes.estimatedOscillationHz, closeTo(1.0, 0.15));
      expect(
        stableRes.compositeScore,
        greaterThanOrEqualTo(MedicalThresholds.minAcceptableGazeStabilityScore),
      );
      expect(stableRes.isStable, isTrue);

      // Inestabilidad ocular (gazeOffsetDeg = 4.2° > 2.5°)
      final unstableSamples = stableSamples
          .map(
            (s) => FaceSample(
              timestamp: s.timestamp,
              headYawDeg: s.headYawDeg,
              headPitchDeg: s.headPitchDeg,
              headRollDeg: s.headRollDeg,
              gazeOffsetDeg: 4.2,
              ipdPixels: s.ipdPixels,
              cheekRedMean: s.cheekRedMean,
              cheekGreenMean: s.cheekGreenMean,
              cheekBlueMean: s.cheekBlueMean,
            ),
          )
          .toList();

      final unstableRes = GazeStabilityAnalyzer.analyze(
        samples: unstableSamples,
        optotypeAccuracy: 0.5,
      );
      expect(unstableRes.fixationRetentionRatio, 0.0);
      expect(unstableRes.isStable, isFalse);
    });
  });

  group('Zero-G Horizon & EVA NO-GO Advisory (S3, S4)', () {
    test('triggers EVA NO-GO when Graybiel >= 5 OR Zero-G Horizon < 70%', () {
      const nomGreen = FacialGreennessResult(
        baselineGreenRedRatio: 0.88,
        initialGreenRedRatio: 0.88,
        finalGreenRedRatio: 0.885,
        deltaGreenRedRatio: 0.005,
        meanWhiteReferenceLuminance: 1.0,
        validSampleCount: 30,
        status: ChromaticityStatus.nominal,
        scientificNote: FacialGreennessAnalyzer.defaultScientificNote,
      );
      const nomGaze = GazeStabilityResult(
        estimatedOscillationHz: 1.0,
        frequencyConsistencyScore: 0.98,
        fixationRetentionRatio: 0.95,
        optotypeAccuracy: 1.0,
        compositeScore: 0.96,
        meanGazeOffsetDeg: 0.8,
        isStable: true,
      );

      final passHorizon = ZeroGHorizonResult.fromAxisErrors(
        meanRollErrorDeg: 2.0,
        meanPitchErrorDeg: 2.0,
        meanYawErrorDeg: 2.0,
      );
      expect(passHorizon.alignmentAccuracyPercent, greaterThanOrEqualTo(70.0));
      expect(passHorizon.passed, isTrue);

      // Caso 1: Todo nominal -> GO EVA
      final goEval = SmsComprehensiveAssessment.evaluate(
        id: 'sms_go',
        graybiel: const GraybielSymptomAssessment(epigastricLevel: 1), // 1 pt
        facialGreenness: nomGreen,
        gazeStability: nomGaze,
        zeroGHorizon: passHorizon,
      );
      expect(goEval.evaNoGoRecommended, isFalse);
      expect(goEval.evaAdvisory.severityCode, 'GREEN');

      // Caso 2: Graybiel >= 5 con Horizon aprobado -> NO-GO EVA
      final noGoByGraybiel = SmsComprehensiveAssessment.evaluate(
        id: 'sms_nogo_graybiel',
        graybiel: const GraybielSymptomAssessment(
          nauseaLevel: 1, // 4 pts
          epigastricLevel: 1, // 1 pt -> total 5 pts
        ),
        facialGreenness: nomGreen,
        gazeStability: nomGaze,
        zeroGHorizon: passHorizon,
      );
      expect(noGoByGraybiel.evaNoGoRecommended, isTrue);
      expect(
        noGoByGraybiel.evaAdvisory.clinicalRationale,
        contains(
          'RECOMENDACIÓN NO-GO EVA — Riesgo de emesis en casco presurizado y desorientación espacial. Notificar al Cirujano de Vuelo',
        ),
      );

      // Caso 3: Graybiel = 0 pero Zero-G Horizon < 70% -> NO-GO EVA
      final failHorizon = ZeroGHorizonResult.fromAxisErrors(
        meanRollErrorDeg: 15.0,
        meanPitchErrorDeg: 14.0,
        meanYawErrorDeg: 16.0,
      );
      expect(failHorizon.alignmentAccuracyPercent, lessThan(70.0));
      expect(failHorizon.passed, isFalse);

      final noGoByHorizon = SmsComprehensiveAssessment.evaluate(
        id: 'sms_nogo_horizon',
        graybiel: const GraybielSymptomAssessment(),
        facialGreenness: nomGreen,
        gazeStability: nomGaze,
        zeroGHorizon: failHorizon,
      );
      expect(noGoByHorizon.evaNoGoRecommended, isTrue);
      expect(
        noGoByHorizon.evaAdvisory.clinicalRationale,
        contains(
          'RECOMENDACIÓN NO-GO EVA — Riesgo de emesis en casco presurizado y desorientación espacial. Notificar al Cirujano de Vuelo',
        ),
      );
    });

    test('SmsRepository stores and round-trips SmsComprehensiveAssessment in memory', () async {
      final repo = SmsRepository();
      final assessment = SmsComprehensiveAssessment.evaluate(
        id: 'sms_repo_1',
        graybiel: const GraybielSymptomAssessment(nauseaLevel: 2),
        facialGreenness: const FacialGreennessResult(
          baselineGreenRedRatio: 0.88,
          initialGreenRedRatio: 0.88,
          finalGreenRedRatio: 0.93,
          deltaGreenRedRatio: 0.05,
          meanWhiteReferenceLuminance: 1.0,
          validSampleCount: 20,
          status: ChromaticityStatus.elevated,
          scientificNote: FacialGreennessAnalyzer.defaultScientificNote,
        ),
        gazeStability: const GazeStabilityResult(
          estimatedOscillationHz: 1.0,
          frequencyConsistencyScore: 0.9,
          fixationRetentionRatio: 0.75,
          optotypeAccuracy: 0.8,
          compositeScore: 0.78,
          meanGazeOffsetDeg: 2.8,
          isStable: false,
        ),
        zeroGHorizon: ZeroGHorizonResult.fromAxisErrors(
          meanRollErrorDeg: 4.0,
          meanPitchErrorDeg: 4.0,
          meanYawErrorDeg: 4.0,
        ),
      );

      await repo.saveAssessment(assessment);
      final loaded = repo.loadAll();
      expect(loaded, hasLength(1));
      expect(loaded.first.id, 'sms_repo_1');
      expect(loaded.first.evaNoGoRecommended, isTrue);

      final roundTripped =
          SmsComprehensiveAssessment.fromMap(assessment.toMap());
      expect(roundTripped.graybiel.totalScore, assessment.graybiel.totalScore);
      expect(roundTripped.evaNoGoRecommended, isTrue);
    });
  });

  group('SmsSuitePage Presentation Smoke Test', () {
    testWidgets('renders 3 tabs including White Reference Card, Zero-G Horizon, and EVA Verdict', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: SmsSuitePage(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(
        find.textContaining('TARJETA BLANCA DE REFERENCIA'),
        findsOneWidget,
      );
      expect(find.text('2. Zero-G Horizon (45s)'), findsOneWidget);
      expect(find.text('3. Dictamen EVA & Cola'), findsOneWidget);
    });
  });
}
