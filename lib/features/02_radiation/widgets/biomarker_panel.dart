import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/space_theme.dart';
import '../data/biomarker_repository.dart';
import '../data/biomarker_simulator.dart';
import '../models/biomarkers/biomarker_baseline.dart';
import '../models/contracts/bio_summary.dart';
import '../providers/biomarker_providers.dart';
import '../providers/biomarker_score_calculator.dart';
import '../providers/symptom_advisor.dart';

/// Nivel del semáforo biológico según el puntaje B.
///
/// Umbrales ILUSTRATIVOS para la demo (no clínicos): con datos reales de
/// Inspiration4 la variación normal entre análisis ronda el 15–25 %.
enum BioLevel {
  normal('Normal', SpaceTheme.green),
  watch('Vigilar', SpaceTheme.warningYellow),
  alert('Alerta', SpaceTheme.dangerRed);

  const BioLevel(this.label, this.color);

  final String label;
  final Color color;

  static const double watchFrom = 0.10;
  static const double alertFrom = 0.25;

  static BioLevel of(double score) => score >= alertFrom
      ? alert
      : score >= watchFrom
          ? watch
          : normal;
}

/// Panel de biomarcadores (parte de Juan): astronauta, día de misión,
/// puntaje B con semáforo, cambios por marcador y gráfica de la misión.
class BiomarkerPanel extends ConsumerWidget {
  const BiomarkerPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(biomarkerRepositoryProvider);
    final scenario = ref.watch(biomarkerScenarioProvider);
    final astronaut = ref.watch(biomarkerAstronautProvider);
    final day = ref.watch(selectedMissionDayProvider);
    final summary = ref.watch(selectedBioSummaryProvider);
    final level = BioLevel.of(summary.score);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Biomarcadores de orina y sangre',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 4),
            const Text(
              'Cambio respecto a la línea base de cada astronauta',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 12),
            Text(
              'Astronauta: $astronaut (cámbialo en el menú de tripulación)',
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              key: const Key('extremeScenarioSwitch'),
              contentPadding: EdgeInsets.zero,
              title: const Text('Escenario extremo (hipotético)'),
              subtitle: Text(
                scenario == SimulationScenario.realistic
                    ? 'Tormenta solar de ejemplo: 50 mSv fuera del refugio, 10 mSv dentro'
                    : 'Tormenta HIPOTÉTICA de 1 Gy (0,25 Gy en el refugio)',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
              value: scenario == SimulationScenario.extremeHypothetical,
              onChanged: (v) => ref.read(biomarkerScenarioProvider.notifier).state =
                  v ? SimulationScenario.extremeHypothetical : SimulationScenario.realistic,
            ),
            Text('Día de misión: $day de ${repo.missionDays}'
                '${day > repo.missionDays ? ' (regreso)' : ''}'),
            Slider(
              min: 1,
              max: (repo.missionDays + 1).toDouble(),
              divisions: repo.missionDays,
              value: day.toDouble().clamp(1, repo.missionDays + 1),
              label: '$day',
              onChanged: (v) =>
                  ref.read(selectedMissionDayProvider.notifier).state = v.round(),
            ),
            _ScoreTile(summary: summary, level: level),
            const SizedBox(height: 12),
            _MarkerTable(summary: summary),
            const SizedBox(height: 16),
            const Text(
              'Síntomas posibles a vigilar',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 6),
            _SymptomList(symptoms: ref.watch(selectedSymptomsProvider)),
            const SizedBox(height: 20),
            const Text(
              'Evolución en la misión',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 4),
            const Text(
              'La franja verde es la variación normal de esa persona. Si la '
              'línea sale de la franja, hay un cambio real. Toca un punto para '
              'ver el valor.',
              style: TextStyle(color: Colors.white60, fontSize: 12),
            ),
            const SizedBox(height: 12),
            _MarkerChart(
              key: const Key('lymphChart'),
              title: 'Defensas: linfocitos en sangre',
              hint: 'Si bajan de la franja, hay menos defensas contra infecciones.',
              color: SpaceTheme.cyan,
              spots: _changeSeries(
                repo,
                repo.bloodSamples(astronaut)
                    .map((b) => (b.takenAt, b.lymphocytes10e9PerL)),
                repo.baselineOf(astronaut).of(Biomarker.bloodLymphocytes)!,
              ),
              normalBand: SymptomAdvisor.beyondNormal,
              badIsDown: true,
              repo: repo,
              day: day,
            ),
            const SizedBox(height: 16),
            _MarkerChart(
              key: const Key('ohdgChart'),
              title: 'Daño oxidativo al ADN: 8-OHdG en orina',
              hint: 'Si sube por encima de la franja, hay más daño oxidativo '
                  '(radiación, ejercicio intenso o mal sueño).',
              color: SpaceTheme.neonPurple,
              spots: _changeSeries(
                repo,
                repo.urineSamples(astronaut)
                    .map((u) => (u.takenAt, u.ohdgPerCreatinine)),
                repo.baselineOf(astronaut).of(Biomarker.urineOhdg)!,
              ),
              normalBand: SymptomAdvisor.beyondNormal,
              badIsDown: false,
              repo: repo,
              day: day,
            ),
            const SizedBox(height: 12),
            const Text(
              'Datos simulados. La sangre previa al vuelo es real (Inspiration4, '
              'NASA OSDR). Los umbrales del semáforo son ilustrativos.',
              style: TextStyle(color: Colors.white38, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScoreTile extends StatelessWidget {
  const _ScoreTile({required this.summary, required this.level});

  final BioSummary summary;
  final BioLevel level;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: level.color, width: 1.5),
      ),
      child: Row(
        children: [
          Icon(Icons.biotech, color: level.color, size: 36),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Puntaje biológico B',
                    style: TextStyle(color: Colors.white70)),
                Text(
                  // Un puntaje negativo (marcadores mejor que la línea base)
                  // se muestra como 0 %: no hay señal de daño.
                  '${(summary.score.clamp(0, 1) * 100).toStringAsFixed(0)} %  ·  ${level.label}',
                  key: const Key('bioScoreText'),
                  style: TextStyle(
                    color: level.color,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          if (summary.samplePending)
            const Chip(
              avatar: Icon(Icons.science_outlined, size: 18),
              label: Text('Muestra pendiente'),
            ),
        ],
      ),
    );
  }
}

class _MarkerTable extends StatelessWidget {
  const _MarkerTable({required this.summary});

