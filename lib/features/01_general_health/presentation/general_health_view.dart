import 'dart:async';
import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:astramed/core/constants/medical_thresholds.dart';
import 'package:astramed/core/theme/space_theme.dart';
import 'package:astramed/features/01_general_health/models/vitals_record.dart';
import 'package:astramed/features/01_general_health/presentation/vitals_trend_card.dart';
import 'package:astramed/features/agent/providers/agent_providers.dart';
import 'package:astramed/features/crew/models/astronaut_profile.dart';
import 'package:astramed/features/crew/presentation/providers/crew_provider.dart';
import 'package:astramed/features/telemetry/models/telemetry_machine.dart';
import 'package:astramed/features/telemetry/presentation/providers/telemetry_provider.dart';
import 'package:astramed/features/telemetry/presentation/widgets/telemetry_config_modal.dart';

/// Pantalla principal de Salud General conectada al astronauta seleccionado individualmente
class GeneralHealthView extends ConsumerStatefulWidget {
  const GeneralHealthView({super.key});

  @override
  ConsumerState<GeneralHealthView> createState() => _GeneralHealthViewState();
}

class _GeneralHealthViewState extends ConsumerState<GeneralHealthView> {
  String _selectedChartMetric = 'heartRate';

  @override
  void initState() {
    super.initState();
    Future.microtask(_consumePendingManualVitals);
  }

