import 'dart:math' as math;

import '../../../../core/calibration/domain/device_calibration.dart';
import '../../../../core/constants/medical_thresholds.dart';
import '../../../../core/sensing/domain/sensing_ports.dart';

/// Nivel de Gafas de Anticipación Espacial (Space Anticipation Glasses)
/// inspirado en NASA OCHMO-MTB-001 y Mader et al. (2011) (+0.50 a +1.75 D).
enum SpaceAnticipationGlassesTier {
  none,
  pair1Plus075D,
  pair2Plus125D,
  pair3Plus175D,
}

extension SpaceAnticipationGlassesTierX on SpaceAnticipationGlassesTier {
  String get labelEs {
    switch (this) {
      case SpaceAnticipationGlassesTier.none:
        return 'Sin gafas preventivas (Visión cercana nominal)';
      case SpaceAnticipationGlassesTier.pair1Plus075D:
        return 'Gafas de Anticipación Espacial Par #1 (+0.75 D)';
      case SpaceAnticipationGlassesTier.pair2Plus125D:
        return 'Gafas de Anticipación Espacial Par #2 (+1.25 D)';
      case SpaceAnticipationGlassesTier.pair3Plus175D:
        return 'Gafas de Anticipación Espacial Par #3 (+1.75 D)';
    }
  }

  double get powerDiopters {
    switch (this) {
      case SpaceAnticipationGlassesTier.none:
        return 0.0;
      case SpaceAnticipationGlassesTier.pair1Plus075D:
        return 0.75;
      case SpaceAnticipationGlassesTier.pair2Plus125D:
        return 1.25;
      case SpaceAnticipationGlassesTier.pair3Plus175D:
        return 1.75;
    }
  }
}

/// Resultado de la estimación trigonométrica de punto cercano y desplazamiento
/// hipermetrópico relativo a la línea base pre-misión del astronauta (S5).
class NearPointEstimate {
  final double distanceCm;
  final double baselineNearPointCm;
  final double hyperopicShiftDiopters;
  final double confidenceIntervalDiopters;
  final SpaceAnticipationGlassesTier recommendedGlassesTier;
  final bool requiresFlightSurgeonAlert;
  final String clinicalSummaryEs;

  const NearPointEstimate({
    required this.distanceCm,
    required this.baselineNearPointCm,
    required this.hyperopicShiftDiopters,
    required this.confidenceIntervalDiopters,
    required this.recommendedGlassesTier,
    required this.requiresFlightSurgeonAlert,
    required this.clinicalSummaryEs,
  });

  Map<String, dynamic> toMap() {
    return {
      'distanceCm': distanceCm,
      'baselineNearPointCm': baselineNearPointCm,
      'hyperopicShiftDiopters': hyperopicShiftDiopters,
      'confidenceIntervalDiopters': confidenceIntervalDiopters,
      'recommendedGlassesTier': recommendedGlassesTier.name,
      'requiresFlightSurgeonAlert': requiresFlightSurgeonAlert,
      'clinicalSummaryEs': clinicalSummaryEs,
    };
  }

  factory NearPointEstimate.fromMap(Map<dynamic, dynamic> map) {
    final tierName = map['recommendedGlassesTier'] as String? ?? 'none';
    final tier = SpaceAnticipationGlassesTier.values.firstWhere(
      (e) => e.name == tierName,
      orElse: () => SpaceAnticipationGlassesTier.none,
    );
    return NearPointEstimate(
      distanceCm: (map['distanceCm'] as num?)?.toDouble() ??
          MedicalThresholds.defaultNearPointBaselineCm,
      baselineNearPointCm: (map['baselineNearPointCm'] as num?)?.toDouble() ??
          MedicalThresholds.defaultNearPointBaselineCm,
      hyperopicShiftDiopters:
          (map['hyperopicShiftDiopters'] as num?)?.toDouble() ?? 0.0,
      confidenceIntervalDiopters:
          (map['confidenceIntervalDiopters'] as num?)?.toDouble() ?? 0.18,
      recommendedGlassesTier: tier,
      requiresFlightSurgeonAlert:
          map['requiresFlightSurgeonAlert'] as bool? ?? false,
      clinicalSummaryEs: map['clinicalSummaryEs'] as String? ?? '',
    );
  }
}

/// Calculadora trigonométrica de distancia ojo-pantalla mediante IPD en píxeles
/// y conversión a desplazamiento hipermetrópico relativo (ΔD) con banda de confianza.
class NearPointDiopterCalculator {
  /// Calcula la distancia entre los ojos y la pantalla en centímetros:
  /// d_cm = (f_px * IPD_mm) / (10 * IPD_px) * cos(yaw)
  static double computeEyeToScreenDistanceCm({
    required double ipdPixels,
    required DeviceCalibration calibration,
    double headYawDeg = 0.0,
  }) {
    return computeDistanceCmFromRaw(
      ipdPixels: ipdPixels,
      focalLengthPx: calibration.focalLengthPx,
      crewIpdMm: calibration.crewIpdMm,
      headYawDeg: headYawDeg,
    );
  }

  /// Versión parametrizada directa para pruebas o calibraciones personalizadas.
  static double computeDistanceCmFromRaw({
    required double ipdPixels,
    required double focalLengthPx,
    required double crewIpdMm,
    double headYawDeg = 0.0,
  }) {
    if (ipdPixels <= 1.0) return 80.0;
    final yawRad = headYawDeg * math.pi / 180.0;
    final yawCos = math.cos(yawRad).clamp(0.75, 1.0);
    final rawDistanceCm = (focalLengthPx * crewIpdMm * yawCos) / (10.0 * ipdPixels);
    return rawDistanceCm.clamp(10.0, 100.0);
  }

