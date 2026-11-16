import 'dart:async';
import 'dart:math' as math;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../02_radiation/models/radiation_dose.dart';
import '../../../02_radiation/providers/biomarker_providers.dart';
import '../../../apolo/providers/apolo_providers.dart';
import '../../../crew/presentation/providers/crew_provider.dart';
import '../../domain/crew_event_response_model.dart';
import '../../domain/mission_simulator_state.dart';

export '../../domain/crew_event_response_model.dart';
export '../../domain/mission_simulator_state.dart';

final simulationResetCounterProvider = StateProvider<int>((ref) => 0);

final missionSimulatorProvider =
    StateNotifierProvider<MissionSimulatorNotifier, MissionSimulatorState>(
      (ref) => MissionSimulatorNotifier(ref),
    );

/// Deterministic synthetic scenarios for exercising the existing clinical rules.
/// Events reach each crew member differently (seeded individual-response model).
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
    state = MissionSimulatorState(
      missionType: state.missionType,
      wholeCrew: state.wholeCrew,
      seed: state.seed,
    );
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
      _evolveEpisodes(day);
    }
  }

  void setWholeCrew(bool value) {
    if (value == state.wholeCrew) return;
    state = state.copyWith(wholeCrew: value);
    _log(value ? 'Event target: whole crew' : 'Event target: selected astronaut');
  }

  /// Applies an event through the individual-response model: each exposed crew
  /// member gets their own exposure, susceptibility and conditions, which then
  /// evolve day by day as countermeasures are applied.
  void triggerEvent(SimulationEvent event, {String? astronautId, bool? wholeCrew}) {
    final crew = _ref.read(crewMembersProvider);
    final crewWide = event == SimulationEvent.solarParticleEvent ||
        (astronautId == null && (wholeCrew ?? state.wholeCrew));
    final String id = astronautId ?? _ref.read(selectedAstronautIdProvider);
    if (!crewWide && crew.every((p) => p.id != id)) {
      throw ArgumentError.value(id, 'astronautId', 'Unknown astronaut');
    }
    final exposed = crewWide ? crew : crew.where((p) => p.id == id).toList();
    final apoloStates = _ref.read(apoloStateNotifierProvider);
    final day = state.missionDay;
    final responses = CrewEventResponseModel.evaluate(
      event: event,
      wholeCrew: crewWide,
      missionDay: day,
      seed: state.seed,
      exposed: [
        for (final p in exposed)
          CrewSnapshot(
            id: p.id,
            age: p.age,
            zone: p.currentZone,
            sleepHours: p.sleep.sleepHours,
            cumulativeDoseMsv: p.radiation.cumulativeDoseMilliSv,
            exerciseTargetReached: p.exercise.targetReached,
            biomarkers: apoloStates[p.id]?.samples.lastOrNull?.values ?? const {},
          ),
      ],
    );

    final apolo = _ref.read(apoloStateNotifierProvider.notifier);
    if (event == SimulationEvent.solarParticleEvent) apolo.setSolarStorm(true);
    _log('${event.name} → ${crewWide ? 'crew' : id}');
    for (final r in responses) {
      final deltas = <String, double>{};
      for (final e in r.episodes) {
        _addAll(deltas, e.deltaBetween(day - 1, day));
      }
      _applyDeltas(
        r.astronautId,
        deltas,
        label: event.name,
        extraDoseMsv: r.cumulativeDoseMsv,
        exerciseMissed: event == SimulationEvent.exerciseFailure ? true : null,
      );
      final pct = (r.probabilityAffected * 100).round();
      final outcome = r.affected
          ? r.conditions.map((e) => '${e.kind.label} [${e.severityLabelOn(day)}]').join(' + ')
          : r.note;
      final exposureText = r.episodes.where((e) => e.isExposure).map(_describeExposure).join(', ');
      _log('${r.astronautId} exposure ×${r.exposure.toStringAsFixed(2)} ($exposureText), '
          'susceptibility ×${r.susceptibility.toStringAsFixed(2)}, $pct% risk → $outcome');
    }
    state = state.copyWith(episodes: [
      ...state.episodes,
      for (final r in responses) ...r.episodes,
    ]);
  }

  static String _describeExposure(AffectionEpisode e) {
    final d = e.peakDeltas;
    return switch (e.kind) {
      AffectionKind.sleepDebt => 'sleep ${d[SimVar.sleepHours]!.toStringAsFixed(1)} h',
      AffectionKind.radiationExposure => 'dose rate +${d[SimVar.doseRate]!.round()} µSv/h',
      AffectionKind.physicalStrain => 'HR +${d[SimVar.heartRate]!.round()} bpm',
      AffectionKind.missedExercise => 'session missed',
      _ => e.kind.label,
    };
  }

  /// Evolves active conditions from the previous day to [day].
  void _evolveEpisodes(int day) {
    if (state.episodes.isEmpty) return;
    final byAstronaut = <String, Map<String, double>>{};
    final remaining = <AffectionEpisode>[];
    final exposureMeasures = <AffectionKind, List<String>>{};
    for (final e in state.episodes) {
      _addAll(byAstronaut.putIfAbsent(e.astronautId, () => {}), e.deltaBetween(day - 1, day));
      if (day == e.onsetDay + 1) {
        if (e.isExposure) {
          exposureMeasures.putIfAbsent(e.kind, () => []).add(e.astronautId);
        } else {
          _log('${e.astronautId} countermeasure for ${e.kind.label}: ${e.kind.countermeasure} '
              '(adherence ${(e.adherence * 100).round()}%)');
        }
      }
      if (e.resolvedOn(day)) {
        if (!e.isExposure) _log('${e.astronautId} recovered from ${e.kind.label}');
      } else {
        if (e.isPersistentOn(day) && !e.isPersistentOn(day - 1)) {
          _log('${e.astronautId} ${e.kind.label} stabilised at a residual level');
        }
        remaining.add(e);
      }
    }
    for (final entry in exposureMeasures.entries) {
      _log('Countermeasure (${entry.value.join(', ')}): ${entry.key.countermeasure}');
    }
    for (final entry in byAstronaut.entries) {
      _applyDeltas(entry.key, entry.value, label: 'recovery day $day');
    }
    final stormWasActive = state.episodes.any((e) => e.kind == AffectionKind.radiationExposure);
    state = state.copyWith(episodes: remaining);
    if (stormWasActive && remaining.every((e) => e.kind != AffectionKind.radiationExposure)) {
      _ref.read(apoloStateNotifierProvider.notifier).setSolarStorm(false);
      _log('Solar particle event over: crew left the storm shelter');
    }
  }

  static void _addAll(Map<String, double> into, Map<String, double> from) {
    for (final e in from.entries) {
      into[e.key] = (into[e.key] ?? 0) + e.value;
    }
  }

  void _applyDeltas(
    String astronautId,
    Map<String, double> d, {
    required String label,
    double extraDoseMsv = 0,
    bool? exerciseMissed,
  }) {
    final matches = _ref.read(crewMembersProvider).where((p) => p.id == astronautId);
    if (matches.isEmpty) return;
    final p = matches.first;
    double v(String k) => d[k] ?? 0;
    final doseRate = (p.radiation.doseRateMicroSvPerHour + v(SimVar.doseRate)).clamp(0.0, 1000.0);
    _ref.read(crewMembersProvider.notifier).applySimulationProfile(
      astronautId: astronautId,
      vitals: p.vitals.copyWith(
        source: 'simulation',
        missionDay: state.missionDay,
        heartRate: (p.vitals.heartRate + v(SimVar.heartRate)).clamp(40.0, 180.0),
        systolicBP: (p.vitals.systolicBP + v(SimVar.systolicBP)).clamp(80.0, 180.0),
        diastolicBP: (p.vitals.diastolicBP + v(SimVar.diastolicBP)).clamp(50.0, 120.0),
        spO2: (p.vitals.spO2 + v(SimVar.spO2)).clamp(85.0, 100.0),
        respiratoryRate: (p.vitals.respiratoryRate + v(SimVar.respiratoryRate)).clamp(10.0, 32.0),
        bodyTemp: (p.vitals.bodyTemp + v(SimVar.bodyTemp)).clamp(35.5, 40.0),
        bloodGlucose: (p.vitals.bloodGlucose + v(SimVar.bloodGlucose)).clamp(60.0, 250.0),
      ),
      sleep: p.sleep.copyWith(
        source: 'simulation',
        sleepHours: (p.sleep.sleepHours + v(SimVar.sleepHours)).clamp(3.0, 9.0),
      ),
      radiation: p.radiation.copyWith(
        source: 'simulation',
        doseRateMicroSvPerHour: doseRate,
        cumulativeDoseMilliSv: p.radiation.cumulativeDoseMilliSv + extraDoseMsv,
        severity: doseRate > 160
            ? RadiationSeverity.critical
            : doseRate > 100
                ? RadiationSeverity.warning
                : RadiationSeverity.normal,
      ),
      exercise: p.exercise.copyWith(
        source: 'simulation',
        targetReached: exerciseMissed == true ? false : p.exercise.targetReached,
      ),
      eventLabel: label,
    );
    final last = _ref.read(apoloStateNotifierProvider)[astronautId]?.samples.lastOrNull?.values ?? const {};
    final markers = {
      for (final k in SimVar.biomarkers)
        if (v(k) != 0) k: double.parse(math.max(0.0, (last[k] ?? 0) + v(k)).toStringAsFixed(2)),
    };
    _ref.read(apoloStateNotifierProvider.notifier).applySimulationProgress(
      missionDay: state.missionDay,
      extraDoseMsv: extraDoseMsv,
      sleepDeltaHours: v(SimVar.sleepHours),
      waterDeltaMl: v(SimVar.waterMl).round(),
      targetAstronautId: astronautId,
      biomarkerOverrides: markers.isEmpty ? null : markers,
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
