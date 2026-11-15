import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:astramed/core/constants/medical_thresholds.dart';
import 'package:astramed/core/theme/space_theme.dart';
import 'package:astramed/features/01_general_health/models/vitals_record.dart';
import 'package:astramed/features/crew/models/astronaut_profile.dart';
import 'package:astramed/features/crew/presentation/providers/crew_provider.dart';
import 'package:astramed/features/telemetry/models/telemetry_machine.dart';
import 'package:astramed/features/telemetry/presentation/providers/telemetry_provider.dart';
import 'package:astramed/features/telemetry/presentation/widgets/telemetry_config_modal.dart';

/// Pantalla principal de Salud General conectada al astronauta seleccionado individualmente
class GeneralHealthView extends ConsumerWidget {
  const GeneralHealthView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final astronaut = ref.watch(selectedAstronautProvider);
    final vitals = astronaut.vitals;
    final connectedMachines = ref.watch(connectedMachinesForSelectedProvider);
    final telemetryState = ref.watch(telemetryProvider);

    final isHrNormal = vitals.heartRate >= MedicalThresholds.minHeartRate &&
        vitals.heartRate <= MedicalThresholds.maxHeartRate;
    final isBpNormal = vitals.systolicBP >= MedicalThresholds.minSystolicBP &&
        vitals.systolicBP <= MedicalThresholds.maxSystolicBP;
    final isSpO2Normal = vitals.spO2 >= MedicalThresholds.minSpO2;
    final isTempNormal = vitals.bodyTemp >= 36.0 && vitals.bodyTemp <= 37.2;
    final isRespNormal =
        vitals.respiratoryRate >= 12.0 && vitals.respiratoryRate <= 20.0;
    final isCapillaryNormal = vitals.capillaryRefillSeconds <= 2.0;

    final vitalsSourceTag =
        '${vitals.astronautId} • ${vitals.source.toUpperCase()} • ${vitals.device}';

    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        // ── BANNER DE IDENTIDAD DEL ASTRONAUTA ACTIVO ──
        _buildAstronautHeader(context, astronaut),

        const SizedBox(height: 12),

        // ── BANNER DE ALERTA DE RIESGO SI APLICA ──
        if (astronaut.riskLevel != CrewRiskLevel.nominal) ...[
          _buildRiskBanner(astronaut),
          const SizedBox(height: 12),
        ],

        // ── PANEL DE ENLACE DE TELEMETRÍA Y MÁQUINAS CONECTADAS ──
        _buildTelemetryLinkCard(
          context,
          ref,
          astronaut,
          connectedMachines,
          telemetryState.isLiveStreaming,
        ),

