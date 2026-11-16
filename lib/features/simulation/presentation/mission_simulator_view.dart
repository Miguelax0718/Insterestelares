import 'package:flutter/material.dart';
import '../../apolo/presentation/apolo_theme.dart';
import 'mission_simulator_card.dart';
export '../domain/mission_simulator_state.dart';

/// Compatibility route; all interactive behavior lives in the cockpit card.
class MissionSimulatorView extends StatelessWidget {
  const MissionSimulatorView({super.key});

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: buildApoloTheme(),
      child: Scaffold(
        appBar: AppBar(title: const Text('Mission Simulator')),
        body: const MissionSimulatorCard(),
      ),
    );
  }
}
