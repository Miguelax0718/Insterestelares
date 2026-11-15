import 'package:astramed/features/agent/domain/agent_contracts.dart';

enum LbnpPhase {
  prepSealCheck('prep_sealCheck', 0, 0),
  stepMinus10_3min('step_minus10_3min', -10, 3),
  targetMinus20_15min('target_minus20_15min', -20, 15),
  gradualDecompressionMinus10_3min(
    'gradual_decompression_minus10_3min',
    -10,
    3,
  ),
  gradualDecompression0_2min('gradual_decompression_0_2min', 0, 2),
  completed('completed', 0, 0),
  aborted('aborted', 0, 0);

  const LbnpPhase(this.wireName, this.pressureMmHg, this.durationMinutes);

  final String wireName;
  final int pressureMmHg;
  final int durationMinutes;

  static LbnpPhase? tryParse(String raw) {
    final normalized = raw.trim();
    for (final phase in LbnpPhase.values) {
      if (phase.wireName == normalized) {
        return phase;
      }
    }
    return null;
  }
}

class LbnpState {
  const LbnpState({
    required this.phase,
    required this.pressureMmHg,
    required this.instruction,
    this.abortPending = false,
    this.emergencyRelease = false,
    this.supineFluidLoadAlert = false,
    this.alerts = const [],
    this.lastSystolicBP,
    this.lastHrDropBpm,
  });

  final LbnpPhase phase;
  final int pressureMmHg;
  final String instruction;
  final bool abortPending;
  final bool emergencyRelease;
  final bool supineFluidLoadAlert;
  final List<String> alerts;
  final double? lastSystolicBP;
  final double? lastHrDropBpm;

  Map<String, dynamic> toJson() => {
    'phase': phase.wireName,
    'pressure_mmhg': pressureMmHg,
    'phase_duration_minutes': phase.durationMinutes,
    'instruction': instruction,
    'abort_pending': abortPending,
    'emergency_release': emergencyRelease,
    'supine_fluid_load_alert': supineFluidLoadAlert,
    'alerts': alerts,
    if (lastSystolicBP != null) 'last_systolic_bp': lastSystolicBP,
    if (lastHrDropBpm != null) 'last_hr_drop_bpm': lastHrDropBpm,
  };
}

class LbnpTransitionResult {
  const LbnpTransitionResult({
    required this.ok,
    required this.state,
    this.error,
  });

  final bool ok;
  final LbnpState state;
  final String? error;
}

class LbnpEngine {
  LbnpEngine._();

  static const double emergencySystolicThresholdMmHg = 85.0;
  static const double emergencyHrDropThresholdBpm = 20.0;

  static LbnpState start() {
    return const LbnpState(
      phase: LbnpPhase.prepSealCheck,
      pressureMmHg: 0,
      instruction:
          'Confirm LBNP waist seal integrity, leg alignment, and baseline cuff vitals before applying -10 mmHg.',
    );
  }

  static bool _isEmergency({
    double? systolicBP,
    double? hrDropBpm,
    bool emergencySyncope = false,
  }) {
    return emergencySyncope ||
        (systolicBP != null && systolicBP < emergencySystolicThresholdMmHg) ||
        (hrDropBpm != null && hrDropBpm > emergencyHrDropThresholdBpm);
  }

  static LbnpState _emergencyAbortState({
    double? systolicBP,
    double? hrDropBpm,
    String? reason,
  }) {
    final reasons = <String>[
      if (systolicBP != null && systolicBP < emergencySystolicThresholdMmHg)
        'Hypotension SBP ${systolicBP.toStringAsFixed(0)} mmHg (< 85 mmHg)',
      if (hrDropBpm != null && hrDropBpm > emergencyHrDropThresholdBpm)
        'Bradycardic drop ${hrDropBpm.toStringAsFixed(0)} bpm (> 20 bpm)',
      if (reason != null && reason.isNotEmpty) reason,
    ];
    return LbnpState(
      phase: LbnpPhase.aborted,
      pressureMmHg: 0,
      emergencyRelease: true,
      supineFluidLoadAlert: true,
      lastSystolicBP: systolicBP,
      lastHrDropBpm: hrDropBpm,
      alerts: [
        'EMERGENCY LBNP RELEASE TO 0 mmHg',
        'SUPINE FLUID LOAD ALERT: Place crew member supine/Trendelenburg and administer oral/IV fluids.',
        ...reasons,
      ],
      instruction:
          'Emergency release complete (0 mmHg). Keep crew member supine, administer fluid load, and recheck BP/HR every 2 minutes.',
    );
  }

