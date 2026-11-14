import 'package:flutter/material.dart';

class MentalHealthView extends StatelessWidget {
  const MentalHealthView({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        const Text(
          'Salud Mental y Ritmo Circadiano',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          'Monitoreo del descanso, estrés por confinamiento y fatiga cognitiva',
          style: TextStyle(color: Colors.white70),
        ),
        const SizedBox(height: 16),
        Card(
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
                  children: const [
                    Text('7.2 Horas dormidas', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    Chip(
                      label: Text('Óptimo', style: TextStyle(color: Colors.white)),
                      backgroundColor: Colors.green,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Fase REM y no-REM equilibradas. Ritmo circadiano ajustado a ciclo de cabina.',
                  style: TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            leading: const Icon(Icons.sentiment_satisfied_alt, color: Colors.amberAccent),
            title: const Text('Estado Anímico Autoevaluado'),
            subtitle: const Text('Nivel de estrés bajo • Concentración óptima'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
          ),
        ),
      ],
    );
  }
}
