import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/medical_thresholds.dart';
import '../../../core/theme/space_theme.dart';
import '../../crew/models/astronaut_profile.dart';
import '../../crew/presentation/providers/crew_provider.dart';

/// Pantalla principal de Salud General conectada al astronauta seleccionado individualmente
class GeneralHealthView extends ConsumerWidget {
  const GeneralHealthView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final astronaut = ref.watch(selectedAstronautProvider);
    final vitals = astronaut.vitals;

    final isHrNormal = vitals.heartRate >= MedicalThresholds.minHeartRate &&
        vitals.heartRate <= MedicalThresholds.maxHeartRate;
    final isBpNormal = vitals.systolicBP >= MedicalThresholds.minSystolicBP &&
        vitals.systolicBP <= MedicalThresholds.maxSystolicBP;
    final isSpO2Normal = vitals.spO2 >= MedicalThresholds.minSpO2;
    final isTempNormal = vitals.bodyTemp >= 36.0 && vitals.bodyTemp <= 37.2;
    final isRespNormal = vitals.respiratoryRate >= 12.0 && vitals.respiratoryRate <= 20.0;
    final isCapillaryNormal = vitals.capillaryRefillSeconds <= 2.0;

    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        // ── BANNER DE IDENTIDAD DEL ASTRONAUTA ACTIVO ──
        _buildAstronautHeader(context, astronaut),

        const SizedBox(height: 12),

        // ── BANNER DE ALERTA DE RIESGO SI APLICA ──
        if (astronaut.riskLevel != CrewRiskLevel.nominal)
          _buildRiskBanner(astronaut),

