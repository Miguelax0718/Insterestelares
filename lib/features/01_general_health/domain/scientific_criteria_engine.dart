import '../models/vitals_record.dart';

/// Contexto fisiológico explícito para evitar errores al evaluar criterios
/// clínicos o fisiológicos fuera de su población/estado de validez.
enum ActivityContext {
  rest('Reposo consciente'),
  sleep('Sueño / Descanso nocturno'),
  physicalActivity('Actividad física / Ejercicio ARED'),
  eva('Actividad Extravehicular (EVA)');

  final String label;
  const ActivityContext(this.label);

  static ActivityContext fromString(String raw) {
    final normalized = raw.trim().toLowerCase();
    switch (normalized) {
      case 'sleep':
      case 'sueño':
      case 'night':
        return ActivityContext.sleep;
      case 'physical_activity':
      case 'physicalactivity':
      case 'exercise':
      case 'ejercicio':
        return ActivityContext.physicalActivity;
      case 'eva':
        return ActivityContext.eva;
      default:
        return ActivityContext.rest;
    }
  }
}

/// Dimensión fisiológica de monitoreo pasivo permanente.
enum PassiveHealthDimension {
  cardiorespiratoryMetabolic('cardiorespiratory_metabolic', 'Cardiorrespiratoria y Metabólica'),
  neurologicalSensory('neurological_sensory', 'Neurológica y Sensorial'),
  musculoskeletal('musculoskeletal', 'Musculoesquelética'),
  circadianPsychoemotional('circadian_psychoemotional', 'Circadiana y Psicoemocional');

  final String id;
  final String label;
  const PassiveHealthDimension(this.id, this.label);
}

/// Distingue referencias científicas generales de límites operacionales espaciales.
enum CriterionLevel {
  generalScientific('Referencia científica general'),
  operationalLimit('Límite operacional espacial'),
  unvalidatedThreshold('Sin umbral clínico definitivo');

  final String label;
  const CriterionLevel(this.label);
}

/// Resultado de evaluación científica contextualizada.
enum EvaluationSeverity {
  normal('Normal según criterio aplicable'),
  contextualWarning('Fuera de referencia — requiere contexto'),
  clinicalAttention('Atención médica / oficial de vuelo requerida'),
  notApplicable('Criterio no aplicable en este contexto');

  final String label;
  const EvaluationSeverity(this.label);
}

/// Metadatos científicos trazables de cada criterio evaluado.
class ScientificCriterion {
  final String id;
  final PassiveHealthDimension dimension;
  final String variable;
  final String unit;
  final CriterionLevel level;
  final ActivityContext validContext;
  final double? minValue;
  final double? maxValue;
  final String population;
  final String source;
  final String hardwareReference;
  final String accuracyEstimate;
  final List<String> datasets;
  final String version;
  final String limitations;

  const ScientificCriterion({
    required this.id,
    required this.dimension,
    required this.variable,
    required this.unit,
    required this.level,
    required this.validContext,
    required this.minValue,
    required this.maxValue,
    required this.population,
    required this.source,
    this.hardwareReference = 'Sensores biomédicos validados',
    this.accuracyEstimate = 'No especificado',
    this.datasets = const [],
    this.version = '1.1.0',
    required this.limitations,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'dimension': dimension.id,
        'variable': variable,
        'unit': unit,
        'level': level.name,
        'valid_context': validContext.name,
        'min_value': minValue,
        'max_value': maxValue,
        'population': population,
        'source': source,
        'hardware_reference': hardwareReference,
        'accuracy_estimate': accuracyEstimate,
        'datasets': datasets,
        'version': version,
        'limitations': limitations,
      };
}

/// Respuesta trazable de una evaluación fisiológica individual.
class EvaluationResult {
  final ScientificCriterion criterion;
  final double measuredValue;
  final ActivityContext observedContext;
  final EvaluationSeverity severity;
  final String interpretation;
  final String scientificCaution;
  final double signalQualityPercent;

  const EvaluationResult({
    required this.criterion,
    required this.measuredValue,
    required this.observedContext,
    required this.severity,
    required this.interpretation,
    required this.scientificCaution,
    this.signalQualityPercent = 100.0,
  });

  bool get hasWarning =>
      severity == EvaluationSeverity.contextualWarning ||
      severity == EvaluationSeverity.clinicalAttention;

  Map<String, dynamic> toJson() => {
        'criterion_id': criterion.id,
        'dimension': criterion.dimension.id,
        'variable': criterion.variable,
        'unit': criterion.unit,
        'measured_value': measuredValue,
        'observed_context': observedContext.name,
        'severity': severity.name,
        'interpretation': interpretation,
        'scientific_caution': scientificCaution,
        'signal_quality_percent': signalQualityPercent,
        'hardware_reference': criterion.hardwareReference,
        'source': criterion.source,
      };
}

/// Resultado de evaluación actigráfica bimodal (HRV + acelerometría triaxial).
class ActigraphyBimodalAssessment {
  final EvaluationSeverity severity;
  final bool hrvValidWindow;
  final String stateLabel;
  final String interpretation;
  final String telemetryNote;
  final List<String> sources;

  const ActigraphyBimodalAssessment({
    required this.severity,
    required this.hrvValidWindow,
    required this.stateLabel,
    required this.interpretation,
    required this.telemetryNote,
    required this.sources,
  });

  Map<String, dynamic> toJson() => {
        'severity': severity.name,
        'hrv_valid_window': hrvValidWindow,
        'state_label': stateLabel,
        'interpretation': interpretation,
        'telemetry_note': telemetryNote,
        'sources': sources,
      };
}

/// Resumen completo de las 4 dimensiones de medición automática permanente.
class PassiveDimensionEvaluation {
  final DateTime evaluatedAt;
  final ActivityContext activityContext;
  final bool inMicrogravity;
  final EvaluationSeverity overallSeverity;
  final List<EvaluationResult> results;
  final ActigraphyBimodalAssessment actigraphyBimodal;
  final Map<String, EvaluationSeverity> dimensionSeverities;
  final List<String> alerts;
  final List<String> recommendations;

  const PassiveDimensionEvaluation({
    required this.evaluatedAt,
    required this.activityContext,
    required this.inMicrogravity,
    required this.overallSeverity,
    required this.results,
    required this.actigraphyBimodal,
    required this.dimensionSeverities,
    required this.alerts,
    required this.recommendations,
  });

  Map<String, dynamic> toJson() => {
        'evaluated_at': evaluatedAt.toIso8601String(),
        'activity_context': activityContext.name,
        'in_microgravity': inMicrogravity,
        'overall_severity': overallSeverity.name,
        'dimension_severities': dimensionSeverities.map((k, v) => MapEntry(k, v.name)),
        'actigraphy_bimodal': actigraphyBimodal.toJson(),
        'alerts': alerts,
        'recommendations': recommendations,
        'results': results.map((r) => r.toJson()).toList(),
      };
}

/// Motor científico determinista Offline-First para criterios de monitoreo
/// automático permanente en 4 dimensiones fisiológicas y validación contextual.
class ScientificCriteriaEngine {
  const ScientificCriteriaEngine();

  static const ScientificCriterion heartRateRestCriterion = ScientificCriterion(
    id: 'hr_rest_aha_general',
    dimension: PassiveHealthDimension.cardiorespiratoryMetabolic,
    variable: 'heart_rate',
    unit: 'lpm',
    level: CriterionLevel.generalScientific,
    validContext: ActivityContext.rest,
    minValue: 60.0,
    maxValue: 100.0,
    hardwareReference: 'Bio-Monitor (CSA), vestimenta biométrica CARDIOBREATH (NASA / Crew-5)',
    accuracyEstimate: '95% - 98% (reposo/sueño); 88% - 92% (ejercicio)',
    datasets: ['NASA Life Sciences Data Archive (LSDA)', 'PhysioNet (WESAD / MIMIC-III)'],
    population: 'Adultos sanos en entorno terrestre en reposo',
    source:
        'American Heart Association; Mendes Zambetta et al. (2024); Fine et al. (2021); CSA',
    limitations:
        'No aplicar en sueño ni ejercicio físico. En microgravedad existe un incremento promedio poblacional no uniforme de +3.44 lpm por redistribución hídrica.',
  );

