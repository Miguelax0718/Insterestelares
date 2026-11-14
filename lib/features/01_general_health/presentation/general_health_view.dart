import 'package:flutter/material.dart';

class GeneralHealthView extends StatelessWidget {
  const GeneralHealthView({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        const Text(
          'Monitoreo de Signos Vitales',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          'Telemetría médica en tiempo real (100% Offline)',
          style: TextStyle(color: Colors.white70),
        ),
        const SizedBox(height: 16),
        _buildMetricCard(
          icon: Icons.favorite,
          iconColor: Colors.redAccent,
          title: 'Frecuencia Cardíaca',
          value: '72 bpm',
          status: 'Normal (50 - 100 bpm)',
          isHealthy: true,
        ),
        _buildMetricCard(
          icon: Icons.speed,
          iconColor: Colors.blueAccent,
          title: 'Presión Arterial',
          value: '120 / 80 mmHg',
          status: 'Óptima',
          isHealthy: true,
        ),
        _buildMetricCard(
          icon: Icons.air,
          iconColor: Colors.cyanAccent,
          title: 'Saturación SpO2',
          value: '98 %',
          status: 'Estable (> 95%)',
          isHealthy: true,
        ),
        _buildMetricCard(
          icon: Icons.thermostat,
          iconColor: Colors.orangeAccent,
          title: 'Temperatura Corporal',
          value: '36.8 °C',
          status: 'Normotermia',
          isHealthy: true,
        ),
      ],
    );
  }

  Widget _buildMetricCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
    required String status,
    required bool isHealthy,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: iconColor.withValues(alpha: 0.2),
          child: Icon(icon, color: iconColor),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(status),
        trailing: Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: isHealthy ? Colors.greenAccent : Colors.redAccent,
          ),
        ),
      ),
    );
  }
}
