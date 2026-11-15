import 'dart:async';

import 'package:astramed/core/theme/space_theme.dart';
import 'package:astramed/features/02_radiation/models/radiation_dose.dart';
import 'package:astramed/features/04_mental_health/models/sleep_record.dart';
import 'package:astramed/features/crew/models/astronaut_profile.dart';
import 'package:astramed/features/crew/presentation/providers/crew_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum MissionType { orbital, lunar, transit, surface }
enum SimulationEvent { sleepLoss, solarParticleEvent, exerciseFailure, workload }

/// Prototipo local para crear condiciones de prueba trazables en los perfiles.
class MissionSimulatorView extends ConsumerStatefulWidget {
  const MissionSimulatorView({super.key});

  @override
  ConsumerState<MissionSimulatorView> createState() => _MissionSimulatorViewState();
}

class _MissionSimulatorViewState extends ConsumerState<MissionSimulatorView> {
  MissionType _missionType = MissionType.lunar;
  int _missionDay = 12;
  bool _running = false;
  Timer? _timer;
  final List<String> _log = [];

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _toggleTime() {
    setState(() => _running = !_running);
    _timer?.cancel();
    if (_running) {
      _timer = Timer.periodic(const Duration(seconds: 2), (_) => _advanceDay());
    }
  }

  void _advanceDay() {
    setState(() {
      _missionDay++;
      _log.insert(0, 'Día $_missionDay: avance de tiempo simulado');
    });
  }

