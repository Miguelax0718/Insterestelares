import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:astramed/features/01_general_health/domain/scientific_criteria_engine.dart';
import 'package:astramed/features/01_general_health/domain/telemetry_view_contracts.dart';
import 'package:astramed/features/crew/presentation/providers/crew_provider.dart';
import 'package:astramed/features/telemetry/models/telemetry_machine.dart';
import 'package:astramed/features/telemetry/presentation/providers/telemetry_provider.dart';

/// Mapea el `activityState` de telemetría hacia [ActivityContext] del motor científico.
ActivityContext mapActivityStateToContext(String activityState) {
  switch (activityState) {
    case 'sleep':
      return ActivityContext.sleep;
    case 'resting':
      return ActivityContext.rest;
    case 'exercise':
    case 'post_eva':
    case 'active_duty':
      return ActivityContext.physicalActivity;
    default:
      return ActivityContext.unknown;
  }
}

/// Extrae el porcentaje numérico de cadenas como `'optimal (98%)'` o `'good (89%)'`.
double? parseSignalQualityPercent(String signalQuality) {
  final match = RegExp(r'(\d+(?:\.\d+)?)\s*%').firstMatch(signalQuality);
  if (match == null) return null;
  return double.tryParse(match.group(1)!);
}

/// Entorno operacional espacial seleccionado activamente en el panel de salud.
final selectedEnvironmentProvider =
    StateProvider<SpaceOperationalEnvironment>(
  (ref) => SpaceOperationalEnvironment.spaceStation,
);

/// Notificador de bitácora clínica persistente para cuestionarios y revisiones de misión.
class ClinicalMissionLogsNotifier
    extends StateNotifier<List<ClinicalMissionLogEntry>> {
  ClinicalMissionLogsNotifier() : super(_initialLogs());

  static List<ClinicalMissionLogEntry> _initialLogs() {
    final now = DateTime.now();
    return [
      ClinicalMissionLogEntry(
        id: 'LOG-D17-SANS',
        astronautId: 'AST-01',
        timestamp: now.subtract(const Duration(hours: 14)),
        missionDay: 17,
        environment: SpaceOperationalEnvironment.spaceStation,
        category: 'Control Periódico Neuro-Ocular',
        title: 'Descarte SANS (ToF + Optotipos)',
        summary:
            'Distancia de enfoque estable (+0.15 D vs basal). Sin escotomas ni cefalea frontal.',
        answers: const {
          'Desplazamiento hiperópico ToF': 'Sin cambio (+0.15 D)',
          'Cefalea o presión retroocular': 'No refiere',
        },
        badgeEarned: 'Visión de Águila Espacial',
        xpAwarded: 40,
      ),
      ClinicalMissionLogEntry(
        id: 'LOG-D15-EVA',
        astronautId: 'AST-03',
        timestamp: now.subtract(const Duration(days: 2, hours: 3)),
        missionDay: 15,
        environment: SpaceOperationalEnvironment.rover,
        category: 'Triaje Post-EVA (Ada)',
        title: 'Revisión térmica e hídrica Post-EVA',
        summary:
            'Ligera fatiga térmica en LCVG tras desplazamiento en Rover; hidratación repuesta con electrolitos.',
        answers: const {
          'Síntoma predominante': 'Fatiga térmica moderada (EVA)',
          'Escala dolor / mareo (1-10)': '2 / 10',
          'Exposición a polvo / gases': 'Sin escape de CH₄ ni regolito en traje',
        },
        badgeEarned: 'Equilibrio Metabólico Perfecto',
        xpAwarded: 50,
      ),
      ClinicalMissionLogEntry(
        id: 'LOG-D12-ECLSS',
        astronautId: 'AST-02',
        timestamp: now.subtract(const Duration(days: 5)),
        missionDay: 12,
        environment: SpaceOperationalEnvironment.spaceStation,
        category: 'Cuestionario Clínico',
        title: 'Chequeo Autonómico y Sueño (ISS)',
        summary:
            'POMS estable; 7.2 h de descanso por actigrafía tras ajuste de iluminación circadiana.',
        answers: const {
          'Calidad de descanso nocturno': 'Reparador (eficiencia 91%)',
          'Vigilancia CO₂ en litera': 'Nominal (<2.5 mmHg)',
        },
        badgeEarned: 'Vigilancia Nominal',
        xpAwarded: 35,
      ),
    ];
  }

  void addEntry(ClinicalMissionLogEntry entry) {
    state = [entry, ...state];
  }
}

