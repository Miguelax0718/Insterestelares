enum TriagePriority {
  green, // Leve / Autotratamiento rutinario
  yellow, // Moderado / Requiere medicación o monitoreo
  red, // Emergencia Crítica / Intervención inmediata
}

class TriageResult {
  final String conditionName;
  final TriagePriority priority;
  final List<String> immediateActions;
  final List<String> requiredSupplies;
  final String? guideAssetPath; // Path a manual en Markdown local
  final String algorithm;
  final String criterionReference;

  const TriageResult({
    required this.conditionName,
    required this.priority,
    required this.immediateActions,
    required this.requiredSupplies,
    this.guideAssetPath,
    this.algorithm = 'DeterministicClinicalDecisionTree v1.0',
    this.criterionReference = 'NASA-STD-3001 Space Medicine Emergency Protocol',
  });
}

TriagePriority parseTriagePriority(String? raw) {
  switch (raw?.toLowerCase()) {
    case 'red':
      return TriagePriority.red;
    case 'yellow':
      return TriagePriority.yellow;
    case 'green':
    default:
      return TriagePriority.green;
  }
}

/// Paso individual de un procedimiento clínico en cabina o microgravedad.
class ProcedureStep {
  final int step;
  final String title;
  final String action;
  final String clinicalTip;
  final int durationSeconds;

  const ProcedureStep({
    required this.step,
    required this.title,
    required this.action,
    required this.clinicalTip,
    required this.durationSeconds,
  });

  factory ProcedureStep.fromJson(Map<String, dynamic> json) {
    return ProcedureStep(
      step: (json['step'] as num?)?.toInt() ?? 1,
      title: json['title']?.toString() ?? '',
      action: json['action']?.toString() ?? '',
      clinicalTip: json['clinicalTip']?.toString() ?? '',
      durationSeconds: (json['durationSeconds'] as num?)?.toInt() ?? 30,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'step': step,
      'title': title,
      'action': action,
      'clinicalTip': clinicalTip,
      'durationSeconds': durationSeconds,
    };
  }
}

/// Insumo o medicamento del botiquín espacial requerido por un procedimiento.
class ProcedureSupply {
  final String itemId;
  final String name;
  final String usage;
  final String location;

  const ProcedureSupply({
    required this.itemId,
    required this.name,
    required this.usage,
    required this.location,
  });

  factory ProcedureSupply.fromJson(Map<String, dynamic> json) {
    return ProcedureSupply(
      itemId: json['itemId']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      usage: json['usage']?.toString() ?? '',
      location: json['location']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'itemId': itemId,
      'name': name,
      'usage': usage,
      'location': location,
    };
  }
}

/// Protocolo médico completo de emergencia o soporte clínico offline.
class MedicalProcedure {
  final String id;
  final String code;
  final String title;
  final String category;
  final TriagePriority priority;
  final String nasaHazard;
  final String summary;
  final List<String> whenToActivate;
  final Map<String, dynamic> vitalTriggers;
  final List<ProcedureStep> steps;
  final List<ProcedureSupply> requiredSupplies;
  final List<String> warnings;
  final String criterionReference;

  const MedicalProcedure({
    required this.id,
    required this.code,
    required this.title,
    required this.category,
    required this.priority,
    required this.nasaHazard,
    required this.summary,
    required this.whenToActivate,
    this.vitalTriggers = const {},
    required this.steps,
    required this.requiredSupplies,
    required this.warnings,
    required this.criterionReference,
  });

  factory MedicalProcedure.fromJson(Map<String, dynamic> json) {
    return MedicalProcedure(
      id: json['id']?.toString() ?? '',
      code: json['code']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      category: json['category']?.toString() ?? 'general',
      priority: parseTriagePriority(json['priority']?.toString()),
      nasaHazard: json['nasaHazard']?.toString() ?? '',
      summary: json['summary']?.toString() ?? '',
      whenToActivate: (json['whenToActivate'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      vitalTriggers: json['vitalTriggers'] is Map
          ? Map<String, dynamic>.from(json['vitalTriggers'] as Map)
          : const {},
      steps: (json['steps'] as List?)
              ?.whereType<Map>()
              .map((e) => ProcedureStep.fromJson(Map<String, dynamic>.from(e)))
              .toList() ??
          const [],
      requiredSupplies: (json['requiredSupplies'] as List?)
              ?.whereType<Map>()
              .map(
                (e) => ProcedureSupply.fromJson(Map<String, dynamic>.from(e)),
              )
              .toList() ??
          const [],
      warnings: (json['warnings'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      criterionReference: json['criterionReference']?.toString() ??
          'NASA-STD-3001 Space Medicine Emergency Protocol',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'code': code,
      'title': title,
      'category': category,
      'priority': priority.name,
      'nasaHazard': nasaHazard,
      'summary': summary,
      'whenToActivate': whenToActivate,
      'vitalTriggers': vitalTriggers,
      'steps': steps.map((s) => s.toJson()).toList(),
      'requiredSupplies': requiredSupplies.map((s) => s.toJson()).toList(),
      'warnings': warnings,
      'criterionReference': criterionReference,
    };
  }
}

/// Escenario rápido de triage por situación clínica o síntoma.
class ClinicalScenario {
  final String id;
  final String label;
  final String symptomSummary;
  final TriagePriority priority;
  final String recommendedProcedureId;
  final List<String> first60Seconds;
  final List<String> verificationQuestions;
  final List<String> emergencySupplies;

  const ClinicalScenario({
    required this.id,
    required this.label,
    required this.symptomSummary,
    required this.priority,
    required this.recommendedProcedureId,
    required this.first60Seconds,
    required this.verificationQuestions,
    required this.emergencySupplies,
  });

  factory ClinicalScenario.fromJson(Map<String, dynamic> json) {
    return ClinicalScenario(
      id: json['id']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      symptomSummary: json['symptomSummary']?.toString() ?? '',
      priority: parseTriagePriority(json['priority']?.toString()),
      recommendedProcedureId:
          json['recommendedProcedureId']?.toString() ?? '',
      first60Seconds: (json['first60Seconds'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      verificationQuestions: (json['verificationQuestions'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      emergencySupplies: (json['emergencySupplies'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'label': label,
      'symptomSummary': symptomSummary,
      'priority': priority.name,
      'recommendedProcedureId': recommendedProcedureId,
      'first60Seconds': first60Seconds,
      'verificationQuestions': verificationQuestions,
      'emergencySupplies': emergencySupplies,
    };
  }
}

/// Sugerencia clínica generada para un tripulante o situación específica.
class ProcedureSuggestion {
  final MedicalProcedure procedure;
  final String reason;
  final bool isUrgent;

  const ProcedureSuggestion({
    required this.procedure,
    required this.reason,
    required this.isUrgent,
  });
}
