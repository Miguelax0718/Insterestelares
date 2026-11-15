import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/space_theme.dart';
import 'biomarker_panel.dart';

/// Gráfica de UN biomarcador a lo largo de la misión, pensada para leerse
/// sin conocimientos médicos:
///
/// - Fondo de colores: verde = normal, amarillo = vigilar, rojo = alerta,
///   según la dirección que es mala para ese marcador.
/// - Cada punto se pinta con el color de su zona.
/// - Líneas marcadas: "Tormenta solar" y el día que se está mirando.
/// - Debajo, una frase con la lectura del día ("Día 96: +32 % · Vigilar").
/// - Al tocar un punto se ve el día, el cambio y su nivel.
class BiomarkerTrendChart extends StatelessWidget {
  const BiomarkerTrendChart({
    super.key,
    required this.title,
    required this.meaning,
    required this.spots,
    required this.lowerIsWorse,
    required this.missionDays,
    required this.selectedDay,
    this.solarEventDay,
  });

  /// Nombre del marcador y para qué sirve, p. ej. "Linfocitos · defensas".
  final String title;

  /// Qué significa que suba o baje, en lenguaje sencillo.
  final String meaning;

  /// Puntos (día de misión, % de cambio vs. la línea base).
  final List<FlSpot> spots;

  /// true si BAJAR es lo malo (linfocitos, neutrófilos).
  final bool lowerIsWorse;

  final int missionDays;
  final int selectedDay;
  final int? solarEventDay;

  static const double _minAxis = -100;
  static const double _maxAxis = 150;

  /// Nivel del semáforo de un cambio en % para este marcador.
  BioLevel levelOf(double pct) =>
      BioLevel.of((lowerIsWorse ? -pct : pct) / 100);

  /// Último punto tomado hasta [selectedDay], o null si aún no hay muestras.
  FlSpot? get latestUpToSelected {
    FlSpot? best;
    for (final s in spots) {
      if (s.x <= selectedDay && (best == null || s.x > best.x)) best = s;
    }
    return best;
  }

  static String pct(double v) => '${v >= 0 ? '+' : ''}${v.toStringAsFixed(0)} %';

  @override
  Widget build(BuildContext context) {
    final ys = spots.map((s) => s.y);
    final dataMin = ys.isEmpty ? 0.0 : ys.reduce(math.min);
    final dataMax = ys.isEmpty ? 0.0 : ys.reduce(math.max);
    // Rango que siempre muestra las tres zonas y algo de margen.
    final minY = (math.min(-40.0, dataMin - 10) / 20).floor() * 20.0;
    final maxY = (math.max(40.0, dataMax + 10) / 20).ceil() * 20.0;
    final lo = minY.clamp(_minAxis, 0.0);
    final hi = maxY.clamp(0.0, _maxAxis);
    final yInterval = math.max(20.0, ((hi - lo) / 4 / 20).ceil() * 20.0);

    final watch = BioLevel.watchFrom * 100;
    final alert = BioLevel.alertFrom * 100;
    final zones = lowerIsWorse
        ? [
            (lo, -alert, SpaceTheme.dangerRed),
            (-alert, -watch, SpaceTheme.warningYellow),
            (-watch, hi, SpaceTheme.green),
          ]
        : [
            (lo, watch, SpaceTheme.green),
            (watch, alert, SpaceTheme.warningYellow),
            (alert, hi, SpaceTheme.dangerRed),
          ];

    final latest = latestUpToSelected;
    final latestLevel = latest == null ? null : levelOf(latest.y);
    const axisStyle = TextStyle(fontSize: 10, color: Colors.white54);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        Text(meaning, style: const TextStyle(color: Colors.white54, fontSize: 12)),
        const SizedBox(height: 8),
        SizedBox(
          height: 190,
          child: LineChart(
            LineChartData(
              minX: 0,
              maxX: (missionDays + 1).toDouble(),
              minY: lo,
              maxY: hi,
              clipData: const FlClipData.all(),
              rangeAnnotations: RangeAnnotations(
                horizontalRangeAnnotations: [
                  for (final (y1, y2, color) in zones)
                    if (y2 > y1)
                      HorizontalRangeAnnotation(
                        y1: y1,
                        y2: y2,
                        color: color.withValues(alpha: 0.10),
                      ),
                ],
              ),
              gridData: FlGridData(
                drawVerticalLine: false,
                horizontalInterval: yInterval,
                getDrawingHorizontalLine: (_) =>
                    const FlLine(color: Colors.white10, strokeWidth: 1),
              ),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: AxisTitles(
                  axisNameWidget: const Text('% vs. tu normal', style: axisStyle),
                  axisNameSize: 16,
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 44,
                    interval: yInterval,
                    getTitlesWidget: (v, meta) => Text(
                      v == 0 ? 'normal' : pct(v),
                      style: axisStyle,
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  axisNameWidget: const Text('Día de misión', style: axisStyle),
                  axisNameSize: 16,
                  sideTitles: SideTitles(
                    showTitles: true,
                    interval: 30,
                    getTitlesWidget: (v, meta) => v % 30 == 0
                        ? Text('${v.toInt()}', style: axisStyle)
                        : const SizedBox.shrink(),
                  ),
                ),
              ),
              extraLinesData: ExtraLinesData(
                horizontalLines: [
                  HorizontalLine(y: 0, color: Colors.white38, strokeWidth: 1),
                ],
                verticalLines: [
                  if (solarEventDay != null)
                    VerticalLine(
                      x: solarEventDay!.toDouble(),
                      color: SpaceTheme.warningYellow,
                      strokeWidth: 1.5,
                      dashArray: [6, 4],
                      label: VerticalLineLabel(
                        show: true,
                        alignment: Alignment.topLeft,
                        style: const TextStyle(
                            color: SpaceTheme.warningYellow, fontSize: 10),
                        labelResolver: (_) => 'Tormenta solar',
                      ),
                    ),
                  VerticalLine(
                    x: selectedDay.toDouble(),
                    color: Colors.white70,
                    strokeWidth: 1,
                    label: VerticalLineLabel(
                      show: true,
                      alignment: Alignment.bottomRight,
                      style: const TextStyle(color: Colors.white70, fontSize: 10),
                      labelResolver: (_) => 'Día $selectedDay',
                    ),
                  ),
                ],
              ),
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipColor: (_) => SpaceTheme.surface,
                  fitInsideHorizontally: true,
                  fitInsideVertically: true,
                  getTooltipItems: (touched) => [
                    for (final t in touched)
                      LineTooltipItem(
                        'Día ${t.x.toInt()}\n${pct(t.y)} · ${levelOf(t.y).label}',
                        TextStyle(color: levelOf(t.y).color, fontSize: 12),
                      ),
                  ],
                ),
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  color: Colors.white54,
                  barWidth: 1.5,
                  dotData: FlDotData(
                    getDotPainter: (spot, _, __, ___) => FlDotCirclePainter(
                      radius: 3.5,
                      color: levelOf(spot.y).color,
                      strokeWidth: 1,
                      strokeColor: SpaceTheme.background,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          latest == null
              ? 'Día $selectedDay: aún no hay muestras.'
              : 'Día $selectedDay (muestra del día ${latest.x.toInt()}): '
                  '${pct(latest.y)} vs. tu normal · ${latestLevel!.label}',
          key: Key('trendReading_$title'),
          style: TextStyle(
            color: latestLevel?.color ?? Colors.white54,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}
