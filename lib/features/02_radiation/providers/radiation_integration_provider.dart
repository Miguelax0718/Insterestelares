import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../crew/presentation/providers/crew_provider.dart';
import '../data/biomarker_repository.dart';
import '../data/dose_linked_biomarker_repository.dart';
import '../models/contracts/dose_summary.dart';
import 'biomarker_providers.dart';
import 'radiation_data_provider.dart';
import 'radiation_summary_calculator.dart';

/// Production adapter. Standalone biological providers retain their mock default.
final linkedBiomarkerRepositoryProvider = Provider<BiomarkerRepository>((ref) {
  final mission = ref.watch(radiationMissionDataProvider).asData?.value;
  final crewIds = ref
      .watch(crewMembersProvider)
      .map((crew) => crew.id)
      .toList();
  final scenario = ref.watch(biomarkerScenarioProvider);
  if (mission == null) {
    return MockBiomarkerRepository(crewIds: crewIds, scenario: scenario);
  }
  return DoseLinkedBiomarkerRepository(
    mission: mission,
    crewIds: crewIds,
    scenario: scenario,
  );
});

/// Installed at the app's root so all biological consumers share the same data.
final radiationIntegrationOverrides = [
  biomarkerRepositoryProvider.overrideWith(
    (ref) => ref.watch(linkedBiomarkerRepositoryProvider),
  ),
  selectedMissionDayProvider.overrideWith((ref) => 1),
];

/// Null is unavailable, including return day; never substitute another crew/day.
final selectedDoseSummaryProvider = Provider<DoseSummary?>((ref) {
  final mission = ref.watch(radiationMissionDataProvider).asData?.value;
  if (mission == null) return null;
  final astronautId = ref.watch(selectedAstronautIdProvider);
  final day = ref.watch(selectedMissionDayProvider);
  final profiles = mission.crewProfiles.where((p) => p.id == astronautId);
  final records = mission.dosimetry.where(
    (r) => r.astronautId == astronautId && r.missionDay == day,
  );
  if (profiles.isEmpty || records.isEmpty) return null;
  final daily = calculateRadiationDailySummary(
    astronautId: astronautId,
    missionDay: day,
    priorCareerDoseMsv: profiles.single.priorCareerEffectiveDoseMsv,
    dosimetry: mission.dosimetry,
    spaceWeather: mission.spaceWeather,
  );
  final repo = ref.watch(biomarkerRepositoryProvider);
  return DoseSummary.fromDaily(
    daily,
    date: repo
        .dateOfMissionDay(day)
        .add(const Duration(hours: 23, minutes: 59)),
  );
});
