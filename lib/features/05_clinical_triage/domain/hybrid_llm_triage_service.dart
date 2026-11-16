import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../01_general_health/domain/scientific_criteria_engine.dart';
import '../../01_general_health/models/vitals_record.dart';
import '../models/triage_decision.dart';
import 'apollo_triage_engine.dart';

/// Backend de inferencia clínica configurable según conectividad y hardware disponible.
enum AiInferenceBackend {
  offlineDeterministic('Motor Determinista Offline (ADA + APOLO)'),
  localSlm('SLM Local / Llama Edge Embebido'),
  cloudLlm('LLM Remoto / Enlace Tierra');

  final String label;
  const AiInferenceBackend(this.label);

  static AiInferenceBackend fromString(String raw) {
    switch (raw.trim().toLowerCase()) {
      case 'local_slm':
      case 'localslm':
      case 'slm':
      case 'local':
        return AiInferenceBackend.localSlm;
      case 'cloud_llm':
      case 'cloudllm':
      case 'cloud':
        return AiInferenceBackend.cloudLlm;
      default:
        return AiInferenceBackend.offlineDeterministic;
    }
  }
}

/// Configuración de inferencia híbrida con degradación automática segura a Offline.
class HybridAiConfig {
  final AiInferenceBackend backend;
  final String endpointUrl;
  final String modelName;
  final int timeoutSeconds;
  final bool allowFallbackToOffline;

  const HybridAiConfig({
    this.backend = AiInferenceBackend.offlineDeterministic,
    this.endpointUrl = '',
    this.modelName = 'astramed-apolo-local',
    this.timeoutSeconds = 12,
    this.allowFallbackToOffline = true,
  });

  HybridAiConfig copyWith({
    AiInferenceBackend? backend,
    String? endpointUrl,
    String? modelName,
    int? timeoutSeconds,
    bool? allowFallbackToOffline,
  }) {
    return HybridAiConfig(
      backend: backend ?? this.backend,
      endpointUrl: endpointUrl ?? this.endpointUrl,
      modelName: modelName ?? this.modelName,
      timeoutSeconds: timeoutSeconds ?? this.timeoutSeconds,
      allowFallbackToOffline:
          allowFallbackToOffline ?? this.allowFallbackToOffline,
    );
  }
}

/// Respuesta trazable del servicio híbrido ADA + APOLO + LLM.
class HybridTriageResponse {
  final ApolloChatMessage message;
  final AiInferenceBackend effectiveBackend;
  final bool usedOfflineFallback;
  final String diagnosticReason;
  final PassiveDimensionEvaluation passiveEvaluation;

  const HybridTriageResponse({
    required this.message,
    required this.effectiveBackend,
    required this.usedOfflineFallback,
    required this.diagnosticReason,
    required this.passiveEvaluation,
  });

  Map<String, dynamic> toJson() => {
        'effective_backend': effectiveBackend.name,
        'used_offline_fallback': usedOfflineFallback,
        'diagnostic_reason': diagnosticReason,
        'message': message.toJson(),
        'passive_evaluation': passiveEvaluation.toJson(),
      };
}

/// Servicio híbrido Offline-First que siempre calcula primero el árbol clínico
/// determinista ADA+APOLO (garantizando seguridad clínica y preservación de
/// prioridad Roja/Amarilla) y opcionalmente consulta un SLM/LLM configurado.
class HybridLlmTriageService {
  final ApolloTriageEngine apolloEngine;
  final ScientificCriteriaEngine criteriaEngine;
  final http.Client httpClient;

  const HybridLlmTriageService({
    this.apolloEngine = const ApolloTriageEngine(),
    this.criteriaEngine = const ScientificCriteriaEngine(),
    required this.httpClient,
  });

