import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/sample_data.dart';
import '../theme/space_theme.dart';

/// Una línea de la gráfica de tendencia.
class TrendSeries {
  const TrendSeries(this.label, this.color, this.spots);
  final String label;
  final Color color;

  /// Puntos (día de misión, valor).
  final List<FlSpot> spots;
}

/// Línea horizontal de referencia (umbral o meta).
class TrendReference {
  const TrendReference(this.value, this.label, this.color);
  final double value;
  final String label;
  final Color color;
}

/// Tarjeta con la tendencia de un indicador a lo largo de la misión, leída de
/// las muestras de `DB/samples/`. Incluye el selector Realista / Extremo.
class MissionTrendCard extends ConsumerWidget {
  const MissionTrendCard({
    super.key,
    required this.icon,
    required this.title,
    required this.data,
    required this.builder,
  });

  final IconData icon;
  final String title;

  /// Estado de carga de la muestra (AsyncValue de un FutureProvider).
  final AsyncValue<Object?> data;

  /// Contenido cuando la muestra ya cargó.
  final WidgetBuilder builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scenario = ref.watch(sampleScenarioProvider);
    return Card(
      color: SpaceTheme.card,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 8,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, color: SpaceTheme.cyan),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ],
                ),
                SegmentedButton<SampleScenario>(
                  showSelectedIcon: false,
                  style: const ButtonStyle(
                    visualDensity: VisualDensity.compact,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  segments: [
                    for (final s in SampleScenario.values)
                      ButtonSegment(value: s, label: Text(s.label)),
                  ],
                  selected: {scenario},
                  onSelectionChanged: (s) =>
                      ref.read(sampleScenarioProvider.notifier).state = s.first,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              scenario == SampleScenario.realistic
                  ? 'Simulación ajustada a datos publicados de astronautas.'
                  : 'Escenario hipotético con emergencias, para probar alertas.',
              style: const TextStyle(color: Colors.white54, fontSize: 11),
            ),
            const SizedBox(height: 12),
            data.when(
              loading: () => const SizedBox(
                height: 120,
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Text(
                'No se pudo leer la muestra local: $e',
                style: const TextStyle(color: SpaceTheme.dangerRed),
              ),
              data: (_) => builder(context),
            ),
          ],
        ),
      ),
    );
  }
}

/// Gráfica de líneas por día de misión, con leyenda y líneas de referencia.
class MissionTrendChart extends StatelessWidget {
  const MissionTrendChart({
    super.key,
    required this.series,
    required this.unit,
    this.references = const [],
    this.decimals = 0,
    this.height = 180,
  });

  final List<TrendSeries> series;
  final String unit;
  final List<TrendReference> references;
  final int decimals;
  final double height;

  @override
  Widget build(BuildContext context) {
    final all = [for (final s in series) ...s.spots];
    if (all.isEmpty) {
      return const Text(
        'Sin datos de muestra para este astronauta.',
        style: TextStyle(color: Colors.white54),
      );
    }
    final ys = [
      ...all.map((s) => s.y),
      ...references.map((r) => r.value),
    ];
    final lo = ys.reduce(math.min);
    final hi = ys.reduce(math.max);
    final pad = math.max((hi - lo) * 0.12, 0.5);
    final minX = all.map((s) => s.x).reduce(math.min);
    final maxX = all.map((s) => s.x).reduce(math.max);
    const axis = TextStyle(fontSize: 10, color: Colors.white54);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: height,
          child: LineChart(
            LineChartData(
              minX: minX,
              maxX: maxX,
              minY: lo - pad,
              maxY: hi + pad,
              clipData: const FlClipData.all(),
              gridData: FlGridData(
                drawVerticalLine: false,
                getDrawingHorizontalLine: (_) =>
                    const FlLine(color: Colors.white10, strokeWidth: 1),
              ),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(),
                rightTitles: const AxisTitles(),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 40,
                    getTitlesWidget: (v, meta) => v == meta.min || v == meta.max
                        ? const SizedBox.shrink()
                        : Text(v.toStringAsFixed(decimals), style: axis),
                  ),
                ),
                bottomTitles: AxisTitles(
                  axisNameWidget: const Text('Día de misión', style: axis),
                  axisNameSize: 16,
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 20,
                    interval: 30,
                    getTitlesWidget: (v, meta) => v % 30 == 0
                        ? Text(v.toInt().toString(), style: axis)
                        : const SizedBox.shrink(),
                  ),
                ),
              ),
              extraLinesData: ExtraLinesData(
                horizontalLines: [
                  for (final r in references)
                    HorizontalLine(
                      y: r.value,
                      color: r.color.withValues(alpha: 0.7),
                      strokeWidth: 1,
                      dashArray: const [6, 4],
                    ),
                ],
              ),
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipItems: (spots) => [
                    for (final s in spots)
                      LineTooltipItem(
                        'Día ${s.x.toInt()}: '
                        '${s.y.toStringAsFixed(decimals)} $unit',
                        TextStyle(color: s.bar.color, fontSize: 11),
                      ),
                  ],
                ),
              ),
              lineBarsData: [
                for (final s in series)
                  LineChartBarData(
                    spots: s.spots,
                    color: s.color,
                    barWidth: 1.6,
                    dotData: FlDotData(show: s.spots.length <= 12),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 4,
          children: [
            for (final s in series) _legend(s.color, s.label),
            for (final r in references) _legend(r.color, r.label, dashed: true),
          ],
        ),
      ],
    );
  }

  Widget _legend(Color color, String label, {bool dashed = false}) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: dashed ? 12 : 10,
            height: dashed ? 2 : 10,
            decoration: BoxDecoration(
              color: color,
              shape: dashed ? BoxShape.rectangle : BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              style: const TextStyle(fontSize: 11, color: Colors.white70),
            ),
          ),
        ],
      );
}

/// Dato resumido bajo la gráfica ("Media en vuelo: 6,1 h").
class TrendStat extends StatelessWidget {
  const TrendStat(this.label, this.value, {super.key, this.color});
  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color ?? Colors.white,
            ),
          ),
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.white54)),
        ],
      );
}
