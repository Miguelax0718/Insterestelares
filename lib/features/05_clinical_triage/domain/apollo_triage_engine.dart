import '../../01_general_health/domain/scientific_criteria_engine.dart';
import '../../01_general_health/models/vitals_record.dart';
import '../models/triage_decision.dart';

/// Mensaje estructurado generado por el motor clínico ADA + APOLO.
class ApolloChatMessage {
  final String id;
  final bool isFromUser;
  final String text;
  final DateTime timestamp;
  final TriagePriority? priority;
  final TriageResult? triageResult;
  final List<String> referencedMetrics;
  final List<String> recommendedSupplies;
  final List<String> sources;
  final String triggeredRule;

  const ApolloChatMessage({
    required this.id,
    required this.isFromUser,
    required this.text,
    required this.timestamp,
    this.priority,
    this.triageResult,
    this.referencedMetrics = const [],
    this.recommendedSupplies = const [],
    this.sources = const [],
    this.triggeredRule = 'none',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'is_from_user': isFromUser,
        'text': text,
        'timestamp': timestamp.toIso8601String(),
        'priority': priority?.name,
        'triggered_rule': triggeredRule,
        'referenced_metrics': referencedMetrics,
        'recommended_supplies': recommendedSupplies,
        'sources': sources,
        'triage_result': triageResult == null
            ? null
            : {
                'condition_name': triageResult!.conditionName,
                'priority': triageResult!.priority.name,
                'immediate_actions': triageResult!.immediateActions,
                'required_supplies': triageResult!.requiredSupplies,
                'guide_asset_path': triageResult!.guideAssetPath,
                'algorithm': triageResult!.algorithm,
                'criterion_reference': triageResult!.criterionReference,
              },
      };
}

/// Motor clínico determinista Offline-First (ADA + APOLO) que cruza síntomas
/// reportados por el astronauta con las 4 dimensiones de medición automática
/// permanente y la telemetría ambiental de cabina.
class ApolloTriageEngine {
  final ScientificCriteriaEngine criteriaEngine;

  const ApolloTriageEngine({
    this.criteriaEngine = const ScientificCriteriaEngine(),
  });

