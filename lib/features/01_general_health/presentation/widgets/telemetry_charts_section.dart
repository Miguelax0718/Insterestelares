import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:astramed/core/theme/space_theme.dart';
import 'package:astramed/features/01_general_health/domain/scientific_criteria_engine.dart';
import 'package:astramed/features/01_general_health/domain/telemetry_view_contracts.dart';

enum _TelemetryChartVariable {
  heartRate('Frecuencia cardíaca', 'lpm'),
  respiratoryRate('Frecuencia respiratoria', 'rpm'),
  spO2('SpO₂', '%');

  final String label;
  final String unit;
  const _TelemetryChartVariable(this.label, this.unit);
}

enum _TimeWindowOption {
  oneHour('1 h', Duration(hours: 1)),
  sixHours('6 h', Duration(hours: 6)),
  twentyFourHours('24 h', Duration(hours: 24)),
  sevenDays('7 d', Duration(days: 7));

  final String label;
  final Duration duration;
  const _TimeWindowOption(this.label, this.duration);
}

/// Sección de gráficas obligatorias para FC, FR y SpO₂ usando fl_chart.
///
/// Si no hay telemetría conectada, muestra «Sin datos disponibles» sin
/// generar curvas ficticias ni valores decorativos.
class TelemetryChartsSection extends StatefulWidget {
  final TelemetrySeriesSnapshot snapshot;

  const TelemetryChartsSection({
    super.key,
    required this.snapshot,
  });

  @override
  State<TelemetryChartsSection> createState() => _TelemetryChartsSectionState();
}

