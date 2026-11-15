import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../domain/apolo_models.dart';

/// Faithful Flutter `CustomPainter` port of `dogSVG()` from `web/apolo/js/dog.js`.
///
/// Supports helmet glass reflection (hidden in high-contrast mode), gentle
/// bobbing float, periodic blink, pointer pupil look-tracking (`lookOffset`),
/// ear perk when `isListening`, animated talking mouth when `isSpeaking`,
/// mood expressions (`ok`, `warn`, `crit` with sweat drop), and tap wiggle.
class ApoloDogWidget extends StatefulWidget {
  const ApoloDogWidget({
    super.key,
    required this.severity,
    this.isListening = false,
    this.isSpeaking = false,
    this.highContrast = false,
    this.lookOffset = Offset.zero,
    this.size = 220,
    this.onTap,
  });

  final ApoloSeverity severity;
  final bool isListening;
  final bool isSpeaking;
  final bool highContrast;
  final Offset lookOffset;
  final double size;
  final VoidCallback? onTap;

  @override
  State<ApoloDogWidget> createState() => _ApoloDogWidgetState();
}

class _ApoloDogWidgetState extends State<ApoloDogWidget>
    with TickerProviderStateMixin {
  late final AnimationController _ambientController;
  late final AnimationController _talkController;
  late final AnimationController _wiggleController;
  late final AnimationController _blinkController;
  Timer? _blinkTimer;
  bool _animationsDisabled = false;

  @override
  void initState() {
    super.initState();
    _ambientController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 5500),
    );
    _talkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _wiggleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 160),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _animationsDisabled = MediaQuery.disableAnimationsOf(context);
    _syncAnimations();
  }

  @override
  void didUpdateWidget(covariant ApoloDogWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isSpeaking != widget.isSpeaking) {
      _syncAnimations();
    }
  }

  void _syncAnimations() {
    if (_animationsDisabled) {
      _ambientController.stop();
      _talkController.stop();
      _blinkController.stop();
      _blinkTimer?.cancel();
      _blinkTimer = null;
      return;
    }
    if (!_ambientController.isAnimating) {
      _ambientController.repeat();
    }
    if (widget.isSpeaking) {
      if (!_talkController.isAnimating) {
        _talkController.repeat(reverse: true);
      }
    } else {
      if (_talkController.isAnimating) {
        _talkController.stop();
        _talkController.value = 0.0;
      }
    }
    _scheduleNextBlink();
  }

  void _scheduleNextBlink() {
    if (_animationsDisabled || _blinkTimer != null) return;
    _blinkTimer = Timer(const Duration(milliseconds: 3400), () async {
      _blinkTimer = null;
      if (!mounted || _animationsDisabled) return;
      try {
        await _blinkController.forward();
        if (mounted) {
          await _blinkController.reverse();
        }
      } catch (_) {
        // Ignore if disposed mid-blink.
      }
      if (mounted && !_animationsDisabled) {
        _scheduleNextBlink();
      }
    });
  }

  void _handleTap() {
    if (!_animationsDisabled) {
      _wiggleController.forward(from: 0.0);
    }
    widget.onTap?.call();
  }

  @override
  void dispose() {
    _blinkTimer?.cancel();
    _ambientController.dispose();
    _talkController.dispose();
    _wiggleController.dispose();
    _blinkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    final shadowWidth = widget.size * 0.64;

    return Semantics(
      button: widget.onTap != null,
      label:
          'Apolo assistant dog, status ${widget.severity.label}${widget.isListening ? ', listening' : ''}${widget.isSpeaking ? ', speaking' : ''}',
      child: GestureDetector(
        onTap: _handleTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedBuilder(
          animation: Listenable.merge([
            _ambientController,
            _talkController,
            _wiggleController,
            _blinkController,
          ]),
          builder: (context, _) {
            final t = disableAnimations ? 0.0 : _ambientController.value;
            final bobWave = disableAnimations ? 0.0 : math.sin(t * math.pi * 2);
            final bobY = disableAnimations ? 0.0 : -5.0 + bobWave * 5.0;
            final bobRot = disableAnimations ? 0.0 : -0.01 + bobWave * 0.01;
            final scaleWhenSpeaking = widget.isSpeaking ? 0.88 : 1.0;

            final wiggleProgress = _wiggleController.value;
            final wiggleRad =
                disableAnimations || !_wiggleController.isAnimating
                ? 0.0
                : math.sin(wiggleProgress * math.pi * 3) *
                      (1.0 - wiggleProgress) *
                      0.16;

            final blinkScaleY = disableAnimations
                ? 1.0
                : (1.0 - _blinkController.value * 0.88);
            final talkScale = widget.isSpeaking
                ? (disableAnimations
                      ? 0.85
                      : 0.35 + _talkController.value * 0.65)
                : 0.0;

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedScale(
                  scale: scaleWhenSpeaking,
                  duration: disableAnimations
                      ? Duration.zero
                      : const Duration(milliseconds: 450),
                  curve: Curves.easeOutBack,
                  child: Transform.translate(
                    offset: Offset(0, bobY),
                    child: Transform.rotate(
                      angle: bobRot,
                      child: SizedBox(
                        width: widget.size,
                        height: widget.size,
                        child: CustomPaint(
                          painter: _ApoloDogPainter(
                            severity: widget.severity,
                            isListening: widget.isListening,
                            isSpeaking: widget.isSpeaking,
                            highContrast: widget.highContrast,
                            lookOffset: disableAnimations
                                ? Offset.zero
                                : widget.lookOffset,
                            ambientPhase: t,
                            animate: !disableAnimations,
                            blinkScaleY: blinkScaleY,
                            talkScale: talkScale,
                            wiggleAngle: wiggleRad,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Transform.scale(
                  scaleX:
                      (widget.isSpeaking ? 0.8 : 1.0) *
                      (1.0 - (bobWave + 1.0) * 0.08),
                  child: Container(
                    width: shadowWidth,
                    height: 14,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      gradient: RadialGradient(
                        colors: [
                          const Color(0x55A994E0),
                          const Color(0x00A994E0),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ApoloDogPainter extends CustomPainter {
  const _ApoloDogPainter({
    required this.severity,
    required this.isListening,
    required this.isSpeaking,
    required this.highContrast,
    required this.lookOffset,
    required this.ambientPhase,
    required this.animate,
    required this.blinkScaleY,
    required this.talkScale,
    required this.wiggleAngle,
  });

  final ApoloSeverity severity;
  final bool isListening;
  final bool isSpeaking;
  final bool highContrast;
  final Offset lookOffset;
  final double ambientPhase;
  final bool animate;
  final double blinkScaleY;
  final double talkScale;
  final double wiggleAngle;

  static const _fur = Color(0xFFFFF3E0);
  static const _snout = Color(0xFFFFFBF4);
  static const _ear = Color(0xFFE2A36B);
  static const _ear2 = Color(0xFFC9844B);
  static const _patch = Color(0xFFEDBB88);
  static const _ink = Color(0xFF231E33);
  static const _blush = Color(0xFFFF9AA6);
  static const _collar = Color(0xFF8367C7);
  static const _tag = Color(0xFFF0FFF1);

  @override
  void paint(Canvas canvas, Size size) {
    final s = math.min(size.width, size.height) / 220.0;
    canvas.save();
    canvas.translate(
      (size.width - 220.0 * s) / 2,
      (size.height - 220.0 * s) / 2,
    );
    canvas.scale(s, s);

    // 1. Space helmet bubble (hidden in high-contrast mode).
    if (!highContrast) {
      final helmetRect = Rect.fromCircle(
        center: const Offset(110, 110),
        radius: 100,
      );
      final glassPaint = Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.30, -0.44),
          radius: 0.80,
          colors: [Color(0x29F0FFF1), Color(0x0DA994E0), Color(0x24A994E0)],
          stops: [0.0, 0.55, 1.0],
        ).createShader(helmetRect);
      canvas.drawCircle(const Offset(110, 110), 100, glassPaint);

      final helmetStroke = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..color = const Color(0x47F0FFF1);
      canvas.drawCircle(const Offset(110, 110), 100, helmetStroke);
    }

    // 2. Neck / chest base.
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(110, 176), width: 72, height: 36),
      Paint()..color = const Color(0xFFF4E2C6),
    );

    // 3. Collar.
    final collarPath = Path()
      ..moveTo(70, 168)
      ..quadraticBezierTo(110, 194, 150, 168)
      ..lineTo(151, 178)
      ..quadraticBezierTo(110, 204, 69, 178)
      ..close();
    canvas.drawPath(collarPath, Paint()..color = _collar);

    // 4. Swaying collar star tag.
    final tagRot = animate ? math.sin(ambientPhase * math.pi * 4) * 0.09 : 0.0;
    canvas.save();
    canvas.translate(110, 182);
    canvas.rotate(tagRot);
    canvas.translate(-110, -182);
    canvas.drawCircle(const Offset(110, 190), 8, Paint()..color = _tag);
    _drawStar(canvas, const Offset(110, 190), 4.8, 2.1, _collar);
    canvas.restore();

    // 5. Floppy ears.
    final double leftEarAngle;
    final double rightEarAngle;
    if (isListening) {
      leftEarAngle = -12 * math.pi / 180;
      rightEarAngle = 12 * math.pi / 180;
    } else if (severity == ApoloSeverity.crit) {
      leftEarAngle = 14 * math.pi / 180;
      rightEarAngle = -14 * math.pi / 180;
    } else if (animate) {
      final w1 = math.sin(ambientPhase * math.pi * 2 * 1.7) * 0.5 + 0.5;
      final w2 =
          math.sin(ambientPhase * math.pi * 2 * 1.7 + math.pi) * 0.5 + 0.5;
      leftEarAngle = (w1 * 7) * math.pi / 180;
      rightEarAngle = -(w2 * 7) * math.pi / 180;
    } else {
      leftEarAngle = 0;
      rightEarAngle = 0;
    }

    // Left ear
    canvas.save();
    canvas.translate(68, 66);
    canvas.rotate(leftEarAngle);
    canvas.translate(-68, -66);
    final leftEarPath = Path()
      ..moveTo(68, 64)
      ..cubicTo(40, 62, 24, 96, 27, 130)
      ..cubicTo(29, 156, 45, 170, 60, 163)
      ..cubicTo(72, 157, 71, 133, 75, 113)
      ..cubicTo(79, 92, 87, 66, 68, 64)
      ..close();
    canvas.drawPath(leftEarPath, Paint()..color = _ear);
    final leftCrease = Path()
      ..moveTo(64, 76)
      ..cubicTo(50, 80, 42, 104, 43, 126)
      ..cubicTo(44, 139, 49, 148, 56, 148);
    canvas.drawPath(
      leftCrease,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0
        ..strokeCap = StrokeCap.round
        ..color = _ear2.withValues(alpha: 0.5),
    );
    canvas.restore();

    // Right ear
    canvas.save();
    canvas.translate(152, 66);
    canvas.rotate(rightEarAngle);
    canvas.translate(-152, -66);
    final rightEarPath = Path()
      ..moveTo(152, 64)
      ..cubicTo(180, 62, 196, 96, 193, 130)
      ..cubicTo(191, 156, 175, 170, 160, 163)
      ..cubicTo(148, 157, 149, 133, 145, 113)
      ..cubicTo(141, 92, 133, 66, 152, 64)
      ..close();
    canvas.drawPath(rightEarPath, Paint()..color = _ear);
    final rightCrease = Path()
      ..moveTo(156, 76)
      ..cubicTo(170, 80, 178, 104, 177, 126)
      ..cubicTo(176, 139, 171, 148, 164, 148);
    canvas.drawPath(
      rightCrease,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0
        ..strokeCap = StrokeCap.round
        ..color = _ear2.withValues(alpha: 0.5),
    );
    canvas.restore();

    // 6. Head group (tilts on listening, wiggles on tap).
    final headAngle = (isListening ? -7 * math.pi / 180 : 0.0) + wiggleAngle;
    canvas.save();
    canvas.translate(110, 150);
    canvas.rotate(headAngle);
    canvas.translate(-110, -150);

    final headRect = Rect.fromCenter(
      center: const Offset(110, 112),
      width: 126,
      height: 114,
    );
    canvas.drawOval(
      headRect,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.10, -0.30),
          radius: 0.70,
          colors: [Colors.white, _fur],
        ).createShader(headRect),
    );

    // Hair tuft
    final tuft = Path()
      ..moveTo(100, 58)
      ..quadraticBezierTo(105, 47, 111, 57)
      ..quadraticBezierTo(116, 48, 122, 59);
    canvas.drawPath(
      tuft,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0
        ..strokeCap = StrokeCap.round
        ..color = _ear2.withValues(alpha: 0.7),
    );

    // Eye patch
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(136, 100), width: 42, height: 36),
      Paint()..color = _patch.withValues(alpha: 0.85),
    );

    // Eyebrows (only shown on warn / crit)
    if (severity != ApoloSeverity.ok) {
      final isCrit = severity == ApoloSeverity.crit;
      final browPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0
        ..strokeCap = StrokeCap.round
        ..color = _ink;

      // Left brow
      canvas.save();
      canvas.translate(85, isCrit ? 81 : 82);
      canvas.rotate((isCrit ? -16 : -6) * math.pi / 180);
      canvas.translate(-85, -84);
      final bl = Path()
        ..moveTo(76, 86)
        ..quadraticBezierTo(85, 82, 94, 85);
      canvas.drawPath(bl, browPaint);
      canvas.restore();

      // Right brow
      canvas.save();
      canvas.translate(135, isCrit ? 81 : 82);
      canvas.rotate((isCrit ? 16 : 6) * math.pi / 180);
      canvas.translate(-135, -84);
      final br = Path()
        ..moveTo(126, 85)
        ..quadraticBezierTo(135, 82, 144, 86);
      canvas.drawPath(br, browPaint);
      canvas.restore();
    }

    // Eyes + pupil tracking + blink
    final clampedLook = _clampOffset(lookOffset, 3.0);
    _drawEye(
      canvas,
      center: const Offset(86, 104),
      blinkScaleY: blinkScaleY,
      look: clampedLook,
    );
    _drawEye(
      canvas,
      center: const Offset(134, 104),
      blinkScaleY: blinkScaleY,
      look: clampedLook,
    );

    // Rosy cheeks
    final blushPaint = Paint()..color = _blush.withValues(alpha: 0.55);
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(72, 126), width: 18, height: 10),
      blushPaint,
    );
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(148, 126), width: 18, height: 10),
      blushPaint,
    );

    // Snout
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(110, 130), width: 50, height: 36),
      Paint()..color = _snout,
    );

    // Nose
    final nosePath = Path()
      ..moveTo(100, 118)
      ..quadraticBezierTo(110, 113, 120, 118)
      ..quadraticBezierTo(119, 127, 110, 129)
      ..quadraticBezierTo(101, 127, 100, 118)
      ..close();
    canvas.drawPath(nosePath, Paint()..color = _ink);
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(106, 119.5), width: 6, height: 3.2),
      Paint()..color = Colors.white.withValues(alpha: 0.6),
    );

    // Mouth
    if (isSpeaking) {
      canvas.save();
      canvas.translate(110, 132);
      canvas.scale(1.0, talkScale.clamp(0.35, 1.0));
      canvas.translate(-110, -132);
      canvas.drawOval(
        Rect.fromCenter(center: const Offset(110, 139), width: 16, height: 14),
        Paint()..color = const Color(0xFF5B1F2E),
      );
      canvas.drawOval(
        Rect.fromCenter(center: const Offset(110, 143), width: 10, height: 6.8),
        Paint()..color = const Color(0xFFFF7E8A),
      );
      canvas.restore();
    } else {
      switch (severity) {
        case ApoloSeverity.ok:
          final okMouth = Path()
            ..moveTo(98, 136)
            ..quadraticBezierTo(104, 143, 110, 136)
            ..quadraticBezierTo(116, 143, 122, 136);
          canvas.drawPath(
            okMouth,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2.6
              ..strokeCap = StrokeCap.round
              ..strokeJoin = StrokeJoin.round
              ..color = _ink,
          );
        case ApoloSeverity.warn:
          final warnMouth = Path()
            ..moveTo(100, 139)
            ..quadraticBezierTo(110, 141, 120, 139);
          canvas.drawPath(
            warnMouth,
            Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2.6
              ..strokeCap = StrokeCap.round
              ..color = _ink,
          );
        case ApoloSeverity.crit:
          canvas.drawOval(
            Rect.fromCenter(
              center: const Offset(110, 139),
              width: 9,
              height: 10,
            ),
            Paint()..color = _ink,
          );
      }
    }

    // Blue sweat drop on critical state
    if (severity == ApoloSeverity.crit) {
      final dropPhase = animate ? (ambientPhase * 2.3) % 1.0 : 0.35;
      final dropY = -4.0 + dropPhase * 14.0;
      final dropAlpha = animate
          ? (dropPhase < 0.3 ? dropPhase / 0.3 : 1.0 - (dropPhase - 0.3) / 0.7)
          : 0.9;
      canvas.save();
      canvas.translate(0, dropY);
      final sweat = Path()
        ..moveTo(163, 76)
        ..quadraticBezierTo(168, 84, 163, 88)
        ..quadraticBezierTo(158, 84, 163, 76)
        ..close();
      canvas.drawPath(
        sweat,
        Paint()..color = const Color(0xFF9FD8FF).withValues(alpha: dropAlpha),
      );
      canvas.restore();
    }

    canvas.restore(); // end head

    // 7. Helmet reflection arc (hidden in high-contrast mode).
    if (!highContrast) {
      final arc = Path()
        ..moveTo(46, 72)
        ..arcToPoint(
          const Offset(88, 36),
          radius: const Radius.circular(76),
          clockwise: true,
        );
      canvas.drawPath(
        arc,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5.0
          ..strokeCap = StrokeCap.round
          ..color = const Color(0x80F0FFF1),
      );
    }

    canvas.restore();
  }

  void _drawEye(
    Canvas canvas, {
    required Offset center,
    required double blinkScaleY,
    required Offset look,
  }) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(1.0, blinkScaleY.clamp(0.12, 1.0));
    canvas.translate(-center.dx, -center.dy);

    canvas.drawOval(
      Rect.fromCenter(center: center, width: 19, height: 22),
      Paint()..color = _ink,
    );

    canvas.drawCircle(
      center + const Offset(3.0, -4.0) + look,
      3.4,
      Paint()..color = Colors.white,
    );
    canvas.drawCircle(
      center + const Offset(-2.5, 4.0) + look,
      1.5,
      Paint()..color = Colors.white,
    );

    canvas.restore();
  }

  void _drawStar(
    Canvas canvas,
    Offset center,
    double outerR,
    double innerR,
    Color color,
  ) {
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final angle = -math.pi / 2 + i * math.pi / 5;
      final r = i.isEven ? outerR : innerR;
      final x = center.dx + math.cos(angle) * r;
      final y = center.dy + math.sin(angle) * r;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    canvas.drawPath(path, Paint()..color = color);
  }

  Offset _clampOffset(Offset raw, double maxLen) {
    final dist = raw.distance;
    if (dist <= maxLen || dist == 0) return raw;
    return raw / dist * maxLen;
  }

  @override
  bool shouldRepaint(covariant _ApoloDogPainter oldDelegate) {
    return oldDelegate.severity != severity ||
        oldDelegate.isListening != isListening ||
        oldDelegate.isSpeaking != isSpeaking ||
        oldDelegate.highContrast != highContrast ||
        oldDelegate.lookOffset != lookOffset ||
        oldDelegate.ambientPhase != ambientPhase ||
        oldDelegate.animate != animate ||
        oldDelegate.blinkScaleY != blinkScaleY ||
        oldDelegate.talkScale != talkScale ||
        oldDelegate.wiggleAngle != wiggleAngle;
  }
}
