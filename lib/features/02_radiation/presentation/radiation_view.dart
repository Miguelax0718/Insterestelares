import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../crew/presentation/providers/crew_provider.dart';
import '../data/biomarker_simulator.dart';
import '../data/biomarker_repository.dart';
import '../data/dose_linked_biomarker_repository.dart';
import '../data/radiation_sample_repository.dart';
import '../models/daily_radiation_record.dart';
import '../models/radiation_organ.dart';
import '../providers/biomarker_providers.dart';
import '../providers/career_dose_calculator.dart';
import '../providers/dose_history.dart';
import '../providers/organ_dose_calculator.dart';
import '../providers/radiation_data_provider.dart';
import '../providers/radiation_summary_calculator.dart';
import '../providers/spe_detector.dart';
import '../widgets/biomarker_panel.dart';
import '../widgets/cumulative_dose_chart.dart';
import '../widgets/radiation_symptoms_card.dart';
import '../widgets/shelter_drill_card.dart';

/// One crew selection and one mission day for the physical and biological layers.
class RadiationView extends ConsumerWidget {
  const RadiationView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(radiationMissionDataProvider)
        .when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text('Unable to load local radiation data: $error'),
            ),
          ),
          data: (mission) => _CombinedMissionView(mission: mission),
        );
  }
}

class _CombinedMissionView extends ConsumerWidget {
  const _CombinedMissionView({required this.mission});

  final RadiationMissionData mission;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final astronaut = ref.watch(selectedAstronautProvider);
    final day = ref.watch(selectedMissionDayProvider);
    late final BiomarkerRepository repository;
    try {
      repository = ref.watch(biomarkerRepositoryProvider);
    } catch (error) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Biomarker integration unavailable: $error'),
          _PhysicalDosePanel(
            mission: mission,
            astronautId: astronaut.id,
            missionDay: day,
          ),
        ],
      );
    }
    final maxDay = repository.missionDays + 1;
    final date = repository
        .dateOfMissionDay(day)
        .toIso8601String()
        .split('T')
        .first;
    final linked = repository is DoseLinkedBiomarkerRepository
        ? repository
        : null;
    final eventDose = linked?.eventDoseMsv[astronaut.id];
    final hasDosimetry = mission.dosimetry.any(
      (r) => r.astronautId == astronaut.id,
    );
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Dosímetro de Radiación Espacial',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        Text('Monitoring: ${astronaut.name} [${astronaut.id}]'),
        const Text(
          'Synthetic mission data. Choose a crewmember in the crew menu.',
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Mission day: $day of ${repository.missionDays}'
                  '${day > repository.missionDays ? ' (return)' : ''} · $date',
                ),
                Slider(
                  key: const Key('radiationMissionDaySlider'),
                  min: 1,
                  max: maxDay.toDouble(),
                  divisions: maxDay - 1,
                  value: day.toDouble().clamp(1, maxDay).toDouble(),
                  label: '$day',
                  onChanged: (value) =>
                      ref.read(selectedMissionDayProvider.notifier).state =
                          value.round(),
                ),
              ],
            ),
          ),
        ),
        if (!hasDosimetry)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'No dosimetry is available for ${astronaut.id}. '
                'Biomarkers remain a separate synthetic scenario for this crewmember; '
                'no physical dose or combined assessment can be inferred.',
                key: const Key('missingDosimetry'),
              ),
            ),
          ),
        _PhysicalDosePanel(
          mission: mission,
          astronautId: astronaut.id,
          missionDay: day,
        ),
        const SizedBox(height: 16),
        if (ref.watch(biomarkerScenarioProvider) ==
            SimulationScenario.extremeHypothetical)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'The extreme scenario changes biological simulation only. '
              'Dosimetry still shows the loaded mission measurements.',
            ),
          ),
        BiomarkerPanel(
          showMissionDaySelector: false,
          realisticDoseDescription: linked == null
              ? null
              : eventDose == null
              ? 'No personal SPE dose is available; the biological demo has no dose-dependent SPE input for this crewmember.'
              : 'Biological demo uses ${eventDose.toStringAsFixed(3)} mSv of SPE dose from the loaded dosimetry.',
        ),
        const SizedBox(height: 16),
        const RadiationSymptomsCard(),
      ],
    );
  }
}

class _PhysicalDosePanel extends StatelessWidget {
  const _PhysicalDosePanel({
    required this.mission,
    required this.astronautId,
    required this.missionDay,
  });

  final RadiationMissionData mission;
  final String astronautId;
  final int missionDay;

