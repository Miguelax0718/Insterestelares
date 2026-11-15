import '../models/biomarkers/biomarker_baseline.dart';
import '../models/biomarkers/blood_sample.dart';
import '../models/biomarkers/urine_sample.dart';
import 'biomarker_repository.dart';
import 'biomarker_simulator.dart';
import 'radiation_sample_repository.dart';

/// Adapts dosimetry to the existing biological simulator without changing it.
/// Missing personal doses stay unavailable in dosimetry. For those crew IDs the
/// biological demo has no dose-dependent SPE input; it is not a zero-dose reading.
class DoseLinkedBiomarkerRepository extends BiomarkerRepository {
  DoseLinkedBiomarkerRepository._(this._simulation, this.eventDoseMsv);

  factory DoseLinkedBiomarkerRepository({
    required RadiationMissionData mission,
    required List<String> crewIds,
    required SimulationScenario scenario,
  }) {
    final days = mission.dosimetry.map((r) => r.missionDay);
    if (days.isEmpty) throw StateError('No mission dosimetry is available.');
    final missionDays = days.reduce((a, b) => a > b ? a : b);
    final eventDays = mission.spaceWeather
        .where((r) => r.eventSpe)
        .map((r) => r.missionDay)
        .toSet();
    if (eventDays.length > 1) {
      throw UnsupportedError(
        'The biological simulator currently supports one SPE per mission.',
      );
    }
    final speDay = eventDays.isEmpty ? null : eventDays.single;
    final eventDose = <String, double>{};
    final sheltered = <String>{};
    for (final record in mission.dosimetry) {
      if (record.missionDay != speDay) continue;
      if (eventDose.containsKey(record.astronautId)) {
        throw StateError('Duplicate SPE dose for ${record.astronautId}.');
      }
      eventDose[record.astronautId] = record.speEventDoseMsv;
      if (record.module == 'storm_shelter') sheltered.add(record.astronautId);
    }
    final simulation = BiomarkerSimulator().simulate(
      crewIds: crewIds,
      missionDays: missionDays,
      speDay: speDay,
      speDoseMsv: eventDose,
      sheltered: sheltered,
      scenario: scenario,
    );
    return DoseLinkedBiomarkerRepository._(
      simulation,
      Map.unmodifiable(eventDose),
    );
  }

  final BiomarkerSimulation _simulation;
  final Map<String, double> eventDoseMsv;

  @override
  DateTime get launch => _simulation.launch;

  @override
  int get missionDays => _simulation.missionDays;

  @override
  List<String> crewIds() => [
    for (final b in _simulation.baselines) b.astronautId,
  ];

  @override
  BiomarkerBaseline baselineOf(String astronautId) =>
      _simulation.baselines.firstWhere((b) => b.astronautId == astronautId);

  @override
  List<UrineSample> urineSamples(String astronautId) => [
    for (final u in _simulation.urine)
      if (u.sample.astronautId == astronautId) u.sample,
  ]..sort((a, b) => a.takenAt.compareTo(b.takenAt));

  @override
  List<BloodSample> bloodSamples(String astronautId) => [
    for (final b in _simulation.blood)
      if (b.sample.astronautId == astronautId) b.sample,
  ]..sort((a, b) => a.takenAt.compareTo(b.takenAt));

  @override
  DateTime? lastSolarEventAt(DateTime date) {
    final day = _simulation.speDay;
    if (day == null) return null;
    final event = launch.add(Duration(days: day, hours: 12));
    return event.isAfter(date) ? null : event;
  }
}
