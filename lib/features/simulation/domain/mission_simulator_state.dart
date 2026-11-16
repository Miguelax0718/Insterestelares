import 'dart:math' as math;

/// Cambio diario de la tripulación en una misión SIN incidentes.
///
/// Sustituye a la deriva lineal anterior (FC +1,6 lpm/día, sueño −0,12 h/día
/// sin límite), que llevaba a toda la tripulación a estado crítico en un mes.
/// Los valores siguen lo publicado en astronautas y se estabilizan:
///
/// - Frecuencia cardiaca en reposo: no cambia en vuelo (Norsk 2015).
/// - Presión sistólica: baja 8 mmHg y se estabiliza en ~2 semanas
///   (Norsk et al. 2015, J Physiol 593:573).
/// - Sueño: baja hasta ~6,1 h por noche en órbita (Barger et al. 2014,
///   Lancet Neurol 13:904). La diferencia entre tipos de misión es una
///   estimación del equipo.
///
/// Los fallos graves salen de los eventos ([SimulationEvent]), no del paso
/// de los días. Fuentes: `sources/links.md`.
class MissionDrift {
  const MissionDrift._();

  /// Días que tarda la presión en estabilizarse.
  static const int bpAdaptationDays = 14;

  /// Caída total de la presión sistólica en vuelo (mmHg).
  static const double bpTotalDrop = 8;

  /// Constante de tiempo (días) con la que el sueño llega a su nivel de vuelo.
  static const double sleepTimeConstantDays = 20;

  /// Horas de sueño que se pierden en total respecto a la línea base nominal
  /// (~7,5 h). Órbita: hasta ~6,1–6,2 h, como en la ISS.
  static double sleepTotalLoss(MissionType type) => switch (type) {
        MissionType.orbital => 1.3,
        MissionType.lunar => 1.4,
        MissionType.surface => 1.5,
        MissionType.transit => 1.6,
      };

  /// Cambio de la presión sistólica al pasar al día [missionDay] (día 1 =
  /// línea base).
  static double bpDelta(int missionDay) =>
      missionDay - 1 <= bpAdaptationDays ? -bpTotalDrop / bpAdaptationDays : 0;

  /// Cambio de las horas de sueño al pasar al día [missionDay].
  static double sleepDelta(MissionType type, int missionDay) {
    double lost(int day) =>
        sleepTotalLoss(type) *
        (1 - math.exp(-(day - 1) / sleepTimeConstantDays));
    return lost(missionDay - 1) - lost(missionDay);
  }
}

/// Episodio leve y aislado de un tripulante: dura pocos días y se resuelve
/// solo. Deja al astronauta en "precaución", nunca en estado crítico.
enum MissionEpisode {
  /// Mareo espacial al llegar a microgravedad. Afecta a ~60–80 % de los
  /// astronautas en los primeros 2–3 días (NASA, Space Motion Sickness).
  spaceMotionSickness('Space motion sickness', 3,
      hr: 8, missesExercise: true),

  /// Una noche de mal sueño (ruido, turno desplazado, carga de trabajo).
  poorSleepNight('Poor sleep night', 1, sleep: -2.0),

  /// Infección leve (resfriado, congestión): febrícula y pulso algo alto.
  minorInfection('Minor infection', 3,
      hr: 12, temp: 1.0, respiratoryRate: 2, missesExercise: true),

  /// Dolor de espalda por el alargamiento de la columna en microgravedad.
  backPain('Back pain', 2, missesExercise: true),

  /// Día de trabajo intenso (mantenimiento, preparación de una EVA).
  heavyWorkday('Heavy workday', 1, hr: 14, respiratoryRate: 3, sleep: -0.8);

  const MissionEpisode(
    this.label,
    this.durationDays, {
    this.hr = 0,
    this.temp = 0,
    this.respiratoryRate = 0,
    this.sleep = 0,
    this.missesExercise = false,
  });

  final String label;
  final int durationDays;

  /// Cambios sobre el estado del día mientras dura el episodio.
  final double hr;
  final double temp;
  final double respiratoryRate;
  final double sleep;
  final bool missesExercise;
}

/// Calendario determinista de episodios: depende solo del astronauta y del
/// día, así que avanzar 5 días de golpe da lo mismo que avanzar de uno en uno.
/// La frecuencia (un episodio cada ~5 semanas por persona) es una estimación
/// del equipo para la demo.
class MissionEpisodes {
  const MissionEpisodes._();

  /// Probabilidad diaria de que empiece un episodio esporádico.
  static const double dailyStartChance = 0.028;

  static const _sporadic = [
    MissionEpisode.poorSleepNight,
    MissionEpisode.heavyWorkday,
    MissionEpisode.backPain,
    MissionEpisode.minorInfection,
    MissionEpisode.poorSleepNight,
    MissionEpisode.heavyWorkday,
  ];

  static int _crewNumber(String astronautId) =>
      int.tryParse(astronautId.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;

  /// Episodio que EMPIEZA ese día, si hay alguno.
  static MissionEpisode? startingOn(String astronautId, int missionDay) {
    final n = _crewNumber(astronautId);
    // Mareo espacial: días 2–4, tres de cada cinco tripulantes.
    if (missionDay == 2) {
      return n % 5 == 1 || n % 5 == 3 || n % 5 == 4
          ? MissionEpisode.spaceMotionSickness
          : null;
    }
    if (missionDay < 8) return null;
    final rng = math.Random(n * 100003 + missionDay * 7919);
    if (rng.nextDouble() >= dailyStartChance) return null;
    return _sporadic[rng.nextInt(_sporadic.length)];
  }

  /// Episodio activo ese día (el que empezó más recientemente y aún dura).
  static MissionEpisode? activeOn(String astronautId, int missionDay) {
    for (var back = 0; back < 3; back++) {
      final episode = startingOn(astronautId, missionDay - back);
      if (episode != null && back < episode.durationDays) return episode;
    }
    return null;
  }
}

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
