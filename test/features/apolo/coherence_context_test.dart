import 'dart:convert';

import 'package:astramed/features/agent/application/context_builder.dart';
import 'package:astramed/features/agent/application/core_tools.dart';
import 'package:astramed/features/agent/application/skill_registry.dart';
import 'package:astramed/features/agent/domain/agent_contracts.dart';
import 'package:astramed/features/agent/domain/guided_assessment_catalog.dart';
import 'package:astramed/features/apolo/agent/apolo_urine_skill.dart';
import 'package:astramed/features/apolo/data/apolo_repository.dart';
import 'package:astramed/features/apolo/providers/apolo_contract_providers.dart';
import 'package:astramed/features/apolo/domain/apolo_models.dart';
import 'package:astramed/features/crew/data/mock_crew_data.dart';
import 'package:astramed/features/crew/presentation/providers/crew_provider.dart';
import 'package:flutter_test/flutter_test.dart';

class _Memory implements MemoryStore {
  @override
  Future<List<MemoryEntry>> recentForPrompt(String id, {int limit = 8}) async => [];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Flags implements AgentFlagsStore {
  final values = <String, Map<String, dynamic>>{};
  @override
  Future<Map<String, Map<String, dynamic>>> allForAstronaut(String id) async => values;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Unused implements ConfirmationGate, AuditLog, MedicationSafety {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Ui implements AgentUiSink {
  final events = <AgentComponentEvent>[];
  @override
  void emit(AgentComponentEvent event) => events.add(event);
  @override
  void submit(String id, Map<String, dynamic> result) {}
}

void main() {
  final crew = MockCrewData.getInitialCrew();
  final actions = ApoloStateNotifier(repository: ApoloRepository(), initialAstronautId: 'AST-03');
  final flags = _Flags();
  final memory = _Memory();
  final ui = _Ui();
  final ctx = ToolContext(
    astronautId: 'AST-03',
    read: <T>(Object provider) {
      if (provider == crewMembersProvider) return crew as T;
      if (provider == apoloActionsProvider) return actions as T;
      throw StateError('Unavailable provider');
    },
    ui: ui, confirm: _Unused(), audit: _Unused(), medication: _Unused(),
    memory: memory, flags: flags,
  );

  test('context preserves both critical systems and budget under oversized flags', () async {
    final astronaut = crew.firstWhere((a) => a.id == 'AST-03');
    final state = actions.stateFor('AST-03');
    final context = await const AgentContextBuilder().build(
      astronaut: astronaut, memory: memory, flags: flags,
      apoloState: state, availableTests: GuidedAssessmentCatalog.all,
    );
    final live = context['live'] as Map;
    expect(live['effective_risk_level'], 'critical');
    expect((live['critical_causes'] as List).join(' '), contains(astronaut.riskTitle));
    for (final mod in state.rankedModules.where((m) => m.severity == ApoloSeverity.crit)) {
      expect((live['critical_causes'] as List).join(' '), contains(mod.keyMetric));
    }
    expect(live['apolo']['urgent_modules'], isNotEmpty);
    expect(context['available_tests'], hasLength(13));
    flags.values['huge'] = {'text': List.filled(20000, '🚀').join()};
    final compact = await const AgentContextBuilder().build(
      astronaut: astronaut, memory: memory, flags: flags,
      apoloState: state, availableTests: GuidedAssessmentCatalog.all,
    );
    expect(utf8.encode(jsonEncode(compact)).length, lessThanOrEqualTo(16384));
    expect(compact['live']['critical_causes'], live['critical_causes']);
    expect(compact['live']['effective_risk_level'], 'critical');
    expect(compact['live']['active_alerts'], live['active_alerts']);
  });

  test('core tools share APOLO state and launch catalog components', () async {
    final tools = {for (final t in coreSkill().tools) t.name: t};
    final vitals = await tools['get_vitals']!.call({}, ctx);
    expect(vitals.data['apolo_overall_severity'], 'crit');
    expect(vitals.data['critical_causes'], isNotEmpty);
    final catalog = await tools['get_available_assessments']!.call({}, ctx);
    expect(catalog.data['assessments'], hasLength(13));
    for (final id in ['zero_g_horizon', 'starfield_distortion']) {
      final result = await tools['launch_assessment']!.call({'assessment_id': id}, ctx);
      expect(result.data['launched'], true);
      final event = ui.events.last as ShowComponentEvent;
      expect(event.id, GuidedAssessmentCatalog.byId(id)!.componentId);
    }
    expect(coreSkill().instructions.length, lessThanOrEqualTo(2000));
    final registry = SkillRegistry([coreSkill(), ApoloUrineSkill()]);
    expect(registry.toolsFor(registry.select(query: 'checkup status critical exercise')).length, lessThanOrEqualTo(32));
  });
}
