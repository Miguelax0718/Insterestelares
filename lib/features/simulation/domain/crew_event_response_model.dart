import 'dart:math' as math;

import 'mission_simulator_state.dart';

/// Individual, evolving crew responses to simulator events.
///
/// Every event runs four steps per crew member:
/// 1. exposure: how strongly the event reaches the person (module shielding,
///    whether they were on the affected shift, ...);
/// 2. susceptibility: a stable personal trait (drawn once per mission seed)
///    combined with the person's current variables (sleep debt, age,
///    deconditioning);
/// 3. whether a physiological condition appears at all (probability);
/// 4. which condition(s) and how strong, using variables the app already
///    measures.
///
/// The reference magnitudes are the fixed values of the team's original
/// simulator (HR 118, SpO2 93, 4.5 h sleep, 180 µSv/h, 8-OHdG 11.2, cortisol
/// 92, NTx 64 ...): a severity of 1.0 reproduces them. Sources and the values
/// that are team estimates are listed in `sources/medical/event_variability.md`.
///
/// Synthetic demo model: not a medical forecast.
abstract final class SimVar {
  static const heartRate = 'hr';
  static const systolicBP = 'sbp';
  static const diastolicBP = 'dbp';
  static const spO2 = 'spo2';
  static const respiratoryRate = 'rr';
  static const bodyTemp = 'temp';
  static const bloodGlucose = 'glucose';
  static const sleepHours = 'sleep';
  static const doseRate = 'doseRate';
  static const waterMl = 'water';

  /// APOLO urine biomarkers handled as absolute sample values.
  static const biomarkers = {'ohdg', 'iso', 'cort', 'mel', 'ntx', 'ctx', 'vol'};
}

enum AffectionKind {
  // Exposure itself (always applied to exposed members).
  sleepDebt,
  radiationExposure,
  missedExercise,
  physicalStrain,
  // Physiological conditions (probabilistic, individual).
  cardiovascularStress,
  stressHormonal,
  metabolic,
  oxidativeStress,
  thermalStrain,
  dehydration,
  boneResorption,
  cardiovascularDeconditioning,
}

extension AffectionKindInfo on AffectionKind {
  String get label => switch (this) {
        AffectionKind.sleepDebt => 'sleep debt',
        AffectionKind.radiationExposure => 'SPE dose',
        AffectionKind.missedExercise => 'missed countermeasure exercise',
        AffectionKind.physicalStrain => 'cardiorespiratory strain',
        AffectionKind.cardiovascularStress => 'cardiovascular stress (HR/BP)',
        AffectionKind.stressHormonal => 'stress response (cortisol/melatonin)',
        AffectionKind.metabolic => 'glucose dysregulation',
        AffectionKind.oxidativeStress => 'oxidative stress (8-OHdG/isoprostanes)',
        AffectionKind.thermalStrain => 'thermal strain',
        AffectionKind.dehydration => 'dehydration',
        AffectionKind.boneResorption => 'bone resorption (NTx/CTx)',
        AffectionKind.cardiovascularDeconditioning => 'cardiovascular deconditioning',
      };

  /// Countermeasure the crew is assumed to apply from the day after onset.
  String get countermeasure => switch (this) {
        AffectionKind.sleepDebt => 'recovery sleep and shifted schedule',
        AffectionKind.radiationExposure => 'storm shelter in the most shielded module',
        AffectionKind.missedExercise => 'ARED/CEVIS sessions resumed',
        AffectionKind.physicalStrain => 'rest and paced workload',
        AffectionKind.cardiovascularStress => 'rest, caffeine cut-off and BP rechecks',
        AffectionKind.stressHormonal => 'light-hygiene and relaxation protocol',
        AffectionKind.metabolic => 'regular meals and glucose rechecks',
        AffectionKind.oxidativeStress => 'antioxidant-rich diet and dose minimisation (ALARA)',
        AffectionKind.thermalStrain => 'cooling and reduced intensity',
        AffectionKind.dehydration => 'oral rehydration plan',
        AffectionKind.boneResorption => 'high-load ARED resistance and nutrition (Ca/vit D)',
        AffectionKind.cardiovascularDeconditioning => 'aerobic CEVIS/T2 sessions and fluid loading',
      };

