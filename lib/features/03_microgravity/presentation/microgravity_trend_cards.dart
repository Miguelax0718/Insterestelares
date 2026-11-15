import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/space_theme.dart';
import '../../../core/widgets/mission_trend_card.dart';
import '../data/microgravity_sample_repository.dart';

const _boneSites = {
  'lumbar_spine': ('Columna lumbar', SpaceTheme.cyan),
  'femoral_neck': ('Cuello del fémur', Colors.amberAccent),
  'trochanter': ('Trocánter', Colors.orangeAccent),
  'total_hip': ('Cadera total', Colors.redAccent),
};

const _muscleRegions = {
  'calf': ('Pantorrilla', Colors.redAccent),
  'thigh': ('Muslo', Colors.amberAccent),
  'upper_arm': ('Brazo', SpaceTheme.cyan),
};

/// Tendencias de hueso, músculo y ejercicio del astronauta, leídas de
/// `DB/samples/microgravity/`.
class MicrogravityTrendCards extends ConsumerWidget {
  const MicrogravityTrendCards({super.key, required this.astronautId});
  final String astronautId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sample = ref.watch(microgravitySampleProvider);
    return Column(
      children: [
        MissionTrendCard(
          icon: Icons.shield_moon_outlined,
          title: 'Densidad ósea (cambio desde antes del vuelo)',
          data: sample,
          builder: (context) {
            final bone = sample.requireValue.bone
                .where((b) => b.astronautId == astronautId)
                .toList();
            final worst = bone.isEmpty
                ? null
                : bone.reduce((a, b) => a.changePct < b.changePct ? a : b);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                MissionTrendChart(
                  unit: '%',
                  decimals: 1,
                  series: [
                    for (final site in _boneSites.entries)
                      TrendSeries(site.value.$1, site.value.$2, [
                        for (final b in bone.where((b) => b.site == site.key))
                          FlSpot(b.missionDay.toDouble(), b.changePct),
                      ]),
                  ],
                ),
                const SizedBox(height: 8),
                if (worst != null)
                  Text(
                    'Mayor pérdida: ${_boneSites[worst.site]?.$1 ?? worst.site}, '
                    '${worst.changePct.toStringAsFixed(1)} % el día '
                    '${worst.missionDay}.',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: worst.changePct <= -10
                          ? SpaceTheme.dangerRed
                          : SpaceTheme.warningYellow,
                    ),
                  ),
                const Text(
                  'Aun con ejercicio se pierde ~1 % de hueso al mes en la '
                  'columna y 1–1,5 % en la cadera (LeBlanc 2000). En vuelo es '
                  'una estimación: la densitometría se hace antes y después.',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 12),
        MissionTrendCard(
          icon: Icons.accessibility_new,
          title: 'Volumen muscular (cambio desde antes del vuelo)',
          data: sample,
          builder: (context) {
            final muscle = sample.requireValue.muscle
                .where((m) => m.astronautId == astronautId)
                .toList();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                MissionTrendChart(
                  unit: '%',
                  decimals: 1,
                  series: [
                    for (final region in _muscleRegions.entries)
                      TrendSeries(region.value.$1, region.value.$2, [
                        for (final m
                            in muscle.where((m) => m.region == region.key))
                          FlSpot(m.missionDay.toDouble(), m.changePct),
                      ]),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'En 6 meses la pantorrilla pierde entre 10 y 16 % y el muslo '
                  'entre 4 y 7 %; el brazo casi no cambia (Gopalakrishnan 2010).',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 12),
        MissionTrendCard(
          icon: Icons.fitness_center,
          title: 'Ejercicio por semana (ARED + T2 + CEVIS)',
          data: sample,
          builder: (context) {
            final data = sample.requireValue;
            final weeks = data.weeklyExerciseMinutes(astronautId);
            final aredDown = data.exercise.any((e) =>
                e.astronautId == astronautId &&
                e.event == 'ared_out_of_service');
            final mean = weeks.isEmpty
                ? 0.0
                : weeks.values.reduce((a, b) => a + b) / weeks.length;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                MissionTrendChart(
                  unit: 'min',
                  series: [
                    TrendSeries('Minutos por semana', Colors.greenAccent, [
                      // Se dibuja en el último día de cada semana.
                      for (final w in weeks.entries)
                        FlSpot(w.key * 7.0, w.value.toDouble()),
                    ]),
                  ],
                  references: const [
                    TrendReference(450, 'Mínimo observado en la ISS (450 min)',
                        SpaceTheme.warningYellow),
                  ],
                ),
                const SizedBox(height: 8),
                TrendStat(
                  'Media semanal',
                  '${mean.toStringAsFixed(0)} min',
                  color: mean < 450 ? SpaceTheme.dangerRed : SpaceTheme.green,
                ),
                if (aredDown)
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Text(
                      'ARED fuera de servicio desde el día 60: sin ejercicio de '
                      'fuerza, la pérdida de hueso y músculo se acelera.',
                      style:
                          TextStyle(color: SpaceTheme.dangerRed, fontSize: 12),
                    ),
                  ),
                const Text(
                  'En la ISS cada astronauta hace ~600 min de ejercicio por '
                  'semana (rango 450–720).',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}