  static const ScientificCriterion respiratoryRateRestCriterion = ScientificCriterion(
    id: 'rr_rest_general',
    dimension: PassiveHealthDimension.cardiorespiratoryMetabolic,
    variable: 'respiratory_rate',
    unit: 'rpm',
    level: CriterionLevel.generalScientific,
    validContext: ActivityContext.rest,
    minValue: 12.0,
    maxValue: 20.0,
    hardwareReference: 'Bio-Monitor (CSA), bandas torácicas de inductancia',
    accuracyEstimate: '93% - 97% en entornos presurizados',
    datasets: ['PhysioNet Clinical Lab Datasets', 'Bio-Monitor ISS Flight Logs'],
    population: 'Adultos sanos en reposo',
    source: 'Cleveland Clinic; Berry et al. (2012); Canadian Space Agency',
    limitations:
        'Referencia orientativa en reposo. No diagnosticar con una única lectura ni extrapolar directamente a ejercicio/EVA.',
  );

  static const ScientificCriterion spo2Criterion = ScientificCriterion(
    id: 'spo2_terrestrial_general',
    dimension: PassiveHealthDimension.cardiorespiratoryMetabolic,
    variable: 'spo2',
    unit: '%',
    level: CriterionLevel.generalScientific,
    validContext: ActivityContext.rest,
    minValue: 95.0,
    maxValue: 100.0,
    hardwareReference: 'Pulsioximetría infrarroja validada FDA 510(k) / Bio-Monitor',
    accuracyEstimate: '93% - 97% en entornos presurizados',
    datasets: ['PhysioNet Clinical Lab Datasets', 'Bio-Monitor ISS Flight Logs'],
    population: 'Adultos sanos en condiciones presurizadas apropiadas',
    source: 'U.S. Food and Drug Administration (2013); NHLBI (2023)',
    limitations:
        'Evaluar calidad de señal, movimiento, perfusión periférica y presión parcial de O2/CO2 en cabina antes de concluir hipoxemia.',
  );

  static const ScientificCriterion coreTempHeatFluxCriterion = ScientificCriterion(
    id: 'core_temp_heat_flux_draeger',
    dimension: PassiveHealthDimension.cardiorespiratoryMetabolic,
    variable: 'core_temp_heat_flux',
    unit: '°C',
    level: CriterionLevel.generalScientific,
    validContext: ActivityContext.rest,
    minValue: 36.0,
    maxValue: 37.3,
    hardwareReference: 'Draeger Double Sensor (validado por DLR y NASA)',
    accuracyEstimate: '96% - 98% (error inferior a ±0.2 °C vs. sonda esofágica/rectal)',
    datasets: ['NASA Human Research Program (HRP) Data Portal'],
    population: 'Tripulación en cabina presurizada o ejercicio aeróbico en microgravedad',
    source: 'NASA-STD-3001 Vol. 2; DLR / NASA Thermal Physiology Reports',
    limitations:
        'Sin convección térmica natural en 0 g, la temperatura central fisiológica en ejercicio/EVA tolera hasta 38.4 °C antes de alerta térmica operacional.',
  );

  static const ScientificCriterion hydrationBisCriterion = ScientificCriterion(
    id: 'hydration_bis_fluid_shift',
    dimension: PassiveHealthDimension.cardiorespiratoryMetabolic,
    variable: 'hydration_bioimpedance_index',
    unit: '%',
    level: CriterionLevel.operationalLimit,
    validContext: ActivityContext.rest,
    minValue: 68.0,
    maxValue: 100.0,
    hardwareReference: 'Parches biométricos dermales de bioimpedancia multifrecuencia (Bodystat BIS)',
    accuracyEstimate: '90% - 94% (con corrección por software de desplazamiento cefálico)',
    datasets: ['NASA HRP Fluid Shift Database'],
    population: 'Tripulación en vuelo espacial con ajuste de desplazamiento cefálico (TBW)',
    source: 'NASA-STD-3001 Vol. 2; NASA HRP Fluid Shift Protocols',
    limitations:
        'Compensación obligatoria por redistribución hídrica cefálica en microgravedad para evitar falsos negativos de deshidratación.',
  );

  static const ScientificCriterion pupillometryNpiCriterion = ScientificCriterion(
    id: 'eye_tracking_pupillometry_npi',
    dimension: PassiveHealthDimension.neurologicalSensory,
    variable: 'pupillometry_npi',
    unit: 'NPi',
    level: CriterionLevel.operationalLimit,
    validContext: ActivityContext.rest,
    minValue: 3.0,
    maxValue: 5.0,
    hardwareReference: 'Tobii Pro Glasses 3, Pupil Labs Core, NeurOptics VIP-200',
    accuracyEstimate: '96% - 98% en resolución del diámetro pupilar (0.05 mm)',
    datasets: [
      'DLR / ESA Microgravity Cognition and Pupillometry Database',
      'PhysioNet Pupillometric Signal Database',
    ],
    population: 'Vigilancia pasiva de equilibrio autónomo y fatiga de tronco encefálico',
    source: 'DLR / ESA Space Physiology Reports',
    limitations:
        'NPi < 3.0 o latencia de Reflejo Pupilar a la Luz (PLR) > 280 ms requiere evaluación neuro-ocular urgente.',
  );

  static const ScientificCriterion hyperopicShiftToFCriterion = ScientificCriterion(
    id: 'hyperopic_shift_tof_passive',
    dimension: PassiveHealthDimension.neurologicalSensory,
    variable: 'passive_near_focus_tof',
    unit: 'cm',
    level: CriterionLevel.operationalLimit,
    validContext: ActivityContext.rest,
    minValue: 20.0,
    maxValue: 35.0,
    hardwareReference: 'Sensor óptico Time-of-Flight (ToF) e IR en tableta de misión / visores',
    accuracyEstimate: '95% - 99% sensibilidad clínica (+0.50 a +1.75 D)',
    datasets: ['NASA Space Medicine On-Orbit Visual Acuity Logs'],
    population: 'Detección pasiva temprana de desplazamiento hiperópico asociado a SANS',
    source: 'Lee et al. (2020, p. 4); Macias et al. (2021, p. 321)',
    limitations:
        'Alejamiento sostenido > 35 cm o desplazamiento >= +0.50 D es marcador temprano indirecto de SANS; confirmar con optometría/ONSD.',
  );

  static const ScientificCriterion passivePvtCriterion = ScientificCriterion(
    id: 'passive_background_pvt_b',
    dimension: PassiveHealthDimension.neurologicalSensory,
    variable: 'passive_pvt_reaction_ms',
    unit: 'ms',
    level: CriterionLevel.operationalLimit,
    validContext: ActivityContext.rest,
    minValue: 150.0,
    maxValue: 355.0,
    hardwareReference: 'Algoritmo pasivo en SO de tableta de misión (matriz NASA Spaceflight PVT-B)',
    accuracyEstimate: '> 95% de sensibilidad para fatiga cognitiva y privación de sueño',
    datasets: ['NASA LSDA Spaceflight Psychomotor Vigilance Task Database'],
    population: 'Analítica en segundo plano durante uso habitual de pantallas',
    source: 'Basner & Dinges (2011); Basner et al. (2014); Piechowski et al. (2020)',
    limitations:
        'Lapsos de atención (>500 ms) >= 3 o precisión táctil < 90% sugieren deterioro de vigilancia por privación de sueño o desalineación circadiana.',
  );

  static const ScientificCriterion inertialImuCriterion = ScientificCriterion(
    id: 'inertial_imu_biomechanics',
    dimension: PassiveHealthDimension.musculoskeletal,
    variable: 'peak_impact_g',
    unit: 'g',
    level: CriterionLevel.operationalLimit,
    validContext: ActivityContext.physicalActivity,
    minValue: 0.005,
    maxValue: 2.5,
    hardwareReference: 'Sensores inerciales triaxiales (IMU) vestibles en pulsera/tobillo/traje EVA',
    accuracyEstimate: '95% - 98% en clasificación de actividad e impacto',
    datasets: ['NASA HRP Biomechanics Archives', 'ESA Human Performance Database'],
    population: 'Registro continuo de actividad diaria, marcha e impactos bruscos',
    source: 'NASA HRP Biomechanics Archives; ESA Human Performance Database',
    limitations:
        'Picos >= 2.5 g disparan protocolo de detección automática de caída o traumatismo inercial.',
  );

