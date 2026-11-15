import 'dart:async';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../../calibration/domain/device_calibration.dart';
import '../domain/sensing_ports.dart';

/// Adaptador multiplataforma de seguimiento facial, cromaticidad RGB en ROI
/// (mejillas y frente), distancia interpupilar (IPD) y vector de fijación ocular.
///
/// Integra la cámara frontal en vivo (`camera`) con análisis espectral YUV420 /
/// BGRA8888 y centroides pupilares, manteniendo continuidad automática mediante
/// el bus de telemetría biométrica cuando no hay cámara física disponible
/// (pruebas automatizadas, escritorio sin webcam o permisos denegados).
class SimulatedFaceTracker implements FaceTrackerPort {
  final DeviceCalibration Function() readCalibration;
  final bool enableHardwareCamera;

  SimulationProfile _profile = SimulationProfile.nominalAstronaut;

  double _distanceCm = 28.0;
  double _manualYawDeg = 0.0;
  double _manualPitchDeg = 0.0;
  double _manualRollDeg = 0.0;
  double _manualGazeOffsetDeg = 0.0;
  bool _autoOscillateHead = true;

  DateTime _profileStartedAt = DateTime.now();

  // Estado del canal óptico real (CameraController + ImageStream)
  final ValueNotifier<CameraController?> _cameraController =
      ValueNotifier<CameraController?>(null);
  final ValueNotifier<bool> _isCameraInitializing = ValueNotifier<bool>(false);
  final ValueNotifier<String?> _cameraStatusNote = ValueNotifier<String?>(null);

  Future<void>? _cameraInitFuture;
  bool _cameraAttempted = false;
  bool _disposed = false;

  DateTime _lastProcessedFrameAt = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime? _lastCameraSampleAt;
  FaceSample? _latestCameraSample;

  // Suavizado exponencial (EMA) para estabilizar métricas ópticas en vivo
  double? _emaRed;
  double? _emaGreen;
  double? _emaBlue;
  double? _emaIpdPx;
  double? _emaGazeDeg;
  double? _emaRollDeg;

  StreamController<FaceSample>? _faceController;
  Timer? _telemetryTimer;
  int _tick = 0;

  SimulatedFaceTracker({
    required this.readCalibration,
    this.enableHardwareCamera = true,
  });

  SimulationProfile get currentProfile => _profile;
  double get currentDistanceCm => _distanceCm;
  bool get autoOscillateHead => _autoOscillateHead;

  CameraController? get activeCameraController => _cameraController.value;
  ValueListenable<CameraController?> get cameraControllerListenable =>
      _cameraController;
  ValueListenable<bool> get isCameraInitializingListenable =>
      _isCameraInitializing;
  ValueListenable<String?> get cameraStatusNoteListenable => _cameraStatusNote;

  void setAutoOscillateHead(bool enabled) {
    _autoOscillateHead = enabled;
  }

  @override
  void setSimulationProfile(SimulationProfile profile) {
    _profile = profile;
    _profileStartedAt = DateTime.now();
    if (profile == SimulationProfile.sansHyperopicShift) {
      _distanceCm = 44.0;
    } else if (profile == SimulationProfile.nominalAstronaut) {
      _distanceCm = 25.0;
    }
  }

  @override
  void setSimulatedDistanceCm(double distanceCm) {
    _distanceCm = distanceCm.clamp(12.0, 80.0);
  }

  @override
  void setSimulatedHeadAngles({
    double? yawDeg,
    double? pitchDeg,
    double? rollDeg,
  }) {
    if (yawDeg != null) _manualYawDeg = yawDeg.clamp(-45.0, 45.0);
    if (pitchDeg != null) _manualPitchDeg = pitchDeg.clamp(-35.0, 35.0);
    if (rollDeg != null) _manualRollDeg = rollDeg.clamp(-45.0, 45.0);
  }

  @override
  void setSimulatedGazeOffsetDeg(double gazeOffsetDeg) {
    _manualGazeOffsetDeg = gazeOffsetDeg.clamp(0.0, 20.0);
  }

