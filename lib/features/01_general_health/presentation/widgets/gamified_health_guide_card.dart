import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:astramed/core/theme/space_theme.dart';
import 'package:astramed/features/01_general_health/domain/scientific_criteria_engine.dart';
import 'package:astramed/features/01_general_health/domain/telemetry_view_contracts.dart';
import 'package:astramed/features/01_general_health/models/vitals_record.dart';

enum _HealthTopic {
  heartRate('Frecuencia Cardíaca', Icons.favorite, Colors.redAccent),
  respiratoryRate('Respiración', Icons.waves, Colors.tealAccent),
  spO2('Oxígeno (SpO₂)', Icons.air, Colors.cyanAccent);

  final String title;
  final IconData icon;
  final Color color;
  const _HealthTopic(this.title, this.icon, this.color);
}

/// Guía gamificada e interactiva de salud para astronautas.
///
/// Traduce las mediciones y tendencias en explicaciones simples sobre cómo se
/// miden, qué significan según el contexto y cuándo requieren atención,
/// fomentando el hábito de seguimiento sin puntuar valores fisiológicos.
class GamifiedHealthGuideCard extends StatefulWidget {
  final TelemetrySeriesSnapshot snapshot;
  final ActivityContext activeContext;
  final VitalsRecord vitals;

  const GamifiedHealthGuideCard({
    super.key,
    required this.snapshot,
    required this.activeContext,
    required this.vitals,
  });

  @override
  State<GamifiedHealthGuideCard> createState() =>
      _GamifiedHealthGuideCardState();
}

class _GamifiedHealthGuideCardState extends State<GamifiedHealthGuideCard> {
  _HealthTopic _selectedTopic = _HealthTopic.heartRate;
  final Set<_HealthTopic> _reviewedTopics = {_HealthTopic.heartRate};

  @override
  Widget build(BuildContext context) {
    final progress = _reviewedTopics.length / _HealthTopic.values.length;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: SpaceTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: SpaceTheme.cyan.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.explore, color: SpaceTheme.cyan, size: 18),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Misión de Seguimiento: Entiende tus Indicadores',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: SpaceTheme.cyan.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${_reviewedTopics.length}/${_HealthTopic.values.length} revisados',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: SpaceTheme.cyan,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Explora cada indicador para saber cómo se mide, qué cambia en el espacio y cuándo avisar al equipo médico.',
            style: TextStyle(fontSize: 11, color: Colors.white70),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: Colors.white12,
              color: progress >= 1.0 ? SpaceTheme.green : SpaceTheme.cyan,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _HealthTopic.values.map((topic) {
              final selected = topic == _selectedTopic;
              final reviewed = _reviewedTopics.contains(topic);
              return ChoiceChip(
                avatar: Icon(
                  reviewed ? Icons.check_circle : topic.icon,
                  size: 16,
                  color: selected ? topic.color : Colors.white60,
                ),
                label: Text(topic.title),
                selected: selected,
                selectedColor: topic.color.withValues(alpha: 0.2),
                backgroundColor: SpaceTheme.card,
                labelStyle: TextStyle(
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                  color: selected ? Colors.white : Colors.white70,
                ),
                onSelected: (_) {
                  setState(() {
                    _selectedTopic = topic;
                    _reviewedTopics.add(topic);
                  });
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          _buildTopicContent(),
        ],
      ),
    );
  }