  /// Calcula el desplazamiento hipermetrópico relativo al punto cercano basal:
  /// ΔD = max(0, 100 / d_base,cm - 100 / d_now,cm)
  static double computeHyperopicShiftDiopters({
    required double currentNearPointCm,
    double baselineNearPointCm = MedicalThresholds.defaultNearPointBaselineCm,
  }) {
    final safeBaseCm = baselineNearPointCm.clamp(10.0, 80.0);
    final safeNowCm = currentNearPointCm.clamp(10.0, 100.0);
    final deltaD = (100.0 / safeBaseCm) - (100.0 / safeNowCm);
    return math.max(0.0, deltaD);
  }

  /// Clasifica el par de Gafas de Anticipación Espacial según ΔD.
  static SpaceAnticipationGlassesTier selectGlassesTier(double deltaDiopters) {
    if (deltaDiopters >= MedicalThresholds.sansHyperopicShiftPair3Diopters) {
      return SpaceAnticipationGlassesTier.pair3Plus175D;
    }
    if (deltaDiopters >= MedicalThresholds.sansHyperopicShiftPair2Diopters) {
      return SpaceAnticipationGlassesTier.pair2Plus125D;
    }
    if (deltaDiopters >= MedicalThresholds.sansHyperopicShiftPair1Diopters) {
      return SpaceAnticipationGlassesTier.pair1Plus075D;
    }
    return SpaceAnticipationGlassesTier.none;
  }

  /// Evalúa el punto cercano a partir de una distancia medida en cm.
  static NearPointEstimate evaluateFromDistanceCm({
    required double currentNearPointCm,
    double baselineNearPointCm = MedicalThresholds.defaultNearPointBaselineCm,
  }) {
    final safeNowCm = currentNearPointCm.clamp(10.0, 100.0);
    final safeBaseCm = baselineNearPointCm.clamp(10.0, 80.0);
    final deltaD = computeHyperopicShiftDiopters(
      currentNearPointCm: safeNowCm,
      baselineNearPointCm: safeBaseCm,
    );

    // Banda de confianza al 95% (~7-8% incertidumbre óptica combinada sobre demanda acomodativa)
    final accommodativeDemandNow = 100.0 / safeNowCm;
    final ciDiopters = (accommodativeDemandNow * 0.08).clamp(0.12, 0.40);

    final tier = selectGlassesTier(deltaD);
    final requiresAlert =
        deltaD >= MedicalThresholds.sansHyperopicShiftPair2Diopters;

    final deltaStr = '+${deltaD.toStringAsFixed(2)} D';
    final ciStr = '±${ciDiopters.toStringAsFixed(2)} D';

    final String summary;
    switch (tier) {
      case SpaceAnticipationGlassesTier.none:
        summary =
            'Desplazamiento estimado de $deltaStr ($ciStr) respecto a tu basal. '
            'Recomendación: Sin gafas preventivas (Visión cercana nominal).';
        break;
      case SpaceAnticipationGlassesTier.pair1Plus075D:
        summary =
            'Desplazamiento estimado de $deltaStr ($ciStr) respecto a tu basal. '
            'Recomendación: Gafas de Anticipación Par #1 (+0.75 D).';
        break;
      case SpaceAnticipationGlassesTier.pair2Plus125D:
        summary =
            'Desplazamiento estimado de $deltaStr ($ciStr) respecto a tu basal. '
            'Recomendación: Gafas de Anticipación Par #2 y reporte al Cirujano de Vuelo.';
        break;
      case SpaceAnticipationGlassesTier.pair3Plus175D:
        summary =
            'Desplazamiento estimado de $deltaStr ($ciStr) respecto a tu basal. '
            'Recomendación: Gafas de Anticipación Par #3 (+1.75 D) y notificación prioritaria al Cirujano de Vuelo.';
        break;
    }

    return NearPointEstimate(
      distanceCm: safeNowCm,
      baselineNearPointCm: safeBaseCm,
      hyperopicShiftDiopters: deltaD,
      confidenceIntervalDiopters: ciDiopters,
      recommendedGlassesTier: tier,
      requiresFlightSurgeonAlert: requiresAlert,
      clinicalSummaryEs: summary,
    );
  }

  /// Evalúa el punto cercano directamente desde la IPD en píxeles de la cámara frontal.
  static NearPointEstimate evaluateFromIpdPixels({
    required double ipdPixels,
    required DeviceCalibration calibration,
    double headYawDeg = 0.0,
  }) {
    final distanceCm = computeEyeToScreenDistanceCm(
      ipdPixels: ipdPixels,
      calibration: calibration,
      headYawDeg: headYawDeg,
    );
    return evaluateFromDistanceCm(
      currentNearPointCm: distanceCm,
      baselineNearPointCm: calibration.baselineNearPointCm,
    );
  }
}

/// Ojo evaluado en protocolo monocular (oclusión del ojo contralateral).
enum OcularEye {
  odRight, // Ojo Derecho (OD)
  osLeft, // Ojo Izquierdo (OI / OS)
}

extension OcularEyeX on OcularEye {
  String get codeEs => this == OcularEye.odRight ? 'OD' : 'OI';
  String get fullNameEs =>
      this == OcularEye.odRight ? 'Ojo Derecho (OD)' : 'Ojo Izquierdo (OI)';
}

/// Nivel de riesgo funcional psicofísico de SANS (TechPort 97109).
/// Nota clínica: No sustituye la escala de Frisén (0-5) medida por OCT/fundoscopía.
enum SansFunctionalRiskTier {
  nominal,
  mildFunctionalShift,
  moderateFoldsOrScotoma,
  criticalNotifyFlightSurgeon,
}