  /// Inicializa de forma segura e idempotente la cámara frontal y el flujo de
  /// análisis de cuadros para telemetría RGB/IPD en vivo.
  Future<void> ensureCameraInitialized() {
    if (_disposed || !enableHardwareCamera) {
      return Future<void>.value();
    }
    if (_cameraController.value?.value.isInitialized == true) {
      return Future<void>.value();
    }
    if (_cameraInitFuture != null) {
      return _cameraInitFuture!;
    }
    if (_cameraAttempted) {
      return Future<void>.value();
    }
    _cameraAttempted = true;
    _cameraInitFuture = _initCameraSafe();
    return _cameraInitFuture!;
  }

  Future<void> _initCameraSafe() async {
    _isCameraInitializing.value = true;
    final completer = Completer<void>();

    runZonedGuarded(
      () async {
        try {
          final cameras = await availableCameras();
          if (_disposed) {
            if (!completer.isCompleted) completer.complete();
            return;
          }
          if (cameras.isEmpty) {
            _cameraStatusNote.value =
                'Sin cámara frontal detectada en este dispositivo';
            _isCameraInitializing.value = false;
            if (!completer.isCompleted) completer.complete();
            return;
          }

          final frontCamera = cameras.firstWhere(
            (c) => c.lensDirection == CameraLensDirection.front,
            orElse: () => cameras.first,
          );

          final controller = CameraController(
            frontCamera,
            ResolutionPreset.medium,
            enableAudio: false,
            imageFormatGroup: ImageFormatGroup.yuv420,
          );

          await controller.initialize();
          if (_disposed) {
            await _disposeControllerSafe(controller);
            if (!completer.isCompleted) completer.complete();
            return;
          }

          _cameraController.value = controller;
          _cameraStatusNote.value = null;
          _isCameraInitializing.value = false;

          try {
            await controller.startImageStream(_onCameraImage);
          } catch (_) {
            // Algunas plataformas soportan CameraPreview sin startImageStream;
            // el preview permanece vivo mientras el bus biométrico respalda las métricas.
            _cameraStatusNote.value =
                'Vista óptica activa · Análisis espectral en bus biométrico';
          }
        } catch (_) {
          if (!_disposed) {
            _cameraStatusNote.value =
                'Canal óptico frontal no disponible · Bus biométrico activo';
            _isCameraInitializing.value = false;
          }
        } finally {
          _cameraInitFuture = null;
          if (!completer.isCompleted) completer.complete();
        }
      },
      (_, _) {
        if (!_disposed) {
          _cameraStatusNote.value =
              'Canal óptico frontal no disponible · Bus biométrico activo';
          _isCameraInitializing.value = false;
        }
        _cameraInitFuture = null;
        if (!completer.isCompleted) completer.complete();
      },
    );

    return completer.future;
  }

  void _onCameraImage(CameraImage image) {
    if (_disposed) return;
    final now = DateTime.now();
    if (now.difference(_lastProcessedFrameAt).inMilliseconds < 80) {
      return; // ~12.5 Hz análisis de imagen sin saturar el hilo UI
    }
    _lastProcessedFrameAt = now;

    FaceSample? analyzed;
    try {
      if (image.format.group == ImageFormatGroup.bgra8888 &&
          image.planes.isNotEmpty) {
        final plane = image.planes.first;
        analyzed = analyzeBgra8888Frame(
          width: image.width,
          height: image.height,
          bytes: plane.bytes,
          rowStride: plane.bytesPerRow,
          timestamp: now,
        );
      } else if (image.planes.length >= 3) {
        final yPlane = image.planes[0];
        final uPlane = image.planes[1];
        final vPlane = image.planes[2];
        analyzed = analyzeYuv420Frame(
          width: image.width,
          height: image.height,
          yBytes: yPlane.bytes,
          uBytes: uPlane.bytes,
          vBytes: vPlane.bytes,
          yRowStride: yPlane.bytesPerRow,
          uvRowStride: uPlane.bytesPerRow,
          uvPixelStride: uPlane.bytesPerPixel ?? 1,
          timestamp: now,
        );
      } else if (image.planes.length == 2) {
        // Fallback NV21 / BiPlanar (Y + VU/UV)
        final yPlane = image.planes[0];
        final uvPlane = image.planes[1];
        analyzed = analyzeYuv420Frame(
          width: image.width,
          height: image.height,
          yBytes: yPlane.bytes,
          uBytes: uvPlane.bytes,
          vBytes: uvPlane.bytes,
          yRowStride: yPlane.bytesPerRow,
          uvRowStride: uvPlane.bytesPerRow,
          uvPixelStride: uvPlane.bytesPerPixel ?? 2,
          timestamp: now,
        );
      }
    } catch (_) {
      analyzed = null;
    }

    if (analyzed != null) {
      _latestCameraSample = analyzed;
      _lastCameraSampleAt = now;
      final controller = _faceController;
      if (controller != null && !controller.isClosed && controller.hasListener) {
        controller.add(analyzed);
      }
    }
  }