        const SizedBox(height: 16),

        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Signos Vitales y Telemetría Médica',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Row(
              children: [
                Icon(Icons.lock_clock, size: 14, color: SpaceTheme.cyan),
                SizedBox(width: 4),
                Text(
                  'Offline Sync',
                  style: TextStyle(fontSize: 12, color: SpaceTheme.cyan),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),

        // ── TARJETAS DE SIGNOS VITALES ──
        _buildMetricCard(
          icon: Icons.favorite,
          iconColor: Colors.redAccent,
          title: 'Frecuencia Cardíaca',
          value: '${vitals.heartRate.toInt()} bpm',
          status: isHrNormal
              ? 'Normal (50 - 100 bpm)'
              : (vitals.heartRate > 100
                  ? 'Taquicardia severa (>100 bpm)'
                  : 'Bradicardia (<50 bpm)'),
          isHealthy: isHrNormal,
        ),

        _buildMetricCard(
          icon: Icons.air,
          iconColor: Colors.cyanAccent,
          title: 'Saturación SpO2',
          value: '${vitals.spO2.toInt()} %',
          status: isSpO2Normal
              ? 'Estable (≥94%)'
              : (vitals.spO2 < 90
                  ? 'ALERTA: Hipoxia aguda (<90%)'
                  : 'Atención: Desaturación leve'),
          isHealthy: isSpO2Normal,
        ),

        _buildMetricCard(
          icon: Icons.speed,
          iconColor: Colors.blueAccent,
          title: 'Presión Arterial',
          value: '${vitals.systolicBP.toInt()} / ${vitals.diastolicBP.toInt()} mmHg',
          status: isBpNormal
              ? 'Óptima (90 - 130 mmHg)'
              : (vitals.systolicBP > 130
                  ? 'Presión arterial elevada'
                  : 'Hipotensión'),
          isHealthy: isBpNormal,
        ),

        _buildMetricCard(
          icon: Icons.waves,
          iconColor: Colors.tealAccent,
          title: 'Frecuencia Respiratoria',
          value: '${vitals.respiratoryRate.toInt()} rpm',
          status: isRespNormal
              ? 'Eupnea / Normal (12 - 20 rpm)'
              : (vitals.respiratoryRate > 20
                  ? 'Polipnea / Taquipnea (Sobreesfuerzo / CO2)'
                  : 'Bradipnea'),
          isHealthy: isRespNormal,
        ),

        _buildMetricCard(
          icon: Icons.touch_app,
          iconColor: Colors.purpleAccent,
          title: 'Tiempo de Llenado Capilar',
          value: '${vitals.capillaryRefillSeconds.toStringAsFixed(1)} s',
          status: isCapillaryNormal
              ? 'Perfusión periférica óptima (<2s)'
              : 'Perfusión lenta / Vasoconstricción (>2s)',
          isHealthy: isCapillaryNormal,
        ),

        _buildMetricCard(
          icon: Icons.thermostat,
          iconColor: Colors.orangeAccent,
          title: 'Temperatura Corporal',
          value: '${vitals.bodyTemp.toStringAsFixed(1)} °C',
          status: isTempNormal
              ? 'Normotermia'
              : (vitals.bodyTemp > 37.2
                  ? 'Febrícula / Estrés térmico'
                  : 'Hipotermia'),
          isHealthy: isTempNormal,
        ),

        _buildMetricCard(
          icon: Icons.bloodtype,
          iconColor: Colors.pinkAccent,
          title: 'Glucosa en Sangre',
          value: '${vitals.bloodGlucose.toInt()} mg/dL',
          status: 'Euglucemia (70 - 140 mg/dL)',
          isHealthy: vitals.bloodGlucose >= 70 && vitals.bloodGlucose <= 140,
        ),

        const SizedBox(height: 16),

        // ── BOTÓN DE MEDICIÓN MANUAL DE EMERGENCIA ──
        _buildManualAssessmentButton(context),
      ],
    );
  }

  /// Banner con la información del astronauta actualmente activo
  Widget _buildAstronautHeader(BuildContext context, AstronautProfile astronaut) {
    final statusColor = astronaut.riskLevel == CrewRiskLevel.critical
        ? SpaceTheme.dangerRed
        : (astronaut.riskLevel == CrewRiskLevel.warning
            ? SpaceTheme.warningYellow
            : SpaceTheme.green);

    return Container(
      padding: const EdgeInsets.all(14.0),
      decoration: BoxDecoration(
        color: SpaceTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: astronaut.riskLevel == CrewRiskLevel.critical
              ? SpaceTheme.dangerRed
              : SpaceTheme.cyan.withValues(alpha: 0.4),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: statusColor.withValues(alpha: 0.2),
            child: Text(
              astronaut.avatarInitials,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: statusColor,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        astronaut.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: SpaceTheme.cyan.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        astronaut.callsign,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: SpaceTheme.cyan,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${astronaut.role} • ${astronaut.currentZone}',
                  style: const TextStyle(fontSize: 12, color: Colors.white70),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      'Edad: ${astronaut.age} años | GS: ${astronaut.bloodType}',
                      style: const TextStyle(fontSize: 11, color: Colors.white54),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Banner que se activa si el astronauta tiene un estado de advertencia o crítico
  Widget _buildRiskBanner(AstronautProfile astronaut) {
    final isCritical = astronaut.riskLevel == CrewRiskLevel.critical;
    final color = isCritical ? SpaceTheme.dangerRed : SpaceTheme.warningYellow;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(isCritical ? Icons.emergency : Icons.warning_amber_rounded, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  astronaut.riskTitle,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            astronaut.riskDescription,
            style: const TextStyle(fontSize: 12, color: Colors.white),
          ),
          if (astronaut.activeAlerts.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: astronaut.activeAlerts.map((alert) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    alert,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
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
      margin: const EdgeInsets.only(bottom: 10),
      color: SpaceTheme.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isHealthy ? Colors.white12 : SpaceTheme.dangerRed,
          width: isHealthy ? 1.0 : 1.5,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        leading: CircleAvatar(
          backgroundColor: iconColor.withValues(alpha: 0.18),
          child: Icon(icon, color: iconColor),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        subtitle: Text(
          status,
          style: TextStyle(
            fontSize: 12,
            color: isHealthy ? Colors.white70 : SpaceTheme.dangerRed,
          ),
        ),
        trailing: Text(
          value,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: isHealthy ? Colors.greenAccent : SpaceTheme.dangerRed,
          ),
        ),
      ),
    );
  }

  Widget _buildManualAssessmentButton(BuildContext context) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: SpaceTheme.surface,
        foregroundColor: SpaceTheme.cyan,
        side: const BorderSide(color: SpaceTheme.cyan, width: 1.2),
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      icon: const Icon(Icons.touch_app),
      label: const Text(
        'Modo Medición Manual de Emergencia (Sin Sensores)',
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
      ),
      onPressed: () {
        _showManualInputDialog(context);
      },
    );
  }

  void _showManualInputDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: SpaceTheme.surface,
          title: const Row(
            children: [
              Icon(Icons.favorite, color: Colors.redAccent),
              SizedBox(width: 8),
              Text('Asistente de Pulso Manual'),
            ],
          ),
          content: const Text(
            'Coloca tus dedos índice y medio en la arteria carótida o radial.\n\n'
            'Cuenta los latidos durante 15 segundos y multiplícalos por 4.\n'
            'Verifica también la frecuencia respiratoria (expansiones del tórax en 30s) y el tiempo de llenado capilar (< 2 segundos).',
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cerrar', style: TextStyle(color: SpaceTheme.cyan)),
            ),
          ],
        );
      },
    );
  }
}