extension SansFunctionalRiskTierX on SansFunctionalRiskTier {
  String get labelEs {
    switch (this) {
      case SansFunctionalRiskTier.nominal:
        return 'Nominal (Sin metamorfopsia ni escotoma funcional)';
      case SansFunctionalRiskTier.mildFunctionalShift:
        return 'Cambio Funcional Leve (Vigilancia SANS)';
      case SansFunctionalRiskTier.moderateFoldsOrScotoma:
        return 'Moderado: Pliegues Coroideos / Escotoma Peripapilar';
      case SansFunctionalRiskTier.criticalNotifyFlightSurgeon:
        return 'Crítico: Metamorfopsia / Escotoma Severo — Notificar Cirujano de Vuelo';
    }
  }
}

/// Estímulo periférico de bajo contraste para mapeo de sensibilidad al contraste
/// y punto ciego / escotoma peripapilar (~15° temporal).
class PeripheralFlashStimulus {
  final String id;
  final double eccentricityDeg;
  final double polarAngleDeg;
  final double contrastLevel; // [0.05..0.40]
  final bool isPeripapillaryZone;
  final bool detectedByUser;

  const PeripheralFlashStimulus({
    required this.id,
    required this.eccentricityDeg,
    required this.polarAngleDeg,
    required this.contrastLevel,
    required this.isPeripapillaryZone,
    required this.detectedByUser,
  });

  PeripheralFlashStimulus copyWith({bool? detectedByUser}) {
    return PeripheralFlashStimulus(
      id: id,
      eccentricityDeg: eccentricityDeg,
      polarAngleDeg: polarAngleDeg,
      contrastLevel: contrastLevel,
      isPeripapillaryZone: isPeripapillaryZone,
      detectedByUser: detectedByUser ?? this.detectedByUser,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'eccentricityDeg': eccentricityDeg,
      'polarAngleDeg': polarAngleDeg,
      'contrastLevel': contrastLevel,
      'isPeripapillaryZone': isPeripapillaryZone,
      'detectedByUser': detectedByUser,
    };
  }

  factory PeripheralFlashStimulus.fromMap(Map<dynamic, dynamic> map) {
    return PeripheralFlashStimulus(
      id: map['id'] as String? ?? '',
      eccentricityDeg: (map['eccentricityDeg'] as num?)?.toDouble() ?? 10.0,
      polarAngleDeg: (map['polarAngleDeg'] as num?)?.toDouble() ?? 0.0,
      contrastLevel: (map['contrastLevel'] as num?)?.toDouble() ?? 0.15,
      isPeripapillaryZone: map['isPeripapillaryZone'] as bool? ?? false,
      detectedByUser: map['detectedByUser'] as bool? ?? false,
    );
  }
}

/// Resultado de la prueba psicofísica "Starfield Distortion Hunter" (TechPort 97109).
class StarfieldAssessmentResult {
  final OcularEye evaluatedEye;
  final double injectedWaveAmplitude;
  final double userStraighteningSlider;
  final double residualMetamorphopsiaIndex;
  final double contrastSensitivityScore;
  final int totalStimuliCount;
  final int missedStimuliCount;
  final int peripapillaryMissedCount;
  final bool blindSpotEnlargementDetected;
  final double centralFixationScore;
  final bool isFixationReliable;
  final SansFunctionalRiskTier riskTier;
  final bool shouldLaunchLbnpCountermeasure;
  final String clinicalNoteEs;

  const StarfieldAssessmentResult({
    required this.evaluatedEye,
    required this.injectedWaveAmplitude,
    required this.userStraighteningSlider,
    required this.residualMetamorphopsiaIndex,
    required this.contrastSensitivityScore,
    required this.totalStimuliCount,
    required this.missedStimuliCount,
    required this.peripapillaryMissedCount,
    required this.blindSpotEnlargementDetected,
    required this.centralFixationScore,
    required this.isFixationReliable,
    required this.riskTier,
    required this.shouldLaunchLbnpCountermeasure,
    required this.clinicalNoteEs,
  });

  Map<String, dynamic> toMap() {
    return {
      'evaluatedEye': evaluatedEye.name,
      'injectedWaveAmplitude': injectedWaveAmplitude,
      'userStraighteningSlider': userStraighteningSlider,
      'residualMetamorphopsiaIndex': residualMetamorphopsiaIndex,
      'contrastSensitivityScore': contrastSensitivityScore,
      'totalStimuliCount': totalStimuliCount,
      'missedStimuliCount': missedStimuliCount,
      'peripapillaryMissedCount': peripapillaryMissedCount,
      'blindSpotEnlargementDetected': blindSpotEnlargementDetected,
      'centralFixationScore': centralFixationScore,
      'isFixationReliable': isFixationReliable,
      'riskTier': riskTier.name,
      'shouldLaunchLbnpCountermeasure': shouldLaunchLbnpCountermeasure,
      'clinicalNoteEs': clinicalNoteEs,
    };
  }

