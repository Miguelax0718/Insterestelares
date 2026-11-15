import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:astramed/core/theme/space_theme.dart';
import 'package:astramed/features/01_general_health/presentation/general_health_view.dart';
import 'package:astramed/features/02_radiation/presentation/radiation_view.dart';
import 'package:astramed/features/03_microgravity/presentation/microgravity_view.dart';
import 'package:astramed/features/04_mental_health/presentation/mental_health_view.dart';
import 'package:astramed/features/05_clinical_triage/presentation/triage_view.dart';
import 'package:astramed/features/agent/data/persistence/agent_hive_boxes.dart';
import 'package:astramed/features/agent/presentation/agent_canvas_view.dart';
import 'package:astramed/features/agent/presentation/agent_test_screen.dart';
import 'package:astramed/features/agent/providers/agent_providers.dart';
import 'package:astramed/features/crew/models/astronaut_profile.dart';
import 'package:astramed/features/crew/presentation/providers/crew_provider.dart';
import 'package:astramed/features/crew/presentation/widgets/crew_sidebar_drawer.dart';
import 'package:astramed/features/telemetry/presentation/providers/telemetry_provider.dart';
import 'package:astramed/features/telemetry/presentation/widgets/telemetry_config_modal.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await AgentHiveBoxes.open();
  runApp(const AstraMedApp());
}

class AstraMedApp extends StatelessWidget {
  const AstraMedApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      child: MaterialApp(
        title: 'AstraMed | Space Health Engine',
        debugShowCheckedModeBanner: false,
        themeMode: ThemeMode.dark,
        darkTheme: SpaceTheme.darkTheme,
        home: const AstraMedDashboard(),
      ),
    );
  }
}

class AstraMedDashboard extends ConsumerStatefulWidget {
  const AstraMedDashboard({super.key});

  @override
  ConsumerState<AstraMedDashboard> createState() => _AstraMedDashboardState();
}

class _AstraMedDashboardState extends ConsumerState<AstraMedDashboard> {
  int _currentIndex = 0;

  final List<Widget> _views = const [
    GeneralHealthView(),
    RadiationView(),
    MicrogravityView(),
    MentalHealthView(),
    TriageView(),
  ];

  final List<String> _titles = const [
    'Monitor de Salud General',
    'Dosímetro de Radiación',
    'Microgravedad & Fisiología',
    'Salud Mental & Sueño',
    'Triage Autónomo & Soporte',
  ];

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      await ref.read(crewMembersProvider.notifier).initializeFromDatabase();
      final crew = ref.read(crewMembersProvider);
      ref.read(telemetryProvider.notifier).syncWithCrewData(crew);
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(proactiveMonitorProvider);
    ref.watch(agentNotifierProvider);
    final activeAstronaut = ref.watch(selectedAstronautProvider);
    final criticalCount = ref.watch(criticalCrewCountProvider);
    final connectedCount = ref.watch(connectedMachinesForSelectedProvider).length;
    final isStreaming = ref.watch(isTelemetryStreamingProvider);

    final statusColor = activeAstronaut.riskLevel == CrewRiskLevel.critical
        ? SpaceTheme.dangerRed
        : (activeAstronaut.riskLevel == CrewRiskLevel.warning
            ? SpaceTheme.warningYellow
            : SpaceTheme.green);