  /// Days for the effect to halve once countermeasures start (team estimates
  /// anchored in the sources of event_variability.md).
  double get baseHalfLifeDays => switch (this) {
        AffectionKind.sleepDebt => 1.0,
        AffectionKind.radiationExposure => 0.5,
        AffectionKind.missedExercise => 0.5,
        AffectionKind.physicalStrain => 0.5,
        AffectionKind.cardiovascularStress => 1.0,
        AffectionKind.stressHormonal => 1.5,
        AffectionKind.metabolic => 2.0,
        AffectionKind.oxidativeStress => 3.0,
        AffectionKind.thermalStrain => 0.5,
        AffectionKind.dehydration => 0.7,
        AffectionKind.boneResorption => 7.0,
        AffectionKind.cardiovascularDeconditioning => 4.0,
      };

  /// Days from onset to peak (markers that build up after the trigger).
  int get peakDelayDays => switch (this) {
        AffectionKind.oxidativeStress => 1,
        AffectionKind.boneResorption => 2,
        _ => 0,
      };

  /// Fraction that does not reverse in flight (bone loss is only partly
  /// recovered while still in microgravity).
  double get residualFraction => this == AffectionKind.boneResorption ? 0.25 : 0.0;
}

/// Stable personal traits, ~1.0 on average (log-normal, σ≈0.3).
class CrewTraits {
  const CrewTraits({
    required this.sleepVulnerability,
    required this.cardioReactivity,
    required this.stressReactivity,
    required this.metabolicSensitivity,
    required this.oxidativeSensitivity,
    required this.boneTurnover,
    required this.thermoReactivity,
    required this.recoveryRate,
  });

  final double sleepVulnerability;
  final double cardioReactivity;
  final double stressReactivity;
  final double metabolicSensitivity;
  final double oxidativeSensitivity;
  final double boneTurnover;
  final double thermoReactivity;
  final double recoveryRate;

  factory CrewTraits.draw(int missionSeed, String astronautId) {
    double t(String name) => math.exp(0.3 * SeededRng.of([missionSeed, astronautId, 'trait', name]).gaussian());
    return CrewTraits(
      sleepVulnerability: t('sleep'),
      cardioReactivity: t('cardio'),
      stressReactivity: t('stress'),
      metabolicSensitivity: t('metabolic'),
      oxidativeSensitivity: t('oxidative'),
      boneTurnover: t('bone'),
      thermoReactivity: t('thermo'),
      recoveryRate: t('recovery'),
    );
  }
}

/// The current variables of a crew member the model reads.
class CrewSnapshot {
  const CrewSnapshot({
    required this.id,
    required this.age,
    required this.zone,
    required this.sleepHours,
    required this.cumulativeDoseMsv,
    required this.exerciseTargetReached,
    this.biomarkers = const {},
  });

  final String id;
  final int age;
  final String zone;
  final double sleepHours;
  final double cumulativeDoseMsv;
  final bool exerciseTargetReached;
  final Map<String, double> biomarkers;
}

/// One evolving condition of one crew member.
class AffectionEpisode {
  const AffectionEpisode({
    required this.astronautId,
    required this.event,
    required this.kind,
    required this.onsetDay,
    required this.severity,
    required this.peakDeltas,
    required this.halfLifeDays,
    required this.adherence,
  });

  final String astronautId;
  final SimulationEvent event;
  final AffectionKind kind;
  final int onsetDay;

  /// 1.0 ≈ the original simulator's fixed reference values.
  final double severity;

  /// Change of each variable at the peak (already scaled by severity).
  final Map<String, double> peakDeltas;
  final double halfLifeDays;

  /// Countermeasure adherence/efficacy for this person (0–1).
  final double adherence;

  bool get isExposure => kind.index <= AffectionKind.physicalStrain.index;

