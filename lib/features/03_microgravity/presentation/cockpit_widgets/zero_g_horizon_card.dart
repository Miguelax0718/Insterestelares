import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../agent/graybiel_engine.dart';
import 'cockpit_card.dart';

class ZeroGHorizonCard extends StatefulWidget {
  const ZeroGHorizonCard({super.key, required this.onSubmit, required this.onDismiss});
  final CockpitSubmit onSubmit;
  final VoidCallback onDismiss;
  @override
  State<ZeroGHorizonCard> createState() => _ZeroGHorizonCardState();
}

class _ZeroGHorizonCardState extends State<ZeroGHorizonCard> with SingleTickerProviderStateMixin {
  late final AnimationController _ring = AnimationController(
    vsync: this, duration: const Duration(seconds: 12));
  final _axes = <double>[12, -15, 10];
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _ring.stop();
    } else {
      _ring.repeat();
    }
  }
  @override
  void dispose() { _ring.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    final score = ZeroGHorizonScorer.evaluate(pitch: _axes[0], roll: _axes[1], yaw: _axes[2]);
    return CockpitCard(title: 'Zero-G Horizon', onDismiss: widget.onDismiss,
      status: score.driftRating, children: [
        const Text('Drag the ring or adjust Pitch, Roll and Yaw to align both reticles. Stop if unwell.'),
        GestureDetector(
          onPanUpdate: (d) => setState(() {
            _axes[0] = (_axes[0] + d.delta.dy / 3).clamp(-30, 30);
            _axes[1] = (_axes[1] + d.delta.dx / 3).clamp(-30, 30);
          }),
          child: SizedBox(height: 160, child: AnimatedBuilder(animation: _ring,
            builder: (_, _) => CustomPaint(painter: ZeroGHorizonPainter(
              pitch: _axes[0], roll: _axes[1], yaw: _axes[2], phase: _ring.value * math.pi * 2)))),
        ),
        Text('Alignment ${score.alignmentPct.toStringAsFixed(0)}% • RMS ${score.rmsErrorDeg.toStringAsFixed(1)}°'),
        for (var i = 0; i < 3; i++) Row(children: [
          SizedBox(width: 48, child: Text(['Pitch', 'Roll', 'Yaw'][i])),
          Expanded(child: Slider(value: _axes[i], min: -30, max: 30,
            label: '${_axes[i].toStringAsFixed(0)}°',
            onChanged: (v) => setState(() => _axes[i] = v))),
          IconButton(tooltip: 'Center ${['Pitch', 'Roll', 'Yaw'][i]}',
            onPressed: () => setState(() => _axes[i] = 0), icon: const Icon(Icons.center_focus_strong)),
        ]),
        FilledButton(onPressed: () => widget.onSubmit({'completed': true,
          'rms_error_deg': score.rmsErrorDeg, 'alignment_pct': score.alignmentPct}),
          child: const Text('Complete Alignment')),
      ]);
  }
}

/// Perspective-projected three-axis docking rings, adapted without sensor plugins.
class ZeroGHorizonPainter extends CustomPainter {
  ZeroGHorizonPainter({required this.pitch, required this.roll, required this.yaw, required this.phase});
  final double pitch, roll, yaw, phase;
  @override
  void paint(Canvas canvas, Size size) {
    const p = ApoloPalette.standard;
    canvas.clipRect(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, Paint()..color = p.bg);
    final center = size.center(Offset.zero);
    final radius = math.min(size.width, size.height) * .38;
    for (var i = 0; i < 48; i++) {
      final theta = i * 2.4 - phase;
      final r = (i * 29 % 100) / 100 * size.longestSide * .55;
      canvas.drawCircle(center + Offset(math.cos(theta) * r, math.sin(theta) * r),
        1, Paint()..color = p.text2);
    }
    void ring(double x, double y, double z, Color color) {
      final transform = Matrix4.identity()
        ..rotateX(x * math.pi / 180)..rotateY(y * math.pi / 180)..rotateZ(z * math.pi / 180);
      final m = transform.storage;
      final points = <Offset>[];
      for (var i = 0; i < 32; i++) {
        final a = i * math.pi / 16;
        final vx = math.cos(a), vy = math.sin(a);
        final perspective = 3.2 / (3.2 - m[2] * vx - m[6] * vy);
        points.add(center + Offset(m[0] * vx + m[4] * vy, m[1] * vx + m[5] * vy) * radius * perspective);
      }
      canvas.drawPath(Path()..addPolygon(points, true),
        Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 2);
      canvas.drawCircle(points[24], 4, Paint()..color = color);
      canvas.drawLine(points[0], points[16], Paint()..color = color);
      canvas.drawLine(points[8], points[24], Paint()..color = color);
    }
    ring(0, 0, phase * 180 / math.pi, p.lav);
    ring(pitch, yaw, roll + phase * 180 / math.pi, p.ok);
  }
  @override
  bool shouldRepaint(covariant ZeroGHorizonPainter old) =>
    pitch != old.pitch || roll != old.roll || yaw != old.yaw || phase != old.phase;
}
