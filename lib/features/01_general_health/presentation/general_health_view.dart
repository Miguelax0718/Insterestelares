import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:astramed/core/constants/medical_thresholds.dart';
import 'package:astramed/core/theme/space_theme.dart';
import 'package:astramed/features/01_general_health/domain/scientific_criteria_engine.dart';
import 'package:astramed/features/01_general_health/models/vitals_record.dart';
import 'package:astramed/features/01_general_health/presentation/providers/telemetry_panel_provider.dart';
import 'package:astramed/features/01_general_health/presentation/widgets/device_availability_card.dart';
import 'package:astramed/features/01_general_health/presentation/widgets/gamified_health_guide_card.dart';
import 'package:astramed/features/crew/models/astronaut_profile.dart';
import 'package:astramed/features/crew/presentation/providers/crew_provider.dart';
import 'package:astramed/features/telemetry/models/telemetry_machine.dart';
import 'package:astramed/features/telemetry/presentation/providers/telemetry_provider.dart';
import 'package:astramed/features/telemetry/presentation/widgets/telemetry_config_modal.dart';

/// Pantalla principal de Signos Vitales y Telemetría Médica conectada al
/// astronauta seleccionado, al bus de telemetría y al motor de criterios científicos.
class GeneralHealthView extends ConsumerWidget {
  const GeneralHealthView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final astronaut = ref.watch(selectedAstronautProvider);
    final telemetryState = ref.watch(telemetryProvider);
    final vitals = astronaut.vitals;
    final telemetrySnapshot = ref.watch(telemetrySeriesSnapshotProvider);

    final detectedContext = mapActivityStateToContext(vitals.activityState);
    final manualOverride = ref.watch(manualActivityContextOverrideProvider);
    final activeContext = manualOverride ?? detectedContext;

    final connectedMachines = telemetryState.machines
        .where((m) => m.isConnectedFor(astronaut.id))
        .toList();

    final hrEval = ScientificCriteriaEngine.evaluateHeartRate(
      bpm: vitals.heartRate,
      context: activeContext,
      individualBaselineBpm: telemetrySnapshot.individualHrBaselineBpm,
    );
    final rrEval = ScientificCriteriaEngine.evaluateRespiratoryRate(
      rpm: vitals.respiratoryRate,
      context: activeContext,
      individualBaselineRpm: telemetrySnapshot.individualRrBaselineRpm,
    );
    final spo2Eval = ScientificCriteriaEngine.evaluateSpO2(
      percent: vitals.spO2,
      context: activeContext,
      individualBaselinePercent: telemetrySnapshot.individualSpo2BaselinePercent,
    );

    final isBpNormal = vitals.systolicBP >= MedicalThresholds.minSystolicBP &&
        vitals.systolicBP <= MedicalThresholds.maxSystolicBP;
    final isTempNormal = vitals.bodyTemp >= 36.0 && vitals.bodyTemp <= 37.2;
    final isCapillaryNormal = vitals.capillaryRefillSeconds <= 2.0;
    final isGlucoseNormal =
        vitals.bloodGlucose >= 70 && vitals.bloodGlucose <= 140;

    final lastUpdateLabel = DateFormat('dd/MM HH:mm:ss').format(vitals.timestamp);
    final metadataTag =
        '${vitals.device} • ${vitals.recordType} • ${vitals.signalQuality}';

    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        _buildAstronautHeader(context, astronaut),
        const SizedBox(height: 12),

        _buildTelemetryLinkCard(
          context,
          ref,
          astronaut,
          connectedMachines,
          telemetryState.isLiveStreaming,
        ),
        const SizedBox(height: 12),

