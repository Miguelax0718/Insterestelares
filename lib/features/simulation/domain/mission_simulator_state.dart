enum MissionType { orbital, lunar, transit, surface }
enum SimulationEvent { sleepLoss, solarParticleEvent, exerciseFailure, workload }

class MissionSimulatorState {
  const MissionSimulatorState({
    this.missionDay = 1,
    this.missionType = MissionType.lunar,
    this.isRunning = false,
    this.log = const [],
  });

  final int missionDay;
  final MissionType missionType;
  final bool isRunning;
  final List<String> log;

  MissionSimulatorState copyWith({
    int? missionDay,
    MissionType? missionType,
    bool? isRunning,
    List<String>? log,
  }) => MissionSimulatorState(
    missionDay: missionDay ?? this.missionDay,
    missionType: missionType ?? this.missionType,
    isRunning: isRunning ?? this.isRunning,
    log: List.unmodifiable(log ?? this.log),
  );
}
