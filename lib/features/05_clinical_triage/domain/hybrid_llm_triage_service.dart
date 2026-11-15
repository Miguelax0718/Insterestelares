import 'dart:convert';
import 'package:http/http.dart' as http;

import 'package:astramed/features/01_general_health/domain/telemetry_view_contracts.dart';
import 'package:astramed/features/05_clinical_triage/domain/apollo_triage_engine.dart';
import 'package:astramed/features/crew/models/astronaut_profile.dart';

/// Backend de inferencia utilizado para asistir al triaje clínico.
enum AiInferenceBackend {
  localWebAi('IA Local (Web/Edge)'),
  cloudFallback('IA Cloud (Fallback)'),
  deterministicAdaOffline('Motor ADA 100% Offline');

  final String label;
  const AiInferenceBackend(this.label);
}

/// Configuración de inferencia híbrida (Local-First con fallback Cloud y ADA Offline).
class HybridAiConfig {
  final bool preferLocalModel;
  final String localEndpoint;
  final String localModelName;
  final String cloudEndpoint;
  final String cloudApiKey;
  final Duration timeout;

  const HybridAiConfig({
    this.preferLocalModel = true,
    this.localEndpoint = 'http://localhost:11434/api/generate',
    this.localModelName = 'llama3.2:1b',
    this.cloudEndpoint =
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent',
    this.cloudApiKey = '',
    this.timeout = const Duration(seconds: 4),
  });

  HybridAiConfig copyWith({
    bool? preferLocalModel,
    String? localEndpoint,
    String? localModelName,
    String? cloudEndpoint,
    String? cloudApiKey,
    Duration? timeout,
  }) {
    return HybridAiConfig(
      preferLocalModel: preferLocalModel ?? this.preferLocalModel,
      localEndpoint: localEndpoint ?? this.localEndpoint,
      localModelName: localModelName ?? this.localModelName,
      cloudEndpoint: cloudEndpoint ?? this.cloudEndpoint,
      cloudApiKey: cloudApiKey ?? this.cloudApiKey,
      timeout: timeout ?? this.timeout,
    );
  }
}

/// Servicio híbrido que combina el árbol determinista ADA/APOLO como guardrail
/// clínico con un LLM local (WebLLM/Ollama) o un modelo en la nube como respaldo.
class HybridLlmTriageService {
  final http.Client _client;

  HybridLlmTriageService({http.Client? client})
      : _client = client ?? http.Client();

  Future<ApolloChatMessage> evaluateQuery({
    required String query,
    required AstronautProfile astronaut,
    required SpaceOperationalEnvironment environment,
    required HybridAiConfig config,
  }) async {
    // Paso 1: Guardrail clínico determinista ADA + APOLO (nunca delegado al LLM).
    final adaBase = ApolloTriageEngine.processQuery(
      query: query,
      astronaut: astronaut,
      environment: environment,
    );

    final systemPrompt = _buildClinicalPrompt(
      query: query,
      astronaut: astronaut,
      environment: environment,
      adaBase: adaBase,
    );

    // Paso 2: Prioridad a modelo local (Ollama / WebLLM bridge).
    if (config.preferLocalModel && config.localEndpoint.trim().isNotEmpty) {
      final localReply = await _tryLocalModel(
        prompt: systemPrompt,
        config: config,
      );
      if (localReply != null && localReply.isNotEmpty) {
        return adaBase.copyWith(
          text: localReply,
          inferenceSource: 'IA Local (Web/Ollama) + Guardrail ADA',
        );
      }
    }

    // Paso 3: Fallback a modelo en la nube si hay API key configurada.
    if (config.cloudApiKey.trim().isNotEmpty &&
        config.cloudEndpoint.trim().isNotEmpty) {
      final cloudReply = await _tryCloudModel(
        prompt: systemPrompt,
        config: config,
      );
      if (cloudReply != null && cloudReply.isNotEmpty) {
        return adaBase.copyWith(
          text: cloudReply,
          inferenceSource: 'IA Cloud (Fallback) + Guardrail ADA',
        );
      }
    }

    // Paso 4: Fallback determinista 100% offline para espacio profundo.
    return adaBase.copyWith(
      inferenceSource: 'Motor Clínico ADA Determinista (100% Offline)',
    );
  }

