import 'package:astramed/core/constants/medical_thresholds.dart';

/// Contexto de actividad en el que se adquirió la medición fisiológica.
enum ActivityContext {
  sleep('Sueño'),
  rest('Reposo'),
  physicalActivity('Actividad física'),
  unknown('Desconocido');

  final String label;
  const ActivityContext(this.label);
}

/// Nivel de procedencia del criterio aplicado.
enum CriterionLevel {
  generalScientific('Referencia científica general'),
  individualBaseline('Referencia individual (basal)'),
  operationalLimit('Límite médico u operativo');

  final String label;
  const CriterionLevel(this.label);
}

/// Clasificación visual y funcional de la evaluación, diferenciando
/// ausencia de datos, observaciones descriptivas, avisos informativos y alertas.
enum EvaluationSeverity {
  noData('Sin datos disponibles'),
  descriptive('Registro descriptivo'),
  informativeNotice('Aviso informativo'),
  operationalAlert('Atención operativa');

  final String label;
  const EvaluationSeverity(this.label);
}

/// Definición versionada y trazable de un criterio científico u operativo.
class ScientificCriterion {
  final String id;
  final String variable;
  final String unit;
  final CriterionLevel level;
  final ActivityContext context;
  final double? minValue;
  final double? maxValue;
  final String population;
  final String source;
  final String version;
  final String limitations;

  const ScientificCriterion({
    required this.id,
    required this.variable,
    required this.unit,
    required this.level,
    required this.context,
    this.minValue,
    this.maxValue,
    required this.population,
    required this.source,
    required this.version,
    required this.limitations,
  });
}

/// Resultado de evaluación fisiológica sin atribuciones diagnósticas.
class EvaluationResult {
  final String variable;
  final double? value;
  final String unit;
  final ActivityContext context;
  final EvaluationSeverity severity;
  final String summary;
  final ScientificCriterion? appliedCriterion;
  final double? individualBaselineDelta;

  const EvaluationResult({
    required this.variable,
    required this.value,
    required this.unit,
    required this.context,
    required this.severity,
    required this.summary,
    this.appliedCriterion,
    this.individualBaselineDelta,
  });

  bool get hasData => severity != EvaluationSeverity.noData && value != null;
}

/// Motor determinista de criterios científicos para monitoreo espacial.
///
/// Prioriza referencias individuales cuando existen, diferencia contextos
/// fisiológicos y evita generar diagnósticos o alertas sin respaldo validado.
class ScientificCriteriaEngine {
  static const ScientificCriterion hrRestGeneralCriterion = ScientificCriterion(
    id: 'hr_rest_aha_general',
    variable: 'Frecuencia cardíaca',
    unit: 'lpm',
    level: CriterionLevel.generalScientific,
    context: ActivityContext.rest,
    minValue: MedicalThresholds.minHeartRate,
    maxValue: MedicalThresholds.maxHeartRate,
    population: 'Adultos sanos en entorno terrestre en reposo',
    source: 'AHA Target Heart Rates; Mendes Zambetta et al. (2024)',
    version: '1.0.0',
    limitations:
        'No aplicar en sueño ni ejercicio. Personas entrenadas pueden tener valores menores. '
        'En microgravedad se reporta un incremento promedio no uniforme de +3.44 lpm.',
  );

  static const ScientificCriterion rrRestGeneralCriterion = ScientificCriterion(
    id: 'rr_rest_general',
    variable: 'Frecuencia respiratoria',
    unit: 'rpm',
    level: CriterionLevel.generalScientific,
    context: ActivityContext.rest,
    minValue: MedicalThresholds.minRespiratoryRate,
    maxValue: MedicalThresholds.maxRespiratoryRate,
    population: 'Adultos sanos en reposo',
    source: 'Cleveland Clinic; Berry et al. (2012)',
    version: '1.0.0',
    limitations:
        'Referencia orientativa en reposo. No diagnosticar alteraciones con una única lectura.',
  );