final clinicalMissionLogsProvider = StateNotifierProvider<
    ClinicalMissionLogsNotifier, List<ClinicalMissionLogEntry>>(
  (ref) => ClinicalMissionLogsNotifier(),
);

enum _VitalHistoryMetric {
  heartRate,
  respiratoryRate,
  spO2,
  systolicBP,
  diastolicBP,
  capillaryRefill,
  bodyTemp,
  bloodGlucose,
  hydration,
  hrv,
}

class _MissionCheckpointSpec {
  final int day;
  final int hourOffset;
  final SpaceOperationalEnvironment env;
  final ActivityContext context;
  final String hardware;
  final double qualityPercent;
  final String note;
  final double hrOffset;
  final double rrOffset;
  final double spo2Offset;
  final double sbpOffset;
  final double dbpOffset;
  final double crtOffset;
  final double tempOffset;
  final double gluOffset;
  final double hydOffset;
  final double hrvOffset;

  const _MissionCheckpointSpec({
    required this.day,
    required this.hourOffset,
    required this.env,
    required this.context,
    required this.hardware,
    required this.qualityPercent,
    required this.note,
    this.hrOffset = 0,
    this.rrOffset = 0,
    this.spo2Offset = 0,
    this.sbpOffset = 0,
    this.dbpOffset = 0,
    this.crtOffset = 0,
    this.tempOffset = 0,
    this.gluOffset = 0,
    this.hydOffset = 0,
    this.hrvOffset = 0,
  });
}