        const SizedBox(height: 16),

        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                'Signos Vitales y Telemetría Médica',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
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
          metadataTag: vitalsSourceTag,
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
          metadataTag: vitalsSourceTag,
          isHealthy: isSpO2Normal,
        ),

        _buildMetricCard(
          icon: Icons.speed,
          iconColor: Colors.blueAccent,
          title: 'Presión Arterial',
          value:
              '${vitals.systolicBP.toInt()} / ${vitals.diastolicBP.toInt()} mmHg',
          status: isBpNormal
              ? 'Óptima (90 - 130 mmHg)'
              : (vitals.systolicBP > 130
                  ? 'Presión arterial elevada'
                  : 'Hipotensión'),
          metadataTag: vitalsSourceTag,
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
          metadataTag: vitalsSourceTag,
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
          metadataTag: vitalsSourceTag,
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
          metadataTag: vitalsSourceTag,
          isHealthy: isTempNormal,
        ),

        _buildMetricCard(
          icon: Icons.bloodtype,
          iconColor: Colors.pinkAccent,
          title: 'Glucosa en Sangre',
          value: '${vitals.bloodGlucose.toInt()} mg/dL',
          status: 'Euglucemia (70 - 140 mg/dL)',
          metadataTag: vitalsSourceTag,
          isHealthy: vitals.bloodGlucose >= 70 && vitals.bloodGlucose <= 140,
        ),

        const SizedBox(height: 16),

        // ── BOTÓN DE MEDICIÓN MANUAL DE EMERGENCIA ──
        _buildManualAssessmentButton(context, ref, astronaut),
      ],
    );
  }

  /// Panel de máquinas conectadas y metadatos de trazabilidad para el astronauta activo
  Widget _buildTelemetryLinkCard(
    BuildContext context,
    WidgetRef ref,
    AstronautProfile astronaut,
    List<TelemetryMachine> connectedMachines,
    bool isLiveStreaming,
  ) {
    final v = astronaut.vitals;
    final isManualSource = v.source.toLowerCase() == 'manual';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: SpaceTheme.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: SpaceTheme.cyan.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isLiveStreaming
                    ? Icons.sensors
                    : Icons.settings_input_antenna,
                color: isLiveStreaming ? SpaceTheme.green : SpaceTheme.cyan,
                size: 18,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Enlace de Telemetría y Equipos',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Colors.white,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: (connectedMachines.isNotEmpty
                          ? SpaceTheme.green
                          : Colors.white38)
                      .withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${connectedMachines.length} activas${isLiveStreaming ? ' • VIVO' : ''}',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: connectedMachines.isNotEmpty
                        ? SpaceTheme.green
                        : Colors.white60,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: SpaceTheme.background.withValues(alpha: 0.75),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: (isManualSource ? Colors.amberAccent : SpaceTheme.cyan)
                    .withValues(alpha: 0.3),
              ),
            ),
            child: Text(
              'astronautId: ${v.astronautId}  •  source: ${v.source}  •  recordType: ${v.recordType}  •  device: ${v.device} (${v.deviceId})\nprotocol: ${v.protocol}  •  method: ${v.measurementMethod}  •  activityState: ${v.activityState}  •  signalQuality: ${v.signalQuality}\nalgorithm: ${v.algorithm}  •  criterionReference: ${v.criterionReference}',
              style: TextStyle(
                fontSize: 10,
                color: isManualSource ? Colors.amberAccent : Colors.white70,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(height: 10),
          if (connectedMachines.isEmpty)
            const Text(
              'No hay máquinas conectadas actualmente para este tripulante.',
              style: TextStyle(fontSize: 11, color: Colors.white54),
            )
          else
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: connectedMachines.map((m) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: SpaceTheme.cyan.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: SpaceTheme.cyan.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.check_circle,
                        size: 11,
                        color: SpaceTheme.green,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        m.code,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: SpaceTheme.cyan,
                  side: const BorderSide(color: SpaceTheme.cyan),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
                icon: const Icon(Icons.tune, size: 15),
                label: const Text(
                  'Configurar Máquinas',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                onPressed: () {
                  TelemetryConfigModal.show(
                    context,
                    initialAstronautId: astronaut.id,
                  );
                },
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: SpaceTheme.cyan,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
                icon: const Icon(Icons.sensors, size: 15),
                label: const Text(
                  'Capturar Telemetría',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                onPressed: connectedMachines.isEmpty
                    ? null
                    : () {
                        final count = ref
                            .read(telemetryProvider.notifier)
                            .pullAllConnectedMachines(astronaut.id);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Se recibieron paquetes de $count máquina(s) conectadas para ${astronaut.name}.',
                            ),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Banner con la información del astronauta actualmente activo
  Widget _buildAstronautHeader(
    BuildContext context,
    AstronautProfile astronaut,
  ) {
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
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
                Text(
                  'ID: ${astronaut.id} | Edad: ${astronaut.age} años | GS: ${astronaut.bloodType}',
                  style: const TextStyle(fontSize: 11, color: Colors.white54),
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
              Icon(
                isCritical ? Icons.emergency : Icons.warning_amber_rounded,
                color: color,
                size: 20,
              ),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
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
    required String metadataTag,
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
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: CircleAvatar(
          backgroundColor: iconColor.withValues(alpha: 0.18),
          child: Icon(icon, color: iconColor),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              status,
              style: TextStyle(
                fontSize: 12,
                color: isHealthy ? Colors.white70 : SpaceTheme.dangerRed,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              metadataTag,
              style: const TextStyle(fontSize: 10, color: Colors.white38),
              overflow: TextOverflow.ellipsis,
            ),
          ],
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

  Widget _buildManualAssessmentButton(
    BuildContext context,
    WidgetRef ref,
    AstronautProfile astronaut,
  ) {
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
        _showManualInputDialog(context, ref, astronaut);
      },
    );
  }

  void _showManualInputDialog(
    BuildContext context,
    WidgetRef ref,
    AstronautProfile astronaut,
  ) {
    final hrController = TextEditingController(
      text: astronaut.vitals.heartRate.toInt().toString(),
    );
    final respController = TextEditingController(
      text: astronaut.vitals.respiratoryRate.toInt().toString(),
    );
    final capController = TextEditingController(
      text: astronaut.vitals.capillaryRefillSeconds.toStringAsFixed(1),
    );
    final tempController = TextEditingController(
      text: astronaut.vitals.bodyTemp.toStringAsFixed(1),
    );

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: SpaceTheme.surface,
          title: Row(
            children: [
              const Icon(Icons.favorite, color: Colors.redAccent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Medición Manual (${astronaut.callsign})',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '• Pulso: Coloca tus dedos índice y medio en carótida o muñeca 15s y multiplica por 4.\n'
                  '• Respiración: Cuenta elevaciones del tórax en 30s y multiplica por 2.\n'
                  '• Llenado Capilar: Presiona una uña 5s y mide cuánto tarda en recuperar el color (< 2.0s normal).',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: hrController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Frecuencia Cardíaca (bpm)',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: respController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Frecuencia Respiratoria (rpm)',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: capController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Tiempo de Llenado Capilar (s)',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: tempController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Temperatura Corporal (°C)',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text(
                'Cancelar',
                style: TextStyle(color: Colors.white60),
              ),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: SpaceTheme.cyan,
                foregroundColor: Colors.black,
              ),
              onPressed: () {
                final newHr =
                    double.tryParse(hrController.text.replaceAll(',', '.')) ??
                        astronaut.vitals.heartRate;
                final newResp =
                    double.tryParse(respController.text.replaceAll(',', '.')) ??
                        astronaut.vitals.respiratoryRate;
                final newCap =
                    double.tryParse(capController.text.replaceAll(',', '.')) ??
                        astronaut.vitals.capillaryRefillSeconds;
                final newTemp =
                    double.tryParse(tempController.text.replaceAll(',', '.')) ??
                        astronaut.vitals.bodyTemp;

                final manualRecord = VitalsRecord(
                  timestamp: DateTime.now(),
                  astronautId: astronaut.id,
                  source: 'manual',
                  deviceId: 'MANUAL-CREW-ASSESSMENT',
                  device: 'Evaluación Manual de Tripulación',
                  protocol: 'Ingreso Manual Offline',
                  measurementMethod:
                      'Registro manual por tripulante (pulsioxímetro / baumanómetro / termómetro)',
                  activityState: 'emergency_triage',
                  signalQuality: 'manual_verified',
                  recordType: 'manual',
                  algorithm: 'DirectCrewEntry v1.0',
                  criterionReference: 'NASA-STD-3001 Vol.2 Vital Limits',
                  heartRate: newHr.clamp(30.0, 220.0),
                  systolicBP: astronaut.vitals.systolicBP,
                  diastolicBP: astronaut.vitals.diastolicBP,
                  spO2: astronaut.vitals.spO2,
                  bodyTemp: newTemp.clamp(32.0, 42.0),
                  bloodGlucose: astronaut.vitals.bloodGlucose,
                  respiratoryRate: newResp.clamp(6.0, 60.0),
                  capillaryRefillSeconds: newCap.clamp(0.5, 10.0),
                );

                ref
                    .read(crewMembersProvider.notifier)
                    .updateVitals(astronaut.id, manualRecord);

                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Registro manual guardado (source: manual) para ${astronaut.name}.',
                    ),
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
              child: const Text(
                'Registrar Manual',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }
}
