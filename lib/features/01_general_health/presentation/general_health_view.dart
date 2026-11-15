import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:astramed/core/theme/space_theme.dart';
import 'package:astramed/features/01_general_health/domain/scientific_criteria_engine.dart';
import 'package:astramed/features/01_general_health/domain/telemetry_view_contracts.dart';
import 'package:astramed/features/01_general_health/models/vitals_record.dart';
import 'package:astramed/features/01_general_health/presentation/providers/telemetry_panel_provider.dart';
import 'package:astramed/features/01_general_health/presentation/widgets/vital_detail_full_screen_view.dart';
import 'package:astramed/features/crew/models/astronaut_profile.dart';
import 'package:astramed/features/crew/presentation/providers/crew_provider.dart';
import 'package:astramed/features/telemetry/models/telemetry_machine.dart';
import 'package:astramed/features/telemetry/presentation/providers/telemetry_provider.dart';
import 'package:astramed/features/telemetry/presentation/widgets/telemetry_config_modal.dart';

/// Pantalla principal de Signos Vitales y Telemetría Médica conectada al
/// astronauta seleccionado, al bus de telemetría y al motor de criterios científicos.
class GeneralHealthView extends ConsumerWidget {
  const GeneralHealthView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final astronaut = ref.watch(selectedAstronautProvider);
    final telemetryState = ref.watch(telemetryProvider);
    final vitals = astronaut.vitals;
    final telemetrySnapshot = ref.watch(telemetrySeriesSnapshotProvider);
    final activeEnvironment = ref.watch(selectedEnvironmentProvider);
    final missionLogs = ref.watch(clinicalMissionLogsProvider);

    void recordMissionLog(ClinicalMissionLogEntry entry) {
      ref.read(clinicalMissionLogsProvider.notifier).addEntry(entry);
    }

    final actigraphyEval = ScientificCriteriaEngine.inferActivityAndValidateHrv(
      accelerometryRmsG: vitals.accelerometryRmsG,
      heartRateBpm: vitals.heartRate,
      respiratoryRateRpm: vitals.respiratoryRate,
      rawActivityState: vitals.activityState,
      restingWakefulHrBaselineBpm:
          telemetrySnapshot.individualHrBaselineBpm ?? 68.0,
    );
    final activeContext = actigraphyEval.inferredContext;

    final connectedMachines = telemetryState.machines
        .where((m) => m.isConnectedFor(astronaut.id))
        .toList();

    final hrEval = ScientificCriteriaEngine.evaluateHeartRate(
      bpm: vitals.heartRate,
      context: activeContext,
      individualBaselineBpm: telemetrySnapshot.individualHrBaselineBpm,
      localCo2MmHg: vitals.localCo2MmHg,
      missionDay: vitals.missionDay,
    );
    final rrEval = ScientificCriteriaEngine.evaluateRespiratoryRate(
      rpm: vitals.respiratoryRate,
      context: activeContext,
      individualBaselineRpm: telemetrySnapshot.individualRrBaselineRpm,
      localCo2MmHg: vitals.localCo2MmHg,
    );
    final spo2Eval = ScientificCriteriaEngine.evaluateSpO2(
      percent: vitals.spO2,
      context: activeContext,
      individualBaselinePercent: telemetrySnapshot.individualSpo2BaselinePercent,
    );

    final bpEval = ScientificCriteriaEngine.evaluateBloodPressureContextual(
      systolicMmHg: vitals.systolicBP,
      diastolicMmHg: vitals.diastolicBP,
      context: activeContext,
    );
    final capillaryEval =
        ScientificCriteriaEngine.evaluateCapillaryRefillContextual(
      seconds: vitals.capillaryRefillSeconds,
      context: activeContext,
    );
    final tempEval = ScientificCriteriaEngine.evaluateBodyTemperatureContextual(
      tempCelsius: vitals.bodyTemp,
      context: activeContext,
    );
    final glucoseEval = ScientificCriteriaEngine.evaluateBloodGlucoseContextual(
      mgDl: vitals.bloodGlucose,
      context: activeContext,
    );
    final hydrationEval = ScientificCriteriaEngine.evaluateHydrationContextual(
      calibratedHydrationPercent: vitals.calibratedHydrationIndex,
      missionDay: vitals.missionDay,
      context: activeContext,
    );
    final hrvEval = ScientificCriteriaEngine.evaluateHrvContextual(
      hrvRmssdMs: vitals.hrvRmssdMs,
      actigraphy: actigraphyEval,
    );

    final lastUpdateLabel = DateFormat('dd/MM HH:mm:ss').format(vitals.timestamp);
    final metadataTag =
        '${vitals.device} • ${vitals.recordType} • ${vitals.signalQuality}';

    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        _buildAstronautHeader(context, astronaut),
        const SizedBox(height: 12),

        _buildTelemetryLinkCard(
          context,
          ref,
          astronaut,
          connectedMachines,
          telemetryState.isLiveStreaming,
        ),
        const SizedBox(height: 12),

        _buildEnvironmentConditionsBanner(
          context,
          ref,
          activeEnvironment,
          vitals,
        ),
        const SizedBox(height: 12),

        if (astronaut.riskLevel != CrewRiskLevel.nominal) ...[
          _buildRiskBanner(astronaut),
          const SizedBox(height: 12),
        ],

