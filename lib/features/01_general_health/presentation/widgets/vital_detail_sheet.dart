import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:astramed/core/theme/space_theme.dart';
import 'package:astramed/features/01_general_health/domain/scientific_criteria_engine.dart';
import 'package:astramed/features/01_general_health/domain/telemetry_view_contracts.dart';

/// Hoja modal de detalle por indicador fisiológico.
///
/// Muestra valor actual, media en el contexto activo, guía educativa simple
/// (cómo se mide, qué significa y cuándo prestar atención) y evolución reciente.
class VitalDetailSheet extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final EvaluationResult evaluation;
  final String contextAverageLabel;
  final String metadataTag;
  final List<TelemetrySamplePoint> samples;
  final String unit;
  final String howToMeasure;
  final String contextMeaning;
  final String whenToPayAttention;

  const VitalDetailSheet({
    super.key,
    required this.title,
    required this.icon,
    required this.color,
    required this.evaluation,
    required this.contextAverageLabel,
    required this.metadataTag,
    required this.samples,
    required this.unit,
    required this.howToMeasure,
    required this.contextMeaning,
    required this.whenToPayAttention,
  });

  static Future<void> show(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
    required EvaluationResult evaluation,
    required String contextAverageLabel,
    required String metadataTag,
    required List<TelemetrySamplePoint> samples,
    required String unit,
    required String howToMeasure,
    required String contextMeaning,
    required String whenToPayAttention,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: SpaceTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => VitalDetailSheet(
        title: title,
        icon: icon,
        color: color,
        evaluation: evaluation,
        contextAverageLabel: contextAverageLabel,
        metadataTag: metadataTag,
        samples: samples,
        unit: unit,
        howToMeasure: howToMeasure,
        contextMeaning: contextMeaning,
        whenToPayAttention: whenToPayAttention,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final validSamples =
        samples.where((s) => s.isValid && s.value != null).toList();
    final criterion = evaluation.appliedCriterion;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.72,
      minChildSize: 0.45,
      maxChildSize: 0.92,
      builder: (context, scrollController) {
        return ListView(
          controller: scrollController,
          padding: const EdgeInsets.all(16),
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: color.withValues(alpha: 0.18),
                  child: Icon(icon, color: color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'Contexto: ${evaluation.context.label} • ${evaluation.severity.label}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: SpaceTheme.cyan,
                        ),
                      ),
                    ],
                  ),
                ),
                if (evaluation.hasData)
                  Text(
                    '${evaluation.value!.toStringAsFixed(unit == 'rpm' ? 1 : 0)} $unit',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: SpaceTheme.card,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    contextAverageLabel,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: SpaceTheme.cyan,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    evaluation.summary,
                    style: const TextStyle(fontSize: 12, color: Colors.white70),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    metadataTag,
                    style: const TextStyle(fontSize: 10, color: Colors.white38),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _buildInfoSection(
              Icons.straighten,
              '¿Cómo se mide?',
              howToMeasure,
            ),
            const SizedBox(height: 10),
            _buildInfoSection(
              Icons.psychology_alt,
              '¿Qué significa en este contexto?',
              contextMeaning,
            ),
            const SizedBox(height: 10),
            _buildInfoSection(
              Icons.health_and_safety,
              '¿Cuándo prestar atención?',
              whenToPayAttention,
            ),
            const SizedBox(height: 14),
            Text(
              'Evolución reciente ($unit)',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            if (validSamples.isNotEmpty)
              SizedBox(
                height: 130,
                child: LineChart(
                  LineChartData(
                    gridData: const FlGridData(show: true, drawVerticalLine: false),
                    borderData: FlBorderData(show: false),
                    titlesData: const FlTitlesData(
                      topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    lineBarsData: [
                      LineChartBarData(
                        spots: List.generate(
                          validSamples.length,
                          (i) => FlSpot(i.toDouble(), validSamples[i].value!),
                        ),
                        isCurved: true,
                        color: color,
                        barWidth: 2.4,
                        dotData: const FlDotData(show: true),
                        belowBarData: BarAreaData(
                          show: true,
                          color: color.withValues(alpha: 0.14),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: SpaceTheme.card,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'Sin datos recientes capturados para trazar evolución. Activa la recepción automática o registra una medición manual.',
                  style: TextStyle(fontSize: 11, color: Colors.white54),
                ),
              ),
            if (criterion != null) ...[
              const SizedBox(height: 12),
              Text(
                'Fuente científica: ${criterion.source} (v${criterion.version})\nLimitaciones: ${criterion.limitations}',
                style: const TextStyle(fontSize: 10, color: Colors.white38),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildInfoSection(IconData sectionIcon, String heading, String body) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: SpaceTheme.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(sectionIcon, size: 17, color: SpaceTheme.cyan),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  heading,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  body,
                  style: const TextStyle(fontSize: 12, color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
