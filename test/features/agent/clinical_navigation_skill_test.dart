import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:astramed/features/agent/application/core_tools.dart';
import 'package:astramed/features/agent/domain/agent_contracts.dart';
import 'package:astramed/features/agent/providers/agent_providers.dart';

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
      'open_clinical_terminal sets clinicalNavigationRequestProvider and resolves status_report',
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
        expect(req1, isNotNull);
        expect(req1!.tabIndex, 1);
        expect(req1.openManualVitals, isFalse);

        // Must pass StatusReportViewModel.fromProps validation without error.
        final registry = container.read(componentRegistryProvider);
        final statusEvent = res1.uiEvents.first as ShowComponentEvent;
        final vm = registry.resolve(statusEvent.id, statusEvent.props);
        expect(vm.componentId, ComponentIds.statusReport);

        final res2 = await openTool.call(const {
          'module': 'general_health',
          'open_manual_vitals': true,
        }, ctx);
        expect(res2.ok, isTrue);
        final req2 = container.read(clinicalNavigationRequestProvider);
        expect(req2!.tabIndex, 0);
        expect(req2.openManualVitals, isTrue);
        expect(req2.nonce, greaterThan(req1.nonce));
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
        expect(navReq, isNotNull);
        expect(navReq!.tabIndex, 0);

        final manualFlow =
            skills.findOfflineFlow('como tomar signos vitales manualmente')
                as QueryAwareDeterministicFlow?;
        expect(manualFlow, isNotNull);
        final step2 = await manualFlow!.startWithQuery(
          'como tomar signos vitales manualmente',
          ctx,
        );
        expect(step2.isTerminal, isTrue);
        expect(step2.prompt.toLowerCase(), contains('15 segundos'));
      },
    );
  });
}
