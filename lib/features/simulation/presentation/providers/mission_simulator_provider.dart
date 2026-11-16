import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../02_radiation/models/radiation_dose.dart';
import '../../../02_radiation/providers/biomarker_providers.dart';
import '../../../apolo/providers/apolo_providers.dart';
import '../../../crew/presentation/providers/crew_provider.dart';
import '../../domain/mission_simulator_state.dart';

export '../../domain/mission_simulator_state.dart';

final missionSimulatorProvider =
    StateNotifierProvider<MissionSimulatorNotifier, MissionSimulatorState>(
      (ref) => MissionSimulatorNotifier(ref),
    );

/// Deterministic synthetic scenarios for exercising the existing clinical rules.
class MissionSimulatorNotifier extends StateNotifier<MissionSimulatorState> {
  MissionSimulatorNotifier(this._ref) : super(const MissionSimulatorState());
  final Ref _ref;
  Timer? _timer;

  /// Episodio leve que cada astronauta tiene aplicado ahora mismo.
  final Map<String, MissionEpisode> _activeEpisodes = {};

  void _log(String message) {
    state = state.copyWith(log: [
      'Day ${state.missionDay}: $message',
      ...state.log,
    ].take(50).toList());
  }

  void initializeNominal() => resetNominal();

  void resetNominal() {
    setRunning(false);
    _activeEpisodes.clear();
    _ref.read(crewMembersProvider.notifier).resetAllNominal();
    _ref.read(apoloStateNotifierProvider.notifier).resetAllNominal();
    _ref.read(selectedMissionDayProvider.notifier).state = 1;
    state = MissionSimulatorState(missionType: state.missionType);
    _log('Nominal baseline restored');
  }

  void setMissionType(MissionType type) {
    state = state.copyWith(missionType: type);
    _log('Mission type: ${type.name}');
  }

  void toggleRunning() => setRunning(!state.isRunning);

  void setRunning(bool running) {
    if (running == state.isRunning) return;
    _timer?.cancel();
    _timer = null;
    state = state.copyWith(isRunning: running);
    if (running) {
      _timer = Timer.periodic(const Duration(seconds: 3), (_) => advanceDays());
    }
    _log(running ? 'Simulation started' : 'Simulation paused');
  }

  void advanceDays([int days = 1]) {
    if (days < 1 || days > 365) {
      throw ArgumentError.value(days, 'days', 'Expected 1–365 days');
    }
    for (var i = 0; i < days; i++) {
      final factor = switch (state.missionType) {
        MissionType.orbital => 0.6,
        MissionType.lunar => 1.0,
        MissionType.transit => 1.4,
        MissionType.surface => 1.6,
      };
      final day = state.missionDay + 1;
      // Un día sin incidentes: la tripulación se adapta y se estabiliza
      // (ver MissionDrift). Los fallos graves salen de triggerEvent.
      final sleepDelta = MissionDrift.sleepDelta(state.missionType, day);
      _ref.read(crewMembersProvider.notifier).applyProgressiveDay(
        missionDay: day,
        doseRateDeltaMicroSv: 0,
        cumulativeDoseDeltaMsv: 0.15 * factor,
        sleepDeltaHours: sleepDelta,
        hrDelta: 0,
        bpDelta: MissionDrift.bpDelta(day),
        exerciseTargetMet: true,
      );
      _ref.read(apoloStateNotifierProvider.notifier).applySimulationProgress(
        missionDay: day,
        extraDoseMsv: 0.15 * factor,
        sleepDeltaHours: sleepDelta,
      );
      _ref.read(selectedMissionDayProvider.notifier).state = day;
      state = state.copyWith(missionDay: day);
      _applyEpisodes(day);
      _log('Nominal ${state.missionType.name} day');
    }
  }