  ApolloChatMessage processQuery({
    required String query,
    required VitalsRecord vitals,
    double sleepHours = 7.5,
    ActivityContext activityContext = ActivityContext.rest,
    bool inMicrogravity = true,
    double signalQualityPercent = 97.0,
    double muscleStrengthRetentionPercent = 92.0,
  }) {
    final lower = query.toLowerCase().trim();
    final now = DateTime.now().toUtc();
    final eval = criteriaEngine.evaluateAllPassiveDimensions(
      vitals: vitals,
      sleepHours: sleepHours,
      context: activityContext,
      inMicrogravity: inMicrogravity,
      signalQualityPercent: signalQualityPercent,
      muscleStrengthRetentionPercent: muscleStrengthRetentionPercent,
    );

    // Regla 1: Hipercapnia (CO2), Hipoxia o Alteración Cardiorrespiratoria
    final bool co2OrRespMatch = _containsAny(lower, const [
          'co2',
          'hipercapnia',
          'ahogo',
          'disnea',
          'aire',
          'respirar',
          'cefalea',
          'mareo',
          'hipoxia',
          'spo2',
        ]) ||
        vitals.localCo2MmHg >= 3.0 ||
        vitals.spO2 < 94.0 ||
        vitals.localO2Percent < 19.5 ||
        vitals.nocturnalDesaturationEvents >= 2;

    if (co2OrRespMatch) {
      final bool isRed = vitals.localCo2MmHg >= 5.0 ||
          vitals.spO2 < 92.0 ||
          vitals.localO2Percent < 18.5;
      final priority = isRed ? TriagePriority.red : TriagePriority.yellow;
      final actions = <String>[
        'Verificar de inmediato flujo de ventilación y depuradores CDRA (PPCO2=${vitals.localCo2MmHg.toStringAsFixed(2)} mmHg, O2=${vitals.localO2Percent.toStringAsFixed(1)}%).',
        'Correlacionar SpO2 continua (${vitals.spO2.toStringAsFixed(1)}%) y FR inductiva (${vitals.respiratoryRate.toStringAsFixed(1)} rpm) en reposo.',
        if (vitals.nocturnalDesaturationEvents > 0)
          'Revisar ventilación en zona de descanso por ${vitals.nocturnalDesaturationEvents} desaturaciones nocturnas registradas.',
        if (isRed)
          'Administrar O2 suplementario al 100%, trasladar a módulo ventilado y contactar al Flight Surgeon.',
      ];
      const supplies = ['Mascarilla O2 portátil', 'Oxímetro secundario', 'Analizador portátil de gases'];
      return _buildMessage(
        id: 'apolo-r1-${now.millisecondsSinceEpoch}',
        timestamp: now,
        ruleId: 'rule_1_co2_hypoxia_cardiorespiratory',
        conditionName: 'Alerta Respiratoria / Atmosférica (CO2-SpO2)',
        priority: priority,
        actions: actions,
        supplies: supplies,
        metrics: [
          'SpO2: ${vitals.spO2.toStringAsFixed(1)}%',
          'FR: ${vitals.respiratoryRate.toStringAsFixed(1)} rpm',
          'PPCO2 cabina: ${vitals.localCo2MmHg.toStringAsFixed(2)} mmHg',
          'SpO2 nocturna: ${vitals.nocturnalSpO2MeanPercent.toStringAsFixed(1)}%',
        ],
        sources: const [
          'NASA-STD-3001 Vol. 2 (Environmental)',
          'U.S. FDA (2013)',
          'Bio-Monitor ISS Flight Logs',
        ],
        summaryPrefix:
            'Evaluación cardiorrespiratoria-ambiental activada (${isRed ? "CÓDIGO ROJO" : "PRECAUCIÓN AMARILLA"}).',
      );
    }

    // Regla 2: SANS / Neuro-Ocular (ToF Hyperopic Shift + Pupilometría NPi/PLR)
    final bool sansOrNeuroEyeMatch = _containsAny(lower, const [
          'vista',
          'borrosa',
          'ojo',
          'sans',
          'pupila',
          'enfoque',
          'lectura',
          'craneal',
          'visual',
          'cefalea visual',
        ]) ||
        vitals.pupillometryNpi < 3.0 ||
        vitals.plrLatencyMs > 280.0 ||
        vitals.passiveNearFocusCm > 35.0 ||
        vitals.estimatedHyperopicShiftDiopters >= 0.50;

    if (sansOrNeuroEyeMatch) {
      final bool isRed = vitals.pupillometryNpi < 2.5 ||
          vitals.plrLatencyMs > 340.0 ||
          vitals.estimatedHyperopicShiftDiopters >= 1.25;
      final priority = isRed ? TriagePriority.red : TriagePriority.yellow;
      final actions = <String>[
        'Registrar pupilometría infrarroja: NPi=${vitals.pupillometryNpi.toStringAsFixed(2)}, diámetro=${vitals.pupilDiameterMm.toStringAsFixed(2)} mm, PLR=${vitals.plrLatencyMs.toStringAsFixed(0)} ms.',
        'Validar desplazamiento hiperópico ToF: distancia=${vitals.passiveNearFocusCm.toStringAsFixed(1)} cm (+${vitals.estimatedHyperopicShiftDiopters.toStringAsFixed(2)} D).',
        'Realizar ultrasonido de vaina del nervio óptico (ONSD), tonometría y oftalmoscopía digital para confirmar/descartar SANS.',
        if (isRed) 'Notificar con prioridad alta a Flight Surgeon y neuro-oftalmología en Tierra.',
      ];
      const supplies = [
        'Pupilómetro NeurOptics / Visor IR',
        'Sonda ultrasonido ocular (ONSD)',
        'Kit lentes correctoras Space Anticipation',
      ];
      return _buildMessage(
        id: 'apolo-r2-${now.millisecondsSinceEpoch}',
        timestamp: now,
        ruleId: 'rule_2_sans_pupillometry_tof',
        conditionName: 'Síndrome Neuro-Ocular / Alerta Oculomotora (SANS-NPi)',
        priority: priority,
        actions: actions,
        supplies: supplies,
        metrics: [
          'NPi: ${vitals.pupillometryNpi.toStringAsFixed(2)}',
          'PLR: ${vitals.plrLatencyMs.toStringAsFixed(0)} ms',
          'Enfoque ToF: ${vitals.passiveNearFocusCm.toStringAsFixed(1)} cm',
          'Shift hiperópico: +${vitals.estimatedHyperopicShiftDiopters.toStringAsFixed(2)} D',
        ],
        sources: const [
          'Lee et al. (2020, p. 4)',
          'Macias et al. (2021, p. 321)',
          'DLR / ESA Space Physiology Reports',
        ],
        summaryPrefix:
            'Correlación neurológica-ocular pasiva (${isRed ? "PRIORIDAD ROJA" : "MONITOREO AMARILLO"}).',
      );
    }

    // Regla 3: Impacto Inercial IMU / Caída / Trauma
    final bool traumaMatch = _containsAny(lower, const [
          'golpe',
          'caida',
          'caída',
          'impacto',
          'trauma',
          'fractura',
          'herida',
          'sangre',
          'accidente',
        ]) ||
        vitals.peakImpactG >= 2.5;

    if (traumaMatch) {
      final bool isRed = vitals.peakImpactG >= 3.5 ||
          vitals.systolicBP < 90.0 ||
          vitals.pupillometryNpi < 3.0;
      final priority = isRed ? TriagePriority.red : TriagePriority.yellow;
      final actions = <String>[
        'Asegurar vía aérea y estabilidad hemodinámica tras evento cinético (pico IMU=${vitals.peakImpactG.toStringAsFixed(2)} g, PA=${vitals.systolicBP.toStringAsFixed(0)}/${vitals.diastolicBP.toStringAsFixed(0)} mmHg).',
        'Evaluar reactividad pupilar inmediata (NPi=${vitals.pupillometryNpi.toStringAsFixed(2)}) y relleno capilar (${vitals.capillaryRefillSeconds.toStringAsFixed(1)} s).',
        'Inmovilizar zona afectada en microgravedad usando sujeciones de cabina y revisar sangrado oculto.',
        if (isRed) 'Activar protocolo de trauma mayor Crew Medical Officer + enlace urgente Flight Surgeon.',
      ];
      const supplies = [
        'Kit de Trauma y Hemostasia Orbital',
        'Férula moldeable de vacío',
        'Apósitos estériles y analgesia',
      ];
      return _buildMessage(
        id: 'apolo-r3-${now.millisecondsSinceEpoch}',
        timestamp: now,
        ruleId: 'rule_3_imu_impact_trauma',
        conditionName: 'Detección de Impacto Inercial / Protocolo de Trauma',
        priority: priority,
        actions: actions,
        supplies: supplies,
        metrics: [
          'Pico IMU: ${vitals.peakImpactG.toStringAsFixed(2)} g',
          'PA: ${vitals.systolicBP.toStringAsFixed(0)}/${vitals.diastolicBP.toStringAsFixed(0)} mmHg',
          'FC: ${vitals.heartRate.toStringAsFixed(0)} lpm',
          'NPi: ${vitals.pupillometryNpi.toStringAsFixed(2)}',
        ],
        sources: const [
          'NASA HRP Biomechanics Archives',
          'ESA Human Performance Database',
          'NASA-STD-3001 Emergency Trauma',
        ],
        summaryPrefix:
            'Evento biomecánico/trauma detectado por sensores inerciales (${isRed ? "CÓDIGO ROJO" : "PRECAUCIÓN AMARILLA"}).',
      );
    }

    // Regla 4: Hidratación BIS / Nefrolitiasis / Desbalance Hídrico
    final bool hydrationRenalMatch = _containsAny(lower, const [
          'riñon',
          'rinon',
          'flanco',
          'orina',
          'hidratacion',
          'hidratación',
          'deshidrat',
          'sed',
          'calculo',
          'cálculo',
        ]) ||
        vitals.calibratedHydrationIndex < 70.0;

    if (hydrationRenalMatch) {
      final bool isRed = vitals.calibratedHydrationIndex < 64.0 ||
          vitals.systolicBP < 90.0;
      final priority = isRed ? TriagePriority.red : TriagePriority.yellow;
      final actions = <String>[
        'Interpretar BIS calibrada compensando fluid-shift orbital: ${vitals.calibratedHydrationIndex.toStringAsFixed(1)}% (crudo ${vitals.hydrationBioimpedanceIndex.toStringAsFixed(1)}%).',
        'Iniciar reposición hídrica oral fraccionada (solución isotónica/electrolitos 500-750 mL) y registrar balance urinario 24 h.',
        'Si hay dolor en flanco o hematuria, realizar ecografía renal focal y valorar protocolo citrato de potasio / analgesia.',
      ];
      const supplies = [
        'Sales de rehidratación oral espacial',
        'Citrato de potasio (kit profilaxis litiasis)',
        'Tiras reactivas de uroanálisis',
      ];
      return _buildMessage(
        id: 'apolo-r4-${now.millisecondsSinceEpoch}',
        timestamp: now,
        ruleId: 'rule_4_bis_hydration_renal',
        conditionName: 'Déficit Hídrico BIS / Riesgo de Litiasis Renal en 0 g',
        priority: priority,
        actions: actions,
        supplies: supplies,
        metrics: [
          'BIS calibrada: ${vitals.calibratedHydrationIndex.toStringAsFixed(1)}%',
          'Día misión: ${vitals.missionDay}',
          'FC: ${vitals.heartRate.toStringAsFixed(0)} lpm',
        ],
        sources: const [
          'NASA HRP Fluid Shift Database',
          'NASA-STD-3001 Vol. 2 Hydration & Renal Risk',
        ],
        summaryPrefix:
            'Evaluación metabólica-hídrica con corrección de desplazamiento cefálico (${isRed ? "CRÍTICA" : "MODERADA"}).',
      );
    }

    // Regla 5: Vigilancia Psicomotriz PVT-B / Sueño / Estrés Autonómico Nocturno
    final bool cognitiveSleepMatch = _containsAny(lower, const [
          'sueño',
          'sueno',
          'insomnio',
          'fatiga',
          'cansancio',
          'ansiedad',
          'estres',
          'estrés',
          'concentracion',
          'concentración',
          'reaccion',
          'reacción',
          'animo',
          'ánimo',
        ]) ||
        vitals.passivePvtReactionMs > 355.0 ||
        vitals.passivePvtLapsesCount >= 3 ||
        sleepHours < 7.0 ||
        vitals.nocturnalHrvRmssdMs < 30.0;

    if (cognitiveSleepMatch) {
      final bool isRed = vitals.passivePvtReactionMs >= 420.0 ||
          vitals.passivePvtLapsesCount >= 5 ||
          sleepHours < 5.0 ||
          vitals.nocturnalHrvRmssdMs < 20.0;
      final priority = isRed ? TriagePriority.red : TriagePriority.yellow;
      final actions = <String>[
        'Diferir tareas de alto riesgo (operación de brazo robótico, acoplamiento o EVA) hasta recuperar vigilancia cognitiva.',
        'Evaluar tríada pasiva: PVT-B=${vitals.passivePvtReactionMs.toStringAsFixed(0)} ms (${vitals.passivePvtLapsesCount} lapsos >500 ms), actigrafía=${sleepHours.toStringAsFixed(1)} h (eficiencia ${vitals.sleepEfficiencyPercent.toStringAsFixed(0)}%), HRV nocturna RMSSD=${vitals.nocturnalHrvRmssdMs.toStringAsFixed(0)} ms.',
        'Aplicar protocolo circadiano: fototerapia azul matinal, reducción de luz azul 90 min pre-sueño y descanso mínimo de 7-9 h.',
      ];
      const supplies = [
        'Panel luminoterapia circadiana SSL',
        'Tapones acústicos y antifaz de cabina',
        'Melatonina 0.5-3 mg (bajo pauta médica)',
      ];
      return _buildMessage(
        id: 'apolo-r5-${now.millisecondsSinceEpoch}',
        timestamp: now,
        ruleId: 'rule_5_cognitive_pvt_circadian_hrv',
        conditionName: 'Fatiga Psicomotriz (PVT-B) / Déficit Circadiano-Autonómico',
        priority: priority,
        actions: actions,
        supplies: supplies,
        metrics: [
          'PVT-B pasivo: ${vitals.passivePvtReactionMs.toStringAsFixed(0)} ms',
          'Lapsos >500 ms: ${vitals.passivePvtLapsesCount}',
          'Sueño actigráfico: ${sleepHours.toStringAsFixed(1)} h (${vitals.sleepEfficiencyPercent.toStringAsFixed(0)}%)',
          'HRV nocturna RMSSD: ${vitals.nocturnalHrvRmssdMs.toStringAsFixed(0)} ms',
        ],
        sources: const [
          'Basner & Dinges (2011); Basner et al. (2014)',
          'Barger et al. (2014); Hirshkowitz et al. (2015)',
          'NASA HRP Autonomic Physiology Records',
        ],
        summaryPrefix:
            'Evaluación neuro-circadiana pasiva completada (${isRed ? "ALERTA ROJA OPERACIONAL" : "AJUSTE PREVENTIVO AMARILLO"}).',
      );
    }

    // Regla 6: Atrofia Muscular Localizada BIS / Carga Térmica Heat-Flux
    final bool muscleThermalMatch = _containsAny(lower, const [
          'musculo',
          'músculo',
          'calambre',
          'atrofia',
          'pierna',
          'cuadriceps',
          'ared',
          'fiebre',
          'temperatura',
          'calor',
          'frio',
          'frío',
        ]) ||
        vitals.muscleVolumeRetentionPercent < 80.0 ||
        vitals.coreTempHeatFluxC >= 37.8 ||
        vitals.coreTempHeatFluxC < 35.5;

    if (muscleThermalMatch) {
      final bool isRed =
          vitals.coreTempHeatFluxC >= 38.8 || vitals.coreTempHeatFluxC < 35.2;
      final priority = isRed ? TriagePriority.red : TriagePriority.yellow;
      final actions = <String>[
        'Auditar temperatura central Heat-Flux Draeger (${vitals.coreTempHeatFluxC.toStringAsFixed(2)} °C) y corregir falta de convección en 0 g con enfriamiento activo/hidratación si >= 37.8 °C.',
        'Revisar bioimpedancia muscular localizada en cuádriceps/gastrocnemio (${vitals.muscleVolumeRetentionPercent.toStringAsFixed(1)}%, ángulo pennación ${vitals.pennationAngleDeg.toStringAsFixed(1)}°).',
        'Ajustar volumen de carga resistiva en ARED (sentadillas/elevación de talones) e ingesta proteica diaria si retención < 80%.',
      ];
      const supplies = [
        'Chaleco enfriamiento líquido LCVG',
        'Antipirético oral (paracetamol/ibuprofeno)',
        'Protocolo resistivo ARED personalizado',
      ];
      return _buildMessage(
        id: 'apolo-r6-${now.millisecondsSinceEpoch}',
        timestamp: now,
        ruleId: 'rule_6_muscle_bis_heatflux_thermal',
        conditionName: 'Carga Térmica Heat-Flux / Vigilancia Muscular Localizada',
        priority: priority,
        actions: actions,
        supplies: supplies,
        metrics: [
          'Temp. Heat-Flux: ${vitals.coreTempHeatFluxC.toStringAsFixed(2)} °C',
          'Volumen muscular BIS: ${vitals.muscleVolumeRetentionPercent.toStringAsFixed(1)}%',
          'Ángulo pennación: ${vitals.pennationAngleDeg.toStringAsFixed(1)}°',
        ],
        sources: const [
          'DLR / NASA Thermal Physiology Reports (Draeger Double Sensor)',
          'ESA Spaceflight Musculoskeletal Atrophy Database',
          'NASA-STD-3001 V1 4024',
        ],
        summaryPrefix:
            'Evaluación termorreguladora y musculoesquelética (${isRed ? "ALERTA TÉRMICA ROJA" : "AJUSTE AMARILLO"}).',
      );
    }

    // Regla 7: Chequeo Integral Multi-Dimensión (ADA Baseline Scan)
    final bool systemicCritical = eval.overallSeverity == EvaluationSeverity.clinicalAttention ||
        vitals.systolicBP < 90.0 ||
        vitals.bloodGlucose < 70.0 ||
        vitals.bloodGlucose > 250.0;
    final bool systemicWarning =
        eval.overallSeverity == EvaluationSeverity.contextualWarning;

    final priority = systemicCritical
        ? TriagePriority.red
        : (systemicWarning ? TriagePriority.yellow : TriagePriority.green);

    final actions = <String>[
      ...eval.recommendations,
      'Validación bimodal Actigrafía-HRV: ${eval.actigraphyBimodal.stateLabel} (${eval.actigraphyBimodal.interpretation}).',
      if (systemicCritical)
        'Escalar hallazgos críticos al oficial médico de tripulación y Flight Surgeon en Tierra.',
    ];

    return _buildMessage(
      id: 'apolo-r7-${now.millisecondsSinceEpoch}',
      timestamp: now,
      ruleId: 'rule_7_general_multidimension_scan',
      conditionName: systemicCritical
          ? 'Anomalía Multi-Dimensión Detectada en Telemetría Pasiva'
          : (systemicWarning
              ? 'Desviación Contextual en Telemetría Pasiva'
              : 'Estado Fisiológico Nominal Across 4 Dimensiones'),
      priority: priority,
      actions: actions,
      supplies: priority == TriagePriority.green
          ? const ['Sin insumos de emergencia requeridos (rutina preventiva)']
          : const ['Kit diagnóstico portátil AstraMed', 'Pulsioxímetro y glucómetro capilar'],
      metrics: [
        'FC: ${vitals.heartRate.toStringAsFixed(0)} lpm | HRV RMSSD: ${vitals.hrvRmssdMs.toStringAsFixed(0)} ms',
        'SpO2: ${vitals.spO2.toStringAsFixed(1)}% | Heat-Flux: ${vitals.coreTempHeatFluxC.toStringAsFixed(2)} °C | BIS: ${vitals.calibratedHydrationIndex.toStringAsFixed(1)}%',
        'NPi: ${vitals.pupillometryNpi.toStringAsFixed(2)} | ToF: ${vitals.passiveNearFocusCm.toStringAsFixed(1)} cm | PVT-B: ${vitals.passivePvtReactionMs.toStringAsFixed(0)} ms',
        'IMU Pico: ${vitals.peakImpactG.toStringAsFixed(2)} g | Músculo BIS: ${vitals.muscleVolumeRetentionPercent.toStringAsFixed(1)}%',
        'Sueño: ${sleepHours.toStringAsFixed(1)} h (${vitals.sleepEfficiencyPercent.toStringAsFixed(0)}%) | HRV nocturna: ${vitals.nocturnalHrvRmssdMs.toStringAsFixed(0)} ms',
      ],
      sources: const [
        'NASA-STD-3001 Vol. 1 & Vol. 2',
        'Mendes Zambetta et al. (2024); Lee et al. (2020); Basner & Dinges (2011)',
        'Bio-Monitor (CSA); Draeger Double Sensor (DLR)',
      ],
      summaryPrefix: priority == TriagePriority.green
          ? 'Barrido integral de las 4 dimensiones pasivas en rango nominal.'
          : 'Barrido integral detectó desviaciones que requieren seguimiento clínico.',
    );
  }

