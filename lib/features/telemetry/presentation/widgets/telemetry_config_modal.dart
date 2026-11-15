import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:astramed/core/theme/space_theme.dart';
import 'package:astramed/features/crew/models/astronaut_profile.dart';
import 'package:astramed/features/crew/presentation/providers/crew_provider.dart';
import 'package:astramed/features/telemetry/models/telemetry_machine.dart';
import 'package:astramed/features/telemetry/presentation/providers/telemetry_provider.dart';

/// Modal interactivo de configuración, vinculación y monitoreo de máquinas
/// de telemetría espacial organizado de manera individual por perfil de tripulante.
class TelemetryConfigModal extends ConsumerStatefulWidget {
  final String? initialAstronautId;

  const TelemetryConfigModal({
    super.key,
    this.initialAstronautId,
  });

  /// Abre el modal responsivo de configuración de telemetría
  static Future<void> show(
    BuildContext context, {
    String? initialAstronautId,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => TelemetryConfigModal(
        initialAstronautId: initialAstronautId,
      ),
    );
  }

  @override
  ConsumerState<TelemetryConfigModal> createState() =>
      _TelemetryConfigModalState();
}

class _TelemetryConfigModalState extends ConsumerState<TelemetryConfigModal> {
  late String _targetAstronautId;

  @override
  void initState() {
    super.initState();
    _targetAstronautId =
        widget.initialAstronautId ?? ref.read(selectedAstronautIdProvider);
  }