  static LbnpTransitionResult advance(
    LbnpState current, {
    bool sealChecked = true,
    double? systolicBP,
    double? hrDropBpm,
    bool emergencySyncope = false,
    int? requestedTargetPressureMmHg,
    LbnpPhase? requestedPhase,
  }) {
    if (current.phase == LbnpPhase.completed ||
        current.phase == LbnpPhase.aborted) {
      return LbnpTransitionResult(
        ok: false,
        state: current,
        error: 'LBNP protocol already ended in ${current.phase.wireName}.',
      );
    }

    if (_isEmergency(
      systolicBP: systolicBP,
      hrDropBpm: hrDropBpm,
      emergencySyncope: emergencySyncope,
    )) {
      return LbnpTransitionResult(
        ok: true,
        state: _emergencyAbortState(
          systolicBP: systolicBP,
          hrDropBpm: hrDropBpm,
        ),
      );
    }

    // Safety invariant: never jump directly from -20 mmHg to 0 mmHg without emergency syncope/hypotension.
    if (current.pressureMmHg == -20 &&
        (requestedTargetPressureMmHg == 0 ||
            requestedPhase == LbnpPhase.gradualDecompression0_2min ||
            requestedPhase == LbnpPhase.completed ||
            requestedPhase == LbnpPhase.aborted)) {
      return LbnpTransitionResult(
        ok: false,
        state: current,
        error:
            'Safety lock: cannot jump directly from -20 mmHg to 0 mmHg without emergency syncope/hypotension; step through -10 mmHg first.',
      );
    }

    if (current.phase == LbnpPhase.prepSealCheck && !sealChecked) {
      return LbnpTransitionResult(
        ok: false,
        state: current,
        error: 'Waist seal check must be confirmed before stepping to -10 mmHg.',
      );
    }

    if (current.phase == LbnpPhase.gradualDecompressionMinus10_3min &&
        current.abortPending) {
      return LbnpTransitionResult(
        ok: true,
        state: LbnpState(
          phase: LbnpPhase.aborted,
          pressureMmHg: 0,
          lastSystolicBP: systolicBP,
          lastHrDropBpm: hrDropBpm,
          alerts: current.alerts,
          instruction:
              'Controlled LBNP abort complete at 0 mmHg after gradual -10 mmHg decompression.',
        ),
      );
    }

    final LbnpPhase nextPhase;
    final String instruction;
    switch (current.phase) {
      case LbnpPhase.prepSealCheck:
        nextPhase = LbnpPhase.stepMinus10_3min;
        instruction =
            'Applying -10 mmHg for 3 minutes. Verify seal and monitor comfort/BP.';
      case LbnpPhase.stepMinus10_3min:
        nextPhase = LbnpPhase.targetMinus20_15min;
        instruction =
            'Applying target -20 mmHg for 15 minutes. Monitor SBP and HR continuously.';
      case LbnpPhase.targetMinus20_15min:
        nextPhase = LbnpPhase.gradualDecompressionMinus10_3min;
        instruction =
            'Gradual decompression step 1: hold -10 mmHg for 3 minutes before releasing to 0 mmHg.';
      case LbnpPhase.gradualDecompressionMinus10_3min:
        nextPhase = LbnpPhase.gradualDecompression0_2min;
        instruction =
            'Gradual decompression step 2: release to 0 mmHg and monitor 2 minutes before exit.';
      case LbnpPhase.gradualDecompression0_2min:
        nextPhase = LbnpPhase.completed;
        instruction =
            'LBNP -20 mmHg protocol completed safely. Document post-run vitals.';
      case LbnpPhase.completed:
      case LbnpPhase.aborted:
        return LbnpTransitionResult(ok: false, state: current);
    }

    return LbnpTransitionResult(
      ok: true,
      state: LbnpState(
        phase: nextPhase,
        pressureMmHg: nextPhase.pressureMmHg,
        instruction: instruction,
        lastSystolicBP: systolicBP,
        lastHrDropBpm: hrDropBpm,
      ),
    );
  }

