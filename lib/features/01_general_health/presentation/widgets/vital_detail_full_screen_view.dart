import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:astramed/core/theme/space_theme.dart';
import 'package:astramed/features/01_general_health/domain/scientific_criteria_engine.dart';
import 'package:astramed/features/01_general_health/domain/telemetry_view_contracts.dart';

/// Vista de pantalla completa para el detalle clínico, gamificado y contextual
/// de un indicador vital específico (Frecuencia Cardíaca, Frecuencia Respiratoria, SpO2).
class VitalDetailFullScreenView extends StatefulWidget {
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
  final ActivityContext activeContext;

  const VitalDetailFullScreenView({
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
    required this.activeContext,
  });

  static Future<void> navigate(
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
    required ActivityContext activeContext,
  }) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => VitalDetailFullScreenView(
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
          activeContext: activeContext,
        ),
      ),
    );
  }

  @override
  State<VitalDetailFullScreenView> createState() =>
      _VitalDetailFullScreenViewState();
}

class _VitalDetailFullScreenViewState extends State<VitalDetailFullScreenView> {
  bool _missionCompleted = false;

  @override
  Widget build(BuildContext context) {
    final validSamples =
        widget.samples.where((s) => s.isValid && s.value != null).toList();
    final criterion = widget.evaluation.appliedCriterion;

    // Calcular valores/medias por contexto específico
    final restAvg = _calculateAverage(widget.samples, ActivityContext.rest);
    final sleepAvg = _calculateAverage(widget.samples, ActivityContext.sleep);
    final activityAvg =
        _calculateAverage(widget.samples, ActivityContext.physicalActivity);

    return Scaffold(
      backgroundColor: SpaceTheme.background,
      appBar: AppBar(
        backgroundColor: SpaceTheme.surface,
        elevation: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: widget.color.withValues(alpha: 0.2),
              child: Icon(widget.icon, color: widget.color, size: 18),
            ),
            const SizedBox(width: 10),
            Text(
              widget.title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // ── TARJETA HERO: VALOR ACTUAL Y ESTADO ──
          _buildHeroCard(restAvg, sleepAvg, activityAvg),
          const SizedBox(height: 16),

          // ── COMPARATIVA VISUAL DE CONTEXTOS (REPOSO, SUEÑO, ACTIVIDAD) ──
          _buildContextsBreakdownCard(restAvg, sleepAvg, activityAvg),
          const SizedBox(height: 16),

          // ── MISIÓN DE GAMIFICACIÓN / APRENDIZAJE ──
          _buildGamificationMissionCard(),
          const SizedBox(height: 16),

          // ── GRÁFICAS Y TENDENCIA TEMPORAL ──
          _buildChartsCard(validSamples),
          const SizedBox(height: 16),

          // ── GUÍA CLARA PARA EL ASTRONAUTA (INSTRUCCIONES SIMPLES) ──
          _buildEducationalInstructionsCard(),
          const SizedBox(height: 16),

          // ── METADATOS Y CRITERIO CIENTÍFICO ──
          if (criterion != null) ...[
            _buildScientificReferenceCard(criterion),
            const SizedBox(height: 20),
          ],
        ],
      ),
    );
  }

  double? _calculateAverage(
      List<TelemetrySamplePoint> samples, ActivityContext ctx) {
    final values = samples
        .where((s) => s.context == ctx && s.isValid && s.value != null)
        .map((s) => s.value!)
        .toList();
    if (values.isEmpty) return null;
    return values.reduce((a, b) => a + b) / values.length;
  }

  Widget _buildHeroCard(double? restAvg, double? sleepAvg, double? activityAvg) {
    final hasData = widget.evaluation.hasData;
    final valStr = hasData
        ? '${widget.evaluation.value!.toStringAsFixed(widget.unit == 'rpm' ? 1 : 0)} ${widget.unit}'
        : 'Sin datos';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: SpaceTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: widget.color.withValues(alpha: 0.4), width: 1.5),
        gradient: LinearGradient(
          colors: [
            widget.color.withValues(alpha: 0.12),
            SpaceTheme.surface,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: SpaceTheme.card,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white12),
                ),
                child: Text(
                  'Contexto actual: ${widget.activeContext.label}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white70,
                  ),
                ),
              ),
              Text(
                widget.evaluation.severity.label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: widget.color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            valStr,
            style: TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.bold,
              color: hasData ? Colors.white : Colors.white54,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            widget.evaluation.summary,
            style: const TextStyle(fontSize: 13, color: Colors.white70),
          ),
          const SizedBox(height: 6),
          Text(
            widget.metadataTag,
            style: const TextStyle(fontSize: 11, color: Colors.white38),
          ),
        ],
      ),
    );
  }

  Widget _buildContextsBreakdownCard(
      double? restAvg, double? sleepAvg, double? activityAvg) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: SpaceTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.compare_arrows, color: SpaceTheme.cyan, size: 18),
              SizedBox(width: 8),
              Text(
                'Valores Medios por Contexto Fisiológico',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildContextBox(
                  'Reposo',
                  restAvg,
                  Icons.chair,
                  Colors.blueAccent,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildContextBox(
                  'Sueño',
                  sleepAvg,
                  Icons.bedtime,
                  Colors.indigoAccent,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildContextBox(
                  'Actividad',
                  activityAvg,
                  Icons.fitness_center,
                  Colors.orangeAccent,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildContextBox(
      String label, double? val, IconData icon, Color boxColor) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: SpaceTheme.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: boxColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 18, color: boxColor),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: Colors.white60),
          ),
          const SizedBox(height: 6),
          Text(
            val != null
                ? '${val.toStringAsFixed(widget.unit == 'rpm' ? 1 : 0)} ${widget.unit}'
                : 'Sin datos',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: val != null ? Colors.white : Colors.white38,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGamificationMissionCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: SpaceTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _missionCompleted ? SpaceTheme.green : SpaceTheme.cyan.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    _missionCompleted
                        ? Icons.military_tech
                        : Icons.stars_rounded,
                    color: _missionCompleted ? SpaceTheme.green : SpaceTheme.cyan,
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Misión: Autoconocimiento Vital',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: (_missionCompleted ? SpaceTheme.green : SpaceTheme.cyan)
                      .withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _missionCompleted ? '+50 XP Cumplido' : 'En progreso',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: _missionCompleted ? SpaceTheme.green : SpaceTheme.cyan,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Comprender tus indicadores reduce riesgos de misión y optimiza las contramedidas de salud espacial.',
            style: TextStyle(fontSize: 12, color: Colors.white70),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: _missionCompleted ? 1.0 : 0.6,
                    minHeight: 6,
                    backgroundColor: Colors.white12,
                    color: _missionCompleted ? SpaceTheme.green : SpaceTheme.cyan,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                _missionCompleted ? '100%' : '60%',
                style: const TextStyle(fontSize: 11, color: Colors.white60),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (!_missionCompleted)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                style: TextButton.styleFrom(
                  foregroundColor: SpaceTheme.cyan,
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: () {
                  setState(() {
                    _missionCompleted = true;
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        '¡Hito de salud registrado! Has revisado la guía contextual.',
                      ),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
                icon: const Icon(Icons.check, size: 16),
                label: const Text('Completar Revisión de Misión'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildChartsCard(List<TelemetrySamplePoint> validSamples) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: SpaceTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.show_chart, color: widget.color, size: 18),
              const SizedBox(width: 8),
              Text(
                'Evolución Gráfica (${widget.unit})',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Tendencia de mediciones válidas recientes capturadas por telemetría o manual.',
            style: TextStyle(fontSize: 11, color: Colors.white54),
          ),
          const SizedBox(height: 14),
          if (validSamples.isNotEmpty)
            SizedBox(
              height: 170,
              child: LineChart(
                LineChartData(
                  gridData: const FlGridData(
                    show: true,
                    drawVerticalLine: false,
                  ),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 22,
                        getTitlesWidget: (val, meta) {
                          final idx = val.toInt();
                          if (idx >= 0 && idx < validSamples.length) {
                            return Text(
                              'P$idx',
                              style: const TextStyle(
                                fontSize: 9,
                                color: Colors.white38,
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: List.generate(
                        validSamples.length,
                        (i) => FlSpot(i.toDouble(), validSamples[i].value!),
                      ),
                      isCurved: true,
                      color: widget.color,
                      barWidth: 2.8,
                      dotData: const FlDotData(show: true),
                      belowBarData: BarAreaData(
                        show: true,
                        color: widget.color.withValues(alpha: 0.15),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Container(
              height: 100,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: SpaceTheme.card,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'Sin muestras suficientes para graficar. Puedes capturar datos desde la cabina o registrar manualmente.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.white54),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEducationalInstructionsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: SpaceTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.menu_book_rounded, color: SpaceTheme.cyan, size: 18),
              SizedBox(width: 8),
              Text(
                'Guía de Instrucciones Simples para el Astronauta',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildStepRow(
            '1. ¿Cómo se mide?',
            widget.howToMeasure,
            Icons.straighten,
            Colors.tealAccent,
          ),
          const SizedBox(height: 10),
          _buildStepRow(
            '2. ¿Qué significa según tu actividad?',
            widget.contextMeaning,
            Icons.psychology_alt,
            Colors.orangeAccent,
          ),
          const SizedBox(height: 10),
          _buildStepRow(
            '3. ¿Cuándo prestar atención o reportar?',
            widget.whenToPayAttention,
            Icons.health_and_safety,
            Colors.redAccent,
          ),
        ],
      ),
    );
  }

  Widget _buildStepRow(
      String heading, String content, IconData icon, Color iconColor) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: SpaceTheme.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: iconColor.withValues(alpha: 0.15),
            child: Icon(icon, size: 16, color: iconColor),
          ),
          const SizedBox(width: 12),
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
                const SizedBox(height: 4),
                Text(
                  content,
                  style: const TextStyle(fontSize: 12, color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScientificReferenceCard(ScientificCriterion criterion) {
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
          const Text(
            'Base Científica y Trazabilidad',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Fuente: ${criterion.source} (v${criterion.version})',
            style: const TextStyle(fontSize: 10, color: Colors.white54),
          ),
          Text(
            'Limitaciones: ${criterion.limitations}',
            style: const TextStyle(fontSize: 10, color: Colors.white38),
          ),
        ],
      ),
    );
  }
}
