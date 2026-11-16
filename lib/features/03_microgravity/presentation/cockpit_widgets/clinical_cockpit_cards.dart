import 'dart:async';
import 'package:flutter/material.dart';
import '../../agent/procedures_engine.dart';
import '../../agent/sans_engine.dart';
import 'cockpit_card.dart';

class LbnpRampCard extends StatefulWidget {
  const LbnpRampCard({super.key, required this.onSubmit, required this.onDismiss,
    this.initialState});
  final CockpitSubmit onSubmit;
  final VoidCallback onDismiss;
  final LbnpState? initialState;
  @override
  State<LbnpRampCard> createState() => _LbnpRampCardState();
}

class _LbnpRampCardState extends State<LbnpRampCard> {
  late final _protocol = LbnpProtocolMachine(initialState: widget.initialState);
  LbnpState get _state => _protocol.state;
  int get _remaining => _protocol.remainingSeconds;
  String? _error;
  Timer? _timer;
  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_remaining > 0) setState(() => _protocol.tick());
    });
  }
  @override
  void dispose() { _timer?.cancel(); super.dispose(); }
  void _advance({LbnpPhase? requested}) {
    final result = _protocol.advance(requestedPhase: requested);
    setState(() {
      _error = result.error;
    });
    if (result.ok) {
      widget.onSubmit({
        ..._state.toJson(), 'completed': _state.phase == LbnpPhase.completed,
        'seal_checked': true,
        'action': _state.phase == LbnpPhase.completed ? 'complete' : 'advance',
      });
    }
  }
  void _emergency() {
    _protocol.abort(emergency: true);
    setState(() { _error = null; });
    widget.onSubmit({..._state.toJson(), 'completed': false, 'action': 'emergency_release'});
  }
  void _dismiss() {
    if (_state.pressureMmHg < 0) {
      final result = _protocol.abort();
      setState(() {
        _error = 'Safety lock: complete gradual decompression before dismissing.';
      });
      if (result.ok) {
        widget.onSubmit({..._state.toJson(), 'completed': false, 'action': 'abort'});
      }
    } else {
      widget.onDismiss();
    }
  }
  @override
  Widget build(BuildContext context) => CockpitCard(title: 'LBNP -20 mmHg',
    onDismiss: _dismiss, critical: _state.emergencyRelease, status: _state.phase.wireName,
    children: [
      const Text('Prescribed protocol only. Confirm seal and baseline vitals; this guide does not control hardware.'),
      Text('${_state.pressureMmHg} mmHg', style: const TextStyle(fontSize: 32)),
      LinearProgressIndicator(value: _state.pressureMmHg.abs() / 20),
      Text(_state.instruction),
      Text('Monitored hold: $_remaining s remaining'),
      if (_error != null) Text(_error!, style: TextStyle(color: ApoloPalette.standard.warn)),
      Wrap(spacing: 8, runSpacing: 8, children: [
        OutlinedButton(onPressed: _state.phase == LbnpPhase.prepSealCheck ?
          () => _advance() : null, child: const Text('Ramp -10')),
        OutlinedButton(onPressed: _state.phase == LbnpPhase.stepMinus10_3min ?
          () => _advance() : null, child: const Text('Hold -20')),
        OutlinedButton(onPressed: _state.phase == LbnpPhase.targetMinus20_15min ?
          () => _advance() : null, child: const Text('Decompress -10')),
        FilledButton(onPressed: _state.phase == LbnpPhase.completed ||
          _state.phase == LbnpPhase.aborted ? null : () => _advance(
            requested: _state.pressureMmHg == -20 ? LbnpPhase.completed : null),
          child: const Text('Complete')),
        FilledButton.icon(style: FilledButton.styleFrom(backgroundColor: ApoloPalette.standard.crit),
          onPressed: _state.phase == LbnpPhase.completed || _state.emergencyRelease ? null : _emergency,
          icon: const Icon(Icons.emergency), label: const Text('Emergency Release')),
      ]),
    ]);
}

class ExerciseMonitorCard extends StatefulWidget {
  const ExerciseMonitorCard({super.key, required this.onSubmit, required this.onDismiss,
    this.props = const {}});
  final CockpitSubmit onSubmit;
  final VoidCallback onDismiss;
  final Map<String, dynamic> props;
  @override
  State<ExerciseMonitorCard> createState() => _ExerciseMonitorCardState();
}

