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
