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
    final astronaut = ref.watch(selectedAstronautProvider);
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
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                for (final id in repo.crewIds())
                  ChoiceChip(
                    label: Text(id),
                    selected: id == astronaut,
                    onSelected: (_) =>
                        ref.read(selectedAstronautProvider.notifier).state = id,
                  ),
              ],
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
              'Evolución en la misión (% vs. línea base)',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 220,
              child: _MissionChart(repo: repo, astronautId: astronaut, day: day),
            ),
            const SizedBox(height: 8),
            const Wrap(
              spacing: 16,
              children: [
                _Legend(color: SpaceTheme.neonPurple, text: '8-OHdG (orina)'),
                _Legend(color: SpaceTheme.cyan, text: 'Linfocitos (sangre)'),
                _Legend(color: SpaceTheme.warningYellow, text: 'Tormenta solar'),
              ],
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

class _MissionChart extends StatelessWidget {
  const _MissionChart({
    required this.repo,
    required this.astronautId,
    required this.day,
  });

  final BiomarkerRepository repo;
  final String astronautId;
  final int day;

  int _dayOf(DateTime t) => t.difference(repo.launch).inDays;

  static double _clampY(double y) => y.clamp(-100.0, 150.0);

  @override
  Widget build(BuildContext context) {
    final base = repo.baselineOf(astronautId);
    final ohdgBase = base.of(Biomarker.urineOhdg)!;
    final lymphBase = base.of(Biomarker.bloodLymphocytes)!;

    final ohdg = [
      for (final u in repo.urineSamples(astronautId))
        if (_dayOf(u.takenAt) >= 1)
          FlSpot(_dayOf(u.takenAt).toDouble(),
              _clampY((u.ohdgPerCreatinine / ohdgBase - 1) * 100)),
    ];
    final lymph = [
      for (final b in repo.bloodSamples(astronautId))
        if (_dayOf(b.takenAt) >= 1)
          FlSpot(_dayOf(b.takenAt).toDouble(),
              _clampY((b.lymphocytes10e9PerL / lymphBase - 1) * 100)),
    ];
    final spe = repo.lastSolarEventAt(repo.dateOfMissionDay(repo.missionDays + 1));

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: (repo.missionDays + 1).toDouble(),
        minY: -100,
        maxY: 150,
        gridData: const FlGridData(drawVerticalLine: false, horizontalInterval: 50),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              interval: 50,
              getTitlesWidget: (v, meta) => Text('${v.toInt()}%',
                  style: const TextStyle(fontSize: 10, color: Colors.white54)),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 30,
              getTitlesWidget: (v, meta) => v % 30 == 0
                  ? Text('d${v.toInt()}',
                      style: const TextStyle(fontSize: 10, color: Colors.white54))
                  : const SizedBox.shrink(),
            ),
          ),
        ),
        extraLinesData: ExtraLinesData(
          horizontalLines: [
            HorizontalLine(y: 0, color: Colors.white24, strokeWidth: 1),
          ],
          verticalLines: [
            if (spe != null)
              VerticalLine(
                x: _dayOf(spe).toDouble(),
                color: SpaceTheme.warningYellow,
                strokeWidth: 1.5,
                dashArray: [6, 4],
              ),
            VerticalLine(x: day.toDouble(), color: Colors.white38, strokeWidth: 1),
          ],
        ),
        lineBarsData: [
          LineChartBarData(
            spots: ohdg,
            color: SpaceTheme.neonPurple,
            barWidth: 2,
            dotData: const FlDotData(show: false),
          ),
          LineChartBarData(
            spots: lymph,
            color: SpaceTheme.cyan,
            barWidth: 2,
            dotData: const FlDotData(show: true),
          ),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.text});

  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 12, height: 3, color: color),
          const SizedBox(width: 6),
          Text(text, style: const TextStyle(fontSize: 11, color: Colors.white70)),
        ],
      );
}