  String _buildClinicalPrompt({
    required String query,
    required AstronautProfile astronaut,
    required SpaceOperationalEnvironment environment,
    required ApolloChatMessage adaBase,
  }) {
    final v = astronaut.vitals;
    return 'Eres APOLO, asistente médico espacial basado en protocolos ADA y NASA-STD-3001.\n'
        'Tripulante: ${astronaut.name} (${astronaut.callsign}) | Entorno: ${environment.label}.\n'
        'Telemetría: FC ${v.heartRate.toInt()} lpm, FR ${v.respiratoryRate.toStringAsFixed(1)} rpm, '
        'SpO2 ${v.spO2.toInt()}%, TA ${v.systolicBP.toInt()}/${v.diastolicBP.toInt()} mmHg, '
        'Temp ${v.bodyTemp.toStringAsFixed(1)} °C, CO2 ${v.localCo2MmHg.toStringAsFixed(1)} mmHg.\n'
        'Guardrail ADA determinado: nivel=${adaBase.triageLevel?.name ?? "green"}, '
        'hardware=${adaBase.recommendedHardware ?? "N/A"}.\n'
        'Consulta del astronauta: "$query"\n'
        'Responde en español claro, empático y conciso (máximo 90 palabras), respetando el nivel de triaje fijado y sin diagnosticar enfermedades.';
  }

  Future<String?> _tryLocalModel({
    required String prompt,
    required HybridAiConfig config,
  }) async {
    try {
      final uri = Uri.parse(config.localEndpoint.trim());
      final response = await _client
          .post(
            uri,
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({
              'model': config.localModelName,
              'prompt': prompt,
              'stream': false,
            }),
          )
          .timeout(config.timeout);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          final text = decoded['response']?.toString() ??
              decoded['text']?.toString() ??
              _extractOpenAiText(decoded);
          return text?.trim();
        }
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  Future<String?> _tryCloudModel({
    required String prompt,
    required HybridAiConfig config,
  }) async {
    try {
      final rawUrl = config.cloudEndpoint.trim();
      final isGemini = rawUrl.contains('generativelanguage.googleapis.com');
      final uri = isGemini
          ? Uri.parse(
              rawUrl.contains('key=')
                  ? rawUrl
                  : '$rawUrl?key=${config.cloudApiKey.trim()}',
            )
          : Uri.parse(rawUrl);

      final headers = <String, String>{'Content-Type': 'application/json'};
      if (!isGemini) {
        headers['Authorization'] = 'Bearer ${config.cloudApiKey.trim()}';
      }

      final body = isGemini
          ? jsonEncode({
              'contents': [
                {
                  'parts': [
                    {'text': prompt},
                  ],
                },
              ],
            })
          : jsonEncode({
              'model': 'gpt-4o-mini',
              'messages': [
                {'role': 'user', 'content': prompt},
              ],
            });

      final response = await _client
          .post(uri, headers: headers, body: body)
          .timeout(config.timeout);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          final geminiText = _extractGeminiText(decoded);
          if (geminiText != null && geminiText.isNotEmpty) {
            return geminiText.trim();
          }
          return _extractOpenAiText(decoded)?.trim();
        }
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  String? _extractGeminiText(Map<String, dynamic> decoded) {
    final candidates = decoded['candidates'];
    if (candidates is List && candidates.isNotEmpty) {
      final first = candidates.first;
      if (first is Map<String, dynamic>) {
        final content = first['content'];
        if (content is Map<String, dynamic>) {
          final parts = content['parts'];
          if (parts is List && parts.isNotEmpty) {
            final part = parts.first;
            if (part is Map<String, dynamic>) {
              return part['text']?.toString();
            }
          }
        }
      }
    }
    return null;
  }

  String? _extractOpenAiText(Map<String, dynamic> decoded) {
    final choices = decoded['choices'];
    if (choices is List && choices.isNotEmpty) {
      final first = choices.first;
      if (first is Map<String, dynamic>) {
        final message = first['message'];
        if (message is Map<String, dynamic>) {
          return message['content']?.toString();
        }
      }
    }
    return null;
  }
}
