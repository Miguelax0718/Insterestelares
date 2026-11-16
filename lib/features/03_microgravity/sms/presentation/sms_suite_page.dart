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
import '../data/sms_repository.dart';
import '../domain/sms_models_and_analyzers.dart';
import 'zero_g_horizon_painter.dart';

/// Suite clínica interactiva de Mareo Espacial (SMS) y Desorientación Sensoriomotora
/// (`03_microgravity/sms`).
///
/// Integra 3 módulos conectados:
/// 1. Visor óptico frontal en vivo + Escáner de Cromaticidad Facial Δ(G/R) con Tarjeta
///    Blanca de Referencia + Estabilidad Ocular 1 Hz + Escala de Graybiel (1968).
/// 2. "Zero-G Horizon": Entrenamiento y evaluación de habituación sensoriomotora 3D (45 s)
///    en Roll, Pitch y Yaw, con actitud comandada por telemetría inercial, pose cefálica
///    y propulsores vernier táctiles.
/// 3. Dictamen Clínico EVA (GO / NO-GO) y cola de telemetría Offline-First.
class SmsSuitePage extends ConsumerStatefulWidget {
  final bool embedded;

  const SmsSuitePage({
    super.key,
    this.embedded = false,
  });

  @override
  ConsumerState<SmsSuitePage> createState() => _SmsSuitePageState();
}

