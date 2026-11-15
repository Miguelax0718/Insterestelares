import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'apolo_theme.dart';

/// Space Cockpit animated starfield, radial nebulae, and periodic comet streak.
/// Respects `MediaQuery.disableAnimations` and `highContrast` mode.
class ApoloSkyBackground extends StatefulWidget {
  const ApoloSkyBackground({
    super.key,
    required this.highContrast,
    required this.child,
  });

  final bool highContrast;
  final Widget child;

  @override
  State<ApoloSkyBackground> createState() => _ApoloSkyBackgroundState();
}

class _ApoloSkyBackgroundState extends State<ApoloSkyBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<_Star> _stars;
  bool _animationsDisabled = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 16),
    );
    final rng = math.Random(42);
    _stars = List<_Star>.generate(90, (_) {
      return _Star(
        nx: rng.nextDouble(),
        ny: rng.nextDouble(),
        radius: 0.6 + rng.nextDouble() * 1.15,
        phase: rng.nextDouble() * math.pi * 2,
        speed: 0.4 + rng.nextDouble() * 1.1,
      );
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final disabled = MediaQuery.disableAnimationsOf(context);
    if (disabled != _animationsDisabled || widget.highContrast) {
      _animationsDisabled = disabled;
    }
    _syncTicker();
  }

  @override
  void didUpdateWidget(covariant ApoloSkyBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.highContrast != widget.highContrast) {
      _syncTicker();
    }
  }

  void _syncTicker() {
    final shouldAnimate = !_animationsDisabled && !widget.highContrast;
    if (shouldAnimate) {
      if (!_controller.isAnimating) {
        _controller.repeat();
      }
    } else {
      if (_controller.isAnimating) {
        _controller.stop();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = ApoloPalette.of(widget.highContrast);
    final disableAnimations = MediaQuery.disableAnimationsOf(context);

    return ColoredBox(
      color: palette.bg,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) {
                  return CustomPaint(
                    painter: _SkyPainter(
                      stars: _stars,
                      progress: (disableAnimations || widget.highContrast)
                          ? 0.0
                          : _controller.value,
                      animate: !disableAnimations && !widget.highContrast,
                      highContrast: widget.highContrast,
                    ),
                  );
                },
              ),
            ),
          ),
          widget.child,
        ],
      ),
    );
  }
}

class _Star {
  const _Star({
    required this.nx,
    required this.ny,
    required this.radius,
    required this.phase,
    required this.speed,
  });

  final double nx;
  final double ny;
  final double radius;
  final double phase;
  final double speed;
}

class _SkyPainter extends CustomPainter {
  const _SkyPainter({
    required this.stars,
    required this.progress,
    required this.animate,
    required this.highContrast,
  });

  final List<_Star> stars;
  final double progress;
  final bool animate;
  final bool highContrast;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    if (!highContrast) {
      // Nebula 1: radial-gradient(1200px 700px at 78% 70%, #25205A55, transparent 60%)
      final n1Center = Offset(size.width * 0.78, size.height * 0.70);
      final n1Radius = math.max(size.width, size.height) * 0.65;
      final n1Paint = Paint()
        ..shader = RadialGradient(
          colors: const [Color(0x5525205A), Color(0x0025205A)],
          stops: const [0.0, 1.0],
        ).createShader(Rect.fromCircle(center: n1Center, radius: n1Radius));
      canvas.drawRect(Offset.zero & size, n1Paint);

      // Nebula 2: radial-gradient(900px 600px at 15% 20%, #12306055, transparent 60%)
      final n2Center = Offset(size.width * 0.15, size.height * 0.20);
      final n2Radius = math.max(size.width, size.height) * 0.55;
      final n2Paint = Paint()
        ..shader = RadialGradient(
          colors: const [Color(0x55123060), Color(0x00123060)],
          stops: const [0.0, 1.0],
        ).createShader(Rect.fromCircle(center: n2Center, radius: n2Radius));
      canvas.drawRect(Offset.zero & size, n2Paint);
    }

    final starPaint = Paint()..style = PaintingStyle.fill;
    final t = progress * 16.0;
    for (final s in stars) {
      final alpha = highContrast
          ? 0.5
          : (!animate
                ? 0.55
                : (0.25 +
                      0.45 * (0.5 + 0.5 * math.sin(s.phase + t * s.speed))));
      starPaint.color = const Color(0xFFF0FFF1).withValues(alpha: alpha);
      canvas.drawCircle(
        Offset(s.nx * size.width, s.ny * size.height),
        s.radius,
        starPaint,
      );
    }

    // Periodic comet streak during the first 12% of the 16s cycle.
    if (animate && progress < 0.12) {
      final p = progress / 0.12;
      final opacity = p < 0.15 ? (p / 0.15) * 0.8 : (1.0 - p) * 0.85;
      final startX = -150.0 + (size.width + 320.0) * p;
      final startY = size.height * 0.28 - 140.0 * p;
      final endX = startX + 135.0;
      final endY = startY - 28.0;

      final cometPaint = Paint()
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round
        ..shader =
            LinearGradient(
              colors: [
                const Color(0x00F0FFF1),
                Color(0xFFF0FFF1).withValues(alpha: opacity.clamp(0.0, 1.0)),
              ],
            ).createShader(
              Rect.fromPoints(Offset(startX, startY), Offset(endX, endY)),
            );

      canvas.drawLine(Offset(startX, startY), Offset(endX, endY), cometPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _SkyPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.animate != animate ||
        oldDelegate.highContrast != highContrast;
  }
}
