import 'package:astramed/features/01_general_health/domain/scientific_criteria_engine.dart';

/// Estado operativo de un dispositivo de telemetría médica.
enum DeviceAvailabilityStatus {
  connected('Conectado'),
  disconnected('Desconectado'),
  pendingIntegration('Pendiente de integración');

  final String label;
  const DeviceAvailabilityStatus(this.label);
}

/// Información descriptiva de un sensor o equipo de monitoreo.
class TelemetryDeviceInfo {
  final String name;
  final String category;
  final DeviceAvailabilityStatus status;
  final List<String> variables;
  final double? validReadingsPercent;
  final bool isSimulated;

  const TelemetryDeviceInfo({
    required this.name,
    required this.category,
    required this.status,
    required this.variables,
    this.validReadingsPercent,
    this.isSimulated = false,
  });
}

/// Entorno operacional espacial que condiciona tanto el ambiente físico como el riesgo clínico.
enum SpaceOperationalEnvironment {
  spaceStation(
    label: 'Estación Espacial (ISS)',
    shortLabel: 'Estación (0 g)',
    gravityProfile: '0 g • Microgravedad continua',
    physicalConditions: [
      'Microgravedad sostenida (0 g) y redistribución cefálica de fluidos',
      'Presión de cabina 101.3 kPa con vigilancia de bolsones de CO₂ (>4.0 mmHg)',
      'Ciclo orbital de 16 amaneceres/día (alteración circadiana)',
      'Radiación ionizante orbital (GCR / paso por Anomalía del Atlántico Sur)',
    ],
    clinicalRisks: [
      'SANS (síndrome neuro-ocular, hipermetropía +0.50 a +1.75 D)',
      'Atrofia muscular en miembros inferiores y pérdida de DMO',
      'Hipercalciuria / litiasis renal y taquicardia por desacondicionamiento',
      'Fragmentación del sueño y fatiga psicomotriz (PVT-B)',
    ],
    accentHex: 0xFF38BDF8,
  ),
  spacecraft(
    label: 'Nave Espacial / Tránsito',
    shortLabel: 'Nave (Tránsito)',
    gravityProfile: '0 g ↔ Hipergravedad (1.5–4 g)',
    physicalConditions: [
      'Aceleraciones dinámicas e hipergravedad durante ignición / reentrada',
      'Cabina compacta con monitoreo estricto de O₂, CO₂ y trazas de CH₄',
      'Aislamiento acústico y vibración estructural continua',
      'Exposición a radiación de espacio profundo sin escudo geomagnético',
    ],
    clinicalRisks: [
      'Mareo de movimiento espacial (SMS) e intolerancia ortostática',
      'Hipotensión / síncope tras cargas G y cefalea hipercapnica',
      'Disnea o irritación tóxica por fugas de propelentes / CH₄',
      'Déficit agudo de alerta cognitiva y lapsos de atención (>500 ms)',
    ],
    accentHex: 0xFFA855F7,
  ),
  rover(
    label: 'Rover / Exploración EVA',
    shortLabel: 'Rover (EVA)',
    gravityProfile: '0.16 g – 0.38 g + Traje presurizado',
    physicalConditions: [
      'Presión reducida en traje EVA (~29.6 kPa O₂ puro) / cabina Rover',
      'Carga térmica metabólica elevada y enfriamiento por LCVG',
      'Vibración todo-terreno, impactos triaxiales e inclinación del terreno',
      'Mayor tasa de dosis de radiación superficial durante salidas',
    ],
    clinicalRisks: [
      'Deshidratación rápida y agotamiento térmico por esfuerzo EVA',
      'Enfermedad descompresiva (DCS) por gradiente de presión',
      'Trauma biomecánico, esguinces o impacto por caída en superficie',
      'Hipoglucemia o taquicardia sostenida por sobrecarga metabólica',
    ],
    accentHex: 0xFFF59E0B,
  ),
  planetaryBase(
    label: 'Base Planetaria (Lunar/Marciana)',
    shortLabel: 'Base Superficie',
    gravityProfile: '0.16 g (Luna) / 0.38 g (Marte)',
    physicalConditions: [
      'Polvo fino abrasivo de regolito (PM2.5) en esclusas de transición',
      'Blindaje parcial de rególito frente a partículas solares (SPE)',
      'Sistemas regenerativos ECLSS cerrados y reciclaje de agua',
      'Hipogravedad prolongada y turnos prolongados de mantenimiento',
    ],
    clinicalRisks: [
      'Neumonitis química e irritación de vías aéreas por polvo de regolito',
      'Conjuntivitis / abrasión corneal e hipoxemia subclínica',
      'Estrés oxidativo por radiación acumulada y alteración del ánimo',
      'Deterioro neuromuscular crónico sin contramedidas de carga',
    ],
    accentHex: 0xFF10B981,
  );