        if (astronaut.riskLevel != CrewRiskLevel.nominal) ...[
          _buildRiskBanner(astronaut),
          const SizedBox(height: 12),
        ],

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Expanded(
              child: Text(
                'Signos Vitales y Telemetría Médica',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            Row(
              children: [
                const Icon(Icons.lock_clock, size: 14, color: SpaceTheme.cyan),
                const SizedBox(width: 4),
                Text(
                  'Act: $lastUpdateLabel',
                  style: const TextStyle(fontSize: 11, color: SpaceTheme.cyan),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 10),

        _buildContextSelector(
          ref,
          activeContext: activeContext,
          detectedContext: detectedContext,
          rawActivityState: vitals.activityState,
          isManualOverride: manualOverride != null,
        ),
        const SizedBox(height: 12),

        _buildEvaluatedMetricCard(
          icon: Icons.favorite,
          iconColor: Colors.redAccent,
          title: 'Frecuencia Cardíaca',
          evaluation: hrEval,
          metadataTag: metadataTag,
          decimals: 0,
        ),
        _buildEvaluatedMetricCard(
          icon: Icons.waves,
          iconColor: Colors.tealAccent,
          title: 'Frecuencia Respiratoria',
          evaluation: rrEval,
          metadataTag: metadataTag,
          decimals: 1,
        ),
        _buildEvaluatedMetricCard(
          icon: Icons.air,
          iconColor: Colors.cyanAccent,
          title: 'Saturación SpO₂',
          evaluation: spo2Eval,
          metadataTag: metadataTag,
          decimals: 0,
        ),

        _buildMetricCard(
          icon: Icons.speed,
          iconColor: Colors.blueAccent,
          title: 'Presión Arterial',
          value:
              '${vitals.systolicBP.toInt()} / ${vitals.diastolicBP.toInt()} mmHg',
          status: isBpNormal
              ? 'Dentro de rango orientativo (90–130 mmHg sistólica)'
              : 'Fuera de rango orientativo (90–130 mmHg sistólica)',
          metadataTag: metadataTag,
          isHealthy: isBpNormal,
        ),
        _buildMetricCard(
          icon: Icons.touch_app,
          iconColor: Colors.purpleAccent,
          title: 'Tiempo de Llenado Capilar',
          value: '${vitals.capillaryRefillSeconds.toStringAsFixed(1)} s',
          status: isCapillaryNormal
              ? 'Registro dentro de referencia (<2 s)'
              : 'Registro prolongado (>2 s) • Verificar perfusión y temperatura',
          metadataTag: metadataTag,
          isHealthy: isCapillaryNormal,
        ),
        _buildMetricCard(
          icon: Icons.thermostat,
          iconColor: Colors.orangeAccent,
          title: 'Temperatura Corporal',
          value: '${vitals.bodyTemp.toStringAsFixed(1)} °C',
          status: isTempNormal
              ? 'Dentro de intervalo orientativo (36.0–37.2 °C)'
              : 'Fuera de intervalo orientativo (36.0–37.2 °C)',
          metadataTag: metadataTag,
          isHealthy: isTempNormal,
        ),
        _buildMetricCard(
          icon: Icons.bloodtype,
          iconColor: Colors.pinkAccent,
          title: 'Glucosa en Sangre',
          value: '${vitals.bloodGlucose.toInt()} mg/dL',
          status: isGlucoseNormal
              ? 'Dentro de intervalo orientativo (70–140 mg/dL)'
              : 'Fuera de intervalo orientativo (70–140 mg/dL)',
          metadataTag: metadataTag,
          isHealthy: isGlucoseNormal,
        ),

        const SizedBox(height: 12),
        GamifiedHealthGuideCard(
          snapshot: telemetrySnapshot,
          activeContext: activeContext,
          vitals: vitals,
        ),
        const SizedBox(height: 12),
        DeviceAvailabilityCard(devices: telemetrySnapshot.devices),
        const SizedBox(height: 16),
        _buildManualAssessmentButton(context, ref, astronaut),
      ],
    );
  }

  Widget _buildContextSelector(
    WidgetRef ref, {
    required ActivityContext activeContext,
    required ActivityContext detectedContext,
    required String rawActivityState,
    required bool isManualOverride,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: SpaceTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  isManualOverride
                      ? 'Contexto manual: ${activeContext.label} (telemetría: $rawActivityState)'
                      : 'Contexto automático desde telemetría: ${detectedContext.label} ($rawActivityState)',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.white70,
                  ),
                ),
              ),
              if (isManualOverride)
                TextButton(
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                  ),
                  onPressed: () {
                    ref
                        .read(manualActivityContextOverrideProvider.notifier)
                        .state = null;
                  },
                  child: const Text(
                    'Usar auto',
                    style: TextStyle(fontSize: 11, color: SpaceTheme.cyan),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: ActivityContext.values.map((ctx) {
              final selected = ctx == activeContext;
              return ChoiceChip(
                label: Text(ctx.label),
                selected: selected,
                visualDensity: VisualDensity.compact,
                selectedColor: SpaceTheme.cyan.withValues(alpha: 0.25),
                backgroundColor: SpaceTheme.card,
                labelStyle: TextStyle(
                  fontSize: 11,
                  color: selected ? SpaceTheme.cyan : Colors.white70,
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                ),
                onSelected: (_) {
                  ref
                      .read(manualActivityContextOverrideProvider.notifier)
                      .state = ctx;
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildTelemetryLinkCard(
    BuildContext context,
    WidgetRef ref,
    AstronautProfile astronaut,
    List<TelemetryMachine> connectedMachines,
    bool isLiveStreaming,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: SpaceTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: connectedMachines.isNotEmpty
              ? SpaceTheme.cyan.withValues(alpha: 0.5)
              : Colors.white12,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isLiveStreaming ? Icons.sensors : Icons.sensors_off,
                color: isLiveStreaming ? SpaceTheme.green : SpaceTheme.cyan,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Equipos de Telemetría (${connectedMachines.length} conectados)',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              if (isLiveStreaming)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: SpaceTheme.green.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'LIVE',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: SpaceTheme.green,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (connectedMachines.isNotEmpty)
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: connectedMachines.map((m) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: SpaceTheme.card,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.white12),
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

  Widget _buildEvaluatedMetricCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required EvaluationResult evaluation,
    required String metadataTag,
    required int decimals,
  }) {
    final Color statusColor;
    switch (evaluation.severity) {
      case EvaluationSeverity.noData:
        statusColor = Colors.white54;
      case EvaluationSeverity.descriptive:
        statusColor = Colors.greenAccent;
      case EvaluationSeverity.informativeNotice:
        statusColor = SpaceTheme.warningYellow;
      case EvaluationSeverity.operationalAlert:
        statusColor = SpaceTheme.dangerRed;
    }

    final displayValue = evaluation.hasData
        ? '${evaluation.value!.toStringAsFixed(decimals)} ${evaluation.unit}'
        : 'Sin datos';

    final criterion = evaluation.appliedCriterion;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: SpaceTheme.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: evaluation.severity == EvaluationSeverity.operationalAlert
              ? SpaceTheme.dangerRed
              : (evaluation.severity == EvaluationSeverity.informativeNotice
                  ? SpaceTheme.warningYellow.withValues(alpha: 0.7)
                  : Colors.white12),
          width: 1.1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: iconColor.withValues(alpha: 0.18),
                  child: Icon(icon, color: iconColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        'Contexto: ${evaluation.context.label} • ${evaluation.severity.label}',
                        style: TextStyle(fontSize: 11, color: statusColor),
                      ),
                    ],
                  ),
                ),
                Text(
                  displayValue,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              evaluation.summary,
              style: const TextStyle(fontSize: 12, color: Colors.white70),
            ),
            const SizedBox(height: 4),
            Text(
              metadataTag,
              style: const TextStyle(fontSize: 10, color: Colors.white38),
              overflow: TextOverflow.ellipsis,
            ),
            if (criterion != null) ...[
              const SizedBox(height: 2),
              Text(
                'Criterio: ${criterion.source} (v${criterion.version})',
                style: const TextStyle(fontSize: 10, color: Colors.white38),
              ),
            ],
          ],
        ),
      ),
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
                  'Edad: ${astronaut.age} años | GS: ${astronaut.bloodType}',
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
          color: isHealthy ? Colors.white12 : SpaceTheme.warningYellow,
          width: isHealthy ? 1.0 : 1.3,
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
                color: isHealthy ? Colors.white70 : SpaceTheme.warningYellow,
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
            color: isHealthy ? Colors.greenAccent : SpaceTheme.warningYellow,
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
      onPressed: () => _showManualInputDialog(context, ref, astronaut),
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
                  '• Pulso: Coloca índice y medio en carótida o muñeca 15s y multiplica por 4.\n'
                  '• Respiración: Cuenta ciclos respiratorios en 30s y multiplica por 2.\n'
                  '• Llenado Capilar: Presiona una uña 5s y mide recuperación (< 2.0s).',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: hrController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Frecuencia Cardíaca (lpm)',
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
              },
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );
  }
}