  /// Aplica o retira los episodios leves del día (mareo espacial, mala
  /// noche, infección leve...). Cada uno se resuelve solo al terminar.
  void _applyEpisodes(int day) {
    final crew = _ref.read(crewMembersProvider.notifier);
    for (final p in List.of(_ref.read(crewMembersProvider))) {
      final previous = _activeEpisodes[p.id];
      final current = MissionEpisodes.activeOn(p.id, day);
      if (previous == null && current == null) continue;

      // Se quita el efecto del episodio anterior y se pone el del actual.
      double change(double Function(MissionEpisode) of) =>
          (current == null ? 0 : of(current)) -
          (previous == null ? 0 : of(previous));
      crew.applySimulationProfile(
        astronautId: p.id,
        vitals: p.vitals.copyWith(
          heartRate: p.vitals.heartRate + change((e) => e.hr),
          bodyTemp: p.vitals.bodyTemp + change((e) => e.temp),
          respiratoryRate:
              p.vitals.respiratoryRate + change((e) => e.respiratoryRate),
        ),
        sleep: p.sleep.copyWith(
          sleepHours: p.sleep.sleepHours + change((e) => e.sleep),
        ),
        radiation: p.radiation,
        exercise: p.exercise.copyWith(
          targetReached: !(current?.missesExercise ?? false),
        ),
        eventLabel: current?.label ?? 'Mission day $day',
      );

      if (current == null) {
        _activeEpisodes.remove(p.id);
        _log('${previous!.label} resolved → ${p.id}');
      } else {
        _activeEpisodes[p.id] = current;
        if (current != previous) _log('${current.label} → ${p.id}');
      }
    }
  }

  void triggerEvent(SimulationEvent event, {String? astronautId}) {
    final String id = astronautId ?? _ref.read(selectedAstronautIdProvider);
    final crew = _ref.read(crewMembersProvider);
    final matches = crew.where((p) => p.id == id);
    if (matches.isEmpty) throw ArgumentError.value(id, 'astronautId', 'Unknown astronaut');
    final p = matches.first;
    final workload = event == SimulationEvent.workload;
    final solar = event == SimulationEvent.solarParticleEvent;
    final sleep = event == SimulationEvent.sleepLoss;
    _ref.read(crewMembersProvider.notifier).applySimulationProfile(
      astronautId: id,
      vitals: p.vitals.copyWith(
        source: 'simulation',
        missionDay: state.missionDay,
        heartRate: workload ? 118.0 : p.vitals.heartRate,
        respiratoryRate: workload ? 26.0 : p.vitals.respiratoryRate,
        spO2: workload ? 93.0 : p.vitals.spO2,
      ),
      sleep: p.sleep.copyWith(
        source: 'simulation',
        sleepHours: sleep ? 4.5 : p.sleep.sleepHours,
      ),
      radiation: p.radiation.copyWith(
        source: 'simulation',
        doseRateMicroSvPerHour: solar ? 180.0 : p.radiation.doseRateMicroSvPerHour,
        cumulativeDoseMilliSv: p.radiation.cumulativeDoseMilliSv + (solar ? 1.5 : 0),
        severity: solar ? RadiationSeverity.critical : p.radiation.severity,
      ),
      exercise: p.exercise.copyWith(
        source: 'simulation',
        targetReached: event == SimulationEvent.exerciseFailure ? false : p.exercise.targetReached,
      ),
      eventLabel: event.name,
    );
    final apolo = _ref.read(apoloStateNotifierProvider.notifier);
    if (solar) apolo.setSolarStorm(true);
    apolo.applySimulationProgress(
      missionDay: state.missionDay,
      extraDoseMsv: solar ? 1.5 : 0,
      sleepDeltaHours: sleep ? -3.0 : 0,
      waterDeltaMl: workload ? -900 : 0,
      targetAstronautId: id,
      biomarkerOverrides: switch (event) {
        SimulationEvent.solarParticleEvent => {'ohdg': 11.2, 'iso': 1.6},
        SimulationEvent.sleepLoss => {'cort': 92.0, 'mel': 7.0},
        SimulationEvent.exerciseFailure => {'ntx': 64.0, 'ctx': 530.0},
        SimulationEvent.workload => {'cort': 92.0, 'vol': 0.7},
      },
    );
    _log('${event.name} → $id');
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