  static const ScientificCriterion spo2GeneralCriterion = ScientificCriterion(
    id: 'spo2_terrestrial_general',
    variable: 'Saturación periférica de oxígeno (SpO₂)',
    unit: '%',
    level: CriterionLevel.generalScientific,
    context: ActivityContext.rest,
    minValue: MedicalThresholds.minSpO2,
    maxValue: 100.0,
    population: 'Adultos sanos en condiciones terrestres apropiadas',
    source: 'FDA Pulse Oximeters (2013); NHLBI (2023)',
    version: '1.0.0',
    limitations:
        'Referencia terrestre general; no es un límite universal de seguridad espacial.',
  );

  static const ScientificCriterion sleepDurationCriterion = ScientificCriterion(
    id: 'sleep_duration_nsf_aasm',
    variable: 'Duración del sueño',
    unit: 'h',
    level: CriterionLevel.generalScientific,
    context: ActivityContext.sleep,
    minValue: MedicalThresholds.minRecommendedSleepHours,
    maxValue: MedicalThresholds.maxRecommendedSleepHours,
    population: 'Adultos (por cada 24 horas)',
    source: 'Hirshkowitz et al. (2015, NSF); Watson et al. (2015, AASM/SRS)',
    version: '1.0.0',
    limitations:
        'La actigrafía no determina fases clínicas REM/NREM. Ajustar a protocolos de misión.',
  );

  static const ScientificCriterion muscleStrengthCriterion = ScientificCriterion(
    id: 'muscle_strength_nasa_std_3001',
    variable: 'Fuerza muscular conservada',
    unit: '%',
    level: CriterionLevel.operationalLimit,
    context: ActivityContext.physicalActivity,
    minValue: MedicalThresholds.minMuscleStrengthRetentionPercent,
    maxValue: null,
    population: 'Tripulación respecto a basal pre-misión equivalente',
    source: 'NASA-STD-3001 Vol. 1, V1 4024; NASA OCHMO-TB-031 (2023)',
    version: '1.0.0',
    limitations:
        'Solo aplicable a evaluaciones instrumentales con el mismo protocolo pre-misión. '
        'No constituye diagnóstico de atrofia muscular.',
  );

  static EvaluationResult evaluateHeartRate({
    required double? bpm,
    required ActivityContext context,
    double? individualBaselineBpm,
  }) {
    if (bpm == null || bpm <= 0) {
      return EvaluationResult(
        variable: 'Frecuencia cardíaca',
        value: null,
        unit: 'lpm',
        context: context,
        severity: EvaluationSeverity.noData,
        summary: 'Sin datos disponibles',
      );
    }

    final delta = individualBaselineBpm != null ? bpm - individualBaselineBpm : null;

    if (context != ActivityContext.rest) {
      final baselineNote = delta != null
          ? ' (${delta >= 0 ? '+' : ''}${delta.toStringAsFixed(1)} lpm vs. basal en ${context.label.toLowerCase()})'
          : '';
      return EvaluationResult(
        variable: 'Frecuencia cardíaca',
        value: bpm,
        unit: 'lpm',
        context: context,
        severity: EvaluationSeverity.descriptive,
        summary: 'Registro en ${context.label.toLowerCase()}: ${bpm.toStringAsFixed(0)} lpm$baselineNote. '
            'No se aplican intervalos de reposo en este contexto.',
        individualBaselineDelta: delta,
      );
    }

    if (individualBaselineBpm != null) {
      final baselineCriterion = ScientificCriterion(
        id: 'hr_rest_individual_baseline',
        variable: 'Frecuencia cardíaca',
        unit: 'lpm',
        level: CriterionLevel.individualBaseline,
        context: ActivityContext.rest,
        minValue: individualBaselineBpm,
        maxValue: individualBaselineBpm,
        population: 'Referencia basal individual pre-misión en reposo',
        source: 'Historial individual del astronauta; Mendes Zambetta et al. (2024)',
        version: '1.0.0',
        limitations:
            'Comparar únicamente en condiciones equivalentes de reposo.',
      );
      return EvaluationResult(
        variable: 'Frecuencia cardíaca',
        value: bpm,
        unit: 'lpm',
        context: context,
        severity: EvaluationSeverity.descriptive,
        summary:
            'Reposo: ${bpm.toStringAsFixed(0)} lpm (${delta! >= 0 ? '+' : ''}${delta.toStringAsFixed(1)} lpm vs. basal individual).',
        appliedCriterion: baselineCriterion,
        individualBaselineDelta: delta,
      );
    }

    final withinGeneral = bpm >= hrRestGeneralCriterion.minValue! &&
        bpm <= hrRestGeneralCriterion.maxValue!;
    return EvaluationResult(
      variable: 'Frecuencia cardíaca',
      value: bpm,
      unit: 'lpm',
      context: context,
      severity: withinGeneral
          ? EvaluationSeverity.descriptive
          : EvaluationSeverity.informativeNotice,
      summary: withinGeneral
          ? 'Dentro de referencia terrestre general en reposo (60–100 lpm, AHA).'
          : 'Fuera de referencia terrestre general en reposo (60–100 lpm, AHA). Evaluar con basal individual y contexto.',
      appliedCriterion: hrRestGeneralCriterion,
    );
  }