        _CircumstantialGamificationCard(
          astronautId: astronaut.id,
          vitals: vitals,
          activeContext: activeContext,
          activeEnvironment: activeEnvironment,
          actigraphyJustification: actigraphyEval.justification,
        ),
        const SizedBox(height: 14),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Expanded(
              child: Text(
                'Signos Vitales y Telemetría Médica',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: SpaceTheme.cyan.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: SpaceTheme.cyan.withValues(alpha: 0.45),
                ),
              ),
              child: Text(
                'Auto: ${activeContext.label}',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: SpaceTheme.cyan,
                ),
              ),
            ),
            Row(
              children: [
                const Icon(Icons.lock_clock, size: 14, color: SpaceTheme.cyan),
                const SizedBox(width: 4),
                Text(
                  'Act: $lastUpdateLabel',
                  style: const TextStyle(fontSize: 11, color: SpaceTheme.cyan),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),

        _buildEvaluatedMetricCard(
          icon: Icons.favorite,
          iconColor: Colors.redAccent,
          title: 'Frecuencia Cardíaca',
          evaluation: hrEval,
          metadataTag: metadataTag,
          decimals: 0,
          onTap: () => VitalDetailFullScreenView.navigate(
            context,
            title: 'Frecuencia Cardíaca',
            icon: Icons.favorite,
            color: Colors.redAccent,
            evaluation: hrEval,
            contextAverageLabel: _formatContextAverage(
              telemetrySnapshot.heartRateSamples,
              activeContext,
              'lpm',
              decimals: 1,
            ),
            metadataTag: metadataTag,
            samples: telemetrySnapshot.heartRateSamples,
            unit: 'lpm',
            howToMeasure:
                'Registro continuo con prenda Bio-Monitor (CSA / protocolo CARDIOBREATH) mediante ECG de parches secos y PPG multi-longitud de onda (precisión 95–98 % en reposo/sueño; 88–92 % en ejercicio).',
            contextMeaning: _heartRateContextTip(activeContext),
            whenToPayAttention:
                'Compara siempre con tu propio promedio basal en el mismo estado. En microgravedad sube +3.44 lpm en promedio por fluid shift. Si supera 115 lpm en reposo sin movimiento en acelerometría (≤0.12 g), dispara alerta crítica.',
            activeContext: activeContext,
            astronautId: astronaut.id,
            missionDay: vitals.missionDay,
            activeEnvironment: activeEnvironment,
            onMissionLogCreated: recordMissionLog,
          ),
        ),
        _buildEvaluatedMetricCard(
          icon: Icons.waves,
          iconColor: Colors.tealAccent,
          title: 'Frecuencia Respiratoria',
          evaluation: rrEval,
          metadataTag: metadataTag,
          decimals: 1,
          onTap: () => VitalDetailFullScreenView.navigate(
            context,
            title: 'Frecuencia Respiratoria',
            icon: Icons.waves,
            color: Colors.tealAccent,
            evaluation: rrEval,
            contextAverageLabel: _formatContextAverage(
              telemetrySnapshot.respiratoryRateSamples,
              activeContext,
              'rpm',
              decimals: 1,
            ),
            metadataTag: metadataTag,
            samples: telemetrySnapshot.respiratoryRateSamples,
            unit: 'rpm',
            howToMeasure:
                'Bandas torácicas de pletismografía inductiva integradas en Bio-Monitor y sensores piezo/inductivos continuos (precisión 93–97 % en entornos presurizados).',
            contextMeaning:
                'En reposo oscila entre 12 y 20 rpm. Ante bolsones de CO₂ (>4.0 mmHg) en Estación o Nave puede elevarse de forma compensatoria antes de aparecer cefalea.',
            whenToPayAttention:
                'Revisa simultáneamente el nivel de CO₂ en cabina, exposición a polvo de regolito en Base Planetaria y presencia de disnea en reposo.',
            activeContext: activeContext,
            astronautId: astronaut.id,
            missionDay: vitals.missionDay,
            activeEnvironment: activeEnvironment,
            onMissionLogCreated: recordMissionLog,
          ),
        ),
        _buildEvaluatedMetricCard(
          icon: Icons.air,
          iconColor: Colors.cyanAccent,
          title: 'Saturación SpO₂',
          evaluation: spo2Eval,
          metadataTag: metadataTag,
          decimals: 0,
          onTap: () => VitalDetailFullScreenView.navigate(
            context,
            title: 'Saturación SpO₂',
            icon: Icons.air,
            color: Colors.cyanAccent,
            evaluation: spo2Eval,
            contextAverageLabel: _formatContextAverage(
              telemetrySnapshot.spO2Samples,
              activeContext,
              '%',
              decimals: 1,
            ),
            metadataTag: metadataTag,
            samples: telemetrySnapshot.spO2Samples,
            unit: '%',
            howToMeasure:
                'Pulsioximetría infrarroja validada FDA 510(k) e integrada en oxímetros portátiles de dedo y monitoreo nocturno continuo (precisión 93–97 %).',
            contextMeaning:
                'Estima la saturación arterial de oxígeno en hemoglobina (95–100 % nominal). En trajes EVA a baja presión (29.6 kPa) o tras inhalación de regolito fino puede descender ligeramente.',
            whenToPayAttention:
                'Verifica perfusión periférica, ajuste del sensor y presión O₂ de cabina/traje. Valores <94 % en reposo o <90 % crítico requieren evaluación médica inmediata.',
            activeContext: activeContext,
            astronautId: astronaut.id,
            missionDay: vitals.missionDay,
            activeEnvironment: activeEnvironment,
            onMissionLogCreated: recordMissionLog,
          ),
        ),

        _buildEvaluatedMetricCard(
          icon: Icons.speed,
          iconColor: Colors.blueAccent,
          title: 'Presión Arterial',
          evaluation: bpEval,
          metadataTag: metadataTag,
          decimals: 0,
          customValueText:
              '${vitals.systolicBP.toInt()} / ${vitals.diastolicBP.toInt()} mmHg',
          onTap: () => VitalDetailFullScreenView.navigate(
            context,
            title: 'Presión Arterial',
            icon: Icons.speed,
            color: Colors.blueAccent,
            evaluation: bpEval,
            contextAverageLabel: _formatContextAverage(
              telemetrySnapshot.systolicBpSamples,
              activeContext,
              'mmHg (sist.)',
              decimals: 0,
            ),
            metadataTag: metadataTag,
            samples: telemetrySnapshot.systolicBpSamples,
            unit: 'mmHg',
            customValueDisplay:
                '${vitals.systolicBP.toInt()} / ${vitals.diastolicBP.toInt()} mmHg',
            howToMeasure:
                'Módulo EPM Cardiocavity (fotopletismografía arterial de dedo y tonometría cardiovascular no invasiva) con confirmación por manguito oscilométrico a la altura del corazón.',
            contextMeaning:
                'En microgravedad los fluidos se desplazan al tórax y cabeza, alterando el reflejo barorreceptor. Durante ejercicio ARED/CEVIS la sistólica sube fisiológicamente hasta ~180 mmHg.',
            whenToPayAttention:
                'En fases de tránsito / hipergravedad (Nave) o pos-EVA vigila hipotensión ortostática (<90/60); en reposo sostenido >140/90 requiere confirmación con protocolo EPM.',
            activeContext: activeContext,
            astronautId: astronaut.id,
            missionDay: vitals.missionDay,
            activeEnvironment: activeEnvironment,
            onMissionLogCreated: recordMissionLog,
          ),
        ),
        _buildEvaluatedMetricCard(
          icon: Icons.touch_app,
          iconColor: Colors.purpleAccent,
          title: 'Tiempo de Llenado Capilar',
          evaluation: capillaryEval,
          metadataTag: metadataTag,
          decimals: 1,
          onTap: () => VitalDetailFullScreenView.navigate(
            context,
            title: 'Tiempo de Llenado Capilar',
            icon: Icons.touch_app,
            color: Colors.purpleAccent,
            evaluation: capillaryEval,
            contextAverageLabel: _formatContextAverage(
              telemetrySnapshot.capillaryRefillSamples,
              activeContext,
              's',
              decimals: 1,
            ),
            metadataTag: metadataTag,
            samples: telemetrySnapshot.capillaryRefillSamples,
            unit: 's',
            howToMeasure:
                'Compresión ungueal controlada de 5 s durante chequeo en Bahía Médica y correlación microvascular con tonometría del módulo EPM Cardiocavity.',
            contextMeaning:
                'Refleja la perfusión microvascular periférica. En reposo y ejercicio suele ser <= 2.0 s; durante sueño o en cabina fría puede alargarse levemente.',
            whenToPayAttention:
                'Si supera 2.5–3.0 s en cabina cálida y en reposo, valida hidratación por bioimpedancia BIS y electrolitos en Abbott i-STAT Alinity.',
            activeContext: activeContext,
            astronautId: astronaut.id,
            missionDay: vitals.missionDay,
            activeEnvironment: activeEnvironment,
            onMissionLogCreated: recordMissionLog,
          ),
        ),
        _buildEvaluatedMetricCard(
          icon: Icons.thermostat,
          iconColor: Colors.orangeAccent,
          title: 'Temperatura Corporal',
          evaluation: tempEval,
          metadataTag: metadataTag,
          decimals: 1,
          onTap: () => VitalDetailFullScreenView.navigate(
            context,
            title: 'Temperatura Corporal',
            icon: Icons.thermostat,
            color: Colors.orangeAccent,
            evaluation: tempEval,
            contextAverageLabel: _formatContextAverage(
              telemetrySnapshot.bodyTempSamples,
              activeContext,
              '°C',
              decimals: 1,
            ),
            metadataTag: metadataTag,
            samples: telemetrySnapshot.bodyTempSamples,
            unit: '°C',
            howToMeasure:
                'Sensor térmico no invasivo Draeger Double Sensor validado por DLR y NASA mediante flujo de calor cutáneo (heat-flux; precisión 96–98 %, error < ±0.2 °C respecto a temperatura central).',
            contextMeaning:
                'En 0 g desaparece la convección natural y en Rover EVA el traje depende del bucle de enfriamiento líquido (LCVG), acelerando el ascenso térmico en ejercicio hasta ~38.4 °C.',
            whenToPayAttention:
                'Distingue hipertermia pos-esfuerzo en Rover/ARED de fiebre infecciosa en reposo (>= 37.8 °C sin carga física reciente).',
            activeContext: activeContext,
            astronautId: astronaut.id,
            missionDay: vitals.missionDay,
            activeEnvironment: activeEnvironment,
            onMissionLogCreated: recordMissionLog,
          ),
        ),
        _buildEvaluatedMetricCard(
          icon: Icons.bloodtype,
          iconColor: Colors.pinkAccent,
          title: 'Glucosa en Sangre',
          evaluation: glucoseEval,
          metadataTag: metadataTag,
          decimals: 0,
          onTap: () => VitalDetailFullScreenView.navigate(
            context,
            title: 'Glucosa en Sangre',
            icon: Icons.bloodtype,
            color: Colors.pinkAccent,
            evaluation: glucoseEval,
            contextAverageLabel: _formatContextAverage(
              telemetrySnapshot.bloodGlucoseSamples,
              activeContext,
              'mg/dL',
              decimals: 0,
            ),
            metadataTag: metadataTag,
            samples: telemetrySnapshot.bloodGlucoseSamples,
            unit: 'mg/dL',
            howToMeasure:
                'Analizador clínico portátil Abbott i-STAT Alinity POCT (glucemia junto con ionograma Ca²⁺/Na⁺/K⁺, creatinina y hemoglobina en cartucho único de sangre capilar) y biosensor intersticial continuo.',
            contextMeaning:
                'El vuelo espacial induce resistencia subclínica leve a la insulina en reposo, mientras que los protocolos EVA de Rover y ARED consumen glucógeno muscular rápidamente.',
            whenToPayAttention:
                'Valores <70 mg/dL antes o durante travesía EVA representan riesgo de hipoglucemia operativa y requieren aporte glucídico inmediato.',
            activeContext: activeContext,
            astronautId: astronaut.id,
            missionDay: vitals.missionDay,
            activeEnvironment: activeEnvironment,
            onMissionLogCreated: recordMissionLog,
          ),
        ),
        _buildEvaluatedMetricCard(
          icon: Icons.water_drop,
          iconColor: Colors.lightBlueAccent,
          title: 'Hidratación (Día ${vitals.missionDay})',
          evaluation: hydrationEval,
          metadataTag:
              'Bodystat BIS ${vitals.hydrationBioimpedanceIndex.toStringAsFixed(0)}% • CO₂ ${vitals.localCo2MmHg.toStringAsFixed(1)} mmHg',
          decimals: 1,
          onTap: () => VitalDetailFullScreenView.navigate(
            context,
            title: 'Hidratación (Día ${vitals.missionDay})',
            icon: Icons.water_drop,
            color: Colors.lightBlueAccent,
            evaluation: hydrationEval,
            contextAverageLabel: _formatContextAverage(
              telemetrySnapshot.hydrationSamples,
              activeContext,
              '%',
              decimals: 1,
            ),
            metadataTag:
                'Parches Bodystat BIS ${vitals.hydrationBioimpedanceIndex.toStringAsFixed(0)}% • Compensación fluid shift Día ${vitals.missionDay}',
            samples: telemetrySnapshot.hydrationSamples,
            unit: '%',
            howToMeasure:
                'Espectroscopia de bioimpedancia eléctrica multifrecuencia (parches dermables Bodystat BIS; precisión 90–94 % con corrección por software del desplazamiento cefálico de fluidos).',
            contextMeaning:
                'Durante los días 1–7 de vuelo se produce diuresis compensatoria (~10–15 % de volumen plasmático). Alcanzar equilibrio sostenido desbloquea la insignia Equilibrio Metabólico Perfecto.',
            whenToPayAttention:
                'Si cae <68 % (o <55 % crítico), especialmente antes o después de operación EVA/Rover, activa reposición isotónica inmediata.',
            activeContext: activeContext,
            astronautId: astronaut.id,
            missionDay: vitals.missionDay,
            activeEnvironment: activeEnvironment,
            onMissionLogCreated: recordMissionLog,
          ),
        ),
        _buildEvaluatedMetricCard(
          icon: Icons.bedtime,
          iconColor: Colors.indigoAccent,
          title: 'HRV y Actigrafía Bimodal',
          evaluation: hrvEval,
          metadataTag:
              'IMU ${vitals.accelerometryRmsG.toStringAsFixed(3)} g • Presión ${vitals.cabinPressureKPa.toStringAsFixed(1)} kPa',
          decimals: 0,
          onTap: () => VitalDetailFullScreenView.navigate(
            context,
            title: 'HRV y Actigrafía Bimodal',
            icon: Icons.bedtime,
            color: Colors.indigoAccent,
            evaluation: hrvEval,
            contextAverageLabel: _formatContextAverage(
              telemetrySnapshot.hrvSamples,
              activeContext,
              'ms',
              decimals: 0,
            ),
            metadataTag:
                'IMU ${vitals.accelerometryRmsG.toStringAsFixed(3)} g • ${actigraphyEval.justification}',
            samples: telemetrySnapshot.hrvSamples,
            unit: 'ms',
            howToMeasure:
                'HRV en dominio del tiempo (RMSSD/SDNN por ECG Bio-Monitor, precisión 95–98 %) fusionada con actígrafo biométrico de muñeca grado médico (Cole-Kripke, 90–95 % vs PSG) y vigilancia psicomotriz pasiva PVT-B (>500 ms).',
            contextMeaning:
                'En 0 g un astronauta flotando dormido mantiene micro-movimiento basal no-cero (0.005–0.065 g) por balistocardiografía; combinado con descenso de FC confirma descanso real.',
            whenToPayAttention:
                'Durante ejercicio CEVIS/ARED la HRV baja fisiológicamente por retiro vagal. Evalúa estrés autonómico y fatiga circadiana solo en reposo o sueño validado.',
            activeContext: activeContext,
            astronautId: astronaut.id,
            missionDay: vitals.missionDay,
            activeEnvironment: activeEnvironment,
            onMissionLogCreated: recordMissionLog,
          ),
        ),

        const SizedBox(height: 16),
        _buildManualAssessmentButton(context, ref, astronaut),

        const SizedBox(height: 16),
        _buildClinicalLogsSection(
          logs: missionLogs,
          activeAstronautId: astronaut.id,
        ),
      ],
    );
  }

  Widget _buildEnvironmentConditionsBanner(
    BuildContext context,
    WidgetRef ref,
    SpaceOperationalEnvironment activeEnv,
    VitalsRecord vitals,
  ) {
    final accent = Color(activeEnv.accentHex);
    final co2Warning = vitals.localCo2MmHg >= 3.5;

    Widget buildInfoColumn({
      required String header,
      required IconData icon,
      required Color iconColor,
      required List<String> items,
    }) {
      return Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: SpaceTheme.card,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 14, color: iconColor),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    header,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: iconColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ...items.take(3).map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Text(
                      '• $item',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.white70,
                        height: 1.25,
                      ),
                    ),
                  ),
                ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: SpaceTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.public, color: accent, size: 18),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Entorno Operacional: Condiciones y Riesgos',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: accent.withValues(alpha: 0.45)),
                ),
                child: Text(
                  activeEnv.gravityProfile,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: accent,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: SpaceOperationalEnvironment.values.map((env) {
              final selected = env == activeEnv;
              final envColor = Color(env.accentHex);
              return ChoiceChip(
                label: Text(
                  env.shortLabel,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                    color: selected ? Colors.black : Colors.white70,
                  ),
                ),
                selected: selected,
                selectedColor: envColor,
                backgroundColor: SpaceTheme.card,
                side: BorderSide(
                  color: selected ? envColor : Colors.white12,
                ),
                visualDensity: VisualDensity.compact,
                onSelected: (_) {
                  ref.read(selectedEnvironmentProvider.notifier).state = env;
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: SpaceTheme.card,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: co2Warning
                    ? SpaceTheme.warningYellow.withValues(alpha: 0.6)
                    : Colors.white10,
              ),
            ),
            child: Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                Text(
                  'CO₂ cabina: ${vitals.localCo2MmHg.toStringAsFixed(1)} mmHg',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: co2Warning ? SpaceTheme.warningYellow : SpaceTheme.cyan,
                  ),
                ),
                Text(
                  'O₂: ${vitals.localO2Percent.toStringAsFixed(1)}%',
                  style: const TextStyle(fontSize: 11, color: Colors.white70),
                ),
                Text(
                  'CH₄: ${vitals.localCh4Ppm.toStringAsFixed(1)} ppm',
                  style: const TextStyle(fontSize: 11, color: Colors.white70),
                ),
                Text(
                  'Presión: ${vitals.cabinPressureKPa.toStringAsFixed(1)} kPa',
                  style: const TextStyle(fontSize: 11, color: Colors.white70),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, constraints) {
              final condCard = buildInfoColumn(
                header: 'Condiciones Físicas Vigiladas',
                icon: Icons.sensors,
                iconColor: accent,
                items: activeEnv.physicalConditions,
              );
              final riskCard = buildInfoColumn(
                header: 'Riesgos Clínicos Monitoreados',
                icon: Icons.health_and_safety,
                iconColor: SpaceTheme.warningYellow,
                items: activeEnv.clinicalRisks,
              );
              if (constraints.maxWidth >= 560) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: condCard),
                    const SizedBox(width: 8),
                    Expanded(child: riskCard),
                  ],
                );
              }
              return Column(
                children: [
                  condCard,
                  const SizedBox(height: 8),
                  riskCard,
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildClinicalLogsSection({
    required List<ClinicalMissionLogEntry> logs,
    required String activeAstronautId,
  }) {
    final sortedLogs = [
      ...logs.where((e) => e.astronautId == activeAstronautId),
      ...logs.where((e) => e.astronautId != activeAstronautId),
    ];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: SpaceTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.assignment_turned_in,
                  color: SpaceTheme.cyan, size: 18),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Bitácora de Evaluaciones Registradas',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              Text(
                '${logs.length} reg.',
                style: const TextStyle(fontSize: 11, color: Colors.white54),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (sortedLogs.isEmpty)
            const Text(
              'Aún no hay cuestionarios clínicos archivados en este turno.',
              style: TextStyle(fontSize: 12, color: Colors.white54),
            )
          else
            ...sortedLogs.take(5).map((entry) {
              final envColor = Color(entry.environment.accentHex);
              final isForActive = entry.astronautId == activeAstronautId;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: SpaceTheme.card,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isForActive
                        ? SpaceTheme.cyan.withValues(alpha: 0.35)
                        : Colors.white10,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: SpaceTheme.surface,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.white12),
                          ),
                          child: Text(
                            '${entry.astronautId} • Día ${entry.missionDay}',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.white70,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: envColor.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            entry.environment.shortLabel,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: envColor,
                            ),
                          ),
                        ),
                        if (entry.badgeEarned != null)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: SpaceTheme.green.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '★ ${entry.badgeEarned} (+${entry.xpAwarded} XP)',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: SpaceTheme.green,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      entry.title,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      entry.summary,
                      style:
                          const TextStyle(fontSize: 11, color: Colors.white70),
                    ),
                    if (entry.answers.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      ...entry.answers.entries.map(
                        (kv) => Text(
                          '• ${kv.key}: ${kv.value}',
                          style: const TextStyle(
                            fontSize: 10,
                            color: Colors.white54,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildTelemetryLinkCard(
    BuildContext context,
    WidgetRef ref,
    AstronautProfile astronaut,
    List<TelemetryMachine> connectedMachines,
    bool isLiveStreaming,
  ) {
    final hasActiveSensors = connectedMachines.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: SpaceTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasActiveSensors
              ? SpaceTheme.cyan.withValues(alpha: 0.5)
              : SpaceTheme.warningYellow.withValues(alpha: 0.6),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                hasActiveSensors
                    ? (isLiveStreaming ? Icons.sensors : Icons.sync)
                    : Icons.sensors_off,
                color: hasActiveSensors
                    ? (isLiveStreaming ? SpaceTheme.green : SpaceTheme.cyan)
                    : SpaceTheme.warningYellow,
                size: 18,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Recepción Automática de Datos',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              Switch(
                value: hasActiveSensors && isLiveStreaming,
                activeTrackColor: SpaceTheme.green.withValues(alpha: 0.5),
                activeThumbColor: SpaceTheme.green,
                onChanged: hasActiveSensors
                    ? (_) {
                        ref
                            .read(telemetryProvider.notifier)
                            .toggleLiveStreaming(astronaut.id);
                      }
                    : null,
              ),
            ],
          ),
          if (!hasActiveSensors) ...[
            const SizedBox(height: 4),
            const Text(
              'No tienes sensores activos en este momento para recibir datos automáticamente. Puedes ingresar tus mediciones manualmente o activar sensores simulados.',
              style: TextStyle(fontSize: 11, color: SpaceTheme.warningYellow),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: SpaceTheme.cyan,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                  icon: const Icon(Icons.edit_note, size: 16),
                  label: const Text(
                    'Ingresar Datos Manualmente',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  onPressed: () =>
                      _showManualInputDialog(context, ref, astronaut),
                ),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: SpaceTheme.cyan,
                    side: const BorderSide(color: SpaceTheme.cyan),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                  icon: const Icon(Icons.tune, size: 15),
                  label: const Text(
                    'Activar Sensores',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  onPressed: () {
                    TelemetryConfigModal.show(
                      context,
                      initialAstronautId: astronaut.id,
                    );
                  },
                ),
              ],
            ),
          ] else ...[
            Text(
              isLiveStreaming
                  ? 'Recibiendo datos automáticamente de ${connectedMachines.length} sensor(es).'
                  : 'Sensores listos (${connectedMachines.length}). Activa el interruptor para recibir datos automáticamente o captura una lectura.',
              style: const TextStyle(fontSize: 11, color: Colors.white70),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: SpaceTheme.cyan,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                  icon: const Icon(Icons.sensors, size: 15),
                  label: const Text(
                    'Capturar Lectura Ahora',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  onPressed: () {
                    final count = ref
                        .read(telemetryProvider.notifier)
                        .pullAllConnectedMachines(astronaut.id);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Se recibieron paquetes de $count equipo(s) para ${astronaut.name}.',
                        ),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                ),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: SpaceTheme.cyan,
                    side: const BorderSide(color: SpaceTheme.cyan),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                  icon: const Icon(Icons.tune, size: 15),
                  label: const Text(
                    'Configurar Sensores',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  onPressed: () {
                    TelemetryConfigModal.show(
                      context,
                      initialAstronautId: astronaut.id,
                    );
                  },
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _formatContextAverage(
    List<TelemetrySamplePoint> samples,
    ActivityContext context,
    String unit, {
    int decimals = 1,
  }) {
    final values = samples
        .where((s) => s.context == context && s.isValid && s.value != null)
        .map((s) => s.value!)
        .toList();
    if (values.isEmpty) {
      return 'Media (${context.label}): Sin datos disponibles';
    }
    final avg = values.reduce((a, b) => a + b) / values.length;
    return 'Media (${context.label}): ${avg.toStringAsFixed(decimals)} $unit (n=${values.length})';
  }

  String _heartRateContextTip(ActivityContext context) {
    switch (context) {
      case ActivityContext.rest:
        return 'En reposo, una referencia general en adultos es 60–100 lpm (personas muy entrenadas pueden tener menos).';
      case ActivityContext.sleep:
        return 'Durante el sueño suele bajar respecto al día. Se compara con tus propias noches anteriores.';
      case ActivityContext.physicalActivity:
        return 'Durante el ejercicio es normal que suba bastante; nunca se evalúa con los límites de reposo.';
      case ActivityContext.unknown:
        return 'Sin contexto definido es difícil interpretar el pulso. Selecciona si estás en reposo, sueño o actividad.';
    }
  }

  Widget _buildEvaluatedMetricCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required EvaluationResult evaluation,
    required String metadataTag,
    required int decimals,
    required VoidCallback onTap,
    String? customValueText,
  }) {
    final Color statusColor;
    switch (evaluation.severity) {
      case EvaluationSeverity.noData:
        statusColor = Colors.white54;
      case EvaluationSeverity.descriptive:
        statusColor = Colors.greenAccent;
      case EvaluationSeverity.informativeNotice:
        statusColor = SpaceTheme.warningYellow;
      case EvaluationSeverity.operationalAlert:
        statusColor = SpaceTheme.dangerRed;
    }

    final displayValue = evaluation.hasData
        ? (customValueText ??
            '${evaluation.value!.toStringAsFixed(decimals)} ${evaluation.unit}')
        : 'Sin datos';

    final criterion = evaluation.appliedCriterion;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: SpaceTheme.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: evaluation.severity == EvaluationSeverity.operationalAlert
              ? SpaceTheme.dangerRed
              : (evaluation.severity == EvaluationSeverity.informativeNotice
                  ? SpaceTheme.warningYellow.withValues(alpha: 0.7)
                  : Colors.white12),
          width: 1.1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: iconColor.withValues(alpha: 0.18),
                    child: Icon(icon, color: iconColor),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          'Contexto: ${evaluation.context.label} • ${evaluation.severity.label}',
                          style: TextStyle(fontSize: 11, color: statusColor),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    displayValue,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.chevron_right,
                    size: 18,
                    color: Colors.white38,
                  ),
                ],
              ),
            const SizedBox(height: 8),
            Text(
              evaluation.summary,
              style: const TextStyle(fontSize: 12, color: Colors.white70),
            ),
            const SizedBox(height: 4),
            Text(
              metadataTag,
              style: const TextStyle(fontSize: 10, color: Colors.white38),
              overflow: TextOverflow.ellipsis,
            ),
            if (criterion != null) ...[
              const SizedBox(height: 2),
              Text(
                'Criterio: ${criterion.source} (v${criterion.version})',
                style: const TextStyle(fontSize: 10, color: Colors.white38),
              ),
            ],
            ],
          ),
        ),
      ),
    );
  }

  /// Banner con la información del astronauta actualmente activo
  Widget _buildAstronautHeader(BuildContext context, AstronautProfile astronaut) {
    final statusColor = astronaut.riskLevel == CrewRiskLevel.critical
        ? SpaceTheme.dangerRed
        : (astronaut.riskLevel == CrewRiskLevel.warning
            ? SpaceTheme.warningYellow
            : SpaceTheme.green);

    return Container(
      padding: const EdgeInsets.all(14.0),
      decoration: BoxDecoration(
        color: SpaceTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: astronaut.riskLevel == CrewRiskLevel.critical
              ? SpaceTheme.dangerRed
              : SpaceTheme.cyan.withValues(alpha: 0.4),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: statusColor.withValues(alpha: 0.2),
            child: Text(
              astronaut.avatarInitials,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: statusColor,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        astronaut.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: SpaceTheme.cyan.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        astronaut.callsign,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: SpaceTheme.cyan,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${astronaut.role} • ${astronaut.currentZone}',
                  style: const TextStyle(fontSize: 12, color: Colors.white70),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  'Edad: ${astronaut.age} años | GS: ${astronaut.bloodType}',
                  style: const TextStyle(fontSize: 11, color: Colors.white54),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Banner que se activa si el astronauta tiene un estado de advertencia o crítico
  Widget _buildRiskBanner(AstronautProfile astronaut) {
    final isCritical = astronaut.riskLevel == CrewRiskLevel.critical;
    final color = isCritical ? SpaceTheme.dangerRed : SpaceTheme.warningYellow;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isCritical ? Icons.emergency : Icons.warning_amber_rounded,
                color: color,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  astronaut.riskTitle,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            astronaut.riskDescription,
            style: const TextStyle(fontSize: 12, color: Colors.white),
          ),
          if (astronaut.activeAlerts.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: astronaut.activeAlerts.map((alert) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    alert,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildManualAssessmentButton(
    BuildContext context,
    WidgetRef ref,
    AstronautProfile astronaut,
  ) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: SpaceTheme.surface,
        foregroundColor: SpaceTheme.cyan,
        side: const BorderSide(color: SpaceTheme.cyan, width: 1.2),
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      icon: const Icon(Icons.touch_app),
      label: const Text(
        'Modo Medición Manual de Emergencia (Sin Sensores)',
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
      ),
      onPressed: () => _showManualInputDialog(context, ref, astronaut),
    );
  }

  void _showManualInputDialog(
    BuildContext context,
    WidgetRef ref,
    AstronautProfile astronaut,
  ) {
    final hrController = TextEditingController(
      text: astronaut.vitals.heartRate.toInt().toString(),
    );
    final respController = TextEditingController(
      text: astronaut.vitals.respiratoryRate.toInt().toString(),
    );
    final capController = TextEditingController(
      text: astronaut.vitals.capillaryRefillSeconds.toStringAsFixed(1),
    );
    final tempController = TextEditingController(
      text: astronaut.vitals.bodyTemp.toStringAsFixed(1),
    );

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: SpaceTheme.surface,
          title: Row(
            children: [
              const Icon(Icons.favorite, color: Colors.redAccent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Medición Manual (${astronaut.callsign})',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '• Pulso: Coloca índice y medio en carótida o muñeca 15s y multiplica por 4.\n'
                  '• Respiración: Cuenta ciclos respiratorios en 30s y multiplica por 2.\n'
                  '• Llenado Capilar: Presiona una uña 5s y mide recuperación (< 2.0s).',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: hrController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Frecuencia Cardíaca (lpm)',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: respController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Frecuencia Respiratoria (rpm)',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: capController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Tiempo de Llenado Capilar (s)',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: tempController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Temperatura Corporal (°C)',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text(
                'Cancelar',
                style: TextStyle(color: Colors.white60),
              ),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: SpaceTheme.cyan,
                foregroundColor: Colors.black,
              ),
              onPressed: () {
                final newHr =
                    double.tryParse(hrController.text.replaceAll(',', '.')) ??
                        astronaut.vitals.heartRate;
                final newResp =
                    double.tryParse(respController.text.replaceAll(',', '.')) ??
                        astronaut.vitals.respiratoryRate;
                final newCap =
                    double.tryParse(capController.text.replaceAll(',', '.')) ??
                        astronaut.vitals.capillaryRefillSeconds;
                final newTemp =
                    double.tryParse(tempController.text.replaceAll(',', '.')) ??
                        astronaut.vitals.bodyTemp;

                final manualRecord = VitalsRecord(
                  timestamp: DateTime.now(),
                  astronautId: astronaut.id,
                  source: 'manual',
                  deviceId: 'MANUAL-CREW-ASSESSMENT',
                  device: 'Evaluación Manual de Tripulación',
                  protocol: 'Ingreso Manual Offline',
                  measurementMethod:
                      'Registro manual por tripulante (pulsioxímetro / baumanómetro / termómetro)',
                  activityState: 'emergency_triage',
                  signalQuality: 'manual_verified',
                  recordType: 'manual',
                  algorithm: 'DirectCrewEntry v1.0',
                  criterionReference: 'NASA-STD-3001 Vol.2 Vital Limits',
                  heartRate: newHr.clamp(30.0, 220.0),
                  systolicBP: astronaut.vitals.systolicBP,
                  diastolicBP: astronaut.vitals.diastolicBP,
                  spO2: astronaut.vitals.spO2,
                  bodyTemp: newTemp.clamp(32.0, 42.0),
                  bloodGlucose: astronaut.vitals.bloodGlucose,
                  respiratoryRate: newResp.clamp(6.0, 60.0),
                  capillaryRefillSeconds: newCap.clamp(0.5, 10.0),
                );

                ref
                    .read(crewMembersProvider.notifier)
                    .updateVitals(astronaut.id, manualRecord);
                Navigator.of(ctx).pop();
              },
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );
  }
}

class _CircumstantialMission {
  final String id;
  final String badgeLabel;
  final String title;
  final String actionLabel;
  final String notificationText;
  final int xpReward;
  final Color accentColor;
  final IconData icon;

  const _CircumstantialMission({
    required this.id,
    required this.badgeLabel,
    required this.title,
    required this.actionLabel,
    required this.notificationText,
    required this.xpReward,
    required this.accentColor,
    required this.icon,
  });
}

/// Panel de gamificación y alertas preventivas activadas por circunstancias reales
/// (CO₂ local, fluid shift por Día de Misión, esfuerzo ARED/CEVIS o sueño bimodal).
class _CircumstantialGamificationCard extends ConsumerStatefulWidget {
  final String astronautId;
  final VitalsRecord vitals;
  final ActivityContext activeContext;
  final SpaceOperationalEnvironment activeEnvironment;
  final String actigraphyJustification;

  const _CircumstantialGamificationCard({
    required this.astronautId,
    required this.vitals,
    required this.activeContext,
    required this.activeEnvironment,
    required this.actigraphyJustification,
  });

  @override
  ConsumerState<_CircumstantialGamificationCard> createState() =>
      _CircumstantialGamificationCardState();
}

class _CircumstantialGamificationCardState
    extends ConsumerState<_CircumstantialGamificationCard> {
  final Map<String, Map<String, int>> _completedXpByAstronaut = {};
  int _selectedMissionIdx = 0;

  List<_CircumstantialMission> _evaluateActiveMissions() {
    final v = widget.vitals;
    final missions = <_CircumstantialMission>[];

    if (v.localCo2MmHg >= 3.5) {
      missions.add(_CircumstantialMission(
        id: 'co2_pocket_${v.localCo2MmHg.toStringAsFixed(1)}',
        badgeLabel: 'RIESGO HIPERCAPNIA 0g',
        title:
            'Riesgo de Hipercapnia por Convección Nula (CO₂ ${v.localCo2MmHg.toStringAsFixed(1)} mmHg)',
        actionLabel: 'Iniciar Cuestionario y Contramedida CO₂ (+60 XP)',
        notificationText:
            'Contramedida CO₂ y triaje adaptativo archivados (+60 XP).',
        xpReward: 60,
        accentColor: SpaceTheme.dangerRed,
        icon: Icons.air,
      ));
    }

    if (v.missionDay <= 7 || v.calibratedHydrationIndex < 72.0) {
      missions.add(_CircumstantialMission(
        id: 'fluid_shift_d${v.missionDay}',
        badgeLabel: 'FLUID SHIFT / SANS',
        title:
            'Adaptación 0g (Día ${v.missionDay}) • Riesgo Hipovolemia y SANS',
        actionLabel:
            'Abrir Cuestionario Neuro-Ocular e Hidratación (+50 XP)',
        notificationText:
            'Control Fluid Shift / SANS archivado en bitácora (+50 XP).',
        xpReward: 50,
        accentColor: SpaceTheme.warningYellow,
        icon: Icons.water_drop,
      ));
    }

    if (widget.activeContext == ActivityContext.physicalActivity) {
      missions.add(const _CircumstantialMission(
        id: 'ared_cevis_cooldown',
        badgeLabel: 'CONTRAMEDIDA ACTIVA',
        title: 'Contramedida ARED / CEVIS / EVA • Umbral Dinámico Activo',
        actionLabel:
            'Completar Evaluación Post-Esfuerzo y Recuperación (+45 XP)',
        notificationText:
            'Evaluación metabólica post-esfuerzo archivada (+45 XP).',
        xpReward: 45,
        accentColor: SpaceTheme.cyan,
        icon: Icons.fitness_center,
      ));
    }

    if (widget.activeContext == ActivityContext.sleep || v.hrvRmssdMs < 42.0) {
      missions.add(_CircumstantialMission(
        id: 'sleep_bimodal_guard',
        badgeLabel: 'PROTECCIÓN CIRCADIANA',
        title:
            'Actigrafía Bimodal (${v.accelerometryRmsG.toStringAsFixed(3)} g) • Protección Circadiana',
        actionLabel: 'Responder Chequeo Circadiano POMS / Sueño (+40 XP)',
        notificationText:
            'Chequeo circadiano y POMS guardado en bitácora (+40 XP).',
        xpReward: 40,
        accentColor: Colors.indigoAccent,
        icon: Icons.bedtime,
      ));
    }

    if (missions.isEmpty) {
      missions.add(const _CircumstantialMission(
        id: 'daily_nominal_check',
        badgeLabel: 'PREVENCIÓN NOMINAL',
        title: 'Condiciones Ambientales y Fisiológicas Estables en Cabina',
        actionLabel: 'Completar Cuestionario Periódico de Control (+35 XP)',
        notificationText:
            'Control periódico archivado • Insignia Vigilancia Nominal (+35 XP).',
        xpReward: 35,
        accentColor: SpaceTheme.green,
        icon: Icons.verified_user,
      ));
    }

    return missions;
  }

  ({
    String q1Title,
    List<String> q1Options,
    String q2TitleNominal,
    List<String> q2OptionsNominal,
    String q2TitleSymptomatic,
    List<String> q2OptionsSymptomatic,
    String q3Title,
    List<String> q3Options,
    String suggestedBadge,
  }) _questionnaireSchemaForMission(_CircumstantialMission mission) {
    if (mission.id.startsWith('co2_pocket')) {
      return (
        q1Title:
            '1. Presencia de síntomas atribuibles a CO₂ (${widget.vitals.localCo2MmHg.toStringAsFixed(1)} mmHg) en ${widget.activeEnvironment.shortLabel}:',
        q1Options: const [
          'Asintomático (ventilación dispersa adecuadamente)',
          'Fatiga leve o embotamiento sin cefalea',
          'Cefalea frontal pulsátil, disnea o náuseas',
        ],
        q2TitleNominal:
            '2. Verificación preventiva ECLSS y vigilancia cognitiva (PVT-B):',
        q2OptionsNominal: const [
          'Ventilación forzada verificada • PVT-B nominal (<500 ms)',
          'Cambio de zona programado con ventilador portátil',
          'Pendiente de inspección de filtros de CO₂',
        ],
        q2TitleSymptomatic:
            '2. Evaluación de Severidad de CO₂ (1-10) y Exposición a Gases:',
        q2OptionsSymptomatic: const [
          'Molestia leve (2-3/10) • Sin fuga de CH₄ ni humo',
          'Moderada (4-6/10) • Mejora parcial al ventilar zona',
          'Alta (>=7/10) • Requiere SpO₂ + evaluación CMO urgente',
        ],
        q3Title: '3. Hardware de confirmación y contramedida registrada:',
        q3Options: const [
          'Ventilación forzada activa + pulsioximetría FDA SpO₂',
          'Rotación de módulo + Bio-Monitor (FR / HRV)',
          'Confirmación bioquímica Abbott i-STAT Alinity',
        ],
        suggestedBadge: 'Vigilancia Nominal',
      );
    }

    if (mission.id.startsWith('fluid_shift')) {
      return (
        q1Title:
            '1. Cribado neuro-ocular (ToF/SANS) y percepción de congestión cefálica:',
        q1Options: const [
          'Distancia de lectura ToF estable • Sin alteración visual',
          'Congestión facial leve sin cambio refractivo en tableta',
          'Visión cercana borrosa (+0.5 D o más) / presión retroocular',
        ],
        q2TitleNominal:
            '2. Pauta hídrica y control bioimpedancia Bodystat BIS:',
        q2OptionsNominal: const [
          'Hidratación isotónica al 100% + registro Bodystat BIS',
          'Reposición parcial; se completará en la siguiente hora',
          'Restricción calórica / baja ingesta reportada hoy',
        ],
        q2TitleSymptomatic:
            '2. Protocolo Clínico SANS: escala y evolución visual:',
        q2OptionsSymptomatic: const [
          'Cambio leve en distancia ToF • Sin escotomas ni dolor',
          'Cefalea leve (3-5/10) + desplazamiento hiperópico en pantalla',
          'Déficit visual o dolor (>=6/10) • Solicitar oftalmoscopia / ONSD',
        ],
        q3Title: '3. Método instrumental utilizado en el control actual:',
        q3Options: const [
          'Sensor ToF pasivo + optotipos + Bodystat BIS',
          'Fondo de ojo digital + medición ToF en tableta de misión',
          'Ecografía ocular ONSD (Butterfly iQ+) + i-STAT',
        ],
        suggestedBadge: 'Visión de Águila Espacial',
      );
    }

    if (mission.id == 'ared_cevis_cooldown') {
      return (
        q1Title:
            '1. Estado físico y térmico durante/tras carga en ${widget.activeEnvironment.shortLabel}:',
        q1Options: const [
          'Esfuerzo tolerado • Recuperación cardíaca progresiva nominal',
          'Fatiga muscular localizada o sobrecarga térmica en LCVG',
          'Mareo ortostático, dolor agudo articular o calambres',
        ],
        q2TitleNominal:
            '2. Contramedida musculoesquelética (ARED/QUS) e ingesta metabólica:',
        q2OptionsNominal: const [
          'Sesión completa + electrolitos y carbohidratos ingeridos',
          'Sesión completada; reposición hídrica en curso',
          'Sesión abreviada por agenda de cabina',
        ],
        q2TitleSymptomatic:
            '2. Protocolo Biomecánico & Metabólico en Misión:',
        q2OptionsSymptomatic: const [
          'Dolor o fatiga leve (2-3/10) sin traumatismo inercial IMU',
          'Sobrecarga moderada (4-6/10) o hipoglucemia sospechada (<75 mg/dL)',
          'Trauma inercial / dolor intenso (>=7/10) • Activar protocolo FAST',
        ],
        q3Title: '3. Equipo de respaldo y validación clínica:',
        q3Options: const [
          'Bio-Monitor (ECG/PPG) + Draeger Double Sensor térmico',
          'Densitometría QUS (SOS/BUA) + Abbott i-STAT (Ca²⁺/glucosa)',
          'IMU triaxial traje EVA + tonometría EPM Cardiocavity',
        ],
        suggestedBadge: 'Estructura Ósea Invulnerable',
      );
    }

    if (mission.id == 'sleep_bimodal_guard') {
      return (
        q1Title:
            '1. Estado psicoemocional POMS/PANAS y calidad de sueño por actigrafía:',
        q1Options: const [
          'Descanso reparador • Ánimo estable y vigor conservado',
          'Sueño fragmentado leve por ciclo orbital / ruido cabina',
          'Insomnio persistente, irritabilidad o lapsos PVT-B >500 ms',
        ],
        q2TitleNominal:
            '2. Higiene circadiana e iluminación de módulo verificadas:',
        q2OptionsNominal: const [
          'Luz azul atenuada + anclaje de saco + HRV nocturna estable',
          'Anclaje verificado; ajuste de horario circadiano pendiente',
          'Turno rotativo con exposición lumínica irregular',
        ],
        q2TitleSymptomatic:
            '2. Protocolo Circadiano & Rendimiento Cognitivo:',
        q2OptionsSymptomatic: const [
          'Fatiga leve (2-3/10) sin error en tareas operativas',
          'Somnolencia moderada (4-6/10) • Requiere descanso programado',
          'Deterioro cognitivo significativo • Restringir EVA / acoplamiento',
        ],
        q3Title: '3. Instrumentación que respalda el registro:',
        q3Options: const [
          'Actígrafo de muñeca (Cole-Kripke) + Bio-Monitor HRV nocturno',
          'PVT-B de fondo en tableta + cuestionario POMS/PANAS',
          'Pupilometría infrarroja pasiva (NPi / PLR) + oximetría nocturna',
        ],
        suggestedBadge: 'Vigilancia Nominal',
      );
    }

    return (
      q1Title:
          '1. Autochequeo multiorgánico periódico en ${widget.activeEnvironment.shortLabel}:',
      q1Options: const [
        'Sin síntomas • Todos los dominios fisiológicos estables',
        'Molestia menor adaptativa (sed, fatiga leve o congestión nasal)',
        'Síntoma focal nuevo que amerita seguimiento adaptativo',
      ],
      q2TitleNominal:
          '2. Cumplimiento de controles preventivos periódicos (Doc 2):',
      q2OptionsNominal: const [
        'Balance hídrico, optotipos/ToF y actividad ARED/CEVIS al día',
        'Control ocular y metabólico i-STAT programado hoy',
        'Requiere recordatorio para hidratación isotónica',
      ],
      q2TitleSymptomatic:
          '2. Triaje Clínico Inicial de Síntomas (Severidad 1-10):',
      q2OptionsSymptomatic: const [
        'Gravedad baja (1-3/10) • Sin exposición a regolito ni gases',
        'Gravedad moderada (4-6/10) • Monitoreo cada 2 h con i-STAT',
        'Gravedad alta (>=7/10) • Escalado a Oficial Médico (CMO)',
      ],
      q3Title: '3. Panel instrumental asociado al registro:',
      q3Options: const [
        'Bio-Monitor (CSA) + Abbott i-STAT Alinity POCT',
        'ToF ocular + QUS óseo + Bodystat BIS',
        'EPM Cardiocavity + Draeger Double Sensor',
      ],
      suggestedBadge: 'Equilibrio Metabólico Perfecto',
    );
  }

  Future<void> _showAdaptiveMissionQuestionnaireModal(
    _CircumstantialMission mission,
    Map<String, int> completedMap,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final schema = _questionnaireSchemaForMission(mission);
    int step = 0;
    int q1Index = 0;
    int q2Index = 0;
    int q3Index = 0;
    final noteController = TextEditingController();

    final submitted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final isSymptomatic = q1Index > 0;
            final q2Title =
                isSymptomatic ? schema.q2TitleSymptomatic : schema.q2TitleNominal;
            final q2Options = isSymptomatic
                ? schema.q2OptionsSymptomatic
                : schema.q2OptionsNominal;

            Widget buildOptionList({
              required List<String> options,
              required int currentIndex,
              required void Function(int idx) onSelect,
            }) {
              return Column(
                children: List.generate(options.length, (i) {
                  final chosen = currentIndex == i;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => setModalState(() => onSelect(i)),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(11),
                        decoration: BoxDecoration(
                          color: chosen
                              ? mission.accentColor.withValues(alpha: 0.16)
                              : SpaceTheme.card,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: chosen ? mission.accentColor : Colors.white12,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              chosen
                                  ? Icons.radio_button_checked
                                  : Icons.radio_button_off,
                              size: 16,
                              color:
                                  chosen ? mission.accentColor : Colors.white38,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                options[i],
                                style: TextStyle(
                                  fontSize: 12,
                                  color: chosen ? Colors.white : Colors.white70,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              );
            }

            return AlertDialog(
              backgroundColor: SpaceTheme.surface,
              title: Row(
                children: [
                  Icon(mission.icon, color: mission.accentColor, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Cuestionario Adaptativo • Paso ${step + 1}/3',
                      style: const TextStyle(fontSize: 15, color: Colors.white),
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LinearProgressIndicator(
                      value: (step + 1) / 3,
                      minHeight: 4,
                      backgroundColor: Colors.white12,
                      color: mission.accentColor,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Entorno: ${widget.activeEnvironment.label} • Día ${widget.vitals.missionDay}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: SpaceTheme.cyan,
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (step == 0) ...[
                      Text(
                        schema.q1Title,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      buildOptionList(
                        options: schema.q1Options,
                        currentIndex: q1Index,
                        onSelect: (idx) {
                          q1Index = idx;
                          q2Index = 0;
                        },
                      ),
                    ] else if (step == 1) ...[
                      Text(
                        q2Title,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      buildOptionList(
                        options: q2Options,
                        currentIndex: q2Index,
                        onSelect: (idx) => q2Index = idx,
                      ),
                    ] else ...[
                      Text(
                        schema.q3Title,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      buildOptionList(
                        options: schema.q3Options,
                        currentIndex: q3Index,
                        onSelect: (idx) => q3Index = idx,
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: noteController,
                        style:
                            const TextStyle(fontSize: 12, color: Colors.white),
                        decoration: const InputDecoration(
                          isDense: true,
                          labelText: 'Nota médica o comentario de turno (opcional)',
                          labelStyle:
                              TextStyle(fontSize: 11, color: Colors.white54),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: SpaceTheme.green.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: SpaceTheme.green.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Text(
                          'Insignia al completar: ${schema.suggestedBadge} (+${mission.xpReward} XP)',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: SpaceTheme.green,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    if (step > 0) {
                      setModalState(() => step -= 1);
                    } else {
                      Navigator.of(dialogCtx).pop(false);
                    }
                  },
                  child: Text(step > 0 ? 'Atrás' : 'Cancelar'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: mission.accentColor,
                    foregroundColor: Colors.black,
                  ),
                  onPressed: () {
                    if (step < 2) {
                      setModalState(() => step += 1);
                    } else {
                      Navigator.of(dialogCtx).pop(true);
                    }
                  },
                  child: Text(
                    step < 2 ? 'Siguiente' : 'Finalizar y Guardar (+${mission.xpReward} XP)',
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    if (submitted != true || !mounted) {
      noteController.dispose();
      return;
    }

    final isSymptomatic = q1Index > 0;
    final q2Answer = isSymptomatic
        ? schema.q2OptionsSymptomatic[q2Index]
        : schema.q2OptionsNominal[q2Index];
    final q1Answer = schema.q1Options[q1Index];
    final q3Answer = schema.q3Options[q3Index];
    final extraNote = noteController.text.trim();
    noteController.dispose();

    final entry = ClinicalMissionLogEntry(
      id: 'MIS-${DateTime.now().millisecondsSinceEpoch}',
      astronautId: widget.astronautId,
      timestamp: DateTime.now(),
      missionDay: widget.vitals.missionDay,
      environment: widget.activeEnvironment,
      category: mission.badgeLabel,
      title: mission.title,
      summary:
          '$q1Answer • $q2Answer${extraNote.isNotEmpty ? " ($extraNote)" : ""}',
      answers: {
        'Evaluación inicial': q1Answer,
        isSymptomatic ? 'Triaje adaptativo (Ada)' : 'Prevención / hábito':
            q2Answer,
        'Hardware confirmatorio': q3Answer,
        if (extraNote.isNotEmpty) 'Observación': extraNote,
      },
      badgeEarned: schema.suggestedBadge,
      xpAwarded: mission.xpReward,
    );

    ref.read(clinicalMissionLogsProvider.notifier).addEntry(entry);

    setState(() {
      completedMap[mission.id] = mission.xpReward;
    });

    messenger.showSnackBar(
      SnackBar(
        content: Text(
          '${mission.notificationText} • Insignia: ${schema.suggestedBadge}',
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final completedMap =
        _completedXpByAstronaut.putIfAbsent(widget.astronautId, () => {});
    final activeMissions = _evaluateActiveMissions();
    final safeIdx = _selectedMissionIdx.clamp(0, activeMissions.length - 1);
    final currentMission = activeMissions[safeIdx];
    final isDone = completedMap.containsKey(currentMission.id);

    final displayXp =
        completedMap.values.fold<int>(0, (sum, xp) => sum + xp);
    final completedActiveCount =
        activeMissions.where((m) => completedMap.containsKey(m.id)).length;
    final progressValue =
        (completedActiveCount / activeMissions.length).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: SpaceTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: currentMission.accentColor.withValues(alpha: 0.55),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(currentMission.icon,
                  color: currentMission.accentColor, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  currentMission.badgeLabel,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.6,
                    color: currentMission.accentColor,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: SpaceTheme.card,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white12),
                ),
                child: Text(
                  'Día ${widget.vitals.missionDay} • $completedActiveCount/${activeMissions.length} • $displayXp XP',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: SpaceTheme.cyan,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            currentMission.title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            widget.actigraphyJustification,
            style: const TextStyle(fontSize: 11, color: Colors.white60),
          ),
          if (activeMissions.length > 1) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: List.generate(activeMissions.length, (i) {
                final m = activeMissions[i];
                final selected = i == safeIdx;
                final done = completedMap.containsKey(m.id);
                return InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => setState(() => _selectedMissionIdx = i),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: selected
                          ? m.accentColor.withValues(alpha: 0.2)
                          : SpaceTheme.card,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: selected ? m.accentColor : Colors.white12,
                      ),
                    ),
                    child: Text(
                      '${done ? "✓ " : ""}${m.badgeLabel}',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight:
                            selected ? FontWeight.bold : FontWeight.normal,
                        color: selected ? Colors.white : Colors.white60,
                      ),
                    ),
                  ),
                );
              }),
            ),
          ],
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progressValue == 0.0 ? 0.12 : progressValue,
              minHeight: 5,
              backgroundColor: Colors.white12,
              color: progressValue >= 1.0
                  ? SpaceTheme.green
                  : currentMission.accentColor,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor:
                    isDone ? SpaceTheme.green : currentMission.accentColor,
                side: BorderSide(
                  color: isDone ? SpaceTheme.green : currentMission.accentColor,
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              icon: Icon(
                isDone ? Icons.check_circle : Icons.quiz_outlined,
                size: 16,
              ),
              label: Text(
                isDone
                    ? 'Cuestionario Completado y Archivado (+${currentMission.xpReward} XP)'
                    : currentMission.actionLabel,
                style:
                    const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
              ),
              onPressed: isDone
                  ? null
                  : () => _showAdaptiveMissionQuestionnaireModal(
                        currentMission,
                        completedMap,
                      ),
            ),
          ),
        ],
      ),
    );
  }
}
