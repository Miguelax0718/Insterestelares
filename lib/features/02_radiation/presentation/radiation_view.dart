import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/daily_radiation_record.dart';
import '../models/radiation_organ.dart';
import '../data/radiation_sample_repository.dart';
import '../models/space_weather_reading.dart';
import '../providers/career_dose_calculator.dart';
import '../providers/organ_dose_calculator.dart';
import '../providers/radiation_data_provider.dart';
import '../providers/radiation_summary_calculator.dart';
import '../providers/spe_detector.dart';

class RadiationView extends ConsumerStatefulWidget {
  const RadiationView({super.key});

  @override
  ConsumerState<RadiationView> createState() => _RadiationViewState();
}

class _RadiationViewState extends ConsumerState<RadiationView> {
  String? _selectedAstronautId;
  int _missionDay = 1;

  @override
  Widget build(BuildContext context) {
    final missionAsync = ref.watch(radiationMissionDataProvider);
    return missionAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('No se pudieron cargar los datos locales de radiación: $error'),
        ),
      ),
      data: (mission) => _buildMissionView(context, mission),
    );
  }

  Widget _buildMissionView(BuildContext context, RadiationMissionData mission) {
    if (mission.crewProfiles.isEmpty) {
      return const Center(child: Text('No hay perfiles de tripulación disponibles.'));
    }

    final firstAstronautId = mission.crewProfiles.first.id;
    final astronautId = mission.crewProfiles.any(
      (profile) => profile.id == _selectedAstronautId,
    )
        ? _selectedAstronautId!
        : firstAstronautId;
    final crewProfile = mission.crewProfiles.singleWhere(
      (profile) => profile.id == astronautId,
    );
    final crewRecords = mission.dosimetry
        .where((record) => record.astronautId == astronautId)
        .toList(growable: false);
    final maxMissionDay = crewRecords.fold<int>(
      1,
      (maximum, record) =>
          record.missionDay > maximum ? record.missionDay : maximum,
    );
    final missionDay = _missionDay > maxMissionDay ? maxMissionDay : _missionDay;

    final summary = calculateRadiationDailySummary(
      astronautId: astronautId,
      missionDay: missionDay,
      priorCareerDoseMsv: crewProfile.priorCareerEffectiveDoseMsv,
      dosimetry: mission.dosimetry,
      spaceWeather: mission.spaceWeather,
    );
    final currentRecord = crewRecords.singleWhere(
      (record) => record.missionDay == missionDay,
    );

    final careerProgress =
        (summary.careerEffectiveDoseMsv / careerDoseLimitMsv).clamp(0.0, 1.0);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Dosimetría espacial',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        const Text(
          'Datos locales de demostración. Las mediciones son sintéticas.',
          style: TextStyle(color: Colors.white70),
        ),
        const SizedBox(height: 16),
        _buildMissionControls(
          mission.crewProfiles.map((profile) => profile.id).toList(),
          astronautId,
          missionDay,
          maxMissionDay,
        ),
        const SizedBox(height: 16),
        _buildCareerDoseCard(summary, careerProgress),
        const SizedBox(height: 12),
        _buildSpeCard(summary, currentRecord),
        const SizedBox(height: 20),
        const Text(
          'Uso de límites por órgano',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        ...summary.organDoseUse.values.map(_buildOrganTile),
      ],
    );
  }

  Widget _buildMissionControls(
    List<String> astronautIds,
    String selectedAstronautId,
    int missionDay,
    int maxMissionDay,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<String>(
              value: selectedAstronautId,
              decoration: const InputDecoration(labelText: 'Tripulante'),
              items: astronautIds
                  .map((id) => DropdownMenuItem(value: id, child: Text(id)))
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedAstronautId = value);
                }
              },
            ),
            const SizedBox(height: 12),
            Text('Día de misión: $missionDay de $maxMissionDay'),
            Slider(
              min: 1,
              max: maxMissionDay.toDouble(),
              divisions: maxMissionDay > 1 ? maxMissionDay - 1 : null,
              value: missionDay.toDouble(),
              label: '$missionDay',
              onChanged: maxMissionDay > 1
                  ? (value) => setState(() => _missionDay = value.round())
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCareerDoseCard(
    RadiationDailySummary summary,
    num progress,
  ) {
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
      SpeStatus.active => ('Evento SPE indicado en el clima espacial', Colors.redAccent),
      SpeStatus.inactive => ('Sin evento SPE indicado ese día', Colors.greenAccent),
      SpeStatus.unknown => ('Dato de clima espacial no disponible', Colors.amberAccent),
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
            Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
            Text('Módulo: ${record.module}'),
            Text('Dosis efectiva del día: ${record.effectiveDoseMsv.toStringAsFixed(3)} mSv'),
            Text('Aporte SPE (incluido arriba): ${record.speEventDoseMsv.toStringAsFixed(3)} mSv'),
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
                  exceeded ? 'Límite superado' : '${(fraction * 100).toStringAsFixed(1)} %',
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
