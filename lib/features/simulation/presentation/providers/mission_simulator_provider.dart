import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../02_radiation/models/radiation_dose.dart';
import '../../../02_radiation/providers/biomarker_providers.dart';
import '../../../apolo/providers/apolo_providers.dart';
import '../../../crew/presentation/providers/crew_provider.dart';
import '../../domain/mission_simulator_state.dart';

export '../../domain/mission_simulator_state.dart';

final simulationResetCounterProvider = StateProvider<int>((ref) => 0);

final missionSimulatorProvider =
    StateNotifierProvider<MissionSimulatorNotifier, MissionSimulatorState>(
      (ref) => MissionSimulatorNotifier(ref),
    );

/// Deterministic synthetic scenarios for exercising the existing clinical rules.
class MissionSimulatorNotifier extends StateNotifier<MissionSimulatorState> {
  MissionSimulatorNotifier(this._ref) : super(const MissionSimulatorState());
  final Ref _ref;
  Timer? _timer;

  void _log(String message) {
    state = state.copyWith(log: [
      'Day ${state.missionDay}: $message',
      ...state.log,
    ].take(50).toList());
  }

  void initializeNominal() => resetNominal();

  void resetNominal() {
    setRunning(false);
    _ref.read(crewMembersProvider.notifier).resetAllNominal();
    _ref.read(apoloStateNotifierProvider.notifier).resetAllNominal();
    _ref.read(selectedMissionDayProvider.notifier).state = 1;
    state = MissionSimulatorState(missionType: state.missionType);
    _log('Nominal baseline restored');
    _ref.read(simulationResetCounterProvider.notifier).state++;
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
      _ref.read(crewMembersProvider.notifier).applyProgressiveDay(
        missionDay: day,
        doseRateDeltaMicroSv: 4.0 * factor,
        cumulativeDoseDeltaMsv: 0.15 * factor,
        sleepDeltaHours: -0.12 * factor,
        hrDelta: 1.6 * factor,
        bpDelta: 0.7 * factor,
        exerciseTargetMet: day < 12,
      );
      _ref.read(apoloStateNotifierProvider.notifier).applySimulationProgress(
        missionDay: day,
        extraDoseMsv: 0.15 * factor,
        sleepDeltaHours: -0.12 * factor,
        waterDeltaMl: -(60 * factor).round(),
      );
      _ref.read(selectedMissionDayProvider.notifier).state = day;
      state = state.copyWith(missionDay: day);
      _log('Progressive ${state.missionType.name} drift');
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
