import 'package:astramed/features/01_general_health/domain/telemetry_view_contracts.dart';
import 'package:astramed/features/05_clinical_triage/models/triage_decision.dart';
import 'package:astramed/features/crew/models/astronaut_profile.dart';

/// Mensaje en el diálogo de triaje médico conversacional
class ApolloChatMessage {
  final String id;
  final String sender; // 'apollo' o 'astronaut'
  final String text;
  final DateTime timestamp;
  final TriagePriority? triageLevel;
  final String? recommendedHardware;
  final List<String>? actionChecklist;
  final List<String>? followUpOptions;
  final String inferenceSource;

  const ApolloChatMessage({
    required this.id,
    required this.sender,
    required this.text,
    required this.timestamp,
    this.triageLevel,
    this.recommendedHardware,
    this.actionChecklist,
    this.followUpOptions,
    this.inferenceSource = 'Motor Clínico ADA Determinista (100% Offline)',
  });

  bool get isApollo => sender == 'apollo';

  ApolloChatMessage copyWith({
    String? id,
    String? sender,
    String? text,
    DateTime? timestamp,
    TriagePriority? triageLevel,
    String? recommendedHardware,
    List<String>? actionChecklist,
    List<String>? followUpOptions,
    String? inferenceSource,
  }) {
    return ApolloChatMessage(
      id: id ?? this.id,
      sender: sender ?? this.sender,
      text: text ?? this.text,
      timestamp: timestamp ?? this.timestamp,
      triageLevel: triageLevel ?? this.triageLevel,
      recommendedHardware: recommendedHardware ?? this.recommendedHardware,
      actionChecklist: actionChecklist ?? this.actionChecklist,
      followUpOptions: followUpOptions ?? this.followUpOptions,
      inferenceSource: inferenceSource ?? this.inferenceSource,
    );
  }
}