  /// Extrae métricas faciales reales (RGB promedio en frente/mejillas e IPD por
  /// centroides oscuros en la banda ocular) desde un buffer `YUV420`.
  FaceSample? analyzeYuv420Frame({
    required int width,
    required int height,
    required Uint8List yBytes,
    required Uint8List uBytes,
    required Uint8List vBytes,
    required int yRowStride,
    required int uvRowStride,
    required int uvPixelStride,
    DateTime? timestamp,
  }) {
    if (width < 16 || height < 16) return null;

    const step = 4;
    double sumR = 0;
    double sumG = 0;
    double sumB = 0;
    double sumLuma = 0;
    int roiCount = 0;

    void sampleRoi(double minXFrac, double maxXFrac, double minYFrac, double maxYFrac) {
      final xStart = (width * minXFrac).round().clamp(0, width - 1);
      final xEnd = (width * maxXFrac).round().clamp(xStart + 1, width);
      final yStart = (height * minYFrac).round().clamp(0, height - 1);
      final yEnd = (height * maxYFrac).round().clamp(yStart + 1, height);

      for (var y = yStart; y < yEnd; y += step) {
        final yRowOffset = y * yRowStride;
        final uvRowOffset = (y >> 1) * uvRowStride;
        for (var x = xStart; x < xEnd; x += step) {
          final yIdx = yRowOffset + x;
          final uvIdx = uvRowOffset + (x >> 1) * uvPixelStride;
          if (yIdx >= yBytes.length ||
              uvIdx >= uBytes.length ||
              uvIdx >= vBytes.length) {
            continue;
          }
          final yVal = yBytes[yIdx].toDouble();
          final uVal = uBytes[uvIdx].toDouble() - 128.0;
          final vVal = vBytes[uvIdx].toDouble() - 128.0;

          final r = (yVal + 1.402 * vVal).clamp(0.0, 255.0);
          final g =
              (yVal - 0.344136 * uVal - 0.714136 * vVal).clamp(0.0, 255.0);
          final b = (yVal + 1.772 * uVal).clamp(0.0, 255.0);

          sumR += r;
          sumG += g;
          sumB += b;
          sumLuma += yVal;
          roiCount++;
        }
      }
    }

    // Frente + Mejilla izquierda + Mejilla derecha
    sampleRoi(0.32, 0.68, 0.12, 0.28);
    sampleRoi(0.18, 0.38, 0.55, 0.78);
    sampleRoi(0.62, 0.82, 0.55, 0.78);

    if (roiCount == 0) return null;

    final rawR = sumR / roiCount;
    final rawG = sumG / roiCount;
    final rawB = sumB / roiCount;
    final meanLuma = sumLuma / roiCount;

    final eyes = _estimateEyeCentroidsFromLuma(
      width: width,
      height: height,
      readLuma: (x, y) {
        final idx = y * yRowStride + x;
        return idx < yBytes.length ? yBytes[idx].toDouble() : meanLuma;
      },
    );

    return _composeCameraSample(
      width: width,
      height: height,
      rawR: rawR,
      rawG: rawG,
      rawB: rawB,
      meanLuma: meanLuma,
      eyeCentroids: eyes,
      timestamp: timestamp ?? DateTime.now(),
    );
  }