const List<_MissionCheckpointSpec> _kMissionCheckpoints = [
  _MissionCheckpointSpec(
    day: 1,
    hourOffset: 8,
    env: SpaceOperationalEnvironment.spacecraft,
    context: ActivityContext.rest,
    hardware: 'Bio-Monitor CSA (ECG/PPG)',
    qualityPercent: 94,
    note:
        'D1 • Nave en tránsito orbital: +3.4 lpm iniciales por redistribución hídrica cefálica (CARDIOBREATH).',
    hrOffset: 6.0,
    rrOffset: 1.5,
    spo2Offset: -0.4,
    sbpOffset: 6.0,
    dbpOffset: 4.0,
    crtOffset: 0.1,
    tempOffset: 0.1,
    gluOffset: 8.0,
    hydOffset: -5.5,
    hrvOffset: -9.0,
  ),
  _MissionCheckpointSpec(
    day: 1,
    hourOffset: 23,
    env: SpaceOperationalEnvironment.spacecraft,
    context: ActivityContext.sleep,
    hardware: 'Actiwatch + Bio-Monitor Nocturno',
    qualityPercent: 95,
    note:
        'D1 • Sueño en cabina de Nave: episodio leve de mareo espacial (SMS) resuelto durante descanso.',
    hrOffset: -7.0,
    rrOffset: -2.0,
    spo2Offset: -0.6,
    sbpOffset: -8.0,
    dbpOffset: -6.0,
    crtOffset: 0.1,
    tempOffset: -0.3,
    gluOffset: -6.0,
    hydOffset: -4.5,
    hrvOffset: 8.0,
  ),
  _MissionCheckpointSpec(
    day: 2,
    hourOffset: 14,
    env: SpaceOperationalEnvironment.spacecraft,
    context: ActivityContext.physicalActivity,
    hardware: 'Bio-Monitor CSA + IMU Triaxial',
    qualityPercent: 90,
    note:
        'D2 • Maniobra de acoplamiento a Estación: carga dinámica y vigilia sostenida (PVT-B nominal).',
    hrOffset: 24.0,
    rrOffset: 5.0,
    spo2Offset: -0.5,
    sbpOffset: 14.0,
    dbpOffset: 7.0,
    crtOffset: -0.1,
    tempOffset: 0.3,
    gluOffset: -4.0,
    hydOffset: -5.0,
    hrvOffset: -18.0,
  ),
  _MissionCheckpointSpec(
    day: 3,
    hourOffset: 10,
    env: SpaceOperationalEnvironment.spaceStation,
    context: ActivityContext.rest,
    hardware: 'Bodystat BIS + Bio-Monitor CSA',
    qualityPercent: 96,
    note:
        'D3 • ISS (0 g): ajuste de fluid shift y calibración multifrecuencia de agua corporal total (TBW).',
    hrOffset: 3.4,
    rrOffset: 0.5,
    spo2Offset: 0.0,
    sbpOffset: 2.0,
    dbpOffset: 1.0,
    crtOffset: 0.0,
    tempOffset: 0.0,
    gluOffset: 2.0,
    hydOffset: -3.5,
    hrvOffset: -3.0,
  ),
  _MissionCheckpointSpec(
    day: 4,
    hourOffset: 16,
    env: SpaceOperationalEnvironment.spaceStation,
    context: ActivityContext.physicalActivity,
    hardware: 'CEVIS + Bio-Monitor CSA (PPG/ECG)',
    qualityPercent: 89,
    note:
        'D4 • ISS Sesion CEVIS (35 min): contramedida aeróbica contra desacondicionamiento cardiovascular.',
    hrOffset: 44.0,
    rrOffset: 10.0,
    spo2Offset: -0.8,
    sbpOffset: 24.0,
    dbpOffset: 5.0,
    crtOffset: -0.2,
    tempOffset: 0.6,
    gluOffset: -9.0,
    hydOffset: -3.0,
    hrvOffset: -26.0,
  ),
  _MissionCheckpointSpec(
    day: 5,
    hourOffset: 3,
    env: SpaceOperationalEnvironment.spaceStation,
    context: ActivityContext.sleep,
    hardware: 'Actiwatch + Bio-Monitor Nocturno',
    qualityPercent: 97,
    note:
        'D5 • Sueño ISS (ciclo 16 amaneceres): recuperación parasimpática RMSSD dentro de rango basal.',
    hrOffset: -10.0,
    rrOffset: -3.0,
    spo2Offset: -0.4,
    sbpOffset: -10.0,
    dbpOffset: -8.0,
    crtOffset: 0.1,
    tempOffset: -0.4,
    gluOffset: -7.0,
    hydOffset: -1.0,
    hrvOffset: 14.0,
  ),
  _MissionCheckpointSpec(
    day: 6,
    hourOffset: 11,
    env: SpaceOperationalEnvironment.spaceStation,
    context: ActivityContext.rest,
    hardware: 'Abbott i-STAT Alinity POCT',
    qualityPercent: 98,
    note:
        'D6 • Control metabólico POCT (ISS): glucemia posprandial e ionograma (Ca²⁺/Na⁺) equilibrados.',
    hrOffset: 0.0,
    rrOffset: 0.0,
    spo2Offset: 0.2,
    sbpOffset: 0.0,
    dbpOffset: 0.0,
    crtOffset: 0.0,
    tempOffset: 0.0,
    gluOffset: 5.0,
    hydOffset: 0.0,
    hrvOffset: 2.0,
  ),
  _MissionCheckpointSpec(
    day: 8,
    hourOffset: 15,
    env: SpaceOperationalEnvironment.spaceStation,
    context: ActivityContext.physicalActivity,
    hardware: 'ARED + Bio-Monitor CSA',
    qualityPercent: 90,
    note:
        'D8 • ISS Sesión ARED resistencia: prevención de atrofia en cuádriceps y pérdida mineral ósea.',
    hrOffset: 38.0,
    rrOffset: 8.5,
    spo2Offset: -0.6,
    sbpOffset: 21.0,
    dbpOffset: 6.0,
    crtOffset: -0.2,
    tempOffset: 0.5,
    gluOffset: -7.0,
    hydOffset: -2.0,
    hrvOffset: -24.0,
  ),
  _MissionCheckpointSpec(
    day: 9,
    hourOffset: 19,
    env: SpaceOperationalEnvironment.spaceStation,
    context: ActivityContext.rest,
    hardware: 'Draeger Double Sensor + Sensores ECLSS',
    qualityPercent: 96,
    note:
        'D9 • ISS Bolsón transitorio de CO₂ (4.4 mmHg): incremento leve de ventilación compensatoria.',
    hrOffset: 5.0,
    rrOffset: 3.0,
    spo2Offset: -0.5,
    sbpOffset: 4.0,
    dbpOffset: 2.0,
    crtOffset: 0.0,
    tempOffset: 0.1,
    gluOffset: 1.0,
    hydOffset: -1.0,
    hrvOffset: -6.0,
  ),
  _MissionCheckpointSpec(
    day: 10,
    hourOffset: 2,
    env: SpaceOperationalEnvironment.spaceStation,
    context: ActivityContext.sleep,
    hardware: 'Bio-Monitor Nocturno + ToF/SANS Log',
    qualityPercent: 97,
    note:
        'D10 • Descanso tras purga de filtros CO₂ y cribado pasivo ToF para vigilancia SANS.',
    hrOffset: -9.0,
    rrOffset: -2.5,
    spo2Offset: -0.2,
    sbpOffset: -9.0,
    dbpOffset: -7.0,
    crtOffset: 0.1,
    tempOffset: -0.3,
    gluOffset: -5.0,
    hydOffset: 0.5,
    hrvOffset: 11.0,
  ),
  _MissionCheckpointSpec(
    day: 12,
    hourOffset: 10,
    env: SpaceOperationalEnvironment.spaceStation,
    context: ActivityContext.rest,
    hardware: 'EPM Cardiocavity + Abbott i-STAT',
    qualityPercent: 98,
    note:
        'D12 • Evaluación cardiovascular previa a transferencia de superficie; estabilidad autonómica.',
    hrOffset: -1.0,
    rrOffset: 0.0,
    spo2Offset: 0.3,
    sbpOffset: -2.0,
    dbpOffset: -1.0,
    crtOffset: 0.0,
    tempOffset: 0.0,
    gluOffset: 2.0,
    hydOffset: 1.0,
    hrvOffset: 4.0,
  ),
  _MissionCheckpointSpec(
    day: 13,
    hourOffset: 14,
    env: SpaceOperationalEnvironment.rover,
    context: ActivityContext.physicalActivity,
    hardware: 'IMU Traje EVA + Draeger Double Sensor',
    qualityPercent: 89,
    note:
        'D13 • Rover / EVA 1 (0.16 g): traje presurizado 29.6 kPa, carga térmica LCVG y esfuerzo físico.',
    hrOffset: 42.0,
    rrOffset: 9.0,
    spo2Offset: -1.0,
    sbpOffset: 22.0,
    dbpOffset: 6.0,
    crtOffset: -0.1,
    tempOffset: 0.7,
    gluOffset: -11.0,
    hydOffset: -4.5,
    hrvOffset: -25.0,
  ),
  _MissionCheckpointSpec(
    day: 14,
    hourOffset: 16,
    env: SpaceOperationalEnvironment.rover,
    context: ActivityContext.physicalActivity,
    hardware: 'Bio-Monitor EVA + Bodystat BIS',
    qualityPercent: 88,
    note:
        'D14 • Rover / EVA 2: deshidratación leve pos-travesía compensada con reposición oral guiada.',
    hrOffset: 40.0,
    rrOffset: 8.5,
    spo2Offset: -0.9,
    sbpOffset: 19.0,
    dbpOffset: 5.0,
    crtOffset: 0.1,
    tempOffset: 0.6,
    gluOffset: -10.0,
    hydOffset: -5.0,
    hrvOffset: -23.0,
  ),
  _MissionCheckpointSpec(
    day: 15,
    hourOffset: 4,
    env: SpaceOperationalEnvironment.rover,
    context: ActivityContext.sleep,
    hardware: 'Actiwatch + Bio-Monitor Nocturno',
    qualityPercent: 95,
    note:
        'D15 • Sueño en cabina Rover: recuperación de tono parasimpático tras dos jornadas EVA.',
    hrOffset: -6.0,
    rrOffset: -2.0,
    spo2Offset: -0.5,
    sbpOffset: -7.0,
    dbpOffset: -5.0,
    crtOffset: 0.1,
    tempOffset: -0.2,
    gluOffset: -4.0,
    hydOffset: -2.0,
    hrvOffset: 7.0,
  ),
  _MissionCheckpointSpec(
    day: 16,
    hourOffset: 11,
    env: SpaceOperationalEnvironment.planetaryBase,
    context: ActivityContext.rest,
    hardware: 'Abbott i-STAT + Oxímetro Base',
    qualityPercent: 96,
    note:
        'D16 • Base Planetaria: ingreso por esclusa con control PM2.5 de regolito y oximetría limpia.',
    hrOffset: 2.0,
    rrOffset: 1.0,
    spo2Offset: -0.3,
    sbpOffset: 2.0,
    dbpOffset: 1.0,
    crtOffset: 0.0,
    tempOffset: 0.1,
    gluOffset: 3.0,
    hydOffset: -1.0,
    hrvOffset: 0.0,
  ),
  _MissionCheckpointSpec(
    day: 17,
    hourOffset: 3,
    env: SpaceOperationalEnvironment.planetaryBase,
    context: ActivityContext.sleep,
    hardware: 'Actiwatch + Draeger Heat-Flux',
    qualityPercent: 97,
    note:
        'D17 • Base Planetaria descanso nocturno: blindaje de regolito reduce tasa de radiación GCR.',
    hrOffset: -10.0,
    rrOffset: -3.0,
    spo2Offset: -0.2,
    sbpOffset: -9.0,
    dbpOffset: -7.0,
    crtOffset: 0.1,
    tempOffset: -0.4,
    gluOffset: -6.0,
    hydOffset: 0.0,
    hrvOffset: 13.0,
  ),
];

