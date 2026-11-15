import 'dart:async';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/space_theme.dart';
import '../data/simulated_sensing_adapters.dart';
import '../domain/sensing_ports.dart';

/// Visor clínico biométrico reutilizable con cámara frontal real (`CameraPreview`)
/// y HUD superpuesto (polígonos ROI en frente/mejillas, calibre interpupilar IPD,
/// vector de fijación ocular, tarjeta blanca D65 opcional y objetivo VOR 1 Hz).
///
/// Cuando el dispositivo no cuenta con cámara física o permisos (por ejemplo en
/// pruebas automatizadas o estaciones sin webcam), conmuta sin cortes a una
/// visualización en vivo de escáner óptico bio-métrico impulsada por telemetría.
class ClinicalCameraHud extends StatefulWidget {
  final FaceSample? sample;
  final CameraController? controller;
  final String title;
  final double height;
  final bool showRoiPolygons;
  final bool showIpdCalipers;
  final bool showGazeVector;
  final bool showWhiteReferenceCard;
  final double whiteReferenceLuminance;
  final bool showVorTarget;
  final double vorPhase;
  final bool showFixationTarget;
  final String? statusNote;
  final bool autoInitCamera;

  const ClinicalCameraHud({
    super.key,
    this.sample,
    this.controller,
    this.title = 'VISOR ÓPTICO FRONTAL EN VIVO',
    this.height = 240.0,
    this.showRoiPolygons = true,
    this.showIpdCalipers = true,
    this.showGazeVector = true,
    this.showWhiteReferenceCard = false,
    this.whiteReferenceLuminance = 1.0,
    this.showVorTarget = false,
    this.vorPhase = 0.0,
    this.showFixationTarget = false,
    this.statusNote,
    this.autoInitCamera = true,
  });

  @override
  State<ClinicalCameraHud> createState() => _ClinicalCameraHudState();
}

