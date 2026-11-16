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
      debugPrint('Warning: using the local medical procedures catalog: $e');
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
      debugPrint('Warning: using local clinical triage scenarios: $e');
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
              'Reported situation (${scenario.label}): ${scenario.symptomSummary}.';
          break;
        }
      }

      final targetProc = findById(targetProcedureId, procedures);
      if (targetProc != null) {
        addSuggestion(
          targetProc.id,
          scenarioNote ?? 'Active clinical situation: ${targetProc.summary}',
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
        'Critical pulse (${v.heartRate.toInt()} bpm) with circulatory compromise. Check consciousness/pulse and initiate microgravity CPR.',
        true,
      );
    }

    if (v.spO2 < 90.0) {
      addSuggestion(
        'PROC-HYPOXIA-DECOMP',
        'Critical SpO2 (${v.spO2.toStringAsFixed(0)}%). Administer 100% oxygen and check EVA/cabin seals.',
        true,
      );
    }

    if (r.doseRateMicroSvPerHour > 100.0 ||
        r.severity == RadiationSeverity.critical) {
      addSuggestion(
        'PROC-RADIATION-ARS',
        'Elevated radiation dose rate (${r.doseRateMicroSvPerHour.toStringAsFixed(0)} µSv/h). Move to a shielded shelter and monitor symptoms.',
        true,
      );
    }

    if (v.heartRate > 115.0 ||
        v.heartRate < 48.0 ||
        v.systolicBP < 88.0 ||
        v.systolicBP > 145.0) {
      addSuggestion(
        'PROC-HEMODYNAMIC-SYNCOPE',
        'Hemodynamic instability (HR ${v.heartRate.toInt()} bpm, BP ${v.systolicBP.toInt()}/${v.diastolicBP.toInt()} mmHg). Rest and monitor cardiovascular status.',
        v.systolicBP < 85.0 || v.systolicBP > 160.0 || v.heartRate > 115.0,
      );
    }

    if (v.respiratoryRate > 22.0) {
      addSuggestion(
        'PROC-HYPERCAPNIA-CO2',
        'Elevated respiratory rate (${v.respiratoryRate.toInt()} breaths/min). Assess CO2 buildup and cabin ventilation.',
        v.respiratoryRate >= 26.0,
      );
    }

    if (v.bodyTemp > 37.3) {
      addSuggestion(
        'PROC-RENAL-DEHYDRATION',
        'Elevated temperature (${v.bodyTemp.toStringAsFixed(1)} °C). Increase oral hydration and temperature monitoring.',
        v.bodyTemp > 38.0,
      );
    }

    if (v.systolicBP > MedicalThresholds.maxSystolicBP &&
        v.systolicBP <= 145.0) {
      addSuggestion(
        'PROC-SANS-CEPHALEA',
        'Borderline blood pressure (${v.systolicBP.toInt()}/${v.diastolicBP.toInt()} mmHg). Monitor headache and vision (SANS).',
        false,
      );
    }

    if (s.sleepHours < MedicalThresholds.minRecommendedSleepHours ||
        s.wakeEpisodes >= 3) {
      addSuggestion(
        'PROC-CIRCADIAN-FATIGUE',
        'Sleep deficit (${s.sleepHours.toStringAsFixed(1)} h, ${s.wakeEpisodes} awakenings). Apply the sleep hygiene protocol.',
        false,
      );
    }

    if (suggestions.isEmpty) {
      addSuggestion(
        'PROC-CIRCADIAN-FATIGUE',
        'Crew member stable (Nominal Status). Maintain preventive monitoring and a healthy sleep routine.',
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
        title: 'Cardiac Arrest and Microgravity CPR (Space ACLS)',
        category: 'cardiovascular',
        priority: TriagePriority.red,
        nasaHazard: 'Gravity fields / Distance from Earth',
        summary:
            'Cardiopulmonary resuscitation adapted for weightlessness when a crew member is unconscious, is not breathing, has no pulse, or has a shockable rhythm.',
        whenToActivate: [
          'Unconscious crew member unresponsive to verbal or tactile stimuli',
          'Absent normal breathing or agonal breathing (gasping)',
          'Absent central pulse or critical heart rate (< 40 bpm or > 150 bpm without perfusion)',
          'Capillary refill > 3.0 seconds with cyanosis or an Astroskin asystole/VF alert',
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
            title: 'Confirm arrest and activate the cabin alarm',
            action:
                'Check consciousness and breathing within 10 seconds. Activate the cabin medical alert to summon the Crew Medical Officer (CMO) and the rest of the crew.',
            clinicalTip:
                'Do not waste time checking a radial pulse if the patient is unresponsive and not breathing; prepare for CPR immediately.',
            durationSeconds: 10,
          ),
          ProcedureStep(
            step: 2,
            title: 'Secure the patient in the CMRS',
            action:
                'Secure the patient to the rigid Crew Medical Restraint System (CMRS) board with chest, pelvic, and leg straps to prevent drifting with each compression.',
            clinicalTip:
                'If alone before the CMRS is deployed, wrap your legs around the patient at the waist (reverse bear hug) while a second crew member brings the CMRS and AED.',
            durationSeconds: 30,
          ),
          ProcedureStep(
            step: 3,
            title: 'Start chest compressions in microgravity',
            action:
                'Apply continuous compressions at the center of the sternum at 100-120 per minute and a depth of 5 to 6 cm. Use the Handstand method (brace feet against the opposite module wall/ceiling to generate axial force) or the Evetts-Russomano method.',
            clinicalTip:
                'Allow full chest recoil between compressions and change rescuers every 2 minutes to prevent fatigue.',
            durationSeconds: 120,
          ),
          ProcedureStep(
            step: 4,
            title: 'Apply the space AED',
            action:
                'Turn on the automated external defibrillator, apply adhesive pads to the dry chest (right subclavicular and left infra-axillary positions), and briefly pause compressions only during rhythm analysis.',
            clinicalTip:
                'Before delivering a shock, visually confirm that no crew member is touching the patient or the metal CMRS frame.',
            durationSeconds: 25,
          ),
          ProcedureStep(
            step: 5,
            title: 'Ventilate with a BVM and 100% O2',
            action:
                'Maintain a patent airway using a jaw thrust or oropharyngeal airway. Give 2 rescue breaths after every 30 compressions using a bag-valve-mask connected to 100% oxygen.',
            clinicalTip:
                'Avoid excessive ventilation (no more than 1 second per breath, until visible chest rise).',
            durationSeconds: 20,
          ),
          ProcedureStep(
            step: 6,
            title: 'Provide ACLS support and record telemetry',
            action:
                'If spontaneous circulation has not returned after 2 minutes of CPR and defibrillation, administer epinephrine 1 mg IV/IO every 3-5 minutes. Record events and queue a report for flight surgeons.',
            clinicalTip:
                'Continue uninterrupted 2-minute cycles until a palpable pulse returns or medical direction advises stopping.',
            durationSeconds: 120,
          ),
        ],
        requiredSupplies: [
          ProcedureSupply(
            itemId: 'CMRS-BOARD',
            name: 'Crew Medical Restraint System (CMRS Board)',
            usage: 'Secure the patient and rescuer in microgravity',
            location: 'Medical Bay / CHeCS Rack',
          ),
          ProcedureSupply(
            itemId: 'AED-SPACE',
            name: 'Space Automated External Defibrillator (AED)',
            usage: 'Rhythm analysis and biphasic defibrillation',
            location: 'Harmony Module / Emergency Kit A1',
          ),
          ProcedureSupply(
            itemId: 'BVM-O2-100',
            name: 'Bag-Valve-Mask + 100% O2 Outlet',
            usage: 'Assisted ventilation at 30:2 with supplemental oxygen',
            location: 'Harmony Module / Airway Kit',
          ),
          ProcedureSupply(
            itemId: 'MED-EPINEPHRINE',
            name: 'Epinephrine 1 mg/10 mL (Prefilled Syringe)',
            usage:
                '1 mg IV/IO every 3-5 minutes for non-shockable or refractory rhythms',
            location: 'ACLS Kit / Red Drawer 1',
          ),
        ],
        warnings: [
          'Never attempt compressions without body restraint; Newton’s third law will push the rescuer away from the patient.',
          'Ensure the chest surface is dry before applying AED pads.',
          'Do not interrupt compressions for more than 10 seconds during airway placement or analysis.',
        ],
        criterionReference:
            'NASA-STD-3001 / ISS Integrated Medical Group ACLS & Microgravity CPR Checklist',
      ),
      MedicalProcedure(
        id: 'PROC-HYPOXIA-DECOMP',
        code: 'IMG-HYP-02',
        title: 'Acute Hypoxia and Post-EVA Decompression',
        category: 'respiratory',
        priority: TriagePriority.red,
        nasaHazard: 'Hostile closed environments / Gravity fields',
        summary:
            'Immediate care for critically low blood oxygen (SpO2 < 90%), an EVA suit leak, depressurization, or decompression sickness.',
        whenToActivate: [
          'SpO2 < 90% confirmed by Astroskin Bio-Monitor or pulse oximeter',
          'Severe breathlessness, rapid breathing (> 24 breaths/min), or confusion',
          'Joint pain, dizziness, or paresthesia after a spacewalk (EVA)',
          'Lip/nail cyanosis or capillary refill > 2.5 seconds',
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
            title: 'Administer 100% supplemental oxygen',
            action:
                'Apply a non-rebreather mask or closed circuit with 100% O2 (10-15 L/min), keeping the astronaut resting, semi-reclined, and secured.',
            clinicalTip:
                'Immediately check cabin pressure and ambient O2 on the ECLSS panel.',
            durationSeconds: 30,
          ),
          ProcedureStep(
            step: 2,
            title: 'Check hatch and EVA suit seals',
            action:
                'If the event occurs in the airlock after an EVA, ensure nominal pressurization at 101.3 kPa (14.7 psi) and assess for bubbles or neurological symptoms of decompression sickness (DCS).',
            clinicalTip:
                'If decompression sickness symptoms are present, initiate the airlock hyperbaric recompression protocol with 100% O2.',
            durationSeconds: 60,
          ),
          ProcedureStep(
            step: 3,
            title: 'Monitor vital signs every 2 minutes',
            action:
                'Connect Astroskin and i-STAT to monitor SpO2 recovery to >= 95%, decreasing heart rate, and venous saturation/blood gases.',
            clinicalTip:
                'If SpO2 does not exceed 92% after 5 minutes of 100% O2, assist ventilation with a BVM and prepare a red alert to Earth.',
            durationSeconds: 120,
          ),
          ProcedureStep(
            step: 4,
            title: 'Provide hydration and rest after the event',
            action:
                'Once stable (SpO2 >= 94%), give oral fluids with electrolytes and continue monitoring for 4 hours.',
            clinicalTip:
                'Do not resume physical activity or EVA until medically cleared.',
            durationSeconds: 180,
          ),
        ],
        requiredSupplies: [
          ProcedureSupply(
            itemId: 'BVM-O2-100',
            name: '100% Oxygen Mask / BVM',
            usage: 'Immediate high-flow oxygen delivery',
            location: 'Quest Airlock / Airway Kit',
          ),
          ProcedureSupply(
            itemId: 'MED-ORAL-REHYDRATION',
            name: 'Oral Rehydration Solution with Electrolytes',
            usage: 'Hemodynamic support after respiratory stabilization',
            location: 'Medical Bay / Green Drawer 2',
          ),
        ],
        warnings: [
          'Do not stop oxygen prematurely even if the crew member reports feeling better.',
          'Avoid physical exertion while respiratory rate exceeds 20 breaths/min.',
        ],
        criterionReference:
            'NASA-STD-3001 Vol. 2 Atmosphere & Decompression Sickness Protocol',
      ),
      MedicalProcedure(
        id: 'PROC-RADIATION-ARS',
        code: 'IMG-RAD-03',
        title: 'Acute Radiation Syndrome (ARS) and Solar Particle Event (SPE)',
        category: 'radiation',
        priority: TriagePriority.red,
        nasaHazard: 'Space radiation',
        summary:
            'Protection and clinical management for a solar particle event (SPE), dose rate > 150 µSv/h, or prodromal radiation symptoms.',
        whenToActivate: [
          'HERA dosimetry alarm with dose rate > 150 µSv/h or rapidly rising cumulative dose',
          'Nausea, vomiting, sudden fatigue, or skin erythema after a solar storm alert',
          'Crew member exposed outside the main module during an SPE',
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
            title: 'Move immediately to the Storm Shelter',
            action:
                'Abort all external module activity or EVA. Move the entire crew to the shielded shelter surrounded by water reserves and hydrogen-rich supplies.',
            clinicalTip:
                'Each minute outside shielding during an SPE peak increases the absorbed bone marrow dose.',
            durationSeconds: 120,
          ),
          ProcedureStep(
            step: 2,
            title: 'Control nausea and prodromal symptoms',
            action:
                'For early nausea or vomiting, administer ondansetron 4-8 mg sublingually/orally to prevent dehydration and aspiration in microgravity.',
            clinicalTip:
                'Record the exact onset time of nausea to help estimate the absorbed biological dose.',
            durationSeconds: 60,
          ),
          ProcedureStep(
            step: 3,
            title: 'Perform hematological assessment and dosimetry',
            action:
                'Take a HERA Radiation Assay reading and capillary i-STAT analysis to monitor electrolytes, glucose, and metabolic status.',
            clinicalTip:
                'Compare cumulative dose against NASA-STD-3001 operational limits.',
            durationSeconds: 180,
          ),
          ProcedureStep(
            step: 4,
            title: 'Maintain hydration and continuous monitoring',
            action:
                'Maintain fluid intake with electrolytes, avoid nephrotoxic drugs, and remain sheltered until decreased solar flux is confirmed.',
            clinicalTip:
                'Reassess oxidative damage biomarkers and lymphocyte count if equipment is available.',
            durationSeconds: 300,
          ),
        ],
        requiredSupplies: [
          ProcedureSupply(
            itemId: 'MED-ONDANSETRON',
            name: 'Ondansetron 4 mg (Dispersible Tablets)',
            usage:
                '1 tablet every 8 hours for radiation-related nausea/vomiting',
            location: 'Main Medical Kit / Yellow Drawer 1',
          ),
          ProcedureSupply(
            itemId: 'MED-ORAL-REHYDRATION',
            name: 'Oral Rehydration Solution',
            usage: 'Controlled fluid replacement in the shelter',
            location: 'Storm Shelter / Emergency Kit',
          ),
        ],
        warnings: [
          'Do not leave the shielded shelter until the HERA dosimeter shows stable baseline levels.',
          'Avoid aspirin or NSAIDs if platelet impairment is suspected.',
        ],
        criterionReference:
            'NASA-STD-3001 Permissible Exposure Limits (PEL) & SRAG SPE Protocol',
      ),
      MedicalProcedure(
        id: 'PROC-HEMODYNAMIC-SYNCOPE',
        code: 'IMG-HEM-04',
        title: 'Arrhythmia, Severe Hypotension or Hypertensive Crisis',
        category: 'hemodynamics',
        priority: TriagePriority.red,
        nasaHazard: 'Gravity fields',
        summary:
            'Cardiovascular stabilization for dangerous blood pressure (< 85 or > 160 mmHg), sustained tachycardia (> 115 bpm), bradycardia (< 48 bpm), or presyncope.',
        whenToActivate: [
          'Systolic pressure < 85 mmHg or > 160 mmHg',
          'Resting heart rate > 115 bpm or symptomatic rate < 48 bpm',
          'Postural dizziness, tunnel vision, chest pain, or palpitations',
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
            title: 'Rest and secure horizontally',
            action:
                'Stop physical activity immediately, secure the astronaut in a resting position, and connect Astroskin and the EPM Cardiocavity Module for continuous recording.',
            clinicalTip:
                'In partial gravity (Moon/Mars), gently elevate the legs if hypotensive.',
            durationSeconds: 45,
          ),
          ProcedureStep(
            step: 2,
            title: 'Rule out reversible causes',
            action:
                'Check SpO2, capillary glucose with i-STAT, body temperature, and cabin CO2 to rule out hypoxia, hypoglycemia, or hypercapnia.',
            clinicalTip:
                'Blood glucose < 70 mg/dL can mimic a severe autonomic crisis.',
            durationSeconds: 90,
          ),
          ProcedureStep(
            step: 3,
            title: 'Provide hemodynamic support',
            action:
                'For hypotension without pulmonary edema, give a rapid oral fluid load with electrolytes (500 mL). For symptomatic hypertensive crisis, maintain a quiet environment, guide slow breathing, and notify the CMO.',
            clinicalTip:
                'Record blood pressure every 5 minutes until systolic pressure stabilizes between 95 and 135 mmHg.',
            durationSeconds: 180,
          ),
          ProcedureStep(
            step: 4,
            title: 'Escalate if chest pain develops',
            action:
                'For crushing chest pain, cold sweats, or neurological deterioration, prepare the AED in monitor mode and consult the ACLS protocol immediately.',
            clinicalTip:
                'Save the complete EPM and Astroskin recording for medical team review.',
            durationSeconds: 120,
          ),
        ],
        requiredSupplies: [
          ProcedureSupply(
            itemId: 'MED-ORAL-REHYDRATION',
            name: 'Oral Rehydration Solution',
            usage:
                'Volume replacement for orthostatic hypotension or dehydration',
            location: 'Medical Bay / Green Drawer 2',
          ),
          ProcedureSupply(
            itemId: 'AED-SPACE',
            name: 'Space AED (Standby / Monitor Mode)',
            usage: 'Monitoring for progression of unstable arrhythmia',
            location: 'Harmony Module / Emergency Kit A1',
          ),
        ],
        warnings: [
          'If the crew member loses their pulse or consciousness, switch immediately to PROC-CARDIAC-ARREST.',
          'Do not strain or exercise on ARED/CEVIS while instability persists.',
        ],
        criterionReference:
            'NASA-STD-3001 Cardiovascular Health & Orthostatic Intolerance Guidelines',
      ),
      MedicalProcedure(
        id: 'PROC-HYPERCAPNIA-CO2',
        code: 'IMG-ENV-05',
        title: 'High CO2 Exposure (Cabin or Suit Hypercapnia)',
        category: 'environmental',
        priority: TriagePriority.red,
        nasaHazard: 'Hostile closed environments',
        summary:
            'Rapid management when carbon dioxide scrubber failure raises ambient CO2, causing throbbing headache, rapid breathing, confusion, or drowsiness.',
        whenToActivate: [
          'Sustained respiratory rate > 22 breaths/min without prior exercise',
          'Severe headache in several crew members or ECLSS pCO2 alarm > 4 mmHg',
          'Lethargy, confusion, facial flushing, or difficulty concentrating',
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
            title: 'Evacuate to a module with fresh air',
            action:
                'Move the affected crew member to an adjacent module with verified nominal ventilation and turn on portable air-mixing fans.',
            clinicalTip:
                'There is no natural convection in microgravity; CO2 pockets form around the head if fans fail.',
            durationSeconds: 45,
          ),
          ProcedureStep(
            step: 2,
            title: 'Provide clean air or supplemental O2',
            action:
                'Give supplemental oxygen if SpO2 < 94% or severe dyspnea is present while checking the CDRA/LiOH scrubber system.',
            clinicalTip:
                'Watch for increasing respiratory fatigue or declining consciousness.',
            durationSeconds: 60,
          ),
          ProcedureStep(
            step: 3,
            title: 'Monitor symptoms and reassess',
            action:
                'Measure respiratory rate, pulse, and blood pressure every 5 minutes. Consider basic analgesia if headache persists after environmental conditions normalize.',
            clinicalTip:
                'Check whether other crew members in the module have simultaneous symptoms.',
            durationSeconds: 180,
          ),
        ],
        requiredSupplies: [
          ProcedureSupply(
            itemId: 'BVM-O2-100',
            name: 'Oxygen Mask / O2 Outlet',
            usage: 'Respiratory support for associated hypoxemia',
            location: 'Airway Kit',
          ),
          ProcedureSupply(
            itemId: 'MED-ACETAMINOPHEN',
            name: 'Paracetamol (Acetaminophen) 500 mg',
            usage: '1 tablet after environmental correction if residual headache persists',
            location: 'Main Medical Kit / Green Drawer 1',
          ),
        ],
        warnings: [
          'Do not return to the affected module until safe pCO2 levels are confirmed on ECLSS.',
          'Do not sleep in compartments with blocked or inactive ventilation.',
        ],
        criterionReference:
            'NASA-STD-3001 Spacecraft Atmospheric CO2 Exposure Limits',
      ),
      MedicalProcedure(
        id: 'PROC-TRAUMA-HEMORRHAGE',
        code: 'IMG-TRM-06',
        title: 'Hemorrhage, Burns and Trauma in Microgravity',
        category: 'trauma',
        priority: TriagePriority.red,
        nasaHazard: 'Hostile closed environments / Gravity fields',
        summary:
            'Control cabin bleeding, open wounds, contusions, or burns while preventing biological fluid dispersal in weightlessness.',
        whenToActivate: [
          'Actively bleeding wound, deep laceration, or mechanical trauma',
          'Thermal, electrical, or chemical burn to skin or limbs',
          'Early shock signs (pulse > 110 bpm, systolic pressure < 90 mmHg, pallor)',
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
            title: 'Contain fluids and apply direct pressure',
            action:
                'Put on sterile gloves and immediately cover the wound with hemostatic gauze, applying firm continuous pressure for 3-5 minutes to prevent floating droplets.',
            clinicalTip:
                'In microgravity, blood forms spheres and adheres through surface tension; seal edges with an absorbent dressing.',
            durationSeconds: 180,
          ),
          ProcedureStep(
            step: 2,
            title: 'Escalate to a tourniquet for arterial bleeding',
            action:
                'If limb bleeding persists despite direct pressure and hemostatic gauze, apply a tourniquet 5-7 cm above the wound and record the exact application time.',
            clinicalTip:
                'Tighten until active bleeding stops; do not place over joints.',
            durationSeconds: 60,
          ),
          ProcedureStep(
            step: 3,
            title: 'Provide burn-specific care',
            action:
                'Cool the affected area with moist sterile compresses (no direct ice) for 10 minutes and cover with sterile burn gel/dressing without bursting blisters.',
            clinicalTip:
                'Remove nearby rings, watches, or sensors before swelling develops.',
            durationSeconds: 120,
          ),
          ProcedureStep(
            step: 4,
            title: 'Provide analgesia and monitor vital signs',
            action:
                'Assess blood pressure, pulse, and capillary refill every 10 minutes. Give oral analgesia according to pain severity if the patient is conscious.',
            clinicalTip:
                'Clean any droplets released into the cabin with disinfectant wipes.',
            durationSeconds: 120,
          ),
        ],
        requiredSupplies: [
          ProcedureSupply(
            itemId: 'SUP-HEMOSTATIC-GAUZE',
            name: 'Hemostatic Gauze and Sealed Dressings',
            usage: 'Direct compression and blood containment in microgravity',
            location: 'Trauma Kit / Red Drawer 2',
          ),
          ProcedureSupply(
            itemId: 'SUP-TOURNIQUET',
            name: 'Tactical Limb Tourniquet',
            usage: 'Control severe arterial bleeding unresponsive to pressure',
            location: 'Trauma Kit / Red Drawer 2',
          ),
          ProcedureSupply(
            itemId: 'SUP-BURN-GEL',
            name: 'Sterile Burn Gel and Dressings',
            usage: 'Cooling and sterile protection of thermal injuries',
            location: 'Trauma Kit / Yellow Drawer 2',
          ),
        ],
        warnings: [
          'Do not use running water to irrigate open wounds in microgravity without a containment bag.',
          'Do not loosen a tourniquet applied for severe bleeding without medical direction.',
        ],
        criterionReference:
            'NASA-ISS Trauma & Fluid Containment Surgical Guidelines',
      ),
      MedicalProcedure(
        id: 'PROC-SANS-CEPHALEA',
        code: 'IMG-NEU-07',
        title: 'Space Headache and Neuro-Ocular Congestion (SANS)',
        category: 'neuro_ocular',
        priority: TriagePriority.yellow,
        nasaHazard: 'Gravity fields',
        summary:
            'Assessment and relief of headache, facial congestion, and visual changes associated with headward fluid shifts in microgravity (SANS).',
        whenToActivate: [
          'Persistent frontal or throbbing headache in weightlessness',
          'Facial pressure, nasal congestion, or changes in visual acuity',
          'Moderately elevated blood pressure (131-155 mmHg) without focal neurological symptoms',
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
            title: 'Rule out environmental CO2 or severe hypertension',
            action:
                'Check cabin pCO2 on the ECLSS panel and measure blood pressure and SpO2 to rule out hypercapnia or hypertensive emergency.',
            clinicalTip:
                'If several astronauts have headaches at the same time, prioritize PROC-HYPERCAPNIA-CO2.',
            durationSeconds: 60,
          ),
          ProcedureStep(
            step: 2,
            title: 'Perform a basic visual assessment',
            action:
                'Perform a quick near-reading test and Amsler grid check for blurring or distortion associated with SANS neuro-ocular syndrome.',
            clinicalTip: 'Document whether vision worsens on waking.',
            durationSeconds: 90,
          ),
          ProcedureStep(
            step: 3,
            title: 'Manage symptoms and maintain hydration',
            action:
                'Give ibuprofen 400 mg or paracetamol 500 mg orally with water, reduce bright screen exposure, and rest in a ventilated area.',
            clinicalTip:
                'Avoid excess dietary sodium for the next 24 hours to reduce headward fluid retention.',
            durationSeconds: 60,
          ),
        ],
        requiredSupplies: [
          ProcedureSupply(
            itemId: 'MED-IBUPROFEN',
            name: 'Ibuprofen 400 mg (Tablets)',
            usage:
                '1 tablet every 8 hours with food or water for mild-to-moderate headache',
            location: 'Main Medical Kit / Green Drawer 1',
          ),
          ProcedureSupply(
            itemId: 'MED-ACETAMINOPHEN',
            name: 'Paracetamol 500 mg (Tablets)',
            usage: 'Alternative analgesic (1 tablet every 6-8 h)',
            location: 'Main Medical Kit / Green Drawer 1',
          ),
        ],
        warnings: [
          'If double vision, one-sided weakness, or confusion develops, activate an immediate red-priority assessment.',
          'Do not combine multiple doses of analgesics from the same drug class.',
        ],
        criterionReference:
            'NASA HRP Spaceflight-Associated Neuro-ocular Syndrome (SANS) Surveillance',
      ),
      MedicalProcedure(
        id: 'PROC-RENAL-DEHYDRATION',
        code: 'IMG-REN-08',
        title: 'Severe Dehydration and Renal Colic (Nephrolithiasis)',
        category: 'renal_metabolic',
        priority: TriagePriority.yellow,
        nasaHazard: 'Gravity fields / Space nutrition',
        summary:
            'Management of dehydration, low-grade fever, or acute lower back pain associated with increased kidney stone risk from bone calcium loss in microgravity.',
        whenToActivate: [
          'Temperature > 37.3 °C (low-grade fever or fever), dry mouth, or mild tachycardia',
          'Severe flank or lower back pain radiating to the abdomen/groin',
          'Concentrated urine, painful urination, or reduced water intake',
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
            title: 'Assess temperature, hydration, and blood glucose',
            action:
                'Measure body temperature, heart rate, blood pressure, and glucose with i-STAT to rule out systemic infection or hypovolemia.',
            clinicalTip:
                'Fever > 38.0 °C with lower back pain requires close follow-up for possible complicated urinary tract infection.',
            durationSeconds: 90,
          ),
          ProcedureStep(
            step: 2,
            title: 'Start divided oral rehydration',
            action:
                'Give oral rehydration solution in frequent sips (250-500 mL every hour to reach at least 2.5 L/day) through a pouch with a mouthpiece.',
            clinicalTip:
                'If nausea prevents drinking, give ondansetron 4 mg first.',
            durationSeconds: 120,
          ),
          ProcedureStep(
            step: 3,
            title: 'Control pain and fever',
            action:
                'For colicky pain or fever, give ibuprofen 400 mg or paracetamol 500 mg according to gastric tolerance and hydration.',
            clinicalTip:
                'Avoid high NSAID doses in severe dehydration; prioritize hydration first.',
            durationSeconds: 60,
          ),
        ],
        requiredSupplies: [
          ProcedureSupply(
            itemId: 'MED-ORAL-REHYDRATION',
            name: 'Oral Rehydration Solution with Electrolytes',
            usage: 'Divided fluid replacement to maintain adequate urine output',
            location: 'Medical Bay / Green Drawer 2',
          ),
          ProcedureSupply(
            itemId: 'MED-ACETAMINOPHEN',
            name: 'Paracetamol 500 mg',
            usage: 'Temperature control and analgesia for patients at renal risk',
            location: 'Main Medical Kit / Green Drawer 1',
          ),
          ProcedureSupply(
            itemId: 'MED-ONDANSETRON',
            name: 'Ondansetron 4 mg',
            usage: 'Control nausea associated with renal colic',
            location: 'Main Medical Kit / Yellow Drawer 1',
          ),
        ],
        warnings: [
          'Do not stop hydration unless explicitly directed by medical personnel.',
          'Watch for temperature above 38.0 °C or inability to urinate.',
        ],
        criterionReference:
            'NASA HRP Renal Stone Risk & Hydration Countermeasures',
      ),
      MedicalProcedure(
        id: 'PROC-VESTIBULAR-SAS',
        code: 'IMG-VES-09',
        title: 'Space Adaptation Syndrome (Motion Sickness and Vertigo)',
        category: 'vestibular',
        priority: TriagePriority.yellow,
        nasaHazard: 'Gravity fields',
        summary:
            'Care for space motion sickness, vestibular disorientation, and nausea during the first days in microgravity or after gravity transitions.',
        whenToActivate: [
          'Severe dizziness with head turns, vertigo, or a sensation of spatial inversion',
          'Nausea, cold sweats, or loss of hand-eye coordination',
          'Difficulty maintaining operational stability after a gravity transition',
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
            title: 'Stabilize visual reference and reduce head turns',
            action:
                'Secure the crew member at a fixed point with a clear vertical orientation relative to module panels and avoid sudden head movements.',
            clinicalTip:
                'Fixating on a nearby stationary object quickly reduces vestibular conflict.',
            durationSeconds: 60,
          ),
          ProcedureStep(
            step: 2,
            title: 'Select antiemetic medication according to activity',
            action:
                'For mild nausea during an operational shift, give ondansetron 4 mg (non-sedating). Reserve promethazine for astronauts able to rest away from critical tasks.',
            clinicalTip:
                'Keep sealable emesis containment bags within immediate reach.',
            durationSeconds: 45,
          ),
          ProcedureStep(
            step: 3,
            title: 'Rehydrate and return gradually',
            action:
                'Replace fluids slowly and temporarily suspend precision tasks or critical console operation until stability returns.',
            clinicalTip:
                'Most SAS symptoms subside within 24-72 hours of adaptation.',
            durationSeconds: 120,
          ),
        ],
        requiredSupplies: [
          ProcedureSupply(
            itemId: 'MED-ONDANSETRON',
            name: 'Ondansetron 4 mg (Non-sedating)',
            usage: 'First-line treatment for nausea during cabin operations',
            location: 'Main Medical Kit / Yellow Drawer 1',
          ),
          ProcedureSupply(
            itemId: 'MED-PROMETHAZINE',
            name: 'Promethazine 25 mg',
            usage: 'Severe space motion sickness followed by rest',
            location: 'Main Medical Kit / Yellow Drawer 1',
          ),
        ],
        warnings: [
          'Do not operate critical controls or the robotic arm, or perform EVA, after promethazine because of drowsiness risk.',
          'Rule out hypoxia or high CO2 before assuming dizziness is vestibular.',
        ],
        criterionReference:
            'NASA HRP Sensorimotor & Space Adaptation Syndrome Protocol',
      ),
      MedicalProcedure(
        id: 'PROC-CIRCADIAN-FATIGUE',
        code: 'IMG-BHP-10',
        title: 'Critical Sleep Deficit, Cognitive Fatigue and Stress',
        category: 'behavioral_circadian',
        priority: TriagePriority.green,
        nasaHazard: 'Isolation and confinement',
        summary:
            'Preventive intervention for accumulated sleep deprivation (< 6.5 h/day), repeated nighttime awakenings, or emotional fatigue from prolonged confinement.',
        whenToActivate: [
          'Actiwatch sleep duration < 6.5 h or repeated awakenings (>= 3)',
          'Morning mood reported as fatigued or stressed',
          'Reduced cognitive performance, irritability, or minor operational errors',
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
            title: 'Restructure the sleep window and cabin lighting',
            action:
                'Schedule a protected rest block of at least 7.5-8 hours, dimming blue light in the sleeping compartment 60 minutes before bed.',
            clinicalTip:
                'Orbit brings 16 sunrises every 24 hours; blue/warm LED lighting control is key to circadian synchronization.',
            durationSeconds: 60,
          ),
          ProcedureStep(
            step: 2,
            title: 'Use breathing techniques and reduce noise',
            action:
                'Practice 5 minutes of guided slow breathing (inhale for 4 seconds, exhale for 6 seconds) and use hearing protection or an eye mask to limit fan-noise and light disturbance.',
            clinicalTip:
                'Check that airflow in the sleeping bag is active to prevent overnight CO2 buildup.',
            durationSeconds: 300,
          ),
          ProcedureStep(
            step: 3,
            title: 'Provide melatonin support if insomnia persists',
            action:
                'If prolonged sleep latency persists after 2 nights, give melatonin 3 mg 30-60 minutes before the scheduled rest cycle.',
            clinicalTip:
                'Reassign high-precision tasks if total sleep was less than 5 hours.',
            durationSeconds: 30,
          ),
        ],
        requiredSupplies: [
          ProcedureSupply(
            itemId: 'MED-MELATONIN',
            name: 'Melatonin 3 mg (Tablets)',
            usage:
                '1 tablet 30-60 min before bed for circadian resynchronization',
            location: 'Main Medical Kit / Green Drawer 3',
          ),
        ],
        warnings: [
          'Avoid caffeine for at least 6 hours before the sleep block.',
          'Do not turn off sleeping compartment fans to reduce noise; use earplugs instead.',
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
        label: 'Cardiac Arrest (CPR)',
        symptomSummary:
            'Crew member unconscious, not breathing, or without a detectable pulse',
        priority: TriagePriority.red,
        recommendedProcedureId: 'PROC-CARDIAC-ARREST',
        first60Seconds: [
          'Confirm unconsciousness and absent breathing within 10 seconds.',
          'Secure the patient to the CMRS board or use a reverse bear hug restraint.',
          'Start chest compressions (100-120/min) using the Handstand or Evetts-Russomano method and bring the AED.',
        ],
        verificationQuestions: [
          'Does the patient respond to a voice or firm shoulder stimulus?',
          'Is breathing normal or only agonal gasping?',
          'Does the Astroskin/EPM sensor show sudden pulse loss or a chaotic rhythm?',
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
        label: 'Hypoxia / Breathlessness',
        symptomSummary:
            'Severe breathlessness, SpO2 < 90%, or symptoms after an EVA',
        priority: TriagePriority.red,
        recommendedProcedureId: 'PROC-HYPOXIA-DECOMP',
        first60Seconds: [
          'Apply a mask with 100% O2 (10-15 L/min).',
          'Check cabin pressure and hatch/EVA suit seals.',
          'Keep the patient resting and monitor SpO2 every 2 minutes.',
        ],
        verificationQuestions: [
          'Is SpO2 below 90%?',
          'Has the patient just returned from a spacewalk (EVA)?',
          'Is there joint pain, dizziness, or bluish lip discoloration?',
        ],
        emergencySupplies: ['BVM-O2-100', 'MED-ORAL-REHYDRATION'],
      ),
      ClinicalScenario(
        id: 'SIT-RADIATION',
        label: 'Radiation / Solar Storm',
        symptomSummary:
            'HERA dosimeter alarm or nausea after a solar alert (SPE)',
        priority: TriagePriority.red,
        recommendedProcedureId: 'PROC-RADIATION-ARS',
        first60Seconds: [
          'Evacuate immediately to the shielded Storm Shelter.',
          'Check the personal HERA dosimeter reading.',
          'Give ondansetron 4 mg for nausea or vomiting.',
        ],
        verificationQuestions: [
          'Does the dose rate exceed 150 uSv/h?',
          'Has nausea, vomiting, or sudden fatigue developed?',
          'Was the patient in an unshielded module or on EVA during the event?',
        ],
        emergencySupplies: ['MED-ONDANSETRON', 'MED-ORAL-REHYDRATION'],
      ),
      ClinicalScenario(
        id: 'SIT-HEMODYNAMIC',
        label: 'Blood Pressure Crisis / Arrhythmia',
        symptomSummary:
            'Very low or high blood pressure, severe tachycardia (>115 bpm), or presyncope',
        priority: TriagePriority.red,
        recommendedProcedureId: 'PROC-HEMODYNAMIC-SYNCOPE',
        first60Seconds: [
          'Stop activity and secure the astronaut in a resting position.',
          'Connect Astroskin and EPM for continuous pulse and pressure monitoring.',
          'Check SpO2 and capillary glucose to rule out hypoxia or hypoglycemia.',
        ],
        verificationQuestions: [
          'Is systolic pressure < 85 mmHg or > 160 mmHg?',
          'Is there chest pain, palpitations, or tunnel vision?',
          'Is the patient normally alert with a palpable pulse?',
        ],
        emergencySupplies: ['MED-ORAL-REHYDRATION', 'AED-SPACE'],
      ),
      ClinicalScenario(
        id: 'SIT-CO2',
        label: 'High CO2 / Stale Air',
        symptomSummary:
            'Rapid breathing (>22 breaths/min), confusion, or headache in the cabin',
        priority: TriagePriority.red,
        recommendedProcedureId: 'PROC-HYPERCAPNIA-CO2',
        first60Seconds: [
          'Move the crew member to an adjacent module with nominal ventilation.',
          'Activate air-mixing fans to disperse CO2 pockets.',
          'Provide oxygen if SpO2 falls below 94%.',
        ],
        verificationQuestions: [
          'Is the ECLSS pCO2 alarm active?',
          'Do other crew members in the same module have headache or fatigue?',
        ],
        emergencySupplies: ['BVM-O2-100', 'MED-ACETAMINOPHEN'],
      ),
      ClinicalScenario(
        id: 'SIT-TRAUMA',
        label: 'Wound / Burn',
        symptomSummary:
            'Active bleeding, blunt impact, or a skin/limb burn',
        priority: TriagePriority.red,
        recommendedProcedureId: 'PROC-TRAUMA-HEMORRHAGE',
        first60Seconds: [
          'Put on gloves and apply firm pressure with sealed hemostatic gauze.',
          'Contain any blood droplets in microgravity.',
          'For burns, cool with a moist sterile compress and cover with sterile gel.',
        ],
        verificationQuestions: [
          'Is bleeding pulsatile or continuing after 5 minutes of pressure?',
          'Does the injury involve the face, eyes, or airway?',
        ],
        emergencySupplies: [
          'SUP-HEMOSTATIC-GAUZE',
          'SUP-TOURNIQUET',
          'SUP-BURN-GEL',
        ],
      ),
      ClinicalScenario(
        id: 'SIT-SANS',
        label: 'Headache / Vision',
        symptomSummary:
            'Frontal headache, facial congestion, or blurred vision (SANS)',
        priority: TriagePriority.yellow,
        recommendedProcedureId: 'PROC-SANS-CEPHALEA',
        first60Seconds: [
          'First rule out elevated CO2 and measure blood pressure.',
          'Perform a quick reading/visual grid test.',
          'Give a standard oral analgesic and reduce screen brightness.',
        ],
        verificationQuestions: [
          'Is blurred vision progressive or recent?',
          'Is there fever or neck stiffness?',
        ],
        emergencySupplies: ['MED-IBUPROFEN', 'MED-ACETAMINOPHEN'],
      ),
      ClinicalScenario(
        id: 'SIT-DEHYDRATION',
        label: 'Fever / Dehydration',
        symptomSummary:
            'Elevated temperature (>37.3 °C), lower back/renal pain, or low hydration',
        priority: TriagePriority.yellow,
        recommendedProcedureId: 'PROC-RENAL-DEHYDRATION',
        first60Seconds: [
          'Measure temperature, heart rate, and capillary glucose.',
          'Start oral rehydration with frequent sips of electrolyte solution.',
          'Control pain or fever with paracetamol 500 mg.',
        ],
        verificationQuestions: [
          'Is there flank/lower back pain or burning on urination?',
          'Can the patient tolerate oral fluids without vomiting?',
        ],
        emergencySupplies: [
          'MED-ORAL-REHYDRATION',
          'MED-ACETAMINOPHEN',
          'MED-ONDANSETRON',
        ],
      ),
      ClinicalScenario(
        id: 'SIT-VESTIBULAR',
        label: 'Space Motion Sickness / Vertigo',
        symptomSummary:
            'Spatial disorientation, vertigo, or nausea from microgravity (SAS)',
        priority: TriagePriority.yellow,
        recommendedProcedureId: 'PROC-VESTIBULAR-SAS',
        first60Seconds: [
          'Secure the crew member facing a fixed vertical reference and avoid head turns.',
          'Keep a sealed containment bag ready.',
          'Give ondansetron 4 mg if operational alertness must be maintained.',
        ],
        verificationQuestions: [
          'Does dizziness occur with head movement during the first days in orbit?',
          'Are vital signs (SpO2 and blood pressure) normal?',
        ],
        emergencySupplies: ['MED-ONDANSETRON', 'MED-PROMETHAZINE'],
      ),
      ClinicalScenario(
        id: 'SIT-FATIGUE',
        label: 'Fatigue / Insomnia',
        symptomSummary:
            'Less than 6.5 hours of sleep, frequent awakenings, or exhaustion',
        priority: TriagePriority.green,
        recommendedProcedureId: 'PROC-CIRCADIAN-FATIGUE',
        first60Seconds: [
          'Schedule a protected rest block (7.5-8 h) with dimmed blue light.',
          'Practice guided 4-6 breathing and check airflow in the sleeping bag.',
          'Consider melatonin 3 mg if difficulty falling asleep persists.',
        ],
        verificationQuestions: [
          'Have there been more than 2 cycles with less than 6 hours of sleep?',
          'Is the crew member assigned to critical high-precision tasks?',
        ],
        emergencySupplies: ['MED-MELATONIN'],
      ),
    ];
  }
}