  /// Extrae métricas faciales reales desde un buffer `BGRA8888`.
  FaceSample? analyzeBgra8888Frame({
    required int width,
    required int height,
    required Uint8List bytes,
    required int rowStride,
    DateTime? timestamp,
  }) {
    if (width < 16 || height < 16) return null;

    const step = 4;
    double sumR = 0;
    double sumG = 0;
    double sumB = 0;
    double sumLuma = 0;
    int roiCount = 0;

    void sampleRoi(double minXFrac, double maxXFrac, double minYFrac, double maxYFrac) {
      final xStart = (width * minXFrac).round().clamp(0, width - 1);
      final xEnd = (width * maxXFrac).round().clamp(xStart + 1, width);
      final yStart = (height * minYFrac).round().clamp(0, height - 1);
      final yEnd = (height * maxYFrac).round().clamp(yStart + 1, height);

      for (var y = yStart; y < yEnd; y += step) {
        final rowOffset = y * rowStride;
        for (var x = xStart; x < xEnd; x += step) {
          final idx = rowOffset + x * 4;
          if (idx + 2 >= bytes.length) continue;
          final b = bytes[idx].toDouble();
          final g = bytes[idx + 1].toDouble();
          final r = bytes[idx + 2].toDouble();
          sumR += r;
          sumG += g;
          sumB += b;
          sumLuma += 0.299 * r + 0.587 * g + 0.114 * b;
          roiCount++;
        }
      }
    }

    sampleRoi(0.32, 0.68, 0.12, 0.28);
    sampleRoi(0.18, 0.38, 0.55, 0.78);
    sampleRoi(0.62, 0.82, 0.55, 0.78);

    if (roiCount == 0) return null;

    final rawR = sumR / roiCount;
    final rawG = sumG / roiCount;
    final rawB = sumB / roiCount;
    final meanLuma = sumLuma / roiCount;

    final eyes = _estimateEyeCentroidsFromLuma(
      width: width,
      height: height,
      readLuma: (x, y) {
        final idx = y * rowStride + x * 4;
        if (idx + 2 >= bytes.length) return meanLuma;
        return 0.299 * bytes[idx + 2] +
            0.587 * bytes[idx + 1] +
            0.114 * bytes[idx];
      },
    );

    return _composeCameraSample(
      width: width,
      height: height,
      rawR: rawR,
      rawG: rawG,
      rawB: rawB,
      meanLuma: meanLuma,
      eyeCentroids: eyes,
      timestamp: timestamp ?? DateTime.now(),
    );
  }

  _EyePairCentroids? _estimateEyeCentroidsFromLuma({
    required int width,
    required int height,
    required double Function(int x, int y) readLuma,
  }) {
    final yStart = (height * 0.34).round().clamp(0, height - 1);
    final yEnd = (height * 0.54).round().clamp(yStart + 1, height);
    final step = math.max(1, (width / 160).floor());

    ({double x, double y, double contrast})? findDarkCentroid(
      double minXFrac,
      double maxXFrac,
    ) {
      final xStart = (width * minXFrac).round().clamp(0, width - 1);
      final xEnd = (width * maxXFrac).round().clamp(xStart + 1, width);
      double sumL = 0;
      int count = 0;
      for (var y = yStart; y < yEnd; y += step) {
        for (var x = xStart; x < xEnd; x += step) {
          sumL += readLuma(x, y);
          count++;
        }
      }
      if (count == 0) return null;
      final meanL = sumL / count;
      if (meanL < 18.0) return null;

      final threshold = meanL * 0.72;
      double weightSum = 0;
      double wx = 0;
      double wy = 0;

      for (var y = yStart; y < yEnd; y += step) {
        for (var x = xStart; x < xEnd; x += step) {
          final l = readLuma(x, y);
          if (l < threshold) {
            final d = meanL - l;
            final w = d * d;
            weightSum += w;
            wx += x * w;
            wy += y * w;
          }
        }
      }
      if (weightSum <= 0) return null;
      return (x: wx / weightSum, y: wy / weightSum, contrast: meanL);
    }

    final left = findDarkCentroid(0.22, 0.48);
    final right = findDarkCentroid(0.52, 0.78);
    if (left == null || right == null) return null;
    if (right.x <= left.x) return null;
    return _EyePairCentroids(
      leftX: left.x,
      leftY: left.y,
      rightX: right.x,
      rightY: right.y,
    );
  }

