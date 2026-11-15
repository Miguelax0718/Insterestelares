import 'package:astramed/features/agent/domain/agent_contracts.dart';

enum SansGrade {
  nominal('nominal'),
  borderline('borderline'),
  grade1('grade_1'),
  grade2('grade_2');

  const SansGrade(this.wireName);

  final String wireName;
}

class SansGogglePair {
  const SansGogglePair({
    required this.id,
    required this.label,
    required this.diopters,
  });

  static const SansGogglePair pairA = SansGogglePair(
    id: 'PAIR-A',
    label: 'PAIR-A +0.75D',
    diopters: 0.75,
  );
  static const SansGogglePair pairB = SansGogglePair(
    id: 'PAIR-B',
    label: 'PAIR-B +1.25D',
    diopters: 1.25,
  );
  static const SansGogglePair pairC = SansGogglePair(
    id: 'PAIR-C',
    label: 'PAIR-C +1.75D',
    diopters: 1.75,
  );

  static const List<SansGogglePair> all = [pairA, pairB, pairC];

  final String id;
  final String label;
  final double diopters;

  static SansGogglePair? parse(String raw) {
    final normalized = raw.trim().toUpperCase();
    for (final pair in all) {
      if (normalized == pair.id ||
          normalized == pair.label.toUpperCase() ||
          normalized.startsWith('${pair.id} ')) {
        return pair;
      }
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'label': label,
    'diopters': diopters,
  };
}

class SansEvaluation {
  const SansEvaluation({
    required this.nearFocusCm,
    required this.hyperopicShiftDiopters,
    required this.gridMetamorphopsia,
    required this.gridScotoma,
    required this.contrastLogCs,
    required this.contrastLoss,
    required this.grade,
    required this.recommendedGoggles,
    required this.summary,
  });

  final double nearFocusCm;
  final double hyperopicShiftDiopters;
  final bool gridMetamorphopsia;
  final bool gridScotoma;
  final double contrastLogCs;
  final bool contrastLoss;
  final SansGrade grade;
  final SansGogglePair? recommendedGoggles;
  final String summary;

  Map<String, dynamic> toJson() => {
    'near_focus_cm': nearFocusCm,
    'hyperopic_shift_diopters': hyperopicShiftDiopters,
    'grid_metamorphopsia': gridMetamorphopsia,
    'grid_scotoma': gridScotoma,
    'contrast_log_cs': contrastLogCs,
    'contrast_loss': contrastLoss,
    'grade': grade.wireName,
    if (recommendedGoggles != null)
      'recommended_goggles': recommendedGoggles!.label,
    if (recommendedGoggles != null)
      'recommended_goggles_diopters': recommendedGoggles!.diopters,
    'summary': summary,
  };
}

class SansEngine {
  SansEngine._();

  // D6 constants for Spaceflight Associated Neuro-ocular Syndrome (SANS).
  static const double baselineNearFocusCm = 25.0;
  static const double shiftTier1ThresholdCm = 35.0;
  static const double shiftTier2ThresholdCm = 45.0;
  static const double shiftTier3ThresholdCm = 55.0;
  static const double contrastLossThresholdLogCs = 1.50;
  static const double borderlineContrastThresholdLogCs = 1.65;

  static double estimateHyperopicShift(double nearFocusCm) {
    if (nearFocusCm <= 0) {
      throw ArgumentError.value(
        nearFocusCm,
        'nearFocusCm',
        'Near focus distance must be positive.',
      );
    }
    if (nearFocusCm > shiftTier3ThresholdCm) {
      return 1.75;
    }
    if (nearFocusCm > shiftTier2ThresholdCm) {
      return 1.25;
    }
    if (nearFocusCm > shiftTier1ThresholdCm) {
      return 0.75;
    }
    return 0.0;
  }

  static SansGogglePair? recommendGoggles(double hyperopicShiftDiopters) {
    if (hyperopicShiftDiopters >= 1.75) {
      return SansGogglePair.pairC;
    }
    if (hyperopicShiftDiopters >= 1.25) {
      return SansGogglePair.pairB;
    }
    if (hyperopicShiftDiopters >= 0.75) {
      return SansGogglePair.pairA;
    }
    return null;
  }

