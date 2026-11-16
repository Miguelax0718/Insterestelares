import 'package:flutter/foundation.dart';

abstract final class ApoloCockpitIds {
  static const String missionSimulator = 'mission_simulator';
  static const String manualVitals = 'manual_vitals';
  static const String medicalProcedures = 'medical_procedures';
  static const Set<String> all = {missionSimulator, manualVitals, medicalProcedures};
}

/// Additional Space Cockpit component IDs introduced alongside the 22 core
/// [ComponentIds.all] identifiers without altering [ComponentIds.all.length].
abstract final class MicrogravityCockpitIds {
  static const String zeroGHorizon = 'zero_g_horizon';
  static const String dvaGaze = 'dva_gaze';

  static const Set<String> all = {zeroGHorizon, dvaGaze};
}

@immutable
class GuidedAssessmentDescriptor {
  const GuidedAssessmentDescriptor({
    required this.id,
    required this.title,
    required this.category,
    required this.skillId,
    required this.componentId,
    required this.estimatedMinutes,
    required this.summary,
    this.defaultProps = const {},
  });

  final String id;
  final String title;
  final String category; // 'microgravity' | 'ocular' | 'cognitive' | 'urine' | 'readiness'
  final String skillId;
  final String componentId;
  final int estimatedMinutes;
  final String summary;
  final Map<String, dynamic> defaultProps;

  Map<String, dynamic> toCompactJson() => <String, dynamic>{
    'id': id,
    'title': title,
    'category': category,
    'skill': skillId,
    'component': componentId,
    'min': estimatedMinutes,
  };
}

/// Authoritative catalog of guided clinical assessments, tests, and
/// countermeasures exposed to both the LLM context and the APOLO UI launcher.
abstract final class GuidedAssessmentCatalog {
  static const List<GuidedAssessmentDescriptor> all = [
    GuidedAssessmentDescriptor(
      id: 'zero_g_horizon',
      title: 'Zero-G Horizon (Sensorimotor)',
      category: 'microgravity',
      skillId: 'graybiel',
      componentId: MicrogravityCockpitIds.zeroGHorizon,
      estimatedMinutes: 1,
      summary: '3-axis docking alignment under rotating starfield conflict.',
    ),
    GuidedAssessmentDescriptor(
      id: 'dva_gaze',
      title: '1 Hz Gaze Stability / DVA',
      category: 'microgravity',
      skillId: 'graybiel',
      componentId: MicrogravityCockpitIds.dvaGaze,
      estimatedMinutes: 1,
      summary: '1 Hz head-yaw fixation and dynamic visual acuity optotype check.',
    ),
    GuidedAssessmentDescriptor(
      id: 'graybiel',
      title: 'Graybiel Motion Sickness Scale',
      category: 'microgravity',
      skillId: 'graybiel',
      componentId: 'graybiel_questionnaire',
      estimatedMinutes: 2,
      summary: 'Vestibular symptom scoring + facial pallor & EVA GO/NO-GO.',
    ),
    GuidedAssessmentDescriptor(
      id: 'starfield_distortion',
      title: 'Starfield Distortion Hunter (SANS)',
      category: 'ocular',
      skillId: 'sans',
      componentId: 'sans_grid',
      estimatedMinutes: 2,
      summary: 'Interactive Amsler metamorphopsia + peripheral scotoma mapper.',
    ),
    GuidedAssessmentDescriptor(
      id: 'near_point_diopter',
      title: 'Near-Point Diopter Meter (SANS)',
      category: 'ocular',
      skillId: 'sans',
      componentId: 'sans_focus',
      estimatedMinutes: 1,
      summary: 'Near-point focus distance -> hyperopic shift & glasses tier.',
    ),
    GuidedAssessmentDescriptor(
      id: 'sans_contrast',
      title: 'SANS Contrast Sensitivity',
      category: 'ocular',
      skillId: 'sans',
      componentId: 'sans_contrast',
      estimatedMinutes: 1,
      summary: 'Low-contrast optotype threshold (logCS) ocular check.',
    ),
    GuidedAssessmentDescriptor(
      id: 'lbnp',
      title: 'LBNP -20 mmHg Countermeasure',
      category: 'ocular',
      skillId: 'procedures',
      componentId: 'lbnp_ramp',
      estimatedMinutes: 3,
      summary: 'Fluid-shift ramp (-10 -> -20 mmHg) with mandatory decompression.',
    ),
    GuidedAssessmentDescriptor(
      id: 'exercise',
      title: 'Exercise Countermeasure Check',
      category: 'microgravity',
      skillId: 'exercise',
      componentId: 'exercise_monitor',
      estimatedMinutes: 2,
      summary: 'ARED / T2 / CEVIS vitals-guarded workout evaluation.',
    ),
    GuidedAssessmentDescriptor(
      id: 'pvt',
      title: 'PVT Reaction Time Test',
      category: 'cognitive',
      skillId: 'mental_health',
      componentId: 'pvt_test',
      estimatedMinutes: 1,
      summary: 'Psychomotor vigilance reaction latency & lapse check.',
    ),
    GuidedAssessmentDescriptor(
      id: 'diary',
      title: 'Daily Sleep & Mood Diary',
      category: 'cognitive',
      skillId: 'mental_health',
      componentId: 'diary_recorder',
      estimatedMinutes: 1,
      summary: 'Circadian sleep quality, workload, and isolation check-in.',
    ),
    GuidedAssessmentDescriptor(
      id: 'readiness',
      title: 'Pre-EVA / Landing Readiness',
      category: 'readiness',
      skillId: 'readiness',
      componentId: 'eva_readiness',
      estimatedMinutes: 2,
      summary: 'Deterministic clinical GO / NO-GO gate for EVA or landing.',
    ),
    GuidedAssessmentDescriptor(
      id: ApoloCockpitIds.manualVitals,
      title: 'Manual Vitals (Tap-to-Count)',
      category: 'readiness',
      skillId: 'clinical_navigation_and_procedures',
      componentId: ApoloCockpitIds.manualVitals,
      estimatedMinutes: 2,
      summary: 'Offline pulse, respiration, capillary refill and temperature entry.',
    ),
    GuidedAssessmentDescriptor(
      id: ApoloCockpitIds.medicalProcedures,
      title: 'Medical Procedures',
      category: 'readiness',
      skillId: 'clinical_navigation_and_procedures',
      componentId: ApoloCockpitIds.medicalProcedures,
      estimatedMinutes: 2,
      summary: 'Offline situation triage, ten protocols and first-aid supplies.',
    ),
  ];

  static GuidedAssessmentDescriptor? byId(String id) {
    final clean = id.trim().toLowerCase();
    for (final item in all) {
      if (item.id == clean || item.componentId == clean) {
        return item;
      }
    }
    return null;
  }
}
