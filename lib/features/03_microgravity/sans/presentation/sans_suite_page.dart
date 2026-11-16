import 'dart:async';
import 'dart:math' as math;
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/calibration/domain/device_calibration.dart';
import '../../../../core/constants/medical_thresholds.dart';
import '../../../../core/sensing/data/simulated_sensing_adapters.dart';
import '../../../../core/sensing/domain/sensing_ports.dart';
import '../../../../core/storage/hive_bootstrap.dart';
import '../../../../core/theme/space_theme.dart';
import '../../../crew/presentation/providers/crew_provider.dart';
import '../data/sans_repository.dart';
import '../domain/sans_models_and_analyzers.dart';

/// Suite clínica interactiva para el Síndrome Neuro-Ocular Asociado a Vuelos Espaciales (SANS):
/// 1. Tele-Medidor de Punto Cercano (ΔD hipermetrópico + Gafas de Anticipación Espacial)
/// 2. "Starfield Distortion Hunter" (TechPort 97109: Metamorfopsia + Escotoma Peripapilar)
/// 3. Asistente de Contramedida LBNP (-20 mmHg) con Descompresión Gradual Obligatoria
class SansSuitePage extends ConsumerStatefulWidget {
  const SansSuitePage({super.key});

  @override
  ConsumerState<SansSuitePage> createState() => _SansSuitePageState();
}