  static EvaluationResult evaluateRespiratoryRate({
    required double? rpm,
    required ActivityContext context,
    double? individualBaselineRpm,
  }) {
    if (rpm == null || rpm <= 0) {
      return EvaluationResult(
        variable: 'Frecuencia respiratoria',
        value: null,
        unit: 'rpm',
        context: context,
        severity: EvaluationSeverity.noData,
        summary: 'Sin datos disponibles',
      );
    }

    final delta = individualBaselineRpm != null ? rpm - individualBaselineRpm : null;

    if (context != ActivityContext.rest) {
      return EvaluationResult(
        variable: 'Frecuencia respiratoria',
        value: rpm,
        unit: 'rpm',
        context: context,
        severity: EvaluationSeverity.descriptive,
        summary: 'Registro en ${context.label.toLowerCase()}: ${rpm.toStringAsFixed(1)} rpm. '
            'No se aplican intervalos de reposo automáticamente.',
        individualBaselineDelta: delta,
      );
    }

    final withinGeneral = rpm >= rrRestGeneralCriterion.minValue! &&
        rpm <= rrRestGeneralCriterion.maxValue!;
    return EvaluationResult(
      variable: 'Frecuencia respiratoria',
      value: rpm,
      unit: 'rpm',
      context: context,
      severity: withinGeneral
          ? EvaluationSeverity.descriptive
          : EvaluationSeverity.informativeNotice,
      summary: withinGeneral
          ? 'Dentro de referencia orientativa en reposo (12–20 rpm).'
          : 'Fuera de referencia orientativa en reposo (12–20 rpm). No diagnosticar por lectura única.',
      appliedCriterion: rrRestGeneralCriterion,
      individualBaselineDelta: delta,
    );
  }

  static EvaluationResult evaluateSpO2({
    required double? percent,
    required ActivityContext context,
    double? individualBaselinePercent,
    bool isSignalValid = true,
  }) {
    if (percent == null || percent <= 0 || !isSignalValid) {
      return EvaluationResult(
        variable: 'SpO₂',
        value: null,
        unit: '%',
        context: context,
        severity: EvaluationSeverity.noData,
        summary: isSignalValid
            ? 'Sin datos disponibles'
            : 'Lectura descartada por baja calidad de señal',
      );
    }

    final delta =
        individualBaselinePercent != null ? percent - individualBaselinePercent : null;
    final withinGeneral = percent >= spo2GeneralCriterion.minValue! &&
        percent <= spo2GeneralCriterion.maxValue!;

    return EvaluationResult(
      variable: 'SpO₂',
      value: percent,
      unit: '%',
      context: context,
      severity: withinGeneral
          ? EvaluationSeverity.descriptive
          : EvaluationSeverity.informativeNotice,
      summary: withinGeneral
          ? 'Dentro de referencia terrestre general (95–100 %, FDA).'
          : 'Por debajo de referencia terrestre general (<95 %). Interpretar según señal, ambiente e historial individual.',
      appliedCriterion: spo2GeneralCriterion,
      individualBaselineDelta: delta,
    );
  }

