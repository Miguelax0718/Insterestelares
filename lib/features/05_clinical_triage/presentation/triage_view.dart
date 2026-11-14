import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:astramed/core/theme/space_theme.dart';
import 'package:astramed/features/crew/models/astronaut_profile.dart';
import 'package:astramed/features/crew/presentation/providers/crew_provider.dart';

class TriageView extends ConsumerWidget {
  const TriageView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final astronaut = ref.watch(selectedAstronautProvider);
    final isCritical = astronaut.riskLevel == CrewRiskLevel.critical;

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
                  'Triage Clínico Autónomo',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Paciente activo: ${astronaut.name} [${astronaut.callsign}]',
                  style: const TextStyle(fontSize: 12, color: SpaceTheme.cyan),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 14),

        // ── ALERTA PRIORITARIA SI EL ASTRONAUTA ESTÁ CRÍTICO ──
        if (isCritical) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: SpaceTheme.dangerRed.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: SpaceTheme.dangerRed, width: 1.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.emergency, color: SpaceTheme.dangerRed, size: 24),
                    SizedBox(width: 8),
                    Text(
                      'INTERVENCIÓN PRIORITARIA REQUERIDA',
                      style: TextStyle(
                        color: SpaceTheme.dangerRed,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  astronaut.riskDescription,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: SpaceTheme.dangerRed,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 38),
                  ),
                  icon: const Icon(Icons.medical_services, size: 18),
                  label: const Text('Iniciar Protocolo de Oxigenoterapia & Soporte'),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: SpaceTheme.dangerRed,
                        content: Text('Iniciando guía clínica para ${astronaut.name}'),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        Card(
          color: SpaceTheme.card,
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
                      'Autodiagnóstico Guiado por Síntomas',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Evalúa a ${astronaut.name} respondiendo preguntas clínicas escalonadas para recibir clasificación determinista (Verde, Amarillo, Rojo).',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: SpaceTheme.cyan,
                    foregroundColor: Colors.black,
                  ),
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Comenzar Evaluación Clínica'),
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
        _buildProtocolTile('Hipoxia y Descompresión en Cabina', Icons.air, Colors.cyanAccent),
        _buildProtocolTile('Tratamiento de Cefalea y Congestión SANS', Icons.remove_red_eye, Colors.blueAccent),
        _buildProtocolTile('Quemaduras y Lesiones por Traumatismo', Icons.local_hospital, Colors.greenAccent),
      ],
    );
  }

  Widget _buildProtocolTile(String title, IconData icon, Color color) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: SpaceTheme.card,
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(title, style: const TextStyle(fontSize: 14)),
        trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.white38),
        onTap: () {},
      ),
    );
  }
}
