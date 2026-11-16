import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/medical_thresholds.dart';
import '../../../core/theme/space_theme.dart';
import '../../../core/widgets/mission_trend_card.dart';
import '../data/vitals_sample_repository.dart';

/// Indicador que se puede graficar en la tendencia de signos vitales.
enum VitalsTrendMetric {
  bloodPressure('Presión', 'mmHg', 0),
  heartRate('Frec. cardiaca', 'bpm', 0),
  bodyTemp('Temperatura', '°C', 1),
  spO2('SpO₂', '%', 0),
  bloodGlucose('Glucosa', 'mg/dL', 0);

  const VitalsTrendMetric(this.label, this.unit, this.decimals);
  final String label;
  final String unit;
  final int decimals;
}

/// Tendencia de los signos vitales del astronauta durante la misión, leída
/// de `DB/samples/vitals/`.
class VitalsTrendCard extends ConsumerStatefulWidget {
  const VitalsTrendCard({super.key, required this.astronautId});
  final String astronautId;

  @override
  ConsumerState<VitalsTrendCard> createState() => _VitalsTrendCardState();
}

class _VitalsTrendCardState extends ConsumerState<VitalsTrendCard> {
  VitalsTrendMetric _metric = VitalsTrendMetric.bloodPressure;

  @override
  Widget build(BuildContext context) {
    final sample = ref.watch(vitalsSampleProvider);
    return MissionTrendCard(
      icon: Icons.show_chart,
      title: 'Tendencia en la misión (180 días)',
      data: sample,
      builder: (context) {
        final points = sample.requireValue
            .where((p) => p.astronautId == widget.astronautId)
            .toList();
        final events = points.where((p) => p.event.isNotEmpty).toList();
        final landing = points.where((p) => p.orthostaticIntolerance).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final m in VitalsTrendMetric.values)
                  ChoiceChip(
                    label: Text(m.label, style: const TextStyle(fontSize: 12)),
                    selected: m == _metric,
                    visualDensity: VisualDensity.compact,
                    onSelected: (_) => setState(() => _metric = m),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            MissionTrendChart(
              series: _series(points),
              references: _references(),
              unit: _metric.unit,
              decimals: _metric.decimals,
            ),
            const SizedBox(height: 8),
            Text(_explanation(),
                style: const TextStyle(color: Colors.white70, fontSize: 12)),
            if (landing.isNotEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text(
                  'Día 181 (aterrizaje): intolerancia al estar de pie. '
                  'Levantarse despacio y con ayuda.',
                  style: TextStyle(color: SpaceTheme.warningYellow, fontSize: 12),
                ),
              ),
            for (final e in events)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'Día ${e.missionDay}: ${_eventLabel(e.event)}',
                  style: const TextStyle(
                      color: SpaceTheme.dangerRed, fontSize: 12),
                ),
              ),
          ],
        );
      },
    );
  }

  List<TrendSeries> _series(List<VitalsSamplePoint> points) {
    List<FlSpot> spots(double Function(VitalsSamplePoint) value) => [
          for (final p in points) FlSpot(p.missionDay.toDouble(), value(p)),
        ];
    return switch (_metric) {
      VitalsTrendMetric.bloodPressure => [
          TrendSeries('Sistólica', Colors.redAccent, spots((p) => p.systolicBP)),
          TrendSeries('Diastólica', SpaceTheme.cyan, spots((p) => p.diastolicBP)),
        ],
      VitalsTrendMetric.heartRate => [
          TrendSeries('Frecuencia cardiaca', Colors.redAccent,
              spots((p) => p.heartRate)),
        ],
      VitalsTrendMetric.bodyTemp => [
          TrendSeries('Temperatura central', Colors.orangeAccent,
              spots((p) => p.bodyTemp)),
        ],
      VitalsTrendMetric.spO2 => [
          TrendSeries('SpO₂', SpaceTheme.cyan, spots((p) => p.spO2)),
        ],
      VitalsTrendMetric.bloodGlucose => [
          TrendSeries('Glucosa', SpaceTheme.neonPurple,
              spots((p) => p.bloodGlucose)),
        ],
    };
  }

  List<TrendReference> _references() => switch (_metric) {
        VitalsTrendMetric.bloodPressure => const [
            TrendReference(MedicalThresholds.maxSystolicBP,
                'Sistólica alta (130)', SpaceTheme.warningYellow),
            TrendReference(MedicalThresholds.minSystolicBP,
                'Sistólica baja (90)', SpaceTheme.dangerRed),
          ],
        VitalsTrendMetric.heartRate => const [
            TrendReference(MedicalThresholds.maxHeartRate, 'Taquicardia (100)',
                SpaceTheme.warningYellow),
          ],
        VitalsTrendMetric.bodyTemp => const [
            TrendReference(38.0, 'Fiebre (38 °C)', SpaceTheme.dangerRed),
          ],
        VitalsTrendMetric.spO2 => const [
            TrendReference(MedicalThresholds.minSpO2, 'SpO₂ baja (94 %)',
                SpaceTheme.dangerRed),
          ],
        VitalsTrendMetric.bloodGlucose => const [
            TrendReference(140, 'Glucosa alta (140)', SpaceTheme.warningYellow),
            TrendReference(70, 'Glucosa baja (70)', SpaceTheme.dangerRed),
          ],
      };

  String _explanation() => switch (_metric) {
        VitalsTrendMetric.bloodPressure =>
          'En microgravedad la presión baja unos 8/9 mmHg y se estabiliza en '
              '~2 semanas. Es lo esperado (Norsk 2015).',
        VitalsTrendMetric.heartRate =>
          'En reposo la frecuencia cardiaca no cambia en vuelo (Norsk 2015).',
        VitalsTrendMetric.bodyTemp =>
          'La temperatura central sube ~1 °C en los primeros 2,5 meses. Es un '
              'efecto conocido del vuelo, no fiebre (Stahn 2017).',
        VitalsTrendMetric.spO2 =>
          'La cabina mantiene presión de nivel del mar: la SpO₂ debe seguir '
              'en 96–100 %.',
        VitalsTrendMetric.bloodGlucose =>
          'Valores previos al vuelo medidos en la tripulación de Inspiration4 '
              '(NASA OSDR, OSD-575).',
      };

  String _eventLabel(String event) => switch (event) {
        'post_eva_hypoxia' => 'hipoxia tras la caminata espacial',
        'radiation_prodrome' => 'síntomas tras la tormenta solar',
        'febrile_infection' => 'infección con fiebre',
        'dehydration' => 'deshidratación',
        'hypertensive_crisis' => 'crisis hipertensiva',
        _ => event,
      };
}