class _ClinicalCameraHudState extends State<ClinicalCameraHud> {
  SimulatedFaceTracker? _sharedTracker;
  CameraController? _ownedController;
  bool _initializing = false;
  String? _localStatusNote;
  bool _resolvedSource = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_resolvedSource) {
      _resolvedSource = true;
      _attachCameraSource();
    }
  }

  @override
  void didUpdateWidget(covariant ClinicalCameraHud oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      _detachSharedTracker();
      if (widget.controller == null) {
        _attachCameraSource();
      }
    }
  }

  void _attachCameraSource() {
    if (widget.controller != null || !widget.autoInitCamera) return;

    // Si existe un ProviderScope con SimulatedFaceTracker, reutilizamos su mismo
    // CameraController para evitar conflictos de apertura múltiple en Android.
    try {
      final container = ProviderScope.containerOf(context, listen: false);
      final port = container.read(faceTrackerPortProvider);
      if (port is SimulatedFaceTracker) {
        _sharedTracker = port;
        port.cameraControllerListenable.addListener(_onSharedCameraChanged);
        port.isCameraInitializingListenable.addListener(_onSharedCameraChanged);
        port.cameraStatusNoteListenable.addListener(_onSharedCameraChanged);
        if (!_isWidgetTestEnvironment) {
          unawaited(port.ensureCameraInitialized());
        }
        return;
      }
    } catch (_) {
      // Uso independiente sin ProviderScope.
    }

    if (!_isWidgetTestEnvironment) {
      unawaited(_initStandaloneCamera());
    } else {
      _localStatusNote = 'Bus óptico bio-métrico activo';
    }
  }

  void _onSharedCameraChanged() {
    if (!mounted) return;
    setState(() {});
  }

  void _detachSharedTracker() {
    final tracker = _sharedTracker;
    if (tracker != null) {
      tracker.cameraControllerListenable.removeListener(_onSharedCameraChanged);
      tracker.isCameraInitializingListenable
          .removeListener(_onSharedCameraChanged);
      tracker.cameraStatusNoteListenable.removeListener(_onSharedCameraChanged);
      _sharedTracker = null;
    }
  }

  Future<void> _initStandaloneCamera() async {
    if (!mounted) return;
    setState(() => _initializing = true);
    try {
      final cameras = await availableCameras();
      if (!mounted) return;
      if (cameras.isEmpty) {
        setState(() {
          _initializing = false;
          _localStatusNote = 'Sin cámara frontal detectada · Escáner óptico activo';
        });
        return;
      }
      final front = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        front,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _ownedController = controller;
        _initializing = false;
        _localStatusNote = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _initializing = false;
        _localStatusNote = 'Canal óptico en modo escáner bio-métrico';
      });
    }
  }

  @override
  void dispose() {
    _detachSharedTracker();
    final owned = _ownedController;
    _ownedController = null;
    if (owned != null) {
      unawaited(owned.dispose());
    }
    super.dispose();
  }

  CameraController? get _effectiveController =>
      widget.controller ??
      _sharedTracker?.activeCameraController ??
      _ownedController;

  bool get _isEffectiveInitializing =>
      widget.controller == null &&
      ((_sharedTracker?.isCameraInitializingListenable.value ?? false) ||
          _initializing);

  String? get _effectiveStatusNote =>
      _sharedTracker?.cameraStatusNoteListenable.value ?? _localStatusNote;

  Widget _buildCameraPreview(CameraController controller) {
    final previewSize = controller.value.previewSize;
    if (previewSize == null) {
      return CameraPreview(controller);
    }
    return ClipRect(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: previewSize.height,
          height: previewSize.width,
          child: CameraPreview(controller),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = _effectiveController;
    final hasLiveCamera =
        controller != null && controller.value.isInitialized;
    final isOpticalSample =
        widget.sample?.source == SensingDataSource.opticalCamera;
    final liveBadgeActive = hasLiveCamera || isOpticalSample;

    return Container(
      decoration: BoxDecoration(
        color: SpaceTheme.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: SpaceTheme.cyan.withValues(alpha: 0.45)),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SizedBox(
                width: 18,
                height: 18,
                child: CustomPaint(painter: _OpticalCameraGlyphPainter()),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.title,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: SpaceTheme.cyan,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: (liveBadgeActive
                          ? SpaceTheme.green
                          : SpaceTheme.cyan)
                      .withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: liveBadgeActive ? SpaceTheme.green : SpaceTheme.cyan,
                  ),
                ),
                child: Text(
                  liveBadgeActive ? 'EN VIVO' : 'TELEMETRÍA ÓPTICA',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: liveBadgeActive ? SpaceTheme.green : SpaceTheme.cyan,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              height: widget.height,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (hasLiveCamera)
                    _buildCameraPreview(controller)
                  else
                    CustomPaint(
                      painter: _OpticalBioScannerBackdropPainter(
                        sample: widget.sample,
                        isInitializing: _isEffectiveInitializing,
                      ),
                    ),
                  CustomPaint(
                    painter: ClinicalBiometricHudPainter(
                      sample: widget.sample,
                      showRoiPolygons: widget.showRoiPolygons,
                      showIpdCalipers: widget.showIpdCalipers,
                      showGazeVector: widget.showGazeVector,
                      showVorTarget: widget.showVorTarget,
                      vorPhase: widget.vorPhase,
                      showFixationTarget: widget.showFixationTarget,
                    ),
                  ),
                  if (widget.showWhiteReferenceCard)
                    Positioned(
                      top: 10,
                      right: 10,
                      child: _WhiteReferenceD65Patch(
                        luminance: widget.whiteReferenceLuminance,
                      ),
                    ),
                  if (widget.showVorTarget)
                    Positioned(
                      bottom: 10,
                      left: 12,
                      child: _HudPillBadge(
                        label: '1.0 Hz VOR',
                        color: SpaceTheme.warningYellow,
                      ),
                    ),
                  if (!hasLiveCamera)
                    Positioned(
                      bottom: 10,
                      right: 12,
                      child: _HudPillBadge(
                        label: _isEffectiveInitializing
                            ? 'INICIALIZANDO ÓPTICA…'
                            : 'ESCÁNER ÓPTICO BIO-MÉTRICO',
                        color: SpaceTheme.cyan,
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (widget.statusNote != null || _effectiveStatusNote != null) ...[
            const SizedBox(height: 8),
            Text(
              widget.statusNote ?? _effectiveStatusNote!,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: widget.statusNote != null
                    ? SpaceTheme.cyan
                    : const Color(0xB3FFFFFF),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _WhiteReferenceD65Patch extends StatelessWidget {
  final double luminance;

  const _WhiteReferenceD65Patch({required this.luminance});

  @override
  Widget build(BuildContext context) {
    final clamped = luminance.clamp(0.25, 1.0);
    final channel = (255 * clamped).round().clamp(64, 255);
    return Container(
      width: 68,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xCC070A0F),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0x88FFFFFF)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 22,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Color.fromARGB(255, channel, channel, channel),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(height: 3),
          const Text(
            'D65 REF',
            style: TextStyle(
              fontSize: 8.5,
              fontWeight: FontWeight.bold,
              color: Color(0xE6FFFFFF),
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _HudPillBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _HudPillBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xBB070A0F),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.65)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.bold,
          color: color,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _OpticalCameraGlyphPainter extends CustomPainter {
  const _OpticalCameraGlyphPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = SpaceTheme.cyan
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(1.5, 3.5, size.width - 3, size.height - 7),
      const Radius.circular(3),
    );
    canvas.drawRRect(rect, stroke);
    canvas.drawCircle(Offset(size.width / 2, size.height / 2), 3.2, stroke);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Visualización en vivo de escáner óptico bio-métrico cuando no existe hardware
/// de cámara física disponible.
class _OpticalBioScannerBackdropPainter extends CustomPainter {
  final FaceSample? sample;
  final bool isInitializing;

  const _OpticalBioScannerBackdropPainter({
    required this.sample,
    required this.isInitializing,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()..color = const Color(0xFF060B12);
    canvas.drawRect(Offset.zero & size, bg);

    // Rejilla telemétrica sutil
    final gridPaint = Paint()
      ..color = SpaceTheme.cyan.withValues(alpha: 0.08)
      ..strokeWidth = 0.8;
    const step = 28.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final yawShift = ((sample?.headYawDeg ?? 0.0) / 45.0) * (size.width * 0.08);
    final pitchShift =
        ((sample?.headPitchDeg ?? 0.0) / 35.0) * (size.height * 0.06);
    final center = Offset(size.width / 2 + yawShift, size.height * 0.48 + pitchShift);

    // Anillos concéntricos de rango óptico
    final ringPaint = Paint()
      ..color = SpaceTheme.cyan.withValues(alpha: 0.16)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    final baseR = math.min(size.width, size.height) * 0.34;
    canvas.drawCircle(center, baseR, ringPaint);
    canvas.drawCircle(center, baseR * 0.68, ringPaint);

    // Contorno craneofacial wireframe
    final faceOval = Rect.fromCenter(
      center: center,
      width: baseR * 1.18,
      height: baseR * 1.56,
    );
    final meshPaint = Paint()
      ..color = SpaceTheme.cyan.withValues(alpha: 0.38)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3;
    canvas.drawOval(faceOval, meshPaint);

    // Línea de barrido impulsada por marca temporal de telemetría
    final phase = isInitializing
        ? 0.5
        : ((sample?.timestamp.millisecondsSinceEpoch ?? 0) % 2000) / 2000.0;
    final scanY = size.height * (0.12 + 0.76 * phase);
    final scanPaint = Paint()
      ..color = SpaceTheme.cyan.withValues(alpha: 0.25)
      ..strokeWidth = 1.5;
    canvas.drawLine(Offset(14, scanY), Offset(size.width - 14, scanY), scanPaint);
  }

  @override
  bool shouldRepaint(covariant _OpticalBioScannerBackdropPainter oldDelegate) {
    return oldDelegate.sample != sample ||
        oldDelegate.isInitializing != isInitializing;
  }
}

/// Pintor del HUD biométrico clínico superpuesto sobre la cámara frontal.
class ClinicalBiometricHudPainter extends CustomPainter {
  final FaceSample? sample;
  final bool showRoiPolygons;
  final bool showIpdCalipers;
  final bool showGazeVector;
  final bool showVorTarget;
  final double vorPhase;
  final bool showFixationTarget;

  const ClinicalBiometricHudPainter({
    required this.sample,
    required this.showRoiPolygons,
    required this.showIpdCalipers,
    required this.showGazeVector,
    required this.showVorTarget,
    required this.vorPhase,
    required this.showFixationTarget,
  });

  static const double _nominalFrameWidthPx = 640.0;

  @override
  void paint(Canvas canvas, Size size) {
    _paintFrameBrackets(canvas, size);
    if (showRoiPolygons) {
      _paintForeheadRoi(canvas, size);
      _paintCheekRois(canvas, size);
    }
    if (showIpdCalipers) {
      _paintIpdCalipers(canvas, size);
    }
    if (showGazeVector) {
      _paintGazeVector(canvas, size);
    }
    if (showVorTarget) {
      _paintVorTarget(canvas, size);
    }
    if (showFixationTarget) {
      _paintFixationTarget(canvas, size);
    }
  }

  void _paintFrameBrackets(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = SpaceTheme.cyan.withValues(alpha: 0.85)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;
    const len = 16.0;
    final corners = <Offset>[
      const Offset(6, 6),
      Offset(size.width - 6, 6),
      Offset(6, size.height - 6),
      Offset(size.width - 6, size.height - 6),
    ];
    for (var i = 0; i < corners.length; i++) {
      final c = corners[i];
      final dx = (i == 0 || i == 2) ? len : -len;
      final dy = (i < 2) ? len : -len;
      canvas.drawLine(c, c + Offset(dx, 0), paint);
      canvas.drawLine(c, c + Offset(0, dy), paint);
    }
  }

  void _paintForeheadRoi(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width * 0.30, size.height * 0.11)
      ..lineTo(size.width * 0.70, size.height * 0.11)
      ..lineTo(size.width * 0.66, size.height * 0.26)
      ..lineTo(size.width * 0.34, size.height * 0.26)
      ..close();
    canvas.drawPath(
      path,
      Paint()..color = SpaceTheme.cyan.withValues(alpha: 0.08),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = SpaceTheme.cyan.withValues(alpha: 0.60)
        ..strokeWidth = 1.4
        ..style = PaintingStyle.stroke,
    );
    final ratioLabel = sample == null
        ? 'FOREHEAD ROI'
        : 'FOREHEAD ROI · G/R ${sample!.normalizedGreenRedRatio.toStringAsFixed(3)}';
    _drawLabel(
      canvas,
      Offset(size.width * 0.30, size.height * 0.11 - 13),
      ratioLabel,
      SpaceTheme.cyan,
    );
  }

  void _paintCheekRois(Canvas canvas, Size size) {
    final left = Path()
      ..moveTo(size.width * 0.16, size.height * 0.56)
      ..lineTo(size.width * 0.38, size.height * 0.60)
      ..lineTo(size.width * 0.36, size.height * 0.80)
      ..lineTo(size.width * 0.16, size.height * 0.76)
      ..close();
    final right = Path()
      ..moveTo(size.width * 0.84, size.height * 0.56)
      ..lineTo(size.width * 0.62, size.height * 0.60)
      ..lineTo(size.width * 0.64, size.height * 0.80)
      ..lineTo(size.width * 0.84, size.height * 0.76)
      ..close();
    final stroke = Paint()
      ..color = SpaceTheme.green.withValues(alpha: 0.65)
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;
    final fill = Paint()..color = SpaceTheme.green.withValues(alpha: 0.08);
    for (final p in [left, right]) {
      canvas.drawPath(p, fill);
      canvas.drawPath(p, stroke);
    }
    _drawLabel(
      canvas,
      Offset(size.width * 0.16, size.height * 0.56 - 13),
      'CHEEK ROI',
      SpaceTheme.green,
    );
  }

  void _paintIpdCalipers(Canvas canvas, Size size) {
    final ipdPx = sample?.ipdPixels ?? 120.0;
    final scale = size.width / _nominalFrameWidthPx;
    final halfSpan = ((ipdPx * scale) / 2).clamp(10.0, size.width * 0.38);
    final cy = size.height * 0.44;
    final left = Offset(size.width / 2 - halfSpan, cy);
    final right = Offset(size.width / 2 + halfSpan, cy);

    final paint = Paint()
      ..color = SpaceTheme.cyan
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke;

    canvas.drawLine(left, right, paint);
    canvas.drawLine(left + const Offset(0, -8), left + const Offset(0, 8), paint);
    canvas.drawLine(
      right + const Offset(0, -8),
      right + const Offset(0, 8),
      paint,
    );

    final pupilRing = Paint()
      ..color = SpaceTheme.cyan.withValues(alpha: 0.90)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;
    canvas.drawCircle(left, 6.5, pupilRing);
    canvas.drawCircle(right, 6.5, pupilRing);

    final pupilDot = Paint()..color = SpaceTheme.cyan;
    canvas.drawCircle(left, 2.2, pupilDot);
    canvas.drawCircle(right, 2.2, pupilDot);

    _drawLabel(
      canvas,
      Offset(size.width / 2 - 42, cy + 10),
      'IPD ${ipdPx.toStringAsFixed(1)} px',
      SpaceTheme.cyan,
    );
  }

  void _paintGazeVector(Canvas canvas, Size size) {
    final gaze = sample?.gazeOffsetDeg ?? 0.0;
    final center = Offset(size.width / 2, size.height * 0.44);
    final maxDim = math.min(size.width, size.height);
    final radius = ((gaze / 10.0).clamp(0.0, 1.0)) * maxDim * 0.28;
    final onTarget = gaze <= 2.5;
    final color = onTarget ? SpaceTheme.green : SpaceTheme.dangerRed;

    final paint = Paint()
      ..color = color.withValues(alpha: 0.80)
      ..strokeWidth = 1.3
      ..style = PaintingStyle.stroke;

    canvas.drawCircle(center, 3.5, paint);
    if (radius > 2) {
      canvas.drawCircle(center, radius, paint);
      canvas.drawLine(
        center + Offset(-radius, 0),
        center + Offset(radius, 0),
        paint,
      );
      canvas.drawLine(
        center + Offset(0, -radius),
        center + Offset(0, radius),
        paint,
      );
    }

    _drawLabel(
      canvas,
      Offset(center.dx + 10, center.dy - 18),
      'GAZE ${gaze.toStringAsFixed(2)}°',
      color,
    );
  }

  void _paintVorTarget(Canvas canvas, Size size) {
    final clampedPhase = vorPhase.clamp(-1.0, 1.0);
    final targetX = size.width * (0.50 + 0.16 * clampedPhase);
    final targetY = size.height * 0.28;
    final target = Offset(targetX, targetY);

    final ringPaint = Paint()
      ..color = SpaceTheme.warningYellow.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;
    canvas.drawCircle(target, 11.0, ringPaint);
    canvas.drawCircle(
      target,
      4.5,
      Paint()..color = SpaceTheme.warningYellow,
    );
  }

  void _paintFixationTarget(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.24);
    final paint = Paint()
      ..color = SpaceTheme.warningYellow.withValues(alpha: 0.9)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(center, 11, paint);
    canvas.drawCircle(center, 18, paint);
    canvas.drawCircle(center, 3, Paint()..color = SpaceTheme.warningYellow);
  }

  void _drawLabel(Canvas canvas, Offset pos, String text, Color color) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: 9.5,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.3,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, pos);
  }

  @override
  bool shouldRepaint(covariant ClinicalBiometricHudPainter oldDelegate) {
    return oldDelegate.sample != sample ||
        oldDelegate.showRoiPolygons != showRoiPolygons ||
        oldDelegate.showIpdCalipers != showIpdCalipers ||
        oldDelegate.showGazeVector != showGazeVector ||
        oldDelegate.showVorTarget != showVorTarget ||
        oldDelegate.vorPhase != vorPhase ||
        oldDelegate.showFixationTarget != showFixationTarget;
  }
}

/// `true` cuando el árbol de widgets se ejecuta bajo `flutter_test`.
bool get _isWidgetTestEnvironment =>
    WidgetsBinding.instance.runtimeType.toString().contains('Test');
