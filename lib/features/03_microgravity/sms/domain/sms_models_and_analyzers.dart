import 'dart:math' as math;

import '../../../../core/constants/medical_thresholds.dart';
import '../../../../core/sensing/domain/sensing_ports.dart';

/// Categorías diagnósticas de la escala de mareo por movimiento de Graybiel et al. (1968)
/// (*Aerospace Medicine*, 39:453-455), empleada por la NASA para clasificar el
/// Síndrome de Adaptación Espacial / Mareo Espacial (SMS).
enum GraybielCategory {
  none, // 0 pts: Sin síntomas
  slightMalaise, // 1–2 pts: Malestar leve (Malaise III)
  moderateMalaiseB, // 3–4 pts: Malestar moderado B (Malaise IIB)
  moderateMalaiseA, // 5–7 pts: Malestar moderado A (Malaise IIA - Umbral NO-GO EVA)
  severeMalaise, // 8–15 pts: Malestar severo (Malaise I)
  frankSickness, // >= 16 pts: Mareo franco / Emesis inminente (Frank Sickness)
}

/// Evaluación clínica estructurada de síntomas según la escala de Graybiel (1968).
///
/// Cada síntoma aporta un puntaje ponderado según su severidad fisiológica:
/// - Náuseas: 0 (Ninguna), 1 (Leve = 4 pts), 2 (Moderada/Severa = 8 pts), 3 (Emesis/Arcadas = 16 pts)
/// - Conciencia/Malestar Epigástrico: 0 (Ninguno), 1 (Conciencia = 1 pt), 2 (Malestar = 2 pts)
/// - Sudoración Fría: 0 (Ninguna), 1 (Leve = 1 pt), 2 (Moderada = 2 pts), 3 (Severa = 4 pts), 4 (Profusa = 8 pts)
/// - Palidez / Rubor Facial: 0 (Ninguna), 1 (Rubor = 1 pt), 2 (Palidez leve = 2 pts), 3 (Palidez moderada = 4 pts), 4 (Palidez severa = 8 pts)
/// - Cefalea: 0 (Ausente), 1 (Presente = 1 pt)
/// - Somnolencia: 0 (Ninguna), 1 (Leve = 1 pt), 2 (Moderada = 2 pts), 3 (Severa = 4 pts)
/// - Vértigo / Desorientación Espacial: 0 (Ninguno), 1 (Leve = 1 pt), 2 (Moderado = 2 pts), 3 (Severo = 4 pts)
class GraybielSymptomAssessment {
  final int nauseaLevel; // 0..3
  final int epigastricLevel; // 0..2
  final int coldSweatingLevel; // 0..4
  final int pallorLevel; // 0..4
  final int headacheLevel; // 0..1
  final int drowsinessLevel; // 0..3
  final int vertigoLevel; // 0..3

  const GraybielSymptomAssessment({
    this.nauseaLevel = 0,
    this.epigastricLevel = 0,
    this.coldSweatingLevel = 0,
    this.pallorLevel = 0,
    this.headacheLevel = 0,
    this.drowsinessLevel = 0,
    this.vertigoLevel = 0,
  });

  static int _mapNauseaPoints(int level) {
    switch (level.clamp(0, 3)) {
      case 1:
        return 4;
      case 2:
        return 8;
      case 3:
        return 16;
      default:
        return 0;
    }
  }

  static int _mapEpigastricPoints(int level) {
    switch (level.clamp(0, 2)) {
      case 1:
        return 1;
      case 2:
        return 2;
      default:
        return 0;
    }
  }

  static int _mapExponentialPoints(int level, {int maxLevel = 4}) {
    switch (level.clamp(0, maxLevel)) {
      case 1:
        return 1;
      case 2:
        return 2;
      case 3:
        return 4;
      case 4:
        return 8;
      default:
        return 0;
    }
  }

  int get nauseaPoints => _mapNauseaPoints(nauseaLevel);
  int get epigastricPoints => _mapEpigastricPoints(epigastricLevel);
  int get coldSweatingPoints =>
      _mapExponentialPoints(coldSweatingLevel, maxLevel: 4);
  int get pallorPoints => _mapExponentialPoints(pallorLevel, maxLevel: 4);
  int get headachePoints => headacheLevel.clamp(0, 1);
  int get drowsinessPoints =>
      _mapExponentialPoints(drowsinessLevel, maxLevel: 3);
  int get vertigoPoints => _mapExponentialPoints(vertigoLevel, maxLevel: 3);