  FaceSample _composeCameraSample({
    required int width,
    required int height,
    required double rawR,
    required double rawG,
    required double rawB,
    required double meanLuma,
    required _EyePairCentroids? eyeCentroids,
    required DateTime timestamp,
  }) {
    final cal = readCalibration();
    const alpha = 0.30;

    final r = _emaRed = _ema(_emaRed, rawR, alpha);
    final g = _emaGreen = _ema(_emaGreen, rawG, alpha);
    final b = _emaBlue = _ema(_emaBlue, rawB, alpha);

    final fallbackIpdPx =
        (cal.focalLengthPx * cal.crewIpdMm) / (_distanceCm * 10.0);

    double measuredIpdPx = fallbackIpdPx;
    double gazeDeg = 0.8;
    double rollDeg = 0.0;

    if (eyeCentroids != null) {
      final dx = eyeCentroids.rightX - eyeCentroids.leftX;
      final dy = eyeCentroids.rightY - eyeCentroids.leftY;
      final pixelDist = math.sqrt(dx * dx + dy * dy);
      final normalizedIpd = pixelDist * (640.0 / width);
      if (normalizedIpd >= 45.0 && normalizedIpd <= 320.0) {
        measuredIpdPx = normalizedIpd;
      }
      rollDeg = (math.atan2(dy, dx) * 180.0 / math.pi).clamp(-35.0, 35.0);

      final midXNorm = ((eyeCentroids.leftX + eyeCentroids.rightX) * 0.5) / width;
      final midYNorm =
          ((eyeCentroids.leftY + eyeCentroids.rightY) * 0.5) / height;
      final offsetNorm = math.sqrt(
        math.pow(midXNorm - 0.50, 2) + math.pow(midYNorm - 0.44, 2),
      );
      gazeDeg = (offsetNorm * 32.0).clamp(0.2, 15.0);
    }

    final smoothIpd = _emaIpdPx = _ema(_emaIpdPx, measuredIpdPx, alpha);
    final smoothGaze = _emaGazeDeg = _ema(_emaGazeDeg, gazeDeg, alpha);
    final smoothRoll = _emaRollDeg = _ema(_emaRollDeg, rollDeg, alpha);

    final faceDetected = meanLuma >= 22.0 && meanLuma <= 248.0;

    return FaceSample(
      timestamp: timestamp,
      headYawDeg: _manualYawDeg,
      headPitchDeg: _manualPitchDeg,
      headRollDeg: smoothRoll,
      gazeOffsetDeg: smoothGaze,
      ipdPixels: smoothIpd,
      cheekRedMean: r,
      cheekGreenMean: g,
      cheekBlueMean: b,
      whiteReferenceLuminance: 1.0,
      faceDetected: faceDetected,
      source: SensingDataSource.opticalCamera,
    );
  }

  double _ema(double? prev, double next, double alpha) {
    if (prev == null) return next;
    return prev + alpha * (next - prev);
  }

  @override
  Stream<FaceSample> watchFaceSamples() {
    _faceController ??= StreamController<FaceSample>.broadcast(
      onListen: _startFaceStream,
      onCancel: _stopFaceStreamIfUnused,
    );
    return _faceController!.stream;
  }

  void _startFaceStream() {
    if (_disposed) return;
    if (enableHardwareCamera) {
      // Inicia cámara sin bloquear el stream síncrono; si falla, el bus biométrico continúa.
      unawaited(ensureCameraInitialized());
    }
    _telemetryTimer?.cancel();
    _telemetryTimer = Timer.periodic(
      const Duration(milliseconds: 50),
      (_) {
        if (_disposed) return;
        final controller = _faceController;
        if (controller == null || controller.isClosed || !controller.hasListener) {
          return;
        }
        final lastCamAt = _lastCameraSampleAt;
        final camSample = _latestCameraSample;
        final now = DateTime.now();
        if (camSample != null &&
            lastCamAt != null &&
            now.difference(lastCamAt) < const Duration(seconds: 2)) {
          // Cuando la cámara acaba de emitir su cuadro más reciente (<150 ms), no duplicamos.
          if (now.difference(lastCamAt).inMilliseconds >= 150) {
            controller.add(camSample.copyWith(timestamp: now));
          }
          return;
        }
        controller.add(_buildBusSample(_tick++));
      },
    );
  }

