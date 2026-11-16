import 'dart:async';
import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:astramed/core/constants/medical_thresholds.dart';
import 'package:astramed/features/01_general_health/models/vitals_record.dart';
import 'package:astramed/features/03_microgravity/presentation/cockpit_widgets/cockpit_card.dart';
import 'package:astramed/features/crew/models/astronaut_profile.dart';
import 'package:astramed/features/crew/presentation/providers/crew_provider.dart';
import 'package:astramed/features/telemetry/presentation/providers/telemetry_provider.dart';

AstronautProfile? _target(WidgetRef ref, String? id) {
  if (id == null) return ref.watch(selectedAstronautProvider);
  for (final astronaut in ref.watch(crewMembersProvider)) {
    if (astronaut.id == id) return astronaut;
  }
  return null;
}

class VitalsTrendCockpitCard extends ConsumerStatefulWidget {
  const VitalsTrendCockpitCard({super.key, this.astronautId, required this.onDismiss});
  final String? astronautId;
  final VoidCallback onDismiss;
  @override
  ConsumerState<VitalsTrendCockpitCard> createState() => _VitalsTrendState();
}

class _VitalsTrendState extends ConsumerState<VitalsTrendCockpitCard> {
  int _metric = 0;
  @override
  Widget build(BuildContext context) {
    final astronaut = _target(ref, widget.astronautId);
    final logs = ref.watch(telemetryProvider).recentLogs;
    if (astronaut == null) return const Text('Crew member unavailable');
    final spec = _metrics[_metric];
    final packets = logs.where((p) => p.astronautId == astronaut.id &&
      p.metrics[spec.key] is num &&
      (p.metrics[spec.key] as num).toDouble().isFinite).toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    final live = packets.length >= 2;
    final current = spec.read(astronaut.vitals);
    final samples = packets.skip(math.max(0, packets.length - 12))
      .map((p) => (p.metrics[spec.key] as num).toDouble()).toList();
    // Never fabricate a historical trend when telemetry is unavailable.
    final values = live ? samples : [current, current];
    final finite = values.where((v) => v.isFinite).toList();
    if (finite.isEmpty) return const Text('No finite vital readings available');
    final low = math.min(spec.low, finite.reduce(math.min));
    final high = math.max(spec.high, finite.reduce(math.max));
    final padding = math.max((high - low) * .15, 1.0);
    return CockpitCard(title: 'Vitals Trend', onDismiss: widget.onDismiss, children: [
      Text('${astronaut.callsign} • ${astronaut.id}'),
      Text(live ? 'Live telemetry • ${samples.length} points'
        : 'Baseline preview • fewer than 2 live points; not measured history'),
      Wrap(spacing: 6, children: [
        for (var i = 0; i < _metrics.length; i++)
          ChoiceChip(label: Text(_metrics[i].label), selected: i == _metric,
            onSelected: (_) => setState(() => _metric = i)),
      ]),
      const SizedBox(height: 12),
      SizedBox(height: 190, child: LineChart(LineChartData(
        minY: low - padding, maxY: high + padding,
        minX: 0, maxX: (values.length - 1).toDouble(),
        rangeAnnotations: RangeAnnotations(horizontalRangeAnnotations: [
          HorizontalRangeAnnotation(y1: spec.low, y2: spec.high,
            color: Colors.green.withValues(alpha: .14)),
        ]),
        titlesData: const FlTitlesData(
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        lineTouchData: const LineTouchData(enabled: true),
        lineBarsData: [LineChartBarData(
          spots: [for (var i = 0; i < values.length; i++)
            if (values[i].isFinite) FlSpot(i.toDouble(), values[i])],
          color: live ? Colors.cyan : Colors.grey,
          isCurved: false, dashArray: live ? null : [5, 5],
          dotData: FlDotData(show: live),
        )],
      ))),
      Text('Current: ${current.toStringAsFixed(1)} ${spec.unit}'),
      Text('Normal band: ${spec.low}–${spec.high} ${spec.unit} • ${spec.reference}'),
    ]);
  }
}

class _Metric {
  const _Metric(this.key, this.label, this.unit, this.low, this.high, this.read,
    [this.reference = 'NASA / medical resting reference']);
  final String key, label, unit, reference;
  final double low, high;
  final double Function(VitalsRecord) read;
}

final _metrics = [
  _Metric('heartRate', 'HR', 'bpm', MedicalThresholds.minHeartRate,
    MedicalThresholds.maxHeartRate, (v) => v.heartRate),
  _Metric('spO2', 'SpO2', '%', MedicalThresholds.minSpO2, 100, (v) => v.spO2),
  _Metric('systolicBP', 'Systolic BP', 'mmHg', MedicalThresholds.minSystolicBP,
    MedicalThresholds.maxSystolicBP, (v) => v.systolicBP),
  _Metric('bodyTemp', 'Body Temp', '°C', 36, 37.2, (v) => v.bodyTemp),
  _Metric('respiratoryRate', 'Respiratory Rate', 'rpm', 12, 20, (v) => v.respiratoryRate),
  _Metric('bloodGlucose', 'Blood Glucose', 'mg/dL', 70, 100, (v) => v.bloodGlucose,
    'General adult fasting reference; meal context required, not a NASA threshold'),
];

/// Target changes replace the entire form, including timers and unsaved values.
class ManualVitalsTapCard extends ConsumerWidget {
  const ManualVitalsTapCard({super.key, this.astronautId,
    required this.onSubmit, required this.onDismiss});
  final String? astronautId;
  final ValueChanged<Map<String, dynamic>> onSubmit;
  final VoidCallback onDismiss;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final astronaut = _target(ref, astronautId);
    if (astronaut == null) return const Text('Crew member unavailable');
    return _ManualForm(key: ValueKey(astronaut.id), astronaut: astronaut,
      onSubmit: onSubmit, onDismiss: onDismiss);
  }
}