  static const ScientificCriterion muscleBioimpedanceCriterion = ScientificCriterion(
    id: 'localized_muscle_bioimpedance',
    dimension: PassiveHealthDimension.musculoskeletal,
    variable: 'muscle_volume_retention_percent',
    unit: '%',
    level: CriterionLevel.operationalLimit,
    validContext: ActivityContext.rest,
    minValue: 80.0,
    maxValue: null,
    hardwareReference: 'Parches dermales vestibles multifrecuencia en cuádriceps y gastrocnemio',
    accuracyEstimate: '93% - 96% de concordancia en volumen muscular y ángulo de pennación',
    datasets: ['ESA Spaceflight Musculoskeletal Atrophy Database'],
    population: 'Vigilancia pasiva de atrofia muscular en miembros inferiores',
    source: 'ESA Spaceflight Musculoskeletal Atrophy Database; NASA-STD-3001 V1 4024',
    limitations:
        'Correlacionar siempre con índice de hidratación BIS para descartar sesgos por desplazamiento de fluidos.',
  );

  static const ScientificCriterion muscleStrengthCriterion = ScientificCriterion(
    id: 'muscle_strength_nasa_std_3001',
    dimension: PassiveHealthDimension.musculoskeletal,
    variable: 'muscle_strength_retention',
    unit: '%',
    level: CriterionLevel.operationalLimit,
    validContext: ActivityContext.physicalActivity,
    minValue: 80.0,
    maxValue: null,
    hardwareReference: 'Dinamometría / plataforma ARED comparativa pre-misión',
    accuracyEstimate: '93% - 96% con protocolo instrumental equivalente',
    datasets: ['NASA-STD-3001 Vol. 1; ESA Human Performance Database'],
    population: 'Tripulación comparada con basal pre-misión equivalente',
    source: 'NASA-STD-3001 Volume 1 V1 4024; NASA OCHMO-TB-031 (2023)',
    limitations:
        'Requiere comparabilidad metodológica exacta con la evaluación basal terrestre.',
  );

  static const ScientificCriterion sleepDurationCriterion = ScientificCriterion(
    id: 'sleep_duration_nsf_aasm',
    dimension: PassiveHealthDimension.circadianPsychoemotional,
    variable: 'sleep_duration',
    unit: 'h',
    level: CriterionLevel.generalScientific,
    validContext: ActivityContext.sleep,
    minValue: 7.0,
    maxValue: 9.0,
    hardwareReference: 'Actígrafo biométrico de muñeca de grado médico',
    accuracyEstimate: '90% - 95% de concordancia con polisomnografía (PSG)',
    datasets: ['NASA LSDA Spaceflight Actigraphy Database', 'PhysioNet Sleep-EDF Database'],
    population: 'Adultos (ventana de 24 horas)',
    source:
        'Sadeh (2011); Hirshkowitz et al. (2015); Watson et al. (2015); Smith et al. (2018); Barger et al. (2014)',
    limitations:
        'La actigrafía mide movimiento y calcula eficiencia/fragmentación sin estadificación clínica EEG REM/NREM.',
  );

  static const ScientificCriterion nocturnalHrvCriterion = ScientificCriterion(
    id: 'nocturnal_hrv_autonomic_recovery',
    dimension: PassiveHealthDimension.circadianPsychoemotional,
    variable: 'nocturnal_hrv_rmssd_sdnn',
    unit: 'ms',
    level: CriterionLevel.generalScientific,
    validContext: ActivityContext.sleep,
    minValue: 30.0,
    maxValue: null,
    hardwareReference: 'Prenda inteligente Bio-Monitor (CSA) / parches ECG nocturno',
    accuracyEstimate: '95% - 98% respecto a Holter ECG en inmovilidad nocturna',
    datasets: ['NASA HRP Autonomic Physiology Records', 'PhysioNet WESAD'],
    population: 'Ventanas de descanso nocturno como marcador de tono parasimpático y estrés',
    source: 'NASA HRP Autonomic Physiology Records; Mendes Zambetta et al. (2024)',
    limitations:
        'Evaluar únicamente en ventanas validadas de inmovilidad nocturna o sueño confirmado.',
  );

  static const ScientificCriterion nocturnalIntegratedVitalsCriterion = ScientificCriterion(
    id: 'nocturnal_integrated_vitals',
    dimension: PassiveHealthDimension.circadianPsychoemotional,
    variable: 'nocturnal_vitals_fc_fr_spo2',
    unit: '%',
    level: CriterionLevel.operationalLimit,
    validContext: ActivityContext.sleep,
    minValue: 94.0,
    maxValue: 100.0,
    hardwareReference: 'Pulsioximetría vestible y banda respiratoria inductiva / Bio-Monitor',
    accuracyEstimate: '93% - 97% en ventanas de reposo presurizado',
    datasets: ['PhysioNet Clinical Lab Datasets', 'Bio-Monitor ISS Flight Logs'],
    population: 'Promedios nocturnos integrados de FC, FR y SpO2',
    source: 'Bio-Monitor ISS Flight Logs; U.S. FDA (2013)',
    limitations:
        'Cualquier desaturación nocturna repetida o SpO2 media < 94% requiere revisar ventilación de litera/cabina y descartar hipopnea.',
  );

  // ===========================================================================
  // 1. DIMENSIÓN CARDIORRESPIRATORIA Y METABÓLICA
  // ===========================================================================

  EvaluationResult evaluateHeartRate({
    required double bpm,
    required ActivityContext context,
    double signalQualityPercent = 98.0,
    bool inMicrogravity = true,
  }) {
    if (signalQualityPercent < 80.0) {
      return EvaluationResult(
        criterion: heartRateRestCriterion,
        measuredValue: bpm,
        observedContext: context,
        severity: EvaluationSeverity.notApplicable,
        interpretation:
            'Señal PPG/ECG degradada (${signalQualityPercent.toStringAsFixed(0)}%). Lectura descartada por artefactos de movimiento o baja perfusión cutánea.',
        scientificCaution: heartRateRestCriterion.limitations,
        signalQualityPercent: signalQualityPercent,
      );
    }

    if (context == ActivityContext.physicalActivity || context == ActivityContext.eva) {
      final bool tachycardiaFlag = bpm > 175.0;
      return EvaluationResult(
        criterion: heartRateRestCriterion,
        measuredValue: bpm,
        observedContext: context,
        severity: tachycardiaFlag
            ? EvaluationSeverity.contextualWarning
            : EvaluationSeverity.notApplicable,
        interpretation: tachycardiaFlag
            ? 'FC elevada (${bpm.toStringAsFixed(0)} lpm) durante ${context.label}. Verificar carga ARED/EVA y recuperación a 2 min.'
            : 'FC ${bpm.toStringAsFixed(0)} lpm en ${context.label}: criterio basal 60-100 lpm no aplicable durante esfuerzo (precisión PPG/ECG 88%-92%).',
        scientificCaution: heartRateRestCriterion.limitations,
        signalQualityPercent: signalQualityPercent,
      );
    }

    if (context == ActivityContext.sleep) {
      final bool abnormalSleepHr = bpm < 40.0 || bpm > 95.0;
      return EvaluationResult(
        criterion: heartRateRestCriterion,
        measuredValue: bpm,
        observedContext: context,
        severity: abnormalSleepHr
            ? EvaluationSeverity.contextualWarning
            : EvaluationSeverity.normal,
        interpretation: abnormalSleepHr
            ? 'FC nocturna de ${bpm.toStringAsFixed(0)} lpm atípica en sueño; correlacionar con HRV y saturación nocturna.'
            : 'FC nocturna de ${bpm.toStringAsFixed(0)} lpm compatible con bradicardia fisiológica del sueño.',
        scientificCaution: heartRateRestCriterion.limitations,
        signalQualityPercent: signalQualityPercent,
      );
    }

    final adjustedMax = inMicrogravity ? 103.44 : 100.0;
    if (bpm >= 60.0 && bpm <= adjustedMax) {
      return EvaluationResult(
        criterion: heartRateRestCriterion,
        measuredValue: bpm,
        observedContext: context,
        severity: EvaluationSeverity.normal,
        interpretation: inMicrogravity && bpm > 100.0
            ? 'FC en reposo ${bpm.toStringAsFixed(1)} lpm dentro de tolerancia por desplazamiento de +3.44 lpm en microgravedad.'
            : 'FC en reposo ${bpm.toStringAsFixed(0)} lpm dentro del rango fisiológico AHA (60-100 lpm).',
        scientificCaution: heartRateRestCriterion.limitations,
        signalQualityPercent: signalQualityPercent,
      );
    }

    return EvaluationResult(
      criterion: heartRateRestCriterion,
      measuredValue: bpm,
      observedContext: context,
      severity: (bpm < 50.0 || bpm > 120.0)
          ? EvaluationSeverity.clinicalAttention
          : EvaluationSeverity.contextualWarning,
      interpretation: bpm < 60.0
          ? 'FC en reposo ${bpm.toStringAsFixed(0)} lpm por debajo de 60 lpm. Confirmar si corresponde a bradicardia atlética basal.'
          : 'FC en reposo ${bpm.toStringAsFixed(0)} lpm superior al rango AHA (incluso ajustando +3.44 lpm orbital). Evaluar hidratación, fiebre o estrés autonómico.',
      scientificCaution: heartRateRestCriterion.limitations,
      signalQualityPercent: signalQualityPercent,
    );
  }

