import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:astramed/core/storage/hive_bootstrap.dart';
import 'package:astramed/core/theme/space_theme.dart';
import 'package:astramed/features/agent/data/persistence/agent_hive_boxes.dart';
import 'package:astramed/features/agent/providers/agent_providers.dart';
import 'package:astramed/features/apolo/presentation/apolo_home_screen.dart';
import 'package:astramed/features/apolo/providers/apolo_providers.dart';
import 'package:astramed/features/crew/presentation/providers/crew_provider.dart';
import 'package:astramed/features/crew/data/mock_crew_data.dart';
import 'package:astramed/features/simulation/presentation/providers/mission_simulator_provider.dart';
import 'package:astramed/features/telemetry/presentation/providers/telemetry_provider.dart';

import 'features/02_radiation/providers/radiation_integration_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await HiveBootstrap.initFlutterStorage();
  await AgentHiveBoxes.open();
  runApp(const ApoloApp());
}

class ApoloApp extends StatelessWidget {
  const ApoloApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        ...radiationIntegrationOverrides,
        ...apoloProviderOverrides,
        apoloStartNominalProvider.overrideWithValue(true),
        crewMembersProvider.overrideWith((ref) => CrewNotifier(
          ref.watch(crewDatabaseServiceProvider), MockCrewData.getNominalCrew(),
        )),
      ],
      child: MaterialApp(
        title: 'APOLO',
        debugShowCheckedModeBanner: false,
        themeMode: ThemeMode.dark,
        darkTheme: SpaceTheme.darkTheme,
        home: const ApoloHomeShell(),
      ),
    );
  }
}

/// Hosts the unified APOLO home screen as the sole entry point and initializes
/// all 5 crew profiles in a clean Day 1 nominal baseline for progressive
/// mission simulation.
class ApoloHomeShell extends ConsumerStatefulWidget {
  const ApoloHomeShell({super.key});

  @override
  ConsumerState<ApoloHomeShell> createState() => _ApoloHomeShellState();
}

class _ApoloHomeShellState extends ConsumerState<ApoloHomeShell> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!mounted) return;
      ref.read(missionSimulatorProvider.notifier).initializeNominal();
      final crew = ref.read(crewMembersProvider);
      ref.read(telemetryProvider.notifier).syncWithCrewData(crew);
      ref.read(proactiveMonitorProvider).start();
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(proactiveMonitorProvider);
    ref.watch(agentNotifierProvider);
    return const ApoloHomeScreen();
  }
}