  /// Fraction of the peak present on [day] (0 before onset).
  double shapeOn(int day) {
    final t = day - onsetDay;
    if (t < 0) return 0;
    final delay = kind.peakDelayDays;
    if (t < delay) return (t + 1) / (delay + 1);
    final r = kind.residualFraction;
    return r + (1 - r) * math.pow(0.5, (t - delay) / halfLifeDays).toDouble();
  }

  double intensityOn(int day) => severity * shapeOn(day);

  /// Variable changes between [fromDay] and [toDay]; fromDay < onset means the
  /// whole onset effect.
  Map<String, double> deltaBetween(int fromDay, int toDay) {
    final k = shapeOn(toDay) - shapeOn(fromDay);
    return {for (final e in peakDeltas.entries) e.key: e.value * k};
  }

  /// Resolved once below 5 % of the reference effect (bone keeps a residual).
  bool resolvedOn(int day) =>
      day > onsetDay + kind.peakDelayDays && intensityOn(day) < 0.05;

  bool isPersistentOn(int day) =>
      kind.residualFraction > 0 && shapeOn(day) <= kind.residualFraction + 0.01;

  String severityLabelOn(int day) {
    final s = intensityOn(day);
    if (s >= 0.75) return 'severe';
    if (s >= 0.4) return 'moderate';
    return 'mild';
  }
}

/// Result of one event for one crew member.
class CrewEventResponse {
  const CrewEventResponse({
    required this.astronautId,
    required this.exposure,
    required this.susceptibility,
    required this.probabilityAffected,
    required this.episodes,
    required this.cumulativeDoseMsv,
    required this.note,
  });

  final String astronautId;
  final double exposure;
  final double susceptibility;
  final double probabilityAffected;

  /// Exposure episode (if any) followed by physiological conditions.
  final List<AffectionEpisode> episodes;

  /// Permanent dose added by the event.
  final double cumulativeDoseMsv;
  final String note;

  Iterable<AffectionEpisode> get conditions => episodes.where((e) => !e.isExposure);
  bool get affected => conditions.isNotEmpty;
}

abstract final class CrewEventResponseModel {
  /// Default seed so the demo is reproducible.
  static const int defaultSeed = 20261115;

  /// Relative SPE dose by module shielding (team estimate; OCHMO-TB-020 and
  /// SRAG describe higher dose in thinly shielded areas and the crew
  /// sheltering in the most shielded modules).
  static const double maxShieldingFactor = 1.35;

  static double shieldingFactor(String zone) {
    final z = zone.toLowerCase();
    if (z.contains('cupola') || z.contains('cúpula')) return maxShieldingFactor;
    if (z.contains('airlock') || z.contains('esclusa') || z.contains('eva')) return 1.25;
    if (z.contains('columbus') || z.contains('kibo') || z.contains('lab')) return 1.0;
    if (z.contains('destiny') || z.contains('command')) return 0.9;
    if (z.contains('harmony') || z.contains('medical') || z.contains('médica')) return 0.8;
    return 1.0;
  }

  static List<CrewEventResponse> evaluate({
    required SimulationEvent event,
    required List<CrewSnapshot> exposed,
    required int missionDay,
    required bool wholeCrew,
    int seed = defaultSeed,
  }) => [
        for (final c in exposed)
          _evaluateOne(event, c, missionDay, wholeCrew, seed),
      ];