  void _applyEvent(SimulationEvent event, AstronautProfile crew) {
    final now = DateTime.now();
    final notifier = ref.read(crewMembersProvider.notifier);
    final affected = crew;
    final label = _eventLabel(event);
    final vitals = affected.vitals.copyWith(
      timestamp: now,
      source: 'simulation',
      device: 'Simulador de misión AstraMed',
      recordType: 'estimación',
      missionDay: _missionDay,
      activityState: event == SimulationEvent.exerciseFailure ? 'active_duty' : 'emergency_triage',
      heartRate: event == SimulationEvent.workload ? (affected.vitals.heartRate + 22).clamp(0, 220).toDouble() : affected.vitals.heartRate,
      respiratoryRate: event == SimulationEvent.workload ? (affected.vitals.respiratoryRate + 5).clamp(0, 60).toDouble() : affected.vitals.respiratoryRate,
    );
    final sleep = affected.sleep.copyWith(
      date: now,
      source: 'simulation',
      recordType: 'estimación',
      sleepHours: event == SimulationEvent.sleepLoss ? (affected.sleep.sleepHours - 3).clamp(0, 24).toDouble() : affected.sleep.sleepHours,
      wakeEpisodes: event == SimulationEvent.sleepLoss ? affected.sleep.wakeEpisodes + 3 : affected.sleep.wakeEpisodes,
      morningMood: event == SimulationEvent.sleepLoss ? MoodLevel.fatigued : affected.sleep.morningMood,
    );
    final radiation = affected.radiation.copyWith(
      timestamp: now,
      source: 'simulation',
      recordType: 'estimación',
      doseRateMicroSvPerHour: event == SimulationEvent.solarParticleEvent ? 180 : affected.radiation.doseRateMicroSvPerHour,
      cumulativeDoseMilliSv: event == SimulationEvent.solarParticleEvent ? affected.radiation.cumulativeDoseMilliSv + 1.5 : affected.radiation.cumulativeDoseMilliSv,
      severity: event == SimulationEvent.solarParticleEvent ? RadiationSeverity.critical : affected.radiation.severity,
    );
    final exercise = affected.exercise.copyWith(
      date: now,
      source: 'simulation',
      recordType: 'estimación',
      targetReached: event == SimulationEvent.exerciseFailure ? false : affected.exercise.targetReached,
    );
    notifier.applySimulationProfile(
      astronautId: affected.id,
      vitals: vitals,
      sleep: sleep,
      radiation: radiation,
      exercise: exercise,
      eventLabel: label,
    );
    setState(() => _log.insert(0, 'Día $_missionDay · ${affected.callsign}: $label'));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label aplicado a ${affected.name}. Revisa su estado clínico.')),
    );
  }

  String _missionLabel(MissionType type) => switch (type) {
        MissionType.orbital => 'Órbita terrestre',
        MissionType.lunar => 'Misión lunar',
        MissionType.transit => 'Tránsito a Marte',
        MissionType.surface => 'Superficie planetaria',
      };

  String _eventLabel(SimulationEvent event) => switch (event) {
        SimulationEvent.sleepLoss => 'Déficit de sueño',
        SimulationEvent.solarParticleEvent => 'Evento de partículas solares',
        SimulationEvent.exerciseFailure => 'Falla de contramedida física',
        SimulationEvent.workload => 'Sobrecarga operativa',
      };

  IconData _eventIcon(SimulationEvent event) => switch (event) {
        SimulationEvent.sleepLoss => Icons.bedtime_off,
        SimulationEvent.solarParticleEvent => Icons.sunny_snowing,
        SimulationEvent.exerciseFailure => Icons.fitness_center,
        SimulationEvent.workload => Icons.assignment_late,
      };

  @override
  Widget build(BuildContext context) {
    final crew = ref.watch(crewMembersProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Simulación de misión'), backgroundColor: SpaceTheme.surface),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _section('MISIÓN ACTIVA', [
            DropdownButtonFormField<MissionType>(
              value: _missionType,
              decoration: const InputDecoration(labelText: 'Tipo de misión'),
              items: MissionType.values.map((type) => DropdownMenuItem(value: type, child: Text(_missionLabel(type)))).toList(),
              onChanged: (value) => setState(() => _missionType = value!),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: Text('DÍA $_missionDay', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: SpaceTheme.cyan))),
              IconButton(onPressed: _missionDay > 1 ? () => setState(() => _missionDay--) : null, icon: const Icon(Icons.remove_circle_outline)),
              IconButton(onPressed: _advanceDay, icon: const Icon(Icons.add_circle_outline)),
              FilledButton.icon(onPressed: _toggleTime, icon: Icon(_running ? Icons.pause : Icons.play_arrow), label: Text(_running ? 'Pausar' : 'Avanzar')),
            ]),
            const Text('Los registros aplicados llevan la fuente “simulation” y sirven para probar el triage.', style: TextStyle(color: Colors.white60)),
          ]),
          const SizedBox(height: 16),
          _section('APLICAR EVENTO', [
            ...SimulationEvent.values.map((event) => Card(
              child: ExpansionTile(
                leading: Icon(_eventIcon(event), color: SpaceTheme.warningYellow),
                title: Text(_eventLabel(event)),
                subtitle: const Text('Selecciona el tripulante afectado'),
                children: crew.map((member) => ListTile(
                  leading: CircleAvatar(child: Text(member.avatarInitials)),
                  title: Text(member.name),
                  subtitle: Text(member.role),
                  trailing: const Icon(Icons.add_alert),
                  onTap: () => _applyEvent(event, member),
                )).toList(),
              ),
            )),
          ]),
          const SizedBox(height: 16),
          _section('BITÁCORA DE SIMULACIÓN', _log.isEmpty
              ? [const Padding(padding: EdgeInsets.all(12), child: Text('Aún no hay eventos. Avanza el tiempo o aplica un evento.', style: TextStyle(color: Colors.white60)))]
              : _log.map((entry) => ListTile(leading: const Icon(Icons.history, size: 18), title: Text(entry))).toList()),
        ],
      ),
    );
  }

  Widget _section(String title, List<Widget> children) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: SpaceTheme.card, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white12)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(color: SpaceTheme.cyan, fontWeight: FontWeight.bold, letterSpacing: 1.1)), const SizedBox(height: 12), ...children]),
      );
}