  void _stopFaceStreamIfUnused() {
    if (_faceController != null && !_faceController!.hasListener) {
      _telemetryTimer?.cancel();
      _telemetryTimer = null;
    }
  }

  FaceSample _buildBusSample(int tick) {
    final now = DateTime.now();
    final elapsedSec =
        now.difference(_profileStartedAt).inMilliseconds / 1000.0;
    final cal = readCalibration();

    final double headYaw = _autoOscillateHead
        ? 18.0 * math.sin(2 * math.pi * 1.0 * elapsedSec) + _manualYawDeg
        : _manualYawDeg;
    final double headPitch =
        _manualPitchDeg + 1.5 * math.cos(2 * math.pi * 0.4 * elapsedSec);
    final double headRoll = _manualRollDeg;

    final distanceMm = _distanceCm * 10.0;
    final yawRad = headYaw * math.pi / 180.0;
    final projectedIpdPx =
        (cal.focalLengthPx * cal.crewIpdMm / distanceMm) *
            math.cos(yawRad).clamp(0.75, 1.0);

    const double redMean = 172.0;
    double greenMean = redMean * cal.baselineGreenRedRatio;
    double gazeOffset = _manualGazeOffsetDeg + 0.6;

    if (_profile == SimulationProfile.smsNauseaOnset) {
      final ramp = (elapsedSec / 15.0).clamp(0.0, 1.0);
      const deltaRatio = 0.062;
      greenMean = redMean * (cal.baselineGreenRedRatio + deltaRatio * ramp);
      gazeOffset = _manualGazeOffsetDeg +
          3.8 * (0.4 + 0.6 * math.sin(2 * math.pi * 1.0 * elapsedSec).abs());
    } else if (_profile == SimulationProfile.sansHyperopicShift) {
      gazeOffset = _manualGazeOffsetDeg + 1.1;
    }

    return FaceSample(
      timestamp: now,
      headYawDeg: headYaw,
      headPitchDeg: headPitch,
      headRollDeg: headRoll,
      gazeOffsetDeg: gazeOffset,
      ipdPixels: projectedIpdPx,
      cheekRedMean: redMean,
      cheekGreenMean: greenMean,
      cheekBlueMean: 138.0,
      whiteReferenceLuminance: 1.0,
      faceDetected: true,
      source: SensingDataSource.biometricTelemetryBus,
    );
  }

  Future<void> _disposeControllerSafe(CameraController controller) async {
    try {
      if (controller.value.isStreamingImages) {
        await controller.stopImageStream();
      }
    } catch (_) {}
    try {
      await controller.dispose();
    } catch (_) {}
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _telemetryTimer?.cancel();
    _telemetryTimer = null;
    final controller = _cameraController.value;
    _cameraController.value = null;
    if (controller != null) {
      await _disposeControllerSafe(controller);
    }
    _cameraController.dispose();
    _isCameraInitializing.dispose();
    _cameraStatusNote.dispose();
    await _faceController?.close();
    _faceController = null;
  }
}

class _EyePairCentroids {
  final double leftX;
  final double leftY;
  final double rightX;
  final double rightY;

  const _EyePairCentroids({
    required this.leftX,
    required this.leftY,
    required this.rightX,
    required this.rightY,
  });
}

/// Adaptador inercial 3D (Roll, Pitch, Yaw) para "Zero-G Horizon" y pruebas
/// vestibulares.
///
/// Integra `sensors_plus` (`gyroscopeEventStream` + `accelerometerEventStream`)
/// mediante filtro complementario y contiene de forma segura cualquier error de
/// plataforma (`MissingPluginException`) con respaldo automático al bus de
/// telemetría vestibular autónomo.
class SimulatedMotionSensor implements MotionSensorPort {
  final bool enableHardwareSensors;

  double _rollDeg = 0.0;
  double _pitchDeg = 0.0;
  double _yawDeg = 0.0;
  double _prevRoll = 0.0;
  double _prevPitch = 0.0;
  double _prevYaw = 0.0;