  factory StarfieldAssessmentResult.fromMap(Map<dynamic, dynamic> map) {
    final eyeName = map['evaluatedEye'] as String? ?? 'odRight';
    final eye = OcularEye.values.firstWhere(
      (e) => e.name == eyeName,
      orElse: () => OcularEye.odRight,
    );
    final tierName = map['riskTier'] as String? ?? 'nominal';
    final tier = SansFunctionalRiskTier.values.firstWhere(
      (e) => e.name == tierName,
      orElse: () => SansFunctionalRiskTier.nominal,
    );
    return StarfieldAssessmentResult(
      evaluatedEye: eye,
      injectedWaveAmplitude:
          (map['injectedWaveAmplitude'] as num?)?.toDouble() ?? 0.0,
      userStraighteningSlider:
          (map['userStraighteningSlider'] as num?)?.toDouble() ?? 0.0,
      residualMetamorphopsiaIndex:
          (map['residualMetamorphopsiaIndex'] as num?)?.toDouble() ?? 0.0,
      contrastSensitivityScore:
          (map['contrastSensitivityScore'] as num?)?.toDouble() ?? 1.0,
      totalStimuliCount: (map['totalStimuliCount'] as num?)?.toInt() ?? 0,
      missedStimuliCount: (map['missedStimuliCount'] as num?)?.toInt() ?? 0,
      peripapillaryMissedCount:
          (map['peripapillaryMissedCount'] as num?)?.toInt() ?? 0,
      blindSpotEnlargementDetected:
          map['blindSpotEnlargementDetected'] as bool? ?? false,
      centralFixationScore:
          (map['centralFixationScore'] as num?)?.toDouble() ?? 1.0,
      isFixationReliable: map['isFixationReliable'] as bool? ?? true,
      riskTier: tier,
      shouldLaunchLbnpCountermeasure:
          map['shouldLaunchLbnpCountermeasure'] as bool? ?? false,
      clinicalNoteEs: map['clinicalNoteEs'] as String? ?? '',
    );
  }
}

/// Analizador psicofísico inspirado en NASA TechPort 97109 (Visual Field,
/// Contrast Sensitivity y Metamorphopsia / Amsler dinámica con verificación de fijación).
class StarfieldDistortionAnalyzer {
  static const double maxAllowedGazeOffsetDeg = 3.0;

  /// Genera la batería estándar de 8 destellos periféricos de bajo contraste
  /// alrededor del planeta central, incluyendo la zona temporal de ~15° (punto ciego).
  static List<PeripheralFlashStimulus> buildStandardStimuli({
    required OcularEye eye,
    bool defaultDetected = true,
  }) {
    // Para OD el campo temporal está a ~0° (derecha); para OI está a ~180° (izquierda).
    final temporalBaseAngle = eye == OcularEye.odRight ? 0.0 : 180.0;
    final nasalBaseAngle = eye == OcularEye.odRight ? 180.0 : 0.0;

    return [
      PeripheralFlashStimulus(
        id: 'peri_temporal_center',
        eccentricityDeg: MedicalThresholds.blindSpotTemporalDeg,
        polarAngleDeg: temporalBaseAngle,
        contrastLevel: 0.14,
        isPeripapillaryZone: true,
        detectedByUser: defaultDetected,
      ),
      PeripheralFlashStimulus(
        id: 'peri_temporal_sup',
        eccentricityDeg: MedicalThresholds.blindSpotTemporalDeg - 1.5,
        polarAngleDeg: (temporalBaseAngle + 18.0) % 360.0,
        contrastLevel: 0.12,
        isPeripapillaryZone: true,
        detectedByUser: defaultDetected,
      ),
      PeripheralFlashStimulus(
        id: 'peri_temporal_inf',
        eccentricityDeg: MedicalThresholds.blindSpotTemporalDeg + 1.5,
        polarAngleDeg: (temporalBaseAngle + 342.0) % 360.0,
        contrastLevel: 0.12,
        isPeripapillaryZone: true,
        detectedByUser: defaultDetected,
      ),
      PeripheralFlashStimulus(
        id: 'quad_sup_right',
        eccentricityDeg: 10.0,
        polarAngleDeg: 45.0,
        contrastLevel: 0.10,
        isPeripapillaryZone: false,
        detectedByUser: defaultDetected,
      ),
      PeripheralFlashStimulus(
        id: 'quad_sup_left',
        eccentricityDeg: 10.0,
        polarAngleDeg: 135.0,
        contrastLevel: 0.10,
        isPeripapillaryZone: false,
        detectedByUser: defaultDetected,
      ),
      PeripheralFlashStimulus(
        id: 'quad_inf_left',
        eccentricityDeg: 11.0,
        polarAngleDeg: 225.0,
        contrastLevel: 0.15,
        isPeripapillaryZone: false,
        detectedByUser: defaultDetected,
      ),
      PeripheralFlashStimulus(
        id: 'quad_inf_right',
        eccentricityDeg: 11.0,
        polarAngleDeg: 315.0,
        contrastLevel: 0.15,
        isPeripapillaryZone: false,
        detectedByUser: defaultDetected,
      ),
      PeripheralFlashStimulus(
        id: 'nasal_mid',
        eccentricityDeg: 12.0,
        polarAngleDeg: nasalBaseAngle,
        contrastLevel: 0.11,
        isPeripapillaryZone: false,
        detectedByUser: defaultDetected,
      ),
    ];
  }

  /// Calcula la fracción de muestras faciales donde el astronauta mantuvo la mirada
  /// fija sobre el planeta central (`gazeOffsetDeg <= 3.0°`).
  static double computeCentralFixationScore(List<FaceSample> samples) {
    if (samples.isEmpty) return 1.0;
    final validSamples = samples.where((s) => s.faceDetected).toList();
    if (validSamples.isEmpty) return 0.0;
    final onTarget = validSamples
        .where((s) => s.gazeOffsetDeg.abs() <= maxAllowedGazeOffsetDeg)
        .length;
    return (onTarget / validSamples.length).clamp(0.0, 1.0);
  }