class _TelemetryChartsSectionState extends State<TelemetryChartsSection> {
  _TelemetryChartVariable _selectedVariable = _TelemetryChartVariable.heartRate;
  _TimeWindowOption _selectedWindow = _TimeWindowOption.twentyFourHours;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: SpaceTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.show_chart, color: SpaceTheme.cyan, size: 18),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Visualización de Telemetría (FC, FR, SpO₂)',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _TelemetryChartVariable.values.map((variable) {
              final selected = variable == _selectedVariable;
              return ChoiceChip(
                label: Text('${variable.label} (${variable.unit})'),
                selected: selected,
                selectedColor: SpaceTheme.cyan.withValues(alpha: 0.25),
                backgroundColor: SpaceTheme.card,
                labelStyle: TextStyle(
                  fontSize: 11,
                  color: selected ? SpaceTheme.cyan : Colors.white70,
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                ),
                onSelected: (_) => setState(() => _selectedVariable = variable),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text(
                'Intervalo:',
                style: TextStyle(fontSize: 11, color: Colors.white60),
              ),
              const SizedBox(width: 8),
              ..._TimeWindowOption.values.map((window) {
                final selected = window == _selectedWindow;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(window.label),
                    selected: selected,
                    visualDensity: VisualDensity.compact,
                    selectedColor: SpaceTheme.cyan.withValues(alpha: 0.2),
                    backgroundColor: SpaceTheme.card,
                    labelStyle: TextStyle(
                      fontSize: 10,
                      color: selected ? SpaceTheme.cyan : Colors.white60,
                    ),
                    onSelected: (_) => setState(() => _selectedWindow = window),
                  ),
                );
              }),
            ],
          ),
          const SizedBox(height: 12),
          ..._buildChartsForSelectedVariable(),
        ],
      ),
    );
  }

  List<Widget> _buildChartsForSelectedVariable() {
    switch (_selectedVariable) {
      case _TelemetryChartVariable.heartRate:
        final samples = _filterByWindow(widget.snapshot.heartRateSamples);
        return [
          _buildTimeSeriesChartCard(
            title: 'Gráfica 1: Frecuencia cardíaca en tiempo real (lpm)',
            subtitle:
                'Fuente: ECG / PPG compatible • Interrupciones mostradas como brechas sin datos.',
            samples: samples,
            lineColor: Colors.redAccent,
            unit: 'lpm',
            baselineValue: widget.snapshot.individualHrBaselineBpm,
          ),
          const SizedBox(height: 10),
          _buildContextBarChartCard(
            title: 'Gráfica 2: Frecuencia cardíaca por contexto',
            subtitle:
                'Promedios separados por sueño, reposo y actividad física con tamaño de muestra.',
            samples: samples,
            unit: 'lpm',
            barColor: Colors.redAccent,
          ),
          const SizedBox(height: 10),
          _buildLongitudinalRestVsSleepCard(
            title: 'Gráfica 3: Tendencia longitudinal (Reposo vs. Sueño)',
            subtitle:
                'Series separadas sin mezclar contextos; incluye basal individual cuando existe.',
            samples: samples,
            unit: 'lpm',
            baselineValue: widget.snapshot.individualHrBaselineBpm,
          ),
        ];
      case _TelemetryChartVariable.respiratoryRate:
        final samples = _filterByWindow(widget.snapshot.respiratoryRateSamples);
        return [
          _buildTimeSeriesChartCard(
            title: 'Gráfica 1: Frecuencia respiratoria temporal (rpm)',
            subtitle:
                'Fuente: Sensor respiratorio compatible • Discontinuidades preservadas sin interpolar.',
            samples: samples,
            lineColor: Colors.tealAccent,
            unit: 'rpm',
            baselineValue: widget.snapshot.individualRrBaselineRpm,
          ),
          const SizedBox(height: 10),
          _buildLongitudinalRestVsSleepCard(
            title: 'Gráfica 2: Evolución respiratoria por estado (Reposo vs. Sueño)',
            subtitle:
                'Comparación longitudinal separada frente a referencia individual.',
            samples: samples,
            unit: 'rpm',
            baselineValue: widget.snapshot.individualRrBaselineRpm,
          ),
          const SizedBox(height: 10),
          _buildDistributionSummaryCard(
            title: 'Gráfica 3: Distribución respiratoria por contexto',
            subtitle:
                'Mínimo, mediana y máximo de mediciones válidas para observar dispersión.',
            samples: samples,
            unit: 'rpm',
          ),
        ];
      case _TelemetryChartVariable.spO2:
        final samples = _filterByWindow(widget.snapshot.spO2Samples);
        final validSamples = samples.where((s) => s.isValid && s.value != null).toList();
        return [
          _buildTimeSeriesChartCard(
            title: 'Gráfica 1: Evolución de SpO₂ (%)',
            subtitle:
                'Fuente: Pulsioxímetro validado • Muestra únicamente lecturas válidas.',
            samples: validSamples,
            lineColor: Colors.cyanAccent,
            unit: '%',
            baselineValue: widget.snapshot.individualSpo2BaselinePercent,
          ),
          const SizedBox(height: 10),
          _buildSpo2ContextSummaryCard(
            title: 'Gráfica 2: Tendencia de SpO₂ por contexto',
            subtitle: 'Promedio y mínimo válido por sueño, reposo y actividad.',
            samples: validSamples,
          ),
          const SizedBox(height: 10),
          _buildSpo2QualityCard(
            title: 'Gráfica 3: Calidad de medición de SpO₂',
            subtitle:
                'Proporción de lecturas válidas, inválidas y faltantes para distinguir fallas de telemetría.',
            samples: samples,
          ),
        ];
    }
  }

  List<TelemetrySamplePoint> _filterByWindow(List<TelemetrySamplePoint> all) {
    if (all.isEmpty) return const [];
    final cutoff = DateTime.now().subtract(_selectedWindow.duration);
    return all.where((p) => p.timestamp.isAfter(cutoff)).toList();
  }

  Widget _buildChartFrame({
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: SpaceTheme.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 11, color: Colors.white54),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildNoDataPlaceholder(String detail) {
    return Container(
      height: 110,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: SpaceTheme.surface.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.signal_cellular_off, color: Colors.white38, size: 22),
          const SizedBox(height: 6),
          const Text(
            'Sin datos disponibles',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            detail,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11, color: Colors.white38),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeSeriesChartCard({
    required String title,
    required String subtitle,
    required List<TelemetrySamplePoint> samples,
    required Color lineColor,
    required String unit,
    double? baselineValue,
  }) {
    final validPoints = samples.where((s) => s.isValid && s.value != null).toList();
    if (validPoints.isEmpty) {
      return _buildChartFrame(
        title: title,
        subtitle: subtitle,
        child: _buildNoDataPlaceholder(
          'Esperando flujo de telemetría real (${_selectedWindow.label}).',
        ),
      );
    }

    final spots = <FlSpot>[];
    for (var i = 0; i < samples.length; i++) {
      final p = samples[i];
      if (!p.isValid || p.value == null) {
        spots.add(FlSpot.nullSpot);
      } else {
        spots.add(FlSpot(i.toDouble(), p.value!));
      }
    }

    final last = validPoints.last;
    final qualityLabel = last.signalQualityPercent != null
        ? '${last.signalQualityPercent!.toStringAsFixed(0)}%'
        : 'N/D';

    return _buildChartFrame(
      title: title,
      subtitle:
          '$subtitle\nÚltima: ${last.value!.toStringAsFixed(1)} $unit (${last.source} • Calidad: $qualityLabel)',
      child: SizedBox(
        height: 150,
        child: LineChart(
          LineChartData(
            gridData: const FlGridData(show: true, drawVerticalLine: false),
            titlesData: const FlTitlesData(
              topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            borderData: FlBorderData(show: false),
            extraLinesData: baselineValue != null
                ? ExtraLinesData(
                    horizontalLines: [
                      HorizontalLine(
                        y: baselineValue,
                        color: SpaceTheme.green.withValues(alpha: 0.7),
                        strokeWidth: 1.2,
                        dashArray: [5, 4],
                      ),
                    ],
                  )
                : null,
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: false,
                color: lineColor,
                barWidth: 2,
                dotData: const FlDotData(show: false),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContextBarChartCard({
    required String title,
    required String subtitle,
    required List<TelemetrySamplePoint> samples,
    required String unit,
    required Color barColor,
  }) {
    final contexts = [
      ActivityContext.sleep,
      ActivityContext.rest,
      ActivityContext.physicalActivity,
    ];
    final averages = <ActivityContext, double?>{};
    final counts = <ActivityContext, int>{};

    for (final ctx in contexts) {
      final values = samples
          .where((s) => s.context == ctx && s.isValid && s.value != null)
          .map((s) => s.value!)
          .toList();
      counts[ctx] = values.length;
      averages[ctx] = values.isEmpty
          ? null
          : values.reduce((a, b) => a + b) / values.length;
    }

    if (counts.values.every((c) => c == 0)) {
      return _buildChartFrame(
        title: title,
        subtitle: subtitle,
        child: _buildNoDataPlaceholder('Sin muestras clasificadas por contexto.'),
      );
    }

    return _buildChartFrame(
      title: title,
      subtitle: subtitle,
      child: SizedBox(
        height: 150,
        child: BarChart(
          BarChartData(
            gridData: const FlGridData(show: true, drawVerticalLine: false),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (value, meta) {
                    final idx = value.toInt();
                    if (idx < 0 || idx >= contexts.length) {
                      return const SizedBox.shrink();
                    }
                    final ctx = contexts[idx];
                    return Text(
                      '${ctx.label}\n(n=${counts[ctx]})',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 10, color: Colors.white70),
                    );
                  },
                  reservedSize: 30,
                ),
              ),
            ),
            barGroups: List.generate(contexts.length, (i) {
              final avg = averages[contexts[i]] ?? 0.0;
              return BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: avg,
                    color: averages[contexts[i]] != null
                        ? barColor
                        : Colors.white12,
                    width: 22,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ],
              );
            }),
          ),
        ),
      ),
    );
  }

  Widget _buildLongitudinalRestVsSleepCard({
    required String title,
    required String subtitle,
    required List<TelemetrySamplePoint> samples,
    required String unit,
    double? baselineValue,
  }) {
    final restSpots = <FlSpot>[];
    final sleepSpots = <FlSpot>[];

    for (var i = 0; i < samples.length; i++) {
      final p = samples[i];
      if (!p.isValid || p.value == null) continue;
      if (p.context == ActivityContext.rest) {
        restSpots.add(FlSpot(i.toDouble(), p.value!));
      } else if (p.context == ActivityContext.sleep) {
        sleepSpots.add(FlSpot(i.toDouble(), p.value!));
      }
    }

    if (restSpots.isEmpty && sleepSpots.isEmpty) {
      return _buildChartFrame(
        title: title,
        subtitle: subtitle,
        child: _buildNoDataPlaceholder(
          'Sin registros longitudinales separados de reposo y sueño.',
        ),
      );
    }

    return _buildChartFrame(
      title: title,
      subtitle: subtitle,
      child: SizedBox(
        height: 150,
        child: LineChart(
          LineChartData(
            gridData: const FlGridData(show: true, drawVerticalLine: false),
            titlesData: const FlTitlesData(
              topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            borderData: FlBorderData(show: false),
            extraLinesData: baselineValue != null
                ? ExtraLinesData(
                    horizontalLines: [
                      HorizontalLine(
                        y: baselineValue,
                        color: SpaceTheme.green.withValues(alpha: 0.7),
                        strokeWidth: 1.2,
                        dashArray: [5, 4],
                      ),
                    ],
                  )
                : null,
            lineBarsData: [
              if (restSpots.isNotEmpty)
                LineChartBarData(
                  spots: restSpots,
                  color: SpaceTheme.cyan,
                  barWidth: 2,
                  dotData: const FlDotData(show: true),
                ),
              if (sleepSpots.isNotEmpty)
                LineChartBarData(
                  spots: sleepSpots,
                  color: Colors.indigoAccent,
                  barWidth: 2,
                  dotData: const FlDotData(show: true),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDistributionSummaryCard({
    required String title,
    required String subtitle,
    required List<TelemetrySamplePoint> samples,
    required String unit,
  }) {
    final rows = <Widget>[];
    for (final ctx in [
      ActivityContext.sleep,
      ActivityContext.rest,
      ActivityContext.physicalActivity,
    ]) {
      final vals = samples
          .where((s) => s.context == ctx && s.isValid && s.value != null)
          .map((s) => s.value!)
          .toList()
        ..sort();
      if (vals.isEmpty) continue;
      final minVal = vals.first;
      final maxVal = vals.last;
      final median = vals[vals.length ~/ 2];
      rows.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(ctx.label, style: const TextStyle(fontSize: 12, color: Colors.white70)),
              Text(
                'Mín ${minVal.toStringAsFixed(1)} • Med ${median.toStringAsFixed(1)} • Máx ${maxVal.toStringAsFixed(1)} $unit (n=${vals.length})',
                style: const TextStyle(fontSize: 11, color: SpaceTheme.cyan),
              ),
            ],
          ),
        ),
      );
    }

    return _buildChartFrame(
      title: title,
      subtitle: subtitle,
      child: rows.isEmpty
          ? _buildNoDataPlaceholder('Sin mediciones válidas para distribución.')
          : Column(children: rows),
    );
  }

  Widget _buildSpo2ContextSummaryCard({
    required String title,
    required String subtitle,
    required List<TelemetrySamplePoint> samples,
  }) {
    final rows = <Widget>[];
    for (final ctx in [
      ActivityContext.sleep,
      ActivityContext.rest,
      ActivityContext.physicalActivity,
    ]) {
      final vals = samples
          .where((s) => s.context == ctx && s.isValid && s.value != null)
          .map((s) => s.value!)
          .toList();
      if (vals.isEmpty) continue;
      final avg = vals.reduce((a, b) => a + b) / vals.length;
      final minVal = vals.reduce((a, b) => a < b ? a : b);
      rows.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(ctx.label, style: const TextStyle(fontSize: 12, color: Colors.white70)),
              Text(
                'Prom ${avg.toStringAsFixed(1)}% • Mín ${minVal.toStringAsFixed(1)}% (n=${vals.length})',
                style: const TextStyle(fontSize: 11, color: Colors.cyanAccent),
              ),
            ],
          ),
        ),
      );
    }

    return _buildChartFrame(
      title: title,
      subtitle: subtitle,
      child: rows.isEmpty
          ? _buildNoDataPlaceholder('Sin lecturas válidas de SpO₂ por contexto.')
          : Column(children: rows),
    );
  }

  Widget _buildSpo2QualityCard({
    required String title,
    required String subtitle,
    required List<TelemetrySamplePoint> samples,
  }) {
    if (samples.isEmpty) {
      return _buildChartFrame(
        title: title,
        subtitle: subtitle,
        child: _buildNoDataPlaceholder('Sin registro de calidad de lecturas de SpO₂.'),
      );
    }

    final total = samples.length.toDouble();
    final valid = samples.where((s) => s.isValid && s.value != null).length;
    final invalid = samples.where((s) => !s.isValid && s.value != null).length;
    final missing = samples.where((s) => s.value == null).length;

    return _buildChartFrame(
      title: title,
      subtitle: subtitle,
      child: SizedBox(
        height: 130,
        child: BarChart(
          BarChartData(
            maxY: 100,
            gridData: const FlGridData(show: true, drawVerticalLine: false),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (val, _) {
                    switch (val.toInt()) {
                      case 0:
                        return const Text('Válidas', style: TextStyle(fontSize: 10, color: Colors.white70));
                      case 1:
                        return const Text('Inválidas', style: TextStyle(fontSize: 10, color: Colors.white70));
                      case 2:
                        return const Text('Faltantes', style: TextStyle(fontSize: 10, color: Colors.white70));
                      default:
                        return const SizedBox.shrink();
                    }
                  },
                ),
              ),
            ),
            barGroups: [
              BarChartGroupData(x: 0, barRods: [BarChartRodData(toY: (valid / total) * 100, color: SpaceTheme.green, width: 22)]),
              BarChartGroupData(x: 1, barRods: [BarChartRodData(toY: (invalid / total) * 100, color: SpaceTheme.warningYellow, width: 22)]),
              BarChartGroupData(x: 2, barRods: [BarChartRodData(toY: (missing / total) * 100, color: Colors.white38, width: 22)]),
            ],
          ),
        ),
      ),
    );
  }
}