class _ExerciseMonitorCardState extends State<ExerciseMonitorCard> {
  late int _minutes = (widget.props['duration_minutes'] as num?)?.toInt() ?? 0;
  bool _symptom = false;
  @override
  Widget build(BuildContext context) {
    // Read supplied telemetry on each rebuild; never fabricate nominal vital signs.
    final hr = widget.props['heart_rate'], spo2 = widget.props['spo2'];
    final unsafe = _symptom || widget.props['unsafe_vitals'] == true ||
      (hr is num && hr > 175) || (spo2 is num && spo2 < 92);
    return CockpitCard(title: 'Exercise Monitor', onDismiss: widget.onDismiss,
      critical: unsafe, status: unsafe ? 'Stop exercise' : 'Vitals check',
      children: [
        Text('HR ${hr ?? 'unavailable'} bpm • SpO2 ${spo2 ?? 'unavailable'}%'),
        Text('$_minutes min logged • ${widget.props['device_name'] ?? 'Countermeasures'}'),
        const Text('Check current telemetry before exercise. Stop immediately if symptoms develop.'),
        Wrap(spacing: 8, children: [
          for (final min in [15, 30]) OutlinedButton(onPressed: unsafe ? null : () {
            setState(() => _minutes += min);
            widget.onSubmit({'completed': true, 'duration_minutes': min,
              'session_duration_minutes': _minutes,
              'added_minutes': min, 'symptom_flagged': _symptom});
          }, child: Text('+${min}m')),
          TextButton(onPressed: () {
            setState(() => _symptom = true);
            widget.onSubmit({'completed': false, 'symptom_flagged': true, 'unsafe_vitals': true});
          }, child: const Text('Flag Symptom')),
        ]),
      ]);
  }
}

class PvtTestCard extends StatefulWidget {
  const PvtTestCard({super.key, required this.onSubmit, required this.onDismiss});
  final CockpitSubmit onSubmit;
  final VoidCallback onDismiss;
  @override
  State<PvtTestCard> createState() => _PvtTestCardState();
}

class _PvtTestCardState extends State<PvtTestCard> {
  Timer? _timer;
  final _watch = Stopwatch();
  final _latencies = <int>[];
  bool _waiting = false, _lit = false;
  int _falseStarts = 0;
  void _start() {
    setState(() { _waiting = true; _lit = false; });
    // Vary foreperiod so users cannot simply anticipate a fixed interval.
    final delay = 1500 + DateTime.now().microsecondsSinceEpoch % 2500;
    _timer = Timer(Duration(milliseconds: delay), () {
      _watch..reset()..start();
      setState(() { _waiting = false; _lit = true; });
    });
  }
  @override
  void dispose() { _timer?.cancel(); _watch.stop(); super.dispose(); }
  @override
  Widget build(BuildContext context) => CockpitCard(title: 'PVT Reaction Time',
    onDismiss: widget.onDismiss, children: [
      const Text('Tap only when the target lights up. This brief check is not a validated full PVT protocol.'),
      FilledButton(onPressed: () {
        if (_lit) {
          _watch.stop();
          setState(() { _latencies.add(_watch.elapsedMilliseconds); _lit = false; });
        } else if (_waiting) {
          setState(() => _falseStarts++);
        } else {
          _start();
        }
      }, style: FilledButton.styleFrom(backgroundColor:
          _lit ? ApoloPalette.standard.ok : ApoloPalette.standard.surface),
        child: Padding(padding: const EdgeInsets.all(20),
          child: Text(_lit ? 'TAP NOW' : _waiting ? 'Wait…' : 'Start reaction trial'))),
      Text('${_latencies.length} trials • $_falseStarts false starts'
        '${_latencies.isEmpty ? '' : ' • Last ${_latencies.last} ms'}'),
      FilledButton(onPressed: _latencies.isEmpty || _waiting || _lit ? null : () => widget.onSubmit({
        'completed': true, 'reaction_times_ms': List.of(_latencies),
        'mean_rt_ms': _latencies.reduce((a, b) => a + b) / _latencies.length,
        'mean_reaction_ms': _latencies.reduce((a, b) => a + b) / _latencies.length,
        'lapses': _latencies.where((v) => v > 500).length,
        'false_starts': _falseStarts,
      }), child: const Text('Submit Reaction Test')),
    ]);
}

class MptTestCard extends StatefulWidget {
  const MptTestCard({super.key, required this.onSubmit, required this.onDismiss});
  final CockpitSubmit onSubmit;
  final VoidCallback onDismiss;
  @override
  State<MptTestCard> createState() => _MptTestCardState();
}

