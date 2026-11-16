import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:astramed/features/apolo/presentation/apolo_theme.dart';
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
  static const _palette = ApoloPalette.standard;
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
        color: _palette.bg2,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _palette.border,
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
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Cabin Equipment & Sensors (${telemetryState.machines.length})',
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
                      '${connectedMachines.length} linked to ${targetAstronaut.callsign}',
                      style: TextStyle(
                        fontSize: 12,
                        color: _palette.mint,
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
              color: _palette.lav.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _palette.border),
            ),
            child: Icon(
              Icons.settings_input_antenna,
              color: _palette.lav2,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Telemetry & Hardware Configuration',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Profile: ${targetAstronaut.name} (${targetAstronaut.id}) • $connectedCount active',
                  style: const TextStyle(fontSize: 12, color: Colors.white70),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Close',
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
      color: _palette.bg2,
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
                selectedColor: _palette.lav.withValues(alpha: 0.2),
                backgroundColor: _palette.surface,
                side: BorderSide(
                  color: isSelected ? _palette.lav2 : _palette.border,
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
                    color: isSelected ? _palette.mint : _palette.text,
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
        color: _palette.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: telemetryState.isLiveStreaming
              ? _palette.ok.withValues(alpha: 0.7)
              : _palette.border,
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
                    ? _palette.ok
                    : Colors.white60,
                size: 20,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Live Stream (3s)',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'Receive automatic telemetry packets from linked hardware',
                      style: TextStyle(fontSize: 11, color: Colors.white60),
                    ),
                  ],
                ),
              ),
              Switch(
                value: telemetryState.isLiveStreaming,
                activeThumbColor: _palette.ok,
                activeTrackColor: _palette.ok.withValues(alpha: 0.35),
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
                  foregroundColor: _palette.mint,
                  side: BorderSide(color: _palette.border),
                ),
                icon: telemetryState.isScanning
                    ? SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: _palette.mint,
                        ),
                      )
                    : const Icon(Icons.radar, size: 16),
                label: Text(
                  telemetryState.isScanning
                      ? 'Scanning Bus...'
                      : 'Scan Space Bus',
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
                                'Scan complete: ${telemetryState.machines.length} cabin devices detected for ${targetAstronaut.name}.',
                              ),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        }
                      },
              ),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: _palette.mint,
                  foregroundColor: Colors.black,
                ),
                icon: const Icon(Icons.download_for_offline, size: 16),
                label: Text(
                  'Read All ($connectedCount)',
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
                              'Telemetry received from $readCount device(s) for ${targetAstronaut.name} (${targetAstronaut.id}).',
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

  Widget _buildMetadataSummaryCard(AstronautProfile astronaut) {
    final v = astronaut.vitals;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _palette.bg2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.verified_user, size: 14, color: _palette.mint),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Active Telemetry Traceability Metadata',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: _palette.mint,
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
        color: _palette.surface,
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
      color: _palette.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isConnected
              ? _palette.lav2.withValues(alpha: 0.65)
              : _palette.border,
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
                                  ? _palette.ok.withValues(alpha: 0.18)
                                  : Colors.white10,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              isConnected ? 'STREAMING' : 'DISCONNECTED',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: isConnected
                                    ? _palette.ok
                                    : Colors.white54,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${machine.id} • ${machine.protocol} • ${machine.defaultRecordType}',
                        style: TextStyle(
                          fontSize: 11,
                          color: _palette.mint,
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
                        'Method: ${machine.measurementMethod} | State: ${machine.defaultActivityState} | Algorithm: ${machine.algorithm} | Criterion: ${machine.criterionReference}',
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
                  activeThumbColor: _palette.lav2,
                  activeTrackColor: _palette.lav.withValues(alpha: 0.35),
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
                      'Battery ${machine.batteryPercent}%',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Icon(
                      Icons.signal_cellular_alt,
                      size: 13,
                      color: _palette.mint,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      'Signal ${machine.signalPercent}%',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
                TextButton.icon(
                  style: TextButton.styleFrom(
                    foregroundColor: _palette.mint,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                  icon: const Icon(Icons.bolt, size: 16),
                  label: Text(
                    isConnected ? 'Capture Reading Now' : 'Connect & Read',
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
                  color: _palette.bg2,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _palette.ok.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Latest packet: astronautId=${lastPacket.astronautId} | source=${lastPacket.source} | device=${lastPacket.device.isNotEmpty ? lastPacket.device : lastPacket.machineId} | recordType=${lastPacket.recordType} | activityState=${lastPacket.activityState} | signalQuality=${lastPacket.signalQuality} | method=${lastPacket.measurementMethod} | algorithm=${lastPacket.algorithm} | criterion=${lastPacket.criterionReference}',
                      style: TextStyle(
                        fontSize: 10,
                        color: _palette.ok,
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
        syncTime != null ? _formatTime(syncTime) : 'Not synced';

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      decoration: BoxDecoration(
        color: _palette.bg2,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(18)),
      ),
      child: Row(
        children: [
          Icon(Icons.storage, size: 16, color: _palette.mint),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'DB/Users/${targetAstronaut.id} • Sync: $syncLabel • ${telemetryState.recentLogs.length} packets',
              style: const TextStyle(fontSize: 11, color: Colors.white70),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: _palette.mint,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            icon: const Icon(Icons.save, size: 16),
            label: const Text(
              'Sync DB/Users',
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
                      'Profile ${targetAstronaut.id} (${targetAstronaut.linkedMachineIds.length} devices) synced to local DB/Users storage.',
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
        return _palette.crit;
      case CrewRiskLevel.warning:
        return _palette.warn;
      case CrewRiskLevel.nominal:
        return _palette.ok;
    }
  }

  Color _getCategoryColor(MachineCategory category) {
    switch (category) {
      case MachineCategory.biometrics:
        return _palette.crit;
      case MachineCategory.dosimetry:
        return _palette.warn;
      case MachineCategory.hemodynamics:
        return _palette.mint;
      case MachineCategory.countermeasure:
        return _palette.ok;
      case MachineCategory.bloodLab:
        return _palette.lav2;
      case MachineCategory.circadian:
        return _palette.lav2;
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