  /// Evalúa metamorfopsia ("Caza de Pliegues"), sensibilidad al contraste periférica,
  /// ensanchamiento del escotoma peripapilar (~15° temporal) y fijación central.
  static StarfieldAssessmentResult evaluate({
    required OcularEye evaluatedEye,
    required double injectedWaveAmplitude,
    required double userStraighteningSlider,
    required List<PeripheralFlashStimulus> stimuli,
    List<FaceSample> fixationSamples = const [],
    double? overrideFixationScore,
  }) {
    // Discrepancia residual entre la curvatura inyectada en la malla y la compensación del usuario
    final residualMetamorphopsia =
        (injectedWaveAmplitude - userStraighteningSlider).abs().clamp(0.0, 2.0);

    final totalCount = stimuli.length;
    final missedStimuli = stimuli.where((s) => !s.detectedByUser).toList();
    final missedCount = missedStimuli.length;
    final peripapillaryMissed = missedStimuli
        .where(
          (s) =>
              s.isPeripapillaryZone ||
              (s.eccentricityDeg - MedicalThresholds.blindSpotTemporalDeg)
                      .abs() <=
                  3.5,
        )
        .length;

    final contrastScore = totalCount == 0
        ? 1.0
        : ((totalCount - missedCount) / totalCount).clamp(0.0, 1.0);

    // Ensanchamiento del escotoma peripapilar si pierde >= 2 estímulos en anillo ~15° temporal
    final blindSpotEnlarged = peripapillaryMissed >= 2;

    final fixationScore = overrideFixationScore?.clamp(0.0, 1.0) ??
        computeCentralFixationScore(fixationSamples);
    final fixationReliable =
        fixationScore >= MedicalThresholds.minAcceptableGazeStabilityScore;

    // Clasificación del nivel de riesgo funcional SANS (TechPort 97109)
    final SansFunctionalRiskTier riskTier;
    if (residualMetamorphopsia >= 0.60 ||
        contrastScore < 0.50 ||
        (blindSpotEnlarged && residualMetamorphopsia >= 0.35)) {
      riskTier = SansFunctionalRiskTier.criticalNotifyFlightSurgeon;
    } else if (residualMetamorphopsia >= 0.35 ||
        contrastScore < 0.70 ||
        blindSpotEnlarged) {
      riskTier = SansFunctionalRiskTier.moderateFoldsOrScotoma;
    } else if (residualMetamorphopsia >= 0.18 || contrastScore < 0.85) {
      riskTier = SansFunctionalRiskTier.mildFunctionalShift;
    } else {
      riskTier = SansFunctionalRiskTier.nominal;
    }

    final shouldLaunchLbnp = riskTier != SansFunctionalRiskTier.nominal;

    final fixationNotice = fixationReliable
        ? 'Fijación central verificada (${(fixationScore * 100).toStringAsFixed(0)}%).'
        : 'Baja fijación central (${(fixationScore * 100).toStringAsFixed(0)}%); repetir con vista fija en el planeta central.';

    final note =
        '[${evaluatedEye.codeEs}] ${riskTier.labelEs}. '
        'Índice metamorfopsia residual: ${residualMetamorphopsia.toStringAsFixed(2)}, '
        'Sensibilidad al contraste: ${(contrastScore * 100).toStringAsFixed(0)}%, '
        'Escotoma peripapilar (~15°): ${blindSpotEnlarged ? "Ensanchado ($peripapillaryMissed fallos)" : "Fisiológico"}. '
        '$fixationNotice '
        'Nota clínica (TechPort 97109): Cribado funcional psicofísico; la estadificación formal de edema de disco óptico (ODE) requiere escala de Frisén (0–5) por OCT/fundoscopía.';

    return StarfieldAssessmentResult(
      evaluatedEye: evaluatedEye,
      injectedWaveAmplitude: injectedWaveAmplitude,
      userStraighteningSlider: userStraighteningSlider,
      residualMetamorphopsiaIndex: residualMetamorphopsia,
      contrastSensitivityScore: contrastScore,
      totalStimuliCount: totalCount,
      missedStimuliCount: missedCount,
      peripapillaryMissedCount: peripapillaryMissed,
      blindSpotEnlargementDetected: blindSpotEnlarged,
      centralFixationScore: fixationScore,
      isFixationReliable: fixationReliable,
      riskTier: riskTier,
      shouldLaunchLbnpCountermeasure: shouldLaunchLbnp,
      clinicalNoteEs: note,
    );
  }
}

/// Fases de la máquina de estados del protocolo LBNP (-20 mmHg) (Lawley et al. 2017).
enum LbnpPhase {
  idle,
  rampDown,
  activeHoldMinus20,
  mandatoryGradualDecompression,
  completed,
  aborted,
}

extension LbnpPhaseX on LbnpPhase {
  String get labelEs {
    switch (this) {
      case LbnpPhase.idle:
        return 'En Espera (0 mmHg)';
      case LbnpPhase.rampDown:
        return 'Presurización Negativa Progresiva';
      case LbnpPhase.activeHoldMinus20:
        return 'Mantenimiento Activo (-20.0 mmHg)';
      case LbnpPhase.mandatoryGradualDecompression:
        return 'Descompresión Gradual Obligatoria (Bloqueo Hemodinámico)';
      case LbnpPhase.completed:
        return 'Sesión Completada con Retorno Seguro (0 mmHg)';
      case LbnpPhase.aborted:
        return 'Sesión Cancelada en Reposo';
    }
  }
}

/// Estado inmutable de una sesión del asistente de contramedida LBNP (-20 mmHg).
class LbnpSessionState {
  final String sessionId;
  final LbnpPhase phase;
  final double currentPressureMmHg;
  final double targetPressureMmHg;
  final int activeHoldElapsedSeconds;
  final int targetHoldDurationSeconds;
  final int decompressionElapsedSeconds;
  final int requiredDecompressionSeconds;
  final bool hemodynamicSafetyLockActive;
  final String statusMessageEs;
  final String? warningBannerEs;
  final DateTime startedAt;
  final DateTime? completedAt;