  static EvaluationResult evaluateSleepDuration({
    required double? hours,
    required bool isSubjectiveManual,
  }) {
    if (hours == null || hours < 0) {
      return const EvaluationResult(
        variable: 'Duración del sueño',
        value: null,
        unit: 'h',
        context: ActivityContext.sleep,
        severity: EvaluationSeverity.noData,
        summary: 'Sin datos disponibles',
      );
    }

    final sourceLabel =
        isSubjectiveManual ? 'Estimación subjetiva (manual)' : 'Actigrafía';

    if (hours < sleepDurationCriterion.minValue!) {
      return EvaluationResult(
        variable: 'Duración del sueño',
        value: hours,
        unit: 'h',
        context: ActivityContext.sleep,
        severity: EvaluationSeverity.informativeNotice,
        summary:
            '$sourceLabel: ${hours.toStringAsFixed(1)} h (<7 h recomendadas). Procurar descanso adecuado según horario operativo.',
        appliedCriterion: sleepDurationCriterion,
      );
    }

    if (hours <= sleepDurationCriterion.maxValue!) {
      return EvaluationResult(
        variable: 'Duración del sueño',
        value: hours,
        unit: 'h',
        context: ActivityContext.sleep,
        severity: EvaluationSeverity.descriptive,
        summary:
            '$sourceLabel: ${hours.toStringAsFixed(1)} h (dentro del intervalo general de 7–9 h).',
        appliedCriterion: sleepDurationCriterion,
      );
    }

    return EvaluationResult(
      variable: 'Duración del sueño',
      value: hours,
      unit: 'h',
      context: ActivityContext.sleep,
      severity: EvaluationSeverity.descriptive,
      summary:
          '$sourceLabel: ${hours.toStringAsFixed(1)} h (>9 h). Contextualizar según carga de misión y recuperación.',
      appliedCriterion: sleepDurationCriterion,
    );
  }

  /// Calcula la fuerza conservada (%) = (actual / basal) * 100 bajo NASA-STD-3001 V1 4024.
  static EvaluationResult evaluateMuscleStrength({
    required double? currentValue,
    required double? baselinePreMissionValue,
    required bool sameProtocol,
    required bool isInstrumental,
  }) {
    if (!isInstrumental ||
        !sameProtocol ||
        currentValue == null ||
        baselinePreMissionValue == null ||
        baselinePreMissionValue <= 0) {
      return const EvaluationResult(
        variable: 'Fuerza muscular conservada',
        value: null,
        unit: '%',
        context: ActivityContext.physicalActivity,
        severity: EvaluationSeverity.noData,
        summary:
            'Sin medición objetiva comparable (requiere evaluación instrumental bajo mismo protocolo pre-misión).',
      );
    }

    final retentionPercent = (currentValue / baselinePreMissionValue) * 100.0;
    final meetsNasaStandard =
        retentionPercent >= muscleStrengthCriterion.minValue!;

    return EvaluationResult(
      variable: 'Fuerza muscular conservada',
      value: retentionPercent,
      unit: '%',
      context: ActivityContext.physicalActivity,
      severity: meetsNasaStandard
          ? EvaluationSeverity.descriptive
          : EvaluationSeverity.operationalAlert,
      summary: meetsNasaStandard
          ? 'Fuerza conservada: ${retentionPercent.toStringAsFixed(1)} % (cumple ≥80 % NASA-STD-3001 V1 4024).'
          : 'Fuerza conservada: ${retentionPercent.toStringAsFixed(1)} % (por debajo del criterio 80 % NASA-STD-3001 V1 4024; no constituye diagnóstico).',
      appliedCriterion: muscleStrengthCriterion,
    );
  }
}