  EvaluationResult evaluateRespiratoryRate({
    required double rpm,
    required ActivityContext context,
    double signalQualityPercent = 96.0,
  }) {
    if (signalQualityPercent < 80.0) {
      return EvaluationResult(
        criterion: respiratoryRateRestCriterion,
        measuredValue: rpm,
        observedContext: context,
        severity: EvaluationSeverity.notApplicable,
        interpretation:
            'Señal inductiva torácica degradada (${signalQualityPercent.toStringAsFixed(0)}%). Verificar ajuste del chaleco Bio-Monitor.',
        scientificCaution: respiratoryRateRestCriterion.limitations,
        signalQualityPercent: signalQualityPercent,
      );
    }

    if (context == ActivityContext.physicalActivity || context == ActivityContext.eva) {
      return EvaluationResult(
        criterion: respiratoryRateRestCriterion,
        measuredValue: rpm,
        observedContext: context,
        severity: rpm > 36.0
            ? EvaluationSeverity.contextualWarning
            : EvaluationSeverity.notApplicable,
        interpretation: rpm > 36.0
            ? 'Taquipnea marcada (${rpm.toStringAsFixed(0)} rpm) durante ${context.label}. Revisar PPCO2 y esfuerzo.'
            : 'FR ${rpm.toStringAsFixed(0)} rpm esperada durante esfuerzo (${context.label}).',
        scientificCaution: respiratoryRateRestCriterion.limitations,
        signalQualityPercent: signalQualityPercent,
      );
    }

    final minVal = context == ActivityContext.sleep ? 10.0 : 12.0;
    final maxVal = context == ActivityContext.sleep ? 20.0 : 20.0;
    if (rpm >= minVal && rpm <= maxVal) {
      return EvaluationResult(
        criterion: respiratoryRateRestCriterion,
        measuredValue: rpm,
        observedContext: context,
        severity: EvaluationSeverity.normal,
        interpretation:
            'Frecuencia respiratoria (${rpm.toStringAsFixed(1)} rpm) en rango normopneico (${minVal.toInt()}-${maxVal.toInt()} rpm).',
        scientificCaution: respiratoryRateRestCriterion.limitations,
        signalQualityPercent: signalQualityPercent,
      );
    }

    return EvaluationResult(
      criterion: respiratoryRateRestCriterion,
      measuredValue: rpm,
      observedContext: context,
      severity: (rpm < 9.0 || rpm > 26.0)
          ? EvaluationSeverity.clinicalAttention
          : EvaluationSeverity.contextualWarning,
      interpretation: rpm < minVal
          ? 'Bradipnea (${rpm.toStringAsFixed(1)} rpm < $minVal rpm). Verificar SpO2, nivel de conciencia y posible depresión respiratoria.'
          : 'Taquipnea (${rpm.toStringAsFixed(1)} rpm > 20 rpm). Correlacionar inmediatamente con PPCO2 ambiental en cabina y SpO2.',
      scientificCaution: respiratoryRateRestCriterion.limitations,
      signalQualityPercent: signalQualityPercent,
    );
  }

  EvaluationResult evaluateSpO2({
    required double spo2Percent,
    double signalQualityPercent = 96.0,
  }) {
    if (signalQualityPercent < 80.0) {
      return EvaluationResult(
        criterion: spo2Criterion,
        measuredValue: spo2Percent,
        observedContext: ActivityContext.rest,
        severity: EvaluationSeverity.notApplicable,
        interpretation:
            'Calidad de pulsioximetría insuficiente (${signalQualityPercent.toStringAsFixed(0)}%). Recalibrar sensor antes de interpretar.',
        scientificCaution: spo2Criterion.limitations,
        signalQualityPercent: signalQualityPercent,
      );
    }

    if (spo2Percent >= 95.0) {
      return EvaluationResult(
        criterion: spo2Criterion,
        measuredValue: spo2Percent,
        observedContext: ActivityContext.rest,
        severity: EvaluationSeverity.normal,
        interpretation:
            'SpO2 ${spo2Percent.toStringAsFixed(1)}% dentro de saturación arterial adecuada (>= 95%).',
        scientificCaution: spo2Criterion.limitations,
        signalQualityPercent: signalQualityPercent,
      );
    }

    if (spo2Percent >= 92.0) {
      return EvaluationResult(
        criterion: spo2Criterion,
        measuredValue: spo2Percent,
        observedContext: ActivityContext.rest,
        severity: EvaluationSeverity.contextualWarning,
        interpretation:
            'SpO2 ${spo2Percent.toStringAsFixed(1)}% ligeramente reducida (92%-94%). Verificar perfusión periférica, O2 de cabina y repetir en reposo.',
        scientificCaution: spo2Criterion.limitations,
        signalQualityPercent: signalQualityPercent,
      );
    }

    return EvaluationResult(
      criterion: spo2Criterion,
      measuredValue: spo2Percent,
      observedContext: ActivityContext.rest,
      severity: EvaluationSeverity.clinicalAttention,
      interpretation:
          'Hipoxemia significativa (SpO2 ${spo2Percent.toStringAsFixed(1)}% < 92%). Evaluar integridad atmosférica, O2 suplementario y soporte clínico inmediato.',
      scientificCaution: spo2Criterion.limitations,
      signalQualityPercent: signalQualityPercent,
    );
  }

  EvaluationResult evaluateCoreTemperatureHeatFlux({
    required double tempCelsius,
    required ActivityContext context,
    double signalQualityPercent = 97.0,
  }) {
    final bool isActive =
        context == ActivityContext.physicalActivity || context == ActivityContext.eva;
    final double maxNormal = isActive ? 38.4 : 37.5;
    final double minNormal = 36.0;

    if (tempCelsius >= minNormal && tempCelsius <= maxNormal) {
      return EvaluationResult(
        criterion: coreTempHeatFluxCriterion,
        measuredValue: tempCelsius,
        observedContext: context,
        severity: EvaluationSeverity.normal,
        interpretation:
            'Temperatura central Heat-Flux (Draeger Double Sensor): ${tempCelsius.toStringAsFixed(2)} °C dentro del margen esperado para ${context.label}.',
        scientificCaution: coreTempHeatFluxCriterion.limitations,
        signalQualityPercent: signalQualityPercent,
      );
    }

    final bool critical = tempCelsius >= 38.8 || tempCelsius < 35.2;
    return EvaluationResult(
      criterion: coreTempHeatFluxCriterion,
      measuredValue: tempCelsius,
      observedContext: context,
      severity: critical
          ? EvaluationSeverity.clinicalAttention
          : EvaluationSeverity.contextualWarning,
      interpretation: tempCelsius > maxNormal
          ? 'Elevación térmica central (${tempCelsius.toStringAsFixed(2)} °C > $maxNormal °C). En 0 g la falta de convección aumenta riesgo de estrés térmico o proceso febril.'
          : 'Descenso térmico central (${tempCelsius.toStringAsFixed(2)} °C < $minNormal °C). Verificar contacto de parche térmico y temperatura de traje/cabina.',
      scientificCaution: coreTempHeatFluxCriterion.limitations,
      signalQualityPercent: signalQualityPercent,
    );
  }