class _ManualForm extends ConsumerStatefulWidget {
  const _ManualForm({super.key, required this.astronaut,
    required this.onSubmit, required this.onDismiss});
  final AstronautProfile astronaut;
  final ValueChanged<Map<String, dynamic>> onSubmit;
  final VoidCallback onDismiss;
  @override
  ConsumerState<_ManualForm> createState() => _ManualFormState();
}

class _ManualFormState extends ConsumerState<_ManualForm> {
  late final List<TextEditingController> _fields;
  final _timers = <Timer?>[null, null, null];
  final _remaining = [0, 0];
  final _taps = [0, 0];
  final _capClock = Stopwatch();
  String? _error;
  @override
  void initState() {
    super.initState();
    final v = widget.astronaut.vitals;
    _fields = [v.heartRate, v.respiratoryRate, v.capillaryRefillSeconds, v.bodyTemp]
      .map((n) => TextEditingController(text: n.toString())).toList();
  }
  @override
  void dispose() {
    for (final timer in _timers) { timer?.cancel(); }
    _capClock.stop();
    for (final field in _fields) { field.dispose(); }
    super.dispose();
  }
  void _start(int index) {
    _timers[index]?.cancel();
    setState(() {
      _remaining[index] = index == 0 ? 15 : 30;
      _taps[index] = 0;
    });
    _timers[index] = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _remaining[index]--;
        if (_remaining[index] == 0) {
          timer.cancel();
          _fields[index].text = (_taps[index] * (index == 0 ? 4 : 2)).toString();
        }
      });
    });
  }
  void _capillary() {
    if (_capClock.isRunning) {
      _capClock.stop();
      _timers[2]?.cancel();
      setState(() => _fields[2].text = (_capClock.elapsedMilliseconds / 1000).toStringAsFixed(2));
    } else {
      _capClock..reset()..start();
      _timers[2] = Timer.periodic(const Duration(milliseconds: 100), (_) {
        setState(() {});
      });
      setState(() {});
    }
  }
  void _save() {
    final values = _fields.map((f) => double.tryParse(f.text.replaceAll(',', '.'))).toList();
    const ranges = [(30.0, 220.0), (6.0, 60.0), (0.0, 10.0), (32.0, 42.0)];
    for (var i = 0; i < values.length; i++) {
      final v = values[i];
      if (v == null || !v.isFinite || v < ranges[i].$1 || v > ranges[i].$2) {
        setState(() => _error = 'Enter finite values within HR 30–220, respiration 6–60, refill 0–10 s, temperature 32–42 °C.');
        return;
      }
    }
    // Read current vitals at save time so incoming telemetry is not overwritten.
    final astronaut = ref.read(crewMembersProvider).firstWhere((a) => a.id == widget.astronaut.id);
    final record = astronaut.vitals.copyWith(timestamp: DateTime.now(),
      source: 'manual', deviceId: 'MANUAL-CREW-ASSESSMENT',
      device: 'Crew manual assessment', protocol: 'Offline manual entry',
      measurementMethod: 'Tap-to-Count / thermometer / capillary stopwatch',
      recordType: 'manual', signalQuality: 'manual_verified',
      algorithm: 'DirectCrewEntry v1.0',
      heartRate: values[0]!, respiratoryRate: values[1]!,
      capillaryRefillSeconds: values[2]!, bodyTemp: values[3]!);
    ref.read(crewMembersProvider.notifier).updateVitals(astronaut.id, record);
    setState(() => _error = null);
    widget.onSubmit({'completed': true, 'astronaut_id': astronaut.id,
      'heart_rate': record.heartRate, 'respiratory_rate': record.respiratoryRate,
      'capillary_refill_seconds': record.capillaryRefillSeconds,
      'body_temp': record.bodyTemp, 'source': 'manual'});
  }
  @override
  Widget build(BuildContext context) => CockpitCard(
    title: 'Manual Vitals (Tap-to-Count)', onDismiss: widget.onDismiss, children: [
      Text('${widget.astronaut.callsign} • ${widget.astronaut.id}'),
      const Text('Pulse: radial artery, 15s ×4. Respiration: chest rises, 30s ×2. '
        'Capillary refill: press nail for 5s, release, then time color return.'),
      for (var i = 0; i < 2; i++) ...[
        Text('${i == 0 ? 'Pulse' : 'Respiration'}: ${_remaining[i]}s • ${_taps[i]} taps'),
        Wrap(spacing: 8, children: [
          TextButton(onPressed: () => _start(i),
            child: Text(i == 0 ? 'Start Pulse (15s)' : 'Start Respiration (30s)')),
          FilledButton(onPressed: _remaining[i] == 0 ? null :
            () => setState(() => _taps[i]++),
            child: Text(i == 0 ? 'Tap Pulse' : 'Tap Respiration')),
        ]),
      ],
      TextButton(onPressed: _capillary, child: Text(_capClock.isRunning
        ? 'Stop Refill (${(_capClock.elapsedMilliseconds / 1000).toStringAsFixed(1)}s)'
        : 'Start Capillary Refill')),
      for (var i = 0; i < _fields.length; i++)
        Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: TextField(
          key: ValueKey(['manual-heart-rate', 'manual-respiratory-rate',
            'manual-capillary-refill', 'manual-body-temp'][i]),
          controller: _fields[i],
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: ['Heart Rate (bpm)', 'Respiratory Rate (rpm)',
            'Capillary Refill (s)', 'Body Temperature (°C)'][i]),
        )),
      if (_error != null) Text(_error!, style: const TextStyle(color: Colors.redAccent)),
      FilledButton(onPressed: _remaining.any((r) => r > 0) || _capClock.isRunning
        ? null : _save, child: const Text('Save Manual Vitals')),
    ]);
}
