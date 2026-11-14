import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
      title: 'AstraMed - Space Health Engine',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF00E5FF),
          brightness: Brightness.dark,
          surface: const Color(0xFF0D1117),
        ),
        scaffoldBackgroundColor: const Color(0xFF070A0F),
        useMaterial3: true,
      ),
      home: const AstraMedDashboard(),
    );
  }
}

class AstraMedDashboard extends StatelessWidget {
  const AstraMedDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.monitor_heart, color: Color(0xFF00E5FF)),
            SizedBox(width: 10),
            Text('AstraMed | Space Health Engine'),
          ],
        ),
        backgroundColor: const Color(0xFF0D1117),
        elevation: 0,
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.rocket_launch_outlined,
              size: 80,
              color: Color(0xFF00E5FF),
            ),
            SizedBox(height: 20),
            Text(
              'AstraMed Operational',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            SizedBox(height: 8),
            Text(
              '100% Offline-First Crew Health Monitoring System',
              style: TextStyle(
                fontSize: 14,
                color: Colors.white70,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
