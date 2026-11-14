import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:astramed/core/theme/space_theme.dart';
import 'package:astramed/features/crew/presentation/providers/crew_provider.dart';

class MicrogravityView extends ConsumerWidget {
  const MicrogravityView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final astronaut = ref.watch(selectedAstronautProvider);
    final exercise = astronaut.exercise;

    final progress = (exercise.durationMinutes / 150.0).clamp(0.0, 1.0);

    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Fisiología en Microgravedad',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Monitoreando: ${astronaut.name} [${astronaut.callsign}]',
                  style: const TextStyle(fontSize: 12, color: SpaceTheme.cyan),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),

        Card(
          color: SpaceTheme.card,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.fitness_center, color: Colors.greenAccent),
                        SizedBox(width: 8),
                        Text(
                          'Contramedidas Físicas (NASA HRP)',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ],
                    ),
                    if (exercise.targetReached)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'META ALCANZADA',
                          style: TextStyle(fontSize: 10, color: Colors.greenAccent, fontWeight: FontWeight.bold),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Text('Dispositivo principal: ${exercise.deviceName}', style: const TextStyle(color: Colors.white70)),
                const SizedBox(height: 6),
                LinearProgressIndicator(
                  value: progress,
                  backgroundColor: Colors.white12,
                  color: exercise.targetReached ? Colors.greenAccent : SpaceTheme.warningYellow,
                  minHeight: 10,
                  borderRadius: BorderRadius.circular(5),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Tiempo: ${exercise.durationMinutes} min / 150 min objetivo',
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '${exercise.caloriesBurned.toInt()} kcal quemadas',
                      style: const TextStyle(color: SpaceTheme.cyan, fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        const Card(
          color: SpaceTheme.card,
          child: ListTile(
            leading: Icon(Icons.accessibility_new, color: SpaceTheme.cyan),
            title: Text('Presión Intracraneal y SANS'),
            subtitle: Text('Redistribución cefálica de fluidos: Monitoreo periódico'),
          ),
        ),
        const SizedBox(height: 8),
        const Card(
          color: SpaceTheme.card,
          child: ListTile(
            leading: Icon(Icons.shield_moon_outlined, color: Colors.amberAccent),
            title: Text('Densidad Mineral Ósea (BMD)'),
            subtitle: Text('Pérdida esperada mitigada con resistencia ARED'),
          ),
        ),
      ],
    );
  }
}
