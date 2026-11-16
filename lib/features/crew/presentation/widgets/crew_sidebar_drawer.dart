import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:astramed/features/01_general_health/presentation/cockpit_widgets/vitals_cockpit_cards.dart';
import 'package:astramed/features/05_clinical_triage/presentation/cockpit_widgets/medical_procedures_card.dart';
import 'package:astramed/features/agent/providers/agent_providers.dart';
import 'package:astramed/features/apolo/presentation/apolo_assessment_launcher_sheet.dart';
import 'package:astramed/features/apolo/presentation/apolo_theme.dart';
import 'package:astramed/features/apolo/domain/apolo_models.dart';
import 'package:astramed/features/apolo/providers/apolo_contract_providers.dart';
import 'package:astramed/features/apolo/providers/apolo_alert_state_provider.dart';
import 'package:astramed/features/crew/models/astronaut_profile.dart';
import 'package:astramed/features/crew/presentation/providers/crew_provider.dart';
import 'package:astramed/features/simulation/presentation/mission_simulator_card.dart';
import 'package:astramed/features/simulation/presentation/providers/mission_simulator_provider.dart';
import 'package:astramed/features/telemetry/presentation/providers/telemetry_provider.dart';
import 'package:astramed/features/telemetry/presentation/widgets/telemetry_config_modal.dart';

/// APOLO crew hub with offline cockpit tools and live crew status.
class CrewSidebarDrawer extends ConsumerWidget {
  const CrewSidebarDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crew = ref.watch(crewMembersProvider);
    final selectedId = ref.watch(selectedAstronautIdProvider);
    final telemetryState = ref.watch(telemetryProvider);

    final criticalCount = ref.watch(effectiveCriticalCrewCountProvider);
    final warningCount = ref.watch(effectiveWarningCrewCountProvider);
    final nominalCount = ref.watch(effectiveNominalCrewCountProvider);
    final apoloState = ref.watch(apoloActiveStateProvider);
    final palette = ApoloPalette.of(apoloState.highContrast);

    return Theme(
      data: buildApoloTheme(highContrast: apoloState.highContrast),
      child: Drawer(
      width: 360,
      backgroundColor: palette.bg,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.horizontal(right: Radius.circular(28)),
        side: BorderSide(color: palette.border),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // ── CABECERA DEL CREW HUB ──
            _buildDrawerHeader(context, criticalCount, warningCount, nominalCount, palette),
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
                  return _CrewAstronautCard(
                    astronaut: astronaut,
                    isSelected: isSelected,
                    connectedMachinesCount: connectedCount,
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
      ),
    );
  }

