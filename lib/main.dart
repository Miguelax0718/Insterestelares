import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/space_theme.dart';
import 'features/01_general_health/presentation/general_health_view.dart';
import 'features/02_radiation/presentation/radiation_view.dart';
import 'features/03_microgravity/presentation/microgravity_view.dart';
import 'features/04_mental_health/presentation/mental_health_view.dart';
import 'features/05_clinical_triage/presentation/triage_view.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const ProviderScope(
      child: AstraMedApp(),
    ),
  );
}

class AstraMedApp extends StatelessWidget {
  const AstraMedApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AstraMed | Space Health Engine',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      darkTheme: SpaceTheme.darkTheme,
      home: const AstraMedDashboard(),
    );
  }
}

class AstraMedDashboard extends StatefulWidget {
  const AstraMedDashboard({super.key});

  @override
  State<AstraMedDashboard> createState() => _AstraMedDashboardState();
}

class _AstraMedDashboardState extends State<AstraMedDashboard> {
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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.rocket_launch, color: SpaceTheme.cyan),
            const SizedBox(width: 10),
            Text(
              _titles[_currentIndex],
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Estado de Conectividad',
            icon: const Icon(Icons.wifi_off, color: Colors.amberAccent),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Modo 100% Offline activo - Espacio Profundo'),
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