  /// Puntaje compuesto total en la escala de Graybiel (1968).
  int get totalScore =>
      nauseaPoints +
      epigastricPoints +
      coldSweatingPoints +
      pallorPoints +
      headachePoints +
      drowsinessPoints +
      vertigoPoints;

  /// Clasificación diagnóstica según el puntaje total.
  GraybielCategory get category => classifyScore(totalScore);

  /// Determina la categoría clínica de Graybiel a partir de un puntaje entero.
  static GraybielCategory classifyScore(int score) {
    if (score <= 0) return GraybielCategory.none;
    if (score <= 2) return GraybielCategory.slightMalaise;
    if (score <= 4) return GraybielCategory.moderateMalaiseB;
    if (score < MedicalThresholds.graybielSevereMalaiseThreshold) {
      return GraybielCategory.moderateMalaiseA; // 5..7
    }
    if (score < MedicalThresholds.graybielFrankSicknessThreshold) {
      return GraybielCategory.severeMalaise; // 8..15
    }
    return GraybielCategory.frankSickness; // >= 16
  }

  /// Etiqueta clínica en español neutral para interfaz médica.
  String get categoryLabel {
    switch (category) {
      case GraybielCategory.none:
        return 'Nominal (0 pts - Sin síntomas)';
      case GraybielCategory.slightMalaise:
        return 'Malestar Leve / Malaise III (1–2 pts)';
      case GraybielCategory.moderateMalaiseB:
        return 'Malestar Moderado B / Malaise IIB (3–4 pts)';
      case GraybielCategory.moderateMalaiseA:
        return 'Malestar Moderado A / Malaise IIA (5–7 pts)';
      case GraybielCategory.severeMalaise:
        return 'Malestar Severo / Malaise I (8–15 pts)';
      case GraybielCategory.frankSickness:
        return 'Mareo Franco / Frank Sickness (≥16 pts)';
    }
  }

  bool get triggersEvaRestriction =>
      totalScore >= MedicalThresholds.graybielModerateMalaiseThreshold;

  GraybielSymptomAssessment copyWith({
    int? nauseaLevel,
    int? epigastricLevel,
    int? coldSweatingLevel,
    int? pallorLevel,
    int? headacheLevel,
    int? drowsinessLevel,
    int? vertigoLevel,
  }) {
    return GraybielSymptomAssessment(
      nauseaLevel: nauseaLevel ?? this.nauseaLevel,
      epigastricLevel: epigastricLevel ?? this.epigastricLevel,
      coldSweatingLevel: coldSweatingLevel ?? this.coldSweatingLevel,
      pallorLevel: pallorLevel ?? this.pallorLevel,
      headacheLevel: headacheLevel ?? this.headacheLevel,
      drowsinessLevel: drowsinessLevel ?? this.drowsinessLevel,
      vertigoLevel: vertigoLevel ?? this.vertigoLevel,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'nauseaLevel': nauseaLevel,
      'epigastricLevel': epigastricLevel,
      'coldSweatingLevel': coldSweatingLevel,
      'pallorLevel': pallorLevel,
      'headacheLevel': headacheLevel,
      'drowsinessLevel': drowsinessLevel,
      'vertigoLevel': vertigoLevel,
      'totalScore': totalScore,
      'category': category.name,
    };
  }