  void _consumePendingManualVitals() {
    if (!mounted) return;
    final shouldOpen = ref.read(pendingManualVitalsDialogProvider);
    if (!shouldOpen) return;
    ref.read(pendingManualVitalsDialogProvider.notifier).state = false;
    final astronaut = ref.read(selectedAstronautProvider);
    _showManualInputDialog(context, ref, astronaut);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<bool>(pendingManualVitalsDialogProvider, (_, shouldOpen) {
      if (!shouldOpen) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _consumePendingManualVitals();
      });
    });

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

        // ── GRÁFICO HISTÓRICO DE TENDENCIAS CON FL_CHART ──
        _buildVitalsHistoryChartCard(astronaut, telemetryState),
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

        // ── TENDENCIA DE LA MISIÓN (DB/samples/vitals) ──
        VitalsTrendCard(astronautId: astronaut.id),

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

  Widget _buildVitalsHistoryChartCard(
    AstronautProfile astronaut,
    TelemetryState telemetryState,
  ) {
    final specs = _vitalsChartSpecs;
    final spec = specs.firstWhere(
      (s) => s.metricKey == _selectedChartMetric,
      orElse: () => specs.first,
    );

    final matchingPackets = telemetryState.recentLogs
        .where(
          (packet) =>
              packet.astronautId == astronaut.id &&
              packet.metrics[spec.metricKey] is num,
        )
        .toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    final recentValues = matchingPackets
        .map((p) => (p.metrics[spec.metricKey] as num).toDouble())
        .toList();
    final recentPoints = recentValues.length > 12
        ? recentValues.sublist(recentValues.length - 12)
        : recentValues;

    final currentValue = spec.currentValueOf(astronaut.vitals);
    final hasLiveHistory = recentPoints.length >= 2;
    final values = hasLiveHistory
        ? [...recentPoints, currentValue]
        : [
            for (final delta in spec.fallbackOffsets) currentValue + delta,
            currentValue,
          ];

    final minSample = values.reduce(math.min);
    final maxSample = values.reduce(math.max);
    final minY = math.min(spec.chartMinY, minSample - spec.yPadding);
    final maxY = math.max(spec.chartMaxY, maxSample + spec.yPadding);
    final spots = [
      for (var i = 0; i < values.length; i++)
        FlSpot(i.toDouble(), values[i]),
    ];

    final isCurrentHealthy =
        currentValue >= spec.minNormal && currentValue <= spec.maxNormal;

    return Card(
      color: SpaceTheme.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: spec.color.withValues(alpha: 0.38),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.show_chart, color: spec.color, size: 20),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Tendencia Histórica de Signos Vitales',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: (hasLiveHistory ? SpaceTheme.cyan : Colors.white24)
                        .withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    hasLiveHistory ? 'Telemetría en vivo' : 'Base local',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: hasLiveHistory ? SpaceTheme.cyan : Colors.white70,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: specs.map((item) {
                final selected = item.metricKey == spec.metricKey;
                return ChoiceChip(
                  selected: selected,
                  selectedColor: item.color.withValues(alpha: 0.22),
                  backgroundColor: SpaceTheme.background,
                  side: BorderSide(
                    color: selected ? item.color : Colors.white12,
                  ),
                  label: Text(
                    item.label,
                    style: TextStyle(
                      fontSize: 11,
                      color: selected ? item.color : Colors.white70,
                      fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  onSelected: (_) {
                    setState(() => _selectedChartMetric = item.metricKey);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 155,
              child: LineChart(
                LineChartData(
                  minX: 0,
                  maxX: math.max(1, spots.length - 1).toDouble(),
                  minY: minY,
                  maxY: maxY,
                  clipData: const FlClipData.all(),
                  rangeAnnotations: RangeAnnotations(
                    horizontalRangeAnnotations: [
                      HorizontalRangeAnnotation(
                        y1: spec.minNormal,
                        y2: spec.maxNormal,
                        color: SpaceTheme.green.withValues(alpha: 0.08),
                      ),
                    ],
                  ),
                  gridData: FlGridData(
                    drawVerticalLine: false,
                    horizontalInterval: spec.yInterval,
                    getDrawingHorizontalLine: (_) =>
                        const FlLine(color: Colors.white10, strokeWidth: 1),
                  ),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        interval: spec.yInterval,
                        getTitlesWidget: (v, _) => Text(
                          spec.formatAxisValue(v),
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.white54,
                          ),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: 1,
                        getTitlesWidget: (v, _) {
                          final idx = v.toInt();
                          if (idx == 0 || idx == spots.length - 1) {
                            return Text(
                              idx == spots.length - 1 ? 'Actual' : 't0',
                              style: const TextStyle(
                                fontSize: 10,
                                color: Colors.white54,
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ),
                  ),
                  extraLinesData: ExtraLinesData(
                    horizontalLines: [
                      HorizontalLine(
                        y: spec.minNormal,
                        color: SpaceTheme.green.withValues(alpha: 0.45),
                        strokeWidth: 1,
                        dashArray: [5, 4],
                      ),
                      HorizontalLine(
                        y: spec.maxNormal,
                        color: SpaceTheme.warningYellow.withValues(alpha: 0.45),
                        strokeWidth: 1,
                        dashArray: [5, 4],
                      ),
                    ],
                  ),
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipColor: (_) => SpaceTheme.surface,
                      fitInsideHorizontally: true,
                      fitInsideVertically: true,
                      getTooltipItems: (touched) => [
                        for (final t in touched)
                          LineTooltipItem(
                            '${spec.formatReading(t.y)} ${spec.unit}',
                            TextStyle(
                              color: spec.color,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      color: spec.color,
                      barWidth: 2.4,
                      belowBarData: BarAreaData(
                        show: true,
                        color: spec.color.withValues(alpha: 0.14),
                      ),
                      dotData: FlDotData(
                        getDotPainter: (spot, _, _, _) => FlDotCirclePainter(
                          radius: 3.2,
                          color: (spot.y >= spec.minNormal &&
                                  spot.y <= spec.maxNormal)
                              ? SpaceTheme.green
                              : SpaceTheme.dangerRed,
                          strokeWidth: 1,
                          strokeColor: SpaceTheme.background,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Actual: ${spec.formatReading(currentValue)} ${spec.unit} • Rango NASA: ${spec.formatAxisValue(spec.minNormal)}–${spec.formatAxisValue(spec.maxNormal)} ${spec.unit}',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: isCurrentHealthy
                          ? Colors.white70
                          : SpaceTheme.warningYellow,
                    ),
                  ),
                ),
                Text(
                  '${spots.length} pts',
                  style: const TextStyle(fontSize: 11, color: Colors.white54),
                ),
              ],
            ),
          ],
        ),
      ),
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
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _TapCounterPanel(
                    title: 'Pulso Manual (Carótida o Muñeca · 15s)',
                    instruction:
                        'Coloca dedos índice y medio sobre arteria radial o carótida y toca el botón en cada latido durante 15s (multiplica ×4 automáticamente).',
                    windowSeconds: 15,
                    multiplier: 4,
                    unit: 'bpm',
                    accentColor: Colors.redAccent,
                    icon: Icons.favorite,
                    onApplied: (value) {
                      hrController.text = value.toString();
                    },
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: hrController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Frecuencia Cardíaca (bpm)',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _TapCounterPanel(
                    title: 'Frecuencia Respiratoria (Tórax · 30s)',
                    instruction:
                        'Observa cada elevación del pecho y toca el botón durante 30s (multiplica ×2 automáticamente).',
                    windowSeconds: 30,
                    multiplier: 2,
                    unit: 'rpm',
                    accentColor: Colors.tealAccent,
                    icon: Icons.air,
                    onApplied: (value) {
                      respController.text = value.toString();
                    },
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
                  const SizedBox(height: 14),
                  _CapillaryStopwatchPanel(
                    onMeasured: (seconds) {
                      capController.text = seconds.toStringAsFixed(1);
                    },
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
                  const SizedBox(height: 12),
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

class _VitalsChartSpec {
  final String metricKey;
  final String label;
  final String unit;
  final double minNormal;
  final double maxNormal;
  final double chartMinY;
  final double chartMaxY;
  final double yInterval;
  final double yPadding;
  final List<double> fallbackOffsets;
  final Color color;
  final bool decimal;
  final double Function(VitalsRecord) currentValueOf;

  const _VitalsChartSpec({
    required this.metricKey,
    required this.label,
    required this.unit,
    required this.minNormal,
    required this.maxNormal,
    required this.chartMinY,
    required this.chartMaxY,
    required this.yInterval,
    required this.yPadding,
    required this.fallbackOffsets,
    required this.color,
    required this.currentValueOf,
    this.decimal = false,
  });

  String formatAxisValue(double value) =>
      decimal ? value.toStringAsFixed(1) : value.round().toString();

  String formatReading(double value) =>
      decimal ? value.toStringAsFixed(1) : value.round().toString();
}

final List<_VitalsChartSpec> _vitalsChartSpecs = [
  _VitalsChartSpec(
    metricKey: 'heartRate',
    label: 'Pulso (bpm)',
    unit: 'bpm',
    minNormal: MedicalThresholds.minHeartRate,
    maxNormal: MedicalThresholds.maxHeartRate,
    chartMinY: 45,
    chartMaxY: 145,
    yInterval: 20,
    yPadding: 8,
    fallbackOffsets: const [-4, -2, 1, -1, 2],
    color: Colors.redAccent,
    currentValueOf: (v) => v.heartRate,
  ),
  _VitalsChartSpec(
    metricKey: 'spO2',
    label: 'SpO₂ (%)',
    unit: '%',
    minNormal: MedicalThresholds.minSpO2,
    maxNormal: 100,
    chartMinY: 85,
    chartMaxY: 101,
    yInterval: 5,
    yPadding: 2,
    fallbackOffsets: const [1, 0, -1, 0, 1],
    color: SpaceTheme.cyan,
    currentValueOf: (v) => v.spO2,
  ),
  _VitalsChartSpec(
    metricKey: 'systolicBP',
    label: 'PA Sistólica',
    unit: 'mmHg',
    minNormal: MedicalThresholds.minSystolicBP,
    maxNormal: MedicalThresholds.maxSystolicBP,
    chartMinY: 75,
    chartMaxY: 165,
    yInterval: 20,
    yPadding: 10,
    fallbackOffsets: const [-3, 2, -1, 4, 1],
    color: Colors.blueAccent,
    currentValueOf: (v) => v.systolicBP,
  ),
  _VitalsChartSpec(
    metricKey: 'bodyTemp',
    label: 'Temp (°C)',
    unit: '°C',
    minNormal: 36.0,
    maxNormal: 37.2,
    chartMinY: 35.0,
    chartMaxY: 39.0,
    yInterval: 1.0,
    yPadding: 0.4,
    fallbackOffsets: const [-0.2, -0.1, 0.1, 0.0, 0.2],
    color: Colors.orangeAccent,
    decimal: true,
    currentValueOf: (v) => v.bodyTemp,
  ),
];

/// Widget reutilizable "Tap-to-Count" con temporizador regresivo para pulso (15s ×4)
/// o frecuencia respiratoria (30s ×2).
class _TapCounterPanel extends StatefulWidget {
  final String title;
  final String instruction;
  final int windowSeconds;
  final int multiplier;
  final String unit;
  final Color accentColor;
  final IconData icon;
  final ValueChanged<int> onApplied;

  const _TapCounterPanel({
    required this.title,
    required this.instruction,
    required this.windowSeconds,
    required this.multiplier,
    required this.unit,
    required this.accentColor,
    required this.icon,
    required this.onApplied,
  });

  @override
  State<_TapCounterPanel> createState() => _TapCounterPanelState();
}

class _TapCounterPanelState extends State<_TapCounterPanel> {
  Timer? _timer;
  bool _running = false;
  bool _completed = false;
  int _remainingSeconds = 0;
  int _taps = 0;

  @override
  void initState() {
    super.initState();
    _remainingSeconds = widget.windowSeconds;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer({bool countFirstTap = false}) {
    _timer?.cancel();
    setState(() {
      _running = true;
      _completed = false;
      _remainingSeconds = widget.windowSeconds;
      _taps = countFirstTap ? 1 : 0;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_remainingSeconds <= 1) {
        timer.cancel();
        final calculated = _taps * widget.multiplier;
        setState(() {
          _remainingSeconds = 0;
          _running = false;
          _completed = true;
        });
        if (calculated > 0) {
          widget.onApplied(calculated);
        }
      } else {
        setState(() => _remainingSeconds -= 1);
      }
    });
  }

  void _handleTap() {
    if (!_running && !_completed && _taps == 0) {
      _startTimer(countFirstTap: true);
      return;
    }
    if (_completed) {
      _startTimer(countFirstTap: true);
      return;
    }
    setState(() => _taps += 1);
  }

  void _reset() {
    _timer?.cancel();
    setState(() {
      _running = false;
      _completed = false;
      _remainingSeconds = widget.windowSeconds;
      _taps = 0;
    });
  }

  int get _estimatedRate {
    if (_completed) return _taps * widget.multiplier;
    final elapsed = widget.windowSeconds - _remainingSeconds;
    if (elapsed <= 0 || _taps == 0) return 0;
    return ((_taps * 60) / elapsed).round();
  }

  @override
  Widget build(BuildContext context) {
    final estimate = _estimatedRate;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: SpaceTheme.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: widget.accentColor.withValues(alpha: 0.45),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(widget.icon, color: widget.accentColor, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  widget.title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: widget.accentColor,
                  ),
                ),
              ),
              Text(
                '${_remainingSeconds}s',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: SpaceTheme.cyan,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            widget.instruction,
            style: const TextStyle(fontSize: 11, color: Colors.white70),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: widget.accentColor.withValues(alpha: 0.2),
                    foregroundColor: Colors.white,
                    side: BorderSide(color: widget.accentColor),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  icon: Icon(widget.icon, size: 16),
                  label: Text(
                    _running
                        ? 'Tocar aquí ($_taps · ~$estimate ${widget.unit})'
                        : (_completed
                            ? 'Listo: $_taps × ${widget.multiplier} = $estimate ${widget.unit}'
                            : 'Tocar para Contar (${widget.windowSeconds}s)'),
                    style: const TextStyle(fontSize: 11.5),
                    overflow: TextOverflow.ellipsis,
                  ),
                  onPressed: _handleTap,
                ),
              ),
              if (_taps > 0 && !_completed) ...[
                const SizedBox(width: 6),
                IconButton(
                  tooltip: 'Aplicar valor estimado',
                  icon: const Icon(Icons.check_circle, color: SpaceTheme.green),
                  onPressed: () {
                    _timer?.cancel();
                    final value = estimate > 0
                        ? estimate
                        : _taps * widget.multiplier;
                    setState(() {
                      _running = false;
                      _completed = true;
                    });
                    widget.onApplied(value);
                  },
                ),
              ],
              if (_running || _completed || _taps > 0)
                IconButton(
                  tooltip: 'Reiniciar contador',
                  icon: const Icon(Icons.refresh, color: Colors.white60),
                  onPressed: _reset,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Cronómetro interactivo de llenado capilar (presión 5s + medición de retorno).
class _CapillaryStopwatchPanel extends StatefulWidget {
  final ValueChanged<double> onMeasured;

  const _CapillaryStopwatchPanel({required this.onMeasured});

  @override
  State<_CapillaryStopwatchPanel> createState() =>
      _CapillaryStopwatchPanelState();
}

class _CapillaryStopwatchPanelState extends State<_CapillaryStopwatchPanel> {
  final Stopwatch _stopwatch = Stopwatch();
  Timer? _ticker;
  double? _lastMeasuredSeconds;

  @override
  void dispose() {
    _ticker?.cancel();
    _stopwatch.stop();
    super.dispose();
  }

  void _toggleStopwatch() {
    if (_stopwatch.isRunning) {
      _ticker?.cancel();
      _stopwatch.stop();
      final measured = double.parse(
        (_stopwatch.elapsedMilliseconds / 1000.0).toStringAsFixed(1),
      );
      setState(() => _lastMeasuredSeconds = measured);
      widget.onMeasured(measured);
    } else {
      _stopwatch
        ..reset()
        ..start();
      _ticker?.cancel();
      _ticker = Timer.periodic(const Duration(milliseconds: 100), (_) {
        if (!mounted) return;
        setState(() {});
      });
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final liveSeconds = _stopwatch.elapsedMilliseconds / 1000.0;
    final display = _stopwatch.isRunning
        ? liveSeconds
        : (_lastMeasuredSeconds ?? 0.0);
    final isNormal = display > 0 && display <= 2.0;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: SpaceTheme.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.purpleAccent.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.timer, color: Colors.purpleAccent, size: 16),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'Cronómetro de Llenado Capilar',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.purpleAccent,
                  ),
                ),
              ),
              Text(
                '${display.toStringAsFixed(1)}s',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: display == 0
                      ? Colors.white54
                      : (isNormal ? SpaceTheme.green : SpaceTheme.warningYellow),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Presiona una uña 5s hasta que blanquee. Suelta y presiona Iniciar; detén apenas recupere su color rosado (< 2.0s normal).',
            style: TextStyle(fontSize: 11, color: Colors.white70),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: _stopwatch.isRunning
                    ? SpaceTheme.warningYellow.withValues(alpha: 0.25)
                    : Colors.purpleAccent.withValues(alpha: 0.18),
                foregroundColor: Colors.white,
                side: BorderSide(
                  color: _stopwatch.isRunning
                      ? SpaceTheme.warningYellow
                      : Colors.purpleAccent,
                ),
              ),
              icon: Icon(_stopwatch.isRunning ? Icons.stop : Icons.play_arrow),
              label: Text(
                _stopwatch.isRunning
                    ? 'Color Recuperado — Detener (${display.toStringAsFixed(1)}s)'
                    : 'Soltar Uña e Iniciar Retorno',
                style: const TextStyle(fontSize: 11.5),
              ),
              onPressed: _toggleStopwatch,
            ),
          ),
        ],
      ),
    );
  }
}