  static LbnpTransitionResult abort(
    LbnpState current, {
    double? systolicBP,
    double? hrDropBpm,
    bool emergencySyncope = false,
    String? reason,
  }) {
    if (_isEmergency(
      systolicBP: systolicBP,
      hrDropBpm: hrDropBpm,
      emergencySyncope: emergencySyncope,
    )) {
      return LbnpTransitionResult(
        ok: true,
        state: _emergencyAbortState(
          systolicBP: systolicBP,
          hrDropBpm: hrDropBpm,
          reason: reason,
        ),
      );
    }

    if (current.pressureMmHg <= -20) {
      return LbnpTransitionResult(
        ok: true,
        state: LbnpState(
          phase: LbnpPhase.gradualDecompressionMinus10_3min,
          pressureMmHg: -10,
          abortPending: true,
          lastSystolicBP: systolicBP,
          lastHrDropBpm: hrDropBpm,
          alerts: [
            'Controlled abort initiated: stepping from -20 mmHg to -10 mmHg for 3 min before 0 mmHg.',
            if (reason != null && reason.isNotEmpty) reason,
          ],
          instruction:
              'Hold -10 mmHg for 3 minutes during gradual decompression, then advance to complete release to 0 mmHg.',
        ),
      );
    }

    return LbnpTransitionResult(
      ok: true,
      state: LbnpState(
        phase: LbnpPhase.aborted,
        pressureMmHg: 0,
        lastSystolicBP: systolicBP,
        lastHrDropBpm: hrDropBpm,
        alerts: [
          'LBNP protocol aborted safely at 0 mmHg.',
          if (reason != null && reason.isNotEmpty) reason,
        ],
        instruction: 'LBNP chamber depressurized to 0 mmHg.',
      ),
    );
  }
}

class LbnpRampViewModel extends AgentViewModel {
  const LbnpRampViewModel({
    required this.astronautId,
    required this.state,
  }) : super(
         componentId: ComponentIds.lbnpRamp,
         title: 'LBNP -20 mmHg Autonomous Protocol',
       );

  factory LbnpRampViewModel.fromProps(Map<String, dynamic> props) {
    final phase =
        LbnpPhase.tryParse(props['phase'] as String? ?? 'prep_sealCheck') ??
        LbnpPhase.prepSealCheck;
    return LbnpRampViewModel(
      astronautId: props['astronaut_id'] as String? ?? 'AST-01',
      state: LbnpState(
        phase: phase,
        pressureMmHg:
            (props['pressure_mmhg'] as num?)?.toInt() ?? phase.pressureMmHg,
        instruction: props['instruction'] as String? ?? '',
        abortPending: props['abort_pending'] as bool? ?? false,
        emergencyRelease: props['emergency_release'] as bool? ?? false,
        supineFluidLoadAlert: props['supine_fluid_load_alert'] as bool? ?? false,
        alerts: (props['alerts'] as List<dynamic>? ?? const []).cast<String>(),
        lastSystolicBP: (props['last_systolic_bp'] as num?)?.toDouble(),
        lastHrDropBpm: (props['last_hr_drop_bpm'] as num?)?.toDouble(),
      ),
    );
  }

  final String astronautId;
  final LbnpState state;

  @override
  Map<String, dynamic> toProps() => {
    'component_id': componentId,
    'title': title,
    'astronaut_id': astronautId,
    ...state.toJson(),
  };
}

enum UltrasoundStep {
  prepGelAndProbe('prep_gel_and_probe'),
  rightKidneyWindow('right_kidney_window'),
  leftKidneyWindow('left_kidney_window'),
  hydronephrosisStoneCheck('hydronephrosis_stone_check'),
  bladderVolumeScan('bladder_volume_scan'),
  completed('completed');

  const UltrasoundStep(this.wireName);

  final String wireName;

  static UltrasoundStep? tryParse(String raw) {
    final normalized = raw.trim();
    for (final step in UltrasoundStep.values) {
      if (step.wireName == normalized) {
        return step;
      }
    }
    return null;
  }
}

class UltrasoundEvaluation {
  const UltrasoundEvaluation({
    required this.step,
    required this.acousticWindowOk,
    required this.hydronephrosisPresent,
    required this.stoneShadowPresent,
    required this.urinaryRetentionRisk,
    required this.findings,
    required this.instruction,
    this.residualBladderVolumeMl,
  });

  final UltrasoundStep step;
  final bool acousticWindowOk;
  final bool hydronephrosisPresent;
  final bool stoneShadowPresent;
  final double? residualBladderVolumeMl;
  final bool urinaryRetentionRisk;
  final List<String> findings;
  final String instruction;

  Map<String, dynamic> toJson() => {
    'step': step.wireName,
    'acoustic_window_ok': acousticWindowOk,
    'hydronephrosis_present': hydronephrosisPresent,
    'stone_shadow_present': stoneShadowPresent,
    if (residualBladderVolumeMl != null)
      'residual_bladder_volume_ml': residualBladderVolumeMl,
    'urinary_retention_risk': urinaryRetentionRisk,
    'findings': findings,
    'instruction': instruction,
  };
}

class UltrasoundEngine {
  UltrasoundEngine._();

  static const double ellipsoidFactor = 0.52;
  static const double elevatedResidualVolumeMl = 150.0;

