import 'package:astramed/features/02_radiation/agent/radiation_health_skills.dart';
import 'package:astramed/features/02_radiation/models/radiation_symptom.dart';
import 'package:astramed/features/02_radiation/providers/biomarker_providers.dart';
import 'package:astramed/features/02_radiation/providers/radiation_data_provider.dart';
import 'package:astramed/features/02_radiation/providers/radiation_integration_provider.dart';
import 'package:astramed/features/02_radiation/providers/symptom_providers.dart';
import 'package:astramed/features/agent/application/skill_registry.dart';
import 'package:astramed/features/agent/domain/agent_contracts.dart';
import 'package:astramed/features/crew/presentation/providers/crew_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../radiation_test_data.dart';

/// Collaborators the read-only radiation tools never touch.
class _Unused
    implements
        AgentUiSink,
        ConfirmationGate,
        AuditLog,
        MemoryStore,
        AgentFlagsStore,
        MedicationSafety {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Radiation tools must be read-only');
}

void main() {
  final mission = loadRadiationTestMission();

  Future<ProviderContainer> container() async {
    final c = ProviderContainer(
      overrides: [
        ...radiationIntegrationOverrides,
        radiationMissionDataProvider.overrideWith((ref) async => mission),
      ],
    );
    addTearDown(c.dispose);
    await c.read(radiationMissionDataProvider.future);
    return c;
  }

  ToolContext ctxFor(ProviderContainer c, String astronautId) {
    final unused = _Unused();
    return ToolContext(
      astronautId: astronautId,
      read: <T>(provider) => c.read(provider as ProviderListenable<T>),
      ui: unused,
      confirm: unused,
      audit: unused,
      memory: unused,
      flags: unused,
      medication: unused,
    );
  }

  test('dose tool matches the Radiation screen summary', () async {
    final c = await container();
    c.read(selectedAstronautIdProvider.notifier).state = 'AST-03';
    c.read(selectedMissionDayProvider.notifier).state = 96;
    final screen = c.read(selectedDoseSummaryProvider)!;

    final result = await const GetRadiationDoseTool().call(
      const {},
      ctxFor(c, 'AST-03'),
    );

    expect(result.ok, isTrue);
    expect(result.data['available'], isTrue);
    expect(result.data['mission_day'], 96);
    expect(
      result.data['career_effective_dose_msv'],
      closeTo(screen.careerEffectiveDoseMsv, 0.01),
    );
    expect(
      result.data['remaining_career_dose_msv'],
      closeTo(screen.remainingCareerDoseMsv, 0.01),
    );
    expect(result.data['spe_status'], screen.speStatus.name);
    expect(
      (result.data['organ_limit_use_pct'] as Map).keys,
      containsAll(screen.organLimitUse.keys.map((o) => o.name)),
    );
  });

  test('dose tool reports missing dosimetry instead of inventing it', () async {
    final c = await container();
    final missingCrew = await const GetRadiationDoseTool().call(
      const {'mission_day': 96},
      ctxFor(c, 'AST-05'),
    );
    final returnDay = await const GetRadiationDoseTool().call(
      const {'mission_day': 181},
      ctxFor(c, 'AST-01'),
    );
    expect(missingCrew.data['available'], isFalse);
    expect(returnDay.data['available'], isFalse);
  });

  test('biomarker tool returns score, level and baseline changes', () async {
    final c = await container();
    final bio = c.read(
      bioSummaryProvider((astronautId: 'AST-03', missionDay: 96)),
    );

    final result = await const GetRadiationBiomarkersTool().call(
      const {'mission_day': 96},
      ctxFor(c, 'AST-03'),
    );

    expect(result.ok, isTrue);
    expect(result.data['available'], isTrue);
    expect(result.data['score'], closeTo(bio.score, 0.001));
    expect(result.data['level'], isIn(['normal', 'watch', 'alert']));
    expect(result.data['sample_pending'], bio.samplePending);
    expect(
      (result.data['change_from_baseline_pct'] as Map).length,
      bio.changeFromBaseline.length,
    );
  });

  test('biomarker tool handles an astronaut without data', () async {
    final c = await container();
    final result = await const GetRadiationBiomarkersTool().call(
      const {},
      ctxFor(c, 'UNKNOWN'),
    );
    expect(result.ok, isTrue);
    expect(result.data['available'], isFalse);
  });

  test('symptom tool lists marked symptoms, most urgent first', () async {
    final c = await container();
    c.read(reportedSymptomsProvider('AST-02').notifier).state = {
      RadiationSymptom.lightFlashes,
      RadiationSymptom.vomiting,
    };

    final result = await const GetRadiationSymptomsTool().call(
      const {},
      ctxFor(c, 'AST-02'),
    );
    final symptoms = result.data['symptoms'] as List;

    expect(result.data['count'], 2);
    expect(result.data['worst_level'], 'urgent');
    expect((symptoms.first as Map)['id'], 'vomiting');
    expect((symptoms.first as Map)['action'], isNotEmpty);

    final none = await const GetRadiationSymptomsTool().call(
      const {},
      ctxFor(c, 'AST-01'),
    );
    expect(none.data['count'], 0);
    expect(none.data['worst_level'], isNull);
  });

  test('offline flow speaks a summary and escalates urgent symptoms', () async {
    final c = await container();
    c.read(selectedMissionDayProvider.notifier).state = 96;
    final calm = await const RadiationHealthOfflineFlow().start(
      ctxFor(c, 'AST-01'),
    );
    expect(calm.isTerminal, isTrue);
    expect(calm.prompt, contains('Career dose'));
    expect(calm.prompt, contains('Biological score'));

    c.read(reportedSymptomsProvider('AST-01').notifier).state = {
      RadiationSymptom.fever,
    };
    final urgent = await const RadiationHealthOfflineFlow().start(
      ctxFor(c, 'AST-01'),
    );
    expect(urgent.verdict!['escalate'], isTrue);
    final banner = urgent.uiEvents.single as ShowComponentEvent;
    expect(banner.id, ComponentIds.alertBanner);
    expect(banner.props['severity'], 'critical');
    expect(urgent.prompt, contains('flight surgeon'));
    expect(urgent.prompt, contains(RadiationSymptom.fever.label));
  });

  test('offline lookup routes biomarker questions to this skill', () {
    final registry = SkillRegistry([radiationHealthSkill()]);
    expect(
      registry.findOfflineFlow('¿cómo van mis biomarcadores?')?.skillId,
      'radiation_health',
    );
  });

  test('skill is selected for radiation questions in Spanish and English', () {
    final registry = SkillRegistry([radiationHealthSkill()]);
    for (final q in [
      '¿Cómo están mis biomarcadores?',
      'what is my radiation dose',
      'tengo un síntoma raro',
    ]) {
      expect(
        registry.select(query: q).map((s) => s.id),
        contains('radiation_health'),
        reason: q,
      );
    }
    final tools = radiationHealthSkill().tools;
    expect(tools.every((t) => t.effect == ToolEffect.read), isTrue);
    expect(tools.map((t) => t.name).toSet(), {
      'get_radiation_dose',
      'get_radiation_biomarkers',
      'get_radiation_symptoms',
    });
  });
}