class _MptTestCardState extends State<MptTestCard> {
  int _hits = 0, _attempts = 0;
  @override
  Widget build(BuildContext context) => CockpitCard(title: 'Motor Precision',
    onDismiss: widget.onDismiss, children: [
      const Text('Tap the moving target as precisely as possible.'),
      LayoutBuilder(builder: (_, constraints) {
        final target = Offset(30 + (_hits * 73 % 100) / 100 * (constraints.maxWidth - 60), 60);
        return GestureDetector(behavior: HitTestBehavior.opaque,
          onTapUp: (d) => setState(() {
            _attempts++;
            if ((d.localPosition - target).distance <= 24) _hits++;
          }),
          child: SizedBox(height: 120, width: double.infinity,
            child: Stack(children: [Positioned(left: target.dx - 24, top: target.dy - 24,
              child: Icon(Icons.gps_fixed, size: 48, color: ApoloPalette.standard.ok))])));
      }),
      Text('$_hits hits / $_attempts attempts'),
      FilledButton(onPressed: _attempts == 0 ? null : () => widget.onSubmit({
        'completed': true, 'hits': _hits, 'total': _attempts,
        'accuracy_pct': _hits / _attempts * 100,
      }), child: const Text('Submit Precision')),
    ]);
}

class DiaryRecorderCard extends StatefulWidget {
  const DiaryRecorderCard({super.key, required this.onSubmit, required this.onDismiss});
  final CockpitSubmit onSubmit;
  final VoidCallback onDismiss;
  @override
  State<DiaryRecorderCard> createState() => _DiaryRecorderCardState();
}

class _DiaryRecorderCardState extends State<DiaryRecorderCard> {
  double _sleep = 8;
  String _mood = 'Steady', _workload = 'Moderate';
  @override
  Widget build(BuildContext context) => CockpitCard(title: 'Sleep & Mood Diary',
    onDismiss: widget.onDismiss, children: [
      Text('Sleep ${_sleep.toStringAsFixed(1)} hours'),
      Slider(value: _sleep, min: 0, max: 12, divisions: 24,
        onChanged: (v) => setState(() => _sleep = v)),
      const Text('Mood'),
      Wrap(spacing: 6, children: [for (final value in ['Low', 'Steady', 'Positive'])
        ChoiceChip(label: Text(value), selected: _mood == value,
          onSelected: (_) => setState(() => _mood = value))]),
      const Text('Workload'),
      Wrap(spacing: 6, children: [for (final value in ['Light', 'Moderate', 'High'])
        ChoiceChip(label: Text(value), selected: _workload == value,
          onSelected: (_) => setState(() => _workload = value))]),
      FilledButton(onPressed: () => widget.onSubmit({'completed': true,
        'sleep_hours': _sleep, 'mood': _mood, 'workload': _workload}),
        child: const Text('Save Diary')),
    ]);
}

class UltrasoundGuideCard extends StatefulWidget {
  const UltrasoundGuideCard({super.key, required this.onSubmit, required this.onDismiss});
  final CockpitSubmit onSubmit;
  final VoidCallback onDismiss;
  @override
  State<UltrasoundGuideCard> createState() => _UltrasoundGuideCardState();
}

class _UltrasoundGuideCardState extends State<UltrasoundGuideCard> {
  final _checked = <UltrasoundStep>{};
  @override
  Widget build(BuildContext context) => CockpitCard(title: 'Renal / Bladder Ultrasound',
    onDismiss: widget.onDismiss, children: [
      const Text('Follow the prescribed scan protocol. Save images for flight surgeon review.'),
      for (final step in UltrasoundStep.values.where((s) => s != UltrasoundStep.completed))
        CheckboxListTile(contentPadding: EdgeInsets.zero,
          title: Text(UltrasoundEngine.evaluateStep(step: step).instruction),
          value: _checked.contains(step), onChanged: (v) => setState(() {
            if (v!) { _checked.add(step); } else { _checked.remove(step); }
          })),
      FilledButton(onPressed: _checked.length < UltrasoundStep.values.length - 1 ? null :
        () => widget.onSubmit({'completed': true,
          'step': UltrasoundStep.completed.wireName,
          'checked_steps': _checked.map((s) => s.wireName).toList()}),
        child: const Text('Complete Scan Checklist')),
    ]);
}