class _SmsSuitePageState extends ConsumerState<SmsSuitePage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  // --- Estado de Pestaña 1: Escáner Δ(G/R), 1 Hz DVA y Escala de Graybiel ---
  StreamSubscription<FaceSample>? _faceSub;
  FaceSample? _latestFaceSample;
  double _whiteCardLuminance = 1.0;

  bool _isScanningChromaticity = false;
  int _scanRemainingSec = 15;
  Timer? _chromaticityTimer;
  final List<FaceSample> _capturedScanSamples = [];
  FacialGreennessResult? _greennessResult;

  bool _isRunningMetronome = false;
  int _metronomeRemainingSec = 10;
  Timer? _metronomeTimer;
  double _metronomePhase = 0.0;
  final List<FaceSample> _capturedMetronomeSamples = [];
  static const List<String> _optotypes = ['E', 'C', 'F', 'P', 'T', 'O', 'Z'];
  String _activeOptotype = 'E';
  int _optotypeHits = 0;
  int _optotypeTotal = 0;
  GazeStabilityResult? _gazeResult;

  GraybielSymptomAssessment _graybiel = const GraybielSymptomAssessment();

  // --- Estado de Pestaña 2: Zero-G Horizon (45 s) ---
  StreamSubscription<MotionSample>? _motionSub;
  MotionSample? _latestMotionSample;

  Timer? _horizonLoopTimer;
  bool _isHorizonRunning = false;
  int _horizonRemainingSec = MedicalThresholds.zeroGHorizonDurationSeconds;
  double _horizonElapsedSec = 0.0;

  double _targetRollDeg = 12.0;
  double _targetPitchDeg = -8.0;
  double _targetYawDeg = 15.0;

  // Actitud de la nave comandada por telemetría en vivo + propulsores vernier.
  double _userRollDeg = 0.0;
  double _userPitchDeg = 0.0;
  double _userYawDeg = 0.0;

  double _vernierRollDeg = 0.0;
  double _vernierPitchDeg = 0.0;
  double _vernierYawDeg = 0.0;

  final List<double> _rollErrors = [];
  final List<double> _pitchErrors = [];
  final List<double> _yawErrors = [];
  ZeroGHorizonResult? _horizonResult;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _subscribeFaceStream();
    _subscribeMotionStream();
  }

  void _subscribeFaceStream({bool continuous = false}) {
    _faceSub?.cancel();
    if (_isWidgetTestEnvironment && !continuous) {
      return;
    }
    final tracker = ref.read(faceTrackerPortProvider);
    _faceSub = tracker.watchFaceSamples().listen(
      (sample) {
        if (!mounted) return;
        final adjustedSample = FaceSample(
          timestamp: sample.timestamp,
          headYawDeg: sample.headYawDeg,
          headPitchDeg: sample.headPitchDeg,
          headRollDeg: sample.headRollDeg,
          gazeOffsetDeg: sample.gazeOffsetDeg,
          ipdPixels: sample.ipdPixels,
          cheekRedMean: sample.cheekRedMean,
          cheekGreenMean: sample.cheekGreenMean,
          cheekBlueMean: sample.cheekBlueMean,
          whiteReferenceLuminance: _whiteCardLuminance,
          faceDetected: sample.faceDetected,
        );
        setState(() {
          _latestFaceSample = adjustedSample;
          _syncAttitudeFromLiveTelemetry();
          if (_isScanningChromaticity) {
            _capturedScanSamples.add(adjustedSample);
          }
          if (_isRunningMetronome) {
            _capturedMetronomeSamples.add(adjustedSample);
            final elapsedMs = DateTime.now().millisecondsSinceEpoch;
            _metronomePhase =
                math.sin(2 * math.pi * 1.0 * (elapsedMs / 1000.0));
          }
        });
      },
      onError: (_) {},
    );
  }

  void _subscribeMotionStream() {
    _motionSub?.cancel();
    if (_isWidgetTestEnvironment) return;
    _motionSub = ref.read(motionSensorPortProvider).watchMotionSamples().listen(
      (sample) {
        if (!mounted) return;
        setState(() {
          _latestMotionSample = sample;
          _syncAttitudeFromLiveTelemetry();
        });
      },
      onError: (_) {},
    );
  }

  /// Fusiona la telemetría inercial (`sensors_plus`), la pose cefálica medida por
  /// la cámara frontal y el empuje de los propulsores vernier táctiles en la
  /// actitud real de la nave (Roll, Pitch, Yaw).
  void _syncAttitudeFromLiveTelemetry() {
    final motion = _latestMotionSample;
    final face = _latestFaceSample;

    final inertialRoll = motion?.rollDeg ?? 0.0;
    final inertialPitch = motion?.pitchDeg ?? 0.0;
    final inertialYaw = motion?.yawDeg ?? 0.0;

    final headRoll = face?.headRollDeg ?? 0.0;
    final headPitch = face?.headPitchDeg ?? 0.0;
    final headYaw = face?.headYawDeg ?? 0.0;

    _userRollDeg =
        (inertialRoll + headRoll + _vernierRollDeg).clamp(-45.0, 45.0);
    _userPitchDeg = (inertialPitch + headPitch * 0.5 + _vernierPitchDeg)
        .clamp(-45.0, 45.0);
    _userYawDeg =
        (inertialYaw + headYaw + _vernierYawDeg).clamp(-45.0, 45.0);
  }

  @override
  void dispose() {
    _faceSub?.cancel();
    _motionSub?.cancel();
    _chromaticityTimer?.cancel();
    _metronomeTimer?.cancel();
    _horizonLoopTimer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  // --- Acciones de Pestaña 1 ---

  void _startChromaticityScan({required int durationSeconds}) {
    _chromaticityTimer?.cancel();
    _subscribeFaceStream(continuous: true);
    setState(() {
      _isScanningChromaticity = true;
      _scanRemainingSec = durationSeconds;
      _capturedScanSamples.clear();
    });

    _chromaticityTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_scanRemainingSec <= 1) {
        timer.cancel();
        _finishChromaticityScan();
      } else {
        setState(() {
          _scanRemainingSec--;
        });
      }
    });
  }

  void _abortChromaticityScan() {
    _chromaticityTimer?.cancel();
    _subscribeFaceStream(continuous: _isRunningMetronome);
    setState(() {
      _isScanningChromaticity = false;
      _scanRemainingSec = 15;
      _capturedScanSamples.clear();
    });
  }

  void _finishChromaticityScan() {
    _subscribeFaceStream(continuous: _isRunningMetronome);
    final cal = ref.read(deviceCalibrationProvider);
    final result = FacialGreennessAnalyzer.analyze(
      samples: _capturedScanSamples,
      baselineGreenRedRatio: cal.baselineGreenRedRatio,
    );
    setState(() {
      _isScanningChromaticity = false;
      _greennessResult = result;
    });
  }

  void _startMetronomeTest() {
    _metronomeTimer?.cancel();
    _subscribeFaceStream(continuous: true);
    setState(() {
      _isRunningMetronome = true;
      _metronomeRemainingSec = 10;
      _capturedMetronomeSamples.clear();
      _optotypeHits = 0;
      _optotypeTotal = 0;
      _activeOptotype = _optotypes[0];
    });

    _metronomeTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_metronomeRemainingSec <= 1) {
        timer.cancel();
        _finishMetronomeTest();
      } else {
        setState(() {
          _metronomeRemainingSec--;
          _activeOptotype =
              _optotypes[_metronomeRemainingSec % _optotypes.length];
        });
      }
    });
  }

  void _onOptotypeSelected(String letter) {
    if (!_isRunningMetronome) return;
    setState(() {
      _optotypeTotal++;
      if (letter == _activeOptotype) {
        _optotypeHits++;
      }
      _activeOptotype =
          _optotypes[(_optotypeTotal + 2) % _optotypes.length];
    });
  }

  void _finishMetronomeTest() {
    _subscribeFaceStream(continuous: _isScanningChromaticity);
    final accuracy =
        _optotypeTotal > 0 ? (_optotypeHits / _optotypeTotal) : 1.0;
    final result = GazeStabilityAnalyzer.analyze(
      samples: _capturedMetronomeSamples,
      optotypeAccuracy: accuracy,
    );
    setState(() {
      _isRunningMetronome = false;
      _gazeResult = result;
    });
  }

  // --- Acciones de Pestaña 2 ("Zero-G Horizon") ---

  void _startHorizonGame({required int durationSeconds}) {
    _horizonLoopTimer?.cancel();
    setState(() {
      _isHorizonRunning = true;
      _horizonRemainingSec = durationSeconds;
      _horizonElapsedSec = 0.0;
      _rollErrors.clear();
      _pitchErrors.clear();
      _yawErrors.clear();
    });

    const tickMs = 50;
    _horizonLoopTimer =
        Timer.periodic(const Duration(milliseconds: tickMs), (timer) {
      if (!mounted) return;
      setState(() {
        _horizonElapsedSec += tickMs / 1000.0;
        final remaining = (durationSeconds - _horizonElapsedSec.floor())
            .clamp(0, durationSeconds);
        _horizonRemainingSec = remaining;

        // Trayectoria orbital 3D del anillo de acoplamiento
        _targetRollDeg = 22.0 * math.sin(0.55 * _horizonElapsedSec);
        _targetPitchDeg = 16.0 * math.cos(0.42 * _horizonElapsedSec);
        _targetYawDeg = 20.0 * math.sin(0.35 * _horizonElapsedSec + 0.8);

        // La actitud proviene exclusivamente de telemetría real + vernier táctil.
        _syncAttitudeFromLiveTelemetry();

        _rollErrors.add((_targetRollDeg - _userRollDeg).abs());
        _pitchErrors.add((_targetPitchDeg - _userPitchDeg).abs());
        _yawErrors.add((_targetYawDeg - _userYawDeg).abs());

        if (_horizonElapsedSec >= durationSeconds) {
          timer.cancel();
          _finishHorizonGame(durationSeconds: durationSeconds);
        }
      });
    });
  }

  void _finishHorizonGame({required int durationSeconds}) {
    final meanRoll = _rollErrors.isEmpty
        ? 3.0
        : _rollErrors.reduce((a, b) => a + b) / _rollErrors.length;
    final meanPitch = _pitchErrors.isEmpty
        ? 3.0
        : _pitchErrors.reduce((a, b) => a + b) / _pitchErrors.length;
    final meanYaw = _yawErrors.isEmpty
        ? 3.0
        : _yawErrors.reduce((a, b) => a + b) / _yawErrors.length;

    final result = ZeroGHorizonResult.fromAxisErrors(
      durationSeconds: durationSeconds,
      meanRollErrorDeg: meanRoll,
      meanPitchErrorDeg: meanPitch,
      meanYawErrorDeg: meanYaw,
    );
    setState(() {
      _isHorizonRunning = false;
      _horizonResult = result;
    });
  }

  void _applyVernier({
    double? roll,
    double? pitch,
    double? yaw,
  }) {
    setState(() {
      if (roll != null) _vernierRollDeg = roll.clamp(-45.0, 45.0);
      if (pitch != null) _vernierPitchDeg = pitch.clamp(-45.0, 45.0);
      if (yaw != null) _vernierYawDeg = yaw.clamp(-45.0, 45.0);
      _syncAttitudeFromLiveTelemetry();
    });
  }

  void _centerVernier() => _applyVernier(roll: 0.0, pitch: 0.0, yaw: 0.0);

  double get _liveHorizonAccuracy {
    final rms = math.sqrt(
      (math.pow(_targetRollDeg - _userRollDeg, 2) +
              math.pow(_targetPitchDeg - _userPitchDeg, 2) +
              math.pow(_targetYawDeg - _userYawDeg, 2)) /
          3.0,
    );
    return ((1.0 - (rms / 30.0)) * 100.0).clamp(0.0, 100.0);
  }

  // --- Evaluación Consolidada ---

  SmsComprehensiveAssessment _buildCurrentAssessment() {
    final cal = ref.read(deviceCalibrationProvider);
    final greenness = _greennessResult ??
        FacialGreennessAnalyzer.analyze(
          samples: _latestFaceSample != null ? [_latestFaceSample!] : const [],
          baselineGreenRedRatio: cal.baselineGreenRedRatio,
        );
    final gaze = _gazeResult ??
        GazeStabilityAnalyzer.analyze(
          samples: _latestFaceSample != null ? [_latestFaceSample!] : const [],
          optotypeAccuracy: 1.0,
        );
    final horizon = _horizonResult ??
        ZeroGHorizonResult.fromAxisErrors(
          durationSeconds: MedicalThresholds.zeroGHorizonDurationSeconds,
          meanRollErrorDeg: (_targetRollDeg - _userRollDeg).abs(),
          meanPitchErrorDeg: (_targetPitchDeg - _userPitchDeg).abs(),
          meanYawErrorDeg: (_targetYawDeg - _userYawDeg).abs(),
        );

    return SmsComprehensiveAssessment.evaluate(
      id: 'sms_${DateTime.now().millisecondsSinceEpoch}',
      graybiel: _graybiel,
      facialGreenness: greenness,
      gazeStability: gaze,
      zeroGHorizon: horizon,
    );
  }

  Future<void> _saveCurrentAssessment() async {
    final assessment = _buildCurrentAssessment();
    await ref.read(smsAssessmentsProvider.notifier).recordAssessment(assessment);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: SpaceTheme.card,
        content: Text(
          'Dictamen SMS guardado en Hive y encolado para sincronización con Tierra (${HiveBootstrap.pendingSyncCount()} pendientes).',
          style: const TextStyle(color: Colors.white),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final content = Column(
      children: [
        _buildTelemetryStatusHeader(),
        Container(
          color: SpaceTheme.surface,
          child: TabBar(
            controller: _tabController,
            indicatorColor: SpaceTheme.cyan,
            labelColor: SpaceTheme.cyan,
            unselectedLabelColor: Colors.white70,
            tabs: const [
              Tab(
                icon: Icon(Icons.face_retouching_natural),
                text: '1. Escáner Δ(G/R) & 1 Hz',
              ),
              Tab(
                icon: Icon(Icons.threed_rotation),
                text: '2. Zero-G Horizon (45s)',
              ),
              Tab(
                icon: Icon(Icons.health_and_safety),
                text: '3. Dictamen EVA & Cola',
              ),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildTab1ScannerAndGraybiel(),
              _buildTab2ZeroGHorizon(),
              _buildTab3ClinicalVerdict(),
            ],
          ),
        ),
      ],
    );

    if (widget.embedded) {
      return content;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Módulo SMS & Habituación Sensoriomotora (0g)'),
      ),
      body: content,
    );
  }

  /// Franja de estado de los canales clínicos activos del módulo.
  Widget _buildTelemetryStatusHeader() {
    final astronaut = ref.watch(selectedAstronautProvider);
    final opticalOnline = _latestFaceSample != null;
    final inertialOnline = _latestMotionSample != null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(
        color: SpaceTheme.card,
        border: Border(bottom: BorderSide(color: Colors.white12)),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        alignment: WrapAlignment.spaceBetween,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.badge_outlined, color: SpaceTheme.cyan, size: 18),
              const SizedBox(width: 6),
              Text(
                'Tripulante activo: ${astronaut.name} [${astronaut.callsign}]',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ],
          ),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _buildChannelBadge(
                icon: Icons.camera_front,
                label: 'Cámara Frontal RGB/IPD',
                online: opticalOnline,
              ),
              _buildChannelBadge(
                icon: Icons.screen_rotation_alt,
                label: 'Giroscopio 3-Ejes',
                online: inertialOnline,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChannelBadge({
    required IconData icon,
    required String label,
    required bool online,
  }) {
    final color = online ? SpaceTheme.green : SpaceTheme.warningYellow;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.7)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            '$label · ${online ? "ACTIVO" : "SINCRONIZANDO"}',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // PESTAÑA 1: VISOR ÓPTICO + TARJETA BLANCA + ESCÁNER Δ(G/R) + METRÓNOMO 1 HZ
  // ===========================================================================
  Widget _buildTab1ScannerAndGraybiel() {
    final sample = _latestFaceSample;
    final cal = ref.watch(deviceCalibrationProvider);
    final liveRatio = sample?.normalizedGreenRedRatio ?? cal.baselineGreenRedRatio;
    final liveDelta = liveRatio - cal.baselineGreenRedRatio;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // 0. Visor clínico de cámara frontal en vivo con HUD biométrico
        _ClinicalOpticalViewport(
          title: 'VISOR ÓPTICO FRONTAL EN VIVO · ROI MEJILLAS/FRENTE · IPD',
          faceSample: sample,
          whiteReferenceLuminance: _whiteCardLuminance,
          vorPhase: _isRunningMetronome ? _metronomePhase : 0.0,
          statusNote: _isScanningChromaticity
              ? 'Escaneo espectral Δ(G/R) en curso · ${_scanRemainingSec}s restantes'
              : null,
        ),

        const SizedBox(height: 12),

        // 1. Tarjeta Blanca de Referencia en Pantalla (Iluminación Controlada D65)
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.wb_iridescent, color: SpaceTheme.cyan),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'TARJETA BLANCA DE REFERENCIA (WHITE REFERENCE CARD)',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: SpaceTheme.cyan,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _buildStepGuideBox(
                  stepLabel: 'PASO 1 · ESCANEO ESPECTRAL Δ(G/R) (15 s)',
                  instruction:
                      '1. Centra tu rostro en el visor superior · '
                      '2. Ajusta el brillo de referencia D65 · '
                      '3. Pulsa Iniciar Escaneo y mantén el rostro estable 15 s.',
                ),
                const SizedBox(height: 12),
                Container(
                  height: 68,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Color.lerp(
                      const Color(0xFF777777),
                      Colors.white,
                      _whiteCardLuminance,
                    ),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: SpaceTheme.cyan, width: 2),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    'REFERENCIA BLANCA CALIBRADA • LUMINANCIA ${(_whiteCardLuminance * 100).toStringAsFixed(0)}%',
                    style: const TextStyle(
                      color: Colors.black87,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
                Row(
                  children: [
                    const Text('Brillo de Referencia:'),
                    Expanded(
                      child: Slider(
                        value: _whiteCardLuminance,
                        min: 0.5,
                        max: 1.0,
                        divisions: 10,
                        label: '${(_whiteCardLuminance * 100).toStringAsFixed(0)}%',
                        onChanged: (val) {
                          setState(() => _whiteCardLuminance = val);
                        },
                      ),
                    ),
                  ],
                ),
                const Divider(height: 20),
                Wrap(
                  spacing: 16,
                  runSpacing: 8,
                  children: [
                    _buildMetricChip(
                      'G/R Basal',
                      cal.baselineGreenRedRatio.toStringAsFixed(3),
                      Colors.white70,
                    ),
                    _buildMetricChip(
                      'G/R Normalizado Vivo',
                      liveRatio.toStringAsFixed(3),
                      SpaceTheme.cyan,
                    ),
                    _buildMetricChip(
                      'Δ(G/R) Instantáneo',
                      '${liveDelta >= 0 ? "+" : ""}${liveDelta.toStringAsFixed(3)}',
                      liveDelta >=
                              MedicalThresholds.facialGreennessWarningDeltaRatio
                          ? SpaceTheme.warningYellow
                          : SpaceTheme.green,
                    ),
                  ],
                ),
                if (_isScanningChromaticity) ...[
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: ((15 - _scanRemainingSec) / 15.0).clamp(0.0, 1.0),
                      minHeight: 8,
                      backgroundColor: SpaceTheme.surface,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        SpaceTheme.cyan,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _isScanningChromaticity
                          ? null
                          : () => _startChromaticityScan(durationSeconds: 15),
                      icon: const Icon(Icons.timer),
                      label: Text(
                        _isScanningChromaticity
                            ? 'Escaneo Espectral en curso (${_scanRemainingSec}s)'
                            : 'Iniciar Escaneo Espectral (15 s)',
                      ),
                    ),
                    if (_isScanningChromaticity)
                      OutlinedButton.icon(
                        onPressed: _abortChromaticityScan,
                        icon: const Icon(Icons.stop_circle_outlined),
                        label: const Text('Detener Escaneo'),
                      ),
                  ],
                ),
                if (_greennessResult != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: SpaceTheme.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _greennessResult!.status ==
                                ChromaticityStatus.nominal
                            ? SpaceTheme.green
                            : SpaceTheme.warningYellow,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Resultado Δ(G/R): ${_greennessResult!.statusLabel} '
                          '(Δ = +${_greennessResult!.deltaGreenRedRatio.toStringAsFixed(3)}, '
                          '${_greennessResult!.validSampleCount} muestras)',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _greennessResult!.scientificNote,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),

        const SizedBox(height: 12),

        // 2. Prueba Interactiva de Estabilidad de Mirada y DVA a 1.0 Hz
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.center_focus_strong, color: SpaceTheme.green),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'ESTABILIDAD OCULAR Y AGUDEZA VISUAL DINÁMICA (METRÓNOMO 1.0 Hz)',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _buildStepGuideBox(
                  stepLabel: 'PASO 2 · ESTABILIDAD OCULAR VOR / DVA (1.0 Hz · 10 s)',
                  instruction:
                      '1. Pulsa Iniciar Prueba · '
                      '2. Gira la cabeza izquierda-derecha a 1.0 Hz sin apartar la vista del punto verde (error ≤ 2.5°) · '
                      '3. Toca cada letra que aparece en el centro.',
                ),
                const SizedBox(height: 12),
                Container(
                  height: 96,
                  decoration: BoxDecoration(
                    color: SpaceTheme.background,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Indicador visual del metrónomo de 1 Hz
                      Align(
                        alignment: Alignment(_metronomePhase * 0.75, -0.65),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: SpaceTheme.cyan.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            '◄ Giro Cefálico 1.0 Hz ►',
                            style: TextStyle(
                              fontSize: 11,
                              color: SpaceTheme.cyan,
                            ),
                          ),
                        ),
                      ),
                      // Punto central fijo con optotipo dinámico
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: SpaceTheme.card,
                          border: Border.all(color: SpaceTheme.green, width: 2.5),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          _activeOptotype,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: SpaceTheme.green,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 16,
                  runSpacing: 8,
                  children: [
                    _buildMetricChip(
                      'Guiñada Cefálica (Yaw)',
                      '${(sample?.headYawDeg ?? 0.0).toStringAsFixed(1)}°',
                      SpaceTheme.cyan,
                    ),
                    _buildMetricChip(
                      'Desviación de Mirada',
                      '${(sample?.gazeOffsetDeg ?? 0.0).toStringAsFixed(2)}°',
                      (sample?.gazeOffsetDeg ?? 0.0) <= 2.5
                          ? SpaceTheme.green
                          : SpaceTheme.dangerRed,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Selecciona la letra que ves en el centro:',
                      style: TextStyle(fontSize: 12, color: Colors.white70),
                    ),
                    if (_isRunningMetronome || _optotypeTotal > 0)
                      Text(
                        'Aciertos: $_optotypeHits/$_optotypeTotal',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: SpaceTheme.cyan,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _optotypes.map((letter) {
                    return ActionChip(
                      label: Text('Optotipo $letter'),
                      onPressed: _isRunningMetronome
                          ? () => _onOptotypeSelected(letter)
                          : null,
                    );
                  }).toList(),
                ),
                if (_isRunningMetronome) ...[
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: ((10 - _metronomeRemainingSec) / 10.0)
                          .clamp(0.0, 1.0),
                      minHeight: 8,
                      backgroundColor: SpaceTheme.surface,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        SpaceTheme.green,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  onPressed: _isRunningMetronome ? null : _startMetronomeTest,
                  icon: const Icon(Icons.play_circle_outline),
                  label: Text(
                    _isRunningMetronome
                        ? 'Evaluando Fijación 1.0 Hz... (${_metronomeRemainingSec}s)'
                        : 'Iniciar Prueba de Estabilidad Ocular 1.0 Hz (10 s)',
                  ),
                ),
                if (_gazeResult != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    'Retención de fijación: ${(_gazeResult!.fixationRetentionRatio * 100).toStringAsFixed(0)}% • '
                    'Frecuencia: ${_gazeResult!.estimatedOscillationHz.toStringAsFixed(2)} Hz • '
                    'Puntaje DVA Compuesto: ${(_gazeResult!.compositeScore * 100).toStringAsFixed(0)}%',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _gazeResult!.isStable
                          ? SpaceTheme.green
                          : SpaceTheme.warningYellow,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),

        const SizedBox(height: 12),

        // 3. Registro Clínico de Síntomas Vestibulares (Escala de Graybiel 1968)
        Card(
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
                        'REGISTRO CLÍNICO DE SÍNTOMAS VESTIBULARES (ESCALA DE GRAYBIEL 1968)',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    Chip(
                      backgroundColor: _graybiel.triggersEvaRestriction
                          ? SpaceTheme.dangerRed.withValues(alpha: 0.25)
                          : SpaceTheme.green.withValues(alpha: 0.2),
                      label: Text(
                        'Puntaje: ${_graybiel.totalScore} pts',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _graybiel.triggersEvaRestriction
                              ? SpaceTheme.dangerRed
                              : SpaceTheme.green,
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  _graybiel.categoryLabel,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 6),
                _buildStepGuideBox(
                  stepLabel: 'PASO 3 · AUTOEVALUACIÓN VESTIBULAR (UMBRAL EVA ≥ 5 PTS)',
                  instruction:
                      'Registra tus síntomas actuales según la escala de Graybiel (1968). '
                      'La telemetría óptica Δ(G/R), fijación 1 Hz e índice 3D complementan el dictamen EVA.',
                ),
                const SizedBox(height: 12),
                _buildSymptomSlider(
                  label: 'Conciencia / Malestar Epigástrico (0, 1, 2 pts)',
                  value: _graybiel.epigastricLevel,
                  max: 2,
                  points: _graybiel.epigastricPoints,
                  onChanged: (v) => setState(
                    () => _graybiel = _graybiel.copyWith(epigastricLevel: v),
                  ),
                ),
                _buildSymptomSlider(
                  label: 'Síndrome de Náusea (0, 4, 8, 16 pts)',
                  value: _graybiel.nauseaLevel,
                  max: 3,
                  points: _graybiel.nauseaPoints,
                  onChanged: (v) => setState(
                    () => _graybiel = _graybiel.copyWith(nauseaLevel: v),
                  ),
                ),
                _buildSymptomSlider(
                  label: 'Sudoración Fría (0, 1, 2, 4, 8 pts)',
                  value: _graybiel.coldSweatingLevel,
                  max: 4,
                  points: _graybiel.coldSweatingPoints,
                  onChanged: (v) => setState(
                    () => _graybiel = _graybiel.copyWith(coldSweatingLevel: v),
                  ),
                ),
                _buildSymptomSlider(
                  label: 'Palidez / Rubor Facial (0, 1, 2, 4, 8 pts)',
                  value: _graybiel.pallorLevel,
                  max: 4,
                  points: _graybiel.pallorPoints,
                  onChanged: (v) => setState(
                    () => _graybiel = _graybiel.copyWith(pallorLevel: v),
                  ),
                ),
                _buildSymptomSlider(
                  label: 'Cefalea (0, 1 pt)',
                  value: _graybiel.headacheLevel,
                  max: 1,
                  points: _graybiel.headachePoints,
                  onChanged: (v) => setState(
                    () => _graybiel = _graybiel.copyWith(headacheLevel: v),
                  ),
                ),
                _buildSymptomSlider(
                  label: 'Somnolencia (0, 1, 2, 4 pts)',
                  value: _graybiel.drowsinessLevel,
                  max: 3,
                  points: _graybiel.drowsinessPoints,
                  onChanged: (v) => setState(
                    () => _graybiel = _graybiel.copyWith(drowsinessLevel: v),
                  ),
                ),
                _buildSymptomSlider(
                  label: 'Vértigo / Desorientación Espacial (0, 1, 2, 4 pts)',
                  value: _graybiel.vertigoLevel,
                  max: 3,
                  points: _graybiel.vertigoPoints,
                  onChanged: (v) => setState(
                    () => _graybiel = _graybiel.copyWith(vertigoLevel: v),
                  ),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: SpaceTheme.cyan,
                      foregroundColor: Colors.black,
                    ),
                    onPressed: () => _tabController.animateTo(1),
                    icon: const Icon(Icons.arrow_forward),
                    label: const Text('Continuar a Zero-G Horizon (Paso 2)'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSymptomSlider({
    required String label,
    required int value,
    required int max,
    required int points,
    required ValueChanged<int> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Text(
              '$label: +$points pts',
              style: const TextStyle(fontSize: 13),
            ),
          ),
          Expanded(
            flex: 3,
            child: Slider(
              value: value.toDouble(),
              min: 0,
              max: max.toDouble(),
              divisions: max,
              label: 'Nivel $value ($points pts)',
              onChanged: (val) => onChanged(val.round()),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // PESTAÑA 2: "ZERO-G HORIZON" (HABITUACIÓN SENSORIOMOTORA 3D - 45 s)
  // ===========================================================================
  Widget _buildTab2ZeroGHorizon() {
    final liveAccuracy = _liveHorizonAccuracy;
    final motion = _latestMotionSample;
    final face = _latestFaceSample;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.rocket_launch, color: SpaceTheme.cyan),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'ZERO-G HORIZON: HABITUACIÓN SENSORIOMOTORA 3D (45 s)',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _buildStepGuideBox(
                  stepLabel: 'PASO 4 · ACOPLAMIENTO 3-EJES (45 s · OBJETIVO ≥ 70%)',
                  instruction:
                      '1. Pulsa Iniciar Sesión 45 s · '
                      '2. Alinea la retícula cian con el anillo objetivo usando el giroscopio/cabeza o arrastrando sobre el visor · '
                      '3. Ajusta actitud fina con los propulsores RCS.',
                ),
                const SizedBox(height: 12),
                // Visor 3D interactivo con joystick de propulsores vernier
                GestureDetector(
                  onPanUpdate: (details) {
                    _applyVernier(
                      yaw: _vernierYawDeg + details.delta.dx * 0.25,
                      pitch: _vernierPitchDeg + details.delta.dy * 0.25,
                    );
                  },
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      height: 250,
                      width: double.infinity,
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: CustomPaint(
                              painter: ZeroGHorizonPainter(
                                targetRollDeg: _targetRollDeg,
                                targetPitchDeg: _targetPitchDeg,
                                targetYawDeg: _targetYawDeg,
                                userRollDeg: _userRollDeg,
                                userPitchDeg: _userPitchDeg,
                                userYawDeg: _userYawDeg,
                                starfieldPhaseRad: _horizonElapsedSec * 0.65,
                                alignmentAccuracyPercent: liveAccuracy,
                              ),
                            ),
                          ),
                          Positioned(
                            top: 10,
                            left: 12,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Tiempo: ${_horizonRemainingSec}s • Precisión 3D: ${liveAccuracy.toStringAsFixed(1)}%',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: liveAccuracy >=
                                          MedicalThresholds.minZeroGHorizonPassScore
                                      ? SpaceTheme.green
                                      : SpaceTheme.warningYellow,
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 10,
                            left: 12,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'Arrastra sobre el visor para comandos de actitud',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  color: Colors.white70,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Telemetría de actitud real de la nave
                const Text(
                  'TELEMETRÍA DE ACTITUD DE LA NAVE (INSTRUMENTACIÓN DE CABINA)',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    color: SpaceTheme.cyan,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    _buildMetricChip(
                      'Roll',
                      '${_userRollDeg.toStringAsFixed(1)}°',
                      SpaceTheme.cyan,
                    ),
                    _buildMetricChip(
                      'Pitch',
                      '${_userPitchDeg.toStringAsFixed(1)}°',
                      SpaceTheme.cyan,
                    ),
                    _buildMetricChip(
                      'Yaw',
                      '${_userYawDeg.toStringAsFixed(1)}°',
                      SpaceTheme.cyan,
                    ),
                    _buildMetricChip(
                      'Angular Rate',
                      '${(motion?.yawRateDegPerSec ?? 0.0).toStringAsFixed(2)} °/s',
                      SpaceTheme.green,
                    ),
                    _buildMetricChip(
                      'Pose Cefálica',
                      'R ${(face?.headRollDeg ?? 0.0).toStringAsFixed(0)}° · '
                          'P ${(face?.headPitchDeg ?? 0.0).toStringAsFixed(0)}° · '
                          'Y ${(face?.headYawDeg ?? 0.0).toStringAsFixed(0)}°',
                      Colors.white70,
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Propulsores vernier de actitud (RCS)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'PROPULSORES VERNIER DE ACTITUD (RCS)',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: SpaceTheme.cyan,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _centerVernier,
                      icon: const Icon(Icons.center_focus_weak, size: 16),
                      label: const Text(
                        'Centrar Vernier',
                        style: TextStyle(fontSize: 11),
                      ),
                    ),
                  ],
                ),
                _buildVernierAxis(
                  label: 'Vernier Roll',
                  value: _vernierRollDeg,
                  onChanged: (v) => _applyVernier(roll: v),
                ),
                _buildVernierAxis(
                  label: 'Vernier Pitch',
                  value: _vernierPitchDeg,
                  onChanged: (v) => _applyVernier(pitch: v),
                ),
                _buildVernierAxis(
                  label: 'Vernier Yaw',
                  value: _vernierYawDeg,
                  onChanged: (v) => _applyVernier(yaw: v),
                ),
                if (_isHorizonRunning) ...[
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: (_horizonElapsedSec /
                              MedicalThresholds.zeroGHorizonDurationSeconds)
                          .clamp(0.0, 1.0),
                      minHeight: 8,
                      backgroundColor: SpaceTheme.surface,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        SpaceTheme.cyan,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _isHorizonRunning
                          ? null
                          : () => _startHorizonGame(
                                durationSeconds:
                                    MedicalThresholds.zeroGHorizonDurationSeconds,
                              ),
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Iniciar Sesión 45 s'),
                    ),
                    if (_isHorizonRunning)
                      OutlinedButton.icon(
                        onPressed: () {
                          _horizonLoopTimer?.cancel();
                          _finishHorizonGame(
                            durationSeconds:
                                MedicalThresholds.zeroGHorizonDurationSeconds,
                          );
                        },
                        icon: const Icon(Icons.stop_circle_outlined),
                        label: const Text('Finalizar Sesión'),
                      ),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: SpaceTheme.cyan,
                        foregroundColor: Colors.black,
                      ),
                      onPressed: () => _tabController.animateTo(2),
                      icon: const Icon(Icons.arrow_forward),
                      label: const Text('Ver Dictamen EVA (Paso 3)'),
                    ),
                  ],
                ),
                if (_horizonResult != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: SpaceTheme.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _horizonResult!.passed
                            ? SpaceTheme.green
                            : SpaceTheme.dangerRed,
                      ),
                    ),
                    child: Text(
                      'Resultado Zero-G Horizon (${_horizonResult!.durationSeconds} s): '
                      'Precisión ${_horizonResult!.alignmentAccuracyPercent.toStringAsFixed(1)}% • '
                      'Índice de Deterioro: ${_horizonResult!.taskImpairmentIndexPercent.toStringAsFixed(1)}% • '
                      'Estado: ${_horizonResult!.passed ? "APROBADO (≥70%)" : "DETERIORO SENSORIOMOTOR (<70%)"}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildVernierAxis({
    required String label,
    required double value,
    required ValueChanged<double> onChanged,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 104,
          child: Text(label, style: const TextStyle(fontSize: 12)),
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          tooltip: 'Reducir $label',
          onPressed: () => onChanged((value - 2.0).clamp(-45.0, 45.0)),
          icon: const Icon(Icons.remove_circle_outline, size: 18),
        ),
        Expanded(
          child: Text(
            '${value >= 0 ? "+" : ""}${value.toStringAsFixed(1)}°',
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
          tooltip: 'Aumentar $label',
          onPressed: () => onChanged((value + 2.0).clamp(-45.0, 45.0)),
          icon: const Icon(Icons.add_circle_outline, size: 18),
        ),
      ],
    );
  }

  // ===========================================================================
  // PESTAÑA 3: DICTAMEN CLÍNICO EVA & TELEMETRÍA OFFLINE
  // ===========================================================================
  Widget _buildTab3ClinicalVerdict() {
    final assessment = _buildCurrentAssessment();
    final history = ref.watch(smsAssessmentsProvider);

    final Color bannerColor;
    if (assessment.evaAdvisory.severityCode == 'RED') {
      bannerColor = SpaceTheme.dangerRed;
    } else if (assessment.evaAdvisory.severityCode == 'YELLOW') {
      bannerColor = SpaceTheme.warningYellow;
    } else {
      bannerColor = SpaceTheme.green;
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Banner de recomendación EVA GO / NO-GO
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: bannerColor.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: bannerColor, width: 2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    assessment.evaNoGoRecommended
                        ? Icons.dangerous
                        : Icons.verified_user,
                    color: bannerColor,
                    size: 28,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      assessment.evaAdvisory.headline,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: bannerColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                assessment.evaAdvisory.clinicalRationale,
                style: const TextStyle(fontSize: 13, color: Colors.white),
              ),
              const SizedBox(height: 12),
              const Text(
                'Directrices Operativas del Cirujano de Vuelo:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 6),
              ...assessment.evaAdvisory.immediateActions.map(
                (action) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('• ', style: TextStyle(color: SpaceTheme.cyan)),
                      Expanded(
                        child: Text(
                          action,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.white70,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // Resumen de los 4 pilares biomédicos
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'RESUMEN DE TELEMETRÍA VESTIBULAR Y AUTONÓMICA',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _buildMetricChip(
                      'Escala Graybiel (1968)',
                      '${assessment.graybiel.totalScore} pts (${assessment.graybiel.category.name})',
                      assessment.graybiel.triggersEvaRestriction
                          ? SpaceTheme.dangerRed
                          : SpaceTheme.green,
                    ),
                    _buildMetricChip(
                      'Cromaticidad Facial Δ(G/R)',
                      '+${assessment.facialGreenness.deltaGreenRedRatio.toStringAsFixed(3)}',
                      assessment.facialGreenness.status ==
                              ChromaticityStatus.nominal
                          ? SpaceTheme.green
                          : SpaceTheme.warningYellow,
                    ),
                    _buildMetricChip(
                      'Estabilidad Ocular 1 Hz',
                      '${(assessment.gazeStability.fixationRetentionRatio * 100).toStringAsFixed(0)}% retención',
                      assessment.gazeStability.isStable
                          ? SpaceTheme.green
                          : SpaceTheme.warningYellow,
                    ),
                    _buildMetricChip(
                      'Zero-G Horizon (3 Ejes)',
                      '${assessment.zeroGHorizon.alignmentAccuracyPercent.toStringAsFixed(1)}% precisión',
                      assessment.zeroGHorizon.passed
                          ? SpaceTheme.green
                          : SpaceTheme.dangerRed,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _saveCurrentAssessment,
                    icon: const Icon(Icons.cloud_upload_outlined),
                    label: const Text(
                      'Guardar Dictamen en Hive y Encolar para Sincronización con Tierra',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        if (history.isNotEmpty) ...[
          const SizedBox(height: 14),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'BITÁCORA LOCAL OFFLINE (${history.length} registros)',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...history.take(5).map((item) {
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        item.evaNoGoRecommended
                            ? Icons.block
                            : Icons.check_circle_outline,
                        color: item.evaNoGoRecommended
                            ? SpaceTheme.dangerRed
                            : SpaceTheme.green,
                      ),
                      title: Text(
                        'Graybiel: ${item.graybiel.totalScore} pts • Horizon: ${item.zeroGHorizon.alignmentAccuracyPercent.toStringAsFixed(1)}%',
                      ),
                      subtitle: Text(
                        item.evaNoGoRecommended
                            ? 'NO-GO EVA Recomendado'
                            : 'GO EVA Nominal',
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        ],
      ],
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

  Widget _buildMetricChip(String label, String value, Color accent) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: SpaceTheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: accent.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: Colors.white60),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: accent,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// VISOR CLÍNICO DE CÁMARA FRONTAL EN VIVO + HUD BIOMÉTRICO
// =============================================================================

/// Visor de la cámara frontal con superposición clínica de regiones de interés
/// (mejillas y frente), pupilas con calibres de distancia interpupilar, panel de
/// iluminación de referencia D65 y objetivo de fijación VOR a 1 Hz.
class _ClinicalOpticalViewport extends StatefulWidget {
  final String title;
  final FaceSample? faceSample;
  final double vorPhase;
  final double whiteReferenceLuminance;
  final String? statusNote;

  const _ClinicalOpticalViewport({
    required this.title,
    required this.faceSample,
    this.vorPhase = 0.0,
    this.whiteReferenceLuminance = 1.0,
    this.statusNote,
  });

  @override
  State<_ClinicalOpticalViewport> createState() =>
      _ClinicalOpticalViewportState();
}

class _ClinicalOpticalViewportState extends State<_ClinicalOpticalViewport> {
  CameraController? _controller;
  bool _initializing = true;
  String? _channelNote;

  @override
  void initState() {
    super.initState();
    if (_isWidgetTestEnvironment) {
      _initializing = false;
      _channelNote = 'Canal óptico en espera de hardware';
      return;
    }
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (!mounted) return;
        setState(() {
          _initializing = false;
          _channelNote = 'Sin cámara frontal detectada en este dispositivo';
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
        _controller = controller;
        _initializing = false;
        _channelNote = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _initializing = false;
        _channelNote = 'Canal óptico frontal no disponible';
      });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

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
    final controller = _controller;
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
                    widget.title,
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
                height: 240,
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
                                    _initializing
                                        ? Icons.hourglass_top
                                        : Icons.videocam_off_outlined,
                                    color: Colors.white30,
                                    size: 34,
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    _channelNote ??
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
                      painter: _ClinicalOpticalHudPainter(
                        sample: widget.faceSample,
                        showRoiPolygons: true,
                        showIpdCalipers: true,
                        showVorTarget: true,
                        vorPhase: widget.vorPhase,
                        whiteReferenceLuminance: widget.whiteReferenceLuminance,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (widget.statusNote != null) ...[
              const SizedBox(height: 8),
              Text(
                widget.statusNote!,
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

/// Pintor del HUD clínico sobre el visor de la cámara frontal.
class _ClinicalOpticalHudPainter extends CustomPainter {
  final FaceSample? sample;
  final bool showRoiPolygons;
  final bool showIpdCalipers;
  final bool showVorTarget;
  final double vorPhase;
  final double whiteReferenceLuminance;

  const _ClinicalOpticalHudPainter({
    required this.sample,
    required this.showRoiPolygons,
    required this.showIpdCalipers,
    required this.showVorTarget,
    required this.vorPhase,
    required this.whiteReferenceLuminance,
  });

  static const double _nominalFrameWidthPx = 640.0;

  @override
  void paint(Canvas canvas, Size size) {
    _paintFrameBrackets(canvas, size);
    if (showRoiPolygons) {
      _paintForeheadRoi(canvas, size);
      _paintCheekRois(canvas, size);
    }
    if (showIpdCalipers) {
      _paintIpdCalipers(canvas, size);
    }
    _paintGazeVector(canvas, size);
    _paintWhiteReferencePanel(canvas, size);
    if (showVorTarget) {
      _paintVorTarget(canvas, size);
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

  void _paintForeheadRoi(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width * 0.30, size.height * 0.10)
      ..lineTo(size.width * 0.70, size.height * 0.10)
      ..lineTo(size.width * 0.66, size.height * 0.26)
      ..lineTo(size.width * 0.34, size.height * 0.26)
      ..close();
    canvas.drawPath(
      path,
      Paint()
        ..color = SpaceTheme.cyan.withValues(alpha: 0.55)
        ..strokeWidth = 1.4
        ..style = PaintingStyle.stroke,
    );
    canvas.drawPath(
      path,
      Paint()..color = SpaceTheme.cyan.withValues(alpha: 0.08),
    );
    _drawLabel(
      canvas,
      Offset(size.width * 0.30, size.height * 0.10 - 13),
      'FOREHEAD ROI',
      SpaceTheme.cyan,
    );
  }

  void _paintCheekRois(Canvas canvas, Size size) {
    final left = Path()
      ..moveTo(size.width * 0.16, size.height * 0.56)
      ..lineTo(size.width * 0.38, size.height * 0.60)
      ..lineTo(size.width * 0.36, size.height * 0.82)
      ..lineTo(size.width * 0.16, size.height * 0.78)
      ..close();
    final right = Path()
      ..moveTo(size.width * 0.84, size.height * 0.56)
      ..lineTo(size.width * 0.62, size.height * 0.60)
      ..lineTo(size.width * 0.64, size.height * 0.82)
      ..lineTo(size.width * 0.84, size.height * 0.78)
      ..close();
    final stroke = Paint()
      ..color = SpaceTheme.green.withValues(alpha: 0.60)
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;
    final fill = Paint()..color = SpaceTheme.green.withValues(alpha: 0.08);
    for (final p in [left, right]) {
      canvas.drawPath(p, fill);
      canvas.drawPath(p, stroke);
    }
    _drawLabel(
      canvas,
      Offset(size.width * 0.16, size.height * 0.56 - 13),
      'CHEEK ROI',
      SpaceTheme.green,
    );
  }

  void _paintIpdCalipers(Canvas canvas, Size size) {
    final ipdPx = sample?.ipdPixels ?? 0.0;
    final scale = size.width / _nominalFrameWidthPx;
    final halfSpan = ((ipdPx * scale) / 2).clamp(6.0, size.width * 0.40);
    final cy = size.height * 0.44;
    final left = Offset(size.width / 2 - halfSpan, cy);
    final right = Offset(size.width / 2 + halfSpan, cy);

    final paint = Paint()
      ..color = SpaceTheme.cyan
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke;

    canvas.drawLine(left, right, paint);
    canvas.drawLine(
      left + const Offset(0, -7),
      left + const Offset(0, 7),
      paint,
    );
    canvas.drawLine(
      right + const Offset(0, -7),
      right + const Offset(0, 7),
      paint,
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
      Offset(size.width / 2 - 46, cy + 10),
      'IPD ${ipdPx.toStringAsFixed(1)} px',
      SpaceTheme.cyan,
    );
  }

  void _paintGazeVector(Canvas canvas, Size size) {
    final gaze = sample?.gazeOffsetDeg ?? 0.0;
    final center = Offset(size.width / 2, size.height * 0.44);
    final maxDim = math.min(size.width, size.height);
    final radius = ((gaze / 10.0).clamp(0.0, 1.0)) * maxDim * 0.30;
    final onTarget = gaze <= 2.5;
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

  void _paintWhiteReferencePanel(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(10, size.height - 40, 62, 30);
    final lum = whiteReferenceLuminance.clamp(0.0, 1.0);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(5)),
      Paint()..color = Color.lerp(const Color(0xFF888888), Colors.white, lum)!,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(5)),
      Paint()
        ..color = SpaceTheme.cyan.withValues(alpha: 0.9)
        ..strokeWidth = 1.2
        ..style = PaintingStyle.stroke,
    );
    final tp = TextPainter(
      text: TextSpan(
        text: 'D65 ${(lum * 100).toStringAsFixed(0)}%',
        style: const TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: rect.width - 6);
    tp.paint(
      canvas,
      Offset(
        rect.left + (rect.width - tp.width) / 2,
        rect.top + (rect.height - tp.height) / 2,
      ),
    );
  }

  void _paintVorTarget(Canvas canvas, Size size) {
    final x = size.width / 2 + vorPhase.clamp(-1.0, 1.0) * size.width * 0.30;
    final center = Offset(x, size.height * 0.20);
    final paint = Paint()
      ..color = SpaceTheme.warningYellow.withValues(alpha: 0.9)
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke;
    canvas.drawCircle(center, 9, paint);
    canvas.drawCircle(center, 2.2, Paint()..color = SpaceTheme.warningYellow);
    _drawLabel(
      canvas,
      Offset(center.dx - 34, center.dy + 12),
      'VOR 1.0 Hz',
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
  bool shouldRepaint(covariant _ClinicalOpticalHudPainter oldDelegate) {
    return oldDelegate.sample != sample ||
        oldDelegate.showRoiPolygons != showRoiPolygons ||
        oldDelegate.showIpdCalipers != showIpdCalipers ||
        oldDelegate.showVorTarget != showVorTarget ||
        oldDelegate.vorPhase != vorPhase ||
        oldDelegate.whiteReferenceLuminance != whiteReferenceLuminance;
  }
}

/// `true` cuando el árbol de widgets se ejecuta bajo `flutter_test`.
bool get _isWidgetTestEnvironment =>
    WidgetsBinding.instance.runtimeType.toString().contains('Test');