  const LbnpSessionState({
    required this.sessionId,
    required this.phase,
    required this.currentPressureMmHg,
    this.targetPressureMmHg = MedicalThresholds.lbnpTargetPressureMmHg,
    required this.activeHoldElapsedSeconds,
    required this.targetHoldDurationSeconds,
    required this.decompressionElapsedSeconds,
    this.requiredDecompressionSeconds =
        MedicalThresholds.lbnpMinDecompressionSeconds,
    required this.hemodynamicSafetyLockActive,
    required this.statusMessageEs,
    this.warningBannerEs,
    required this.startedAt,
    this.completedAt,
  });

  factory LbnpSessionState.initial({
    String sessionId = 'lbnp_idle',
    int targetHoldDurationSeconds = 60,
    int requiredDecompressionSeconds =
        MedicalThresholds.lbnpMinDecompressionSeconds,
  }) {
    return LbnpSessionState(
      sessionId: sessionId,
      phase: LbnpPhase.idle,
      currentPressureMmHg: 0.0,
      targetPressureMmHg: MedicalThresholds.lbnpTargetPressureMmHg,
      activeHoldElapsedSeconds: 0,
      targetHoldDurationSeconds: targetHoldDurationSeconds,
      decompressionElapsedSeconds: 0,
      requiredDecompressionSeconds: requiredDecompressionSeconds,
      hemodynamicSafetyLockActive: false,
      statusMessageEs:
          'Protocolo Chibis / LBNP (-20 mmHg) listo bajo prescripción del Cirujano de Vuelo.',
      warningBannerEs: null,
      startedAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  }

  double get decompressionProgress {
    if (requiredDecompressionSeconds <= 0) return 1.0;
    return (decompressionElapsedSeconds / requiredDecompressionSeconds)
        .clamp(0.0, 1.0);
  }

  double get activeHoldProgress {
    if (targetHoldDurationSeconds <= 0) return 1.0;
    return (activeHoldElapsedSeconds / targetHoldDurationSeconds)
        .clamp(0.0, 1.0);
  }

  LbnpSessionState copyWith({
    String? sessionId,
    LbnpPhase? phase,
    double? currentPressureMmHg,
    double? targetPressureMmHg,
    int? activeHoldElapsedSeconds,
    int? targetHoldDurationSeconds,
    int? decompressionElapsedSeconds,
    int? requiredDecompressionSeconds,
    bool? hemodynamicSafetyLockActive,
    String? statusMessageEs,
    String? warningBannerEs,
    bool clearWarningBanner = false,
    DateTime? startedAt,
    DateTime? completedAt,
  }) {
    return LbnpSessionState(
      sessionId: sessionId ?? this.sessionId,
      phase: phase ?? this.phase,
      currentPressureMmHg: currentPressureMmHg ?? this.currentPressureMmHg,
      targetPressureMmHg: targetPressureMmHg ?? this.targetPressureMmHg,
      activeHoldElapsedSeconds:
          activeHoldElapsedSeconds ?? this.activeHoldElapsedSeconds,
      targetHoldDurationSeconds:
          targetHoldDurationSeconds ?? this.targetHoldDurationSeconds,
      decompressionElapsedSeconds:
          decompressionElapsedSeconds ?? this.decompressionElapsedSeconds,
      requiredDecompressionSeconds:
          requiredDecompressionSeconds ?? this.requiredDecompressionSeconds,
      hemodynamicSafetyLockActive:
          hemodynamicSafetyLockActive ?? this.hemodynamicSafetyLockActive,
      statusMessageEs: statusMessageEs ?? this.statusMessageEs,
      warningBannerEs: clearWarningBanner
          ? null
          : (warningBannerEs ?? this.warningBannerEs),
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'sessionId': sessionId,
      'phase': phase.name,
      'currentPressureMmHg': currentPressureMmHg,
      'targetPressureMmHg': targetPressureMmHg,
      'activeHoldElapsedSeconds': activeHoldElapsedSeconds,
      'targetHoldDurationSeconds': targetHoldDurationSeconds,
      'decompressionElapsedSeconds': decompressionElapsedSeconds,
      'requiredDecompressionSeconds': requiredDecompressionSeconds,
      'hemodynamicSafetyLockActive': hemodynamicSafetyLockActive,
      'statusMessageEs': statusMessageEs,
      'warningBannerEs': warningBannerEs,
      'startedAtIso': startedAt.toUtc().toIso8601String(),
      'completedAtIso': completedAt?.toUtc().toIso8601String(),
    };
  }

  factory LbnpSessionState.fromMap(Map<dynamic, dynamic> map) {
    final phaseName = map['phase'] as String? ?? 'idle';
    final phase = LbnpPhase.values.firstWhere(
      (e) => e.name == phaseName,
      orElse: () => LbnpPhase.idle,
    );
    return LbnpSessionState(
      sessionId: map['sessionId'] as String? ?? 'lbnp_record',
      phase: phase,
      currentPressureMmHg:
          (map['currentPressureMmHg'] as num?)?.toDouble() ?? 0.0,
      targetPressureMmHg: (map['targetPressureMmHg'] as num?)?.toDouble() ??
          MedicalThresholds.lbnpTargetPressureMmHg,
      activeHoldElapsedSeconds:
          (map['activeHoldElapsedSeconds'] as num?)?.toInt() ?? 0,
      targetHoldDurationSeconds:
          (map['targetHoldDurationSeconds'] as num?)?.toInt() ?? 60,
      decompressionElapsedSeconds:
          (map['decompressionElapsedSeconds'] as num?)?.toInt() ?? 0,
      requiredDecompressionSeconds:
          (map['requiredDecompressionSeconds'] as num?)?.toInt() ??
              MedicalThresholds.lbnpMinDecompressionSeconds,
      hemodynamicSafetyLockActive:
          map['hemodynamicSafetyLockActive'] as bool? ?? false,
      statusMessageEs: map['statusMessageEs'] as String? ?? '',
      warningBannerEs: map['warningBannerEs'] as String?,
      startedAt: DateTime.tryParse(map['startedAtIso'] as String? ?? '') ??
          DateTime.now().toUtc(),
      completedAt: map['completedAtIso'] != null
          ? DateTime.tryParse(map['completedAtIso'] as String)
          : null,
    );
  }
}

/// Máquina de estados determinista para el asistente de pantalón LBNP a -20 mmHg (S7).
///
/// INVARIANTE CRÍTICO DE SEGURIDAD HEMODINÁMICA:
/// Intentar finalizar o liberar la succión directamente desde `activeHoldMinus20`
/// (o cualquier estado con succión activa) transiciona obligatoriamente a
/// `mandatoryGradualDecompression` durante `MedicalThresholds.lbnpMinDecompressionSeconds`
/// (15 s: -20 -> -15 -> -10 -> -5 -> 0 mmHg) y bloquea la liberación abrupta para
/// prevenir el pico hipertensivo craneal de rebote o presíncope.
class LbnpProtocolMachine {
  LbnpSessionState _state;

