import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/medical_thresholds.dart';
import '../../../core/theme/space_theme.dart';
import '../../../core/widgets/mission_trend_card.dart';
import '../data/sleep_sample_repository.dart';

/// Tendencia del sueño del astronauta durante la misión, leída de
/// `DB/samples/sleep/`.
class SleepTrendCard extends ConsumerWidget {
  const SleepTrendCard({super.key, required this.astronautId});
  final String astronautId;

  /// Media de las 7 noches que terminan en cada noche (suaviza la curva).
  static List<FlSpot> weeklyAverage(List<SleepSampleNight> nights) {
    final spots = <FlSpot>[];
    for (var i = 0; i < nights.length; i++) {
      final from = i < 6 ? 0 : i - 6;
      final window = nights.sublist(from, i + 1);
      final mean =
          window.map((n) => n.sleepHours).reduce((a, b) => a + b) / window.length;
      spots.add(FlSpot(nights[i].missionDay.toDouble(), mean));
    }
    return spots;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sample = ref.watch(sleepSampleProvider);
    return MissionTrendCard(
      icon: Icons.nights_stay,
      title: 'Sueño durante la misión (180 noches)',
      data: sample,
      builder: (context) {
        final inflight = sample.requireValue
            .where((n) => n.astronautId == astronautId && n.phase == 'inflight')
            .toList();
        if (inflight.isEmpty) {
          return const Text('Sin datos de muestra para este astronauta.',
              style: TextStyle(color: Colors.white54));
        }
        final mean = inflight.map((n) => n.sleepHours).reduce((a, b) => a + b) /
            inflight.length;
        final shortNights = inflight.where((n) => n.sleepHours < 6).length;
        final medicated = inflight.where((n) => n.sleepMedication).length;
        final deficit = mean < MedicalThresholds.minRecommendedSleepHours;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            MissionTrendChart(
              unit: 'h',
              decimals: 1,
              series: [
                TrendSeries('Horas por noche', Colors.purpleAccent.withValues(alpha: 0.35), [
                  for (final n in inflight)
                    FlSpot(n.missionDay.toDouble(), n.sleepHours),
                ]),
                TrendSeries('Media de 7 noches', Colors.purpleAccent,
                    weeklyAverage(inflight)),
              ],
              references: const [
                TrendReference(MedicalThresholds.minRecommendedSleepHours,
                    'Mínimo recomendado (${MedicalThresholds.minRecommendedSleepHours} h)', SpaceTheme.warningYellow),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 24,
              runSpacing: 8,
              children: [
                TrendStat('Media en vuelo', '${mean.toStringAsFixed(1)} h',
                    color: deficit ? SpaceTheme.warningYellow : SpaceTheme.green),
                TrendStat('Noches con menos de 6 h',
                    '$shortNights de ${inflight.length}'),
                TrendStat('Noches con medicación', '$medicated'),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'En la ISS los astronautas duermen de media 6,1 h por noche, '
              'menos de las 8,5 h programadas (Barger 2014).',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        );
      },
    );
  }
}
