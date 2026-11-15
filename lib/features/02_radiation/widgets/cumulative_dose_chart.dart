import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../providers/career_dose_calculator.dart';
import '../providers/dose_history.dart';

/// Offline chart using Flutter drawing primitives and an accessible summary.
class CumulativeDoseChart extends StatelessWidget {
  const CumulativeDoseChart({super.key, required this.points});

  final List<DoseHistoryPoint> points;

  @override
  Widget build(BuildContext context) {
    final last = points.last;
    final missionDose = last.careerDoseMsv - points.first.careerDoseMsv;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Cumulative effective dose',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Day ${last.missionDay}: '
              '${last.careerDoseMsv.toStringAsFixed(1)} mSv career total',
            ),
            Text(
              '${missionDose.toStringAsFixed(1)} mSv added during this mission',
            ),
            const SizedBox(height: 12),
            Semantics(
              label:
                  'Career dose from '
                  '${points.first.careerDoseMsv.toStringAsFixed(1)} mSv before flight '
                  'to ${last.careerDoseMsv.toStringAsFixed(1)} mSv on day '
                  '${last.missionDay}. Reference: 600 mSv.',
              image: true,
              child: SizedBox(
                height: 220,
                width: double.infinity,
                child: CustomPaint(
                  painter: _DoseChartPainter(
                    points,
                    Theme.of(context).colorScheme.primary,
                    Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
            ),
            const Text(
              'Solid line: career dose, including prior missions.\n'
              'Dashed line: 600 mSv reference. Day 0: before flight.\n'
              'Only data through the selected day are shown.',
            ),
          ],
        ),
      ),
    );
  }
}

class _DoseChartPainter extends CustomPainter {
  _DoseChartPainter(this.points, this.lineColor, this.textColor);

  final List<DoseHistoryPoint> points;
  final Color lineColor;
  final Color textColor;

  @override
  void paint(Canvas canvas, Size size) {
    final plot = Rect.fromLTRB(48, 24, size.width - 12, size.height - 32);
    if (plot.width <= 0 || plot.height <= 0) return;
    final topDose = math.max(
      careerDoseLimitMsv * 1.1,
      points.last.careerDoseMsv * 1.1,
    );
    final endDay = points.last.missionDay.toDouble();
    double x(int day) => plot.left + plot.width * day / endDay;
    double y(double dose) => plot.bottom - plot.height * dose / topDose;
    void label(String value, Offset offset) {
      final painter = TextPainter(
        text: TextSpan(
          text: value,
          style: TextStyle(fontSize: 11, color: textColor),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      painter.paint(canvas, offset);
    }

    final grid = Paint()..color = textColor.withValues(alpha: 0.2);
    for (final dose in [0.0, topDose / 2, topDose]) {
      canvas.drawLine(
        Offset(plot.left, y(dose)),
        Offset(plot.right, y(dose)),
        grid,
      );
      label(dose.toStringAsFixed(0), Offset(0, y(dose) - 6));
    }
    label('mSv', const Offset(0, 2));
    label('0', Offset(plot.left, plot.bottom + 8));
    label(
      'Day ${points.last.missionDay}',
      Offset(math.max(plot.left + 20, plot.right - 52), plot.bottom + 8),
    );
    final reference = Paint()
      ..color = Colors.amber
      ..strokeWidth = 1.5;
    for (var left = plot.left; left < plot.right; left += 10) {
      canvas.drawLine(
        Offset(left, y(careerDoseLimitMsv)),
        Offset(math.min(left + 5, plot.right), y(careerDoseLimitMsv)),
        reference,
      );
    }
    final path = Path()
      ..moveTo(x(points.first.missionDay), y(points.first.careerDoseMsv));
    for (final point in points.skip(1)) {
      path.lineTo(x(point.missionDay), y(point.careerDoseMsv));
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = lineColor
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke,
    );
    canvas.drawCircle(
      Offset(x(points.last.missionDay), y(points.last.careerDoseMsv)),
      4,
      Paint()..color = lineColor,
    );
  }

  @override
  bool shouldRepaint(covariant _DoseChartPainter oldDelegate) =>
      oldDelegate.points != points ||
      oldDelegate.lineColor != lineColor ||
      oldDelegate.textColor != textColor;
}