  Widget _buildTopicContent() {
    switch (_selectedTopic) {
      case _HealthTopic.heartRate:
        return _buildGuideCard(
          topic: _HealthTopic.heartRate,
          howToMeasure:
              'Se registra con tu prenda Bio-Monitor (ECG/PPG) o contando tus pulsaciones en muñeca o cuello durante 15 segundos y multiplicando por 4.',
          contextMeaning: _heartRateContextTip(widget.activeContext),
          whenToPayAttention:
              'Compara siempre con tu propio promedio en el mismo estado (reposo vs. ejercicio). En microgravedad puede subir ~3–4 lpm de forma habitual. Si notas palpitaciones o mareo en reposo, consulta protocolo.',
          samples: widget.snapshot.heartRateSamples,
          unit: 'lpm',
          currentSummary: '${widget.vitals.heartRate.toInt()} lpm (${widget.activeContext.label})',
        );
      case _HealthTopic.respiratoryRate:
        return _buildGuideCard(
          topic: _HealthTopic.respiratoryRate,
          howToMeasure:
              'La banda torácica detecta cada expansión del pecho. Si no tienes sensor, cuenta cuántas veces sube y baja tu pecho en 30 segundos y multiplica por 2.',
          contextMeaning:
              'En reposo suele estar entre 12 y 20 respiraciones por minuto. Durante el ejercicio sube de forma natural para aportar más oxígeno.',
          whenToPayAttention:
              'Una sola lectura aislada no indica un problema. Presta atención si en reposo notas falta de aire persistente o si el ambiente de cabina reporta CO₂ elevado.',
          samples: widget.snapshot.respiratoryRateSamples,
          unit: 'rpm',
          currentSummary:
              '${widget.vitals.respiratoryRate.toStringAsFixed(1)} rpm (${widget.activeContext.label})',
        );
      case _HealthTopic.spO2:
        return _buildGuideCard(
          topic: _HealthTopic.spO2,
          howToMeasure:
              'Coloca el pulsioxímetro en un dedo limpio y sin movimiento durante unos segundos hasta que la lectura se estabilice.',
          contextMeaning:
              'Mide qué porcentaje de tu sangre transporta oxígeno. En tierra una referencia común en adultos sanos es 95–100 %, aunque la calidad de señal y el frío en dedos pueden alterar la lectura.',
          whenToPayAttention:
              'Si ves un valor bajo, primero revisa que el sensor esté bien ajustado y la mano tibia. Repite la medición en reposo antes de reportar al equipo médico.',
          samples: widget.snapshot.spO2Samples,
          unit: '%',
          currentSummary: '${widget.vitals.spO2.toInt()} % (${widget.activeContext.label})',
        );
    }
  }

  String _heartRateContextTip(ActivityContext context) {
    switch (context) {
      case ActivityContext.rest:
        return 'En reposo, una referencia general en adultos es 60–100 lpm (personas muy entrenadas pueden tener menos).';
      case ActivityContext.sleep:
        return 'Durante el sueño suele bajar respecto al día. Se compara con tus propias noches anteriores.';
      case ActivityContext.physicalActivity:
        return 'Durante el ejercicio es normal que suba bastante; nunca se evalúa con los límites de reposo.';
      case ActivityContext.unknown:
        return 'Sin contexto definido es difícil interpretar el pulso. Selecciona si estás en reposo, sueño o actividad.';
    }
  }

  Widget _buildGuideCard({
    required _HealthTopic topic,
    required String howToMeasure,
    required String contextMeaning,
    required String whenToPayAttention,
    required List<TelemetrySamplePoint> samples,
    required String unit,
    required String currentSummary,
  }) {
    final validSamples =
        samples.where((s) => s.isValid && s.value != null).toList();

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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                topic.title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: topic.color,
                ),
              ),
              Text(
                currentSummary,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildInfoRow(Icons.straighten, '¿Cómo se mide?', howToMeasure),
          const SizedBox(height: 8),
          _buildInfoRow(
            Icons.psychology_alt,
            '¿Qué significa ahora?',
            contextMeaning,
          ),
          const SizedBox(height: 8),
          _buildInfoRow(
            Icons.health_and_safety,
            '¿Cuándo prestar atención?',
            whenToPayAttention,
          ),
          const SizedBox(height: 10),
          if (validSamples.isNotEmpty) ...[
            Text(
              'Evolución reciente ($unit)',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.white70,
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: 95,
              child: LineChart(
                LineChartData(
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  titlesData: const FlTitlesData(
                    topTitles:
                        AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles:
                        AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles:
                        AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    leftTitles:
                        AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: List.generate(
                        validSamples.length,
                        (i) => FlSpot(i.toDouble(), validSamples[i].value!),
                      ),
                      isCurved: true,
                      color: topic.color,
                      barWidth: 2.2,
                      dotData: const FlDotData(show: true),
                      belowBarData: BarAreaData(
                        show: true,
                        color: topic.color.withValues(alpha: 0.14),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ] else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: SpaceTheme.surface.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, size: 15, color: Colors.white54),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Sin datos recientes capturados para trazar evolución. Usa "Capturar Telemetría" o "Medición Manual".',
                      style: TextStyle(fontSize: 11, color: Colors.white54),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String heading, String body) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 15, color: SpaceTheme.cyan),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: const TextStyle(fontSize: 12, color: Colors.white70),
              children: [
                TextSpan(
                  text: '$heading ',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                TextSpan(text: body),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
