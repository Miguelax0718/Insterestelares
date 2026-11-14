import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:astramed/core/theme/space_theme.dart';
import 'package:astramed/features/crew/models/astronaut_profile.dart';
import 'package:astramed/features/crew/presentation/providers/crew_provider.dart';
import 'package:astramed/features/telemetry/presentation/providers/telemetry_provider.dart';
import 'package:astramed/features/telemetry/presentation/widgets/telemetry_config_modal.dart';

/// Sidebar (Drawer) lateral izquierdo para alternar entre los 5 perfiles de astronautas
/// y visualizar de un vistazo el estado de riesgo y telemetría de cada uno.
class CrewSidebarDrawer extends ConsumerWidget {
  const CrewSidebarDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crew = ref.watch(crewMembersProvider);
    final selectedId = ref.watch(selectedAstronautIdProvider);
    final telemetryState = ref.watch(telemetryProvider);

    final criticalCount = ref.watch(criticalCrewCountProvider);
    final warningCount = ref.watch(warningCrewCountProvider);
    final nominalCount = ref.watch(nominalCrewCountProvider);

    return Drawer(
      backgroundColor: SpaceTheme.surface,
      child: SafeArea(
        child: Column(
          children: [
            // ── CABECERA DEL CREW HUB ──
            _buildDrawerHeader(context, criticalCount, warningCount, nominalCount),
            const Divider(color: Colors.white24, height: 1),

            // ── LISTA DE LOS 5 PERFILES ──
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                itemCount: crew.length,
                itemBuilder: (context, index) {
                  final astronaut = crew[index];
                  final isSelected = astronaut.id == selectedId;
                  final connectedCount = telemetryState.machines
                      .where((m) => m.isConnectedFor(astronaut.id))
                      .length;
                  return _buildAstronautCard(
                    context,
                    ref,
                    astronaut,
                    isSelected,
                    connectedCount,
                  );
                },
              ),
            ),

            const Divider(color: Colors.white24, height: 1),

            // ── PIE DE PÁGINA / ACCIONES RÁPIDAS ──
            _buildDrawerFooter(context, ref, selectedId),
          ],
        ),
      ),
    );
  }

  /// Cabecera con resumen general de la tripulación
  Widget _buildDrawerHeader(
    BuildContext context,
    int criticalCount,
    int warningCount,
    int nominalCount,
  ) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      color: SpaceTheme.background,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: SpaceTheme.cyan.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: SpaceTheme.cyan, width: 1.5),
                ),
                child: const Icon(Icons.groups, color: SpaceTheme.cyan, size: 24),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TRIPULACIÓN ARTEMIS',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        letterSpacing: 1.2,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'AstraMed Crew Hub (5 Tripulantes)',
                      style: TextStyle(fontSize: 12, color: Colors.white60),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Barra de estado global del equipo
          Row(
            children: [
              _buildStatusPill(
                label: '$criticalCount Crítico',
                color: SpaceTheme.dangerRed,
                icon: Icons.error_outline,
              ),
              const SizedBox(width: 6),
              _buildStatusPill(
                label: '$warningCount Atención',
                color: SpaceTheme.warningYellow,
                icon: Icons.warning_amber_rounded,
              ),
              const SizedBox(width: 6),
              _buildStatusPill(
                label: '$nominalCount Estable',
                color: SpaceTheme.green,
                icon: Icons.check_circle_outline,
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Tarjeta de cada astronauta en el sidebar
  Widget _buildAstronautCard(
    BuildContext context,
    WidgetRef ref,
    AstronautProfile astronaut,
    bool isSelected,
    int connectedMachinesCount,
  ) {
    final statusColor = _getRiskColor(astronaut.riskLevel);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      elevation: isSelected ? 4 : 1,
      color: isSelected
          ? SpaceTheme.cyan.withValues(alpha: 0.12)
          : SpaceTheme.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected
              ? SpaceTheme.cyan
              : (astronaut.riskLevel == CrewRiskLevel.critical
                  ? SpaceTheme.dangerRed
                  : Colors.white12),
          width: isSelected ? 2.0 : (astronaut.riskLevel == CrewRiskLevel.critical ? 1.5 : 1.0),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          // Cambia el astronauta activo
          ref.read(selectedAstronautIdProvider.notifier).state = astronaut.id;
          Navigator.of(context).pop(); // Cierra el Drawer
        },
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Fila superior: Avatar, Nombre, Rol y Badge de Selección
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Avatar con aro del color de riesgo
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: statusColor.withValues(alpha: 0.2),
                        child: Text(
                          astronaut.avatarInitials,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: statusColor,
                          ),
                        ),
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: statusColor,
                            shape: BoxShape.circle,
                            border: Border.all(color: SpaceTheme.surface, width: 2),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 10),

                  // Nombre, Callsign y Rol
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
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: Colors.white,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(
                                color: Colors.white10,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                astronaut.callsign,
                                style: const TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: SpaceTheme.cyan,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          astronaut.role,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.white70,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),

                  // Indicador de "ACTIVO" si está seleccionado
                  if (isSelected)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: SpaceTheme.cyan,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        'ACTIVO',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 10),

              // ── BADGE DE RIESGO / ESTADO DE SALUD ──
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: statusColor.withValues(alpha: 0.4)),
                ),
                child: Row(
                  children: [
                    Icon(_getRiskIcon(astronaut.riskLevel), size: 14, color: statusColor),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        astronaut.riskTitle,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              // ── PREVIEW DE TELEMETRÍA RÁPIDA (FC, SpO2, PA) ──
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildMiniMetric(
                      label: 'FC',
                      value: '${astronaut.vitals.heartRate.toInt()} bpm',
                      isWarning: astronaut.vitals.heartRate > 100 ||
                          astronaut.vitals.heartRate < 50,
                    ),
                    const Text('|', style: TextStyle(color: Colors.white24, fontSize: 10)),
                    _buildMiniMetric(
                      label: 'SpO2',
                      value: '${astronaut.vitals.spO2.toInt()}%',
                      isWarning: astronaut.vitals.spO2 < 94,
                    ),
                    const Text('|', style: TextStyle(color: Colors.white24, fontSize: 10)),
                    _buildMiniMetric(
                      label: 'PA',
                      value:
                          '${astronaut.vitals.systolicBP.toInt()}/${astronaut.vitals.diastolicBP.toInt()}',
                      isWarning: astronaut.vitals.systolicBP > 130 ||
                          astronaut.vitals.systolicBP < 90,
                    ),
                  ],
                ),
              ),

              // Alerta principal si existe riesgo
              if (astronaut.activeAlerts.isNotEmpty) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.bolt, color: Colors.amberAccent, size: 12),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        astronaut.activeAlerts.first,
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.amberAccent,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 6),

              // ── FILA DE TELEMETRÍA Y ACCESO RÁPIDO A CONFIGURACIÓN ──
              Row(
                children: [
                  Icon(
                    Icons.sensors,
                    size: 13,
                    color: connectedMachinesCount > 0
                        ? SpaceTheme.cyan
                        : Colors.white38,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      '$connectedMachinesCount máq. activas • ${astronaut.vitals.source.toUpperCase()}',
                      style: TextStyle(
                        fontSize: 10,
                        color: connectedMachinesCount > 0
                            ? SpaceTheme.cyan
                            : Colors.white54,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  InkWell(
                    borderRadius: BorderRadius.circular(6),
                    onTap: () {
                      final rootContext =
                          Navigator.of(context, rootNavigator: true).context;
                      Navigator.of(context).pop();
                      TelemetryConfigModal.show(
                        rootContext,
                        initialAstronautId: astronaut.id,
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: SpaceTheme.cyan.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: SpaceTheme.cyan.withValues(alpha: 0.45),
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.settings_input_antenna,
                            size: 11,
                            color: SpaceTheme.cyan,
                          ),
                          SizedBox(width: 3),
                          Text(
                            'Config',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: SpaceTheme.cyan,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Muestra una métrica compacta en el preview de cada tarjeta
  Widget _buildMiniMetric({
    required String label,
    required String value,
    required bool isWarning,
  }) {
    return Row(
      children: [
        Text(
          '$label: ',
          style: const TextStyle(fontSize: 10, color: Colors.white60),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: isWarning ? SpaceTheme.dangerRed : Colors.white,
          ),
        ),
      ],
    );
  }

  /// Chip de resumen de estado para la cabecera
  Widget _buildStatusPill({
    required String label,
    required Color color,
    required IconData icon,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 3),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Pie del drawer con controles de telemetría y simulación
  Widget _buildDrawerFooter(
    BuildContext context,
    WidgetRef ref,
    String selectedId,
  ) {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        children: [
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: SpaceTheme.cyan,
              foregroundColor: Colors.black,
              minimumSize: const Size(double.infinity, 38),
            ),
            icon: const Icon(Icons.settings_input_antenna, size: 16),
            label: const Text(
              'Configurar Máquinas de Telemetría',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
            onPressed: () {
              final rootContext =
                  Navigator.of(context, rootNavigator: true).context;
              Navigator.of(context).pop();
              TelemetryConfigModal.show(
                rootContext,
                initialAstronautId: selectedId,
              );
            },
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: SpaceTheme.cyan,
              side: const BorderSide(color: SpaceTheme.cyan),
              minimumSize: const Size(double.infinity, 38),
            ),
            icon: const Icon(Icons.sync, size: 16),
            label: const Text(
              'Restablecer Tripulación Base',
              style: TextStyle(fontSize: 12),
            ),
            onPressed: () {
              ref.read(crewMembersProvider.notifier).resetToInitial();
              ref.read(telemetryProvider.notifier).resetToInitial();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Telemetría de la tripulación reiniciada a valores base',
                  ),
                  duration: Duration(seconds: 2),
                ),
              );
            },
          ),
        ],
      ),
    );
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

  IconData _getRiskIcon(CrewRiskLevel level) {
    switch (level) {
      case CrewRiskLevel.critical:
        return Icons.emergency;
      case CrewRiskLevel.warning:
        return Icons.warning_amber_rounded;
      case CrewRiskLevel.nominal:
        return Icons.verified;
    }
  }
}