/// Genera un historial clínico coherente de 18 días multi-entorno y lo fusiona
/// con los paquetes en vivo recibidos en [recorded].
List<TelemetrySamplePoint> _buildRealisticMissionHistoryForMetric({
  required _VitalHistoryMetric metric,
  required List<TelemetrySamplePoint> recorded,
  required double currentValue,
  required ActivityContext currentContext,
  required DateTime currentTimestamp,
  required int currentMissionDay,
  required SpaceOperationalEnvironment activeEnvironment,
  required String currentSourceLabel,
  required double nominalRestBaseline,
  required double minClamp,
  required double maxClamp,
  double? currentSecondaryValue,
}) {
  final int clampedCurrentDay = currentMissionDay.clamp(1, 30);
  final DateTime missionStart =
      currentTimestamp.subtract(Duration(days: clampedCurrentDay - 1));

  final historical = <TelemetrySamplePoint>[];
  for (final cp in _kMissionCheckpoints) {
    if (cp.day >= clampedCurrentDay) continue;
    final double delta;
    switch (metric) {
      case _VitalHistoryMetric.heartRate:
        delta = cp.hrOffset;
      case _VitalHistoryMetric.respiratoryRate:
        delta = cp.rrOffset;
      case _VitalHistoryMetric.spO2:
        delta = cp.spo2Offset;
      case _VitalHistoryMetric.systolicBP:
        delta = cp.sbpOffset;
      case _VitalHistoryMetric.diastolicBP:
        delta = cp.dbpOffset;
      case _VitalHistoryMetric.capillaryRefill:
        delta = cp.crtOffset;
      case _VitalHistoryMetric.bodyTemp:
        delta = cp.tempOffset;
      case _VitalHistoryMetric.bloodGlucose:
        delta = cp.gluOffset;
      case _VitalHistoryMetric.hydration:
        delta = cp.hydOffset;
      case _VitalHistoryMetric.hrv:
        delta = cp.hrvOffset;
    }

    final double computed =
        (nominalRestBaseline + delta).clamp(minClamp, maxClamp);
    final DateTime ts = DateTime(
      missionStart.year,
      missionStart.month,
      missionStart.day,
      cp.hourOffset,
    ).add(Duration(days: cp.day - 1));

    historical.add(
      TelemetrySamplePoint(
        timestamp: ts,
        value: double.parse(computed.toStringAsFixed(1)),
        context: cp.context,
        source: cp.hardware,
        signalQualityPercent: cp.qualityPercent,
        missionDay: cp.day,
        environment: cp.env,
        clinicalEventNote: cp.note,
      ),
    );
  }

  // Enriquecemos paquetes reales recientes con día de misión y entorno activo si carecen de ellos.
  final enrichedRecorded = recorded.map((sample) {
    return TelemetrySamplePoint(
      timestamp: sample.timestamp,
      value: sample.value?.clamp(minClamp, maxClamp),
      secondaryValue: sample.secondaryValue,
      context: sample.context,
      isValid: sample.isValid,
      source: sample.source,
      signalQualityPercent: sample.signalQualityPercent ?? 96,
      missionDay: sample.missionDay ?? clampedCurrentDay,
      environment: sample.environment ?? activeEnvironment,
      clinicalEventNote: sample.clinicalEventNote ??
          'Día $clampedCurrentDay • Lectura activa en ${activeEnvironment.shortLabel}.',
    );
  }).toList();

  final merged = [...historical, ...enrichedRecorded];

  // Punto actual garantizado al día de misión vigente para reflejar cambios manuales o inyecciones.
  merged.add(
    TelemetrySamplePoint(
      timestamp: currentTimestamp,
      value: double.parse(currentValue.clamp(minClamp, maxClamp).toStringAsFixed(1)),
      secondaryValue: currentSecondaryValue,
      context: currentContext,
      source: currentSourceLabel,
      signalQualityPercent: 98,
      missionDay: clampedCurrentDay,
      environment: activeEnvironment,
      clinicalEventNote:
          'Día $clampedCurrentDay • Estado vigente (${activeEnvironment.label}).',
    ),
  );

  // Garantiza presencia de los 3 contextos para el desglose basal si el día actual filtró algo.
  for (final requiredCtx in [
    ActivityContext.rest,
    ActivityContext.sleep,
    ActivityContext.physicalActivity,
  ]) {
    if (!merged.any((s) => s.context == requiredCtx)) {
      merged.add(
        TelemetrySamplePoint(
          timestamp: currentTimestamp.subtract(const Duration(hours: 2)),
          value: nominalRestBaseline.clamp(minClamp, maxClamp),
          context: requiredCtx,
          source: '$currentSourceLabel (basal)',
          signalQualityPercent: 95,
          missionDay: clampedCurrentDay,
          environment: activeEnvironment,
          clinicalEventNote: 'Referencia basal de contexto en misión.',
        ),
      );
    }
  }

  merged.sort((a, b) => a.timestamp.compareTo(b.timestamp));
  return merged;
}

