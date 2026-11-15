import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../../../core/theme/space_theme.dart';

/// Pintor 3D con proyección en perspectiva (`Matrix4`) para el minijuego
/// "Zero-G Horizon" de habituación sensoriomotora en 3 ejes (Roll, Pitch, Yaw).
///
/// Crea un conflicto visual-vestibular controlado:
/// - El campo estelar de fondo rota en dirección OPUESTA al anillo de acoplamiento.
/// - El anillo de acoplamiento 3D rota en Roll (Z), Pitch (X) y Yaw (Y).
/// - El astronauta alinea la retícula de su nave en los 3 ejes.
class ZeroGHorizonPainter extends CustomPainter {
  final double targetRollDeg;
  final double targetPitchDeg;
  final double targetYawDeg;

  final double userRollDeg;
  final double userPitchDeg;
  final double userYawDeg;

  final double starfieldPhaseRad;
  final double alignmentAccuracyPercent;

  ZeroGHorizonPainter({
    required this.targetRollDeg,
    required this.targetPitchDeg,
    required this.targetYawDeg,
    required this.userRollDeg,
    required this.userPitchDeg,
    required this.userYawDeg,
    required this.starfieldPhaseRad,
    required this.alignmentAccuracyPercent,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) * 0.36;

    // 1. Fondo profundo de cabina espacial
    final bgPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          const Color(0xFF0F1B2D),
          SpaceTheme.background,
        ],
        radius: 0.95,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    // 2. Campo estelar en contra-rotación (conflicto visual-vestibular controlado)
    _paintCounterRotatingStarfield(canvas, size, center);

    // 3. Anillo de acoplamiento objetivo en 3D usando Matrix4 (Pitch, Yaw, Roll)
    final bool isAligned = alignmentAccuracyPercent >= 70.0;
    final Color ringColor =
        isAligned ? SpaceTheme.green : SpaceTheme.warningYellow;

    _paintProjected3DRing(
      canvas: canvas,
      center: center,
      scale: radius,
      rollDeg: targetRollDeg,
      pitchDeg: targetPitchDeg,
      yawDeg: targetYawDeg,
      color: ringColor,
      strokeWidth: 3.0,
      isTarget: true,
    );

    // 4. Retícula 3D de actitud de la nave del astronauta
    _paintProjected3DRing(
      canvas: canvas,
      center: center,
      scale: radius * 0.88,
      rollDeg: userRollDeg,
      pitchDeg: userPitchDeg,
      yawDeg: userYawDeg,
      color: SpaceTheme.cyan,
      strokeWidth: 2.2,
      isTarget: false,
    );

    // 5. Indicador central de vector de acoplamiento
    final double yawDeltaPx = (userYawDeg - targetYawDeg) * 1.8;
    final double pitchDeltaPx = (userPitchDeg - targetPitchDeg) * 1.8;
    final Offset vectorPos =
        center + Offset(yawDeltaPx, pitchDeltaPx);