/// Motor determinista y clínico de APOLO para evaluación de triaje
class ApolloTriageEngine {
  static ApolloChatMessage processQuery({
    required String query,
    required AstronautProfile astronaut,
    required SpaceOperationalEnvironment environment,
  }) {
    final lower = query.toLowerCase();
    final vitals = astronaut.vitals;
    final now = DateTime.now();

    // 1. Detección de Hipercapnia / Bolsón de CO2 / Asfixia
    if (lower.contains('co2') ||
        lower.contains('asfixia') ||
        lower.contains('ahogo') ||
        lower.contains('aire') ||
        lower.contains('falta de aire')) {
      final bool co2Elevated = vitals.localCo2MmHg >= 3.5;
      final bool spo2Low = vitals.spO2 < 94.0;
      final priority = (co2Elevated || spo2Low) ? TriagePriority.red : TriagePriority.yellow;

      final telemetryNote = 'Telemetría: CO₂ local en cabina: ${vitals.localCo2MmHg.toStringAsFixed(1)} mmHg (límite 3.5), SpO₂: ${vitals.spO2.toStringAsFixed(0)}%.';

      String contextAdvice = '';
      if (environment == SpaceOperationalEnvironment.spaceStation) {
        contextAdvice = 'En 0 g sin convección natural se forman microbolsas de CO₂ alrededor de la cara en módulos estancos o zonas mal ventiladas.';
      } else if (environment == SpaceOperationalEnvironment.rover) {
        contextAdvice = 'En traje EVA/Rover vigila inmediatamente la purga del cánister de hidróxido de litio (LiOH).';
      } else {
        contextAdvice = 'Vigila el sistema de regeneración de aire ECLSS y el flujo presurizado.';
      }

      return ApolloChatMessage(
        id: 'APOLLO-${now.millisecondsSinceEpoch}',
        sender: 'apollo',
        text: 'Protocolo de Hipercapnia & Ventilación Activado.\n\n$telemetryNote\n\n$contextAdvice\n\n¿Presentas cefalea frontal punzante o náuseas?',
        timestamp: now,
        triageLevel: priority,
        recommendedHardware: 'Sensores ECLSS de cabina + Bio-Monitor (FR y SpO₂)',
        actionChecklist: const [
          'Activar ventilación forzada auxiliar o abandonar módulo actual.',
          'Colocarse oxímetro de pulso para verificar SpO₂ en reposo.',
          'Si persiste disnea, acudir a la Bahía Médica para suministro de O₂ enriquecido.',
        ],
        followUpOptions: const [
          'Activé ventilador auxiliar y mejoró el aire',
          'Siento cefalea intensa y mareo',
          'La SpO₂ en reposo sigue bajando',
        ],
      );
    }

    // 2. Síndrome Neuro-Ocular (SANS) / Cefalea / Visión Borrosa
    if (lower.contains('visión') ||
        lower.contains('borrosa') ||
        lower.contains('cabeza') ||
        lower.contains('ojo') ||
        lower.contains('sans') ||
        lower.contains('escotoma')) {
      final bool highBp = vitals.systolicBP > 140.0;
      final priority = highBp ? TriagePriority.yellow : TriagePriority.green;

      return ApolloChatMessage(
        id: 'APOLLO-${now.millisecondsSinceEpoch}',
        sender: 'apollo',
        text: 'Evaluando sospecha de Síndrome Neuro-Ocular (SANS) & Congestión Cefálica.\n\nEn entorno de ${environment.label}, la redistribución cefálica de fluidos eleva la presión venosa intracraneal y modifica la curvatura corneal (desplazamiento hiperópico).\n\nTelemetría actual: TA ${vitals.systolicBP.toInt()}/${vitals.diastolicBP.toInt()} mmHg, Día de Misión ${vitals.missionDay}.',
        timestamp: now,
        triageLevel: priority,
        recommendedHardware: 'Tableta con ToF (agudeza visual) + Ecógrafo ONSD (Butterfly iQ+)',
        actionChecklist: const [
          'Ejecutar test ToF de distancia de lectura en tableta para cuantificar cambio hiperópico.',
          'Inspección pupilar y agudeza con optotipos Snellen/LogMAR.',
          'Reportar al Oficial Médico (CMO) si hay dolor retroocular o escotomas.',
        ],
        followUpOptions: const [
          'ToF indica +0.25 D (estable sin escotomas)',
          'El dolor aumenta al inclinarme hacia adelante',
          'Presento escotomas o pérdida de campo visual',
        ],
      );
    }

    // 3. Traumatismo / Golpes / Caídas / Biomecánica
    if (lower.contains('golpe') ||
        lower.contains('trauma') ||
        lower.contains('caída') ||
        lower.contains('fractura') ||
        lower.contains('impacto')) {
      final isRoverOrSurface = environment == SpaceOperationalEnvironment.rover ||
          environment == SpaceOperationalEnvironment.planetaryBase;
      final priority = TriagePriority.red;

      return ApolloChatMessage(
        id: 'APOLLO-${now.millisecondsSinceEpoch}',
        sender: 'apollo',
        text: 'Protocolo de Trauma Biomecánico & Lesión por Impacto.\n\n${isRoverOrSurface ? "Alerta en superficie/Rover: riesgo de perforación de traje presurizado y contusión acelerométrica." : "En 0 g el impacto inercial contra mamparos o racks puede producir luxaciones y trauma cerrado sin deformidad externa evidente."}\n\nLlenado capilar actual: ${vitals.capillaryRefillSeconds.toStringAsFixed(1)} s.',
        timestamp: now,
        triageLevel: priority,
        recommendedHardware: 'Sonda Butterfly iQ+ (FAST abdominal/torácico) + Acelerómetro IMU',
        actionChecklist: const [
          'Inspeccionar integridad del traje presurizado o signos de hemorragia activa.',
          'Comprobar pulsos periféricos y tiempo de llenado capilar.',
          'Iniciar barrido ecográfico FAST para descartar hemotórax o líquido libre.',
        ],
        followUpOptions: const [
          'FAST ecográfico negativo (sin hemorragia interna)',
          'Hay deformidad visible o dolor incapacitante',
          'El traje presurizado muestra pérdida de presión',
        ],
      );
    }

    // 4. Dolor Lumbar / Litiasis / Cálculo Renal
    if (lower.contains('lumbar') ||
        lower.contains('riñón') ||
        lower.contains('renal') ||
        lower.contains('orina') ||
        lower.contains('cálculo')) {
      return ApolloChatMessage(
        id: 'APOLLO-${now.millisecondsSinceEpoch}',
        sender: 'apollo',
        text: 'Sospecha de Litiasis Renal (Cálculo Renal por Microgravedad).\n\nEn microgravedad la resorción ósea libera calcio sérico (hipercalciuria) aumentando exponencialmente el riesgo de formación de litiasis de oxalato/fosfato de calcio.\n\nÍndice de hidratación actual: ${vitals.calibratedHydrationIndex.toStringAsFixed(0)}% (Bodystat BIS).',
        timestamp: now,
        triageLevel: TriagePriority.yellow,
        recommendedHardware: 'Abbott i-STAT Alinity (Ca²⁺ / Creatinina) + Ecógrafo Renal',
        actionChecklist: const [
          'Tomar muestra de sangre capilar en cartucho CG4+/CHEM8+ de i-STAT.',
          'Evaluar si el dolor es cólico intermitente con irradiación hacia fosa ilíaca.',
          'Aumentar ingesta de agua oral a >2.5 L/día y administrar analgesia prescrita.',
        ],
        followUpOptions: const [
          'Dolor cólico moderado irradiado a fosa ilíaca',
          'i-STAT muestra calcio y creatinina normales',
          'Tengo hematuria visible o fiebre asociada',
        ],
      );
    }

    // 5. Consulta general o por defecto
    return ApolloChatMessage(
      id: 'APOLLO-${now.millisecondsSinceEpoch}',
      sender: 'apollo',
      text: 'He registrado tu consulta: "$query".\n\nCruzando con la telemetría en vivo de ${astronaut.name} en ${environment.label}:\n• Frecuencia Cardíaca: ${vitals.heartRate.toInt()} lpm\n• SpO₂: ${vitals.spO2.toStringAsFixed(0)}%\n• PA: ${vitals.systolicBP.toInt()}/${vitals.diastolicBP.toInt()} mmHg\n• Temp: ${vitals.bodyTemp.toStringAsFixed(1)} °C\n\nNo se detectan arritmias críticas ni hipoxia aguda en curso. ¿Qué molestia o síntoma específico presentas?',
      timestamp: now,
      triageLevel: TriagePriority.green,
      recommendedHardware: 'Bio-Monitor CSA + Draeger Double Sensor',
      actionChecklist: const [
        'Selecciona uno de los presets de síntoma o describe tu molestia en detalle.',
        'Verifica que tus sensores vestibles mantengan contacto óptimo con la piel.',
      ],
      followUpOptions: const [
        'Siento fatiga general tras ejercicio',
        'Todo en orden, solo chequeo preventivo',
        'Quiero revisar protocolo de hidratación o descanso',
      ],
    );
  }
}