  @override
  Widget build(BuildContext context) {
    final crew = ref.watch(crewMembersProvider);
    final telemetryState = ref.watch(telemetryProvider);

    final targetAstronaut = crew.firstWhere(
      (a) => a.id == _targetAstronautId,
      orElse: () => crew.first,
    );

    final connectedMachines = telemetryState.machines
        .where((m) => m.isConnectedFor(targetAstronaut.id))
        .toList();

    final maxHeight = MediaQuery.of(context).size.height * 0.92;

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight, maxWidth: 880),
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: SpaceTheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: SpaceTheme.cyan.withValues(alpha: 0.45),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.6),
            blurRadius: 24,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildModalHeader(context, targetAstronaut, connectedMachines.length),
          const Divider(color: Colors.white12, height: 1),
          _buildCrewSelectorRow(crew, telemetryState.machines, targetAstronaut.id),
          const Divider(color: Colors.white12, height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildMasterControlPanel(
                  context,
                  telemetryState,
                  targetAstronaut,
                  connectedMachines.length,
                ),
                const SizedBox(height: 12),
                _buildScenarioSimulatorSection(context, targetAstronaut),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Equipos y Sensores de Cabina (${telemetryState.machines.length})',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${connectedMachines.length} vinculados a ${targetAstronaut.callsign}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: SpaceTheme.cyan,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ...telemetryState.machines.map(
                  (machine) => _buildMachineCard(
                    context,
                    machine,
                    targetAstronaut,
                  ),
                ),
                const SizedBox(height: 6),
                _buildMetadataSummaryCard(targetAstronaut),
              ],
            ),
          ),
          const Divider(color: Colors.white12, height: 1),
          _buildFooterBar(context, telemetryState, targetAstronaut),
        ],
      ),
    );
  }

  Widget _buildModalHeader(
    BuildContext context,
    AstronautProfile targetAstronaut,
    int connectedCount,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 10, 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: SpaceTheme.cyan.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: SpaceTheme.cyan.withValues(alpha: 0.5)),
            ),
            child: const Icon(
              Icons.settings_input_antenna,
              color: SpaceTheme.cyan,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Configuración de Telemetría y Máquinas',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Perfil: ${targetAstronaut.name} (${targetAstronaut.id}) • $connectedCount activas',
                  style: const TextStyle(fontSize: 12, color: Colors.white70),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Cerrar',
            icon: const Icon(Icons.close, color: Colors.white70),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildCrewSelectorRow(
    List<AstronautProfile> crew,
    List<TelemetryMachine> machines,
    String activeTargetId,
  ) {
    return Container(
      width: double.infinity,
      color: SpaceTheme.background.withValues(alpha: 0.65),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: crew.map((astro) {
            final isSelected = astro.id == activeTargetId;
            final statusColor = _getRiskColor(astro.riskLevel);
            final count =
                machines.where((m) => m.isConnectedFor(astro.id)).length;

            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                selected: isSelected,
                selectedColor: SpaceTheme.cyan.withValues(alpha: 0.2),
                backgroundColor: SpaceTheme.card,
                side: BorderSide(
                  color: isSelected ? SpaceTheme.cyan : Colors.white12,
                  width: isSelected ? 1.5 : 1,
                ),
                avatar: CircleAvatar(
                  radius: 11,
                  backgroundColor: statusColor.withValues(alpha: 0.25),
                  child: Text(
                    astro.avatarInitials,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                ),
                label: Text(
                  '${astro.callsign} ($count)',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected ? SpaceTheme.cyan : Colors.white,
                  ),
                ),
                onSelected: (_) {
                  setState(() {
                    _targetAstronautId = astro.id;
                  });
                },
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildMasterControlPanel(
    BuildContext context,
    TelemetryState telemetryState,
    AstronautProfile targetAstronaut,
    int connectedCount,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: SpaceTheme.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: telemetryState.isLiveStreaming
              ? SpaceTheme.green.withValues(alpha: 0.7)
              : Colors.white12,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                telemetryState.isLiveStreaming
                    ? Icons.sensors
                    : Icons.sensors_off,
                color: telemetryState.isLiveStreaming
                    ? SpaceTheme.green
                    : Colors.white60,
                size: 20,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Transmisión en Vivo (Live Stream 3s)',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'Recibe paquetes automáticos de las máquinas vinculadas',
                      style: TextStyle(fontSize: 11, color: Colors.white60),
                    ),
                  ],
                ),
              ),
              Switch(
                value: telemetryState.isLiveStreaming,
                activeThumbColor: SpaceTheme.green,
                activeTrackColor: SpaceTheme.green.withValues(alpha: 0.35),
                onChanged: (_) {
                  ref
                      .read(telemetryProvider.notifier)
                      .toggleLiveStreaming(targetAstronaut.id);
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: SpaceTheme.cyan,
                  side: const BorderSide(color: SpaceTheme.cyan),
                ),
                icon: telemetryState.isScanning
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: SpaceTheme.cyan,
                        ),
                      )
                    : const Icon(Icons.radar, size: 16),
                label: Text(
                  telemetryState.isScanning
                      ? 'Escaneando Bus...'
                      : 'Escanear Bus Espacial',
                  style: const TextStyle(fontSize: 12),
                ),
                onPressed: telemetryState.isScanning
                    ? null
                    : () async {
                        await ref
                            .read(telemetryProvider.notifier)
                            .scanCabinBus(targetAstronaut.id);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Escaneo completo: ${telemetryState.machines.length} equipos detectados en cabina para ${targetAstronaut.name}.',
                              ),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        }
                      },
              ),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: SpaceTheme.cyan,
                  foregroundColor: Colors.black,
                ),
                icon: const Icon(Icons.download_for_offline, size: 16),
                label: Text(
                  'Leer Todas ($connectedCount)',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onPressed: connectedCount == 0
                    ? null
                    : () {
                        final readCount = ref
                            .read(telemetryProvider.notifier)
                            .pullAllConnectedMachines(targetAstronaut.id);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Telemetría recibida de $readCount máquina(s) para ${targetAstronaut.name} (${targetAstronaut.id}).',
                            ),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
              ),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white24),
                ),
                icon: const Icon(Icons.data_object, size: 16),
                label: const Text(
                  'Inspeccionar JSON DB',
                  style: TextStyle(fontSize: 12),
                ),
                onPressed: () => _showJsonPreviewDialog(context, targetAstronaut),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildScenarioSimulatorSection(
    BuildContext context,
    AstronautProfile targetAstronaut,
  ) {
    final scenarios = <Map<String, String>>[
      {'id': 'nominal_rest', 'label': 'Reposo Nominal (Día 18)'},
      {'id': 'sleep_bimodal', 'label': 'Sueño Bimodal (0.018g + Dip FC)'},
      {'id': 'exercise_ared', 'label': 'Ejercicio ARED (152 lpm sin falsa alarma)'},
      {'id': 'co2_pocket', 'label': 'Bolsillo CO₂ 0g (4.6 mmHg)'},
      {'id': 'fluid_shift_day2', 'label': 'Día 2 Misión (Fluid Shift 0g)'},
    ];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: SpaceTheme.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: SpaceTheme.cyan.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.science_outlined, size: 16, color: SpaceTheme.cyan),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Inyector de Escenarios de Simulación (Fuera de UI de Uso)',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Estado actual: Día ${targetAstronaut.vitals.missionDay} • Actigrafía ${targetAstronaut.vitals.accelerometryRmsG.toStringAsFixed(3)} g • CO₂ ${targetAstronaut.vitals.localCo2MmHg.toStringAsFixed(1)} mmHg',
            style: const TextStyle(fontSize: 11, color: Colors.white60),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: scenarios.map((sc) {
              return ActionChip(
                backgroundColor: SpaceTheme.surface,
                side: BorderSide(color: SpaceTheme.cyan.withValues(alpha: 0.45)),
                label: Text(
                  sc['label']!,
                  style: const TextStyle(fontSize: 11, color: SpaceTheme.cyan),
                ),
                onPressed: () {
                  ref
                      .read(crewMembersProvider.notifier)
                      .applySimulationScenario(targetAstronaut.id, sc['id']!);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Escenario "${sc['label']}" inyectado en ${targetAstronaut.callsign}.',
                      ),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                },
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildMetadataSummaryCard(AstronautProfile astronaut) {
    final v = astronaut.vitals;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: SpaceTheme.background.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: SpaceTheme.cyan.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.verified_user, size: 14, color: SpaceTheme.cyan),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Metadatos Activos de Trazabilidad Telemétrica',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: SpaceTheme.cyan,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _buildMetadataChip('astronautId', v.astronautId),
              _buildMetadataChip('source', v.source),
              _buildMetadataChip('deviceId', v.deviceId),
              _buildMetadataChip('device', v.device),
              _buildMetadataChip('protocol', v.protocol),
              _buildMetadataChip('measurementMethod', v.measurementMethod),
              _buildMetadataChip('activityState', v.activityState),
              _buildMetadataChip('signalQuality', v.signalQuality),
              _buildMetadataChip('recordType', v.recordType),
              _buildMetadataChip('algorithm', v.algorithm),
              _buildMetadataChip('criterionReference', v.criterionReference),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetadataChip(String key, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: SpaceTheme.card,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white12),
      ),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(fontSize: 11),
          children: [
            TextSpan(
              text: '$key: ',
              style: const TextStyle(color: Colors.white54),
            ),
            TextSpan(
              text: value,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMachineCard(
    BuildContext context,
    TelemetryMachine machine,
    AstronautProfile astronaut,
  ) {
    final isConnected = machine.isConnectedFor(astronaut.id);
    final lastPacket = machine.lastPacketFor(astronaut.id);
    final catColor = _getCategoryColor(machine.category);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: SpaceTheme.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isConnected
              ? SpaceTheme.cyan.withValues(alpha: 0.65)
              : Colors.white12,
          width: isConnected ? 1.4 : 1.0,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: catColor.withValues(alpha: 0.16),
                  child: Icon(
                    _getCategoryIcon(machine.category),
                    color: catColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              machine.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: isConnected
                                  ? SpaceTheme.green.withValues(alpha: 0.18)
                                  : Colors.white10,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              isConnected ? 'STREAMING' : 'DESCONECTADA',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: isConnected
                                    ? SpaceTheme.green
                                    : Colors.white54,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${machine.id} • ${machine.protocol} • ${machine.defaultRecordType}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: SpaceTheme.cyan,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        machine.description,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Método: ${machine.measurementMethod} | Estado: ${machine.defaultActivityState} | Algoritmo: ${machine.algorithm} | Criterio: ${machine.criterionReference}',
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.white54,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: isConnected,
                  activeThumbColor: SpaceTheme.cyan,
                  activeTrackColor: SpaceTheme.cyan.withValues(alpha: 0.35),
                  onChanged: (_) {
                    ref
                        .read(telemetryProvider.notifier)
                        .toggleMachineForAstronaut(astronaut.id, machine.id);
                  },
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 4,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.battery_std,
                      size: 13,
                      color: Colors.greenAccent,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      'Bat ${machine.batteryPercent}%',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Icon(
                      Icons.signal_cellular_alt,
                      size: 13,
                      color: SpaceTheme.cyan,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      'Señal ${machine.signalPercent}%',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: SpaceTheme.cyan,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                  icon: const Icon(Icons.bolt, size: 16),
                  label: Text(
                    isConnected ? 'Capturar Lectura Ahora' : 'Conectar y Leer',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onPressed: () {
                    if (!isConnected) {
                      ref
                          .read(telemetryProvider.notifier)
                          .toggleMachineForAstronaut(astronaut.id, machine.id);
                    } else {
                      ref
                          .read(telemetryProvider.notifier)
                          .pullSingleMachine(astronaut.id, machine.id);
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: machine.supportedMetrics.map((metric) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Text(
                    metric,
                    style: const TextStyle(fontSize: 10, color: Colors.white70),
                  ),
                );
              }).toList(),
            ),
            if (isConnected && lastPacket != null) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: SpaceTheme.background,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: SpaceTheme.green.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Último paquete: astronautId=${lastPacket.astronautId} | source=${lastPacket.source} | device=${lastPacket.device.isNotEmpty ? lastPacket.device : lastPacket.machineId} | recordType=${lastPacket.recordType} | activityState=${lastPacket.activityState} | signalQuality=${lastPacket.signalQuality} | method=${lastPacket.measurementMethod} | algorithm=${lastPacket.algorithm} | criterion=${lastPacket.criterionReference}',
                      style: const TextStyle(
                        fontSize: 10,
                        color: SpaceTheme.green,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_formatTime(lastPacket.timestamp)} • ${_formatPacketMetrics(lastPacket.metrics)}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFooterBar(
    BuildContext context,
    TelemetryState telemetryState,
    AstronautProfile targetAstronaut,
  ) {
    final syncTime =
        telemetryState.lastSyncAt ?? targetAstronaut.lastTelemetrySync;
    final syncLabel =
        syncTime != null ? _formatTime(syncTime) : 'Sin sincronizar';

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      decoration: const BoxDecoration(
        color: SpaceTheme.background,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(18)),
      ),
      child: Row(
        children: [
          const Icon(Icons.storage, size: 16, color: SpaceTheme.cyan),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'DB/Users/${targetAstronaut.id} • Sync: $syncLabel • ${telemetryState.recentLogs.length} paquetes',
              style: const TextStyle(fontSize: 11, color: Colors.white70),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: SpaceTheme.green,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            icon: const Icon(Icons.save, size: 16),
            label: const Text(
              'Sincronizar DB/Users',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
            onPressed: () async {
              await ref
                  .read(crewMembersProvider.notifier)
                  .saveProfileToDb(targetAstronaut.id);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Perfil ${targetAstronaut.id} (${targetAstronaut.linkedMachineIds.length} máquinas) sincronizado en almacenamiento local DB/Users.',
                    ),
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  void _showJsonPreviewDialog(
    BuildContext context,
    AstronautProfile astronaut,
  ) {
    final jsonString =
        ref.read(crewMembersProvider.notifier).exportProfileToDbJson(astronaut.id);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: SpaceTheme.surface,
        title: Row(
          children: [
            const Icon(Icons.data_object, color: SpaceTheme.cyan),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'DB/Users/${astronaut.id}.json',
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 520,
          height: 360,
          child: SingleChildScrollView(
            child: SelectableText(
              jsonString,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 11,
                color: Colors.greenAccent,
              ),
            ),
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: jsonString));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('JSON copiado al portapapeles'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            icon: const Icon(Icons.copy, size: 16, color: SpaceTheme.cyan),
            label: const Text(
              'Copiar JSON',
              style: TextStyle(color: SpaceTheme.cyan),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cerrar', style: TextStyle(color: Colors.white70)),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    final s = dt.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  String _formatPacketMetrics(Map<String, dynamic> metrics) {
    return metrics.entries.map((e) => '${e.key}: ${e.value}').join(' • ');
  }

  Color _getRiskColor(CrewRiskLevel level) {
    switch (level) {
      case CrewRiskLevel.critical:
        return SpaceTheme.dangerRed;
      case CrewRiskLevel.warning:
        return SpaceTheme.warningYellow;
      case CrewRiskLevel.nominal:
        return SpaceTheme.green;
    }
  }

  Color _getCategoryColor(MachineCategory category) {
    switch (category) {
      case MachineCategory.biometrics:
        return Colors.redAccent;
      case MachineCategory.dosimetry:
        return Colors.amberAccent;
      case MachineCategory.hemodynamics:
        return SpaceTheme.cyan;
      case MachineCategory.countermeasure:
        return SpaceTheme.green;
      case MachineCategory.bloodLab:
        return Colors.pinkAccent;
      case MachineCategory.circadian:
        return SpaceTheme.neonPurple;
    }
  }

  IconData _getCategoryIcon(MachineCategory category) {
    switch (category) {
      case MachineCategory.biometrics:
        return Icons.monitor_heart;
      case MachineCategory.dosimetry:
        return Icons.wb_sunny;
      case MachineCategory.hemodynamics:
        return Icons.bloodtype;
      case MachineCategory.countermeasure:
        return Icons.fitness_center;
      case MachineCategory.bloodLab:
        return Icons.biotech;
      case MachineCategory.circadian:
        return Icons.bedtime;
    }
  }
}
