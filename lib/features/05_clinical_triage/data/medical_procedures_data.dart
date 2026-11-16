import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'package:astramed/core/constants/medical_thresholds.dart';
import 'package:astramed/features/02_radiation/models/radiation_dose.dart';
import 'package:astramed/features/05_clinical_triage/models/triage_decision.dart';
import 'package:astramed/features/crew/models/astronaut_profile.dart';

/// Repositorio offline de documentación clínica, escenarios de triage
/// y motor determinista de sugerencia de procedimientos médicos espaciales.
class MedicalProceduresData {
  /// Carga los 10 protocolos médicos desde `DB/Information/medical_procedures_catalog.json`
  /// con respaldo inmediato en memoria para operación 100% offline.
  static Future<List<MedicalProcedure>> loadProceduresFromDb() async {
    try {
      final raw = await rootBundle.loadString(
        'DB/Information/medical_procedures_catalog.json',
      );
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic> && decoded['procedures'] is List) {
        final list = (decoded['procedures'] as List)
            .whereType<Map>()
            .map(
              (item) =>
                  MedicalProcedure.fromJson(Map<String, dynamic>.from(item)),
            )
            .toList();
        if (list.isNotEmpty) return list;
      }
    } catch (e) {
      debugPrint('Aviso: usando catálogo local de procedimientos médicos: $e');
    }
    return getProcedures();
  }

  /// Carga los escenarios rápidos desde `DB/Information/clinical_situations_triage.json`
  /// con respaldo inmediato en memoria.
  static Future<List<ClinicalScenario>> loadScenariosFromDb() async {
    try {
      final raw = await rootBundle.loadString(
        'DB/Information/clinical_situations_triage.json',
      );
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic> && decoded['scenarios'] is List) {
        final list = (decoded['scenarios'] as List)
            .whereType<Map>()
            .map(
              (item) =>
                  ClinicalScenario.fromJson(Map<String, dynamic>.from(item)),
            )
            .toList();
        if (list.isNotEmpty) return list;
      }
    } catch (e) {
      debugPrint('Aviso: usando escenarios locales de triage clínico: $e');
    }
    return getScenarios();
  }

  /// Busca un procedimiento por su identificador único.
  static MedicalProcedure? findById(
    String id, [
    List<MedicalProcedure>? catalog,
  ]) {
    final source = catalog ?? getProcedures();
    for (final proc in source) {
      if (proc.id == id) return proc;
    }
    return null;
  }

  /// Motor determinista que evalúa al tripulante o la situación seleccionada
  /// y sugiere en primer lugar el procedimiento médico más adecuado.
  static List<ProcedureSuggestion> suggestProceduresForAstronaut(
    AstronautProfile astronaut, {
    String? simulatedSituationId,
    List<MedicalProcedure>? catalog,
    List<ClinicalScenario>? scenarios,
  }) {
    final procedures = catalog ?? getProcedures();
    final scenarioList = scenarios ?? getScenarios();
    final suggestions = <ProcedureSuggestion>[];
    final seenIds = <String>{};

    void addSuggestion(String procedureId, String reason, bool isUrgent) {
      if (seenIds.contains(procedureId)) return;
      final proc = findById(procedureId, procedures);
      if (proc != null) {
        seenIds.add(procedureId);
        suggestions.add(
          ProcedureSuggestion(
            procedure: proc,
            reason: reason,
            isUrgent: isUrgent,
          ),
        );
      }
    }

    // 1. Priorizar situación seleccionada o simulada explícitamente
    if (simulatedSituationId != null && simulatedSituationId.isNotEmpty) {
      String targetProcedureId = simulatedSituationId;
      String? scenarioNote;

      for (final scenario in scenarioList) {
        if (scenario.id == simulatedSituationId ||
            scenario.recommendedProcedureId == simulatedSituationId) {
          targetProcedureId = scenario.recommendedProcedureId;
          scenarioNote =
              'Situación reportada (${scenario.label}): ${scenario.symptomSummary}.';
          break;
        }
      }

      final targetProc = findById(targetProcedureId, procedures);
      if (targetProc != null) {
        addSuggestion(
          targetProc.id,
          scenarioNote ?? 'Situación clínica activa: ${targetProc.summary}',
          targetProc.priority == TriagePriority.red,
        );
      }
    }

    // 2. Evaluación automática de telemetría y signos vitales actuales
    final v = astronaut.vitals;
    final r = astronaut.radiation;
    final s = astronaut.sleep;

    if (v.heartRate <= 0 ||
        v.heartRate < 40.0 ||
        v.heartRate > 150.0 ||
        (v.spO2 < 85.0 && v.systolicBP < 80.0)) {
      addSuggestion(
        'PROC-CARDIAC-ARREST',
        'Pulso crítico (${v.heartRate.toInt()} bpm) con compromiso circulatorio. Verificar conciencia/pulso e iniciar RCP en microgravedad.',
        true,
      );
    }

    if (v.spO2 < 90.0) {
      addSuggestion(
        'PROC-HYPOXIA-DECOMP',
        'Saturación SpO2 crítica (${v.spO2.toStringAsFixed(0)}%). Administrar oxígeno al 100% y revisar sello EVA/cabina.',
        true,
      );
    }

    if (r.doseRateMicroSvPerHour > 100.0 ||
        r.severity == RadiationSeverity.critical) {
      addSuggestion(
        'PROC-RADIATION-ARS',
        'Tasa de radiación elevada (${r.doseRateMicroSvPerHour.toStringAsFixed(0)} µSv/h). Trasladar a refugio blindado y vigilar síntomas.',
        true,
      );
    }

    if (v.heartRate > 115.0 ||
        v.heartRate < 48.0 ||
        v.systolicBP < 88.0 ||
        v.systolicBP > 145.0) {
      addSuggestion(
        'PROC-HEMODYNAMIC-SYNCOPE',
        'Inestabilidad hemodinámica (FC ${v.heartRate.toInt()} bpm, PA ${v.systolicBP.toInt()}/${v.diastolicBP.toInt()} mmHg). Reposo y control cardiovascular.',
        v.systolicBP < 85.0 || v.systolicBP > 160.0 || v.heartRate > 115.0,
      );
    }

    if (v.respiratoryRate > 22.0) {
      addSuggestion(
        'PROC-HYPERCAPNIA-CO2',
        'Frecuencia respiratoria alta (${v.respiratoryRate.toInt()} rpm). Evaluar acumulación de CO2 y ventilación de cabina.',
        v.respiratoryRate >= 26.0,
      );
    }

    if (v.bodyTemp > 37.3) {
      addSuggestion(
        'PROC-RENAL-DEHYDRATION',
        'Temperatura elevada (${v.bodyTemp.toStringAsFixed(1)} °C). Reforzar hidratación oral y control térmico.',
        v.bodyTemp > 38.0,
      );
    }

    if (v.systolicBP > MedicalThresholds.maxSystolicBP &&
        v.systolicBP <= 145.0) {
      addSuggestion(
        'PROC-SANS-CEPHALEA',
        'Presión arterial limítrofe (${v.systolicBP.toInt()}/${v.diastolicBP.toInt()} mmHg). Vigilar cefalea y visión (SANS).',
        false,
      );
    }

    if (s.sleepHours < MedicalThresholds.minRecommendedSleepHours ||
        s.wakeEpisodes >= 3) {
      addSuggestion(
        'PROC-CIRCADIAN-FATIGUE',
        'Déficit de descanso (${s.sleepHours.toStringAsFixed(1)} h, ${s.wakeEpisodes} despertares). Aplicar protocolo de higiene del sueño.',
        false,
      );
    }

    if (suggestions.isEmpty) {
      addSuggestion(
        'PROC-CIRCADIAN-FATIGUE',
        'Tripulante estable (Estado Nominal). Mantener vigilancia preventiva y rutina de descanso saludable.',
        false,
      );
    }

    return suggestions;
  }

  /// Catálogo local completo de los 10 protocolos médicos de respuesta offline.
  static List<MedicalProcedure> getProcedures() {
    return const [
      MedicalProcedure(
        id: 'PROC-CARDIAC-ARREST',
        code: 'IMG-ACLS-01',
        title: 'Paro Cardíaco y RCP en Microgravedad (ACLS Espacial)',
        category: 'cardiovascular',
        priority: TriagePriority.red,
        nasaHazard: 'Gravity fields / Distance from Earth',
        summary:
            'Protocolo de reanimación cardiopulmonar adaptado a ingravidez cuando un tripulante pierde la conciencia, no respira o presenta ausencia de pulso o ritmo desfibrilable.',
        whenToActivate: [
          'Tripulante inconsciente que no responde a estímulos verbales ni táctiles',
          'Ausencia de respiración normal o respiración agónica (jadeo)',
          'Ausencia de pulso central o frecuencia cardíaca crítica (< 40 bpm o > 150 bpm sin perfusión)',
          'Llenado capilar > 3.0 segundos con cianosis o alerta de asistolia/FV en Astroskin',
        ],
        vitalTriggers: {
          'minHeartRate': 40.0,
          'maxHeartRate': 150.0,
          'minSpO2': 85.0,
          'minSystolicBP': 75.0,
          'keywords': [
            'paro',
            'rcp',
            'sin pulso',
            'inconsciente',
            'asistolia',
            'fibrilación',
            'cardíaco',
          ],
        },
        steps: [
          ProcedureStep(
            step: 1,
            title: 'Confirmar paro y activar alarma de cabina',
            action:
                'Verificar estado de conciencia y respiración en máximo 10 segundos. Activar la alerta médica de cabina para convocar al Oficial Médico (CMO) y al resto de la tripulación.',
            clinicalTip:
                'No perder tiempo buscando pulso radial si no hay respuesta ni respiración; iniciar preparación de RCP de inmediato.',
            durationSeconds: 10,
          ),
          ProcedureStep(
            step: 2,
            title: 'Inmovilizar en el sistema CMRS',
            action:
                'Asegurar al paciente sobre la camilla rígida CMRS (Crew Medical Restraint System) con las correas de pecho, pelvis y piernas para evitar que el cuerpo flote con cada compresión.',
            clinicalTip:
                'Si estás solo y el CMRS aún no está desplegado, sujeta tus piernas alrededor de la cintura del paciente (abrazo invertido) mientras un segundo tripulante trae el CMRS y el DEA.',
            durationSeconds: 30,
          ),
          ProcedureStep(
            step: 3,
            title: 'Iniciar compresiones torácicas en microgravedad',
            action:
                'Aplicar compresiones continuas en el centro del esternón a ritmo de 100-120 por minuto y profundidad de 5 a 6 cm. Usar el método Handstand (apoyar los pies contra la pared/techo opuesto del módulo para generar fuerza axial) o el método Evetts-Russomano.',
            clinicalTip:
                'Permitir la reexpansión completa del tórax entre compresiones y rotar al reanimador cada 2 minutos para evitar fatiga.',
            durationSeconds: 120,
          ),
          ProcedureStep(
            step: 4,
            title: 'Aplicar DEA espacial (AED)',
            action:
                'Encender el desfibrilador externo automático, colocar los parches adhesivos en tórax seco (subclavicular derecho e infraaxilar izquierdo) y detener brevemente las compresiones solo mientras analiza el ritmo.',
            clinicalTip:
                'Antes de administrar la descarga, verificar visualmente que ningún tripulante toque el cuerpo o el marco metálico del CMRS.',
            durationSeconds: 25,
          ),
          ProcedureStep(
            step: 5,
            title: 'Ventilación con mascarilla BVM y O2 al 100%',
            action:
                'Asegurar vía aérea permeable con tracción mandibular o cánula orofaríngea. Administrar 2 ventilaciones de rescate cada 30 compresiones usando bolsa-válvula-mascarilla conectada a oxígeno al 100%.',
            clinicalTip:
                'Evitar hiperventilación excesiva (máximo 1 segundo por insuflación hasta ver elevación torácica).',
            durationSeconds: 20,
          ),
          ProcedureStep(
            step: 6,
            title: 'Soporte ACLS y registro telemétrico',
            action:
                'Si no hay retorno de circulación espontánea tras 2 minutos de RCP y descarga, administrar Epinefrina 1 mg IV/IO cada 3-5 minutos. Registrar eventos y enviar paquete diferido a Cirujanos de Vuelo.',
            clinicalTip:
                'Mantener ciclos continuos de 2 minutos hasta recuperar pulso palpable o indicación médica de término.',
            durationSeconds: 120,
          ),
        ],
        requiredSupplies: [
          ProcedureSupply(
            itemId: 'CMRS-BOARD',
            name: 'Crew Medical Restraint System (Camilla CMRS)',
            usage: 'Fijación del paciente y del reanimador en microgravedad',
            location: 'Bahía Médica / Rack CHeCS',
          ),
          ProcedureSupply(
            itemId: 'AED-SPACE',
            name: 'Desfibrilador Externo Automático Espacial (AED)',
            usage: 'Análisis de ritmo y desfibrilación bifásica',
            location: 'Módulo Harmony / Kit Emergencia A1',
          ),
          ProcedureSupply(
            itemId: 'BVM-O2-100',
            name: 'Bolsa-Válvula-Mascarilla + Toma O2 100%',
            usage: 'Ventilación asistida 30:2 con oxígeno suplementario',
            location: 'Módulo Harmony / Kit Vía Aérea',
          ),
          ProcedureSupply(
            itemId: 'MED-EPINEPHRINE',
            name: 'Epinefrina 1 mg/10 mL (Jeringa precargada)',
            usage:
                '1 mg IV/IO cada 3-5 minutos en ritmo no desfibrilable o refractario',
            location: 'Botiquín ACLS / Cajón Rojo 1',
          ),
        ],
        warnings: [
          'Nunca intentar compresiones sin anclaje corporal; la tercera ley de Newton impulsará al reanimador lejos del paciente.',
          'Asegurarse de que la superficie torácica esté seca antes de usar los parches del DEA.',
          'No interrumpir las compresiones más de 10 segundos durante la colocación de vía aérea o análisis.',
        ],
        criterionReference:
            'NASA-STD-3001 / ISS Integrated Medical Group ACLS & Microgravity CPR Checklist',
      ),
      MedicalProcedure(
        id: 'PROC-HYPOXIA-DECOMP',
        code: 'IMG-HYP-02',
        title: 'Hipoxia Aguda y Descompresión Post-EVA',
        category: 'respiratory',
        priority: TriagePriority.red,
        nasaHazard: 'Hostile closed environments / Gravity fields',
        summary:
            'Atención inmediata ante caída crítica de oxígeno en sangre (SpO2 < 90%), fuga de traje EVA, despresurización o enfermedad por descompresión.',
        whenToActivate: [
          'SpO2 < 90% confirmado en Bio-Monitor Astroskin o pulsioxímetro',
          'Falta de aire intensa, polipnea (> 24 rpm) o confusión mental',
          'Dolor articular, mareo o parestesias tras una caminata espacial (EVA)',
          'Cianosis labial/ungueal o llenado capilar > 2.5 segundos',
        ],
        vitalTriggers: {
          'minSpO2': 90.0,
          'maxRespiratoryRate': 24.0,
          'keywords': [
            'hipoxia',
            'spo2',
            'falta de aire',
            'ahogo',
            'descompresión',
            'eva',
            'oxígeno',
          ],
        },
        steps: [
          ProcedureStep(
            step: 1,
            title: 'Suministrar oxígeno suplementario al 100%',
            action:
                'Colocar mascarilla de no reinhalación o circuito cerrado con flujo de O2 al 100% (10-15 L/min) manteniendo al astronauta en reposo semi-reclinado y anclado.',
            clinicalTip:
                'Revisar inmediatamente la presión de cabina y el nivel de O2 ambiental en el panel ECLSS.',
            durationSeconds: 30,
          ),
          ProcedureStep(
            step: 2,
            title: 'Verificar sello de escotilla y traje EVA',
            action:
                'Si el evento ocurre en la esclusa tras una EVA, asegurar presurización nominal a 101.3 kPa (14.7 psi) y descartar burbujas o síntomas neurológicos por descompresión (DCS).',
            clinicalTip:
                'Si hay síntomas de enfermedad por descompresión, iniciar protocolo de recompresión hiperbárica en esclusa con O2 al 100%.',
            durationSeconds: 60,
          ),
          ProcedureStep(
            step: 3,
            title: 'Monitorear signos vitales cada 2 minutos',
            action:
                'Conectar Astroskin e i-STAT para vigilar recuperación de SpO2 >= 95%, descenso de frecuencia cardíaca y saturación venosa/gases.',
            clinicalTip:
                'Si el SpO2 no supera 92% tras 5 minutos de O2 al 100%, asistir ventilación con BVM y preparar alerta roja a Tierra.',
            durationSeconds: 120,
          ),
          ProcedureStep(
            step: 4,
            title: 'Hidratación y reposo post-evento',
            action:
                'Una vez estabilizado (SpO2 >= 94%), administrar hidratación oral con electrolitos y mantener monitoreo continuo durante 4 horas.',
            clinicalTip:
                'Prohibir nuevas actividades físicas o EVA hasta autorización médica.',
            durationSeconds: 180,
          ),
        ],
        requiredSupplies: [
          ProcedureSupply(
            itemId: 'BVM-O2-100',
            name: 'Mascarilla de Oxígeno 100% / BVM',
            usage: 'Administración inmediata de oxígeno a alto flujo',
            location: 'Esclusa Quest / Kit Vía Aérea',
          ),
          ProcedureSupply(
            itemId: 'MED-ORAL-REHYDRATION',
            name: 'Solución de Rehidratación Oral con Electrolitos',
            usage: 'Soporte hemodinámico tras estabilización respiratoria',
            location: 'Bahía Médica / Cajón Verde 2',
          ),
        ],
        warnings: [
          'No retirar el oxígeno prematuramente aunque el tripulante sienta mejoría subjetiva.',
          'Evitar cualquier esfuerzo físico mientras la frecuencia respiratoria supere 20 rpm.',
        ],
        criterionReference:
            'NASA-STD-3001 Vol. 2 Atmosphere & Decompression Sickness Protocol',
      ),
      MedicalProcedure(
        id: 'PROC-RADIATION-ARS',
        code: 'IMG-RAD-03',
        title: 'Síndrome Agudo por Radiación (ARS) y Tormenta Solar (SPE)',
        category: 'radiation',
        priority: TriagePriority.red,
        nasaHazard: 'Space radiation',
        summary:
            'Protocolo de protección y manejo clínico ante evento de partículas solares (SPE), tasa de dosis > 150 µSv/h o síntomas prodrómicos de radiación.',
        whenToActivate: [
          'Alarma de dosimetría HERA con tasa > 150 µSv/h o dosis acumulada en rápido ascenso',
          'Náuseas, vómitos, fatiga súbita o eritema cutáneo tras alerta de tormenta solar',
          'Tripulante expuesto fuera del módulo principal durante evento SPE',
        ],
        vitalTriggers: {
          'maxDoseRateMicroSvPerHour': 150.0,
          'keywords': [
            'radiación',
            'tormenta solar',
            'spe',
            'ars',
            'hera',
            'dosis',
            'náuseas',
          ],
        },
        steps: [
          ProcedureStep(
            step: 1,
            title: 'Refugio inmediato en Storm Shelter',
            action:
                'Abortar cualquier actividad en módulos externos o EVA. Trasladar a toda la tripulación al refugio blindado rodeado por reservas de agua y suministros de alta densidad de hidrógeno.',
            clinicalTip:
                'Cada minuto fuera del blindaje durante un pico SPE multiplica la dosis absorbida en médula ósea.',
            durationSeconds: 120,
          ),
          ProcedureStep(
            step: 2,
            title: 'Control de náuseas y síntomas prodrómicos',
            action:
                'Si hay náuseas o vómitos tempranos, administrar Ondansetrón 4-8 mg sublingual/oral para prevenir deshidratación y broncoaspiración en microgravedad.',
            clinicalTip:
                'Registrar hora exacta de inicio de náuseas; ayuda a estimar la dosis biológica absorbida.',
            durationSeconds: 60,
          ),
          ProcedureStep(
            step: 3,
            title: 'Evaluación hematológica y dosimetría',
            action:
                'Realizar lectura con HERA Radiation Assay y análisis capilar con i-STAT para vigilar electrolitos, glucosa y estado metabólico.',
            clinicalTip:
                'Comparar la dosis acumulada contra los límites operacionales NASA-STD-3001.',
            durationSeconds: 180,
          ),
          ProcedureStep(
            step: 4,
            title: 'Hidratación y vigilancia continua',
            action:
                'Mantener ingesta de líquidos con electrolitos, evitar fármacos nefrotóxicos y permanecer en el refugio hasta confirmación de descenso de flujo solar.',
            clinicalTip:
                'Reevaluar biomarcadores de daño oxidativo y conteo linfocitario si hay equipo disponible.',
            durationSeconds: 300,
          ),
        ],
        requiredSupplies: [
          ProcedureSupply(
            itemId: 'MED-ONDANSETRON',
            name: 'Ondansetrón 4 mg (Tabletas dispersables)',
            usage:
                '1 tableta cada 8 horas para control de náuseas/vómito por radiación',
            location: 'Botiquín Principal / Cajón Amarillo 1',
          ),
          ProcedureSupply(
            itemId: 'MED-ORAL-REHYDRATION',
            name: 'Solución de Rehidratación Oral',
            usage: 'Reposición hídrica controlada en refugio',
            location: 'Storm Shelter / Kit Emergencia',
          ),
        ],
        warnings: [
          'No abandonar el refugio blindado hasta que el dosímetro HERA marque niveles basales estables.',
          'Evitar administrar aspirina o AINEs si se sospecha afectación plaquetaria.',
        ],
        criterionReference:
            'NASA-STD-3001 Permissible Exposure Limits (PEL) & SRAG SPE Protocol',
      ),
      MedicalProcedure(
        id: 'PROC-HEMODYNAMIC-SYNCOPE',
        code: 'IMG-HEM-04',
        title: 'Arritmia, Hipotensión Severa o Crisis Hipertensiva',
        category: 'hemodynamics',
        priority: TriagePriority.red,
        nasaHazard: 'Gravity fields',
        summary:
            'Estabilización cardiovascular ante presiones arteriales peligrosas (< 85 o > 160 mmHg), taquicardia sostenida (> 115 bpm), bradicardia (< 48 bpm) o presíncope.',
        whenToActivate: [
          'Presión sistólica < 85 mmHg o > 160 mmHg',
          'Frecuencia cardíaca > 115 bpm en reposo o < 48 bpm sintomática',
          'Mareo al cambiar de postura, visión en túnel, dolor torácico o palpitaciones',
        ],
        vitalTriggers: {
          'minHeartRate': 48.0,
          'maxHeartRate': 115.0,
          'minSystolicBP': 88.0,
          'maxSystolicBP': 145.0,
          'keywords': [
            'presión',
            'arritmia',
            'síncope',
            'hipotensión',
            'hipertensión',
            'taquicardia',
            'palpitaciones',
          ],
        },
        steps: [
          ProcedureStep(
            step: 1,
            title: 'Reposo y anclaje horizontal',
            action:
                'Detener actividad física de inmediato, anclar al astronauta en posición de reposo y conectar Astroskin y EPM Cardiocavity Module para trazado continuo.',
            clinicalTip:
                'En entornos con gravedad parcial (Luna/Marte), elevar suavemente las piernas si hay hipotensión.',
            durationSeconds: 45,
          ),
          ProcedureStep(
            step: 2,
            title: 'Descartar causas reversibles',
            action:
                'Verificar SpO2, glucosa capilar con i-STAT, temperatura corporal y niveles de CO2 en cabina para descartar hipoxia, hipoglucemia o hipercapnia.',
            clinicalTip:
                'Una glucemia < 70 mg/dL puede simular una crisis autonómica severa.',
            durationSeconds: 90,
          ),
          ProcedureStep(
            step: 3,
            title: 'Maniobras de soporte hemodinámico',
            action:
                'En hipotensión sin edema pulmonar, administrar carga rápida de hidratación oral con electrolitos (500 mL). En crisis hipertensiva sintomática, mantener ambiente tranquilo, respiración lenta guiada y notificar al CMO.',
            clinicalTip:
                'Registrar presión cada 5 minutos hasta estabilización entre 95 y 135 mmHg sistólica.',
            durationSeconds: 180,
          ),
          ProcedureStep(
            step: 4,
            title: 'Escalamiento si aparece dolor torácico',
            action:
                'Si hay dolor opresivo en pecho, sudoración fría o deterioro neurológico, preparar el DEA en modo monitor y consultar protocolo ACLS de inmediato.',
            clinicalTip:
                'Guardar el registro completo de EPM y Astroskin para revisión del equipo médico.',
            durationSeconds: 120,
          ),
        ],
        requiredSupplies: [
          ProcedureSupply(
            itemId: 'MED-ORAL-REHYDRATION',
            name: 'Solución de Rehidratación Oral',
            usage:
                'Expansión de volumen en hipotensión ortostática o deshidratación',
            location: 'Bahía Médica / Cajón Verde 2',
          ),
          ProcedureSupply(
            itemId: 'AED-SPACE',
            name: 'DEA Espacial (en espera / modo monitor)',
            usage: 'Vigilancia en caso de progresión de arritmia inestable',
            location: 'Módulo Harmony / Kit Emergencia A1',
          ),
        ],
        warnings: [
          'Si el tripulante pierde el pulso o la conciencia, cambiar de inmediato a PROC-CARDIAC-ARREST.',
          'No realizar maniobras de esfuerzo o ejercicio en ARED/CEVIS mientras persista la inestabilidad.',
        ],
        criterionReference:
            'NASA-STD-3001 Cardiovascular Health & Orthostatic Intolerance Guidelines',
      ),
      MedicalProcedure(
        id: 'PROC-HYPERCAPNIA-CO2',
        code: 'IMG-ENV-05',
        title: 'Exposición a Alto CO2 (Hipercapnia en Cabina o Traje)',
        category: 'environmental',
        priority: TriagePriority.red,
        nasaHazard: 'Hostile closed environments',
        summary:
            'Manejo rápido cuando el fallo de depuradores de dióxido de carbono eleva el CO2 ambiental causando cefalea pulsátil, polipnea, confusión o somnolencia.',
        whenToActivate: [
          'Frecuencia respiratoria sostenida > 22 rpm sin ejercicio previo',
          'Dolor de cabeza intenso en varios tripulantes o alarma ECLSS de pCO2 > 4 mmHg',
          'Letargo, confusión, enrojecimiento facial o dificultad para concentrarse',
        ],
        vitalTriggers: {
          'maxRespiratoryRate': 22.0,
          'keywords': [
            'co2',
            'hipercapnia',
            'polipnea',
            'aire viciado',
            'ventilación',
            'eclss',
          ],
        },
        steps: [
          ProcedureStep(
            step: 1,
            title: 'Evacuar a módulo con aire renovado',
            action:
                'Trasladar al tripulante afectado a un módulo adyacente con ventilación nominal verificada y activar ventiladores portátiles de mezcla de aire.',
            clinicalTip:
                'En microgravedad no existe convección natural; se forman bolsas de CO2 alrededor de la cabeza si fallan los ventiladores.',
            durationSeconds: 45,
          ),
          ProcedureStep(
            step: 2,
            title: 'Suministrar aire limpio o O2 de soporte',
            action:
                'Administrar oxígeno suplementario si SpO2 < 94% o si hay disnea intensa, mientras se verifica el sistema de depuración CDRA/LiOH.',
            clinicalTip:
                'Vigilar que no se acumule fatiga respiratoria ni caída del nivel de conciencia.',
            durationSeconds: 60,
          ),
          ProcedureStep(
            step: 3,
            title: 'Control de síntomas y reevaluación',
            action:
                'Medir frecuencia respiratoria, pulso y presión cada 5 minutos. Si la cefalea persiste tras normalizar el ambiente, valorar analgesia básica.',
            clinicalTip:
                'Confirmar que el resto de la tripulación en ese módulo no presente síntomas simultáneos.',
            durationSeconds: 180,
          ),
        ],
        requiredSupplies: [
          ProcedureSupply(
            itemId: 'BVM-O2-100',
            name: 'Mascarilla de Oxígeno / Toma O2',
            usage: 'Soporte respiratorio si existe hipoxemia asociada',
            location: 'Kit Vía Aérea',
          ),
          ProcedureSupply(
            itemId: 'MED-ACETAMINOPHEN',
            name: 'Paracetamol (Acetaminofén) 500 mg',
            usage: '1 tableta tras corregir ambiente si persiste cefalea residual',
            location: 'Botiquín Principal / Cajón Verde 1',
          ),
        ],
        warnings: [
          'No regresar al módulo afectado hasta confirmar niveles seguros de pCO2 en el sistema ECLSS.',
          'No dormir en compartimentos con flujo de ventilación obstruido o apagado.',
        ],
        criterionReference:
            'NASA-STD-3001 Spacecraft Atmospheric CO2 Exposure Limits',
      ),
      MedicalProcedure(
        id: 'PROC-TRAUMA-HEMORRHAGE',
        code: 'IMG-TRM-06',
        title: 'Hemorragia, Quemaduras y Traumatismo en Microgravedad',
        category: 'trauma',
        priority: TriagePriority.red,
        nasaHazard: 'Hostile closed environments / Gravity fields',
        summary:
            'Control de sangrados, heridas abiertas, contusiones o quemaduras en cabina evitando la dispersión de fluidos biológicos en ingravidez.',
        whenToActivate: [
          'Herida con sangrado activo, laceración profunda o traumatismo mecánico',
          'Quemadura térmica, eléctrica o química en piel o extremidades',
          'Signos de choque temprano (pulso > 110 bpm, presión sistólica < 90 mmHg, palidez)',
        ],
        vitalTriggers: {
          'keywords': [
            'hemorragia',
            'sangrado',
            'herida',
            'corte',
            'quemadura',
            'trauma',
            'golpe',
          ],
        },
        steps: [
          ProcedureStep(
            step: 1,
            title: 'Contener fluidos y aplicar presión directa',
            action:
                'Colocarse guantes estériles y cubrir la herida de inmediato con gasa hemostática aplicando presión firme y continua durante 3-5 minutos para evitar gotas flotantes.',
            clinicalTip:
                'En microgravedad la sangre forma esferas y se adhiere por tensión superficial; sellar bordes con apósito absorbente.',
            durationSeconds: 180,
          ),
          ProcedureStep(
            step: 2,
            title: 'Escalar a torniquete si el sangrado es arterial',
            action:
                'Si la hemorragia en una extremidad no cede con presión directa y gasa hemostática, colocar torniquete 5-7 cm por encima de la herida y anotar hora exacta de aplicación.',
            clinicalTip:
                'Apretar hasta detener el sangrado activo; no colocar sobre articulaciones.',
            durationSeconds: 60,
          ),
          ProcedureStep(
            step: 3,
            title: 'Cuidado específico en quemaduras',
            action:
                'Enfriar la zona afectada con compresas estériles húmedas (sin hielo directo) durante 10 minutos y cubrir con gel/apósito estéril para quemaduras sin reventar ampollas.',
            clinicalTip:
                'Retirar anillos, relojes o sensores cercanos antes de que aparezca edema.',
            durationSeconds: 120,
          ),
          ProcedureStep(
            step: 4,
            title: 'Analgesia y control de signos vitales',
            action:
                'Evaluar presión arterial, pulso y llenado capilar cada 10 minutos. Administrar analgesia oral según intensidad del dolor si el paciente está consciente.',
            clinicalTip:
                'Limpiar con toallitas desinfectantes cualquier microgota liberada en cabina.',
            durationSeconds: 120,
          ),
        ],
        requiredSupplies: [
          ProcedureSupply(
            itemId: 'SUP-HEMOSTATIC-GAUZE',
            name: 'Gasa Hemostática y Apósitos Sellados',
            usage: 'Compresión directa y contención de sangre en microgravedad',
            location: 'Kit Trauma / Cajón Rojo 2',
          ),
          ProcedureSupply(
            itemId: 'SUP-TOURNIQUET',
            name: 'Torniquete Táctico de Extremidad',
            usage: 'Control de hemorragia arterial severa que no cede a presión',
            location: 'Kit Trauma / Cajón Rojo 2',
          ),
          ProcedureSupply(
            itemId: 'SUP-BURN-GEL',
            name: 'Gel y Apósitos Estériles para Quemaduras',
            usage: 'Enfriamiento y protección estéril de lesiones térmicas',
            location: 'Kit Trauma / Cajón Amarillo 2',
          ),
        ],
        warnings: [
          'No usar agua a chorro en microgravedad para lavar heridas abiertas sin bolsa de contención.',
          'No aflojar un torniquete colocado por hemorragia severa sin indicación médica.',
        ],
        criterionReference:
            'NASA-ISS Trauma & Fluid Containment Surgical Guidelines',
      ),
      MedicalProcedure(
        id: 'PROC-SANS-CEPHALEA',
        code: 'IMG-NEU-07',
        title: 'Cefalea Espacial y Congestión Neuro-Ocular (SANS)',
        category: 'neuro_ocular',
        priority: TriagePriority.yellow,
        nasaHazard: 'Gravity fields',
        summary:
            'Evaluación y alivio de dolor de cabeza, congestión facial y cambios visuales asociados al desplazamiento cefálico de fluidos en microgravedad (SANS).',
        whenToActivate: [
          'Dolor de cabeza frontal o pulsátil persistente en ingravidez',
          'Sensación de presión facial, congestión nasal o cambios de agudeza visual',
          'Presión arterial moderadamente elevada (131-155 mmHg) sin síntomas neurológicos focales',
        ],
        vitalTriggers: {
          'maxSystolicBP': 135.0,
          'keywords': [
            'cefalea',
            'dolor de cabeza',
            'sans',
            'visión',
            'ocular',
            'congestión',
          ],
        },
        steps: [
          ProcedureStep(
            step: 1,
            title: 'Descartar causa ambiental (CO2) o hipertensión severa',
            action:
                'Verificar pCO2 de cabina en el panel ECLSS y tomar presión arterial y SpO2 para descartar hipercapnia o emergencia hipertensiva.',
            clinicalTip:
                'Si varios astronautas tienen cefalea a la vez, priorizar protocolo PROC-HYPERCAPNIA-CO2.',
            durationSeconds: 60,
          ),
          ProcedureStep(
            step: 2,
            title: 'Evaluación visual básica',
            action:
                'Realizar prueba rápida de lectura cercana y cuadrícula de Amsler para detectar borrosidad o distorsión asociada a síndrome neuro-ocular SANS.',
            clinicalTip: 'Documentar si la visión empeora al despertar.',
            durationSeconds: 90,
          ),
          ProcedureStep(
            step: 3,
            title: 'Manejo sintomático e hidratación',
            action:
                'Administrar Ibuprofeno 400 mg o Paracetamol 500 mg vía oral con agua, reducir exposición a pantallas brillantes y descansar en área ventilada.',
            clinicalTip:
                'Evitar exceso de sodio en la dieta durante las siguientes 24 horas para disminuir retención cefálica.',
            durationSeconds: 60,
          ),
        ],
        requiredSupplies: [
          ProcedureSupply(
            itemId: 'MED-IBUPROFEN',
            name: 'Ibuprofeno 400 mg (Tabletas)',
            usage:
                '1 tableta cada 8 horas con alimentos o agua para cefalea leve-moderada',
            location: 'Botiquín Principal / Cajón Verde 1',
          ),
          ProcedureSupply(
            itemId: 'MED-ACETAMINOPHEN',
            name: 'Paracetamol 500 mg (Tabletas)',
            usage: 'Alternativa analgésica (1 tableta cada 6-8 h)',
            location: 'Botiquín Principal / Cajón Verde 1',
          ),
        ],
        warnings: [
          'Si aparecen visión doble, debilidad en un lado del cuerpo o confusión, activar evaluación roja inmediata.',
          'No combinar múltiples dosis de analgésicos del mismo grupo.',
        ],
        criterionReference:
            'NASA HRP Spaceflight-Associated Neuro-ocular Syndrome (SANS) Surveillance',
      ),
      MedicalProcedure(
        id: 'PROC-RENAL-DEHYDRATION',
        code: 'IMG-REN-08',
        title: 'Deshidratación Severa y Cólico Renal (Nefrolitiasis)',
        category: 'renal_metabolic',
        priority: TriagePriority.yellow,
        nasaHazard: 'Gravity fields / Space nutrition',
        summary:
            'Manejo de deshidratación, febrícula o dolor lumbar agudo por riesgo incrementado de cálculos renales debido a pérdida ósea de calcio en microgravedad.',
        whenToActivate: [
          'Temperatura > 37.3 °C (febrícula o fiebre), boca seca o taquicardia leve',
          'Dolor intenso en flanco o espalda baja irradiado a abdomen/ingle',
          'Orina concentrada, ardor al orinar o disminución de ingesta de agua',
        ],
        vitalTriggers: {
          'maxTemp': 37.3,
          'keywords': [
            'deshidratación',
            'riñón',
            'renal',
            'cólico',
            'fiebre',
            'febrícula',
            'orina',
            'temperatura',
          ],
        },
        steps: [
          ProcedureStep(
            step: 1,
            title: 'Evaluar temperatura, hidratación y glucemia',
            action:
                'Medir temperatura corporal, frecuencia cardíaca, presión arterial y glucosa con i-STAT para descartar infección sistémica o hipovolemia.',
            clinicalTip:
                'La fiebre > 38.0 °C con dolor lumbar requiere seguimiento estrecho por posible infección urinaria complicada.',
            durationSeconds: 90,
          ),
          ProcedureStep(
            step: 2,
            title: 'Iniciar rehidratación oral fraccionada',
            action:
                'Administrar solución de rehidratación oral en sorbos frecuentes (250-500 mL cada hora hasta alcanzar al menos 2.5 L/día) mediante bolsa con boquilla.',
            clinicalTip:
                'Si hay náuseas que impiden beber, administrar primero Ondansetrón 4 mg.',
            durationSeconds: 120,
          ),
          ProcedureStep(
            step: 3,
            title: 'Control del dolor y fiebre',
            action:
                'Para dolor tipo cólico o fiebre, administrar Ibuprofeno 400 mg o Paracetamol 500 mg según tolerancia gástrica e hidratación.',
            clinicalTip:
                'Evitar dosis altas de AINEs si el paciente está severamente deshidratado; priorizar hidratación primero.',
            durationSeconds: 60,
          ),
        ],
        requiredSupplies: [
          ProcedureSupply(
            itemId: 'MED-ORAL-REHYDRATION',
            name: 'Solución de Rehidratación Oral con Electrolitos',
            usage: 'Reposición hídrica fraccionada para diuresis adecuada',
            location: 'Bahía Médica / Cajón Verde 2',
          ),
          ProcedureSupply(
            itemId: 'MED-ACETAMINOPHEN',
            name: 'Paracetamol 500 mg',
            usage: 'Control térmico y analgesia segura en riesgo renal',
            location: 'Botiquín Principal / Cajón Verde 1',
          ),
          ProcedureSupply(
            itemId: 'MED-ONDANSETRON',
            name: 'Ondansetrón 4 mg',
            usage: 'Control de náuseas asociadas a cólico renal',
            location: 'Botiquín Principal / Cajón Amarillo 1',
          ),
        ],
        warnings: [
          'No suspender la hidratación salvo indicación médica explícita.',
          'Vigilar si la temperatura supera 38.0 °C o aparece incapacidad para orinar.',
        ],
        criterionReference:
            'NASA HRP Renal Stone Risk & Hydration Countermeasures',
      ),
      MedicalProcedure(
        id: 'PROC-VESTIBULAR-SAS',
        code: 'IMG-VES-09',
        title: 'Síndrome de Adaptación Espacial (Mareo y Vértigo)',
        category: 'vestibular',
        priority: TriagePriority.yellow,
        nasaHazard: 'Gravity fields',
        summary:
            'Atención de mareo cinético espacial, desorientación vestibular y náuseas durante los primeros días en microgravedad o tras transiciones gravitacionales.',
        whenToActivate: [
          'Mareo intenso al girar la cabeza, vértigo o sensación de inversión espacial',
          'Náuseas, sudoración fría o pérdida de coordinación mano-ojo',
          'Dificultad para mantener estabilidad en operaciones tras transición de gravedad',
        ],
        vitalTriggers: {
          'keywords': [
            'mareo',
            'vértigo',
            'vestibular',
            'sas',
            'equilibrio',
            'vómito',
          ],
        },
        steps: [
          ProcedureStep(
            step: 1,
            title: 'Estabilizar referencia visual y reducir giros cefálicos',
            action:
                'Anclar al tripulante en un punto fijo con orientación vertical clara respecto a los paneles del módulo y evitar movimientos bruscos de la cabeza.',
            clinicalTip:
                'Fijar la vista en un objeto cercano estático reduce rápidamente el conflicto vestibular.',
            durationSeconds: 60,
          ),
          ProcedureStep(
            step: 2,
            title: 'Medicación antiemética según actividad',
            action:
                'Si hay náuseas leves durante turno operativo, administrar Ondansetrón 4 mg (no produce sedación). Reservar Prometazina solo si el astronauta puede reposar fuera de tareas críticas.',
            clinicalTip:
                'Alistar bolsas de contención de vómito sellables al alcance inmediato.',
            durationSeconds: 45,
          ),
          ProcedureStep(
            step: 3,
            title: 'Rehidratación y retorno gradual',
            action:
                'Reponer líquidos lentamente y suspender temporalmente tareas de precisión o manejo de consola crítica hasta recuperar estabilidad.',
            clinicalTip:
                'La mayoría de los síntomas SAS se atenúan en 24-72 horas de adaptación.',
            durationSeconds: 120,
          ),
        ],
        requiredSupplies: [
          ProcedureSupply(
            itemId: 'MED-ONDANSETRON',
            name: 'Ondansetrón 4 mg (Sin sedación)',
            usage: 'Primera línea para náuseas operacionales en cabina',
            location: 'Botiquín Principal / Cajón Amarillo 1',
          ),
          ProcedureSupply(
            itemId: 'MED-PROMETHAZINE',
            name: 'Prometazina 25 mg',
            usage: 'Casos severos de mareo espacial con reposo posterior',
            location: 'Botiquín Principal / Cajón Amarillo 1',
          ),
        ],
        warnings: [
          'No operar controles críticos, brazo robótico ni EVA después de tomar Prometazina por riesgo de somnolencia.',
          'Descartar hipoxia o alto CO2 antes de asumir que todo mareo es vestibular.',
        ],
        criterionReference:
            'NASA HRP Sensorimotor & Space Adaptation Syndrome Protocol',
      ),
      MedicalProcedure(
        id: 'PROC-CIRCADIAN-FATIGUE',
        code: 'IMG-BHP-10',
        title: 'Déficit Crítico de Sueño, Fatiga Cognitiva y Estrés',
        category: 'behavioral_circadian',
        priority: TriagePriority.green,
        nasaHazard: 'Isolation and confinement',
        summary:
            'Intervención preventiva ante privación acumulada de sueño (< 6.5 h/día), múltiples despertares nocturnos o fatiga emocional por confinamiento prolongado.',
        whenToActivate: [
          'Horas de sueño registradas < 6.5 h en Actiwatch o múltiples despertares (>= 3)',
          'Ánimo matutino reportado como fatigado o estresado',
          'Disminución de rendimiento cognitivo, irritabilidad o errores operacionales leves',
        ],
        vitalTriggers: {
          'maxSleepHours': 6.5,
          'keywords': [
            'sueño',
            'insomnio',
            'fatiga',
            'estrés',
            'descanso',
            'cansancio',
            'ánimo',
          ],
        },
        steps: [
          ProcedureStep(
            step: 1,
            title: 'Reestructurar ventana de descanso y luz de cabina',
            action:
                'Programar un bloque protegido de descanso de al menos 7.5-8 horas, atenuando luz azul en el compartimento de descanso 60 minutos antes de dormir.',
            clinicalTip:
                'En órbita ocurren 16 amaneceres cada 24 horas; el control de iluminación LED azul/cálida es clave para sincronizar el ritmo circadiano.',
            durationSeconds: 60,
          ),
          ProcedureStep(
            step: 2,
            title: 'Técnicas de respiración y reducción de ruido',
            action:
                'Realizar 5 minutos de respiración lenta guiada (4 segundos inhalar, 6 segundos exhalar) y usar protección auditiva o antifaz para bloquear ruido de ventiladores.',
            clinicalTip:
                'Verificar que el flujo de aire en el saco de dormir esté activo para evitar acumulación nocturna de CO2.',
            durationSeconds: 300,
          ),
          ProcedureStep(
            step: 3,
            title: 'Soporte circadiano con Melatonina si persiste insomnio',
            action:
                'Si tras 2 noches persiste latencia de sueño prolongada, administrar Melatonina 3 mg 30-60 minutos antes del ciclo de descanso programado.',
            clinicalTip:
                'Reasignar tareas de alta precisión si el sueño acumulado fue menor a 5 horas.',
            durationSeconds: 30,
          ),
        ],
        requiredSupplies: [
          ProcedureSupply(
            itemId: 'MED-MELATONIN',
            name: 'Melatonina 3 mg (Tabletas)',
            usage:
                '1 tableta 30-60 min antes de dormir para resincronización circadiana',
            location: 'Botiquín Principal / Cajón Verde 3',
          ),
        ],
        warnings: [
          'Evitar cafeína al menos 6 horas antes del bloque de sueño.',
          'No apagar los ventiladores del compartimento de descanso por ruido; usar tapones auditivos en su lugar.',
        ],
        criterionReference:
            'NASA-STD-3001 Behavioral Health & Circadian Fatigue Management',
      ),
    ];
  }

  /// Escenarios rápidos de triage clínico para selección en cabina.
  static List<ClinicalScenario> getScenarios() {
    return const [
      ClinicalScenario(
        id: 'SIT-CARDIAC-ARREST',
        label: 'Paro Cardíaco (RCP)',
        symptomSummary:
            'Tripulante inconsciente, no respira o sin pulso detectable',
        priority: TriagePriority.red,
        recommendedProcedureId: 'PROC-CARDIAC-ARREST',
        first60Seconds: [
          'Confirmar inconsciencia y ausencia de respiración en 10 segundos.',
          'Fijar al paciente en camilla CMRS o aplicar abrazo invertido de sujeción.',
          'Iniciar compresiones torácicas (100-120/min) usando método Handstand o Evetts-Russomano y traer el DEA.',
        ],
        verificationQuestions: [
          '¿Responde al llamado o estímulo firme en los hombros?',
          '¿Presenta respiración normal o solo jadeo agónico?',
          '¿El sensor Astroskin/EPM muestra pérdida súbita de pulso o ritmo caótico?',
        ],
        emergencySupplies: [
          'CMRS-BOARD',
          'AED-SPACE',
          'BVM-O2-100',
          'MED-EPINEPHRINE',
        ],
      ),
      ClinicalScenario(
        id: 'SIT-HYPOXIA',
        label: 'Hipoxia / Falta de Aire',
        symptomSummary:
            'Ahogo intenso, SpO2 < 90% o síntomas tras caminata EVA',
        priority: TriagePriority.red,
        recommendedProcedureId: 'PROC-HYPOXIA-DECOMP',
        first60Seconds: [
          'Colocar mascarilla con O2 al 100% (10-15 L/min).',
          'Verificar presión de cabina y sello de escotilla/traje EVA.',
          'Mantener en reposo y vigilar SpO2 cada 2 minutos.',
        ],
        verificationQuestions: [
          '¿El SpO2 está por debajo de 90%?',
          '¿Acaba de regresar de una caminata espacial (EVA)?',
          '¿Presenta dolor articular, mareo o coloración azulada en labios?',
        ],
        emergencySupplies: ['BVM-O2-100', 'MED-ORAL-REHYDRATION'],
      ),
      ClinicalScenario(
        id: 'SIT-RADIATION',
        label: 'Radiación / Tormenta Solar',
        symptomSummary:
            'Alarma del dosímetro HERA o náuseas tras alerta solar (SPE)',
        priority: TriagePriority.red,
        recommendedProcedureId: 'PROC-RADIATION-ARS',
        first60Seconds: [
          'Evacuar de inmediato al refugio blindado (Storm Shelter).',
          'Verificar lectura del dosímetro personal HERA.',
          'Administrar Ondansetrón 4 mg si presenta náuseas o vómitos.',
        ],
        verificationQuestions: [
          '¿La tasa de dosis supera 150 uSv/h?',
          '¿Aparecieron náuseas, vómitos o fatiga repentina?',
          '¿Estuvo en módulo no blindado o en EVA durante el evento?',
        ],
        emergencySupplies: ['MED-ONDANSETRON', 'MED-ORAL-REHYDRATION'],
      ),
      ClinicalScenario(
        id: 'SIT-HEMODYNAMIC',
        label: 'Crisis de Presión / Arritmia',
        symptomSummary:
            'Presión muy baja o alta, taquicardia severa (>115 bpm) o presíncope',
        priority: TriagePriority.red,
        recommendedProcedureId: 'PROC-HEMODYNAMIC-SYNCOPE',
        first60Seconds: [
          'Detener actividad y anclar al astronauta en posición de reposo.',
          'Conectar Astroskin y EPM para vigilar pulso y presión continua.',
          'Verificar SpO2 y glucemia capilar para descartar hipoxia o hipoglucemia.',
        ],
        verificationQuestions: [
          '¿La presión sistólica es < 85 mmHg o > 160 mmHg?',
          '¿Siente dolor torácico, palpitaciones o visión en túnel?',
          '¿Mantiene estado de alerta normal y pulso palpable?',
        ],
        emergencySupplies: ['MED-ORAL-REHYDRATION', 'AED-SPACE'],
      ),
      ClinicalScenario(
        id: 'SIT-CO2',
        label: 'Alto CO2 / Aire Viciado',
        symptomSummary:
            'Respiración rápida (>22 rpm), confusión o dolor de cabeza en cabina',
        priority: TriagePriority.red,
        recommendedProcedureId: 'PROC-HYPERCAPNIA-CO2',
        first60Seconds: [
          'Trasladar al tripulante a un módulo adyacente con ventilación nominal.',
          'Activar ventiladores de mezcla de aire para disipar bolsas de CO2.',
          'Suministrar oxígeno si SpO2 cae por debajo de 94%.',
        ],
        verificationQuestions: [
          '¿La alarma de pCO2 del sistema ECLSS está activa?',
          '¿Otros tripulantes en el mismo módulo presentan cefalea o fatiga?',
        ],
        emergencySupplies: ['BVM-O2-100', 'MED-ACETAMINOPHEN'],
      ),
      ClinicalScenario(
        id: 'SIT-TRAUMA',
        label: 'Herida / Quemadura',
        symptomSummary:
            'Sangrado activo, golpe fuerte o quemadura en piel/extremidades',
        priority: TriagePriority.red,
        recommendedProcedureId: 'PROC-TRAUMA-HEMORRHAGE',
        first60Seconds: [
          'Colocar guantes y presionar firmemente con gasa hemostática sellada.',
          'Contener cualquier gota de sangre en microgravedad.',
          'En quemaduras, enfriar con compresa húmeda estéril y cubrir con gel estéril.',
        ],
        verificationQuestions: [
          '¿El sangrado es pulsátil o no se detiene tras 5 minutos de presión?',
          '¿La lesión afecta cara, ojos o vías respiratorias?',
        ],
        emergencySupplies: [
          'SUP-HEMOSTATIC-GAUZE',
          'SUP-TOURNIQUET',
          'SUP-BURN-GEL',
        ],
      ),
      ClinicalScenario(
        id: 'SIT-SANS',
        label: 'Dolor de Cabeza / Visión',
        symptomSummary:
            'Cefalea frontal, congestión facial o visión borrosa (SANS)',
        priority: TriagePriority.yellow,
        recommendedProcedureId: 'PROC-SANS-CEPHALEA',
        first60Seconds: [
          'Descartar primero nivel elevado de CO2 y tomar presión arterial.',
          'Realizar prueba rápida de lectura/rejilla visual.',
          'Administrar analgésico oral estándar y reducir brillo de pantallas.',
        ],
        verificationQuestions: [
          '¿La visión borrosa es progresiva o reciente?',
          '¿Presenta fiebre o rigidez cervical?',
        ],
        emergencySupplies: ['MED-IBUPROFEN', 'MED-ACETAMINOPHEN'],
      ),
      ClinicalScenario(
        id: 'SIT-DEHYDRATION',
        label: 'Fiebre / Deshidratación',
        symptomSummary:
            'Temperatura elevada (>37.3 °C), dolor lumbar/renal o baja hidratación',
        priority: TriagePriority.yellow,
        recommendedProcedureId: 'PROC-RENAL-DEHYDRATION',
        first60Seconds: [
          'Medir temperatura, frecuencia cardíaca y glucosa capilar.',
          'Iniciar rehidratación oral en sorbos frecuentes con electrolitos.',
          'Controlar dolor o fiebre con Paracetamol 500 mg.',
        ],
        verificationQuestions: [
          '¿Presenta dolor en costado lumbar o ardor al orinar?',
          '¿Tolera líquidos por vía oral sin vomitar?',
        ],
        emergencySupplies: [
          'MED-ORAL-REHYDRATION',
          'MED-ACETAMINOPHEN',
          'MED-ONDANSETRON',
        ],
      ),
      ClinicalScenario(
        id: 'SIT-VESTIBULAR',
        label: 'Mareo / Vértigo Espacial',
        symptomSummary:
            'Desorientación espacial, vértigo o náuseas por microgravedad (SAS)',
        priority: TriagePriority.yellow,
        recommendedProcedureId: 'PROC-VESTIBULAR-SAS',
        first60Seconds: [
          'Anclar al tripulante mirando una referencia vertical fija y evitar giros de cabeza.',
          'Tener lista bolsa sellada de contención.',
          'Administrar Ondansetrón 4 mg si requiere mantener alerta operativa.',
        ],
        verificationQuestions: [
          '¿El mareo ocurre al mover la cabeza en los primeros días en órbita?',
          '¿Los signos vitales (SpO2 y presión) son normales?',
        ],
        emergencySupplies: ['MED-ONDANSETRON', 'MED-PROMETHAZINE'],
      ),
      ClinicalScenario(
        id: 'SIT-FATIGUE',
        label: 'Fatiga / Insomnio',
        symptomSummary:
            'Sueño menor a 6.5 horas, despertares frecuentes o agotamiento',
        priority: TriagePriority.green,
        recommendedProcedureId: 'PROC-CIRCADIAN-FATIGUE',
        first60Seconds: [
          'Programar bloque protegido de descanso (7.5-8 h) con luz azul atenuada.',
          'Practicar respiración guiada 4-6 y revisar flujo de aire en el saco de dormir.',
          'Considerar Melatonina 3 mg si persiste dificultad para conciliar el sueño.',
        ],
        verificationQuestions: [
          '¿Lleva más de 2 ciclos con menos de 6 horas de sueño?',
          '¿Está asignado a tareas críticas que requieran alta precisión?',
        ],
        emergencySupplies: ['MED-MELATONIN'],
      ),
    ];
  }
}