  static double estimateBladderVolumeMl({
    required double widthCm,
    required double heightCm,
    required double lengthCm,
  }) {
    if (widthCm <= 0 || heightCm <= 0 || lengthCm <= 0) {
      throw ArgumentError(
        'Bladder dimensions (width, height, length) must be positive.',
      );
    }
    return double.parse(
      (ellipsoidFactor * widthCm * heightCm * lengthCm).toStringAsFixed(2),
    );
  }

  static UltrasoundEvaluation evaluateStep({
    required UltrasoundStep step,
    bool acousticWindowOk = true,
    bool hydronephrosisPresent = false,
    bool stoneShadowPresent = false,
    double? bladderWidthCm,
    double? bladderHeightCm,
    double? bladderLengthCm,
  }) {
    double? volumeMl;
    if (bladderWidthCm != null &&
        bladderHeightCm != null &&
        bladderLengthCm != null) {
      volumeMl = estimateBladderVolumeMl(
        widthCm: bladderWidthCm,
        heightCm: bladderHeightCm,
        lengthCm: bladderLengthCm,
      );
    }

    final retentionRisk =
        volumeMl != null && volumeMl > elevatedResidualVolumeMl;
    final findings = <String>[
      if (!acousticWindowOk)
        'Suboptimal acoustic window; reapply gel and adjust intercostal angle.',
      if (hydronephrosisPresent)
        'Collecting system dilatation (hydronephrosis) flagged.',
      if (stoneShadowPresent)
        'Echogenic focus with posterior acoustic shadowing (suspected nephrolithiasis).',
      if (retentionRisk)
        'Elevated post-void residual bladder volume (${volumeMl.toStringAsFixed(1)} mL > 150 mL).',
    ];

    final instruction = switch (step) {
      UltrasoundStep.prepGelAndProbe =>
        'Select 3.5-5.0 MHz curvilinear probe, apply acoustic gel, and position astronaut supine.',
      UltrasoundStep.rightKidneyWindow =>
        'Place probe at right subcostal / mid-axillary line using the liver as acoustic window; inspect renal pelvis.',
      UltrasoundStep.leftKidneyWindow =>
        'Place probe at left posterior axillary line using the spleen window; inspect cortex and calyces.',
      UltrasoundStep.hydronephrosisStoneCheck =>
        'Sweep kidney long and short axes to check for calyceal dilatation (hydronephrosis) or stone acoustic shadow.',
      UltrasoundStep.bladderVolumeScan =>
        'Scan suprapubic transverse and sagittal planes; record width, height, and length in cm for volume estimation.',
      UltrasoundStep.completed =>
        'Renal and bladder ultrasound scan complete; save cine loops for ground flight surgeon review.',
    };

    return UltrasoundEvaluation(
      step: step,
      acousticWindowOk: acousticWindowOk,
      hydronephrosisPresent: hydronephrosisPresent,
      stoneShadowPresent: stoneShadowPresent,
      residualBladderVolumeMl: volumeMl,
      urinaryRetentionRisk: retentionRisk,
      findings: List.unmodifiable(findings),
      instruction: instruction,
    );
  }
}

class UltrasoundGuideViewModel extends AgentViewModel {
  const UltrasoundGuideViewModel({
    required this.astronautId,
    required this.evaluation,
  }) : super(
         componentId: ComponentIds.ultrasoundGuide,
         title: 'Autonomous Renal & Bladder Ultrasound Guide',
       );

  factory UltrasoundGuideViewModel.fromProps(Map<String, dynamic> props) {
    final step =
        UltrasoundStep.tryParse(
          props['step'] as String? ?? 'prep_gel_and_probe',
        ) ??
        UltrasoundStep.prepGelAndProbe;
    return UltrasoundGuideViewModel(
      astronautId: props['astronaut_id'] as String? ?? 'AST-01',
      evaluation: UltrasoundEvaluation(
        step: step,
        acousticWindowOk: props['acoustic_window_ok'] as bool? ?? true,
        hydronephrosisPresent:
            props['hydronephrosis_present'] as bool? ?? false,
        stoneShadowPresent: props['stone_shadow_present'] as bool? ?? false,
        residualBladderVolumeMl:
            (props['residual_bladder_volume_ml'] as num?)?.toDouble(),
        urinaryRetentionRisk:
            props['urinary_retention_risk'] as bool? ?? false,
        findings: (props['findings'] as List<dynamic>? ?? const [])
            .cast<String>(),
        instruction: props['instruction'] as String? ?? '',
      ),
    );
  }

  final String astronautId;
  final UltrasoundEvaluation evaluation;

  @override
  Map<String, dynamic> toProps() => {
    'component_id': componentId,
    'title': title,
    'astronaut_id': astronautId,
    ...evaluation.toJson(),
  };
}
