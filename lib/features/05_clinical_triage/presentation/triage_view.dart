import 'package:flutter/material.dart';

class TriageView extends StatelessWidget {
  const TriageView({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        const Text(
          'Triage y Diagnóstico Clínico Autónomo',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          'Protocolos de emergencia NASA para misiones en espacio profundo (100% Offline)',
          style: TextStyle(color: Colors.white70),
        ),
        const SizedBox(height: 16),
        Card(
          color: const Color(0xFF141D2B),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.health_and_safety, color: Colors.greenAccent),
                    SizedBox(width: 8),
                    Text(
                      'Iniciar Autodiagnóstico Rápido',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Responde a preguntas clínicas escalonadas para recibir clasificación de gravedad y guía de tratamiento paso a paso.',
                  style: TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00E5FF),
                    foregroundColor: Colors.black,
                  ),
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Comenzar Evaluación de Síntomas'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Protocolos de Emergencia Disponibles en Local',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 8),
        _buildProtocolTile('Manejo de Síndrome Agudo por Radiación (ARS)', Icons.warning_amber, Colors.orangeAccent),
        _buildProtocolTile('Soporte Cardiopulmonar en Microgravedad', Icons.favorite, Colors.redAccent),
        _buildProtocolTile('Tratamiento de Cefalea y Congestión SANS', Icons.remove_red_eye, Colors.blueAccent),
        _buildProtocolTile('Quemaduras y Lesiones por Traumatismo en Cabina', Icons.local_hospital, Colors.greenAccent),
      ],
    );
  }

  Widget _buildProtocolTile(String title, IconData icon, Color color) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(title, style: const TextStyle(fontSize: 14)),
        trailing: const Icon(Icons.arrow_forward_ios, size: 14),
        onTap: () {},
      ),
    );
  }
}
