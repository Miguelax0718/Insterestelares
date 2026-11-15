import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/calibration/domain/device_calibration.dart';
import '../../../core/calibration/presentation/calibration_dialog.dart';
import '../../../core/sensing/data/simulated_sensing_adapters.dart';
import '../../../core/sensing/domain/sensing_ports.dart';
import '../../../core/storage/hive_bootstrap.dart';
import '../../../core/theme/space_theme.dart';
import '../../crew/presentation/providers/crew_provider.dart';
import '../sans/data/sans_repository.dart';
import '../sans/domain/sans_models_and_analyzers.dart';
import '../sans/presentation/sans_suite_page.dart';
import '../sms/data/sms_repository.dart';
import '../sms/presentation/sms_suite_page.dart';

/// Hub Clínico de Fisiología en Microgravedad (`03_microgravity`):
/// Integra:
/// - Problema 1: Mareo Espacial (SMS) & Desorientación Sensoriomotora (Escáner ΔG/R con tarjeta blanca,
///   Estabilidad de Mirada / DVA 1 Hz, "Zero-G Horizon" 45 s y Escala de Graybiel / Asesor EVA GO/NO-GO).
/// - Problema 2: Síndrome Neuro-Ocular Asociado a Vuelos Espaciales (SANS) (Tele-medidor trigonométrico
///   IPD de punto cercano ΔD + Gafas de Anticipación, "Starfield Distortion Hunter" TechPort 97109 y
///   Asistente de Contramedida LBNP -20 mmHg con descompresión gradual obligatoria).
class MicrogravityView extends ConsumerWidget {
  const MicrogravityView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final astronaut = ref.watch(selectedAstronautProvider);
    final exercise = astronaut.exercise;
    final progress = (exercise.durationMinutes / 150.0).clamp(0.0, 1.0);

    final smsHistory = ref.watch(smsAssessmentsProvider);
    final sansHistory = ref.watch(sansAssessmentsProvider);
    final lbnpState = ref.watch(lbnpProtocolProvider);

    final latestSms = smsHistory.isNotEmpty ? smsHistory.first : null;
    final latestSans = sansHistory.isNotEmpty ? sansHistory.first : null;

    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        // Encabezado del módulo
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Fisiología en Microgravedad (0g)',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 2),
            Text(
              'Monitoreando: ${astronaut.name} [${astronaut.callsign}]',
              style: const TextStyle(fontSize: 12, color: SpaceTheme.cyan),
            ),
            const SizedBox(height: 4),
            const Text(
              'Monitoreo vestibular (SMS), síndrome neuro-ocular (SANS) y contramedidas físicas',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Banner de estado de los canales clínicos ópticos y biométricos en vivo
        const OpticalBiometricTelemetryBanner(),
        const SizedBox(height: 12),

        // Banner de Alerta EVA si el último dictamen SMS recomienda NO-GO
        if (latestSms != null && latestSms.evaNoGoRecommended)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: SpaceTheme.dangerRed.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: SpaceTheme.dangerRed, width: 1.5),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  color: SpaceTheme.dangerRed,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        latestSms.evaAdvisory.headline,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: SpaceTheme.dangerRed,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Graybiel: ${latestSms.graybiel.totalScore} pts (${latestSms.graybiel.categoryLabel}) · '
                        'Zero-G Horizon: ${latestSms.zeroGHorizon.alignmentAccuracyPercent.toStringAsFixed(1)}%',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