  final String label;
  final String shortLabel;
  final String gravityProfile;
  final List<String> physicalConditions;
  final List<String> clinicalRisks;
  final int accentHex;

  const SpaceOperationalEnvironment({
    required this.label,
    required this.shortLabel,
    required this.gravityProfile,
    required this.physicalConditions,
    required this.clinicalRisks,
    required this.accentHex,
  });
}

/// Registro clínico persistente originado por cuestionarios adaptativos o revisiones.
class ClinicalMissionLogEntry {
  final String id;
  final String astronautId;
  final DateTime timestamp;
  final int missionDay;
  final SpaceOperationalEnvironment environment;
  final String category;
  final String title;
  final String summary;
  final Map<String, String> answers;
  final String? badgeEarned;
  final int xpAwarded;

  const ClinicalMissionLogEntry({
    required this.id,
    required this.astronautId,
    required this.timestamp,
    required this.missionDay,
    required this.environment,
    required this.category,
    required this.title,
    required this.summary,
    this.answers = const {},
    this.badgeEarned,
    this.xpAwarded = 0,
  });
}

/// Punto de serie temporal para visualización desacoplada de telemetría.
class TelemetrySamplePoint {
  final DateTime timestamp;
  final double? value;
  final double? secondaryValue;
  final ActivityContext context;
  final bool isValid;
  final String source;
  final double? signalQualityPercent;
  final int? missionDay;
  final SpaceOperationalEnvironment? environment;
  final String? clinicalEventNote;

  const TelemetrySamplePoint({
    required this.timestamp,
    required this.value,
    this.secondaryValue,
    required this.context,
    this.isValid = true,
    required this.source,
    this.signalQualityPercent,
    this.missionDay,
    this.environment,
    this.clinicalEventNote,
  });
}

/// Contrato de lectura para el panel de gráficas y disponibilidad.
///
/// Se mantiene desacoplado de la capa de ingesta/telemetría para integrarse
/// sin conflictos con el módulo de adquisición en desarrollo.
class TelemetrySeriesSnapshot {
  final List<TelemetrySamplePoint> heartRateSamples;
  final List<TelemetrySamplePoint> respiratoryRateSamples;
  final List<TelemetrySamplePoint> spO2Samples;
  final List<TelemetrySamplePoint> systolicBpSamples;
  final List<TelemetrySamplePoint> diastolicBpSamples;
  final List<TelemetrySamplePoint> capillaryRefillSamples;
  final List<TelemetrySamplePoint> bodyTempSamples;
  final List<TelemetrySamplePoint> bloodGlucoseSamples;
  final List<TelemetrySamplePoint> hydrationSamples;
  final List<TelemetrySamplePoint> hrvSamples;
  final double? individualHrBaselineBpm;
  final double? individualRrBaselineRpm;
  final double? individualSpo2BaselinePercent;
  final List<TelemetryDeviceInfo> devices;

  const TelemetrySeriesSnapshot({
    required this.heartRateSamples,
    required this.respiratoryRateSamples,
    required this.spO2Samples,
    this.systolicBpSamples = const [],
    this.diastolicBpSamples = const [],
    this.capillaryRefillSamples = const [],
    this.bodyTempSamples = const [],
    this.bloodGlucoseSamples = const [],
    this.hydrationSamples = const [],
    this.hrvSamples = const [],
    this.individualHrBaselineBpm,
    this.individualRrBaselineRpm,
    this.individualSpo2BaselinePercent,
    required this.devices,
  });

  factory TelemetrySeriesSnapshot.empty() {
    return const TelemetrySeriesSnapshot(
      heartRateSamples: [],
      respiratoryRateSamples: [],
      spO2Samples: [],
      devices: [
        TelemetryDeviceInfo(
          name: 'Bio-Monitor / AstroSkin',
          category: 'Prenda inteligente ISS (ECG, respiración, acelerometría)',
          status: DeviceAvailabilityStatus.pendingIntegration,
          variables: ['FC', 'FR', 'Actividad'],
        ),
        TelemetryDeviceInfo(
          name: 'Banda ECG / Sensor PPG',
          category: 'Alternativa de monitoreo cardíaco',
          status: DeviceAvailabilityStatus.pendingIntegration,
          variables: ['FC'],
        ),
        TelemetryDeviceInfo(
          name: 'Banda Respiratoria Torácica',
          category: 'Alternativa de ciclos respiratorios',
          status: DeviceAvailabilityStatus.pendingIntegration,
          variables: ['FR'],
        ),
        TelemetryDeviceInfo(
          name: 'Pulsioxímetro Validado',
          category: 'Oximetría de pulso (SpO₂)',
          status: DeviceAvailabilityStatus.pendingIntegration,
          variables: ['SpO₂'],
        ),
      ],
    );
  }
}