  LbnpProtocolMachine({LbnpSessionState? initialState})
      : _state = initialState ?? LbnpSessionState.initial();

  LbnpSessionState get state => _state;

  /// Inicia la rampa de succión negativa hacia -20.0 mmHg.
  LbnpSessionState startSession({
    String? sessionId,
    int targetHoldDurationSeconds = 60,
    int requiredDecompressionSeconds =
        MedicalThresholds.lbnpMinDecompressionSeconds,
    DateTime? now,
  }) {
    final timestamp = (now ?? DateTime.now()).toUtc();
    _state = LbnpSessionState(
      sessionId: sessionId ?? 'lbnp_${timestamp.millisecondsSinceEpoch}',
      phase: LbnpPhase.rampDown,
      currentPressureMmHg: -5.0,
      targetPressureMmHg: MedicalThresholds.lbnpTargetPressureMmHg,
      activeHoldElapsedSeconds: 0,
      targetHoldDurationSeconds: targetHoldDurationSeconds,
      decompressionElapsedSeconds: 0,
      requiredDecompressionSeconds: requiredDecompressionSeconds,
      hemodynamicSafetyLockActive: true,
      statusMessageEs:
          'Descendiendo presión LBNP gradualmente (-5.0 mmHg -> -20.0 mmHg)...',
      warningBannerEs: null,
      startedAt: timestamp,
    );
    return _state;
  }

  /// Avanza el reloj del protocolo en `deltaSeconds`.
  LbnpSessionState tick({int deltaSeconds = 1, DateTime? now}) {
    if (deltaSeconds <= 0) return _state;

    switch (_state.phase) {
      case LbnpPhase.idle:
      case LbnpPhase.completed:
      case LbnpPhase.aborted:
        return _state;

      case LbnpPhase.rampDown:
        final nextPressure = (_state.currentPressureMmHg - (5.0 * deltaSeconds))
            .clamp(MedicalThresholds.lbnpTargetPressureMmHg, 0.0);
        if (nextPressure <= MedicalThresholds.lbnpTargetPressureMmHg) {
          _state = _state.copyWith(
            phase: LbnpPhase.activeHoldMinus20,
            currentPressureMmHg: MedicalThresholds.lbnpTargetPressureMmHg,
            hemodynamicSafetyLockActive: true,
            statusMessageEs:
                'Succión nominal estabilizada en -20.0 mmHg (Drenaje venoso caudal activo).',
          );
        } else {
          _state = _state.copyWith(
            currentPressureMmHg: nextPressure,
            hemodynamicSafetyLockActive: true,
            statusMessageEs:
                'Rampa LBNP en curso: ${nextPressure.toStringAsFixed(1)} mmHg.',
          );
        }
        return _state;

      case LbnpPhase.activeHoldMinus20:
        final nextHold = _state.activeHoldElapsedSeconds + deltaSeconds;
        if (nextHold >= _state.targetHoldDurationSeconds) {
          _state = _state.copyWith(
            phase: LbnpPhase.mandatoryGradualDecompression,
            currentPressureMmHg: MedicalThresholds.lbnpTargetPressureMmHg,
            activeHoldElapsedSeconds: _state.targetHoldDurationSeconds,
            decompressionElapsedSeconds: 0,
            hemodynamicSafetyLockActive: true,
            statusMessageEs:
                'Tiempo objetivo alcanzado. Iniciando fase obligatoria de descompresión gradual (${_state.requiredDecompressionSeconds} s).',
          );
        } else {
          _state = _state.copyWith(
            activeHoldElapsedSeconds: nextHold,
            currentPressureMmHg: MedicalThresholds.lbnpTargetPressureMmHg,
            hemodynamicSafetyLockActive: true,
            statusMessageEs:
                'Mantenimiento activo a -20.0 mmHg ($nextHold/${_state.targetHoldDurationSeconds} s).',
          );
        }
        return _state;

      case LbnpPhase.mandatoryGradualDecompression:
        final nextDecomp = _state.decompressionElapsedSeconds + deltaSeconds;
        final totalDecomp = _state.requiredDecompressionSeconds;
        if (nextDecomp >= totalDecomp) {
          _state = _state.copyWith(
            phase: LbnpPhase.completed,
            currentPressureMmHg: 0.0,
            decompressionElapsedSeconds: totalDecomp,
            hemodynamicSafetyLockActive: false,
            clearWarningBanner: true,
            completedAt: (now ?? DateTime.now()).toUtc(),
            statusMessageEs:
                'Descompresión gradual completada (0.0 mmHg). Válvula liberada de forma segura.',
          );
        } else {
          final stepPressure = _computeGradualDecompressionPressure(
            elapsedSec: nextDecomp,
            totalSec: totalDecomp,
          );
          _state = _state.copyWith(
            decompressionElapsedSeconds: nextDecomp,
            currentPressureMmHg: stepPressure,
            hemodynamicSafetyLockActive: true,
            statusMessageEs:
                'Descompresión gradual obligatoria: ${stepPressure.toStringAsFixed(1)} mmHg ($nextDecomp/$totalDecomp s). No abrir sello.',
          );
        }
        return _state;
    }
  }

