import '../models/biomarkers/biomarker_baseline.dart';
import '../models/biomarkers/blood_sample.dart';
import '../models/biomarkers/urine_sample.dart';
import 'biomarker_simulator.dart';
import 'example_mission.dart';

/// De dónde saca la app las muestras de orina y sangre de cada astronauta.
///
/// La pantalla y los providers solo conocen esta interfaz. Hoy la implementa
/// [MockBiomarkerRepository] (datos simulados); el día que haya datos reales
/// (Hive, sensores, laboratorio a bordo) se crea otra clase con los mismos
/// métodos y se cambia en `biomarkerRepositoryProvider`, sin tocar la UI.
abstract class BiomarkerRepository {
  /// Fecha del lanzamiento (día 0 de la misión).
  DateTime get launch;

  /// Duración de la misión en días.
  int get missionDays;

  List<String> crewIds();

  BiomarkerBaseline baselineOf(String astronautId);

  /// Muestras de orina del astronauta, de la más antigua a la más reciente.
  List<UrineSample> urineSamples(String astronautId);

  /// Muestras de sangre del astronauta, de la más antigua a la más reciente.
  List<BloodSample> bloodSamples(String astronautId);

  /// Momento de la tormenta solar (SPE) más reciente hasta [date], o null.
  DateTime? lastSolarEventAt(DateTime date);

  /// Dosis (Gy) que recibió el astronauta en la tormenta solar más reciente
  /// hasta [date]; 0 si no hubo tormenta.
  double lastSolarEventDoseGy(String astronautId, DateTime date);

  /// Fecha de un día de misión (día 1 = primer día en vuelo).
  DateTime dateOfMissionDay(int day) => launch.add(Duration(days: day));
}

/// Repositorio MOCK: genera en memoria los mismos datos que
/// `DB/samples/biomarkers/` (misma semilla), sin leer archivos, así funciona
/// también en Chrome y sin conexión.
class MockBiomarkerRepository extends BiomarkerRepository {
  MockBiomarkerRepository({
    SimulationScenario scenario = SimulationScenario.realistic,
    List<String> crewIds = BiomarkerSimulator.defaultCrew,
    BiomarkerSimulator? simulator,
  }) : _sim = (simulator ?? BiomarkerSimulator()).simulate(
          crewIds: crewIds,
          speDay: exampleSpeDay,
          speDoseMsv: exampleSpeDoseMsv,
          sheltered: exampleSheltered,
          scenario: scenario,
        );

  final BiomarkerSimulation _sim;

  SimulationScenario get scenario => _sim.scenario;

  @override
  DateTime get launch => _sim.launch;

  @override
  int get missionDays => _sim.missionDays;

  @override
  List<String> crewIds() => [for (final b in _sim.baselines) b.astronautId];

  @override
  BiomarkerBaseline baselineOf(String astronautId) =>
      _sim.baselines.firstWhere(
        (b) => b.astronautId == astronautId,
        orElse: () => throw ArgumentError('Astronauta desconocido: $astronautId'),
      );

  @override
  List<UrineSample> urineSamples(String astronautId) => _sorted([
        for (final u in _sim.urine)
          if (u.sample.astronautId == astronautId) u.sample,
      ], (s) => s.takenAt);

  @override
  List<BloodSample> bloodSamples(String astronautId) => _sorted([
        for (final b in _sim.blood)
          if (b.sample.astronautId == astronautId) b.sample,
      ], (s) => s.takenAt);

  @override
  DateTime? lastSolarEventAt(DateTime date) {
    final day = _sim.speDay;
    if (day == null) return null;
    // La tormenta empieza a mediodía del día del SPE.
    final at = launch.add(Duration(days: day, hours: 12));
    return at.isAfter(date) ? null : at;
  }

  @override
  double lastSolarEventDoseGy(String astronautId, DateTime date) {
    if (lastSolarEventAt(date) == null) return 0;
    if (scenario == SimulationScenario.extremeHypothetical) {
      return exampleSheltered.contains(astronautId)
          ? BiomarkerSimulator.extremeShelteredSpeDoseGy
          : BiomarkerSimulator.extremeSpeDoseGy;
    }
    return (exampleSpeDoseMsv[astronautId] ?? 0) / 1000;
  }

  static List<T> _sorted<T>(List<T> xs, DateTime Function(T) key) =>
      xs..sort((a, b) => key(a).compareTo(key(b)));
}