  factory GraybielSymptomAssessment.fromMap(Map<dynamic, dynamic> map) {
    return GraybielSymptomAssessment(
      nauseaLevel: (map['nauseaLevel'] as num?)?.toInt() ?? 0,
      epigastricLevel: (map['epigastricLevel'] as num?)?.toInt() ?? 0,
      coldSweatingLevel: (map['coldSweatingLevel'] as num?)?.toInt() ?? 0,
      pallorLevel: (map['pallorLevel'] as num?)?.toInt() ?? 0,
      headacheLevel: (map['headacheLevel'] as num?)?.toInt() ?? 0,
      drowsinessLevel: (map['drowsinessLevel'] as num?)?.toInt() ?? 0,
      vertigoLevel: (map['vertigoLevel'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Estado del biomarcador experimental de cromaticidad verde/roja facial.
enum ChromaticityStatus {
  nominal,
  elevated,
  critical,
}

/// Resultado del análisis de cromaticidad facial relativa Δ(G/R) durante 15 s
/// normalizado contra la tarjeta blanca de referencia en pantalla.
class FacialGreennessResult {
  final double baselineGreenRedRatio;
  final double initialGreenRedRatio;
  final double finalGreenRedRatio;
  final double deltaGreenRedRatio;
  final double meanWhiteReferenceLuminance;
  final int validSampleCount;
  final ChromaticityStatus status;
  final String scientificNote;

  const FacialGreennessResult({
    required this.baselineGreenRedRatio,
    required this.initialGreenRedRatio,
    required this.finalGreenRedRatio,
    required this.deltaGreenRedRatio,
    required this.meanWhiteReferenceLuminance,
    required this.validSampleCount,
    required this.status,
    required this.scientificNote,
  });

  String get statusLabel {
    switch (status) {
      case ChromaticityStatus.nominal:
        return 'Perfusion Cutánea Nominal';
      case ChromaticityStatus.elevated:
        return 'Vasoconstricción / Palidez Verdosa Leve-Moderada';
      case ChromaticityStatus.critical:
        return 'Vasoconstricción Autonómica Marcada (Alerta SMS)';
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'baselineGreenRedRatio': baselineGreenRedRatio,
      'initialGreenRedRatio': initialGreenRedRatio,
      'finalGreenRedRatio': finalGreenRedRatio,
      'deltaGreenRedRatio': deltaGreenRedRatio,
      'meanWhiteReferenceLuminance': meanWhiteReferenceLuminance,
      'validSampleCount': validSampleCount,
      'status': status.name,
      'scientificNote': scientificNote,
    };
  }

  factory FacialGreennessResult.fromMap(Map<dynamic, dynamic> map) {
    final statusStr = map['status'] as String? ?? 'nominal';
    final status = ChromaticityStatus.values.firstWhere(
      (e) => e.name == statusStr,
      orElse: () => ChromaticityStatus.nominal,
    );
    return FacialGreennessResult(
      baselineGreenRedRatio:
          (map['baselineGreenRedRatio'] as num?)?.toDouble() ?? 0.88,
      initialGreenRedRatio:
          (map['initialGreenRedRatio'] as num?)?.toDouble() ?? 0.88,
      finalGreenRedRatio:
          (map['finalGreenRedRatio'] as num?)?.toDouble() ?? 0.88,
      deltaGreenRedRatio:
          (map['deltaGreenRedRatio'] as num?)?.toDouble() ?? 0.0,
      meanWhiteReferenceLuminance:
          (map['meanWhiteReferenceLuminance'] as num?)?.toDouble() ?? 1.0,
      validSampleCount: (map['validSampleCount'] as num?)?.toInt() ?? 0,
      status: status,
      scientificNote: map['scientificNote'] as String? ??
          FacialGreennessAnalyzer.defaultScientificNote,
    );
  }
}

/// Analizador de cromaticidad verde facial relativa Δ(G/R) en ventana de 15 segundos.
///
/// Fundamentación biomédica:
/// - Bonnard et al. (2026, *Experimental Brain Research*) demostraron en vuelo parabólico y
///   realidad virtual que el incremento relativo de cromaticidad verde frente a roja en
///   mejillas/frente correlaciona con vasoconstricción simpática periférica previa a la náusea.
/// - Para mitigar variaciones de iluminación en cabina, cada muestra normaliza el cociente
///   `(G / R)` dividiendo por la luminancia de la tarjeta blanca de referencia en pantalla.
class FacialGreennessAnalyzer {
  static const String defaultScientificNote =
      'Biomarcador relativo experimental (Bonnard et al. 2026, estudio en vuelo parabólico/VR). '
      'Mide el desplazamiento relativo Δ(G/R) durante 15 s normalizado contra la tarjeta blanca '
      'en pantalla como iluminación controlada.';

  static FacialGreennessResult analyze({
    required List<FaceSample> samples,
    required double baselineGreenRedRatio,
  }) {
    final detected = samples.where((s) => s.faceDetected).toList();
    if (detected.isEmpty) {
      return FacialGreennessResult(
        baselineGreenRedRatio: baselineGreenRedRatio,
        initialGreenRedRatio: baselineGreenRedRatio,
        finalGreenRedRatio: baselineGreenRedRatio,
        deltaGreenRedRatio: 0.0,
        meanWhiteReferenceLuminance: 1.0,
        validSampleCount: 0,
        status: ChromaticityStatus.nominal,
        scientificNote: defaultScientificNote,
      );
    }

    final normalizedRatios =
        detected.map((s) => s.normalizedGreenRedRatio).toList();
    final meanLum = detected
            .map((s) => s.whiteReferenceLuminance)
            .reduce((a, b) => a + b) /
        detected.length;

    // Ventana inicial y ventana final (último tercio de la serie de 15 s)
    final windowSize = math.max(1, detected.length ~/ 3);
    final initialSlice = normalizedRatios.take(windowSize).toList();
    final finalSlice =
        normalizedRatios.skip(detected.length - windowSize).toList();

    final initialMean =
        initialSlice.reduce((a, b) => a + b) / initialSlice.length;
    final finalMean = finalSlice.reduce((a, b) => a + b) / finalSlice.length;

    // El cambio relativo se evalúa respecto al valor basal calibrado (o ventana inicial si es mayor el cambio)
    final deltaVsBaseline = finalMean - baselineGreenRedRatio;
    final deltaVsInitial = finalMean - initialMean;
    final delta = math.max(deltaVsBaseline, deltaVsInitial);

    final ChromaticityStatus status;
    if (delta >= MedicalThresholds.facialGreennessCriticalDeltaRatio) {
      status = ChromaticityStatus.critical;
    } else if (delta >= MedicalThresholds.facialGreennessWarningDeltaRatio) {
      status = ChromaticityStatus.elevated;
    } else {
      status = ChromaticityStatus.nominal;
    }

    return FacialGreennessResult(
      baselineGreenRedRatio: baselineGreenRedRatio,
      initialGreenRedRatio: initialMean,
      finalGreenRedRatio: finalMean,
      deltaGreenRedRatio: delta,
      meanWhiteReferenceLuminance: meanLum,
      validSampleCount: detected.length,
      status: status,
      scientificNote: defaultScientificNote,
    );
  }
}

/// Resultado de la prueba de Estabilidad de la Mirada a 1 Hz y Agudeza Visual Dinámica (DVA).
class GazeStabilityResult {
  final double estimatedOscillationHz;
  final double frequencyConsistencyScore;
  final double fixationRetentionRatio;
  final double optotypeAccuracy;
  final double compositeScore;
  final double meanGazeOffsetDeg;
  final bool isStable;

  const GazeStabilityResult({
    required this.estimatedOscillationHz,
    required this.frequencyConsistencyScore,
    required this.fixationRetentionRatio,
    required this.optotypeAccuracy,
    required this.compositeScore,
    required this.meanGazeOffsetDeg,
    required this.isStable,
  });

  Map<String, dynamic> toMap() {
    return {
      'estimatedOscillationHz': estimatedOscillationHz,
      'frequencyConsistencyScore': frequencyConsistencyScore,
      'fixationRetentionRatio': fixationRetentionRatio,
      'optotypeAccuracy': optotypeAccuracy,
      'compositeScore': compositeScore,
      'meanGazeOffsetDeg': meanGazeOffsetDeg,
      'isStable': isStable,
    };
  }

  factory GazeStabilityResult.fromMap(Map<dynamic, dynamic> map) {
    return GazeStabilityResult(
      estimatedOscillationHz:
          (map['estimatedOscillationHz'] as num?)?.toDouble() ?? 1.0,
      frequencyConsistencyScore:
          (map['frequencyConsistencyScore'] as num?)?.toDouble() ?? 1.0,
      fixationRetentionRatio:
          (map['fixationRetentionRatio'] as num?)?.toDouble() ?? 1.0,
      optotypeAccuracy: (map['optotypeAccuracy'] as num?)?.toDouble() ?? 1.0,
      compositeScore: (map['compositeScore'] as num?)?.toDouble() ?? 1.0,
      meanGazeOffsetDeg: (map['meanGazeOffsetDeg'] as num?)?.toDouble() ?? 0.5,
      isStable: map['isStable'] as bool? ?? true,
    );
  }
}

/// Analizador de Estabilidad Ocular y Agudeza Visual Dinámica (DVA) a 1.0 Hz.
///
/// Nota técnica: Con una cámara frontal convencional (20–30 fps) no es posible medir
/// la ganancia de fase del reflejo vestíbulo-ocular (VOR) clínico de alta velocidad (>250 Hz),
/// pero sí la retención de fijación central (`gazeOffsetDeg <= 2.5°`) y el reconocimiento de
/// optotipos dinámicos mientras la cabeza oscila al ritmo de un metrónomo de 1.0 Hz.
class GazeStabilityAnalyzer {
  static const double maxAcceptableGazeOffsetDeg = 2.5;

  static GazeStabilityResult analyze({
    required List<FaceSample> samples,
    double optotypeAccuracy = 1.0,
  }) {
    final detected = samples.where((s) => s.faceDetected).toList();
    final clampedOptotype = optotypeAccuracy.clamp(0.0, 1.0);

    if (detected.isEmpty) {
      return GazeStabilityResult(
        estimatedOscillationHz: 0.0,
        frequencyConsistencyScore: 0.0,
        fixationRetentionRatio: 0.0,
        optotypeAccuracy: clampedOptotype,
        compositeScore: 0.0,
        meanGazeOffsetDeg: 0.0,
        isStable: false,
      );
    }

    // 1. Retención de fijación central (fracción de muestras con gazeOffsetDeg <= 2.5°)
    final retainedCount = detected
        .where((s) => s.gazeOffsetDeg <= maxAcceptableGazeOffsetDeg)
        .length;
    final fixationRetentionRatio = retainedCount / detected.length;

    final meanGazeOffset =
        detected.map((s) => s.gazeOffsetDeg).reduce((a, b) => a + b) /
            detected.length;

    // 2. Estimación de frecuencia de oscilación cefálica (cruces por cero de headYawDeg)
    double estimatedHz = MedicalThresholds.targetHeadOscillationHz;
    if (detected.length >= 4) {
      final durationSec = detected.last.timestamp
              .difference(detected.first.timestamp)
              .inMilliseconds /
          1000.0;
      if (durationSec >= 0.5) {
        int zeroCrossings = 0;
        for (int i = 1; i < detected.length; i++) {
          final prev = detected[i - 1].headYawDeg;
          final curr = detected[i].headYawDeg;
          if ((prev < 0 && curr >= 0) || (prev >= 0 && curr < 0)) {
            zeroCrossings++;
          }
        }
        if (zeroCrossings > 0) {
          // Cada ciclo completo tiene 2 cruces por cero
          estimatedHz = (zeroCrossings / 2.0) / durationSec;
        } else {
          estimatedHz = 0.0;
        }
      }
    }

    final freqError =
        (estimatedHz - MedicalThresholds.targetHeadOscillationHz).abs();
    final frequencyConsistencyScore =
        (1.0 - (freqError / 0.8)).clamp(0.0, 1.0);

    // 3. Puntaje compuesto [0..1]: 60% retención de fijación, 25% optotipo DVA, 15% ritmo 1 Hz
    final compositeScore = (0.60 * fixationRetentionRatio +
            0.25 * clampedOptotype +
            0.15 * frequencyConsistencyScore)
        .clamp(0.0, 1.0);

    final isStable =
        compositeScore >= MedicalThresholds.minAcceptableGazeStabilityScore &&
            fixationRetentionRatio >=
                MedicalThresholds.minAcceptableGazeStabilityScore;

    return GazeStabilityResult(
      estimatedOscillationHz: estimatedHz,
      frequencyConsistencyScore: frequencyConsistencyScore,
      fixationRetentionRatio: fixationRetentionRatio,
      optotypeAccuracy: clampedOptotype,
      compositeScore: compositeScore,
      meanGazeOffsetDeg: meanGazeOffset,
      isStable: isStable,
    );
  }
}

/// Resultado del entrenamiento y evaluación sensoriomotora "Zero-G Horizon" (45 s)
/// en 3 ejes (Roll, Pitch, Yaw) bajo conflicto visual-vestibular controlado.
class ZeroGHorizonResult {
  final int durationSeconds;
  final double meanRollErrorDeg;
  final double meanPitchErrorDeg;
  final double meanYawErrorDeg;
  final double alignmentAccuracyPercent;
  final double taskImpairmentIndexPercent;
  final bool passed;

  const ZeroGHorizonResult({
    required this.durationSeconds,
    required this.meanRollErrorDeg,
    required this.meanPitchErrorDeg,
    required this.meanYawErrorDeg,
    required this.alignmentAccuracyPercent,
    required this.taskImpairmentIndexPercent,
    required this.passed,
  });

  /// Calcula el desempeño del acoplamiento en 3 ejes a partir de los errores angulares medios.
  /// Inspirado en NASA NTRS 20150018603 / Mulavara et al. (2010), donde la discordancia
  /// sensoriomotora incrementa ~48% el tiempo de recorrido de obstáculos post-aterrizaje.
  factory ZeroGHorizonResult.fromAxisErrors({
    int durationSeconds = MedicalThresholds.zeroGHorizonDurationSeconds,
    required double meanRollErrorDeg,
    required double meanPitchErrorDeg,
    required double meanYawErrorDeg,
  }) {
    final rmsError = math.sqrt(
      (meanRollErrorDeg * meanRollErrorDeg +
              meanPitchErrorDeg * meanPitchErrorDeg +
              meanYawErrorDeg * meanYawErrorDeg) /
          3.0,
    );
    // Error RMS de 0° = 100% precisión; error RMS >= 30° = 0% precisión
    final accuracy = ((1.0 - (rmsError / 30.0)) * 100.0).clamp(0.0, 100.0);
    // Índice de deterioro funcional (0% óptimo; ~48%+ en desorientación marcada)
    final impairment = ((100.0 - accuracy) * 0.95).clamp(0.0, 100.0);

    return ZeroGHorizonResult(
      durationSeconds: durationSeconds,
      meanRollErrorDeg: meanRollErrorDeg,
      meanPitchErrorDeg: meanPitchErrorDeg,
      meanYawErrorDeg: meanYawErrorDeg,
      alignmentAccuracyPercent: accuracy,
      taskImpairmentIndexPercent: impairment,
      passed: accuracy >= MedicalThresholds.minZeroGHorizonPassScore,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'durationSeconds': durationSeconds,
      'meanRollErrorDeg': meanRollErrorDeg,
      'meanPitchErrorDeg': meanPitchErrorDeg,
      'meanYawErrorDeg': meanYawErrorDeg,
      'alignmentAccuracyPercent': alignmentAccuracyPercent,
      'taskImpairmentIndexPercent': taskImpairmentIndexPercent,
      'passed': passed,
    };
  }

  factory ZeroGHorizonResult.fromMap(Map<dynamic, dynamic> map) {
    return ZeroGHorizonResult(
      durationSeconds: (map['durationSeconds'] as num?)?.toInt() ??
          MedicalThresholds.zeroGHorizonDurationSeconds,
      meanRollErrorDeg: (map['meanRollErrorDeg'] as num?)?.toDouble() ?? 0.0,
      meanPitchErrorDeg: (map['meanPitchErrorDeg'] as num?)?.toDouble() ?? 0.0,
      meanYawErrorDeg: (map['meanYawErrorDeg'] as num?)?.toDouble() ?? 0.0,
      alignmentAccuracyPercent:
          (map['alignmentAccuracyPercent'] as num?)?.toDouble() ?? 100.0,
      taskImpairmentIndexPercent:
          (map['taskImpairmentIndexPercent'] as num?)?.toDouble() ?? 0.0,
      passed: map['passed'] as bool? ?? true,
    );
  }
}

/// Dictamen de seguridad operativa para Actividad Extravehicular (EVA)
/// emitido por el motor de decisión clínica SMS.
class EvaSafetyAdvisory {
  final bool evaNoGoRecommended;
  final String severityCode; // 'GREEN', 'YELLOW', 'RED'
  final String headline;
  final String clinicalRationale;
  final List<String> immediateActions;

  const EvaSafetyAdvisory({
    required this.evaNoGoRecommended,
    required this.severityCode,
    required this.headline,
    required this.clinicalRationale,
    required this.immediateActions,
  });

  Map<String, dynamic> toMap() {
    return {
      'evaNoGoRecommended': evaNoGoRecommended,
      'severityCode': severityCode,
      'headline': headline,
      'clinicalRationale': clinicalRationale,
      'immediateActions': immediateActions,
    };
  }

  factory EvaSafetyAdvisory.fromMap(Map<dynamic, dynamic> map) {
    return EvaSafetyAdvisory(
      evaNoGoRecommended: map['evaNoGoRecommended'] as bool? ?? false,
      severityCode: map['severityCode'] as String? ?? 'GREEN',
      headline: map['headline'] as String? ?? '',
      clinicalRationale: map['clinicalRationale'] as String? ?? '',
      immediateActions: (map['immediateActions'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
    );
  }
}

/// Registro consolidado de evaluación de Mareo Espacial (SMS) y función sensoriomotora.
class SmsComprehensiveAssessment {
  final String id;
  final DateTime timestamp;
  final GraybielSymptomAssessment graybiel;
  final FacialGreennessResult facialGreenness;
  final GazeStabilityResult gazeStability;
  final ZeroGHorizonResult zeroGHorizon;
  final EvaSafetyAdvisory evaAdvisory;

  const SmsComprehensiveAssessment({
    required this.id,
    required this.timestamp,
    required this.graybiel,
    required this.facialGreenness,
    required this.gazeStability,
    required this.zeroGHorizon,
    required this.evaAdvisory,
  });

  bool get evaNoGoRecommended => evaAdvisory.evaNoGoRecommended;

  /// Evalúa integralmente los 4 pilares (Escala de Graybiel, Δ(G/R) facial,
  /// Estabilidad Ocular 1 Hz y Zero-G Horizon 3D) y genera el dictamen clínico EVA.
  factory SmsComprehensiveAssessment.evaluate({
    required String id,
    DateTime? timestamp,
    required GraybielSymptomAssessment graybiel,
    required FacialGreennessResult facialGreenness,
    required GazeStabilityResult gazeStability,
    required ZeroGHorizonResult zeroGHorizon,
  }) {
    final now = timestamp ?? DateTime.now();
    final bool graybielNoGo =
        graybiel.totalScore >= MedicalThresholds.graybielModerateMalaiseThreshold;
    final bool horizonFailed = zeroGHorizon.alignmentAccuracyPercent <
        MedicalThresholds.minZeroGHorizonPassScore;
    final bool evaNoGo = graybielNoGo || horizonFailed;

    final String severityCode;
    final String headline;
    final String rationale;
    final List<String> actions;

    if (evaNoGo) {
      severityCode = 'RED';
      headline =
          'RECOMENDACIÓN NO-GO EVA — Riesgo de emesis en casco presurizado y desorientación espacial. Notificar al Cirujano de Vuelo';
      final reasons = <String>[];
      if (graybielNoGo) {
        reasons.add(
            'Puntaje de Graybiel ${graybiel.totalScore} pts (${graybiel.categoryLabel} ≥ ${MedicalThresholds.graybielModerateMalaiseThreshold} pts)');
      }
      if (horizonFailed) {
        reasons.add(
            'Precisión en Zero-G Horizon ${zeroGHorizon.alignmentAccuracyPercent.toStringAsFixed(1)}% (< ${MedicalThresholds.minZeroGHorizonPassScore.toStringAsFixed(0)}% requerido)');
      }
      if (facialGreenness.status != ChromaticityStatus.nominal) {
        reasons.add(
            'Desplazamiento cromático facial Δ(G/R) +${facialGreenness.deltaGreenRedRatio.toStringAsFixed(3)}');
      }
      rationale =
          'RECOMENDACIÓN NO-GO EVA — Riesgo de emesis en casco presurizado y desorientación espacial. Notificar al Cirujano de Vuelo. '
          'Criterios activados: ${reasons.join('; ')}. La emesis dentro de un traje EMU presurizado representa riesgo vital de aspiración y obstrucción de soporte vital.';
      actions = const [
        'Suspender programación de caminata espacial (EVA) durante al menos 24–48 horas.',
        'Notificar de inmediato al Cirujano de Vuelo (Flight Surgeon) vía telemetría diferida.',
        'Restringir movimientos cefálicos rápidos en cabeceo y alabeo; mantener anclaje táctil en cabina.',
        'Valorar protocolo antiemético del botiquín ISS (Prometazina 25 mg IM/VO con monitoreo de sedación).',
      ];
    } else if (graybiel.totalScore >= 3 ||
        facialGreenness.status != ChromaticityStatus.nominal ||
        !gazeStability.isStable) {
      severityCode = 'YELLOW';
      headline =
          'PRECAUCIÓN SENSORIOMOTORA — Adaptación vestibular en curso (GO condicional en intravehicular)';
      rationale =
          'Puntaje de Graybiel ${graybiel.totalScore} pts (${graybiel.categoryLabel}), '
          'Δ(G/R) facial +${facialGreenness.deltaGreenRedRatio.toStringAsFixed(3)}, '
          'estabilidad ocular ${(gazeStability.compositeScore * 100).toStringAsFixed(0)}%. '
          'Apto para tareas intravehiculares con monitoreo cada 4 horas.';
      actions = const [
        'Continuar sesiones breves de habituación progresiva en "Zero-G Horizon" (45 s).',
        'Evitar rotaciones cefálicas bruscas fuera del eje visual de trabajo.',
        'Repetir escaneo Δ(G/R) y prueba de estabilidad de mirada a 1 Hz en 4 horas.',
      ];
    } else {
      severityCode = 'GREEN';
      headline = 'APTO PARA EVA (GO) — Función Vestibular y Sensoriomotora Nominal';
      rationale =
          'Escala de Graybiel en ${graybiel.totalScore} pts, cromaticidad Δ(G/R) nominal '
          '(+${facialGreenness.deltaGreenRedRatio.toStringAsFixed(3)}), fijación ocular a 1 Hz '
          'en ${(gazeStability.fixationRetentionRatio * 100).toStringAsFixed(0)}% y acoplamiento '
          '3D Zero-G Horizon en ${zeroGHorizon.alignmentAccuracyPercent.toStringAsFixed(1)}%.';
      actions = const [
        'Autorizado para actividades extravehiculares (EVA) y maniobras robóticas de precisión.',
        'Mantener rutina estándar de habituación pre-aterrizaje.',
      ];
    }

    return SmsComprehensiveAssessment(
      id: id,
      timestamp: now,
      graybiel: graybiel,
      facialGreenness: facialGreenness,
      gazeStability: gazeStability,
      zeroGHorizon: zeroGHorizon,
      evaAdvisory: EvaSafetyAdvisory(
        evaNoGoRecommended: evaNoGo,
        severityCode: severityCode,
        headline: headline,
        clinicalRationale: rationale,
        immediateActions: actions,
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'timestampIso': timestamp.toUtc().toIso8601String(),
      'graybiel': graybiel.toMap(),
      'facialGreenness': facialGreenness.toMap(),
      'gazeStability': gazeStability.toMap(),
      'zeroGHorizon': zeroGHorizon.toMap(),
      'evaAdvisory': evaAdvisory.toMap(),
    };
  }

  factory SmsComprehensiveAssessment.fromMap(Map<dynamic, dynamic> map) {
    final tsStr = map['timestampIso'] as String?;
    final parsedTs =
        tsStr != null ? DateTime.tryParse(tsStr)?.toLocal() : null;
    return SmsComprehensiveAssessment(
      id: map['id'] as String? ?? 'sms_unknown',
      timestamp: parsedTs ?? DateTime.now(),
      graybiel: GraybielSymptomAssessment.fromMap(
        (map['graybiel'] as Map<dynamic, dynamic>?) ?? const {},
      ),
      facialGreenness: FacialGreennessResult.fromMap(
        (map['facialGreenness'] as Map<dynamic, dynamic>?) ?? const {},
      ),
      gazeStability: GazeStabilityResult.fromMap(
        (map['gazeStability'] as Map<dynamic, dynamic>?) ?? const {},
      ),
      zeroGHorizon: ZeroGHorizonResult.fromMap(
        (map['zeroGHorizon'] as Map<dynamic, dynamic>?) ?? const {},
      ),
      evaAdvisory: EvaSafetyAdvisory.fromMap(
        (map['evaAdvisory'] as Map<dynamic, dynamic>?) ?? const {},
      ),
    );
  }
}
