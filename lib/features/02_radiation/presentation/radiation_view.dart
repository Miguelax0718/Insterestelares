import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:astramed/core/constants/medical_thresholds.dart';
import 'package:astramed/core/theme/space_theme.dart';
import 'package:astramed/features/crew/models/astronaut_profile.dart';
import 'package:astramed/features/crew/presentation/providers/crew_provider.dart';

class RadiationView extends ConsumerWidget {
  const RadiationView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final astronaut = ref.watch(selectedAstronautProvider);
    final radiation = astronaut.radiation;

    final isHigh = radiation.doseRateMicroSvPerHour > 100.0;
    final progress = (radiation.cumulativeDoseMilliSv / MedicalThresholds.radiationCareerLimitMax)
        .clamp(0.0, 1.0);

    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        // Tag del astronauta
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Dosímetro de Radiación Espacial',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Monitoreando: ${astronaut.name} [${astronaut.callsign}]',
                  style: const TextStyle(fontSize: 12, color: SpaceTheme.cyan),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                astronaut.currentZone,
                style: const TextStyle(fontSize: 11, color: Colors.white70),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        Card(
          color: SpaceTheme.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: isHigh ? SpaceTheme.dangerRed : SpaceTheme.cyan,
              width: 1.5,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Icon(
                  Icons.shield_outlined,
                  size: 48,
                  color: isHigh ? SpaceTheme.dangerRed : SpaceTheme.cyan,
                ),
                const SizedBox(height: 10),
                const Text(
                  'Tasa de Dosis Actual (Dosímetro Personal)',
                  style: TextStyle(fontSize: 13, color: Colors.white70),
                ),
                const SizedBox(height: 4),
                Text(
                  '${radiation.doseRateMicroSvPerHour.toStringAsFixed(1)} uSv/h',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: isHigh ? SpaceTheme.dangerRed : SpaceTheme.cyan,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  isHigh
                      ? '⚠️ ALERTA: TASA DE DOSIS ELEVADA (>100 uSv/h)'
                      : 'ESTADO: NIVEL BASAL NOMINAL (<100 uSv/h)',
                  style: TextStyle(
                    color: isHigh ? SpaceTheme.dangerRed : Colors.greenAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        Card(
          color: SpaceTheme.card,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Exposición Acumulada del Astronauta en Misión',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const SizedBox(height: 10),
                LinearProgressIndicator(
                  value: progress,
                  backgroundColor: Colors.white12,
                  color: isHigh ? SpaceTheme.warningYellow : SpaceTheme.cyan,
                  minHeight: 12,
                  borderRadius: BorderRadius.circular(6),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${radiation.cumulativeDoseMilliSv.toStringAsFixed(1)} mSv acumulados',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      'Límite Carrera NASA: ${MedicalThresholds.radiationCareerLimitMax.toInt()} mSv',
                      style: const TextStyle(color: Colors.white54, fontSize: 11),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
