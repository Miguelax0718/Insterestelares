import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/medical_thresholds.dart';
import '../../../core/theme/space_theme.dart';
import '../../04_mental_health/models/sleep_record.dart';
import '../../crew/presentation/providers/crew_provider.dart';

class MentalHealthView extends ConsumerWidget {
  const MentalHealthView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final astronaut = ref.watch(selectedAstronautProvider);
    final sleep = astronaut.sleep;

    final isOptimalSleep = sleep.sleepHours >= MedicalThresholds.minRecommendedSleepHours;
    final moodText = _getMoodText(sleep.morningMood);
    final moodColor = _getMoodColor(sleep.morningMood);

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
                  'Salud Mental y Ritmo Circadiano',
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
                const Row(
                  children: [
                    Icon(Icons.bedtime, color: Colors.purpleAccent),
                    SizedBox(width: 8),
                    Text(
                      'Registro de Sueño (Últimas 24h)',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${sleep.sleepHours.toStringAsFixed(1)} Horas',
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    Chip(
                      label: Text(
                        isOptimalSleep ? 'Descanso Óptimo' : 'Déficit de Sueño',
                        style: const TextStyle(color: Colors.white, fontSize: 11),
                      ),
                      backgroundColor: isOptimalSleep ? Colors.green : SpaceTheme.dangerRed,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Interrupciones nocturnas: ${sleep.wakeEpisodes} micro-despertares registrados.',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        Card(
          color: SpaceTheme.card,
          child: ListTile(
            leading: Icon(Icons.sentiment_satisfied_alt, color: moodColor, size: 28),
            title: const Text('Estado de Ánimo y Fatiga Cognitiva'),
            subtitle: Text('Evaluación matutina: $moodText'),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: moodColor.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: moodColor),
              ),
              child: Text(
                moodText.toUpperCase(),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: moodColor,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _getMoodText(MoodLevel mood) {
    switch (mood) {
      case MoodLevel.great:
        return 'Excelente / Alta concentración';
      case MoodLevel.good:
        return 'Bueno / Estado nominal';
      case MoodLevel.neutral:
        return 'Neutral / Adaptación estable';
      case MoodLevel.fatigued:
        return 'Fatigado / Carga mental elevada';
      case MoodLevel.stressed:
        return 'Estrés agudo / Sobrecarga';
    }
  }

  Color _getMoodColor(MoodLevel mood) {
    switch (mood) {
      case MoodLevel.great:
      case MoodLevel.good:
        return Colors.greenAccent;
      case MoodLevel.neutral:
        return SpaceTheme.cyan;
      case MoodLevel.fatigued:
        return SpaceTheme.warningYellow;
      case MoodLevel.stressed:
        return SpaceTheme.dangerRed;
    }
  }
}