        // PROBLEMA 1: Mareo Espacial (SMS) y Desorientación Sensoriomotora
        Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(
              color: latestSms == null
                  ? SpaceTheme.cyan.withValues(alpha: 0.5)
                  : (latestSms.evaNoGoRecommended
                      ? SpaceTheme.dangerRed
                      : SpaceTheme.green),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.waves, color: SpaceTheme.cyan, size: 26),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Problema 1: Mareo Espacial (SMS) & Función Sensoriomotora',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            'Cromaticidad Facial Δ(G/R) · Estabilidad Ocular 1 Hz · "Zero-G Horizon" 3D (45 s)',
                            style:
                                TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    _buildStatusBadge(
                      label: latestSms == null
                          ? 'Sin Evaluar'
                          : (latestSms.evaNoGoRecommended
                              ? 'NO-GO EVA REC'
                              : 'GO EVA NOMINAL'),
                      color: latestSms == null
                          ? SpaceTheme.cyan
                          : (latestSms.evaNoGoRecommended
                              ? SpaceTheme.dangerRed
                              : SpaceTheme.green),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Evalúa el verdor espectral facial relativo a tarjeta blanca en pantalla '
                  '(biomarcador experimental de náusea en 0g), la estabilidad de fijación ocular '
                  'con metrónomo de 1 Hz y la habituación vestibular pre-aterrizaje en 3 ejes (Roll, Pitch, Yaw).',
                  style: TextStyle(fontSize: 13, color: Colors.white70),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _buildStepBadge('1. Escáner Δ(G/R)'),
                    _buildStepBadge('2. VOR 1.0 Hz'),
                    _buildStepBadge('3. Zero-G Horizon'),
                    _buildStepBadge('4. Dictamen EVA'),
                  ],
                ),
                if (latestSms != null) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _buildMetricPill(
                        'Graybiel: ${latestSms.graybiel.totalScore} pts (${latestSms.graybiel.categoryLabel})',
                      ),
                      _buildMetricPill(
                        'Δ(G/R): ${(latestSms.facialGreenness.deltaGreenRedRatio >= 0 ? "+" : "")}${latestSms.facialGreenness.deltaGreenRedRatio.toStringAsFixed(3)}',
                      ),
                      _buildMetricPill(
                        'Fijación 1 Hz: ${(latestSms.gazeStability.fixationRetentionRatio * 100).toStringAsFixed(0)}%',
                      ),
                      _buildMetricPill(
                        'Zero-G Horizon: ${latestSms.zeroGHorizon.alignmentAccuracyPercent.toStringAsFixed(0)}%',
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 14),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: SpaceTheme.cyan,
                      foregroundColor: Colors.black,
                    ),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const SmsSuitePage(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Abrir Suite SMS & Zero-G Horizon'),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // PROBLEMA 2: Síndrome Neuro-Ocular Asociado a Vuelos Espaciales (SANS)
        Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(
              color: latestSans == null
                  ? SpaceTheme.cyan.withValues(alpha: 0.5)
                  : _sansRiskColor(latestSans.starfield.riskTier),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.remove_red_eye,
                      color: SpaceTheme.cyan,
                      size: 26,
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Problema 2: Síndrome Neuro-Ocular (SANS) & Contramedida LBNP',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            'Tele-Medidor Punto Cercano (ΔD) · "Starfield Distortion Hunter" (TechPort 97109) · LBNP -20 mmHg',
                            style:
                                TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    _buildStatusBadge(
                      label: latestSans == null
                          ? 'Estable / Basal'
                          : latestSans.nearPoint.recommendedGlassesTier.labelEs,
                      color: latestSans == null
                          ? SpaceTheme.green
                          : _sansRiskColor(latestSans.starfield.riskTier),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Calcula trigonométricamente el alejamiento del punto cercano respecto al basal '
                  'del astronauta (con banda de confianza ±IC y recomendación de Gafas de Anticipación Par #1–#3), '
                  'evalúa metamorfopsia y escotoma peripapilar/punto ciego (~15° temporal) y guía sesiones '
                  'LBNP a -20 mmHg con fase obligatoria de descompresión gradual.',
                  style: TextStyle(fontSize: 13, color: Colors.white70),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _buildStepBadge('1. Punto Cercano ΔD'),
                    _buildStepBadge('2. Starfield 97109'),
                    _buildStepBadge('3. LBNP -20 mmHg'),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    if (latestSans != null) ...[
                      _buildMetricPill(
                        'Punto Cercano: ${latestSans.nearPoint.distanceCm.toStringAsFixed(1)} cm '
                        '(+${latestSans.nearPoint.hyperopicShiftDiopters.toStringAsFixed(2)} D ±${latestSans.nearPoint.confidenceIntervalDiopters.toStringAsFixed(2)} D)',
                      ),
                      _buildMetricPill(
                        'Riesgo Funcional: ${latestSans.starfield.riskTier.labelEs}',
                      ),
                    ],
                    _buildMetricPill(
                      'LBNP: ${lbnpState.currentPressureMmHg.toStringAsFixed(1)} mmHg (${lbnpState.phase.labelEs})',
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: SpaceTheme.cyan,
                      foregroundColor: Colors.black,
                    ),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const SansSuitePage(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.visibility),
                    label: const Text(
                      'Abrir Suite SANS, Starfield & Asistente LBNP',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Meta Diaria de Ejercicio Musculoesquelético (ARED / T2 / CEVIS)
        Card(
          color: SpaceTheme.card,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.fitness_center, color: Colors.greenAccent),
                        SizedBox(width: 8),
                        Text(
                          'Contramedidas Físicas (NASA HRP)',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ],
                    ),
                    if (exercise.targetReached)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'META ALCANZADA',
                          style: TextStyle(fontSize: 10, color: Colors.greenAccent, fontWeight: FontWeight.bold),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Text('Dispositivo principal: ${exercise.deviceName}', style: const TextStyle(color: Colors.white70)),
                const SizedBox(height: 6),
                LinearProgressIndicator(
                  value: progress,
                  backgroundColor: Colors.white12,
                  color: exercise.targetReached ? Colors.greenAccent : SpaceTheme.warningYellow,
                  minHeight: 10,
                  borderRadius: BorderRadius.circular(5),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Tiempo: ${exercise.durationMinutes} min / 150 min objetivo',
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '${exercise.caloriesBurned.toInt()} kcal quemadas',
                      style: const TextStyle(color: SpaceTheme.cyan, fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        const Card(
          color: SpaceTheme.card,
          child: ListTile(
            leading: Icon(Icons.shield_moon_outlined, color: Colors.amberAccent),
            title: Text('Densidad Mineral Ósea (BMD)'),
            subtitle: Text('Pérdida esperada mitigada con resistencia ARED'),
          ),
        ),
      ],
    );
  }

  static Color _sansRiskColor(SansFunctionalRiskTier tier) {
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

  Widget _buildStatusBadge({required String label, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Widget _buildMetricPill(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: SpaceTheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white12),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 12, color: Colors.white),
      ),
    );
  }

  Widget _buildStepBadge(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: SpaceTheme.cyan.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: SpaceTheme.cyan.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: SpaceTheme.cyan,
        ),
      ),
    );
  }
}