    return Scaffold(
      // ── SIDEBAR IZQUIERDO PARA GESTIÓN DE LOS 5 PERFILES ──
      drawer: const CrewSidebarDrawer(),

      appBar: AppBar(
        leading: Builder(
          builder: (drawerContext) => IconButton(
            tooltip: 'Abrir Crew Hub (5 Tripulantes)',
            icon: Badge(
              isLabelVisible: criticalCount > 0,
              backgroundColor: SpaceTheme.dangerRed,
              label: Text(
                '$criticalCount',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              child: const Icon(Icons.menu, color: SpaceTheme.cyan),
            ),
            onPressed: () {
              Scaffold.of(drawerContext).openDrawer();
            },
          ),
        ),
        title: Builder(
          builder: (drawerContext) => InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () {
              Scaffold.of(drawerContext).openDrawer();
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 15,
                    backgroundColor: statusColor.withValues(alpha: 0.2),
                    child: Text(
                      activeAstronaut.avatarInitials,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                activeAstronaut.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 2),
                            const Icon(
                              Icons.arrow_drop_down,
                              size: 18,
                              color: SpaceTheme.cyan,
                            ),
                          ],
                        ),
                        Text(
                          _titles[_currentIndex],
                          style: const TextStyle(fontSize: 10, color: Colors.white70),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Autonomous Clinical Agent',
            icon: const Icon(Icons.smart_toy_outlined, color: SpaceTheme.cyan),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AgentCanvasView()),
            ),
          ),
          IconButton(
            tooltip: 'Agent console',
            icon: const Icon(Icons.graphic_eq),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AgentTestScreen()),
            ),
          ),
          // Badge rápido de estado de riesgo del astronauta activo
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: statusColor.withValues(alpha: 0.6)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  activeAstronaut.riskLevel == CrewRiskLevel.critical
                      ? Icons.emergency
                      : (activeAstronaut.riskLevel == CrewRiskLevel.warning
                          ? Icons.warning_amber
                          : Icons.check_circle),
                  size: 12,
                  color: statusColor,
                ),
                const SizedBox(width: 4),
                Text(
                  activeAstronaut.riskLevel == CrewRiskLevel.critical
                      ? 'CRÍTICO'
                      : (activeAstronaut.riskLevel == CrewRiskLevel.warning
                          ? 'ATENCIÓN'
                          : 'NOMINAL'),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ],
            ),
          ),

          // Botón de configuración de máquinas de telemetría por tripulante
          IconButton(
            tooltip: 'Configurar Máquinas de Telemetría (${activeAstronaut.callsign})',
            icon: Badge(
              isLabelVisible: true,
              backgroundColor: isStreaming ? SpaceTheme.green : SpaceTheme.cyan,
              textColor: Colors.black,
              label: Text(
                '$connectedCount',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              child: Icon(
                Icons.settings_input_antenna,
                color: isStreaming ? SpaceTheme.green : SpaceTheme.cyan,
                size: 21,
              ),
            ),
            onPressed: () {
              TelemetryConfigModal.show(
                context,
                initialAstronautId: activeAstronaut.id,
              );
            },
          ),

          // Indicador de modo 100% Offline
          IconButton(
            tooltip: 'Estado de Conectividad (100% Offline)',
            icon: const Icon(Icons.wifi_off, color: Colors.amberAccent, size: 20),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('AstraMed opera 100% Offline en Espacio Profundo'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
          ),
        ],
      ),
      body: _views[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.monitor_heart_outlined),
            selectedIcon: Icon(Icons.monitor_heart, color: SpaceTheme.cyan),
            label: 'Salud',
          ),
          NavigationDestination(
            icon: Icon(Icons.shield_outlined),
            selectedIcon: Icon(Icons.shield, color: SpaceTheme.cyan),
            label: 'Radiación',
          ),
          NavigationDestination(
            icon: Icon(Icons.accessibility_new_outlined),
            selectedIcon: Icon(Icons.accessibility_new, color: SpaceTheme.cyan),
            label: 'Microgravedad',
          ),
          NavigationDestination(
            icon: Icon(Icons.bedtime_outlined),
            selectedIcon: Icon(Icons.bedtime, color: SpaceTheme.cyan),
            label: 'Descanso',
          ),
          NavigationDestination(
            icon: Icon(Icons.health_and_safety_outlined),
            selectedIcon: Icon(Icons.health_and_safety, color: SpaceTheme.cyan),
            label: 'Triage',
          ),
        ],
      ),
    );
  }
}