  /// Cabecera con resumen general de la tripulación
  Widget _buildDrawerHeader(
    BuildContext context,
    int criticalCount,
    int warningCount,
    int nominalCount,
    ApoloPalette palette,
  ) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [palette.bg2, palette.surface]),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: palette.lav2.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: palette.lav2, width: 1.5),
                ),
                child: Icon(Icons.groups, color: palette.lav2, size: 24),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                       'ARTEMIS CREW',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        letterSpacing: 1.2,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                       'APOLO Crew Hub (5 Astronauts)',
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
                label: '$criticalCount Critical',
                color: palette.crit,
                icon: Icons.error_outline,
              ),
              const SizedBox(width: 6),
              _buildStatusPill(
                label: '$warningCount Attention',
                color: palette.warn,
                icon: Icons.warning_amber_rounded,
              ),
              const SizedBox(width: 6),
              _buildStatusPill(
                label: '$nominalCount Nominal',
                color: palette.ok,
                icon: Icons.check_circle_outline,
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Muestra una métrica compacta en el preview de cada tarjeta
  static Widget _buildMiniMetric({
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
            color: isWarning ? ApoloPalette.standard.crit : Colors.white,
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

  /// Pie del drawer con accesos rápidos a todas las herramientas de cabina
  Widget _buildDrawerFooter(
    BuildContext context,
    WidgetRef ref,
    String selectedId,
  ) {
    final highContrast = ref.watch(apoloActiveStateProvider).highContrast;
    final palette = ApoloPalette.of(highContrast);
    void openCockpitSheet(Widget Function(BuildContext sheetContext) builder) {
      final rootContext = Navigator.of(context, rootNavigator: true).context;
      Navigator.of(context).pop();
      showModalBottomSheet<void>(
        context: rootContext,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (sheetContext) => Theme(
          data: buildApoloTheme(highContrast: highContrast),
          child: SafeArea(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.88,
              ),
              child: Container(
                margin: const EdgeInsets.fromLTRB(10, 10, 10, 10),
                decoration: BoxDecoration(
                  color: palette.bg2,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: palette.border),
                ),
                clipBehavior: Clip.antiAlias,
                child: builder(sheetContext),
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  key: const ValueKey('sidebar_mission_simulator_button'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: palette.lav2,
                    side: BorderSide(color: palette.border),
                    minimumSize: const Size(0, 36),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  icon: const Icon(Icons.rocket_launch_outlined, size: 15),
                  label: const Text(
                    'Simulator',
                    style: TextStyle(fontSize: 11.5),
                    overflow: TextOverflow.ellipsis,
                  ),
                  onPressed: () => openCockpitSheet(
                    (sheetCtx) => MissionSimulatorCard(
                      onDismiss: () => Navigator.of(sheetCtx).pop(),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: OutlinedButton.icon(
                  key: const ValueKey('sidebar_assessments_button'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: palette.lav2,
                    side: BorderSide(color: palette.border),
                    minimumSize: const Size(0, 36),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  icon: const Icon(Icons.fitness_center, size: 15),
                  label: const Text(
                    'Tests',
                    style: TextStyle(fontSize: 11.5),
                    overflow: TextOverflow.ellipsis,
                  ),
                  onPressed: () {
                    final orchestrator = ref.read(agentOrchestratorProvider.notifier);
                    final speakReply = ref.read(agentVoiceRepliesEnabledProvider);
                    final rootContext =
                        Navigator.of(context, rootNavigator: true).context;
                    Navigator.of(context).pop();
                    ApoloAssessmentLauncherSheet.show(
                      rootContext,
                      onLaunch: (descriptor) {
                        orchestrator.launchGuidedAssessment(
                              descriptor,
                              speakReply: speakReply,
                            );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  key: const ValueKey('sidebar_manual_vitals_button'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: palette.mint,
                    side: BorderSide(color: palette.border),
                    minimumSize: const Size(0, 36),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  icon: const Icon(Icons.touch_app_outlined, size: 15),
                  label: const Text(
                    'Manual Vitals',
                    style: TextStyle(fontSize: 11.5),
                    overflow: TextOverflow.ellipsis,
                  ),
                  onPressed: () => openCockpitSheet(
                    (sheetCtx) => SingleChildScrollView(
                      padding: const EdgeInsets.all(12),
                      child: ManualVitalsTapCard(
                        astronautId: selectedId,
                        onSubmit: (_) => Navigator.of(sheetCtx).pop(),
                        onDismiss: () => Navigator.of(sheetCtx).pop(),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: OutlinedButton.icon(
                  key: const ValueKey('sidebar_procedures_button'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: palette.lav2,
                    side: BorderSide(color: palette.border),
                    minimumSize: const Size(0, 36),
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  icon: const Icon(Icons.medical_services_outlined, size: 15),
                  label: const Text(
                    'Procedures',
                    style: TextStyle(fontSize: 11.5),
                    overflow: TextOverflow.ellipsis,
                  ),
                  onPressed: () => openCockpitSheet(
                    (sheetCtx) => SingleChildScrollView(
                      padding: const EdgeInsets.all(12),
                      child: MedicalProceduresCockpitCard(
                        astronautId: selectedId,
                        onDismiss: () => Navigator.of(sheetCtx).pop(),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          OutlinedButton.icon(
            key: const ValueKey('sidebar_vitals_chart_button'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white24),
              minimumSize: const Size(double.infinity, 36),
            ),
            icon: const Icon(Icons.show_chart_rounded, size: 16),
            label: const Text(
              'Vitals Trends',
              style: TextStyle(fontSize: 12),
            ),
            onPressed: () => openCockpitSheet(
              (sheetCtx) => SingleChildScrollView(
                padding: const EdgeInsets.all(12),
                child: VitalsTrendCockpitCard(
                  astronautId: selectedId,
                  onDismiss: () => Navigator.of(sheetCtx).pop(),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          ElevatedButton.icon(
            key: const ValueKey('sidebar_telemetry_config_button'),
            style: ElevatedButton.styleFrom(
              backgroundColor: palette.elev,
              foregroundColor: palette.text,
              minimumSize: const Size(double.infinity, 36),
            ),
            icon: const Icon(Icons.settings_input_antenna, size: 16),
            label: const Text(
              'Configure Telemetry Machines',
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
          const SizedBox(height: 6),
          OutlinedButton.icon(
            key: const ValueKey('sidebar_reset_nominal_button'),
            style: OutlinedButton.styleFrom(
              foregroundColor: palette.mint,
              side: BorderSide(color: palette.border),
              minimumSize: const Size(double.infinity, 36),
            ),
            icon: const Icon(Icons.sync, size: 16),
            label: const Text(
              'Reset All Nominal',
              style: TextStyle(fontSize: 12),
            ),
            onPressed: () {
              ref.read(missionSimulatorProvider.notifier).resetNominal();
              ref.read(telemetryProvider.notifier).resetToInitial();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Crew reset to nominal (Day 1)',
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

}

class _CrewAstronautCard extends ConsumerStatefulWidget {
  const _CrewAstronautCard({
    required this.astronaut,
    required this.isSelected,
    required this.connectedMachinesCount,
  });

  final AstronautProfile astronaut;
  final bool isSelected;
  final int connectedMachinesCount;

  @override
  ConsumerState<_CrewAstronautCard> createState() => _CrewAstronautCardState();
}

class _CrewAstronautCardState extends ConsumerState<_CrewAstronautCard> {
  bool _showAllAlerts = false;

  @override
  Widget build(BuildContext context) {
    final astronaut = widget.astronaut;
    final isSelected = widget.isSelected;
    final connectedMachinesCount = widget.connectedMachinesCount;
    final highContrast = ref.watch(apoloActiveStateProvider).highContrast;
    final palette = ApoloPalette.of(highContrast);
    final status = ref.watch(crewEffectiveStatusesProvider)[astronaut.id];
    final alerts = status?.alerts ?? astronaut.activeAlerts;
    final extraCount =
        status?.extraIssueCount ?? (alerts.length > 1 ? alerts.length - 1 : 0);
    if (extraCount == 0 && _showAllAlerts) {
      _showAllAlerts = false;
    }
    final severity = status?.severity ??
        switch (astronaut.riskLevel) {
          CrewRiskLevel.critical => ApoloSeverity.crit,
          CrewRiskLevel.warning => ApoloSeverity.warn,
          CrewRiskLevel.nominal => ApoloSeverity.ok,
        };
    final statusColor = palette.forSeverity(severity);

    return Card(
      key: ValueKey('crew_status_${astronaut.id}'),
      margin: const EdgeInsets.symmetric(vertical: 6),
      elevation: isSelected ? 4 : 1,
      color: isSelected
          ? palette.elev
          : palette.surface.withValues(alpha: highContrast ? 1 : 0.78),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected
              ? palette.lav2
              : (severity != ApoloSeverity.ok ? statusColor : palette.border),
          width: isSelected ? 2.0 : (severity != ApoloSeverity.ok ? 1.5 : 1.0),
        ),
      ),
      child: InkWell(
        key: ValueKey('crew_drawer_item_${astronaut.id}'),
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          // Cambia el astronauta activo en crew y en el agente APOLO
          ref.read(selectedAstronautIdProvider.notifier).state = astronaut.id;
          ref
              .read(agentOrchestratorProvider.notifier)
              .switchAstronaut(astronaut.id);
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
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: statusColor, width: 1.5),
                          boxShadow: highContrast
                              ? null
                              : [
                                  BoxShadow(
                                    color: statusColor.withValues(alpha: 0.25),
                                    blurRadius: 18,
                                  ),
                                ],
                        ),
                        child: CircleAvatar(
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
                            border: Border.all(
                              color: palette.surface,
                              width: 2,
                            ),
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
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white10,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                astronaut.callsign,
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: palette.lav2,
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: palette.mint,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        'ACTIVE',
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

              ApoloStatusChip(
                severity: severity,
                highContrast: highContrast,
                compact: true,
              ),
              const SizedBox(height: 6),
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
                    Icon(
                      apoloSeverityIcon(severity),
                      size: 14,
                      color: statusColor,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        status?.title ?? astronaut.riskTitle,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (extraCount > 0) ...[
                      const SizedBox(width: 6),
                      Tooltip(
                        message: alerts.join('\n'),
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => setState(
                            () => _showAllAlerts = !_showAllAlerts,
                          ),
                          child: Container(
                            key: ValueKey(
                              'crew_extra_alerts_badge_${astronaut.id}',
                            ),
                            width: 22,
                            height: 22,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: statusColor,
                              shape: BoxShape.circle,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(2),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  '+$extraCount',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: severity == ApoloSeverity.crit
                                        ? Colors.white
                                        : const Color(0xFF0B0C1E),
                                    height: 1.0,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 8),

              // ── PREVIEW DE TELEMETRÍA RÁPIDA (FC, SpO2, PA) ──
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: palette.bg2,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CrewSidebarDrawer._buildMiniMetric(
                        label: 'HR',
                        value: '${astronaut.vitals.heartRate.toInt()} bpm',
                        isWarning: astronaut.vitals.heartRate > 100 ||
                            astronaut.vitals.heartRate < 50,
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 6),
                        child: Text(
                          '|',
                          style: TextStyle(color: Colors.white24, fontSize: 10),
                        ),
                      ),
                      CrewSidebarDrawer._buildMiniMetric(
                        label: 'SpO2',
                        value: '${astronaut.vitals.spO2.toInt()}%',
                        isWarning: astronaut.vitals.spO2 < 94,
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 6),
                        child: Text(
                          '|',
                          style: TextStyle(color: Colors.white24, fontSize: 10),
                        ),
                      ),
                      CrewSidebarDrawer._buildMiniMetric(
                        label: 'BP',
                        value:
                            '${astronaut.vitals.systolicBP.toInt()}/${astronaut.vitals.diastolicBP.toInt()}',
                        isWarning: astronaut.vitals.systolicBP > 130 ||
                            astronaut.vitals.systolicBP < 90,
                      ),
                    ],
                  ),
                ),
              ),

              // Alerta principal si existe riesgo
              if (alerts.isNotEmpty) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.bolt, color: Colors.amberAccent, size: 12),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        alerts.first,
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
                if (_showAllAlerts && alerts.length > 1)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, left: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final extra in alerts.skip(1))
                          Padding(
                            padding: const EdgeInsets.only(bottom: 2),
                            child: Text(
                              '• $extra',
                              style: const TextStyle(
                                fontSize: 10,
                                color: Colors.amberAccent,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ),
                      ],
                    ),
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
                        ? palette.mint
                        : Colors.white38,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      '$connectedMachinesCount active • ${astronaut.vitals.source.toUpperCase()}',
                      style: TextStyle(
                        fontSize: 10,
                        color: connectedMachinesCount > 0
                            ? palette.mint
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
                        color: palette.elev,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: palette.border,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.settings_input_antenna,
                            size: 11,
                            color: palette.lav2,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            'Config',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: palette.lav2,
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
}