  final BioSummary summary;

  @override
  Widget build(BuildContext context) {
    if (summary.changeFromBaseline.isEmpty) {
      return const Text('Sin muestras recientes (últimos 14 días).',
          style: TextStyle(color: Colors.white54));
    }
    return Column(
      children: [
        for (final m in Biomarker.values)
          if (summary.changeOf(m) != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Expanded(child: Text(m.label)),
                  Text(
                    _pct(summary.changeOf(m)!),
                    style: TextStyle(color: _changeColor(m, summary.changeOf(m)!)),
                  ),
                ],
              ),
            ),
      ],
    );
  }

  static String _pct(double r) =>
      '${r >= 0 ? '+' : ''}${(r * 100).toStringAsFixed(0)} %';

  /// Rojo si el cambio va en la dirección "mala" y supera la variación
  /// normal; amarillo si va en esa dirección pero es pequeño.
  static Color _changeColor(Biomarker m, double r) {
    final bad = BiomarkerScoreCalculator.lowerIsWorse.contains(m) ? -r : r;
    if (bad >= BioLevel.alertFrom) return SpaceTheme.dangerRed;
    if (bad >= BioLevel.watchFrom) return SpaceTheme.warningYellow;
    return Colors.white70;
  }
}

/// Serie de % de cambio vs. la línea base, solo durante y después del vuelo.
List<FlSpot> _changeSeries(
  BiomarkerRepository repo,
  Iterable<(DateTime, double)> values,
  double baseline,
) =>
    [
      for (final (t, v) in values)
        if (t.difference(repo.launch).inDays >= 1)
          FlSpot(
            t.difference(repo.launch).inDays.toDouble(),
            ((v / baseline - 1) * 100).clamp(-90.0, 140.0).toDouble(),
          ),
    ];

/// Gráfica simple de un marcador: % de cambio vs. la línea base, con la
/// franja de variación normal en verde, la zona de alerta tenue en rojo, la
/// tormenta solar marcada y el día seleccionado.
class _MarkerChart extends StatelessWidget {
  const _MarkerChart({
    super.key,
    required this.title,
    required this.hint,
    required this.color,
    required this.spots,
    required this.normalBand,
    required this.badIsDown,
    required this.repo,
    required this.day,
  });

  final String title;
  final String hint;
  final Color color;
  final List<FlSpot> spots;

  /// Ancho de la franja normal (0,25 = ±25 %).
  final double normalBand;

  /// true si lo preocupante es que BAJE (linfocitos).
  final bool badIsDown;
  final BiomarkerRepository repo;
  final int day;