  @override
  Widget build(BuildContext context) {
    final profiles = mission.crewProfiles.where((p) => p.id == astronautId);
    final currentRecords = mission.dosimetry.where(
      (r) => r.astronautId == astronautId && r.missionDay == missionDay,
    );
    if (profiles.isEmpty) return const SizedBox.shrink();
    if (currentRecords.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          'No dosimetry record for $astronautId on day $missionDay. '
          'No dose is substituted from a different day.',
          key: const Key('missingDailyDose'),
        ),
      );
    }
    final profile = profiles.single;
    final record = currentRecords.single;
    final summary = calculateRadiationDailySummary(
      astronautId: astronautId,
      missionDay: missionDay,
      priorCareerDoseMsv: profile.priorCareerEffectiveDoseMsv,
      dosimetry: mission.dosimetry,
      spaceWeather: mission.spaceWeather,
    );
    final history = calculateDoseHistory(
      astronautId: astronautId,
      missionDay: missionDay,
      priorCareerDoseMsv: profile.priorCareerEffectiveDoseMsv,
      records: mission.dosimetry,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildCareerDoseCard(
          summary,
          (summary.careerEffectiveDoseMsv / careerDoseLimitMsv).clamp(0.0, 1.0),
        ),
        const SizedBox(height: 12),
        _buildSpeCard(summary, record),
        if (summary.speStatus == SpeStatus.active &&
            record.module != 'storm_shelter')
          ShelterDrillCard(key: ValueKey('$astronautId-$missionDay')),
        if (summary.speStatus == SpeStatus.active &&
            record.module == 'storm_shelter')
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'The selected record already places this crewmember in the storm shelter.',
            ),
          ),
        const SizedBox(height: 12),
        CumulativeDoseChart(points: history),
        const SizedBox(height: 16),
        const Text(
          'Organ dose limits',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        ...summary.organDoseUse.values.map(_buildOrganTile),
      ],
    );
  }

  // Existing dosimetry cards are retained below.

  Widget _buildCareerDoseCard(RadiationDailySummary summary, num progress) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Presupuesto de dosis de carrera',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            LinearProgressIndicator(value: progress.toDouble(), minHeight: 10),
            const SizedBox(height: 8),
            Text(
              '${summary.careerEffectiveDoseMsv.toStringAsFixed(1)} mSv acumulados · '
              '${summary.remainingCareerDoseMsv.toStringAsFixed(1)} mSv restantes',
            ),
            const Text('Límite de referencia: 600 mSv'),
            if (summary.careerLimitReached)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Se alcanzó o superó el límite de referencia.',
                  style: TextStyle(color: Colors.redAccent),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSpeCard(
    RadiationDailySummary summary,
    DailyRadiationRecord record,
  ) {
    final (String label, Color color) = switch (summary.speStatus) {
      SpeStatus.active => (
        'Evento SPE indicado en el clima espacial',
        Colors.redAccent,
      ),
      SpeStatus.inactive => (
        'Sin evento SPE indicado ese día',
        Colors.greenAccent,
      ),
      SpeStatus.unknown => (
        'Dato de clima espacial no disponible',
        Colors.amberAccent,
      ),
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Clima espacial',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(color: color, fontWeight: FontWeight.bold),
            ),
            Text('Módulo: ${record.module}'),
            Text(
              'Dosis efectiva del día: ${record.effectiveDoseMsv.toStringAsFixed(3)} mSv',
            ),
            Text(
              'Aporte SPE (incluido arriba): ${record.speEventDoseMsv.toStringAsFixed(3)} mSv',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrganTile(OrganDoseUse organUse) {
    final worstWindow = organUse.windows.entries.reduce(
      (current, next) => current.value.fractionUsed >= next.value.fractionUsed
          ? current
          : next,
    );
    final fraction = worstWindow.value.fractionUsed;
    final exceeded = fraction > 1.0;
    final progress = fraction.clamp(0.0, 1.0).toDouble();

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(_organLabel(organUse.organ))),
                Text(
                  exceeded
                      ? 'Límite superado'
                      : '${(fraction * 100).toStringAsFixed(1)} %',
                  style: TextStyle(
                    color: exceeded ? Colors.redAccent : Colors.white70,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            LinearProgressIndicator(value: progress),
            const SizedBox(height: 4),
            Text('Ventana más alta: ${_windowLabel(worstWindow.key)}'),
          ],
        ),
      ),
    );
  }

  String _organLabel(RadiationOrgan organ) {
    switch (organ) {
      case RadiationOrgan.lens:
        return 'Cristalino';
      case RadiationOrgan.skin:
        return 'Piel';
      case RadiationOrgan.bloodFormingOrgans:
        return 'Órganos hematopoyéticos';
      case RadiationOrgan.circulatorySystem:
        return 'Sistema circulatorio';
      case RadiationOrgan.centralNervousSystem:
        return 'Sistema nervioso central';
    }
  }

  String _windowLabel(DoseWindow window) {
    switch (window) {
      case DoseWindow.last30Days:
        return 'Últimos 30 días';
      case DoseWindow.last365Days:
        return 'Últimos 365 días';
      case DoseWindow.thisMissionAgainstCareerLimit:
        return 'Esta misión frente al límite de carrera';
    }
  }
}
