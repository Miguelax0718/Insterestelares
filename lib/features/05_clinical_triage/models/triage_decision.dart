enum TriagePriority {
  green,   // Leve / Autotratamiento rutinario
  yellow,  // Moderado / Requiere medicación o monitoreo
  red,     // Emergencia Crítica / Intervención inmediata
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
