import '../../agent/domain/agent_contracts.dart';
import '../data/radiation_sample_repository.dart';
import '../models/biomarkers/biomarker_baseline.dart';
import '../models/contracts/bio_summary.dart';
import '../models/contracts/dose_summary.dart';
import '../models/radiation_symptom.dart';
import '../providers/biomarker_providers.dart';
import '../providers/radiation_data_provider.dart';
import '../providers/radiation_summary_calculator.dart';
import '../providers/symptom_providers.dart';
import '../widgets/biomarker_panel.dart' show BioLevel;

/// Read-only bridge between the Radiation module (María's dosimetry and
/// Juan's biomarkers) and the clinical agent.
///
/// Every tool reads the same Riverpod providers the Radiation screen uses, so
/// the agent explains exactly what the astronaut sees. Nothing is written and
/// nothing leaves the device (offline-first).

const _missionDayParam = {
  'mission_day': {
    'type': 'integer',
    'description':
        'Mission day to inspect. Defaults to the day selected on the Radiation screen.',
  },
};

const _illustrativeNote =
    'Prototype thresholds are illustrative, not clinical criteria. '
    'Escalate to the flight surgeon when in doubt.';

int _missionDay(Map<String, dynamic> args, ToolContext ctx) {
  final raw = args['mission_day'];
  if (raw is num && raw >= 1) return raw.toInt();
  return ctx.read<int>(selectedMissionDayProvider);
}

double _round(double value, [int digits = 2]) =>
    double.parse(value.toStringAsFixed(digits));

/// Physical dose for [astronautId] on [missionDay], or null when the bundled
/// dataset has no record (e.g. return day or a crewmember without dosimetry).
DoseSummary? doseSummaryFor({
  required RadiationMissionData mission,
  required String astronautId,
  required int missionDay,
  required DateTime date,
}) {
  final profiles = mission.crewProfiles.where((p) => p.id == astronautId);
  final hasRecord = mission.dosimetry.any(
    (r) => r.astronautId == astronautId && r.missionDay == missionDay,
  );
  if (profiles.isEmpty || !hasRecord) return null;
  final daily = calculateRadiationDailySummary(
    astronautId: astronautId,
    missionDay: missionDay,
    priorCareerDoseMsv: profiles.single.priorCareerEffectiveDoseMsv,
    dosimetry: mission.dosimetry,
    spaceWeather: mission.spaceWeather,
  );
  return DoseSummary.fromDaily(daily, date: date);
}

class GetRadiationDoseTool extends AgentTool {
  const GetRadiationDoseTool();

  @override
  String get name => 'get_radiation_dose';

  @override
  String get description =>
      'Read the astronaut\'s physical radiation dose for a mission day: career '
      'effective dose and remaining margin (mSv, NASA-STD-3001 600 mSv limit), '
      'percent of each organ\'s non-cancer limit used, and solar particle event status.';

  @override
  Map<String, dynamic> get parameters => const {
    'type': 'object',
    'properties': _missionDayParam,
  };

  @override
  Future<ToolResult> call(Map<String, dynamic> args, ToolContext ctx) async {
    final day = _missionDay(args, ctx);
    final RadiationMissionData mission;
    try {
      mission = await ctx.read<Future<RadiationMissionData>>(
        radiationMissionDataProvider.future,
      );
    } catch (e) {
      return ToolResult.fail('Radiation dataset unavailable: $e');
    }
    final repo = ctx.read(biomarkerRepositoryProvider);
    final summary = doseSummaryFor(
      mission: mission,
      astronautId: ctx.astronautId,
      missionDay: day,
      date: repo
          .dateOfMissionDay(day)
          .add(const Duration(hours: 23, minutes: 59)),
    );
    if (summary == null) {
      return ToolResult.ok({
        'astronaut_id': ctx.astronautId,
        'mission_day': day,
        'available': false,
        'reason': 'No dosimetry record for this astronaut and mission day.',
      });
    }
    final organs = summary.organLimitUse.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return ToolResult.ok({
      'astronaut_id': summary.astronautId,
      'mission_day': day,
      'available': true,
      'career_effective_dose_msv': _round(summary.careerEffectiveDoseMsv),
      'remaining_career_dose_msv': _round(summary.remainingCareerDoseMsv),
      'organ_limit_use_pct': {
        for (final e in organs) e.key.name: _round(e.value * 100, 1),
      },
      'spe_status': summary.speStatus.name,
      'note': 'Organ use reflects this mission only; prior organ doses are not in the dataset.',
    });
  }
}

