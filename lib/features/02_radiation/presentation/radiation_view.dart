import 'package:flutter/material.dart';

class RadiationView extends StatelessWidget {
  const RadiationView({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        const Text(
          'Dosímetro de Radiación Espacial',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          'Monitoreo GCR (Rayos Cósmicos) y SPE (Eventos de Partículas Solares)',
          style: TextStyle(color: Colors.white70),
        ),
        const SizedBox(height: 16),
        Card(
          color: const Color(0xFF141D2B),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0xFF00E5FF), width: 1.5),
          ),
          child: const Padding(
            padding: EdgeInsets.all(16.0),
            child: Column(
              children: [
                Icon(Icons.shield_outlined, size: 50, color: Color(0xFF00E5FF)),
                SizedBox(height: 12),
                Text(
                  'Tasa de Dosis Actual',
                  style: TextStyle(fontSize: 14, color: Colors.white70),
                ),
                SizedBox(height: 4),
                Text(
                  '62.4 uSv/h',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF00E5FF),
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'ESTADO: NIVEL BASAL NOMINAL',
                  style: TextStyle(
                    color: Colors.greenAccent,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Exposición Acumulada de la Misión',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                const LinearProgressIndicator(
                  value: 0.18,
                  backgroundColor: Colors.white12,
                  color: Color(0xFF00E5FF),
                  minHeight: 10,
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    Text('108 mSv acumulados', style: TextStyle(color: Colors.white70)),
                    Text('Límite de Carrera: 600 mSv', style: TextStyle(color: Colors.white54)),
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