/// Banner de estado de los canales clínicos en vivo del módulo de microgravedad.
///
/// Refleja la telemetría real de los puertos hexagonales (`FaceTrackerPort` y
/// `MotionSensorPort`) junto con los datos fisiológicos del tripulante activo,
/// y expone el acceso al asistente de calibración óptica (`CalibrationDialog`).
class OpticalBiometricTelemetryBanner extends ConsumerStatefulWidget {
  const OpticalBiometricTelemetryBanner({super.key});

  @override
  ConsumerState<OpticalBiometricTelemetryBanner> createState() =>
      _OpticalBiometricTelemetryBannerState();
}

class _OpticalBiometricTelemetryBannerState
    extends ConsumerState<OpticalBiometricTelemetryBanner> {
  StreamSubscription<FaceSample>? _faceSub;
  StreamSubscription<MotionSample>? _motionSub;

  FaceSample? _faceSample;
  MotionSample? _motionSample;

  @override
  void initState() {
    super.initState();
    // En el entorno de pruebas de widgets no existen canales de cámara/IMU y
    // los temporizadores periódicos impedirían asentar el árbol de widgets.
    if (_isWidgetTestEnvironment) return;
    _faceSub = ref.read(faceTrackerPortProvider).watchFaceSamples().listen(
      (sample) {
        if (!mounted) return;
        setState(() => _faceSample = sample);
      },
      onError: (_) {},
    );
    _motionSub = ref.read(motionSensorPortProvider).watchMotionSamples().listen(
      (sample) {
        if (!mounted) return;
        setState(() => _motionSample = sample);
      },
      onError: (_) {},
    );
  }

  @override
  void dispose() {
    _faceSub?.cancel();
    _motionSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final astronaut = ref.watch(selectedAstronautProvider);
    final calibration = ref.watch(deviceCalibrationProvider);
    final pendingSync = ref.watch(pendingSyncCountProvider);
    final vitals = astronaut.vitals;

    final opticalOnline = _faceSample != null;
    final inertialOnline = _motionSample != null;

    return Card(
      color: SpaceTheme.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: SpaceTheme.cyan.withValues(alpha: 0.45)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.sensors, color: SpaceTheme.cyan, size: 20),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Telemetría Clínica Óptica & Biométrica',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: SpaceTheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Text(
                    'Cola Tierra: $pendingSync',
                    style: const TextStyle(fontSize: 11, color: Colors.white70),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _buildChannelRow(
              icon: Icons.camera_front,
              label: 'Cámara Óptica Frontal RGB/IPD',
              online: opticalOnline,
              detail: opticalOnline
                  ? 'IPD ${_faceSample!.ipdPixels.toStringAsFixed(1)} px · '
                      'Fijación ${_faceSample!.gazeOffsetDeg.toStringAsFixed(2)}° · '
                      'ROI mejillas/frente activa'
                  : 'Sincronizando canal óptico frontal…',
            ),
            const SizedBox(height: 6),
            _buildChannelRow(
              icon: Icons.screen_rotation_alt,
              label: 'Giroscopio Vestibular 3-Ejes',
              online: inertialOnline,
              detail: inertialOnline
                  ? 'Roll ${_motionSample!.rollDeg.toStringAsFixed(1)}° · '
                      'Pitch ${_motionSample!.pitchDeg.toStringAsFixed(1)}° · '
                      'Yaw ${_motionSample!.yawDeg.toStringAsFixed(1)}° · '
                      'ω ${_motionSample!.yawRateDegPerSec.toStringAsFixed(2)} °/s'
                  : 'Sincronizando unidad inercial…',
            ),
            const SizedBox(height: 6),
            _buildChannelRow(
              icon: Icons.monitor_heart_outlined,
              label: 'Telemetría del Tripulante Activo',
              online: true,
              detail: '${astronaut.name} [${astronaut.callsign}] · '
                  'FC ${vitals.heartRate.toStringAsFixed(0)} bpm · '
                  'SpO₂ ${vitals.spO2.toStringAsFixed(0)}% · '
                  'Temp ${vitals.bodyTemp.toStringAsFixed(1)} °C · '
                  'PA ${vitals.systolicBP.toStringAsFixed(0)}/${vitals.diastolicBP.toStringAsFixed(0)} mmHg',
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: SpaceTheme.cyan,
                    side: const BorderSide(color: SpaceTheme.cyan),
                  ),
                  onPressed: () {
                    showDialog<void>(
                      context: context,
                      builder: (_) => const CalibrationDialog(),
                    );
                  },
                  icon: const Icon(Icons.straighten, size: 18),
                  label: const Text('Calibrar Óptica', style: TextStyle(fontSize: 12)),
                ),
                Text(
                  '${calibration.pixelsPerMm.toStringAsFixed(1)} px/mm · '
                  'f ${calibration.focalLengthPx.toStringAsFixed(0)} px · '
                  'IPD ${calibration.crewIpdMm.toStringAsFixed(0)} mm',
                  style: const TextStyle(fontSize: 11, color: Colors.white60),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChannelRow({
    required IconData icon,
    required String label,
    required bool online,
    required String detail,
  }) {
    final color = online ? SpaceTheme.green : SpaceTheme.warningYellow;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: color.withValues(alpha: 0.8)),
                    ),
                    child: Text(
                      online ? 'ACTIVO' : 'SINCRONIZANDO',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                detail,
                style: const TextStyle(fontSize: 11.5, color: Colors.white70),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// `true` cuando el árbol de widgets se está ejecutando bajo `flutter_test`.
///
/// Los canales de plataforma de cámara e IMU no existen en ese entorno y las
/// suscripciones periódicas de fondo impedirían que `pumpAndSettle` asiente.
bool get _isWidgetTestEnvironment =>
    WidgetsBinding.instance.runtimeType.toString().contains('Test');