class GetRadiationBiomarkersTool extends AgentTool {
  const GetRadiationBiomarkersTool();

  @override
  String get name => 'get_radiation_biomarkers';

  @override
  String get description =>
      'Read the astronaut\'s radiation biomarkers for a mission day: biological '
      'score B with its traffic-light level, percent change of each marker '
      '(8-OHdG, isoprostanes, MDA, lymphocytes, neutrophils, CRP) versus the '
      'personal baseline, and whether a sample is pending.';

  @override
  Map<String, dynamic> get parameters => const {
    'type': 'object',
    'properties': _missionDayParam,
  };

  @override
  Future<ToolResult> call(Map<String, dynamic> args, ToolContext ctx) async {
    final day = _missionDay(args, ctx);
    final repo = ctx.read(biomarkerRepositoryProvider);
    if (!repo.crewIds().contains(ctx.astronautId)) {
      return ToolResult.ok({
        'astronaut_id': ctx.astronautId,
        'mission_day': day,
        'available': false,
        'reason': 'No biomarker data for this astronaut.',
      });
    }
    final BioSummary bio = ctx.read(
      bioSummaryProvider((astronautId: ctx.astronautId, missionDay: day)),
    );
    final level = BioLevel.of(bio.score);
    return ToolResult.ok({
      'astronaut_id': bio.astronautId,
      'mission_day': day,
      'available': true,
      'score': _round(bio.score, 3),
      'level': level.name,
      'level_thresholds': {
        'watch_from': BioLevel.watchFrom,
        'alert_from': BioLevel.alertFrom,
      },
      'change_from_baseline_pct': {
        for (final m in Biomarker.values)
          if (bio.changeOf(m) != null) m.name: _round(bio.changeOf(m)! * 100, 1),
      },
      'sample_pending': bio.samplePending,
      'note': _illustrativeNote,
    });
  }
}

class GetRadiationSymptomsTool extends AgentTool {
  const GetRadiationSymptomsTool();

  @override
  String get name => 'get_radiation_symptoms';

  @override
  String get description =>
      'Read the radiation-related symptoms the astronaut marked today, each '
      'with its urgency (info, watch, urgent), why it happens and what to do.';

  @override
  Map<String, dynamic> get parameters => const {
    'type': 'object',
    'properties': <String, dynamic>{},
  };

  @override
  Future<ToolResult> call(Map<String, dynamic> args, ToolContext ctx) async {
    final Set<RadiationSymptom> marked = ctx.read(
      reportedSymptomsProvider(ctx.astronautId),
    );
    final sorted = marked.toList()
      ..sort((a, b) => b.level.index.compareTo(a.level.index));
    return ToolResult.ok({
      'astronaut_id': ctx.astronautId,
      'count': sorted.length,
      'worst_level': RadiationSymptom.worstOf(sorted)?.name,
      'symptoms': [
        for (final s in sorted)
          {
            'id': s.name,
            'label': s.label,
            'level': s.level.name,
            'when': s.when,
            'why': s.why,
            'action': s.action,
          },
      ],
      'note': _illustrativeNote,
    });
  }
}

/// Offline fallback: reads the three tools and speaks a short deterministic
/// summary, so the astronaut gets an answer without the LLM server.
class RadiationHealthOfflineFlow implements DeterministicFlow {
  const RadiationHealthOfflineFlow();

  @override
  String get skillId => 'radiation_health';