  @override
  Widget build(BuildContext context) {
    final band = normalBand * 100;
    final minY = badIsDown ? -90.0 : -60.0;
    final maxY = badIsDown ? 60.0 : 140.0;
    final spe = repo.lastSolarEventAt(repo.dateOfMissionDay(repo.missionDays + 1));
    final speDay = spe?.difference(repo.launch).inDays;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
        Text(hint, style: const TextStyle(color: Colors.white54, fontSize: 11)),
        const SizedBox(height: 8),
        SizedBox(
          height: 180,
          child: LineChart(
            LineChartData(
              minX: 0,
              maxX: (repo.missionDays + 1).toDouble(),
              minY: minY,
              maxY: maxY,
              clipData: const FlClipData.all(),
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
              rangeAnnotations: RangeAnnotations(
                horizontalRangeAnnotations: [
                  HorizontalRangeAnnotation(
                    y1: -band,
                    y2: band,
                    color: SpaceTheme.green.withValues(alpha: 0.12),
                  ),
                  if (badIsDown)
                    HorizontalRangeAnnotation(
                      y1: minY,
                      y2: -band,
                      color: SpaceTheme.dangerRed.withValues(alpha: 0.07),
                    )
                  else
                    HorizontalRangeAnnotation(
                      y1: band,
                      y2: maxY,
                      color: SpaceTheme.dangerRed.withValues(alpha: 0.07),
                    ),
                ],
              ),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 44,
                    interval: 25,
                    getTitlesWidget: (v, meta) {
                      final label = v == 0
                          ? 'base'
                          : (v.abs() - band).abs() < 0.1
                              ? '${v > 0 ? '+' : ''}${v.toInt()}%'
                              : '';
                      return Text(label,
                          style: const TextStyle(fontSize: 10, color: Colors.white54));
                    },
                  ),
                ),
                bottomTitles: AxisTitles(
                  axisNameWidget: const Text('Día de misión',
                      style: TextStyle(fontSize: 10, color: Colors.white54)),
                  sideTitles: SideTitles(
                    showTitles: true,
                    interval: 30,
                    getTitlesWidget: (v, meta) => v % 30 == 0
                        ? Text('${v.toInt()}',
                            style: const TextStyle(fontSize: 10, color: Colors.white54))
                        : const SizedBox.shrink(),
                  ),
                ),
              ),
              extraLinesData: ExtraLinesData(
                horizontalLines: [
                  HorizontalLine(y: 0, color: Colors.white30, strokeWidth: 1),
                ],
                verticalLines: [
                  if (speDay != null)
                    VerticalLine(
                      x: speDay.toDouble(),
                      color: SpaceTheme.warningYellow,
                      strokeWidth: 1.5,
                      dashArray: [6, 4],
                      label: VerticalLineLabel(
                        show: true,
                        alignment: Alignment.topRight,
                        style: const TextStyle(
                            fontSize: 10, color: SpaceTheme.warningYellow),
                        labelResolver: (_) => 'Tormenta solar',
                      ),
                    ),
                  VerticalLine(
                    x: day.toDouble(),
                    color: Colors.white54,
                    strokeWidth: 1,
                    label: VerticalLineLabel(
                      show: true,
                      alignment: Alignment.bottomRight,
                      style: const TextStyle(fontSize: 10, color: Colors.white70),
                      labelResolver: (_) => 'Hoy',
                    ),
                  ),
                ],
              ),
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipColor: (_) => SpaceTheme.surface,
                  getTooltipItems: (touched) => [
                    for (final t in touched)
                      LineTooltipItem(
                        'Día ${t.x.toInt()}\n'
                        '${t.y >= 0 ? '+' : ''}${t.y.toStringAsFixed(0)} % vs. base',
                        TextStyle(color: color, fontSize: 12),
                      ),
                  ],
                ),
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  color: color,
                  barWidth: 2.5,
                  isCurved: false,
                  dotData: FlDotData(
                    show: true,
                    getDotPainter: (spot, _, _, _) {
                      final out = badIsDown ? spot.y < -band : spot.y > band;
                      return FlDotCirclePainter(
                        radius: out ? 4 : 2.5,
                        color: out ? SpaceTheme.dangerRed : color,
                        strokeWidth: 0,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SymptomList extends StatelessWidget {
  const _SymptomList({required this.symptoms});

  final List<PossibleSymptom> symptoms;

  static Color _color(SymptomLevel l) => switch (l) {
        SymptomLevel.alert => SpaceTheme.dangerRed,
        SymptomLevel.watch => SpaceTheme.warningYellow,
        SymptomLevel.info => SpaceTheme.green,
      };

  static IconData _icon(SymptomLevel l) => switch (l) {
        SymptomLevel.alert => Icons.warning_amber_rounded,
        SymptomLevel.watch => Icons.visibility_outlined,
        SymptomLevel.info => Icons.check_circle_outline,
      };

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('symptomList'),
      children: [
        for (final s in symptoms)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _color(s.level).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border(left: BorderSide(color: _color(s.level), width: 3)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(_icon(s.level), color: _color(s.level), size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.title,
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      Text(s.detail,
                          style: const TextStyle(fontSize: 12, color: Colors.white70)),
                      const SizedBox(height: 2),
                      Text('Fuente: ${s.source}',
                          style: const TextStyle(fontSize: 10, color: Colors.white38)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        const Text(
          'Orientativo: no reemplaza la valoración del médico de vuelo.',
          style: TextStyle(fontSize: 10, color: Colors.white38),
        ),
      ],
    );
  }
}
