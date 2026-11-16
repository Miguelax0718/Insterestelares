import 'package:camera/camera.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:astramed/core/calibration/domain/device_calibration.dart';
import 'package:astramed/core/sensing/data/simulated_sensing_adapters.dart';
import 'package:astramed/core/sensing/domain/sensing_ports.dart';
import 'package:astramed/core/sensing/presentation/clinical_camera_hud.dart';

class _FakeCameraController extends CameraController {
  _FakeCameraController()
      : super(
          const CameraDescription(
            name: 'front_test',
            lensDirection: CameraLensDirection.front,
            sensorOrientation: 270,
          ),
          ResolutionPreset.medium,
          enableAudio: false,
        ) {
    value = CameraValue(
      isInitialized: true,
      previewSize: const Size(640, 480),
      isRecordingVideo: false,
      isTakingPicture: false,
      isStreamingImages: false,
      isRecordingPaused: false,
      flashMode: FlashMode.off,
      exposureMode: ExposureMode.auto,
      focusMode: FocusMode.auto,
      exposurePointSupported: false,
      focusPointSupported: false,
      deviceOrientation: DeviceOrientation.portraitUp,
      description: const CameraDescription(
        name: 'front_test',
        lensDirection: CameraLensDirection.front,
        sensorOrientation: 270,
      ),
    );
  }

  @override
  Widget buildPreview() {
    return const SizedBox(
      key: Key('real_camera_preview_surface'),
      width: 640,
      height: 480,
    );
  }
}