double? _averageForContext(
  List<TelemetrySamplePoint> samples,
  ActivityContext context,
) {
  final values = samples
      .where((s) => s.context == context && s.isValid && s.value != null)
      .map((s) => s.value!)
      .toList();
  if (values.isEmpty) return null;
  return values.reduce((a, b) => a + b) / values.length;
}

/// Snapshot de series temporales y disponibilidad de dispositivos conectado
/// al estado real de [telemetryProvider] y al astronauta activo.
final telemetrySeriesSnapshotProvider = Provider<TelemetrySeriesSnapshot>((ref) {
  final astronaut = ref.watch(selectedAstronautProvider);
  final telemetryState = ref.watch(telemetryProvider);
  final activeEnvironment = ref.watch(selectedEnvironmentProvider);
  final v = astronaut.vitals;

  final devices = telemetryState.machines.map((machine) {
    final machineStatus = machine.statusFor(astronaut.id);
    final DeviceAvailabilityStatus availability;
    switch (machineStatus) {
      case MachineConnectionStatus.connected:
      case MachineConnectionStatus.streaming:
        availability = DeviceAvailabilityStatus.connected;
      case MachineConnectionStatus.disconnected:
      case MachineConnectionStatus.connecting:
      case MachineConnectionStatus.error:
        availability = DeviceAvailabilityStatus.disconnected;
    }

    final lastPacket = machine.lastPacketByAstronaut[astronaut.id];
    final validPercent = lastPacket != null
        ? parseSignalQualityPercent(lastPacket.signalQuality)
        : null;

    return TelemetryDeviceInfo(
      name: machine.name,
      category: '${machine.code} • ${machine.protocol}',
      status: availability,
      variables: machine.supportedMetrics,
      validReadingsPercent: validPercent,
      isSimulated: true,
    );
  }).toList();

  final astronautPackets = telemetryState.recentLogs
      .where((p) => p.astronautId == astronaut.id)
      .toList()
      .reversed
      .toList();

  final hrSamples = <TelemetrySamplePoint>[];
  final rrSamples = <TelemetrySamplePoint>[];
  final spo2Samples = <TelemetrySamplePoint>[];
  final systolicBpSamples = <TelemetrySamplePoint>[];
  final diastolicBpSamples = <TelemetrySamplePoint>[];
  final capillaryRefillSamples = <TelemetrySamplePoint>[];
  final bodyTempSamples = <TelemetrySamplePoint>[];
  final bloodGlucoseSamples = <TelemetrySamplePoint>[];
  final hydrationSamples = <TelemetrySamplePoint>[];
  final hrvSamples = <TelemetrySamplePoint>[];

  void addMetric(
    List<TelemetrySamplePoint> target,
    double? value,
    DateTime timestamp,
    ActivityContext ctx,
    bool isValid,
    String sourceLabel,
    double? quality,
  ) {
    if (value == null) return;
    target.add(TelemetrySamplePoint(
      timestamp: timestamp,
      value: value,
      context: ctx,
      isValid: isValid,
      source: sourceLabel,
      signalQualityPercent: quality,
    ));
  }

  for (final packet in astronautPackets) {
    final ctx = mapActivityStateToContext(packet.activityState);
    final quality = parseSignalQualityPercent(packet.signalQuality);
    final isValid = quality == null || quality >= 60.0;
    final sourceLabel =
        packet.device.isNotEmpty ? packet.device : packet.machineId;
    final metrics = packet.metrics;

    addMetric(hrSamples, (metrics['heartRate'] as num?)?.toDouble(),
        packet.timestamp, ctx, isValid, sourceLabel, quality);
    addMetric(rrSamples, (metrics['respiratoryRate'] as num?)?.toDouble(),
        packet.timestamp, ctx, isValid, sourceLabel, quality);
    addMetric(spo2Samples, (metrics['spO2'] as num?)?.toDouble(),
        packet.timestamp, ctx, isValid, sourceLabel, quality);
    addMetric(systolicBpSamples, (metrics['systolicBP'] as num?)?.toDouble(),
        packet.timestamp, ctx, isValid, sourceLabel, quality);
    addMetric(diastolicBpSamples, (metrics['diastolicBP'] as num?)?.toDouble(),
        packet.timestamp, ctx, isValid, sourceLabel, quality);
    addMetric(
        capillaryRefillSamples,
        (metrics['capillaryRefillSeconds'] as num?)?.toDouble(),
        packet.timestamp,
        ctx,
        isValid,
        sourceLabel,
        quality);
    addMetric(bodyTempSamples, (metrics['bodyTemp'] as num?)?.toDouble(),
        packet.timestamp, ctx, isValid, sourceLabel, quality);
    addMetric(
        bloodGlucoseSamples,
        (metrics['bloodGlucose'] as num?)?.toDouble(),
        packet.timestamp,
        ctx,
        isValid,
        sourceLabel,
        quality);

    final rawHydration =
        (metrics['hydrationBioimpedanceIndex'] as num?)?.toDouble();
    if (rawHydration != null) {
      final mDay = (metrics['missionDay'] as num?)?.toInt() ?? v.missionDay;
      final offset = mDay <= 3 ? -6.5 : (mDay <= 7 ? -3.0 : 0.0);
      addMetric(hydrationSamples, (rawHydration + offset).clamp(0.0, 100.0),
          packet.timestamp, ctx, isValid, sourceLabel, quality);
    }

    addMetric(hrvSamples, (metrics['hrvRmssdMs'] as num?)?.toDouble(),
        packet.timestamp, ctx, isValid, sourceLabel, quality);
  }

  final currentCtx = ScientificCriteriaEngine.inferActivityAndValidateHrv(
    accelerometryRmsG: v.accelerometryRmsG,
    heartRateBpm: v.heartRate,
    respiratoryRateRpm: v.respiratoryRate,
    rawActivityState: v.activityState,
  ).inferredContext;

  final double baseHr = v.heartRate > 95 ? 68.0 : v.heartRate;
  final double baseRr = v.respiratoryRate > 22 ? 15.0 : v.respiratoryRate;
  final double baseSpo2 = v.spO2 < 94 ? 97.5 : v.spO2;
  final double baseSbp = v.systolicBP > 138 ? 118.0 : v.systolicBP;
  final double baseDbp = v.diastolicBP > 88 ? 76.0 : v.diastolicBP;
  final double baseTemp = v.bodyTemp > 37.3 ? 36.6 : v.bodyTemp;
  final double baseGlu = v.bloodGlucose > 135 ? 92.0 : v.bloodGlucose;
  final double baseHyd = v.calibratedHydrationIndex < 55
      ? 72.0
      : v.calibratedHydrationIndex;
  final double baseHrv = v.hrvRmssdMs < 35 ? 54.0 : v.hrvRmssdMs;

  final seededHr = _buildRealisticMissionHistoryForMetric(
    metric: _VitalHistoryMetric.heartRate,
    recorded: hrSamples,
    currentValue: v.heartRate,
    currentContext: currentCtx,
    currentTimestamp: v.timestamp,
    currentMissionDay: v.missionDay,
    activeEnvironment: activeEnvironment,
    currentSourceLabel: v.device,
    nominalRestBaseline: baseHr,
    minClamp: 40,
    maxClamp: 200,
  );
  final seededRr = _buildRealisticMissionHistoryForMetric(
    metric: _VitalHistoryMetric.respiratoryRate,
    recorded: rrSamples,
    currentValue: v.respiratoryRate,
    currentContext: currentCtx,
    currentTimestamp: v.timestamp,
    currentMissionDay: v.missionDay,
    activeEnvironment: activeEnvironment,
    currentSourceLabel: v.device,
    nominalRestBaseline: baseRr,
    minClamp: 8,
    maxClamp: 45,
  );
  final seededSpo2 = _buildRealisticMissionHistoryForMetric(
    metric: _VitalHistoryMetric.spO2,
    recorded: spo2Samples,
    currentValue: v.spO2,
    currentContext: currentCtx,
    currentTimestamp: v.timestamp,
    currentMissionDay: v.missionDay,
    activeEnvironment: activeEnvironment,
    currentSourceLabel: v.device,
    nominalRestBaseline: baseSpo2,
    minClamp: 80,
    maxClamp: 100,
  );
  final seededSysBp = _buildRealisticMissionHistoryForMetric(
    metric: _VitalHistoryMetric.systolicBP,
    recorded: systolicBpSamples,
    currentValue: v.systolicBP,
    currentContext: currentCtx,
    currentTimestamp: v.timestamp,
    currentMissionDay: v.missionDay,
    activeEnvironment: activeEnvironment,
    currentSourceLabel: v.device,
    nominalRestBaseline: baseSbp,
    minClamp: 80,
    maxClamp: 210,
  );
  final seededDiaBp = _buildRealisticMissionHistoryForMetric(
    metric: _VitalHistoryMetric.diastolicBP,
    recorded: diastolicBpSamples,
    currentValue: v.diastolicBP,
    currentContext: currentCtx,
    currentTimestamp: v.timestamp,
    currentMissionDay: v.missionDay,
    activeEnvironment: activeEnvironment,
    currentSourceLabel: v.device,
    nominalRestBaseline: baseDbp,
    minClamp: 50,
    maxClamp: 120,
  );
  final seededCapRefill = _buildRealisticMissionHistoryForMetric(
    metric: _VitalHistoryMetric.capillaryRefill,
    recorded: capillaryRefillSamples,
    currentValue: v.capillaryRefillSeconds,
    currentContext: currentCtx,
    currentTimestamp: v.timestamp,
    currentMissionDay: v.missionDay,
    activeEnvironment: activeEnvironment,
    currentSourceLabel: v.device,
    nominalRestBaseline: v.capillaryRefillSeconds > 2.2
        ? 1.5
        : v.capillaryRefillSeconds,
    minClamp: 0.5,
    maxClamp: 5.0,
  );
  final seededTemp = _buildRealisticMissionHistoryForMetric(
    metric: _VitalHistoryMetric.bodyTemp,
    recorded: bodyTempSamples,
    currentValue: v.bodyTemp,
    currentContext: currentCtx,
    currentTimestamp: v.timestamp,
    currentMissionDay: v.missionDay,
    activeEnvironment: activeEnvironment,
    currentSourceLabel: v.device,
    nominalRestBaseline: baseTemp,
    minClamp: 35.0,
    maxClamp: 40.5,
  );
  final seededGlucose = _buildRealisticMissionHistoryForMetric(
    metric: _VitalHistoryMetric.bloodGlucose,
    recorded: bloodGlucoseSamples,
    currentValue: v.bloodGlucose,
    currentContext: currentCtx,
    currentTimestamp: v.timestamp,
    currentMissionDay: v.missionDay,
    activeEnvironment: activeEnvironment,
    currentSourceLabel: v.device,
    nominalRestBaseline: baseGlu,
    minClamp: 55.0,
    maxClamp: 220.0,
  );
  final seededHydration = _buildRealisticMissionHistoryForMetric(
    metric: _VitalHistoryMetric.hydration,
    recorded: hydrationSamples,
    currentValue: v.calibratedHydrationIndex,
    currentContext: currentCtx,
    currentTimestamp: v.timestamp,
    currentMissionDay: v.missionDay,
    activeEnvironment: activeEnvironment,
    currentSourceLabel: v.device,
    nominalRestBaseline: baseHyd,
    minClamp: 40.0,
    maxClamp: 100.0,
  );
  final seededHrv = _buildRealisticMissionHistoryForMetric(
    metric: _VitalHistoryMetric.hrv,
    recorded: hrvSamples,
    currentValue: v.hrvRmssdMs,
    currentContext: currentCtx,
    currentTimestamp: v.timestamp,
    currentMissionDay: v.missionDay,
    activeEnvironment: activeEnvironment,
    currentSourceLabel: v.device,
    nominalRestBaseline: baseHrv,
    minClamp: 10.0,
    maxClamp: 150.0,
  );

  return TelemetrySeriesSnapshot(
    heartRateSamples: seededHr,
    respiratoryRateSamples: seededRr,
    spO2Samples: seededSpo2,
    systolicBpSamples: seededSysBp,
    diastolicBpSamples: seededDiaBp,
    capillaryRefillSamples: seededCapRefill,
    bodyTempSamples: seededTemp,
    bloodGlucoseSamples: seededGlucose,
    hydrationSamples: seededHydration,
    hrvSamples: seededHrv,
    individualHrBaselineBpm: _averageForContext(seededHr, ActivityContext.rest),
    individualRrBaselineRpm: _averageForContext(seededRr, ActivityContext.rest),
    individualSpo2BaselinePercent:
        _averageForContext(seededSpo2, ActivityContext.rest),
    devices: devices,
  );
});