  static CrewEventResponse _evaluateOne(
    SimulationEvent event,
    CrewSnapshot c,
    int day,
    bool wholeCrew,
    int seed,
  ) {
    final rng = SeededRng.of([seed, c.id, event.name, day]);
    final traits = CrewTraits.draw(seed, c.id);
    final ageFactor = 1 + (c.age - 35) / 40;
    final priorSleepDebt = math.max(0.0, 7.0 - c.sleepHours);

    // 1. Exposure.
    final double exposure = switch (event) {
      SimulationEvent.solarParticleEvent => shieldingFactor(c.zone) * rng.range(0.9, 1.1),
      _ when !wholeCrew => rng.range(0.85, 1.15),
      // A crew-wide disturbance does not reach everyone equally.
      SimulationEvent.sleepLoss => rng.range(0.2, 1.2),
      SimulationEvent.workload => rng.range(0.4, 1.15),
      SimulationEvent.exerciseFailure => rng.range(0.5, 1.1),
    };

    // 2. Susceptibility from traits and current variables.
    final double susceptibility = switch (event) {
      SimulationEvent.sleepLoss => traits.sleepVulnerability * (1 + 0.15 * priorSleepDebt),
      SimulationEvent.solarParticleEvent =>
        traits.oxidativeSensitivity * (1 + 0.2 * priorSleepDebt / 3),
      SimulationEvent.workload => traits.cardioReactivity * ageFactor *
          (c.exerciseTargetReached ? 1.0 : 1.25) * (c.sleepHours < 6 ? 1.2 : 1.0),
      SimulationEvent.exerciseFailure => traits.boneTurnover * ageFactor,
    };

    final load = exposure * susceptibility;
    final pAffected = 1 - math.exp(-1.1 * load);
    double severity() => (load * rng.range(0.7, 1.2)).clamp(0.1, 1.2);
    double adherence() => rng.range(0.7, 1.0);

    AffectionEpisode episode(AffectionKind kind, double sev, Map<String, double> ref) {
      final a = adherence();
      return AffectionEpisode(
        astronautId: c.id,
        event: event,
        kind: kind,
        onsetDay: day,
        severity: sev,
        peakDeltas: {for (final e in ref.entries) e.key: e.value * sev},
        halfLifeDays: kind.baseHalfLifeDays / (traits.recoveryRate * a),
        adherence: a,
      );
    }

    double toRef(String biomarker, double ref) =>
        math.max(0.0, ref - (c.biomarkers[biomarker] ?? ref * 0.5));

    // Exposure effect (always applied) — reference values of the original model.
    final episodes = <AffectionEpisode>[];
    var cumulativeDose = 0.0;
    switch (event) {
      case SimulationEvent.sleepLoss:
        episodes.add(episode(AffectionKind.sleepDebt, exposure, {SimVar.sleepHours: -3.0}));
      case SimulationEvent.solarParticleEvent:
        // The original 180 µSv/h (+140) and +1.5 mSv are the reading in the
        // least-shielded module; sheltered modules receive proportionally less.
        final relative = exposure / maxShieldingFactor;
        episodes.add(episode(AffectionKind.radiationExposure, exposure, {SimVar.doseRate: 140.0 / maxShieldingFactor}));
        cumulativeDose = 1.5 * relative;
      case SimulationEvent.workload:
        episodes.add(episode(AffectionKind.physicalStrain, (exposure * susceptibility).clamp(0.3, 1.2),
            {SimVar.heartRate: 48.0, SimVar.respiratoryRate: 11.0, SimVar.spO2: -6.0, SimVar.waterMl: -900.0}));
      case SimulationEvent.exerciseFailure:
        episodes.add(episode(AffectionKind.missedExercise, 1.0, const {}));
    }

    // 3. Does a physiological condition appear?
    final affected = rng.next() < pAffected;
    if (!affected) {
      return CrewEventResponse(
        astronautId: c.id,
        exposure: exposure,
        susceptibility: susceptibility,
        probabilityAffected: pAffected,
        episodes: episodes,
        cumulativeDoseMsv: cumulativeDose,
        note: 'no additional condition (resilient)',
      );
    }

    // 4. Which conditions, weighted by the person's profile.
    final candidates = <(AffectionKind, double, Map<String, double>)>[
      ...switch (event) {
        SimulationEvent.sleepLoss => [
            (AffectionKind.cardiovascularStress, traits.cardioReactivity * ageFactor,
                {SimVar.heartRate: 6.0, SimVar.systolicBP: 8.0, SimVar.diastolicBP: 5.0}),
            (AffectionKind.stressHormonal, traits.stressReactivity,
                {'cort': toRef('cort', 92.0), 'mel': -math.max(0.0, (c.biomarkers['mel'] ?? 20) - 7.0)}),
            (AffectionKind.metabolic, traits.metabolicSensitivity,
                {SimVar.bloodGlucose: 14.0}),
          ],
        SimulationEvent.solarParticleEvent => [
            (AffectionKind.oxidativeStress, 1.0,
                {'ohdg': toRef('ohdg', 11.2), 'iso': toRef('iso', 1.6)}),
          ],
        SimulationEvent.workload => [
            (AffectionKind.thermalStrain, traits.thermoReactivity, {SimVar.bodyTemp: 0.9}),
            (AffectionKind.dehydration, 1.0,
                {'vol': -math.max(0.0, (c.biomarkers['vol'] ?? 2.0) - 0.7), SimVar.waterMl: -400.0}),
            (AffectionKind.stressHormonal, traits.stressReactivity, {'cort': toRef('cort', 92.0)}),
          ],
        SimulationEvent.exerciseFailure => [
            (AffectionKind.boneResorption, traits.boneTurnover * ageFactor,
                {'ntx': toRef('ntx', 64.0), 'ctx': toRef('ctx', 530.0)}),
            (AffectionKind.cardiovascularDeconditioning, traits.cardioReactivity,
                {SimVar.heartRate: 6.0, SimVar.systolicBP: -8.0}),
          ],
      },
    ];
    final first = _pickWeighted(candidates, rng);
    final firstSeverity = severity();
    episodes.add(episode(first.$1, firstSeverity, first.$3));
    // A strong response can involve a second system.
    if (candidates.length > 1 && firstSeverity > 0.8 && rng.next() < 0.6) {
      final rest = candidates.where((o) => o.$1 != first.$1).toList();
      final second = _pickWeighted(rest, rng);
      episodes.add(episode(second.$1, severity() * 0.7, second.$3));
    }
    return CrewEventResponse(
      astronautId: c.id,
      exposure: exposure,
      susceptibility: susceptibility,
      probabilityAffected: pAffected,
      episodes: episodes,
      cumulativeDoseMsv: cumulativeDose,
      note: episodes.where((e) => !e.isExposure).map((e) => e.kind.label).join(' + '),
    );
  }