class _SansSuitePageState extends ConsumerState<SansSuitePage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  StreamSubscription<FaceSample>? _faceSubscription;

  // Telemetría óptica y cámara frontal compartida entre pestañas
  CameraController? _cameraController;
  bool _cameraInitializing = true;
  String? _cameraNote;
  FaceSample? _latestFaceSample;
  final List<FaceSample> _recentFixationSamples = [];

  // Tab 1: distancia trigonométrica en vivo y bloqueo del punto de enfoque nítido
  double? _lockedNearPointCm;
  double _caliperVernierPx = 0.0;

  // Tab 2: Starfield Distortion Hunter (TechPort 97109)
  OcularEye _selectedEye = OcularEye.odRight;
  final double _injectedWaveAmplitude = 0.55;
  double _userStraighteningSlider = 0.15;
  late List<PeripheralFlashStimulus> _stimuli;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _stimuli = StarfieldDistortionAnalyzer.buildStandardStimuli(
      eye: _selectedEye,
      defaultDetected: true,
    );

    if (_isWidgetTestEnvironment) {
      _cameraInitializing = false;
      _cameraNote = 'Canal óptico en espera de hardware';
      return;
    }
    _initFrontCamera();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final tracker = ref.read(faceTrackerPortProvider);
      _faceSubscription = tracker.watchFaceSamples().listen(
        (sample) {
          if (!mounted) return;
          setState(() {
            _latestFaceSample = sample;
            _recentFixationSamples.add(sample);
            if (_recentFixationSamples.length > 60) {
              _recentFixationSamples.removeAt(0);
            }
          });
        },
        onError: (_) {},
      );
    });
  }

  Future<void> _initFrontCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (!mounted) return;
        setState(() {
          _cameraInitializing = false;
          _cameraNote = 'Sin cámara frontal detectada en este dispositivo';
        });
        return;
      }
      final front = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        front,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _cameraController = controller;
        _cameraInitializing = false;
        _cameraNote = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _cameraInitializing = false;
        _cameraNote = 'Canal óptico frontal no disponible';
      });
    }
  }

  @override
  void dispose() {
    _faceSubscription?.cancel();
    _cameraController?.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _selectEye(OcularEye eye) {
    setState(() {
      _selectedEye = eye;
      _stimuli = StarfieldDistortionAnalyzer.buildStandardStimuli(
        eye: eye,
        defaultDetected: true,
      );
    });
  }

  /// IPD aparente corregida por el vernier de alineación del calibre interpupilar.
  double _correctedIpdPx(DeviceCalibration calibration) {
    final raw = _latestFaceSample?.ipdPixels ??
        (calibration.focalLengthPx *
            calibration.crewIpdMm /
            (calibration.baselineNearPointCm * 10.0));
    return (raw + _caliperVernierPx).clamp(4.0, 4000.0);
  }

  /// Distancia ojo-pantalla calculada en vivo por trigonometría estenopeica:
  /// d = (f_px · IPD_mm) / (IPD_px · cos θ)
  double _liveDistanceCm(DeviceCalibration calibration) {
    return NearPointDiopterCalculator.computeEyeToScreenDistanceCm(
      ipdPixels: _correctedIpdPx(calibration),
      calibration: calibration,
      headYawDeg: _latestFaceSample?.headYawDeg ?? 0.0,
    );
  }

  void _confirmNearPointFocus(DeviceCalibration calibration) {
    setState(() {
      _lockedNearPointCm = _liveDistanceCm(calibration);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: SpaceTheme.card,
        content: Text(
          'Punto de enfoque nítido capturado a ${_lockedNearPointCm!.toStringAsFixed(1)} cm. '
          'Prescripción calculada sobre la distancia trigonométrica en vivo.',
          style: const TextStyle(color: Colors.white),
        ),
      ),
    );
  }

  void _reopenLiveFocus() {
    setState(() => _lockedNearPointCm = null);
  }

  void _adjustCaliperVernier(double deltaPx) {
    setState(() {
      _caliperVernierPx = (_caliperVernierPx + deltaPx).clamp(-40.0, 40.0);
    });
  }

  Future<void> _saveCurrentSansAssessment(
    NearPointEstimate nearEstimate,
    StarfieldAssessmentResult starfieldResult,
  ) async {
    await ref.read(sansAssessmentsProvider.notifier).recordAssessment(
          nearPoint: nearEstimate,
          starfield: starfieldResult,
        );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: SpaceTheme.card,
        content: Text(
          'Evaluación SANS guardada offline y encolada para Control de Misión (${starfieldResult.evaluatedEye.codeEs}).',
          style: const TextStyle(color: Colors.white),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final calibration = ref.watch(deviceCalibrationProvider);
    final pendingSync = ref.watch(pendingSyncCountProvider);

    final liveDistanceCm = _liveDistanceCm(calibration);
    final effectiveDistanceCm = _lockedNearPointCm ?? liveDistanceCm;

    final nearEstimate = NearPointDiopterCalculator.evaluateFromDistanceCm(
      currentNearPointCm: effectiveDistanceCm,
      baselineNearPointCm: calibration.baselineNearPointCm,
    );

    final starfieldResult = StarfieldDistortionAnalyzer.evaluate(
      evaluatedEye: _selectedEye,
      injectedWaveAmplitude: _injectedWaveAmplitude,
      userStraighteningSlider: _userStraighteningSlider,
      stimuli: _stimuli,
      fixationSamples: _recentFixationSamples,
    );

    return Scaffold(
      backgroundColor: SpaceTheme.background,
      appBar: AppBar(
        backgroundColor: SpaceTheme.surface,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'SUITE NEURO-OCULAR (SANS)',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.1,
                color: SpaceTheme.cyan,
              ),
            ),
            Text(
              'Telemetría IPD • Cribado Psicofísico TechPort 97109 • Asistente LBNP -20 mmHg',
              style: TextStyle(fontSize: 11, color: Colors.white70),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12.0),
            child: Chip(
              backgroundColor: SpaceTheme.card,
              side: const BorderSide(color: SpaceTheme.cyan, width: 0.8),
              avatar: const Icon(
                Icons.cloud_upload_outlined,
                size: 16,
                color: SpaceTheme.cyan,
              ),
              label: Text(
                'Cola Tierra: $pendingSync',
                style: const TextStyle(fontSize: 11, color: Colors.white),
              ),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: SpaceTheme.cyan,
          labelColor: SpaceTheme.cyan,
          unselectedLabelColor: Colors.white60,
          isScrollable: true,
          tabs: const [
            Tab(
              icon: Icon(Icons.visibility_outlined),
              text: '1. Punto Cercano (ΔD & Gafas)',
            ),
            Tab(
              icon: Icon(Icons.grid_4x4_outlined),
              text: '2. Starfield Distortion Hunter',
            ),
            Tab(
              icon: Icon(Icons.compress_outlined),
              text: '3. Contramedida LBNP (-20 mmHg)',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildNearPointTab(
            context,
            calibration,
            nearEstimate,
            liveDistanceCm,
          ),
          _buildStarfieldTab(context, nearEstimate, starfieldResult),
          _buildLbnpTab(context, nearEstimate, starfieldResult),
        ],
      ),
    );
  }

  // ===========================================================================
  // TAB 1: TELE-MEDIDOR DE PUNTO CERCANO (ΔD & GAFAS DE ANTICIPACIÓN)
  // ===========================================================================
  Widget _buildNearPointTab(
    BuildContext context,
    DeviceCalibration calibration,
    NearPointEstimate estimate,
    double liveDistanceCm,
  ) {
    final ipdPx = _correctedIpdPx(calibration);
    final tierColor = _colorForGlassesTier(estimate.recommendedGlassesTier);
    final locked = _lockedNearPointCm != null;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Visor óptico frontal en vivo con calibres IPD bilaterales
          _SansOpticalViewport(
            title: 'VISOR ÓPTICO FRONTAL EN VIVO · CALIBRE INTERPUPILAR BILATERAL',
            cameraController: _cameraController,
            initializing: _cameraInitializing,
            channelNote: _cameraNote,
            faceSample: _latestFaceSample,
            showIpdCalipers: true,
            showFixationTarget: false,
            statusNote: locked
                ? 'Punto de enfoque nítido bloqueado a ${_lockedNearPointCm!.toStringAsFixed(1)} cm'
                : 'Distancia trigonométrica en vivo: ${liveDistanceCm.toStringAsFixed(1)} cm',
          ),

          const SizedBox(height: 12),

          _buildStepGuideBox(
            stepLabel: 'GUÍA RÁPIDA · PUNTO CERCANO (ΔD)',
            instruction:
                '1. Alinea tus ojos dentro del visor superior · '
                '2. Aleja lentamente la pantalla hasta ver nítida la línea J1 · '
                '3. Pulsa "Confirmar Punto de Enfoque Nítido".',
          ),

          const SizedBox(height: 12),

          // Banner de Telemetría Trigonométrica IPD en vivo
          Card(
            color: SpaceTheme.card,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: SpaceTheme.cyan.withValues(alpha: 0.4),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.camera_front, color: SpaceTheme.cyan),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'TELE-MEDIDOR TRIGONOMÉTRICO DE DISTANCIA DE ENFOQUE (IPD)',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: SpaceTheme.cyan,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: SpaceTheme.surface,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'IPD Base: ${calibration.crewIpdMm.toStringAsFixed(1)} mm',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.white70,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _MetricPill(
                        label: 'IPD aparente cámara',
                        value: '${ipdPx.toStringAsFixed(1)} px',
                        accent: SpaceTheme.cyan,
                      ),
                      _MetricPill(
                        label: 'Distancia Ojo-Pantalla (d)',
                        value: '${estimate.distanceCm.toStringAsFixed(1)} cm',
                        accent: locked ? SpaceTheme.green : SpaceTheme.cyan,
                      ),
                      _MetricPill(
                        label: 'Punto Cercano Basal',
                        value:
                            '${estimate.baselineNearPointCm.toStringAsFixed(1)} cm',
                        accent: Colors.white70,
                      ),
                      _MetricPill(
                        label: 'Desplazamiento (ΔD ± IC 95%)',
                        value:
                            '+${estimate.hyperopicShiftDiopters.toStringAsFixed(2)} D (±${estimate.confidenceIntervalDiopters.toStringAsFixed(2)} D)',
                        accent: tierColor,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Divider(height: 12),
                  const SizedBox(height: 8),
                  const Text(
                    'Calibración de Vernier Óptico (alineación del calibre interpupilar):',
                    style: TextStyle(fontSize: 12, color: Colors.white70),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        tooltip: 'Alinear calibre a la izquierda',
                        onPressed: () => _adjustCaliperVernier(-0.5),
                        icon: const Icon(Icons.keyboard_arrow_left, size: 20),
                      ),
                      Expanded(
                        child: Text(
                          'Offset de calibre: ${_caliperVernierPx >= 0 ? "+" : ""}${_caliperVernierPx.toStringAsFixed(1)} px',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                            color: SpaceTheme.cyan,
                          ),
                        ),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        tooltip: 'Alinear calibre a la derecha',
                        onPressed: () => _adjustCaliperVernier(0.5),
                        icon: const Icon(Icons.keyboard_arrow_right, size: 20),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    children: [
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: SpaceTheme.green,
                          foregroundColor: Colors.black,
                        ),
                        onPressed: locked
                            ? null
                            : () => _confirmNearPointFocus(calibration),
                        icon: const Icon(Icons.center_focus_strong),
                        label: const Text(
                          'Confirmar Punto de Enfoque Nítido (Capturar ΔD)',
                        ),
                      ),
                      if (locked)
                        OutlinedButton.icon(
                          onPressed: _reopenLiveFocus,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retomar Medición en Vivo'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Carta de Optotipos de Punto Cercano (Snellen / Sloan de Cabina Espacial)
          Card(
            color: SpaceTheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Colors.white24),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'CARTA DE OPTOTIPOS DE PROXIMIDAD (CALIBRADA EN PÍXELES/MM)',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Instrucción: Sostén la pantalla frente a tu rostro con el ojo contralateral ocluido y aléjala lentamente hasta que la línea J1 sea completamente nítida.',
                    style: TextStyle(fontSize: 12, color: Colors.white60),
                  ),
                  const Divider(height: 20, color: Colors.white12),
                  _buildOptotypeRow(
                    tag: 'J5 (20/50)',
                    text: 'NAV  ORB  ΔV  408  KMS',
                    fontSize: 19,
                    isSharp: estimate.distanceCm >= 20.0,
                  ),
                  _buildOptotypeRow(
                    tag: 'J3 (20/40)',
                    text: 'docking-port  attitude  roll-04.2',
                    fontSize: 15,
                    isSharp: estimate.distanceCm >= 23.0,
                  ),
                  _buildOptotypeRow(
                    tag: 'J2 (20/30)',
                    text: 'O2-PARTIAL-16.4  CO2-SCRUBBER-NOMINAL',
                    fontSize: 12.5,
                    isSharp: estimate.distanceCm >= 25.0,
                  ),
                  _buildOptotypeRow(
                    tag: 'J1 (20/20)',
                    text: 'TELEMETRÍA FINA: LBNP -20.0 mmHg • FRISÉN OCT • CHIBIS',
                    fontSize: 10.5,
                    isSharp: true,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Tarjeta de Recomendación Clínica de Gafas de Anticipación Espacial
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: tierColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: tierColor, width: 1.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      estimate.requiresFlightSurgeonAlert
                          ? Icons.warning_amber_rounded
                          : Icons.check_circle_outline,
                      color: tierColor,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        estimate.recommendedGlassesTier.labelEs,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: tierColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  estimate.clinicalSummaryEs,
                  style: const TextStyle(fontSize: 13.5, color: Colors.white),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: SpaceTheme.cyan,
                        foregroundColor: Colors.black,
                      ),
                      onPressed: () => _tabController.animateTo(1),
                      icon: const Icon(Icons.arrow_forward),
                      label: const Text('Continuar a Starfield Hunter (Paso 2)'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptotypeRow({
    required String tag,
    required String text,
    required double fontSize,
    required bool isSharp,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          SizedBox(
            width: 82,
            child: Text(
              tag,
              style: const TextStyle(
                fontSize: 11,
                color: SpaceTheme.cyan,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: fontSize,
                letterSpacing: 1.4,
                fontWeight: FontWeight.w600,
                color: isSharp ? Colors.white : Colors.white54,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _colorForGlassesTier(SpaceAnticipationGlassesTier tier) {
    switch (tier) {
      case SpaceAnticipationGlassesTier.none:
        return SpaceTheme.green;
      case SpaceAnticipationGlassesTier.pair1Plus075D:
        return SpaceTheme.cyan;
      case SpaceAnticipationGlassesTier.pair2Plus125D:
        return SpaceTheme.warningYellow;
      case SpaceAnticipationGlassesTier.pair3Plus175D:
        return SpaceTheme.dangerRed;
    }
  }

  // ===========================================================================
  // TAB 2: "STARFIELD DISTORTION HUNTER" (NASA TECHPORT 97109)
  // ===========================================================================
  Widget _buildStarfieldTab(
    BuildContext context,
    NearPointEstimate nearEstimate,
    StarfieldAssessmentResult starfieldResult,
  ) {
    final gazeOffset = _latestFaceSample?.gazeOffsetDeg ?? 0.0;
    final fixationOk =
        gazeOffset <= StarfieldDistortionAnalyzer.maxAllowedGazeOffsetDeg;
    final riskColor = _colorForRiskTier(starfieldResult.riskTier);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Monitor de fijación central con cámara frontal en vivo
          _SansOpticalViewport(
            title: 'MONITOR DE FIJACIÓN CENTRAL · CÁMARA FRONTAL EN VIVO',
            cameraController: _cameraController,
            initializing: _cameraInitializing,
            channelNote: _cameraNote,
            faceSample: _latestFaceSample,
            height: 190,
            showIpdCalipers: false,
            showFixationTarget: true,
            statusNote: fixationOk
                ? 'Fijación central verificada: desviación ${gazeOffset.toStringAsFixed(2)}° '
                    '(límite ≤ ${StarfieldDistortionAnalyzer.maxAllowedGazeOffsetDeg.toStringAsFixed(1)}°)'
                : 'Desviación de mirada ${gazeOffset.toStringAsFixed(2)}° fuera del planeta central. '
                    'Reajusta la vista para un registro válido.',
          ),

          const SizedBox(height: 12),

          _buildStepGuideBox(
            stepLabel: 'GUÍA RÁPIDA · STARFIELD DISTORTION HUNTER',
            instruction:
                '1. Tapa el ojo contralateral y elige OD o OI · '
                '2. Fija la vista en el planeta central y toca cualquier destello periférico que NO veas nítido (marca rojo = escotoma) · '
                '3. Endereza la línea ondulada con el deslizador.',
          ),

          const SizedBox(height: 12),

          // Selector Monocular + Verificador de Fijación Central
          Card(
            color: SpaceTheme.card,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 8,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      const Text(
                        'Protocolo Monocular: ',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      ChoiceChip(
                        label: const Text('Ojo Derecho (OD)'),
                        selected: _selectedEye == OcularEye.odRight,
                        selectedColor: SpaceTheme.cyan.withValues(alpha: 0.25),
                        onSelected: (_) => _selectEye(OcularEye.odRight),
                      ),
                      ChoiceChip(
                        label: const Text('Ojo Izquierdo (OI)'),
                        selected: _selectedEye == OcularEye.osLeft,
                        selectedColor: SpaceTheme.cyan.withValues(alpha: 0.25),
                        onSelected: (_) => _selectEye(OcularEye.osLeft),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: (fixationOk
                              ? SpaceTheme.green
                              : SpaceTheme.warningYellow)
                          .withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: fixationOk
                            ? SpaceTheme.green
                            : SpaceTheme.warningYellow,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          fixationOk ? Icons.center_focus_strong : Icons.warning,
                          size: 16,
                          color: fixationOk
                              ? SpaceTheme.green
                              : SpaceTheme.warningYellow,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Fijación Planeta Central: ${gazeOffset.toStringAsFixed(1)}° '
                          '(${(starfieldResult.centralFixationScore * 100).toStringAsFixed(0)}%)',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Malla Holográfica Interactiva (Caza de Pliegues + Destellos Periféricos)
          Card(
            color: SpaceTheme.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: SpaceTheme.cyan.withValues(alpha: 0.4),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'MALLA HOLOGRÁFICA DE NAVEGACIÓN ESTELAR (TECHPORT 97109)',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: SpaceTheme.cyan,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Mantén la vista fija en el planeta central. Toca los destellos grises periféricos que logres percibir (los no tocados marcan escotomas / punto ciego ~15° temporal) y endereza la onda con el control inferior.',
                    style: TextStyle(fontSize: 11.5, color: Colors.white70),
                  ),
                  const SizedBox(height: 10),
                  Center(
                    child: AspectRatio(
                      aspectRatio: 1.35,
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final canvasSize = Size(
                            constraints.maxWidth,
                            constraints.maxHeight,
                          );
                          return GestureDetector(
                            onTapDown: (details) {
                              _handleStarfieldTap(
                                details.localPosition,
                                canvasSize,
                              );
                            },
                            child: CustomPaint(
                              size: canvasSize,
                              painter: StarfieldHolographicGridPainter(
                                residualWaveAmplitude: _injectedWaveAmplitude -
                                    _userStraighteningSlider,
                                stimuli: _stimuli,
                                evaluatedEye: _selectedEye,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      const Text(
                        'Verde/Blanco = Percibido · Rojo = Escotoma · Anillo = ~15°',
                        style: TextStyle(fontSize: 11, color: Colors.white60),
                      ),
                      TextButton.icon(
                        onPressed: () => _selectEye(_selectedEye),
                        icon: const Icon(Icons.refresh, size: 15),
                        label: const Text(
                          'Restablecer Destellos',
                          style: TextStyle(fontSize: 11.5),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Control "Caza de Pliegues" (Metamorfopsia)
          Card(
            color: SpaceTheme.card,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Expanded(
                        child: Text(
                          'Caza de Pliegues (Metamorfopsia): Enderezar línea holográfica',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      Text(
                        'Residual: ${starfieldResult.residualMetamorphopsiaIndex.toStringAsFixed(2)}',
                        style: const TextStyle(
                          color: SpaceTheme.cyan,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    value: _userStraighteningSlider.clamp(-1.0, 1.0),
                    min: -1.0,
                    max: 1.0,
                    divisions: 80,
                    activeColor: SpaceTheme.cyan,
                    label: _userStraighteningSlider.toStringAsFixed(2),
                    onChanged: (val) {
                      setState(() {
                        _userStraighteningSlider = val;
                      });
                    },
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Destellos periféricos percibidos: '
                    '${_stimuli.where((s) => s.detectedByUser).length}/${_stimuli.length} · '
                    'Sensibilidad al contraste: '
                    '${(starfieldResult.contrastSensitivityScore * 100).toStringAsFixed(0)}%',
                    style: const TextStyle(fontSize: 12, color: Colors.white70),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Diagnóstico Funcional SANS y Lanzador de Contramedida LBNP
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: riskColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: riskColor, width: 1.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  starfieldResult.riskTier.labelEs,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: riskColor,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  starfieldResult.clinicalNoteEs,
                  style: const TextStyle(fontSize: 12.5, color: Colors.white),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: SpaceTheme.cyan,
                        foregroundColor: Colors.black,
                      ),
                      onPressed: () => _saveCurrentSansAssessment(
                        nearEstimate,
                        starfieldResult,
                      ),
                      icon: const Icon(Icons.save_outlined),
                      label: const Text('Guardar Evaluación SANS Offline'),
                    ),
                    if (starfieldResult.shouldLaunchLbnpCountermeasure)
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: SpaceTheme.warningYellow,
                          foregroundColor: Colors.black,
                        ),
                        onPressed: () {
                          _tabController.animateTo(2);
                        },
                        icon: const Icon(Icons.compress),
                        label: const Text(
                          'Lanzar Contramedida LBNP (-20 mmHg)',
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _handleStarfieldTap(Offset localPos, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = math.min(size.width, size.height) * 0.44;

    int? closestIndex;
    double minDistance = 32.0;

    for (int i = 0; i < _stimuli.length; i++) {
      final s = _stimuli[i];
      final rad = s.polarAngleDeg * math.pi / 180.0;
      final normR = (s.eccentricityDeg / 18.0).clamp(0.15, 0.98);
      final stimPos = Offset(
        center.dx + math.cos(rad) * maxRadius * normR,
        center.dy - math.sin(rad) * maxRadius * normR,
      );
      final dist = (localPos - stimPos).distance;
      if (dist < minDistance) {
        minDistance = dist;
        closestIndex = i;
      }
    }

    if (closestIndex != null) {
      setState(() {
        final current = _stimuli[closestIndex!];
        _stimuli[closestIndex] = current.copyWith(
          detectedByUser: !current.detectedByUser,
        );
      });
    }
  }

  Color _colorForRiskTier(SansFunctionalRiskTier tier) {
    switch (tier) {
      case SansFunctionalRiskTier.nominal:
        return SpaceTheme.green;
      case SansFunctionalRiskTier.mildFunctionalShift:
        return SpaceTheme.cyan;
      case SansFunctionalRiskTier.moderateFoldsOrScotoma:
        return SpaceTheme.warningYellow;
      case SansFunctionalRiskTier.criticalNotifyFlightSurgeon:
        return SpaceTheme.dangerRed;
    }
  }

  // ===========================================================================
  // TAB 3: ASISTENTE LBNP (-20 mmHg) & DESCOMPRESIÓN GRADUAL OBLIGATORIA
  // ===========================================================================
  Widget _buildLbnpTab(
    BuildContext context,
    NearPointEstimate nearEstimate,
    StarfieldAssessmentResult starfieldResult,
  ) {
    final lbnpState = ref.watch(lbnpProtocolProvider);
    final lbnpNotifier = ref.read(lbnpProtocolProvider.notifier);
    final savedAssessments = ref.watch(sansAssessmentsProvider);
    final astronaut = ref.watch(selectedAstronautProvider);

    final pressureFraction = (lbnpState.currentPressureMmHg.abs() /
            MedicalThresholds.lbnpTargetPressureMmHg.abs())
        .clamp(0.0, 1.0);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Encabezado Clínico LBNP (Lawley et al., 2017)
          Card(
            color: SpaceTheme.card,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: SpaceTheme.cyan.withValues(alpha: 0.5),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.shield_outlined, color: SpaceTheme.cyan),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'ASISTENTE DE CONTRAMEDIDA LBNP (-20 mmHg) • PROTOCOLO CHIBIS',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: SpaceTheme.cyan,
                            fontSize: 13.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _buildStepGuideBox(
                    stepLabel: 'PROTOCOLO CHIBIS-M (-20 mmHg)',
                    instruction:
                        '1. Pulsa Iniciar Sellado y Presurización · '
                        '2. Mantén la presión objetivo · '
                        '3. Al terminar, ejecuta Descompresión Gradual (-20 → 0 mmHg) sin liberar de golpe.',
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Telemetría de Presión LBNP (Chibis-M / Protocolo -20 mmHg)',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: SpaceTheme.cyan,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Estado: ${lbnpState.phase.labelEs}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        '${lbnpState.currentPressureMmHg.toStringAsFixed(1)} mmHg',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: lbnpState.hemodynamicSafetyLockActive
                              ? SpaceTheme.warningYellow
                              : SpaceTheme.green,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: pressureFraction,
                      minHeight: 14,
                      backgroundColor: SpaceTheme.surface,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        lbnpState.phase ==
                                LbnpPhase.mandatoryGradualDecompression
                            ? SpaceTheme.warningYellow
                            : SpaceTheme.cyan,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    lbnpState.statusMessageEs,
                    style: const TextStyle(fontSize: 12.5, color: Colors.white),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    children: [
                      _MetricPill(
                        label: 'Tripulante',
                        value: '${astronaut.name} [${astronaut.callsign}]',
                        accent: Colors.white70,
                      ),
                      _MetricPill(
                        label: 'Mantenimiento Activo',
                        value:
                            '${lbnpState.activeHoldElapsedSeconds}/${lbnpState.targetHoldDurationSeconds} s',
                        accent: SpaceTheme.cyan,
                      ),
                      _MetricPill(
                        label: 'Sello de Presión',
                        value: lbnpState.hemodynamicSafetyLockActive
                            ? 'BLOQUEADO'
                            : 'LIBERADO',
                        accent: lbnpState.hemodynamicSafetyLockActive
                            ? SpaceTheme.warningYellow
                            : SpaceTheme.green,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Alerta de Bloqueo Hemodinámico si se intentó liberar de golpe
          if (lbnpState.warningBannerEs != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: SpaceTheme.dangerRed.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: SpaceTheme.dangerRed, width: 1.5),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.lock_clock,
                    color: SpaceTheme.dangerRed,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      lbnpState.warningBannerEs!,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 12),

          // Panel de Fase de Descompresión Gradual Obligatoria (15 s)
          Card(
            color: SpaceTheme.surface,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Expanded(
                        child: Text(
                          'FASE DE DESCOMPRESIÓN GRADUAL OBLIGATORIA (-20 → 0 mmHg)',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: SpaceTheme.warningYellow,
                          ),
                        ),
                      ),
                      Text(
                        '${lbnpState.decompressionElapsedSeconds}/${lbnpState.requiredDecompressionSeconds} s',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: lbnpState.decompressionProgress,
                      minHeight: 10,
                      backgroundColor: SpaceTheme.card,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        SpaceTheme.green,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Regla de Seguridad Biomédica: Prohibido liberar la succión de golpe desde -20 mmHg. '
                    'El retorno escalonado (-20 → -15 → -10 → -5 → 0 mmHg) evita el pico hipertensivo intracraneal de rebote.',
                    style: TextStyle(fontSize: 11.5, color: Colors.white60),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: SpaceTheme.cyan,
                          foregroundColor: Colors.black,
                        ),
                        onPressed: lbnpState.phase == LbnpPhase.idle ||
                                lbnpState.phase == LbnpPhase.completed ||
                                lbnpState.phase == LbnpPhase.aborted
                            ? () => lbnpNotifier.startProtocol()
                            : null,
                        icon: const Icon(Icons.play_arrow),
                        label: const Text(
                          'Iniciar Sellado y Presurización',
                        ),
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: SpaceTheme.warningYellow,
                          foregroundColor: Colors.black,
                        ),
                        onPressed: lbnpState.hemodynamicSafetyLockActive
                            ? () => lbnpNotifier.requestStopOrRelease()
                            : null,
                        icon: const Icon(Icons.security_update_warning),
                        label: const Text(
                          'Iniciar Descompresión Gradual (-20 → 0 mmHg)',
                        ),
                      ),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: SpaceTheme.dangerRed,
                          side: const BorderSide(color: SpaceTheme.dangerRed),
                        ),
                        onPressed: lbnpState.phase != LbnpPhase.idle &&
                                lbnpState.phase != LbnpPhase.completed &&
                                lbnpState.phase != LbnpPhase.aborted
                            ? () => lbnpNotifier.requestStopOrRelease()
                            : null,
                        icon: const Icon(Icons.emergency_share),
                        label: const Text('Parada de Emergencia'),
                      ),
                      if (lbnpState.phase == LbnpPhase.completed ||
                          lbnpState.phase == LbnpPhase.aborted)
                        OutlinedButton.icon(
                          onPressed: () => lbnpNotifier.resetIfSafe(),
                          icon: const Icon(Icons.refresh),
                          label: const Text('Reiniciar Asistente'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Bitácora Histórica Local (Hive Offline)
          Text(
            'HISTÓRICO LOCAL DE EVALUACIONES SANS (${savedAssessments.length})',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 8),
          if (savedAssessments.isEmpty)
            const Card(
              color: SpaceTheme.card,
              child: Padding(
                padding: EdgeInsets.all(14),
                child: Text(
                  'Aún no hay evaluaciones SANS registradas en esta sesión.',
                  style: TextStyle(fontSize: 12, color: Colors.white60),
                ),
              ),
            )
          else
            ...savedAssessments.take(5).map(
                  (item) => Card(
                    color: SpaceTheme.card,
                    child: ListTile(
                      dense: true,
                      leading: const Icon(
                        Icons.remove_red_eye_outlined,
                        color: SpaceTheme.cyan,
                      ),
                      title: Text(
                        '[${item.starfield.evaluatedEye.codeEs}] ΔD: +${item.nearPoint.hyperopicShiftDiopters.toStringAsFixed(2)} D • ${item.nearPoint.recommendedGlassesTier.labelEs}',
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: Text(
                        item.starfield.clinicalNoteEs,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildStepGuideBox({
    required String stepLabel,
    required String instruction,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: SpaceTheme.cyan.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: SpaceTheme.cyan.withValues(alpha: 0.30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            stepLabel,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: SpaceTheme.cyan,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            instruction,
            style: const TextStyle(fontSize: 12, color: Colors.white70),
          ),
        ],
      ),
    );
  }
}

class _MetricPill extends StatelessWidget {
  final String label;
  final String value;
  final Color accent;

  const _MetricPill({
    required this.label,
    required this.value,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: SpaceTheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: accent.withValues(alpha: 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 10.5, color: Colors.white60),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.bold,
              color: accent,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// VISOR CLÍNICO DE CÁMARA FRONTAL EN VIVO + HUD DE CALIBRE IPD / FIJACIÓN
// =============================================================================

/// Visor de cámara frontal con superposición clínica de calibres interpupilares
/// bilaterales y verificador de fijación central del planeta.
class _SansOpticalViewport extends StatelessWidget {
  final String title;
  final CameraController? cameraController;
  final bool initializing;
  final String? channelNote;
  final FaceSample? faceSample;
  final double height;
  final bool showIpdCalipers;
  final bool showFixationTarget;
  final String? statusNote;

  const _SansOpticalViewport({
    required this.title,
    required this.cameraController,
    required this.initializing,
    required this.channelNote,
    required this.faceSample,
    this.height = 230,
    this.showIpdCalipers = true,
    this.showFixationTarget = false,
    this.statusNote,
  });

  Widget _buildPreview(BuildContext context, CameraController controller) {
    final previewSize = controller.value.previewSize;
    if (previewSize == null) return CameraPreview(controller);
    final isLandscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    final boxWidth = isLandscape ? previewSize.width : previewSize.height;
    final boxHeight = isLandscape ? previewSize.height : previewSize.width;
    return ClipRect(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: boxWidth,
          height: boxHeight,
          child: CameraPreview(controller),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = cameraController;
    final live = controller != null && controller.value.isInitialized;

    return Card(
      color: SpaceTheme.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: SpaceTheme.cyan.withValues(alpha: 0.45)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.camera_front, color: SpaceTheme.cyan, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: SpaceTheme.cyan,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: (live ? SpaceTheme.green : SpaceTheme.warningYellow)
                        .withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: live ? SpaceTheme.green : SpaceTheme.warningYellow,
                    ),
                  ),
                  child: Text(
                    live ? 'EN VIVO' : 'SINCRONIZANDO',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: live ? SpaceTheme.green : SpaceTheme.warningYellow,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                height: height,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ColoredBox(
                      color: const Color(0xFF05080D),
                      child: live
                          ? _buildPreview(context, controller)
                          : Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    initializing
                                        ? Icons.hourglass_top
                                        : Icons.videocam_off_outlined,
                                    color: Colors.white30,
                                    size: 34,
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    channelNote ??
                                        'Inicializando canal óptico frontal…',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Colors.white38,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                    ),
                    CustomPaint(
                      painter: _SansOpticalHudPainter(
                        sample: faceSample,
                        showIpdCalipers: showIpdCalipers,
                        showFixationTarget: showFixationTarget,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (statusNote != null) ...[
              const SizedBox(height: 8),
              Text(
                statusNote!,
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.bold,
                  color: SpaceTheme.cyan,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SansOpticalHudPainter extends CustomPainter {
  final FaceSample? sample;
  final bool showIpdCalipers;
  final bool showFixationTarget;

  const _SansOpticalHudPainter({
    required this.sample,
    required this.showIpdCalipers,
    required this.showFixationTarget,
  });

  static const double _nominalFrameWidthPx = 640.0;

  @override
  void paint(Canvas canvas, Size size) {
    _paintFrameBrackets(canvas, size);
    if (showIpdCalipers) {
      _paintIpdCalipers(canvas, size);
    }
    _paintGazeVector(canvas, size);
    if (showFixationTarget) {
      _paintFixationTarget(canvas, size);
    }
  }

  void _paintFrameBrackets(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = SpaceTheme.cyan.withValues(alpha: 0.85)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;
    const len = 16.0;
    final corners = <Offset>[
      const Offset(6, 6),
      Offset(size.width - 6, 6),
      Offset(6, size.height - 6),
      Offset(size.width - 6, size.height - 6),
    ];
    for (var i = 0; i < corners.length; i++) {
      final c = corners[i];
      final dx = (i == 0 || i == 2) ? len : -len;
      final dy = (i < 2) ? len : -len;
      canvas.drawLine(c, c + Offset(dx, 0), paint);
      canvas.drawLine(c, c + Offset(0, dy), paint);
    }
  }

  void _paintIpdCalipers(Canvas canvas, Size size) {
    final ipdPx = sample?.ipdPixels ?? 0.0;
    final scale = size.width / _nominalFrameWidthPx;
    final halfSpan = ((ipdPx * scale) / 2).clamp(6.0, size.width * 0.40);
    final cy = size.height * 0.46;
    final left = Offset(size.width / 2 - halfSpan, cy);
    final right = Offset(size.width / 2 + halfSpan, cy);

    final paint = Paint()
      ..color = SpaceTheme.cyan
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke;

    canvas.drawLine(left, right, paint);
    canvas.drawLine(left + const Offset(0, -8), left + const Offset(0, 8), paint);
    canvas.drawLine(
      right + const Offset(0, -8),
      right + const Offset(0, 8),
      paint,
    );

    // Calibres verticales de alineación (vernier óptico)
    final vernier = Paint()
      ..color = SpaceTheme.cyan.withValues(alpha: 0.45)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
      Offset(left.dx, cy - 22),
      Offset(left.dx, cy + 22),
      vernier,
    );
    canvas.drawLine(
      Offset(right.dx, cy - 22),
      Offset(right.dx, cy + 22),
      vernier,
    );

    final pupilPaint = Paint()
      ..color = SpaceTheme.cyan.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;
    canvas.drawCircle(left, 6, pupilPaint);
    canvas.drawCircle(right, 6, pupilPaint);

    final dotPaint = Paint()..color = SpaceTheme.cyan;
    canvas.drawCircle(left, 2, dotPaint);
    canvas.drawCircle(right, 2, dotPaint);

    _drawLabel(
      canvas,
      Offset(size.width / 2 - 46, cy + 12),
      'IPD ${ipdPx.toStringAsFixed(1)} px',
      SpaceTheme.cyan,
    );
  }

  void _paintGazeVector(Canvas canvas, Size size) {
    final gaze = sample?.gazeOffsetDeg ?? 0.0;
    final center = Offset(size.width / 2, size.height * 0.46);
    final maxDim = math.min(size.width, size.height);
    final radius = ((gaze / 10.0).clamp(0.0, 1.0)) * maxDim * 0.30;
    final onTarget = gaze <= StarfieldDistortionAnalyzer.maxAllowedGazeOffsetDeg;
    final color = onTarget ? SpaceTheme.green : SpaceTheme.dangerRed;

    final paint = Paint()
      ..color = color.withValues(alpha: 0.75)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(center, 3.5, paint);
    if (radius > 2) {
      canvas.drawCircle(center, radius, paint);
      canvas.drawLine(
        center + Offset(-radius, 0),
        center + Offset(radius, 0),
        paint,
      );
      canvas.drawLine(
        center + Offset(0, -radius),
        center + Offset(0, radius),
        paint,
      );
    }
    _drawLabel(
      canvas,
      Offset(center.dx + 10, center.dy - 18),
      'GAZE ${gaze.toStringAsFixed(2)}°',
      color,
    );
  }

  void _paintFixationTarget(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.24);
    final paint = Paint()
      ..color = SpaceTheme.warningYellow.withValues(alpha: 0.9)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(center, 12, paint);
    canvas.drawCircle(center, 20, paint);
    canvas.drawLine(
      center + const Offset(-28, 0),
      center + const Offset(-14, 0),
      paint,
    );
    canvas.drawLine(
      center + const Offset(14, 0),
      center + const Offset(28, 0),
      paint,
    );
    canvas.drawCircle(center, 2.5, Paint()..color = SpaceTheme.warningYellow);
    _drawLabel(
      canvas,
      Offset(center.dx - 40, center.dy + 24),
      'FIJACIÓN CENTRAL',
      SpaceTheme.warningYellow,
    );
  }

  void _drawLabel(Canvas canvas, Offset offset, String text, Color color) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.bold,
          color: color,
          letterSpacing: 0.4,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _SansOpticalHudPainter oldDelegate) {
    return oldDelegate.sample != sample ||
        oldDelegate.showIpdCalipers != showIpdCalipers ||
        oldDelegate.showFixationTarget != showFixationTarget;
  }
}

/// CustomPainter que renderiza la malla de navegación estelar holográfica
/// con planeta central de fijación, distorsión sinusoidal por metamorfopsia
/// ("Caza de Pliegues") y destellos grises periféricos (~15° punto ciego).
class StarfieldHolographicGridPainter extends CustomPainter {
  final double residualWaveAmplitude;
  final List<PeripheralFlashStimulus> stimuli;
  final OcularEye evaluatedEye;

  const StarfieldHolographicGridPainter({
    required this.residualWaveAmplitude,
    required this.stimuli,
    required this.evaluatedEye,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final bgPaint = Paint()..color = const Color(0xFF05080D);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(10)),
      bgPaint,
    );

    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = math.min(size.width, size.height) * 0.44;

    final gridPaint = Paint()
      ..color = SpaceTheme.cyan.withValues(alpha: 0.24)
      ..strokeWidth = 1.1
      ..style = PaintingStyle.stroke;

    final distortedPaint = Paint()
      ..color = SpaceTheme.cyan.withValues(alpha: 0.75)
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke;

    // Líneas horizontales y verticales de la malla Amsler holográfica
    const int gridSteps = 8;
    for (int i = -gridSteps; i <= gridSteps; i++) {
      final norm = i / gridSteps;
      final yBase = center.dy + norm * maxRadius;
      final xBase = center.dx + norm * maxRadius;

      // Las líneas cercanas al centro sufren ondulación metamórfica si residualWaveAmplitude != 0
      final waveFactor = math.exp(-norm * norm * 3.0) * residualWaveAmplitude;

      final hPath = Path();
      final vPath = Path();
      const int segments = 40;
      for (int s = 0; s <= segments; s++) {
        final t = s / segments;
        final x = center.dx - maxRadius + (2 * maxRadius * t);
        final yWave = math.sin(t * math.pi * 4.0) * waveFactor * 18.0;
        if (s == 0) {
          hPath.moveTo(x, yBase + yWave);
        } else {
          hPath.lineTo(x, yBase + yWave);
        }

        final y = center.dy - maxRadius + (2 * maxRadius * t);
        final xWave = math.sin(t * math.pi * 4.0) * waveFactor * 18.0;
        if (s == 0) {
          vPath.moveTo(xBase + xWave, y);
        } else {
          vPath.lineTo(xBase + xWave, y);
        }
      }

      final activeLine = i.abs() <= 2;
      canvas.drawPath(hPath, activeLine ? distortedPaint : gridPaint);
      canvas.drawPath(vPath, activeLine ? distortedPaint : gridPaint);
    }

    // Anillo peripapilar de referencia (~15° excentricidad)
    final ringRadius = maxRadius * (MedicalThresholds.blindSpotTemporalDeg / 18.0);
    final ringPaint = Paint()
      ..color = SpaceTheme.neonPurple.withValues(alpha: 0.28)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawCircle(center, ringRadius, ringPaint);

    // Planeta central de fijación ocular obligatoria
    final planetGlow = Paint()
      ..color = SpaceTheme.cyan.withValues(alpha: 0.22)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 18, planetGlow);

    final planetCore = Paint()
      ..color = SpaceTheme.cyan
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 7, planetCore);

    // Destellos periféricos de bajo contraste y marcadores de escotoma
    for (final s in stimuli) {
      final rad = s.polarAngleDeg * math.pi / 180.0;
      final normR = (s.eccentricityDeg / 18.0).clamp(0.15, 0.98);
      final pos = Offset(
        center.dx + math.cos(rad) * maxRadius * normR,
        center.dy - math.sin(rad) * maxRadius * normR,
      );

      if (s.detectedByUser) {
        final grayAlpha = (0.35 + s.contrastLevel * 1.5).clamp(0.35, 0.90);
        final flashPaint = Paint()
          ..color = Colors.white.withValues(alpha: grayAlpha)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(pos, 7.5, flashPaint);

        final borderPaint = Paint()
          ..color = SpaceTheme.green.withValues(alpha: 0.8)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5;
        canvas.drawCircle(pos, 10.0, borderPaint);
      } else {
        // Escotoma / Punto ciego reportado en esta coordenada
        final scotomaFill = Paint()
          ..color = SpaceTheme.dangerRed.withValues(alpha: 0.28)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(pos, 11.0, scotomaFill);

        final scotomaStroke = Paint()
          ..color = SpaceTheme.dangerRed
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0;
        canvas.drawCircle(pos, 11.0, scotomaStroke);
      }
    }
  }

  @override
  bool shouldRepaint(covariant StarfieldHolographicGridPainter oldDelegate) {
    return oldDelegate.residualWaveAmplitude != residualWaveAmplitude ||
        oldDelegate.evaluatedEye != evaluatedEye ||
        oldDelegate.stimuli != stimuli;
  }
}

/// `true` cuando el árbol de widgets se ejecuta bajo `flutter_test`.
bool get _isWidgetTestEnvironment =>
    WidgetsBinding.instance.runtimeType.toString().contains('Test');