  EvaluationResult evaluateHydrationBioimpedance({
    required double rawIndexPercent,
    required int missionDay,
    bool inMicrogravity = true,
    double signalQualityPercent = 92.0,
  }) {
    final double compensation = (inMicrogravity && missionDay >= 2) ? 3.5 : 0.0;
    final double calibrated = (rawIndexPercent - compensation).clamp(0.0, 100.0);

    if (calibrated >= 70.0) {
      return EvaluationResult(
        criterion: hydrationBisCriterion,
        measuredValue: calibrated,
        observedContext: ActivityContext.rest,
        severity: EvaluationSeverity.normal,
        interpretation:
            'Hidratación BIS calibrada: ${calibrated.toStringAsFixed(1)}% (crudo ${rawIndexPercent.toStringAsFixed(1)}%, ajuste fluid-shift -${compensation.toStringAsFixed(1)}%). Euhidratación.',
        scientificCaution: hydrationBisCriterion.limitations,
        signalQualityPercent: signalQualityPercent,
      );
    }

    if (calibrated >= 64.0) {
      return EvaluationResult(
        criterion: hydrationBisCriterion,
        measuredValue: calibrated,
        observedContext: ActivityContext.rest,
        severity: EvaluationSeverity.contextualWarning,
        interpretation:
            'Déficit hídrico leve-moderado por BIS calibrada (${calibrated.toStringAsFixed(1)}% < 70%). Reforzar hidratación oral y monitorear litiasis renal.',
        scientificCaution: hydrationBisCriterion.limitations,
        signalQualityPercent: signalQualityPercent,
      );
    }

    return EvaluationResult(
      criterion: hydrationBisCriterion,
      measuredValue: calibrated,
      observedContext: ActivityContext.rest,
      severity: EvaluationSeverity.clinicalAttention,
      interpretation:
          'Deshidratación crítica por BIS calibrada (${calibrated.toStringAsFixed(1)}% < 64%). Riesgo elevado de intolerancia ortostática y nefrolitiasis en órbita.',
      scientificCaution: hydrationBisCriterion.limitations,
      signalQualityPercent: signalQualityPercent,
    );
  }

  // ===========================================================================
  // 2. DIMENSIÓN NEUROLÓGICA Y SENSORIAL (MEDICIÓN PASIVA CONTINUA)
  // ===========================================================================

  EvaluationResult evaluatePassivePupillometry({
    required double pupilDiameterMm,
    required double npi,
    required double plrLatencyMs,
    double blinkRatePerMin = 15.0,
    double microsaccadeVelocityDegPerSec = 42.0,
    double signalQualityPercent = 97.0,
  }) {
    if (signalQualityPercent < 80.0) {
      return EvaluationResult(
        criterion: pupillometryNpiCriterion,
        measuredValue: npi,
        observedContext: ActivityContext.rest,
        severity: EvaluationSeverity.notApplicable,
        interpretation:
            'Calidad IR de eye-tracking insuficiente (${signalQualityPercent.toStringAsFixed(0)}%). Limpiar ópticas de visor Tobii/Pupil.',
        scientificCaution: pupillometryNpiCriterion.limitations,
        signalQualityPercent: signalQualityPercent,
      );
    }

    final bool abnormalNpi = npi < 3.0;
    final bool abnormalPlr = plrLatencyMs > 280.0;
    final bool abnormalMicrosaccades = microsaccadeVelocityDegPerSec < 22.0;
    final bool abnormalDiameter = pupilDiameterMm < 2.0 || pupilDiameterMm > 7.0;

    if (!abnormalNpi && !abnormalPlr && !abnormalMicrosaccades && !abnormalDiameter) {
      return EvaluationResult(
        criterion: pupillometryNpiCriterion,
        measuredValue: npi,
        observedContext: ActivityContext.rest,
        severity: EvaluationSeverity.normal,
        interpretation:
            'Pupilometría pasiva nominal: NPi ${npi.toStringAsFixed(2)}, diámetro ${pupilDiameterMm.toStringAsFixed(2)} mm, PLR ${plrLatencyMs.toStringAsFixed(0)} ms, parpadeo ${blinkRatePerMin.toStringAsFixed(0)}/min.',
        scientificCaution: pupillometryNpiCriterion.limitations,
        signalQualityPercent: signalQualityPercent,
      );
    }

    return EvaluationResult(
      criterion: pupillometryNpiCriterion,
      measuredValue: npi,
      observedContext: ActivityContext.rest,
      severity: (npi < 2.5 || plrLatencyMs > 340.0)
          ? EvaluationSeverity.clinicalAttention
          : EvaluationSeverity.contextualWarning,
      interpretation:
          'Alteración pupilar/oculomotora pasiva (NPi ${npi.toStringAsFixed(2)}, PLR ${plrLatencyMs.toStringAsFixed(0)} ms, micro-sacadas ${microsaccadeVelocityDegPerSec.toStringAsFixed(0)} °/s). Posible fatiga autonómica de tronco encefálico o aumento de presión intracraneal.',
      scientificCaution: pupillometryNpiCriterion.limitations,
      signalQualityPercent: signalQualityPercent,
    );
  }

  EvaluationResult evaluatePassiveHyperopicShiftToF({
    required double nearFocusCm,
    required double estimatedShiftDiopters,
    double signalQualityPercent = 97.0,
  }) {
    if (nearFocusCm <= 35.0 && estimatedShiftDiopters < 0.50) {
      return EvaluationResult(
        criterion: hyperopicShiftToFCriterion,
        measuredValue: nearFocusCm,
        observedContext: ActivityContext.rest,
        severity: EvaluationSeverity.normal,
        interpretation:
            'Distancia de enfoque ToF (${nearFocusCm.toStringAsFixed(1)} cm) y estimación refractiva (+${estimatedShiftDiopters.toStringAsFixed(2)} D) sin signos de desplazamiento hiperópico SANS.',
        scientificCaution: hyperopicShiftToFCriterion.limitations,
        signalQualityPercent: signalQualityPercent,
      );
    }

    final bool highShift = nearFocusCm > 42.0 || estimatedShiftDiopters >= 1.0;
    return EvaluationResult(
      criterion: hyperopicShiftToFCriterion,
      measuredValue: nearFocusCm,
      observedContext: ActivityContext.rest,
      severity: highShift
          ? EvaluationSeverity.clinicalAttention
          : EvaluationSeverity.contextualWarning,
      interpretation:
          'Alejamiento de lectura pasivo ToF (${nearFocusCm.toStringAsFixed(1)} cm, shift estimado +${estimatedShiftDiopters.toStringAsFixed(2)} D). Marcador temprano de Síndrome Neuro-Ocular (SANS); programar tonometría, fondo de ojo y ultrasonido ONSD.',
      scientificCaution: hyperopicShiftToFCriterion.limitations,
      signalQualityPercent: signalQualityPercent,
    );
  }

  EvaluationResult evaluatePassiveBackgroundPvt({
    required double reactionMs,
    required int lapsesCount,
    required double pointerAccuracyPercent,
    double signalQualityPercent = 96.0,
  }) {
    if (reactionMs <= 355.0 && lapsesCount <= 2 && pointerAccuracyPercent >= 90.0) {
      return EvaluationResult(
        criterion: passivePvtCriterion,
        measuredValue: reactionMs,
        observedContext: ActivityContext.rest,
        severity: EvaluationSeverity.normal,
        interpretation:
            'Vigilancia psicomotriz pasiva (PVT-B) nominal: latencia media ${reactionMs.toStringAsFixed(0)} ms, lapsos (>500 ms) $lapsesCount, precisión táctil ${pointerAccuracyPercent.toStringAsFixed(1)}%.',
        scientificCaution: passivePvtCriterion.limitations,
        signalQualityPercent: signalQualityPercent,
      );
    }

    final bool severe = reactionMs >= 420.0 || lapsesCount >= 5 || pointerAccuracyPercent < 82.0;
    return EvaluationResult(
      criterion: passivePvtCriterion,
      measuredValue: reactionMs,
      observedContext: ActivityContext.rest,
      severity: severe
          ? EvaluationSeverity.clinicalAttention
          : EvaluationSeverity.contextualWarning,
      interpretation:
          'Deterioro de vigilancia psicomotriz pasiva (${reactionMs.toStringAsFixed(0)} ms, $lapsesCount lapsos >500 ms, precisión ${pointerAccuracyPercent.toStringAsFixed(1)}%). Restringir tareas críticas (robótica/EVA) hasta evaluar sueño y PPCO2.',
      scientificCaution: passivePvtCriterion.limitations,
      signalQualityPercent: signalQualityPercent,
    );
  }