  Future<HybridTriageResponse> evaluate({
    required String query,
    required VitalsRecord vitals,
    required HybridAiConfig config,
    double sleepHours = 7.5,
    ActivityContext activityContext = ActivityContext.rest,
    bool inMicrogravity = true,
    double signalQualityPercent = 97.0,
    double muscleStrengthRetentionPercent = 92.0,
  }) async {
    final passiveEval = criteriaEngine.evaluateAllPassiveDimensions(
      vitals: vitals,
      sleepHours: sleepHours,
      context: activityContext,
      inMicrogravity: inMicrogravity,
      signalQualityPercent: signalQualityPercent,
      muscleStrengthRetentionPercent: muscleStrengthRetentionPercent,
    );

    final deterministicMsg = apolloEngine.processQuery(
      query: query,
      vitals: vitals,
      sleepHours: sleepHours,
      activityContext: activityContext,
      inMicrogravity: inMicrogravity,
      signalQualityPercent: signalQualityPercent,
      muscleStrengthRetentionPercent: muscleStrengthRetentionPercent,
    );

    if (config.backend == AiInferenceBackend.offlineDeterministic ||
        config.endpointUrl.trim().isEmpty) {
      return HybridTriageResponse(
        message: deterministicMsg,
        effectiveBackend: AiInferenceBackend.offlineDeterministic,
        usedOfflineFallback: false,
        diagnosticReason: config.backend == AiInferenceBackend.offlineDeterministic
            ? 'Ejecución offline determinista ADA+APOLO completada.'
            : 'Endpoint remoto/SLM vacío; ejecutado motor determinista ADA+APOLO offline.',
        passiveEvaluation: passiveEval,
      );
    }

    try {
      final uri = Uri.parse(config.endpointUrl.trim());
      final payload = <String, dynamic>{
        'model': config.modelName,
        'query': query,
        'deterministic_triage': deterministicMsg.toJson(),
        'passive_evaluation': passiveEval.toJson(),
      };

      final response = await httpClient
          .post(
            uri,
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(Duration(seconds: config.timeoutSeconds));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw StateError('HTTP ${response.statusCode}');
      }

      final decoded = jsonDecode(response.body);
      final String? llmText = _extractResponseText(decoded);
      if (llmText == null || llmText.trim().isEmpty) {
        throw const FormatException('Respuesta LLM vacía');
      }

      // Guardrail clínico: la narrativa del LLM enriquece la explicación pero
      // NUNCA rebaja la prioridad clínica determinista ADA+APOLO ni elimina suministros.
      final guardedText = StringBuffer()
        ..writeln(llmText.trim())
        ..writeln('')
        ..writeln(
          '[Verificación ADA+APOLO | Prioridad ${deterministicMsg.priority?.name.toUpperCase() ?? "GREEN"} | Regla ${deterministicMsg.triggeredRule}]',
        );

      final enriched = ApolloChatMessage(
        id: deterministicMsg.id,
        isFromUser: false,
        text: guardedText.toString().trim(),
        timestamp: deterministicMsg.timestamp,
        priority: deterministicMsg.priority,
        triageResult: deterministicMsg.triageResult,
        referencedMetrics: deterministicMsg.referencedMetrics,
        recommendedSupplies: deterministicMsg.recommendedSupplies,
        sources: [
          ...deterministicMsg.sources,
          'LLM (${config.backend.name}:${config.modelName})',
        ],
        triggeredRule: deterministicMsg.triggeredRule,
      );

      return HybridTriageResponse(
        message: enriched,
        effectiveBackend: config.backend,
        usedOfflineFallback: false,
        diagnosticReason: 'Síntesis LLM verificada sobre guardrail ADA+APOLO.',
        passiveEvaluation: passiveEval,
      );
    } catch (err) {
      if (!config.allowFallbackToOffline) {
        rethrow;
      }
      return HybridTriageResponse(
        message: deterministicMsg,
        effectiveBackend: AiInferenceBackend.offlineDeterministic,
        usedOfflineFallback: true,
        diagnosticReason:
            'Degradación segura a ADA+APOLO offline tras fallo en ${config.backend.name}: $err',
        passiveEvaluation: passiveEval,
      );
    }
  }

  String? _extractResponseText(dynamic decoded) {
    if (decoded is Map<String, dynamic>) {
      final direct = decoded['response'] ?? decoded['text'] ?? decoded['reply'] ?? decoded['content'];
      if (direct is String && direct.trim().isNotEmpty) return direct;

      final choices = decoded['choices'];
      if (choices is List && choices.isNotEmpty && choices.first is Map) {
        final first = choices.first as Map;
        final msg = first['message'];
        if (msg is Map && msg['content'] is String) {
          return msg['content'] as String;
        }
        if (first['text'] is String) {
          return first['text'] as String;
        }
      }
      final message = decoded['message'];
      if (message is Map && message['content'] is String) {
        return message['content'] as String;
      }
    }
    return null;
  }

  TriagePriority maxPriority(TriagePriority a, TriagePriority b) {
    if (a == TriagePriority.red || b == TriagePriority.red) return TriagePriority.red;
    if (a == TriagePriority.yellow || b == TriagePriority.yellow) return TriagePriority.yellow;
    return TriagePriority.green;
  }
}