  static SansEvaluation evaluate({
    required double nearFocusCm,
    bool gridMetamorphopsia = false,
    bool gridScotoma = false,
    double contrastLogCs = 1.80,
    bool? contrastLoss,
  }) {
    final shiftD = estimateHyperopicShift(nearFocusCm);
    final hasContrastLoss =
        contrastLoss ?? (contrastLogCs < contrastLossThresholdLogCs);
    final borderlineContrast =
        !hasContrastLoss && contrastLogCs < borderlineContrastThresholdLogCs;
    final hasGridAbnormality = gridMetamorphopsia || gridScotoma;

    final SansGrade grade;
    if (hasGridAbnormality || (hasContrastLoss && shiftD > 0)) {
      grade = SansGrade.grade2;
    } else if (shiftD >= 1.25 || (hasContrastLoss && shiftD == 0)) {
      grade = SansGrade.grade1;
    } else if (shiftD >= 0.75 || borderlineContrast) {
      grade = SansGrade.borderline;
    } else {
      grade = SansGrade.nominal;
    }

    final goggles = recommendGoggles(shiftD);
    final summary = switch (grade) {
      SansGrade.nominal =>
        'Nominal ocular evaluation; near focus ${nearFocusCm.toStringAsFixed(0)} cm.',
      SansGrade.borderline =>
        'Mild hyperopic shift (+${shiftD.toStringAsFixed(2)}D). '
            '${goggles != null ? 'Consider ${goggles.label}.' : 'Monitor contrast.'}',
      SansGrade.grade1 =>
        'SANS Grade 1 with +${shiftD.toStringAsFixed(2)}D shift. '
            '${goggles != null ? 'Recommend ${goggles.label}.' : 'Schedule follow-up OCT.'}',
      SansGrade.grade2 =>
        'SANS Grade 2 (${hasGridAbnormality ? 'Amsler distortion/scotoma' : 'contrast loss + hyperopic shift'}). '
            '${goggles != null ? 'Assign ${goggles.label} and schedule flight surgeon fundoscopy.' : 'Schedule flight surgeon fundoscopy.'}',
    };

    return SansEvaluation(
      nearFocusCm: nearFocusCm,
      hyperopicShiftDiopters: shiftD,
      gridMetamorphopsia: gridMetamorphopsia,
      gridScotoma: gridScotoma,
      contrastLogCs: contrastLogCs,
      contrastLoss: hasContrastLoss,
      grade: grade,
      recommendedGoggles: goggles,
      summary: summary,
    );
  }
}

class SansGridViewModel extends AgentViewModel {
  const SansGridViewModel({
    required this.astronautId,
    required this.instruction,
    this.metamorphopsiaReported = false,
    this.scotomaReported = false,
    this.affectedQuadrant,
  }) : super(
         componentId: ComponentIds.sansGrid,
         title: 'SANS Amsler Grid Test',
       );

  factory SansGridViewModel.fromProps(Map<String, dynamic> props) {
    return SansGridViewModel(
      astronautId: props['astronaut_id'] as String? ?? 'AST-01',
      instruction:
          props['instruction'] as String? ??
          'Fixate on the central dot at 30 cm and mark wavy lines or blind spots.',
      metamorphopsiaReported:
          props['metamorphopsia_reported'] as bool? ?? false,
      scotomaReported: props['scotoma_reported'] as bool? ?? false,
      affectedQuadrant: props['affected_quadrant'] as String?,
    );
  }

  final String astronautId;
  final String instruction;
  final bool metamorphopsiaReported;
  final bool scotomaReported;
  final String? affectedQuadrant;

  @override
  Map<String, dynamic> toProps() => {
    'component_id': componentId,
    'title': title,
    'astronaut_id': astronautId,
    'instruction': instruction,
    'metamorphopsia_reported': metamorphopsiaReported,
    'scotoma_reported': scotomaReported,
    if (affectedQuadrant != null) 'affected_quadrant': affectedQuadrant,
  };
}

class SansContrastViewModel extends AgentViewModel {
  const SansContrastViewModel({
    required this.astronautId,
    required this.instruction,
    this.contrastLogCs,
    this.contrastLoss = false,
  }) : super(
         componentId: ComponentIds.sansContrast,
         title: 'SANS Contrast Sensitivity Test',
       );

  factory SansContrastViewModel.fromProps(Map<String, dynamic> props) {
    return SansContrastViewModel(
      astronautId: props['astronaut_id'] as String? ?? 'AST-01',
      instruction:
          props['instruction'] as String? ??
          'Read the lowest-contrast triplet visible on the chart.',
      contrastLogCs: (props['contrast_log_cs'] as num?)?.toDouble(),
      contrastLoss: props['contrast_loss'] as bool? ?? false,
    );
  }

  final String astronautId;
  final String instruction;
  final double? contrastLogCs;
  final bool contrastLoss;

  @override
  Map<String, dynamic> toProps() => {
    'component_id': componentId,
    'title': title,
    'astronaut_id': astronautId,
    'instruction': instruction,
    if (contrastLogCs != null) 'contrast_log_cs': contrastLogCs,
    'contrast_loss': contrastLoss,
  };
}

class SansFocusViewModel extends AgentViewModel {
  const SansFocusViewModel({
    required this.astronautId,
    required this.instruction,
    this.nearFocusCm,
    this.estimatedDiopters,
  }) : super(
         componentId: ComponentIds.sansFocus,
         title: 'SANS Near Focus Distance Test',
       );

  factory SansFocusViewModel.fromProps(Map<String, dynamic> props) {
    return SansFocusViewModel(
      astronautId: props['astronaut_id'] as String? ?? 'AST-01',
      instruction:
          props['instruction'] as String? ??
          'Bring the near target closer until sharp focus blurs and record distance in cm.',
      nearFocusCm: (props['near_focus_cm'] as num?)?.toDouble(),
      estimatedDiopters: (props['estimated_diopters'] as num?)?.toDouble(),
    );
  }

  final String astronautId;
  final String instruction;
  final double? nearFocusCm;
  final double? estimatedDiopters;

  @override
  Map<String, dynamic> toProps() => {
    'component_id': componentId,
    'title': title,
    'astronaut_id': astronautId,
    'instruction': instruction,
    if (nearFocusCm != null) 'near_focus_cm': nearFocusCm,
    if (estimatedDiopters != null) 'estimated_diopters': estimatedDiopters,
  };
}