  @override
  Future<DeterministicStep> start(ToolContext ctx) async {
    final dose = (await const GetRadiationDoseTool().call(const {}, ctx)).data;
    final bio =
        (await const GetRadiationBiomarkersTool().call(const {}, ctx)).data;
    final symptoms =
        (await const GetRadiationSymptomsTool().call(const {}, ctx)).data;

    final parts = <String>[];
    final urgent = <String>[];

    if (dose['available'] == true) {
      parts.add(
        'Career dose ${dose['career_effective_dose_msv']} mSv, '
        '${dose['remaining_career_dose_msv']} mSv left before the NASA limit.',
      );
      if (dose['spe_status'] == 'active') {
        urgent.add('a solar particle event is active, go to the shelter');
      }
    } else {
      parts.add('No dosimetry record for this day.');
    }

    if (bio['available'] == true) {
      final level = bio['level'] as String;
      parts.add('Biological score is $level.');
      if (level == 'alert') urgent.add('the biological score is in alert');
      if (bio['sample_pending'] == true) {
        parts.add('A biomarker sample is due.');
      }
    }

    final count = symptoms['count'] as int;
    if (count > 0) {
      parts.add('$count radiation symptom${count == 1 ? '' : 's'} marked.');
      final urgentLabels = [
        for (final s in symptoms['symptoms'] as List)
          if ((s as Map)['level'] == 'urgent') s['label'],
      ];
      if (urgentLabels.isNotEmpty) {
        urgent.add('urgent symptom: ${urgentLabels.join(', ')}');
      }
    }

    if (urgent.isNotEmpty) {
      parts.add('Contact the flight surgeon now: ${urgent.join(', ')}.');
    }

    final severity = urgent.isNotEmpty
        ? 'critical'
        : (bio['level'] == 'watch' || count > 0)
        ? 'warning'
        : 'info';
    final summary = parts.join(' ');
    return DeterministicStep(
      prompt: 'Offline radiation check. $summary',
      uiEvents: [
        AgentComponentEvent.show(ComponentIds.alertBanner, {
          'title': 'Radiation status',
          'message': summary,
          'severity': severity,
          if (urgent.isEmpty)
            'recommended_action':
                'Open the Radiation tab for charts and per-marker detail.',
        }),
      ],
      isTerminal: true,
      verdict: {
        'escalate': urgent.isNotEmpty,
        'dose': dose,
        'biomarkers': bio,
        'symptoms': symptoms,
      },
    );
  }

  @override
  Future<DeterministicStep> advance(String userInput, ToolContext ctx) =>
      start(ctx);
}

/// Skill exposing the Radiation module's dose, biomarkers and symptoms.
AgentSkill radiationHealthSkill() => const AgentSkill(
  offlineFlow: RadiationHealthOfflineFlow(),
  componentIds: [ComponentIds.alertBanner],
  id: 'radiation_health',
  instructions:
      'To explain the astronaut\'s radiation status, read get_radiation_dose, '
      'get_radiation_biomarkers and get_radiation_symptoms instead of guessing. '
      'Explain in plain language: the biological score level (normal, watch, '
      'alert), which markers moved most, the remaining career dose, and what to '
      'do for each symptom. Any urgent symptom, an alert-level score or an '
      'active solar particle event means: recommend sheltering if applicable '
      'and contacting the flight surgeon now. Never present these thresholds '
      'as a diagnosis. Keep answers short enough to be spoken.',
  tools: [
    GetRadiationDoseTool(),
    GetRadiationBiomarkersTool(),
    GetRadiationSymptomsTool(),
  ],
  triggers: [
    'radiation',
    'radiación',
    'radiacion',
    'dose',
    'dosis',
    'msv',
    'sievert',
    'biomarker',
    'biomarcador',
    'lymphocyte',
    'linfocito',
    'neutrophil',
    'neutrófilo',
    'score',
    'puntaje',
    'symptom',
    'síntoma',
    'sintoma',
    'nausea',
    'náusea',
  ],
);