void main() {
  group('DeviceCalibration & Sensing Ports (PRESERVE)', () {
    test('calculates pixelsPerMm accurately from ISO ID-1 card width', () {
      const initial = DeviceCalibration();
      final calibrated = DeviceCalibration.fromId1CardWidthPx(
        cardWidthLogicalPx: 85.60 * 5.0,
        current: initial,
      );
      expect(calibrated.pixelsPerMm, closeTo(5.0, 0.001));
    });

    test('calibrates camera focal length in pixels from known distance and IPD',
        () {
      const initial = DeviceCalibration(crewIpdMm: 63.0);
      final calibrated = initial.calibrateFocalLength(
        measuredIpdPx: 126.0,
        knownDistanceCm: 30.0,
      );
      expect(calibrated.focalLengthPx, closeTo(600.0, 0.01));
    });

    test('SimulatedFaceTracker emits expected IPD pixels and greenness shift',
        () async {
      const cal = DeviceCalibration(
        focalLengthPx: 600.0,
        crewIpdMm: 63.0,
        baselineGreenRedRatio: 0.88,
      );
      final tracker = SimulatedFaceTracker(
        readCalibration: () => cal,
        enableHardwareCamera: false,
      );
      addTearDown(tracker.dispose);

      tracker.setAutoOscillateHead(false);
      tracker.setSimulatedDistanceCm(30.0);

      final sample = await tracker.watchFaceSamples().first;
      expect(sample.ipdPixels, closeTo(126.0, 0.5));
      expect(sample.normalizedGreenRedRatio, closeTo(0.88, 0.01));
      expect(sample.source, SensingDataSource.biometricTelemetryBus);

      tracker.setSimulationProfile(SimulationProfile.sansHyperopicShift);
      expect(tracker.currentDistanceCm, closeTo(44.0, 0.1));
    });
  });

  group('T5: Hardware Camera + IMU Integration & Fallback', () {
    test(
        'SimulatedFaceTracker falls back cleanly to biometricTelemetryBus when camera hardware is unavailable',
        () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      final tracker = SimulatedFaceTracker(
        readCalibration: () => const DeviceCalibration(),
        enableHardwareCamera: true,
      );
      addTearDown(tracker.dispose);

      await tracker.ensureCameraInitialized();
      final sample = await tracker.watchFaceSamples().first;
      expect(sample.faceDetected, isTrue);
      expect(sample.ipdPixels, greaterThan(0));
      expect(sample.source, SensingDataSource.biometricTelemetryBus);
    });

    test(
        'SimulatedFaceTracker extracts real ROI RGB and ocular IPD from YUV420 frames',
        () {
      const width = 160;
      const height = 120;
      final yBytes = Uint8List(width * height);
      final uBytes = Uint8List((width ~/ 2) * (height ~/ 2));
      final vBytes = Uint8List((width ~/ 2) * (height ~/ 2));

      // Fill uniform facial mid-tone Y=160, U=120, V=145
      yBytes.fillRange(0, yBytes.length, 160);
      uBytes.fillRange(0, uBytes.length, 120);
      vBytes.fillRange(0, vBytes.length, 145);

      // Paint two dark pupil blobs in the eye band (y ~ 50, x=56 and x=104 -> 48 px apart -> 192 px at 640w)
      for (var y = 46; y <= 54; y++) {
        for (var x = 52; x <= 60; x++) {
          yBytes[y * width + x] = 20;
        }
        for (var x = 100; x <= 108; x++) {
          yBytes[y * width + x] = 20;
        }
      }

      final tracker = SimulatedFaceTracker(
        readCalibration: () => const DeviceCalibration(),
        enableHardwareCamera: false,
      );
      addTearDown(tracker.dispose);

      final sample = tracker.analyzeYuv420Frame(
        width: width,
        height: height,
        yBytes: yBytes,
        uBytes: uBytes,
        vBytes: vBytes,
        yRowStride: width,
        uvRowStride: width ~/ 2,
        uvPixelStride: 1,
      );

      expect(sample, isNotNull);
      expect(sample!.source, SensingDataSource.opticalCamera);
      expect(sample.faceDetected, isTrue);
      expect(sample.cheekRedMean, greaterThan(sample.cheekGreenMean));
      expect(sample.ipdPixels, closeTo(192.0, 24.0));
    });

    test(
        'SimulatedFaceTracker extracts real ROI RGB and ocular IPD from BGRA8888 frames',
        () {
      const width = 160;
      const height = 120;
      final bytes = Uint8List(width * height * 4);
      for (var i = 0; i < width * height; i++) {
        bytes[i * 4] = 120; // B
        bytes[i * 4 + 1] = 152; // G
        bytes[i * 4 + 2] = 188; // R
        bytes[i * 4 + 3] = 255; // A
      }
      for (var y = 46; y <= 54; y++) {
        for (var x = 52; x <= 60; x++) {
          final idx = (y * width + x) * 4;
          bytes[idx] = 15;
          bytes[idx + 1] = 15;
          bytes[idx + 2] = 15;
        }
        for (var x = 100; x <= 108; x++) {
          final idx = (y * width + x) * 4;
          bytes[idx] = 15;
          bytes[idx + 1] = 15;
          bytes[idx + 2] = 15;
        }
      }

      final tracker = SimulatedFaceTracker(
        readCalibration: () => const DeviceCalibration(),
        enableHardwareCamera: false,
      );
      addTearDown(tracker.dispose);

      final sample = tracker.analyzeBgra8888Frame(
        width: width,
        height: height,
        bytes: bytes,
        rowStride: width * 4,
      );

      expect(sample, isNotNull);
      expect(sample!.source, SensingDataSource.opticalCamera);
      expect(sample.cheekRedMean, closeTo(188.0, 1.0));
      expect(sample.cheekGreenMean, closeTo(152.0, 1.0));
      expect(sample.ipdPixels, closeTo(192.0, 24.0));
    });

    test(
        'SimulatedMotionSensor integrates sensors_plus safely with biometricTelemetryBus fallback and processes live IMU',
        () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      final sensor = SimulatedMotionSensor(enableHardwareSensors: true);
      addTearDown(sensor.dispose);

      sensor.setControlInput(rollDeg: 10.0, pitchDeg: -5.0, yawDeg: 8.0);
      final fallbackSample = await sensor.watchMotionSamples().first;
      expect(fallbackSample.source, SensingDataSource.biometricTelemetryBus);
      expect(fallbackSample.rollDeg, closeTo(10.0, 0.01));

      // Feed live hardware IMU values and verify conversion rad/s -> deg/s
      sensor.ingestHardwareImu(
        gyroXRad: 0.5,
        gyroYRad: -0.25,
        gyroZRad: 1.0,
        accelX: 0.0,
        accelY: 1.5,
        accelZ: 9.6,
        dtSec: 0.05,
      );
      final liveSample = await sensor.watchMotionSamples().first;
      expect(liveSample.source, SensingDataSource.opticalCamera);
      expect(liveSample.yawRateDegPerSec, closeTo(57.2958, 0.2));
    });
  });

  group('T5: ClinicalCameraHud Widget & Overlay', () {
    testWidgets(
        'renders live optical bio-scanner fallback and biometric HUD overlays without hardware camera',
        (tester) async {
      final sample = FaceSample(
        timestamp: DateTime(2026, 11, 14, 12, 0, 0),
        headYawDeg: 4.5,
        headPitchDeg: -2.0,
        headRollDeg: 1.0,
        gazeOffsetDeg: 1.25,
        ipdPixels: 132.4,
        cheekRedMean: 170.0,
        cheekGreenMean: 150.0,
        cheekBlueMean: 135.0,
        whiteReferenceLuminance: 0.95,
        source: SensingDataSource.biometricTelemetryBus,
      );

      await tester.pumpWidget(
        ProviderScope(
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: MediaQuery(
              data: const MediaQueryData(size: Size(400, 800)),
              child: ClinicalCameraHud(
                sample: sample,
                showRoiPolygons: true,
                showIpdCalipers: true,
                showGazeVector: true,
                showWhiteReferenceCard: true,
                whiteReferenceLuminance: 0.95,
                showVorTarget: true,
                vorPhase: 0.5,
                statusNote: 'Escáner facial activo',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('VISOR ÓPTICO FRONTAL EN VIVO'), findsOneWidget);
      expect(find.text('D65 REF'), findsOneWidget);
      expect(find.text('1.0 Hz VOR'), findsOneWidget);
      expect(find.text('Escáner facial activo'), findsOneWidget);
      expect(find.byType(CameraPreview), findsNothing);
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets(
        'renders real CameraPreview when an initialized CameraController is provided',
        (tester) async {
      final fakeController = _FakeCameraController();
      addTearDown(() async {
        // Explicit ValueNotifier disposal not required for fake test controller.
      });

      final sample = FaceSample(
        timestamp: DateTime(2026, 11, 14, 12, 0, 0),
        headYawDeg: 0.0,
        headPitchDeg: 0.0,
        headRollDeg: 0.0,
        gazeOffsetDeg: 0.4,
        ipdPixels: 128.0,
        cheekRedMean: 168.0,
        cheekGreenMean: 148.0,
        cheekBlueMean: 136.0,
        source: SensingDataSource.opticalCamera,
      );

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: MediaQuery(
            data: const MediaQueryData(size: Size(400, 800)),
            child: ClinicalCameraHud(
              controller: fakeController,
              sample: sample,
              showRoiPolygons: true,
              showIpdCalipers: true,
              showGazeVector: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(CameraPreview), findsOneWidget);
      expect(find.byKey(const Key('real_camera_preview_surface')), findsOneWidget);
      expect(find.text('EN VIVO'), findsOneWidget);
    });
  });
}