  // ===========================================================================
  // 3. DIMENSIÓN MUSCULOESQUELÉTICA
  // ===========================================================================

  EvaluationResult evaluateInertialBiomechanics({
    required double rmsG,
    required double peakImpactG,
    required double strideCadenceStepsPerMin,
    required ActivityContext context,
  }) {
    if (peakImpactG >= 2.5) {
      return EvaluationResult(
        criterion: inertialImuCriterion,
        measuredValue: peakImpactG,
        observedContext: context,
        severity: EvaluationSeverity.clinicalAttention,
        interpretation:
            'Impacto inercial brusco detectado (${peakImpactG.toStringAsFixed(2)} g >= 2.5 g) por IMU vestible. Activar verificación inmediata de traumatismo o caída.',
        scientificCaution: inertialImuCriterion.limitations,
      );
    }

    return EvaluationResult(
      criterion: inertialImuCriterion,
      measuredValue: peakImpactG,
      observedContext: context,
      severity: EvaluationSeverity.normal,
      interpretation:
          'Inercia biomecánica sin impactos anómalos (pico ${peakImpactG.toStringAsFixed(2)} g, RMS ${rmsG.toStringAsFixed(3)} g, cadencia ${strideCadenceStepsPerMin.toStringAsFixed(0)} pasos/min).',
      scientificCaution: inertialImuCriterion.limitations,
    );
  }

  EvaluationResult evaluateLocalizedMuscleBioimpedance({
    required double volumeRetentionPercent,
    required double pennationAngleDeg,
    required double calibratedHydrationIndex,
    double signalQualityPercent = 94.0,
  }) {
    final bool hydrationBiasRisk = calibratedHydrationIndex < 68.0;
    if (volumeRetentionPercent >= 80.0 && !hydrationBiasRisk) {
      return EvaluationResult(
        criterion: muscleBioimpedanceCriterion,
        measuredValue: volumeRetentionPercent,
        observedContext: ActivityContext.rest,
        severity: EvaluationSeverity.normal,
        interpretation:
            'Retención volumétrica muscular en cuádriceps/gastrocnemio del ${volumeRetentionPercent.toStringAsFixed(1)}% (ángulo de pennación ${pennationAngleDeg.toStringAsFixed(1)}°) conforme al objetivo >= 80%.',
        scientificCaution: muscleBioimpedanceCriterion.limitations,
        signalQualityPercent: signalQualityPercent,
      );
    }

    if (volumeRetentionPercent < 75.0) {
      return EvaluationResult(
        criterion: muscleBioimpedanceCriterion,
        measuredValue: volumeRetentionPercent,
        observedContext: ActivityContext.rest,
        severity: EvaluationSeverity.clinicalAttention,
        interpretation:
            'Atrofia muscular progresiva relevante (${volumeRetentionPercent.toStringAsFixed(1)}% < 75%, pennación ${pennationAngleDeg.toStringAsFixed(1)}°). Ajustar inmediatamente carga resistiva ARED e ingesta proteica.',
        scientificCaution: muscleBioimpedanceCriterion.limitations,
        signalQualityPercent: signalQualityPercent,
      );
    }

    return EvaluationResult(
      criterion: muscleBioimpedanceCriterion,
      measuredValue: volumeRetentionPercent,
      observedContext: ActivityContext.rest,
      severity: EvaluationSeverity.contextualWarning,
      interpretation: hydrationBiasRisk
          ? 'Bioimpedancia muscular ${volumeRetentionPercent.toStringAsFixed(1)}% potencialmente sesgada por déficit hídrico BIS (${calibratedHydrationIndex.toStringAsFixed(1)}%). Corregir hidratación y reevaluar.'
          : 'Tendencia de reducción muscular (${volumeRetentionPercent.toStringAsFixed(1)}% < 80%). Reforzar protocolo ARED en miembros inferiores.',
      scientificCaution: muscleBioimpedanceCriterion.limitations,
      signalQualityPercent: signalQualityPercent,
    );
  }

  EvaluationResult evaluateMuscleStrength({
    required double retentionPercent,
    required bool comparableBaselineProtocol,
  }) {
    if (!comparableBaselineProtocol) {
      return EvaluationResult(
        criterion: muscleStrengthCriterion,
        measuredValue: retentionPercent,
        observedContext: ActivityContext.physicalActivity,
        severity: EvaluationSeverity.notApplicable,
        interpretation:
            'Sin protocolo instrumental equivalente pre-misión; la retención de ${retentionPercent.toStringAsFixed(1)}% no es comparable bajo NASA-STD-3001 V1 4024.',
        scientificCaution: muscleStrengthCriterion.limitations,
      );
    }

    if (retentionPercent >= 80.0) {
      return EvaluationResult(
        criterion: muscleStrengthCriterion,
        measuredValue: retentionPercent,
        observedContext: ActivityContext.physicalActivity,
        severity: EvaluationSeverity.normal,
        interpretation:
            'Retención de fuerza muscular ${retentionPercent.toStringAsFixed(1)}% cumple estándar NASA-STD-3001 (>= 80% respecto a basal).',
        scientificCaution: muscleStrengthCriterion.limitations,
      );
    }

    return EvaluationResult(
      criterion: muscleStrengthCriterion,
      measuredValue: retentionPercent,
      observedContext: ActivityContext.physicalActivity,
      severity: EvaluationSeverity.contextualWarning,
      interpretation:
          'Retención de fuerza ${retentionPercent.toStringAsFixed(1)}% por debajo del límite operacional del 80%. Revisar adherencia a ARED y nutrición.',
      scientificCaution: muscleStrengthCriterion.limitations,
    );
  }

  // ===========================================================================
  // 4. DIMENSIÓN CIRCADIANA Y PSICOEMOCIONAL + ACTIGRAFÍA BIMODAL
  // ===========================================================================

  EvaluationResult evaluateSleepDuration({
    required double hours,
    required ActivityContext context,
    bool viaActigraphy = true,
  }) {
    final String methodNote = viaActigraphy
        ? 'Medición actigráfica pasiva (concordancia 90%-95% con PSG en duración).'
        : 'Autorregistro subjetivo de sueño.';

    if (hours >= 7.0 && hours <= 9.0) {
      return EvaluationResult(
        criterion: sleepDurationCriterion,
        measuredValue: hours,
        observedContext: context,
        severity: EvaluationSeverity.normal,
        interpretation:
            'Duración de sueño ${hours.toStringAsFixed(1)} h dentro del rango NSF/AASM (7-9 h). $methodNote',
        scientificCaution: sleepDurationCriterion.limitations,
      );
    }

    if (hours < 7.0) {
      return EvaluationResult(
        criterion: sleepDurationCriterion,
        measuredValue: hours,
        observedContext: context,
        severity: hours < 5.5
            ? EvaluationSeverity.clinicalAttention
            : EvaluationSeverity.contextualWarning,
        interpretation:
            'Restricción de sueño (${hours.toStringAsFixed(1)} h < 7 h). Riesgo directo de deterioro en PVT-B, estado de ánimo y respuesta inmunológica. $methodNote',
        scientificCaution: sleepDurationCriterion.limitations,
      );
    }

    return EvaluationResult(
      criterion: sleepDurationCriterion,
      measuredValue: hours,
      observedContext: context,
      severity: EvaluationSeverity.contextualWarning,
      interpretation:
          'Duración de sueño extendida (${hours.toStringAsFixed(1)} h > 9 h). Evaluar fatiga acumulada, recuperación post-EVA o desalineación circadiana. $methodNote',
      scientificCaution: sleepDurationCriterion.limitations,
    );
  }

