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

/// Resultado de la fusión actigráfica bimodal (Acelerometría RMS no-cero + FC)
/// para inferir el estado de sueño/reposo/actividad y validar HRV en 0g.
class ActigraphyBimodalAssessment {
  final ActivityContext inferredContext;
  final bool isHrvValidForStress;
  final double accelerometryRmsG;
  final String justification;

  const ActigraphyBimodalAssessment({
    required this.inferredContext,
    required this.isHrvValidForStress,
    required this.accelerometryRmsG,
    required this.justification,
  });
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

  static const double sleepMicroMotionMinG = 0.005;
  static const double sleepMicroMotionMaxG = 0.065;
  static const double restMaxMotionG = 0.120;
  static const double exerciseMotionThresholdG = 0.250;
  static const double co2FocalPocketAlertMmHg = 4.0;

  /// Fusión actigráfica bimodal: combina acelerometría basal no-cero
  /// (balistocardiografía + respiración en 0g) con el descenso parasimpático
  /// de la frecuencia cardíaca y frecuencia respiratoria para inferir contexto y validar HRV.
  static ActigraphyBimodalAssessment inferActivityAndValidateHrv({
    required double accelerometryRmsG,
    required double heartRateBpm,
    required double respiratoryRateRpm,
    required String rawActivityState,
    double restingWakefulHrBaselineBpm = 68.0,
  }) {
    final normalizedRaw = rawActivityState.toLowerCase();

    if (normalizedRaw == 'exercise' ||
        normalizedRaw == 'post_eva' ||
        accelerometryRmsG > exerciseMotionThresholdG) {
      return ActigraphyBimodalAssessment(
        inferredContext: ActivityContext.physicalActivity,
        isHrvValidForStress: false,
        accelerometryRmsG: accelerometryRmsG,
        justification:
            'Esfuerzo activo detectado (${accelerometryRmsG.toStringAsFixed(3)} g, ${heartRateBpm.toStringAsFixed(0)} lpm). '
            'HRV excluida de análisis de estrés por retiro vagal fisiológico del ejercicio.',
      );
    }

    final inSleepMicroMotionBand = accelerometryRmsG >= sleepMicroMotionMinG &&
        accelerometryRmsG <= sleepMicroMotionMaxG;
    final hasParasympatheticHrDip =
        heartRateBpm > 0 && heartRateBpm <= restingWakefulHrBaselineBpm * 0.90;
    final hasCalmSleepRespiration =
        respiratoryRateRpm >= 8.0 && respiratoryRateRpm <= 16.5;

    if (normalizedRaw == 'sleep' ||
        (inSleepMicroMotionBand &&
            hasParasympatheticHrDip &&
            hasCalmSleepRespiration)) {
      return ActigraphyBimodalAssessment(
        inferredContext: ActivityContext.sleep,
        isHrvValidForStress: true,
        accelerometryRmsG: accelerometryRmsG,
        justification:
            'Fusión bimodal (acelerometría ${accelerometryRmsG.toStringAsFixed(3)} g + descenso vagal FC ${heartRateBpm.toStringAsFixed(0)} lpm): '
            'sueño validado y HRV apta para análisis circadiano.',
      );
    }

    if (normalizedRaw == 'resting' || accelerometryRmsG <= restMaxMotionG) {
      return ActigraphyBimodalAssessment(
        inferredContext: ActivityContext.rest,
        isHrvValidForStress: true,
        accelerometryRmsG: accelerometryRmsG,
        justification:
            'Reposo basal estable (${accelerometryRmsG.toStringAsFixed(3)} g). Lectura de HRV válida para control autonómico.',
      );
    }

    return ActigraphyBimodalAssessment(
      inferredContext: ActivityContext.physicalActivity,
      isHrvValidForStress: false,
      accelerometryRmsG: accelerometryRmsG,
      justification:
          'Actividad operativa en curso (${accelerometryRmsG.toStringAsFixed(3)} g). HRV en espera de ventana de reposo.',
    );
  }

