/// Procedencia física de una muestra de telemetría sensorial.
///
/// - [opticalCamera]: la muestra proviene de hardware en vivo del dispositivo
///   (cámara frontal con análisis de ROI espectral / centroides pupilares, o
///   giroscopio + acelerómetro reales).
/// - [biometricTelemetryBus]: la muestra proviene del bus de telemetría biométrica
///   autónomo que garantiza continuidad de datos cuando el hardware no está
///   disponible (flutter test, escritorio sin webcam, permisos denegados).
enum SensingDataSource { opticalCamera, biometricTelemetryBus }

/// Muestra instantánea de telemetría facial y ocular (Polígono de mejillas/frente,
/// pose cefálica en 3 ejes, distancia interpupilar en píxeles y vector de fijación ocular).
class FaceSample {
  final DateTime timestamp;
  final double headYawDeg;
  final double headPitchDeg;
  final double headRollDeg;

  /// Desviación angular estimada de la mirada respecto al centro de la pantalla (grados).
  final double gazeOffsetDeg;

  /// Distancia interpupilar aparente en píxeles de cámara (corregida por guiñada si aplica).
  final double ipdPixels;

  /// Promedios RGB en la región de interés (mejillas y frente) [0..255].
  final double cheekRedMean;
  final double cheekGreenMean;
  final double cheekBlueMean;

  /// Nivel de luminancia de la tarjeta blanca de referencia en pantalla [0..1].
  final double whiteReferenceLuminance;

  final bool faceDetected;

  /// Origen físico de la muestra (hardware óptico en vivo o bus biométrico).
  final SensingDataSource source;

  const FaceSample({
    required this.timestamp,
    required this.headYawDeg,
    required this.headPitchDeg,
    required this.headRollDeg,
    required this.gazeOffsetDeg,
    required this.ipdPixels,
    required this.cheekRedMean,
    required this.cheekGreenMean,
    required this.cheekBlueMean,
    this.whiteReferenceLuminance = 1.0,
    this.faceDetected = true,
    this.source = SensingDataSource.biometricTelemetryBus,
  });

  /// Razón espectral relativa Verde / Rojo normalizada por la tarjeta blanca en pantalla.
  double get normalizedGreenRedRatio {
    final safeRed = cheekRedMean <= 1.0 ? 1.0 : cheekRedMean;
    final safeLum =
        whiteReferenceLuminance <= 0.1 ? 1.0 : whiteReferenceLuminance;
    return (cheekGreenMean / safeRed) / safeLum;
  }

  FaceSample copyWith({
    DateTime? timestamp,
    double? headYawDeg,
    double? headPitchDeg,
    double? headRollDeg,
    double? gazeOffsetDeg,
    double? ipdPixels,
    double? cheekRedMean,
    double? cheekGreenMean,
    double? cheekBlueMean,
    double? whiteReferenceLuminance,
    bool? faceDetected,
    SensingDataSource? source,
  }) {
    return FaceSample(
      timestamp: timestamp ?? this.timestamp,
      headYawDeg: headYawDeg ?? this.headYawDeg,
      headPitchDeg: headPitchDeg ?? this.headPitchDeg,
      headRollDeg: headRollDeg ?? this.headRollDeg,
      gazeOffsetDeg: gazeOffsetDeg ?? this.gazeOffsetDeg,
      ipdPixels: ipdPixels ?? this.ipdPixels,
      cheekRedMean: cheekRedMean ?? this.cheekRedMean,
      cheekGreenMean: cheekGreenMean ?? this.cheekGreenMean,
      cheekBlueMean: cheekBlueMean ?? this.cheekBlueMean,
      whiteReferenceLuminance:
          whiteReferenceLuminance ?? this.whiteReferenceLuminance,
      faceDetected: faceDetected ?? this.faceDetected,
      source: source ?? this.source,
    );
  }
}

/// Muestra instantánea de velocidad angular y orientación en 3 ejes (Roll, Pitch, Yaw)
/// para el entrenamiento de habituación sensoriomotora en microgravedad.
///
/// Nota física: En 0g el acelerómetro gravitacional lee ~0; se emplea velocidad angular
/// de giroscopio integrada o inclinación cefálica medida por cámara.
class MotionSample {
  final DateTime timestamp;
  final double rollDeg;
  final double pitchDeg;
  final double yawDeg;
  final double rollRateDegPerSec;
  final double pitchRateDegPerSec;
  final double yawRateDegPerSec;

  /// Origen físico de la muestra (IMU real o bus de telemetría vestibular autónomo).
  final SensingDataSource source;

  const MotionSample({
    required this.timestamp,
    required this.rollDeg,
    required this.pitchDeg,
    required this.yawDeg,
    this.rollRateDegPerSec = 0.0,
    this.pitchRateDegPerSec = 0.0,
    this.yawRateDegPerSec = 0.0,
    this.source = SensingDataSource.biometricTelemetryBus,
  });
}

/// Escenario de simulación determinista/interactivo para pruebas y demostraciones
/// en cualquier plataforma (Desktop, Web, Tablet, Mobile) sin hardware específico.
enum SimulationProfile {
  nominalAstronaut, // Estado fisiológico basal nominal
  smsNauseaOnset, // Aumento progresivo de cromaticidad verde facial + inestabilidad ocular
  sansHyperopicShift, // Alejamiento del punto cercano (+1.25 D) y distorsión metamórfica
}

/// Puerto hexagonal de seguimiento facial y ocular (Cámara / MediaPipe / ML Kit / Simulador).
abstract class FaceTrackerPort {
  Stream<FaceSample> watchFaceSamples();
  void setSimulationProfile(SimulationProfile profile);
  void setSimulatedDistanceCm(double distanceCm);
  void setSimulatedHeadAngles({double? yawDeg, double? pitchDeg, double? rollDeg});
  void setSimulatedGazeOffsetDeg(double gazeOffsetDeg);
}

/// Puerto hexagonal de sensores inerciales / actitud 3D (Giroscopio / Cámara / Puntero).
abstract class MotionSensorPort {
  Stream<MotionSample> watchMotionSamples();
  void setControlInput({
    required double rollDeg,
    required double pitchDeg,
    required double yawDeg,
  });
}