  EvaluationResult evaluateNocturnalAutonomicHrv({
    required double nocturnalRmssdMs,
    required double nocturnalSdnnMs,
    required double sleepEfficiencyPercent,
    required double sleepFragmentationIndex,
    required double sleepRegularityIndex,
    double signalQualityPercent = 96.0,
  }) {
    final bool lowHrv = nocturnalRmssdMs < 30.0;
    final bool poorEfficiency = sleepEfficiencyPercent < 85.0;
    final bool highFragmentation = sleepFragmentationIndex > 20.0;
    final bool irregularSchedule = sleepRegularityIndex < 75.0;

    if (!lowHrv && !poorEfficiency && !highFragmentation && !irregularSchedule) {
      return EvaluationResult(
        criterion: nocturnalHrvCriterion,
        measuredValue: nocturnalRmssdMs,
        observedContext: ActivityContext.sleep,
        severity: EvaluationSeverity.normal,
        interpretation:
            'Recuperación autonómica nocturna óptima: RMSSD ${nocturnalRmssdMs.toStringAsFixed(0)} ms, SDNN ${nocturnalSdnnMs.toStringAsFixed(0)} ms, eficiencia ${sleepEfficiencyPercent.toStringAsFixed(0)}%, SRI ${sleepRegularityIndex.toStringAsFixed(0)}%.',
        scientificCaution: nocturnalHrvCriterion.limitations,
        signalQualityPercent: signalQualityPercent,
      );
    }

    return EvaluationResult(
      criterion: nocturnalHrvCriterion,
      measuredValue: nocturnalRmssdMs,
      observedContext: ActivityContext.sleep,
      severity: (nocturnalRmssdMs < 20.0 || sleepEfficiencyPercent < 75.0)
          ? EvaluationSeverity.clinicalAttention
          : EvaluationSeverity.contextualWarning,
      interpretation:
          'Estrés autonómico o fragmentación nocturna detectada (RMSSD ${nocturnalRmssdMs.toStringAsFixed(0)} ms, eficiencia ${sleepEfficiencyPercent.toStringAsFixed(0)}%, fragmentación ${sleepFragmentationIndex.toStringAsFixed(1)}%, SRI ${sleepRegularityIndex.toStringAsFixed(0)}%). Implementar fototerapia circadiana y descarga operativa.',
      scientificCaution: nocturnalHrvCriterion.limitations,
      signalQualityPercent: signalQualityPercent,
    );
  }

  EvaluationResult evaluateNocturnalIntegratedVitals({
    required double nocturnalHrMeanBpm,
    required double nocturnalRrMeanRpm,
    required double nocturnalSpO2MeanPercent,
    required int desaturationEvents,
    double signalQualityPercent = 95.0,
  }) {
    if (nocturnalSpO2MeanPercent >= 94.0 &&
        desaturationEvents == 0 &&
        nocturnalRrMeanRpm >= 10.0 &&
        nocturnalRrMeanRpm <= 20.0) {
      return EvaluationResult(
        criterion: nocturnalIntegratedVitalsCriterion,
        measuredValue: nocturnalSpO2MeanPercent,
        observedContext: ActivityContext.sleep,
        severity: EvaluationSeverity.normal,
        interpretation:
            'Vitales nocturnos integrados estables: FC media ${nocturnalHrMeanBpm.toStringAsFixed(0)} lpm, FR media ${nocturnalRrMeanRpm.toStringAsFixed(1)} rpm, SpO2 media ${nocturnalSpO2MeanPercent.toStringAsFixed(1)}%, 0 desaturaciones.',
        scientificCaution: nocturnalIntegratedVitalsCriterion.limitations,
        signalQualityPercent: signalQualityPercent,
      );
    }

    return EvaluationResult(
      criterion: nocturnalIntegratedVitalsCriterion,
      measuredValue: nocturnalSpO2MeanPercent,
      observedContext: ActivityContext.sleep,
      severity: (nocturnalSpO2MeanPercent < 92.0 || desaturationEvents >= 3)
          ? EvaluationSeverity.clinicalAttention
          : EvaluationSeverity.contextualWarning,
      interpretation:
          'Anomalía en vitales nocturnos (SpO2 media ${nocturnalSpO2MeanPercent.toStringAsFixed(1)}%, $desaturationEvents desaturaciones, FR ${nocturnalRrMeanRpm.toStringAsFixed(1)} rpm). Verificar flujo de ventilación en litera (acumulación localizada de CO2 en 0 g) y descartar hipopnea.',
      scientificCaution: nocturnalIntegratedVitalsCriterion.limitations,
      signalQualityPercent: signalQualityPercent,
    );
  }

  ActigraphyBimodalAssessment evaluateActigraphyBimodal({
    required double hrvRmssdMs,
    double hrvSdnnMs = 0.0,
    required double actigraphyAxisG,
    required ActivityContext context,
    double signalQualityPercent = 96.0,
  }) {
    final bool isPhysicallyActive = actigraphyAxisG >= 0.15 ||
        context == ActivityContext.physicalActivity ||
        context == ActivityContext.eva;

    if (isPhysicallyActive) {
      return ActigraphyBimodalAssessment(
        severity: EvaluationSeverity.notApplicable,
        hrvValidWindow: false,
        stateLabel: 'Ventana activa / Ejercicio (${actigraphyAxisG.toStringAsFixed(2)} g)',
        interpretation:
            'Fusión bimodal bloqueó análisis de HRV como estrés autonómico debido a actividad física detectada por acelerometría triaxial.',
        telemetryNote:
            'RMSSD=${hrvRmssdMs.toStringAsFixed(1)} ms y SDNN=${hrvSdnnMs.toStringAsFixed(1)} ms archivados solo para perfil metabólico de esfuerzo.',
        sources: const ['NASA LSDA / PhysioNet WESAD', 'NASA-HRP Bimodal Actigraphy'],
      );
    }

    if (signalQualityPercent < 80.0) {
      return ActigraphyBimodalAssessment(
        severity: EvaluationSeverity.notApplicable,
        hrvValidWindow: false,
        stateLabel: 'Artefacto de señal (${signalQualityPercent.toStringAsFixed(0)}%)',
        interpretation:
            'Ventana de reposo descartada por baja calidad de contacto de electrodos Bio-Monitor.',
        telemetryNote: 'Repetir captura tras reposo inmóvil de 5 minutos.',
        sources: const ['Mendes Zambetta et al. (2024)'],
      );
    }

    final bool autonomicStress = hrvRmssdMs < 30.0;
    return ActigraphyBimodalAssessment(
      severity: autonomicStress
          ? EvaluationSeverity.contextualWarning
          : EvaluationSeverity.normal,
      hrvValidWindow: true,
      stateLabel: 'Ventana válida de inmovilidad (${actigraphyAxisG.toStringAsFixed(3)} g)',
      interpretation: autonomicStress
          ? 'Predominio simpático / estrés fisiológico detectado en reposo confirmado (RMSSD ${hrvRmssdMs.toStringAsFixed(1)} ms < 30 ms).'
          : 'Equilibrio vagal-autonómico adecuado en reposo confirmado (RMSSD ${hrvRmssdMs.toStringAsFixed(1)} ms, SDNN ${hrvSdnnMs.toStringAsFixed(1)} ms).',
      telemetryNote: 'Fusión bimodal Actigrafía + HRV validada sin contaminación cinética.',
      sources: const [
        'NASA LSDA / PhysioNet WESAD',
        'Mendes Zambetta et al. (2024)',
      ],
    );
  }

  // ===========================================================================
  // EVALUACIÓN INTEGRAL DE LAS 4 DIMENSIONES PASIVAS
  // ===========================================================================

