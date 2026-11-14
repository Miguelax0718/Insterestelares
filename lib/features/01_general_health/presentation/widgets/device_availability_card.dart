import 'package:flutter/material.dart';
import 'package:astramed/core/theme/space_theme.dart';
import 'package:astramed/features/01_general_health/domain/telemetry_view_contracts.dart';

/// Panel de disponibilidad de sensores y calidad de datos por dispositivo.
class DeviceAvailabilityCard extends StatelessWidget {
  final List<TelemetryDeviceInfo> devices;

  const DeviceAvailabilityCard({
    super.key,
    required this.devices,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: SpaceTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.sensors, color: SpaceTheme.cyan, size: 18),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Disponibilidad de Dispositivos y Calidad de Datos',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          if (devices.any((d) => d.isSimulated)) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: SpaceTheme.warningYellow.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: SpaceTheme.warningYellow.withValues(alpha: 0.5),
                ),
              ),
              child: const Text(
                'MODO SIMULACIÓN: Equipos físicos no disponibles; datos generados para pruebas (ver DB/simulation_and_pending_integrations.md).',
                style: TextStyle(fontSize: 10, color: SpaceTheme.warningYellow),
              ),
            ),
          ],
          const SizedBox(height: 4),
          const Text(
            'La presencia de un equipo en misión no garantiza acceso automático a su telemetría.',
            style: TextStyle(fontSize: 11, color: Colors.white54),
          ),
          const SizedBox(height: 10),
          ...devices.map(_buildDeviceRow),
        ],
      ),
    );
  }

  Widget _buildDeviceRow(TelemetryDeviceInfo device) {
    final Color statusColor;
    final IconData statusIcon;
    switch (device.status) {
      case DeviceAvailabilityStatus.connected:
        statusColor = SpaceTheme.green;
        statusIcon = Icons.check_circle_outline;
      case DeviceAvailabilityStatus.disconnected:
        statusColor = SpaceTheme.dangerRed;
        statusIcon = Icons.link_off;
      case DeviceAvailabilityStatus.pendingIntegration:
        statusColor = SpaceTheme.warningYellow;
        statusIcon = Icons.hourglass_empty;
    }

    final qualityText = device.validReadingsPercent != null
        ? ' • Válidas: ${device.validReadingsPercent!.toStringAsFixed(0)}%'
        : '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: SpaceTheme.card,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white10),
        ),
        child: Row(
          children: [
            Icon(statusIcon, color: statusColor, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    device.name,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    '${device.category} (${device.variables.join(', ')})$qualityText',
                    style: const TextStyle(fontSize: 11, color: Colors.white60),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: statusColor.withValues(alpha: 0.5)),
              ),
              child: Text(
                device.status.label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: statusColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
