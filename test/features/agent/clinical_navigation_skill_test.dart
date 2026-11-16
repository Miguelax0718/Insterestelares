import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:astramed/features/agent/application/core_tools.dart';
import 'package:astramed/features/agent/domain/agent_contracts.dart';
import 'package:astramed/features/agent/providers/agent_providers.dart';
import 'package:astramed/features/05_clinical_triage/agent/clinical_navigation_and_procedures_skill.dart';

class _CapturingUiSink implements AgentUiSink {
  final List<AgentComponentEvent> emitted = [];

  @override
  void emit(AgentComponentEvent event) {
    emitted.add(event);
  }

  @override
  void submit(String componentId, Map<String, dynamic> result) {}
}

ToolContext _buildTestContext(ProviderContainer container, _CapturingUiSink ui) {
  return ToolContext(
    astronautId: 'AST-01',
    read: <T>(Object provider) =>
        container.read(provider as ProviderListenable<T>),
    ui: ui,
    confirm: container.read(agentConfirmationGateProvider),
    audit: container.read(agentAuditLogProvider),
    memory: container.read(agentMemoryStoreProvider),
    flags: container.read(agentFlagsStoreProvider),
    medication: container.read(medicationSafetyProvider),
  );
}

void main() {
  test('manual how-to returns every guide without reopening the form', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final ctx = _buildTestContext(container, _CapturingUiSink());
    for (final query in [
      'How do I measure vital signs manually without sensors?',
      'measure vital signs manually',
      'without sensors',
      'how to measure pulse',
      'explain manual vitals',
      'como medir manualmente',
    ]) {
      final flow = container.read(skillRegistryProvider).findOfflineFlow(query)
          as QueryAwareDeterministicFlow?;
      expect(flow, isNotNull, reason: query);
      final step = await flow!.startWithQuery(query, ctx);
      expect(step.verdict!['opened_manual_dialog'], false, reason: query);
      final ids = step.uiEvents.whereType<ShowComponentEvent>().map((e) => e.id);
      expect(ids, isNot(contains('manual_vitals')));
      expect(ids, contains(ComponentIds.statusReport));
      expect(step.isTerminal, true);
      expect(step.prompt, contains('15 seconds'));
      if (query == 'How do I measure vital signs manually without sensors?') {
        for (final text in [
          'radial artery', '×4', '30 seconds', '×2', 'nail bed',
          '< 2.0 seconds', 'thermometer', 'cuff at heart level',
        ]) {
          expect(step.prompt, contains(text));
        }
        expect(step.verdict!['guides'], hasLength(5));
      }
    }
    for (final query in ['Open manual vitals', 'start manual vitals',
      'record manual vitals', 'open manual vitals and explain how to measure']) {
      final step = await const ClinicalNavigationOfflineFlow().advance(query, ctx);
      expect(step.verdict!['opened_manual_dialog'], true);
      expect(step.uiEvents.whereType<ShowComponentEvent>().map((e) => e.id),
          contains('manual_vitals'));
    }
  });
  test('Spanish and English protocol triggers return the same English procedure', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final ctx = _buildTestContext(container, _CapturingUiSink());
    final skill = clinicalNavigationAndProceduresSkill();
    for (final query in ['protocolo rcp', 'cpr protocol']) {
      expect(skill.triggers.any((trigger) => query.contains(trigger)), isTrue);
      final result = await const ClinicalNavigationOfflineFlow().startWithQuery(query, ctx);
      expect(result.verdict!['primary_procedure']['id'], 'PROC-CARDIAC-ARREST');
      expect(result.prompt, startsWith('Cardiac Arrest and Microgravity CPR'));
      expect(result.prompt, contains('Check consciousness and breathing within 10 seconds.'));
    }
    for (final query in ['medir pulso', 'measure pulse']) {
      final result = await const ClinicalNavigationOfflineFlow().startWithQuery(query, ctx);
      expect(result.prompt, contains('15 seconds'));
      expect(result.uiEvents.whereType<ShowComponentEvent>().map((e) => e.id),
        isNot(contains('manual_vitals')));
    }
  });
  test('Spanish and English offline intents open interactive APOLO cards', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final ctx = _buildTestContext(container, _CapturingUiSink());
    for (final entry in {
      'record manual vitals': 'manual_vitals',
      'grafica vitales': ComponentIds.telemetryChart,
      'vitals trend': ComponentIds.telemetryChart,
      'abre triage': 'medical_procedures',
      'procedimientos': 'medical_procedures',
      'procedures': 'medical_procedures',
      'simulador': 'mission_simulator',
      'simulator': 'mission_simulator',
    }.entries) {
      final result = await const ClinicalNavigationOfflineFlow()
        .startWithQuery(entry.key, ctx);
      expect(result.uiEvents.whereType<ShowComponentEvent>().map((e) => e.id),
        contains(entry.value), reason: entry.key);
    }
  });
  test('APOLO orb commands retain their original route and result', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final ctx = _buildTestContext(container, _CapturingUiSink());
    final tool = clinicalNavigationAndProceduresSkill().tools
      .firstWhere((t) => t.name == 'open_clinical_terminal');
    for (final command in ['orbs', 'show_all_orbs', 'hydration', 'renal', 'bones', 'immunity', 'metabolism']) {
      final result = await tool.call({'module': command}, ctx);
      expect(result.ok, true);
      expect(result.data['mode'], 'apolo_orb');
      expect(result.data['show_all_orbs'], command == 'orbs' || command == 'show_all_orbs');
      expect(container.read(clinicalNavigationRequestProvider), isNull);
    }
  });
  group('show_component hydration & clinical_navigation_and_procedures skill', () {
    test(
      'show_component hydrates crew_status even when LLM passes empty props',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final ui = _CapturingUiSink();
        final ctx = _buildTestContext(container, ui);
        final showTool = coreSkill().tools.firstWhere(
          (t) => t.name == 'show_component',
        );

        final result = await showTool.call(const {
          'id': ComponentIds.crewStatus,
          'props': <String, dynamic>{},
        }, ctx);

        expect(result.ok, isTrue);
        expect(ui.emitted, isNotEmpty);
        final event = ui.emitted.last as ShowComponentEvent;
        expect(event.id, ComponentIds.crewStatus);
        expect(event.props['crew'], isA<List>());
        expect((event.props['crew'] as List), isNotEmpty);

        // Must resolve cleanly through ComponentRegistry without FormatException.
        final registry = container.read(componentRegistryProvider);
        final vm = registry.resolve(event.id, event.props);
        expect(vm.componentId, ComponentIds.crewStatus);
      },
    );

    test(
      'open_clinical_terminal opens cockpit cards without legacy navigation',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final ui = _CapturingUiSink();
        final ctx = _buildTestContext(container, ui);
        final skills = container.read(skillRegistryProvider);
        final tools = skills.toolsFor(skills.skills);
        final openTool = tools.firstWhere(
          (t) => t.name == 'open_clinical_terminal',
        );

        final res1 = await openTool.call(const {
          'module': 'radiation',
        }, ctx);
        expect(res1.ok, isTrue);
        final req1 = container.read(clinicalNavigationRequestProvider);
        expect(req1, isNull);
        expect(res1.uiEvents.whereType<ShowComponentEvent>().map((e) => e.id),
            contains(ComponentIds.statusReport));

        // Must pass StatusReportViewModel.fromProps validation without error.
        final registry = container.read(componentRegistryProvider);
        final statusEvent = res1.uiEvents.whereType<ShowComponentEvent>()
            .firstWhere((e) => e.id == ComponentIds.statusReport);
        final vm = registry.resolve(statusEvent.id, statusEvent.props);
        expect(vm.componentId, ComponentIds.statusReport);

        final res2 = await openTool.call(const {
          'module': 'general_health',
          'open_manual_vitals': true,
        }, ctx);
        expect(res2.ok, isTrue);
        final req2 = container.read(clinicalNavigationRequestProvider);
        expect(req2, isNull);
        expect(res2.uiEvents.whereType<ShowComponentEvent>().map((e) => e.id),
            contains('manual_vitals'));
        for (final entry in {
          'vitals': ComponentIds.telemetryChart,
          'triage': 'medical_procedures',
          'simulador': 'mission_simulator',
          'microgravity': 'zero_g_horizon',
          'mental_health': ComponentIds.pvtTest,
        }.entries) {
          final result = await openTool.call({'module': entry.key}, ctx);
          expect(result.uiEvents.whereType<ShowComponentEvent>().map((e) => e.id),
              contains(entry.value));
          for (final event in result.uiEvents.whereType<ShowComponentEvent>()) {
            if (event.id == ComponentIds.telemetryChart ||
                event.id == ComponentIds.vitalsCard ||
                event.id == ComponentIds.statusReport) {
              expect(registry.resolve(event.id, event.props).componentId, event.id);
            }
          }
          expect(container.read(clinicalNavigationRequestProvider), isNull);
        }
      },
    );

    test(
      'search_medical_procedures finds SAS/SMS, SANS, and Radiation protocols offline',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final ui = _CapturingUiSink();
        final ctx = _buildTestContext(container, ui);
        final skills = container.read(skillRegistryProvider);
        final tools = skills.toolsFor(skills.skills);
        final searchTool = tools.firstWhere(
          (t) => t.name == 'search_medical_procedures',
        );

        final sasRes = await searchTool.call(const {
          'query': 'mareo espacial sms sas vestibular',
        }, ctx);
        expect(sasRes.ok, isTrue);
        final card = sasRes.uiEvents.whereType<ShowComponentEvent>()
            .firstWhere((e) => e.id == 'medical_procedures');
        expect(card.props['procedure_id'], 'PROC-VESTIBULAR-SAS');
        expect(
          (sasRes.data['primary_procedure'] as Map)['id'],
          'PROC-VESTIBULAR-SAS',
        );

        final sansRes = await searchTool.call(const {
          'query': 'sindrome neuro ocular sans vista',
        }, ctx);
        expect(sansRes.ok, isTrue);
        expect(
          (sansRes.data['primary_procedure'] as Map)['id'],
          'PROC-SANS-CEPHALEA',
        );

        final radRes = await searchTool.call(const {
          'query': 'radiacion tormenta solar ars',
        }, ctx);
        expect(radRes.ok, isTrue);
        expect(
          (radRes.data['primary_procedure'] as Map)['id'],
          'PROC-RADIATION-ARS',
        );
      },
    );

    test(
      'offline deterministic flow handles "abre la terminal" and manual vitals guidance',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final ui = _CapturingUiSink();
        final ctx = _buildTestContext(container, ui);
        final skills = container.read(skillRegistryProvider);

        final terminalFlow =
            skills.findOfflineFlow('abre la terminal')
                as QueryAwareDeterministicFlow?;
        expect(terminalFlow, isNotNull);
        expect(terminalFlow!.skillId, 'clinical_navigation_and_procedures');

        final step1 = await terminalFlow.startWithQuery('abre la terminal', ctx);
        expect(step1.isTerminal, isTrue);
        final navReq = container.read(clinicalNavigationRequestProvider);
        expect(navReq, isNull);
        expect(step1.uiEvents.whereType<ShowComponentEvent>().map((e) => e.id),
            contains(ComponentIds.telemetryChart));

        final manualFlow =
            skills.findOfflineFlow('como tomar signos vitales manualmente')
                as QueryAwareDeterministicFlow?;
        expect(manualFlow, isNotNull);
        final step2 = await manualFlow!.startWithQuery(
          'como tomar signos vitales manualmente',
          ctx,
        );
        expect(step2.isTerminal, isTrue);
        expect(step2.prompt.toLowerCase(), contains('15 seconds'));
      },
    );
  });
}