  ApolloChatMessage _buildMessage({
    required String id,
    required DateTime timestamp,
    required String ruleId,
    required String conditionName,
    required TriagePriority priority,
    required List<String> actions,
    required List<String> supplies,
    required List<String> metrics,
    required List<String> sources,
    required String summaryPrefix,
  }) {
    final result = TriageResult(
      conditionName: conditionName,
      priority: priority,
      immediateActions: actions,
      requiredSupplies: supplies,
      guideAssetPath: 'DB/references.md',
      algorithm: 'ADA+APOLO Deterministic Clinical Matrix v1.1 ($ruleId)',
      criterionReference: sources.join(' | '),
    );

    final buffer = StringBuffer()
      ..writeln('$summaryPrefix Diagnóstico orientativo: $conditionName.')
      ..writeln('Acciones recomendadas:')
      ..writeln(actions.map((a) => '- $a').join('\n'));

    return ApolloChatMessage(
      id: id,
      isFromUser: false,
      text: buffer.toString().trim(),
      timestamp: timestamp,
      priority: priority,
      triageResult: result,
      referencedMetrics: metrics,
      recommendedSupplies: supplies,
      sources: sources,
      triggeredRule: ruleId,
    );
  }

  bool _containsAny(String haystack, List<String> needles) {
    for (final needle in needles) {
      if (haystack.contains(needle)) return true;
    }
    return false;
  }
}