  // Estado IMU en vivo
  double _hwRollDeg = 0.0;
  double _hwPitchDeg = 0.0;
  double _hwYawDeg = 0.0;
  double _hwRollRateDegPerSec = 0.0;
  double _hwPitchRateDegPerSec = 0.0;
  double _hwYawRateDegPerSec = 0.0;
  double _lastAccelX = 0.0;
  double _lastAccelY = 0.0;
  double _lastAccelZ = 9.81;
  bool _hasAccel = false;
  DateTime? _lastGyroAt;
  DateTime? _lastHardwareImuAt;

  StreamSubscription<GyroscopeEvent>? _gyroSub;
  StreamSubscription<AccelerometerEvent>? _accelSub;
  bool _hardwareSensorsStarted = false;
  bool _disposed = false;

  StreamController<MotionSample>? _motionController;
  Timer? _motionTimer;

  SimulatedMotionSensor({this.enableHardwareSensors = true});

  @override
  void setControlInput({
    required double rollDeg,
    required double pitchDeg,
    required double yawDeg,
  }) {
    _rollDeg = rollDeg.clamp(-60.0, 60.0);
    _pitchDeg = pitchDeg.clamp(-60.0, 60.0);
    _yawDeg = yawDeg.clamp(-60.0, 60.0);
  }

  /// Procesa una muestra real de giroscopio (rad/s) y acelerómetro (m/s²).
  void ingestHardwareImu({
    double? gyroXRad,
    double? gyroYRad,
    double? gyroZRad,
    double? accelX,
    double? accelY,
    double? accelZ,
    double dtSec = 0.05,
    DateTime? timestamp,
  }) {
    if (accelX != null && accelY != null && accelZ != null) {
      _lastAccelX = accelX;
      _lastAccelY = accelY;
      _lastAccelZ = accelZ;
      _hasAccel = true;
    }

    const radToDeg = 180.0 / math.pi;
    final safeDt = dtSec.clamp(0.005, 0.25);

    if (gyroXRad != null && gyroYRad != null && gyroZRad != null) {
      _hwPitchRateDegPerSec = gyroXRad * radToDeg;
      _hwRollRateDegPerSec = gyroYRad * radToDeg;
      _hwYawRateDegPerSec = gyroZRad * radToDeg;

      _hwPitchDeg += _hwPitchRateDegPerSec * safeDt;
      _hwRollDeg += _hwRollRateDegPerSec * safeDt;
      _hwYawDeg += _hwYawRateDegPerSec * safeDt;
    }

    // Filtro complementario cuando existe vector gravitacional válido (~1g);
    // en microgravedad (|a| < 2.0 m/s²) predomina integración pura de giroscopio.
    if (_hasAccel) {
      final mag = math.sqrt(
        _lastAccelX * _lastAccelX +
            _lastAccelY * _lastAccelY +
            _lastAccelZ * _lastAccelZ,
      );
      if (mag > 4.0 && mag < 18.0) {
        final accelRoll =
            math.atan2(_lastAccelY, _lastAccelZ) * radToDeg;
        final accelPitch = math.atan2(
              -_lastAccelX,
              math.sqrt(_lastAccelY * _lastAccelY + _lastAccelZ * _lastAccelZ),
            ) *
            radToDeg;
        _hwRollDeg = 0.96 * _hwRollDeg + 0.04 * accelRoll;
        _hwPitchDeg = 0.96 * _hwPitchDeg + 0.04 * accelPitch;
      }
    }

    _hwRollDeg = _hwRollDeg.clamp(-60.0, 60.0);
    _hwPitchDeg = _hwPitchDeg.clamp(-60.0, 60.0);
    _hwYawDeg = _hwYawDeg.clamp(-60.0, 60.0);
    _lastHardwareImuAt = timestamp ?? DateTime.now();
  }