  PassiveDimensionEvaluation evaluateAllPassiveDimensions({
    required VitalsRecord vitals,
    required double sleepHours,
    ActivityContext context = ActivityContext.rest,
    bool inMicrogravity = true,
    double signalQualityPercent = 97.0,
    double muscleStrengthRetentionPercent = 92.0,
  }) {
    final results = <EvaluationResult>[
      // Dimensión 1: Cardiorrespiratoria y Metabólica
      evaluateHeartRate(
        bpm: vitals.heartRate,
        context: context,
        signalQualityPercent: signalQualityPercent,
        inMicrogravity: inMicrogravity,
      ),
      evaluateRespiratoryRate(
        rpm: vitals.respiratoryRate,
        context: context,
        signalQualityPercent: signalQualityPercent,
      ),
      evaluateSpO2(
        spo2Percent: vitals.spO2,
        signalQualityPercent: signalQualityPercent,
      ),
      evaluateCoreTemperatureHeatFlux(
        tempCelsius: vitals.coreTempHeatFluxC,
        context: context,
        signalQualityPercent: signalQualityPercent,
      ),
      evaluateHydrationBioimpedance(
        rawIndexPercent: vitals.hydrationBioimpedanceIndex,
        missionDay: vitals.missionDay,
        inMicrogravity: inMicrogravity,
        signalQualityPercent: signalQualityPercent,
      ),
      // Dimensión 2: Neurológica y Sensorial
      evaluatePassivePupillometry(
        pupilDiameterMm: vitals.pupilDiameterMm,
        npi: vitals.pupillometryNpi,
        plrLatencyMs: vitals.plrLatencyMs,
        blinkRatePerMin: vitals.blinkRatePerMin,
        microsaccadeVelocityDegPerSec: vitals.microsaccadeVelocityDegPerSec,
        signalQualityPercent: signalQualityPercent,
      ),
      evaluatePassiveHyperopicShiftToF(
        nearFocusCm: vitals.passiveNearFocusCm,
        estimatedShiftDiopters: vitals.estimatedHyperopicShiftDiopters,
        signalQualityPercent: signalQualityPercent,
      ),
      evaluatePassiveBackgroundPvt(
        reactionMs: vitals.passivePvtReactionMs,
        lapsesCount: vitals.passivePvtLapsesCount,
        pointerAccuracyPercent: vitals.touchPointerAccuracyPercent,
        signalQualityPercent: signalQualityPercent,
      ),
      // Dimensión 3: Musculoesquelética
      evaluateInertialBiomechanics(
        rmsG: vitals.accelerometryRmsG,
        peakImpactG: vitals.peakImpactG,
        strideCadenceStepsPerMin: vitals.strideCadenceStepsPerMin,
        context: context,
      ),
      evaluateLocalizedMuscleBioimpedance(
        volumeRetentionPercent: vitals.muscleVolumeRetentionPercent,
        pennationAngleDeg: vitals.pennationAngleDeg,
        calibratedHydrationIndex: vitals.calibratedHydrationIndex,
        signalQualityPercent: signalQualityPercent,
      ),
      evaluateMuscleStrength(
        retentionPercent: muscleStrengthRetentionPercent,
        comparableBaselineProtocol: true,
      ),
      // Dimensión 4: Circadiana y Psicoemocional
      evaluateSleepDuration(
        hours: sleepHours,
        context: ActivityContext.sleep,
        viaActigraphy: true,
      ),
      evaluateNocturnalAutonomicHrv(
        nocturnalRmssdMs: vitals.nocturnalHrvRmssdMs,
        nocturnalSdnnMs: vitals.nocturnalHrvSdnnMs,
        sleepEfficiencyPercent: vitals.sleepEfficiencyPercent,
        sleepFragmentationIndex: vitals.sleepFragmentationIndex,
        sleepRegularityIndex: vitals.sleepRegularityIndex,
        signalQualityPercent: signalQualityPercent,
      ),
      evaluateNocturnalIntegratedVitals(
        nocturnalHrMeanBpm: vitals.nocturnalHeartRateMeanBpm,
        nocturnalRrMeanRpm: vitals.nocturnalRespiratoryRateMeanRpm,
        nocturnalSpO2MeanPercent: vitals.nocturnalSpO2MeanPercent,
        desaturationEvents: vitals.nocturnalDesaturationEvents,
        signalQualityPercent: signalQualityPercent,
      ),
    ];

    final actigraphyBimodal = evaluateActigraphyBimodal(
      hrvRmssdMs: vitals.hrvRmssdMs,
      hrvSdnnMs: vitals.hrvSdnnMs,
      actigraphyAxisG: vitals.accelerometryRmsG,
      context: context,
      signalQualityPercent: signalQualityPercent,
    );

    final Map<String, EvaluationSeverity> dimSeverity = {};
    for (final dim in PassiveHealthDimension.values) {
      final dimResults = results.where((r) => r.criterion.dimension == dim);
      dimSeverity[dim.id] = _maxSeverity(
        dimResults.map((r) => r.severity).followedBy(
              dim == PassiveHealthDimension.cardiorespiratoryMetabolic
                  ? [actigraphyBimodal.severity]
                  : const [],
            ),
      );
    }

    final overall = _maxSeverity(dimSeverity.values);
    final alerts = <String>[
      for (final r in results)
        if (r.hasWarning) '[${r.criterion.dimension.label}] ${r.interpretation}',
      if (actigraphyBimodal.severity == EvaluationSeverity.contextualWarning)
        '[Actigrafía Bimodal] ${actigraphyBimodal.interpretation}',
    ];

    final recommendations = _buildRecommendations(results, vitals, actigraphyBimodal);

    return PassiveDimensionEvaluation(
      evaluatedAt: DateTime.now().toUtc(),
      activityContext: context,
      inMicrogravity: inMicrogravity,
      overallSeverity: overall,
      results: results,
      actigraphyBimodal: actigraphyBimodal,
      dimensionSeverities: dimSeverity,
      alerts: alerts,
      recommendations: recommendations,
    );
  }

  EvaluationSeverity _maxSeverity(Iterable<EvaluationSeverity> severities) {
    var best = EvaluationSeverity.normal;
    for (final s in severities) {
      if (s == EvaluationSeverity.clinicalAttention) {
        return EvaluationSeverity.clinicalAttention;
      }
      if (s == EvaluationSeverity.contextualWarning) {
        best = EvaluationSeverity.contextualWarning;
      }
    }
    return best;
  }

  List<String> _buildRecommendations(
    List<EvaluationResult> results,
    VitalsRecord vitals,
    ActigraphyBimodalAssessment bimodal,
  ) {
    final recs = <String>[];
    for (final r in results) {
      if (!r.hasWarning) continue;
      switch (r.criterion.id) {
        case 'hydration_bis_fluid_shift':
          recs.add('Aumentar ingesta de líquidos isotónicos y registrar diuresis 24 h para prevenir litiasis.');
          break;
        case 'hyperopic_shift_tof_passive':
        case 'eye_tracking_pupillometry_npi':
          recs.add('Completar chequeo dirigido de SANS (agudeza cercana y ultrasonido ONSD) y reportar a Flight Surgeon.');
          break;
        case 'passive_background_pvt_b':
        case 'sleep_duration_nsf_aasm':
        case 'nocturnal_hrv_autonomic_recovery':
          recs.add('Priorizar ventana de descanso de 7-9 h, fototerapia circadiana y diferir maniobras críticas.');
          break;
        case 'inertial_imu_biomechanics':
          recs.add('Ejecutar revisión secundaria de trauma tras impacto >= 2.5 g.');
          break;
        case 'localized_muscle_bioimpedance':
        case 'muscle_strength_nasa_std_3001':
          recs.add('Reforzar contramedidas de resistencia (ARED) enfocadas en cuádriceps y gastrocnemio.');
          break;
        case 'nocturnal_integrated_vitals':
        case 'spo2_terrestrial_general':
        case 'rr_rest_general':
          recs.add('Auditar circulación de aire en cabina/litera (PPCO2 ${vitals.localCo2MmHg.toStringAsFixed(1)} mmHg, O2 ${vitals.localO2Percent.toStringAsFixed(1)}%).');
          break;
      }
    }
    if (bimodal.severity == EvaluationSeverity.contextualWarning && recs.isEmpty) {
      recs.add('Repetir captura de HRV en reposo inmóvil y reducir carga cognitiva temporalmente.');
    }
    if (recs.isEmpty) {
      recs.add('Todas las dimensiones pasivas en rango nominal; mantener rutina de contramedidas y monitoreo continuo.');
    }
    return recs.toSet().toList();
  }
}