  static (AffectionKind, double, Map<String, double>) _pickWeighted(
    List<(AffectionKind, double, Map<String, double>)> options,
    SeededRng rng,
  ) {
    final total = options.fold<double>(0, (s, o) => s + o.$2);
    var x = rng.next() * total;
    for (final o in options) {
      x -= o.$2;
      if (x <= 0) return o;
    }
    return options.last;
  }
}

/// Small deterministic PRNG (mulberry32) seeded by a stable FNV-1a hash, so
/// results are identical on web, desktop and in tests.
class SeededRng {
  SeededRng(int seed) : _state = seed & 0xFFFFFFFF;

  factory SeededRng.of(List<Object> parts) {
    var h = 0x811C9DC5;
    for (final unit in parts.join('|').codeUnits) {
      h ^= unit;
      h = _imul(h, 0x01000193);
    }
    return SeededRng(h);
  }

  int _state;

  double next() {
    _state = (_state + 0x6D2B79F5) & 0xFFFFFFFF;
    var t = _state;
    t = _imul(t ^ (t >>> 15), t | 1);
    t ^= (t + _imul(t ^ (t >>> 7), t | 61)) & 0xFFFFFFFF;
    return ((t ^ (t >>> 14)) & 0xFFFFFFFF) / 4294967296.0;
  }

  double range(double min, double max) => min + (max - min) * next();

  double gaussian() {
    final u = math.max(next(), 1e-12);
    final v = next();
    return math.sqrt(-2 * math.log(u)) * math.cos(2 * math.pi * v);
  }

  static int _imul(int a, int b) {
    final aHi = (a >>> 16) & 0xFFFF, aLo = a & 0xFFFF;
    final bHi = (b >>> 16) & 0xFFFF, bLo = b & 0xFFFF;
    return ((aLo * bLo) + ((((aHi * bLo) + (aLo * bHi)) << 16) & 0xFFFFFFFF)) & 0xFFFFFFFF;
  }
}
