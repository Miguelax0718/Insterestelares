import 'dart:convert';

import 'package:astramed/features/01_general_health/domain/telemetry_view_contracts.dart';
import 'package:astramed/features/05_clinical_triage/domain/hybrid_llm_triage_service.dart';
import 'package:astramed/features/05_clinical_triage/models/triage_decision.dart';
import 'package:astramed/features/crew/data/mock_crew_data.dart';
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
}
