import 'crew_event_response_model.dart';

enum MissionType { orbital, lunar, transit, surface }
enum SimulationEvent { sleepLoss, solarParticleEvent, exerciseFailure, workload }

class MissionSimulatorState {
  const MissionSimulatorState({
    this.missionDay = 1,
    this.missionType = MissionType.lunar,
    this.isRunning = false,
    this.log = const [],
    this.episodes = const [],
    this.wholeCrew = false,
    this.seed = CrewEventResponseModel.defaultSeed,
  });

  final int missionDay;
  final MissionType missionType;
  final bool isRunning;
  final List<String> log;

  /// Active, evolving conditions caused by events.
  final List<AffectionEpisode> episodes;

  /// Apply sleep loss / workload / exercise failure to the whole crew instead
  /// of the selected astronaut (solar particle events always reach everyone).
  final bool wholeCrew;

  /// Seed of the individual-response model; fixed for a reproducible demo.
  final int seed;

  MissionSimulatorState copyWith({
    int? missionDay,
    MissionType? missionType,
    bool? isRunning,
    List<String>? log,
    List<AffectionEpisode>? episodes,
    bool? wholeCrew,
    int? seed,
  }) => MissionSimulatorState(
    missionDay: missionDay ?? this.missionDay,
    missionType: missionType ?? this.missionType,
    isRunning: isRunning ?? this.isRunning,
    log: List.unmodifiable(log ?? this.log),
    episodes: List.unmodifiable(episodes ?? this.episodes),
    wholeCrew: wholeCrew ?? this.wholeCrew,
    seed: seed ?? this.seed,
  );
}