  /// Calcula el escalón de presión durante la descompresión gradual (-20 -> -15 -> -10 -> -5 -> 0 mmHg).
  static double _computeGradualDecompressionPressure({
    required int elapsedSec,
    required int totalSec,
  }) {
    if (totalSec <= 0 || elapsedSec >= totalSec) return 0.0;
    final ratio = (elapsedSec / totalSec).clamp(0.0, 1.0);
    if (ratio < 0.25) return -20.0;
    if (ratio < 0.50) return -15.0;
    if (ratio < 0.75) return -10.0;
    return -5.0;
  }

  /// Solicita detener o finalizar la sesión o liberar la presión.
  ///
  /// INVARIANTE: Si la presión es negativa (`activeHoldMinus20` o `rampDown`),
  /// NUNCA libera de golpe a 0 mmHg; fuerza `mandatoryGradualDecompression`
  /// y activa la alerta de bloqueo hemodinámico.
  LbnpSessionState requestStopOrRelease() {
    if (_state.phase == LbnpPhase.activeHoldMinus20 ||
        _state.phase == LbnpPhase.rampDown) {
      _state = _state.copyWith(
        phase: LbnpPhase.mandatoryGradualDecompression,
        decompressionElapsedSeconds: 0,
        hemodynamicSafetyLockActive: true,
        warningBannerEs:
            'BLOQUEO HEMODINÁMICO ACTIVO: Prohibida la descompresión instantánea desde ${_state.currentPressureMmHg.toStringAsFixed(1)} mmHg. '
            'Ejecutando rampa gradual obligatoria de ${_state.requiredDecompressionSeconds} s (-20 → -15 → -10 → -5 → 0 mmHg) para evitar pico hipertensivo craneal por retorno sanguíneo.',
        statusMessageEs:
            'Descompresión gradual obligatoria iniciada (0/${_state.requiredDecompressionSeconds} s).',
      );
      return _state;
    }

    if (_state.phase == LbnpPhase.mandatoryGradualDecompression) {
      final remaining =
          _state.requiredDecompressionSeconds - _state.decompressionElapsedSeconds;
      _state = _state.copyWith(
        hemodynamicSafetyLockActive: true,
        warningBannerEs:
            'BLOQUEO HEMODINÁMICO ACTIVO: Faltan $remaining s de descompresión gradual (${_state.currentPressureMmHg.toStringAsFixed(1)} mmHg). '
            'La liberación abrupta está bloqueada para proteger la presión intracraneal.',
      );
      return _state;
    }

    if (_state.phase == LbnpPhase.idle) {
      _state = _state.copyWith(
        phase: LbnpPhase.aborted,
        currentPressureMmHg: 0.0,
        hemodynamicSafetyLockActive: false,
        statusMessageEs: 'Sesión cancelada antes de presurizar.',
      );
    }
    return _state;
  }

  /// Reinicia la máquina únicamente si ya está en `completed`, `aborted` o `idle`.
  LbnpSessionState resetIfSafe() {
    if (_state.hemodynamicSafetyLockActive) {
      return requestStopOrRelease();
    }
    _state = LbnpSessionState.initial(
      targetHoldDurationSeconds: _state.targetHoldDurationSeconds,
      requiredDecompressionSeconds: _state.requiredDecompressionSeconds,
    );
    return _state;
  }
}

/// Registro consolidado de evaluación SANS (Punto cercano ΔD + Starfield TechPort 97109)
/// para almacenamiento local en Hive y cola de sincronización con Tierra.
class SansComprehensiveAssessment {
  final String id;
  final DateTime recordedAt;
  final NearPointEstimate nearPoint;
  final StarfieldAssessmentResult starfield;

  const SansComprehensiveAssessment({
    required this.id,
    required this.recordedAt,
    required this.nearPoint,
    required this.starfield,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'recordedAtIso': recordedAt.toUtc().toIso8601String(),
      'nearPoint': nearPoint.toMap(),
      'starfield': starfield.toMap(),
    };
  }

  factory SansComprehensiveAssessment.fromMap(Map<dynamic, dynamic> map) {
    final nearPointMap =
        (map['nearPoint'] as Map<dynamic, dynamic>?) ?? const {};
    final starfieldMap =
        (map['starfield'] as Map<dynamic, dynamic>?) ?? const {};
    return SansComprehensiveAssessment(
      id: map['id'] as String? ?? 'sans_unknown',
      recordedAt: DateTime.tryParse(map['recordedAtIso'] as String? ?? '') ??
          DateTime.now().toUtc(),
      nearPoint: NearPointEstimate.fromMap(nearPointMap),
      starfield: StarfieldAssessmentResult.fromMap(starfieldMap),
    );
  }
}
