import 'dart:convert';

import 'package:astramed/features/01_general_health/domain/telemetry_view_contracts.dart';
import 'package:astramed/features/01_general_health/models/vitals_record.dart';
import 'package:astramed/features/05_clinical_triage/domain/hybrid_llm_triage_service.dart';
import 'package:astramed/features/05_clinical_triage/models/triage_decision.dart';
import 'package:astramed/features/agent/domain/agent_contracts.dart';
import 'package:astramed/features/agent/providers/agent_providers.dart';
import 'package:astramed/features/crew/data/mock_crew_data.dart';
import 'package:astramed/features/crew/presentation/providers/crew_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  final astronaut = MockCrewData.getInitialCrew().first;

  group('HybridLlmTriageService', () {
    test('Prioriza modelo local Web/Ollama y conserva nivel ADA determinista',
        () async {
      final client = MockClient((request) async {
        expect(request.url.toString(), 'http://localhost:11434/api/generate');
        return http.Response(
          jsonEncode({'response': 'Respuesta generada localmente con guía ADA.'}),
          200,
        );
      });

      final service = HybridLlmTriageService(client: client);
      final reply = await service.evaluateQuery(
        query: 'Siento falta de aire por bolsa de CO2',
        astronaut: astronaut,
        environment: SpaceOperationalEnvironment.spaceStation,
        config: const HybridAiConfig(
          preferLocalModel: true,
          cloudApiKey: 'test-cloud-key',
        ),
      );

      expect(reply.inferenceSource, 'IA Local (Web/Ollama) + Guardrail ADA');
      expect(reply.text, 'Respuesta generada localmente con guía ADA.');
      expect(
        reply.triageLevel == TriagePriority.yellow ||
            reply.triageLevel == TriagePriority.red,
        isTrue,
      );
      expect(reply.actionChecklist, isNotEmpty);
    });

    test('Hace fallback al modelo en la nube si el modelo local falla',
        () async {
      final client = MockClient((request) async {
        if (request.url.host == 'localhost') {
          return http.Response('offline', 503);
        }
        return http.Response(
          jsonEncode({
            'candidates': [
              {
                'content': {
                  'parts': [
                    {'text': 'Respuesta asistida desde modelo Cloud.'},
                  ],
                },
              },
            ],
          }),
          200,
        );
      });

      final service = HybridLlmTriageService(client: client);
      final reply = await service.evaluateQuery(
        query: 'Tengo dolor de cabeza y visión borrosa',
        astronaut: astronaut,
        environment: SpaceOperationalEnvironment.spaceStation,
        config: const HybridAiConfig(
          preferLocalModel: true,
          cloudApiKey: 'fake-gemini-key',
        ),
      );

      expect(reply.inferenceSource, 'IA Cloud (Fallback) + Guardrail ADA');
      expect(reply.text, 'Respuesta asistida desde modelo Cloud.');
      expect(reply.recommendedHardware, isNotNull);
    });

    test('Opera 100% offline con motor ADA si local y nube fallan', () async {
      final client = MockClient((_) async => http.Response('unreachable', 503));

      final service = HybridLlmTriageService(client: client);
      final reply = await service.evaluateQuery(
        query: 'Sufrí un golpe fuerte contra el mamparo',
        astronaut: astronaut,
        environment: SpaceOperationalEnvironment.spaceStation,
        config: const HybridAiConfig(
          preferLocalModel: true,
          cloudApiKey: '',
        ),
      );

      expect(
        reply.inferenceSource,
        'Motor Clínico ADA Determinista (100% Offline)',
      );
      expect(reply.triageLevel, TriagePriority.red);
      expect(reply.followUpOptions, isNotEmpty);
    });
  });

  group('Integración Telemetría Científica & Triaje ADA con Agent Bot', () {
    test(
      'Registra evaluate_scientific_vitals_criteria y run_ada_apollo_triage en skillRegistryProvider y los ejecuta con ProviderContainer',
      () async {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        final registry = container.read(skillRegistryProvider);
        final skill = registry.byId('scientific_telemetry_criteria');
        expect(skill, isNotNull);
        expect(
          skill!.tools.map((t) => t.name),
          containsAll([
            'evaluate_scientific_vitals_criteria',
            'run_ada_apollo_triage',
          ]),
        );

        final crew = container.read(crewMembersProvider);
        final criticalCommander = crew.first.copyWith(
          vitals: VitalsRecord(
            timestamp: DateTime.now(),
            astronautId: crew.first.id,
            heartRate: 118,
            systolicBP: 145,
            diastolicBP: 92,
            spO2: 92,
            bodyTemp: 37.9,
            bloodGlucose: 65,
            respiratoryRate: 24,
            capillaryRefillSeconds: 3.3,
            activityState: 'resting',
            localCo2MmHg: 4.5,
          ),
        );
        container.read(crewMembersProvider.notifier).state = [
          criticalCommander,
          ...crew.skip(1),
        ];

        final ctx = ToolContext(
          astronautId: criticalCommander.id,
          read: <T>(provider) =>
              container.read(provider as ProviderListenable<T>),
          ui: _NoopUiSink(),
          confirm: container.read(agentConfirmationGateProvider),
          audit: container.read(agentAuditLogProvider),
          memory: container.read(agentMemoryStoreProvider),
          flags: container.read(agentFlagsStoreProvider),
          medication: container.read(medicationSafetyProvider),
        );

        final evalTool = skill.tools.firstWhere(
          (t) => t.name == 'evaluate_scientific_vitals_criteria',
        );
        final evalRes = await evalTool.call({'activity_context': 'rest'}, ctx);
        expect(evalRes.ok, isTrue);
        expect(evalRes.data['overall_severity'], 'critical');
        expect((evalRes.data['evaluations'] as List).length, 9);
        final evalEvents =
            evalRes.uiEvents.whereType<ShowComponentEvent>().map((e) => e.id);
        expect(
          evalEvents,
          containsAll([ComponentIds.vitalsCard, ComponentIds.alertBanner]),
        );

        final triageTool = skill.tools.firstWhere(
          (t) => t.name == 'run_ada_apollo_triage',
        );
        final triageRes = await triageTool.call({
          'query': 'Siento asfixia y bolsa de CO2 en estación',
          'environment': 'spaceStation',
        }, ctx);
        expect(triageRes.ok, isTrue);
        expect(triageRes.data['priority'], 'red');
        expect(
          triageRes.uiEvents.whereType<ShowComponentEvent>().single.id,
          ComponentIds.alertBanner,
        );

        final offlineStep = await skill.offlineFlow!.start(ctx);
        expect(offlineStep.options, contains('Finalizar'));
        expect(offlineStep.uiEvents, isNotEmpty);
      },
    );
  });
}

class _NoopUiSink implements AgentUiSink {
  @override
  void emit(AgentComponentEvent event) {}

  @override
  void submit(String componentId, Map<String, dynamic> result) {}
}