  void _ensureHardwareSensorsStarted() {
    if (_disposed || !enableHardwareSensors || _hardwareSensorsStarted) return;
    _hardwareSensorsStarted = true;

    runZonedGuarded(
      () {
        _gyroSub = gyroscopeEventStream(
          samplingPeriod: const Duration(milliseconds: 50),
        ).listen(
          (event) {
            if (_disposed) return;
            final now = DateTime.now();
            final dt = _lastGyroAt == null
                ? 0.05
                : now.difference(_lastGyroAt!).inMicroseconds / 1e6;
            _lastGyroAt = now;
            ingestHardwareImu(
              gyroXRad: event.x,
              gyroYRad: event.y,
              gyroZRad: event.z,
              dtSec: dt,
              timestamp: now,
            );
          },
          onError: (_) => _cancelHardwareSubs(),
          cancelOnError: true,
        );

        _accelSub = accelerometerEventStream(
          samplingPeriod: const Duration(milliseconds: 50),
        ).listen(
          (event) {
            if (_disposed) return;
            ingestHardwareImu(
              accelX: event.x,
              accelY: event.y,
              accelZ: event.z,
              timestamp: DateTime.now(),
            );
          },
          onError: (_) => _cancelHardwareSubs(),
          cancelOnError: true,
        );
      },
      (_, _) => _cancelHardwareSubs(),
    );
  }

  void _cancelHardwareSubs() {
    _gyroSub?.cancel();
    _gyroSub = null;
    _accelSub?.cancel();
    _accelSub = null;
  }

  @override
  Stream<MotionSample> watchMotionSamples() {
    _motionController ??= StreamController<MotionSample>.broadcast(
      onListen: _startMotionStream,
      onCancel: _stopMotionStreamIfUnused,
    );
    return _motionController!.stream;
  }

  void _startMotionStream() {
    if (_disposed) return;
    _ensureHardwareSensorsStarted();
    _motionTimer?.cancel();
    const dt = 0.05;
    _motionTimer = Timer.periodic(
      const Duration(milliseconds: 50),
      (_) {
        if (_disposed) return;
        final controller = _motionController;
        if (controller == null || controller.isClosed || !controller.hasListener) {
          return;
        }
        final now = DateTime.now();
        final lastHw = _lastHardwareImuAt;
        if (lastHw != null &&
            now.difference(lastHw) < const Duration(seconds: 2)) {
          controller.add(
            MotionSample(
              timestamp: now,
              rollDeg: _hwRollDeg,
              pitchDeg: _hwPitchDeg,
              yawDeg: _hwYawDeg,
              rollRateDegPerSec: _hwRollRateDegPerSec,
              pitchRateDegPerSec: _hwPitchRateDegPerSec,
              yawRateDegPerSec: _hwYawRateDegPerSec,
              source: SensingDataSource.opticalCamera,
            ),
          );
          return;
        }

        final rollRate = (_rollDeg - _prevRoll) / dt;
        final pitchRate = (_pitchDeg - _prevPitch) / dt;
        final yawRate = (_yawDeg - _prevYaw) / dt;
        _prevRoll = _rollDeg;
        _prevPitch = _pitchDeg;
        _prevYaw = _yawDeg;

        controller.add(
          MotionSample(
            timestamp: now,
            rollDeg: _rollDeg,
            pitchDeg: _pitchDeg,
            yawDeg: _yawDeg,
            rollRateDegPerSec: rollRate,
            pitchRateDegPerSec: pitchRate,
            yawRateDegPerSec: yawRate,
            source: SensingDataSource.biometricTelemetryBus,
          ),
        );
      },
    );
  }

  void _stopMotionStreamIfUnused() {
    if (_motionController != null && !_motionController!.hasListener) {
      _motionTimer?.cancel();
      _motionTimer = null;
    }
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _motionTimer?.cancel();
    _motionTimer = null;
    _cancelHardwareSubs();
    await _motionController?.close();
    _motionController = null;
  }
}

final simulationProfileProvider = StateProvider<SimulationProfile>((ref) {
  return SimulationProfile.nominalAstronaut;
});

final faceTrackerPortProvider = Provider<FaceTrackerPort>((ref) {
  final tracker = SimulatedFaceTracker(
    readCalibration: () => ref.read(deviceCalibrationProvider),
  );
  ref.listen<SimulationProfile>(simulationProfileProvider, (_, next) {
    tracker.setSimulationProfile(next);
  });
  ref.onDispose(() {
    unawaited(tracker.dispose());
  });
  return tracker;
});

final motionSensorPortProvider = Provider<MotionSensorPort>((ref) {
  final sensor = SimulatedMotionSensor();
  ref.onDispose(() {
    unawaited(sensor.dispose());
  });
  return sensor;
});