    final hudLinePaint = Paint()
      ..color = Colors.white24
      ..strokeWidth = 1.0;
    canvas.drawLine(
      Offset(center.dx - 24, center.dy),
      Offset(center.dx + 24, center.dy),
      hudLinePaint,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy - 24),
      Offset(center.dx, center.dy + 24),
      hudLinePaint,
    );

    final vectorPaint = Paint()
      ..color = isAligned ? SpaceTheme.green : SpaceTheme.dangerRed
      ..style = PaintingStyle.fill;
    canvas.drawCircle(vectorPos, 5.5, vectorPaint);
  }

  void _paintCounterRotatingStarfield(
    Canvas canvas,
    Size size,
    Offset center,
  ) {
    final starPaint = Paint()..style = PaintingStyle.fill;
    // Contra-rotación opuesta al movimiento del objetivo para inducir discordancia controlada
    final double counterRollRad =
        -(targetRollDeg * math.pi / 180.0) - starfieldPhaseRad;
    final double counterYawShift = -targetYawDeg * 2.2;
    final double counterPitchShift = -targetPitchDeg * 2.2;

    const int starCount = 48;
    for (int i = 0; i < starCount; i++) {
      final seedAngle = (i * 137.5) * math.pi / 180.0 + counterRollRad;
      final normDist = ((i * 29) % 100) / 100.0;
      final radial = normDist * math.max(size.width, size.height) * 0.55;

      final dx = center.dx +
          radial * math.cos(seedAngle) +
          counterYawShift * (0.3 + normDist);
      final dy = center.dy +
          radial * math.sin(seedAngle) +
          counterPitchShift * (0.3 + normDist);

      if (dx >= 0 && dx <= size.width && dy >= 0 && dy <= size.height) {
        final alpha = (100 + (i % 4) * 38).clamp(0, 255);
        starPaint.color = Color.fromARGB(alpha, 200, 230, 255);
        final starRadius = (i % 3 == 0) ? 2.0 : 1.2;
        canvas.drawCircle(Offset(dx, dy), starRadius, starPaint);
      }
    }
  }

  void _paintProjected3DRing({
    required Canvas canvas,
    required Offset center,
    required double scale,
    required double rollDeg,
    required double pitchDeg,
    required double yawDeg,
    required Color color,
    required double strokeWidth,
    required bool isTarget,
  }) {
    final double rollRad = rollDeg * math.pi / 180.0;
    final double pitchRad = pitchDeg * math.pi / 180.0;
    final double yawRad = yawDeg * math.pi / 180.0;

    // Matriz de transformación 3D usando Matrix4 (Pitch X, Yaw Y, Roll Z)
    final Matrix4 transform = Matrix4.identity()
      ..rotateX(pitchRad)
      ..rotateY(yawRad)
      ..rotateZ(rollRad);

    const int segments = 16;
    final List<Offset> projectedPoints = [];
    const double cameraDistance = 3.2;

    for (int i = 0; i < segments; i++) {
      final theta = (2 * math.pi * i) / segments;
      final localX = math.cos(theta);
      final localY = math.sin(theta);

      final storage = transform.storage;
      // Multiplicación de punto (localX, localY, 0, 1) por Matrix4 column-major
      final rx = storage[0] * localX + storage[4] * localY + storage[12];
      final ry = storage[1] * localX + storage[5] * localY + storage[13];
      final rz = storage[2] * localX + storage[6] * localY + storage[14];

      final perspective = cameraDistance / (cameraDistance - rz).clamp(1.2, 6.0);
      final screenX = center.dx + rx * scale * perspective;
      final screenY = center.dy + ry * scale * perspective;
      projectedPoints.add(Offset(screenX, screenY));
    }

    final ringPath = Path()..moveTo(projectedPoints[0].dx, projectedPoints[0].dy);
    for (int i = 1; i < projectedPoints.length; i++) {
      ringPath.lineTo(projectedPoints[i].dx, projectedPoints[i].dy);
    }
    ringPath.close();

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawPath(ringPath, paint);

    // Marcadores de referencia superior (Roll 0°) y ejes laterales
    if (projectedPoints.length >= 12) {
      final topMarker = projectedPoints[12]; // -90° (arriba en coordenadas de pantalla)
      final markerPaint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;
      canvas.drawCircle(topMarker, isTarget ? 5.0 : 4.0, markerPaint);

      // Ejes de referencia internos
      final axisPaint = Paint()
        ..color = color.withValues(alpha: 0.45)
        ..strokeWidth = 1.3;
      canvas.drawLine(projectedPoints[0], projectedPoints[8], axisPaint);
      canvas.drawLine(projectedPoints[4], projectedPoints[12], axisPaint);
    }
  }

  @override
  bool shouldRepaint(covariant ZeroGHorizonPainter oldDelegate) {
    return oldDelegate.targetRollDeg != targetRollDeg ||
        oldDelegate.targetPitchDeg != targetPitchDeg ||
        oldDelegate.targetYawDeg != targetYawDeg ||
        oldDelegate.userRollDeg != userRollDeg ||
        oldDelegate.userPitchDeg != userPitchDeg ||
        oldDelegate.userYawDeg != userYawDeg ||
        oldDelegate.starfieldPhaseRad != starfieldPhaseRad;
  }
}