  static EvaluationResult evaluateHeartRate({
    required double? bpm,
    required ActivityContext context,
    double? individualBaselineBpm,
    double? localCo2MmHg,
    int? missionDay,
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

    if (context == ActivityContext.physicalActivity) {
      final baselineNote = delta != null
          ? ' (${delta >= 0 ? '+' : ''}${delta.toStringAsFixed(1)} lpm vs. basal en ${context.label.toLowerCase()})'
          : '';
      return EvaluationResult(
        variable: 'Frecuencia cardíaca',
        value: bpm,
        unit: 'lpm',
        context: context,
        severity: EvaluationSeverity.descriptive,
        summary:
            'Respuesta cronotrópica en ${context.label.toLowerCase()}: ${bpm.toStringAsFixed(0)} lpm$baselineNote. '
            'No se aplican intervalos de reposo durante esfuerzo.',
        individualBaselineDelta: delta,
      );
    }

    if ((context == ActivityContext.rest || context == ActivityContext.sleep) &&
        localCo2MmHg != null &&
        localCo2MmHg >= co2FocalPocketAlertMmHg &&
        bpm > hrRestGeneralCriterion.maxValue!) {
      return EvaluationResult(
        variable: 'Frecuencia cardíaca',
        value: bpm,
        unit: 'lpm',
        context: context,
        severity: EvaluationSeverity.operationalAlert,
        summary:
            'FC elevada en ${context.label.toLowerCase()} (${bpm.toStringAsFixed(0)} lpm) correlacionada con bolsillo focal de CO₂ (${localCo2MmHg.toStringAsFixed(1)} mmHg). Verificar flujo ECLSS.',
        appliedCriterion: hrRestGeneralCriterion,
        individualBaselineDelta: delta,
      );
    }

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
            'Reposo${missionDay != null ? ' (Día $missionDay)' : ''}: ${bpm.toStringAsFixed(0)} lpm (${delta! >= 0 ? '+' : ''}${delta.toStringAsFixed(1)} lpm vs. basal individual).',
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
    double? localCo2MmHg,
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

    if ((context == ActivityContext.rest || context == ActivityContext.sleep) &&
        localCo2MmHg != null &&
        localCo2MmHg >= co2FocalPocketAlertMmHg &&
        rpm > rrRestGeneralCriterion.maxValue!) {
      return EvaluationResult(
        variable: 'Frecuencia respiratoria',
        value: rpm,
        unit: 'rpm',
        context: context,
        severity: EvaluationSeverity.operationalAlert,
        summary:
            'Taquipnea en ${context.label.toLowerCase()} (${rpm.toStringAsFixed(1)} rpm) asociada a CO₂ local elevado (${localCo2MmHg.toStringAsFixed(1)} mmHg).',
        appliedCriterion: rrRestGeneralCriterion,
        individualBaselineDelta: delta,
      );
    }

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

  static const ScientificCriterion bloodPressureCriterion = ScientificCriterion(
    id: 'bp_contextual_nasa_std_3001',
    variable: 'Presión Arterial',
    unit: 'mmHg',
    level: CriterionLevel.generalScientific,
    context: ActivityContext.rest,
    minValue: MedicalThresholds.minSystolicBP,
    maxValue: MedicalThresholds.maxSystolicBP,
    population: 'Tripulación adulta en reposo o ejercicio controlado en 0g',
    source: 'NASA-STD-3001 Vol. 2 / AHA Cardiovascular Adaptation in 0g',
    version: '1.1.0',
    limitations:
        'En microgravedad el desplazamiento cefálico de fluidos modifica el tono barorreflejo. '
        'En ejercicio ARED/CEVIS la sistólica fisiológica puede ascender hasta 180 mmHg.',
  );

  static const ScientificCriterion capillaryRefillCriterion = ScientificCriterion(
    id: 'capillary_refill_perfusion',
    variable: 'Tiempo de Llenado Capilar',
    unit: 's',
    level: CriterionLevel.operationalLimit,
    context: ActivityContext.rest,
    minValue: 0.5,
    maxValue: 2.0,
    population: 'Evaluación periférica de perfusión en vuelo y EVA',
    source: 'NASA-STD-3001 Vol. 2 / Microvascular Perfusion Standard',
    version: '1.0.0',
    limitations:
        'El frío en guantes EVA o el estado de reposo prolongado en 0g pueden retrasar el retorno capilar sin hipovolemia sistémica.',
  );

  static const ScientificCriterion bodyTempCriterion = ScientificCriterion(
    id: 'body_temp_thermoregulation_0g',
    variable: 'Temperatura Corporal',
    unit: '°C',
    level: CriterionLevel.generalScientific,
    context: ActivityContext.rest,
    minValue: 36.0,
    maxValue: 37.3,
    population: 'Tripulación en ambiente controlado o esfuerzo aeróbico',
    source: 'NASA-STD-3001 Vol. 2 / Thermoregulation in Microgravity (Stahn et al.)',
    version: '1.0.0',
    limitations:
        'La ausencia de convección natural en 0g eleva la temperatura central en ejercicio (hasta 38.4 °C fisiológicos).',
  );

  static const ScientificCriterion bloodGlucoseCriterion = ScientificCriterion(
    id: 'blood_glucose_metabolic_0g',
    variable: 'Glucosa en Sangre',
    unit: 'mg/dL',
    level: CriterionLevel.generalScientific,
    context: ActivityContext.rest,
    minValue: 70.0,
    maxValue: 140.0,
    population: 'Tripulación en ayuno, posprandial o demanda metabólica',
    source: 'NASA-STD-3001 Nutritional & Metabolic Standard',
    version: '1.0.0',
    limitations:
        'En microgravedad puede existir resistencia subclínica transitoria a la insulina o consumo acelerado durante ARED/EVA.',
  );

  static const ScientificCriterion hydrationCriterion = ScientificCriterion(
    id: 'hydration_fluid_shift_0g',
    variable: 'Hidratación Calibrada (Bioimpedancia)',
    unit: '%',
    level: CriterionLevel.operationalLimit,
    context: ActivityContext.rest,
    minValue: 68.0,
    maxValue: 100.0,
    population: 'Tripulación calibrada según día de misión y fluid shift',
    source: 'NASA-STD-3001 Vol. 2 / Fluid Shift & Plasma Volume Compensation',
    version: '1.1.0',
    limitations:
        'Durante los primeros 7 días en 0g se aplica corrección por diuresis compensatoria cefálica.',
  );

  static const ScientificCriterion hrvBimodalCriterion = ScientificCriterion(
    id: 'hrv_bimodal_actigraphy_0g',
    variable: 'HRV y Actigrafía Bimodal',
    unit: 'ms',
    level: CriterionLevel.generalScientific,
    context: ActivityContext.sleep,
    minValue: 30.0,
    maxValue: null,
    population: 'Validación parasimpática en reposo y sueño espacial',
    source: 'BHP Cole-Kripke & NASA-HRP Bimodal Actigraphy Fusion',
    version: '1.1.0',
    limitations:
        'No debe interpretarse como estrés autonómico cuando la acelerometría RMS supera el umbral de ejercicio activo.',
  );

  static EvaluationResult evaluateBloodPressureContextual({
    required double systolicMmHg,
    required double diastolicMmHg,
    required ActivityContext context,
  }) {
    final bpText = '${systolicMmHg.toInt()}/${diastolicMmHg.toInt()} mmHg';
    if (context == ActivityContext.physicalActivity) {
      final expectedDuringExercise =
          systolicMmHg >= 90.0 && systolicMmHg <= 180.0 && diastolicMmHg <= 95.0;
      return EvaluationResult(
        variable: 'Presión Arterial',
        value: systolicMmHg,
        unit: 'mmHg',
        context: context,
        severity: expectedDuringExercise
            ? EvaluationSeverity.descriptive
            : EvaluationSeverity.informativeNotice,
        summary: expectedDuringExercise
            ? 'Respuesta tensional ($bpText) acorde al esfuerzo en ${context.label.toLowerCase()} (hasta 180 mmHg sistólica)'
            : 'Presión ($bpText) fuera de banda esperada durante actividad física',
        appliedCriterion: bloodPressureCriterion,
      );
    }

    final withinRestBand = systolicMmHg >= MedicalThresholds.minSystolicBP &&
        systolicMmHg <= MedicalThresholds.maxSystolicBP &&
        diastolicMmHg >= 60.0 &&
        diastolicMmHg <= 85.0;
    return EvaluationResult(
      variable: 'Presión Arterial',
      value: systolicMmHg,
      unit: 'mmHg',
      context: context,
      severity: withinRestBand
          ? EvaluationSeverity.descriptive
          : EvaluationSeverity.informativeNotice,
      summary: withinRestBand
          ? 'Registro ($bpText) dentro de rango orientativo en ${context.label.toLowerCase()} (90–130 / 60–85 mmHg)'
          : 'Registro ($bpText) fuera de rango orientativo en ${context.label.toLowerCase()} (90–130 / 60–85 mmHg)',
      appliedCriterion: bloodPressureCriterion,
    );
  }

  static EvaluationResult evaluateCapillaryRefillContextual({
    required double seconds,
    required ActivityContext context,
  }) {
    final double maxThreshold =
        context == ActivityContext.sleep ? 2.3 : 2.0;
    final bool isNominal = seconds > 0 && seconds <= maxThreshold;
    final bool isCritical = seconds > 3.0;

    return EvaluationResult(
      variable: 'Tiempo de Llenado Capilar',
      value: seconds,
      unit: 's',
      context: context,
      severity: isCritical
          ? EvaluationSeverity.operationalAlert
          : (isNominal
              ? EvaluationSeverity.descriptive
              : EvaluationSeverity.informativeNotice),
      summary: isNominal
          ? 'Perfusión periférica adecuada (${seconds.toStringAsFixed(1)} s <= ${maxThreshold.toStringAsFixed(1)} s) en ${context.label.toLowerCase()}'
          : 'Retorno capilar prolongado (${seconds.toStringAsFixed(1)} s) en ${context.label.toLowerCase()} • Verificar temperatura periférica y volemia',
      appliedCriterion: capillaryRefillCriterion,
    );
  }

  static EvaluationResult evaluateBodyTemperatureContextual({
    required double tempCelsius,
    required ActivityContext context,
  }) {
    final double maxTemp =
        context == ActivityContext.physicalActivity ? 38.4 : 37.3;
    final bool isNominal = tempCelsius >= 36.0 && tempCelsius <= maxTemp;

    return EvaluationResult(
      variable: 'Temperatura Corporal',
      value: tempCelsius,
      unit: '°C',
      context: context,
      severity: isNominal
          ? EvaluationSeverity.descriptive
          : EvaluationSeverity.informativeNotice,
      summary: isNominal
          ? (context == ActivityContext.physicalActivity
              ? 'Termorregulación esperada durante actividad física (36.0–38.4 °C)'
              : 'Dentro de intervalo orientativo (36.0–37.3 °C)')
          : 'Fuera de intervalo esperado para ${context.label.toLowerCase()} (máx ${maxTemp.toStringAsFixed(1)} °C)',
      appliedCriterion: bodyTempCriterion,
    );
  }

  static EvaluationResult evaluateBloodGlucoseContextual({
    required double mgDl,
    required ActivityContext context,
  }) {
    if (mgDl < 70.0) {
      return EvaluationResult(
        variable: 'Glucosa en Sangre',
        value: mgDl,
        unit: 'mg/dL',
        context: context,
        severity: EvaluationSeverity.operationalAlert,
        summary:
            'Hipoglucemia operativa (${mgDl.toStringAsFixed(0)} mg/dL < 70) en ${context.label.toLowerCase()} • Priorizar aporte de carbohidratos',
        appliedCriterion: bloodGlucoseCriterion,
      );
    }

    final double upperLimit =
        context == ActivityContext.physicalActivity ? 155.0 : 140.0;
    final bool isNominal = mgDl <= upperLimit;

    return EvaluationResult(
      variable: 'Glucosa en Sangre',
      value: mgDl,
      unit: 'mg/dL',
      context: context,
      severity: isNominal
          ? EvaluationSeverity.descriptive
          : EvaluationSeverity.informativeNotice,
      summary: isNominal
          ? (context == ActivityContext.physicalActivity
              ? 'Demanda glucogénica cubierta durante esfuerzo (70–${upperLimit.toInt()} mg/dL)'
              : 'Glucemia dentro de intervalo orientativo en ${context.label.toLowerCase()} (70–${upperLimit.toInt()} mg/dL)')
          : 'Glucemia elevada (${mgDl.toStringAsFixed(0)} mg/dL) para ${context.label.toLowerCase()} • Verificar última ingesta',
      appliedCriterion: bloodGlucoseCriterion,
    );
  }

  static EvaluationResult evaluateHydrationContextual({
    required double calibratedHydrationPercent,
    required int missionDay,
    required ActivityContext context,
  }) {
    final isOptimal = calibratedHydrationPercent >= 68.0;
    final isCritical = calibratedHydrationPercent < 55.0;

    return EvaluationResult(
      variable: 'Hidratación (Bioimpedancia)',
      value: calibratedHydrationPercent,
      unit: '%',
      context: context,
      severity: isCritical
          ? EvaluationSeverity.operationalAlert
          : (isOptimal
              ? EvaluationSeverity.descriptive
              : EvaluationSeverity.informativeNotice),
      summary: isOptimal
          ? 'Calibrada Día $missionDay (ajuste cefálico 0g): rango hídrico nominal'
          : 'Calibrada Día $missionDay: tendencia hídrica baja (<68 %) • Priorizar reposición oral',
      appliedCriterion: hydrationCriterion,
    );
  }

  static EvaluationResult evaluateHrvContextual({
    required double hrvRmssdMs,
    required ActigraphyBimodalAssessment actigraphy,
  }) {
    if (!actigraphy.isHrvValidForStress) {
      return EvaluationResult(
        variable: 'HRV & Actigrafía Bimodal',
        value: hrvRmssdMs,
        unit: 'ms',
        context: actigraphy.inferredContext,
        severity: EvaluationSeverity.descriptive,
        summary:
            'Acelerometría ${actigraphy.accelerometryRmsG.toStringAsFixed(3)} g • HRV excluida como marcador de estrés durante esfuerzo/movimiento',
        appliedCriterion: hrvBimodalCriterion,
      );
    }

    final isBalanced = hrvRmssdMs >= 30.0;
    return EvaluationResult(
      variable: 'HRV & Actigrafía Bimodal',
      value: hrvRmssdMs,
      unit: 'ms',
      context: actigraphy.inferredContext,
      severity: isBalanced
          ? EvaluationSeverity.descriptive
          : EvaluationSeverity.informativeNotice,
      summary: isBalanced
          ? 'Actigrafía ${actigraphy.accelerometryRmsG.toStringAsFixed(3)} g (${actigraphy.inferredContext.label}) • HRV válida y recuperación vagal adecuada'
          : 'Actigrafía ${actigraphy.accelerometryRmsG.toStringAsFixed(3)} g (${actigraphy.inferredContext.label}) • HRV reducida en reposo/sueño',
      appliedCriterion: hrvBimodalCriterion,
    );
  }
}
