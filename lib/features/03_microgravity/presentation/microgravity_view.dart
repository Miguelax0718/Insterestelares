import 'package:flutter/material.dart';

class MicrogravityView extends StatelessWidget {
  const MicrogravityView({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        const Text(
          'Fisiología en Microgravedad',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          'Monitoreo de fluidos, densidad ósea y contramedidas físicas',
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
                    Icon(Icons.fitness_center, color: Colors.greenAccent),
                    SizedBox(width: 8),
                    Text(
                      'Meta Diaria de Ejercicio (NASA HRP)',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text('Objetivo mínimo: 2.5 horas / día'),
                const SizedBox(height: 8),
                const LinearProgressIndicator(
                  value: 0.75,
                  backgroundColor: Colors.white12,
                  color: Colors.greenAccent,
                  minHeight: 8,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Completado hoy: 112 min / 150 min (ARED + T2 Treadmill)',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            leading: const Icon(Icons.accessibility_new, color: Color(0xFF00E5FF)),
            title: const Text('Presión Intracraneal y SANS'),
            subtitle: const Text('Redistribución cefálica de fluidos: Estable'),
            trailing: const Icon(Icons.check_circle, color: Colors.greenAccent),
          ),
        ),
      ],
    );
  }
}
