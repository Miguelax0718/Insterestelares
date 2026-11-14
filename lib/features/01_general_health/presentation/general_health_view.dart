import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:astramed/core/constants/medical_thresholds.dart';
import 'package:astramed/core/theme/space_theme.dart';
import 'package:astramed/features/01_general_health/domain/scientific_criteria_engine.dart';
import 'package:astramed/features/01_general_health/presentation/providers/telemetry_panel_provider.dart';
import 'package:astramed/features/01_general_health/presentation/widgets/device_availability_card.dart';
import 'package:astramed/features/01_general_health/presentation/widgets/telemetry_charts_section.dart';
import 'package:astramed/features/crew/models/astronaut_profile.dart';
import 'package:astramed/features/crew/presentation/providers/crew_provider.dart';

/// Pantalla principal de Signos Vitales y Telemetría Médica.
///
/// Evalúa variables fisiológicas de forma contextual y descriptiva mediante
/// [ScientificCriteriaEngine], sin diagnósticos automáticos ni valores ficticios.
class GeneralHealthView extends ConsumerWidget {
  const GeneralHealthView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final astronaut = ref.watch(selectedAstronautProvider);
    final vitals = astronaut.vitals;
    final activeContext = ref.watch(activeActivityContextProvider);
    final telemetrySnapshot = ref.watch(telemetrySeriesSnapshotProvider);

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

    final lastUpdateLabel = DateFormat('dd/MM HH:mm').format(vitals.timestamp);

    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        _buildAstronautHeader(context, astronaut),
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

        _buildContextSelector(ref, activeContext),
        const SizedBox(height: 12),

        _buildEvaluatedMetricCard(
          icon: Icons.favorite,
          iconColor: Colors.redAccent,
          title: 'Frecuencia Cardíaca',
          evaluation: hrEval,
          decimals: 0,
        ),
        _buildEvaluatedMetricCard(
          icon: Icons.waves,
          iconColor: Colors.tealAccent,
          title: 'Frecuencia Respiratoria',
          evaluation: rrEval,
          decimals: 1,
        ),
        _buildEvaluatedMetricCard(
          icon: Icons.air,
          iconColor: Colors.cyanAccent,
          title: 'Saturación SpO₂',
          evaluation: spo2Eval,
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
          isHealthy: isGlucoseNormal,
        ),

        const SizedBox(height: 12),
        DeviceAvailabilityCard(devices: telemetrySnapshot.devices),
        const SizedBox(height: 12),
        TelemetryChartsSection(snapshot: telemetrySnapshot),
        const SizedBox(height: 16),
        _buildManualAssessmentButton(context),
      ],
    );
  }

  Widget _buildContextSelector(WidgetRef ref, ActivityContext activeContext) {
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
          const Text(
            'Contexto de evaluación fisiológica',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.white70,
            ),
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
                  ref.read(activeActivityContextProvider.notifier).state = ctx;
                },
              );
            }).toList(),
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
            if (criterion != null) ...[
              const SizedBox(height: 4),
              Text(
                'Fuente: ${criterion.source} (v${criterion.version})',
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
            color: isHealthy ? Colors.white70 : SpaceTheme.warningYellow,
          ),
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
        'Modo Medición Manual (Sin Sensores Automáticos)',
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
      ),
      onPressed: () => _showManualInputDialog(context),
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
              Expanded(child: Text('Asistente de Medición Manual')),
            ],
          ),
          content: const Text(
            'Alternativa manual cuando no hay sensores automáticos:\n\n'
            '• Frecuencia cardíaca: coloca índice y medio en arteria carótida o radial, cuenta 15 s y multiplica por 4 (lpm).\n'
            '• Frecuencia respiratoria: cuenta ciclos respiratorios completos en 60 s (o 30 s × 2) (rpm).\n'
            '• SpO₂: introduce únicamente lecturas de un pulsioxímetro validado.\n\n'
            'Las entradas manuales se conservan diferenciadas de la telemetría instrumental.',
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text(
                'Cerrar',
                style: TextStyle(color: SpaceTheme.cyan),
              ),
            ),
          ],
        );
      },
    );
  }
}
