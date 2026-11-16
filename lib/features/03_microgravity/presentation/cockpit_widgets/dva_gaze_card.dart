import 'package:flutter/material.dart';
import '../../agent/graybiel_engine.dart';
import 'cockpit_card.dart';

class DvaGazeCard extends StatefulWidget {
  const DvaGazeCard({super.key, required this.onSubmit, required this.onDismiss});
  final CockpitSubmit onSubmit;
  final VoidCallback onDismiss;
  @override
  State<DvaGazeCard> createState() => _DvaGazeCardState();
}

class _DvaGazeCardState extends State<DvaGazeCard> with SingleTickerProviderStateMixin {
  static const _letters = ['E', 'F', 'P', 'T', 'O'];
  late final AnimationController _pulse = AnimationController(vsync: this,
    duration: const Duration(milliseconds: 1000));
  int _total = 0, _correct = 0;
  bool _fixated = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) { _pulse.stop(); } else { _pulse.repeat(); }
  }
  @override
  void dispose() { _pulse.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    final result = GazeStabilityAnalyzer.analyze(correctCount: _correct,
      total: _total, fixationRatio: _fixated ? 1 : 0);
    return CockpitCard(title: '1 Hz DVA', onDismiss: widget.onDismiss, children: [
      const Text('Keep your eyes on the target. If comfortable, gently turn your head to the 1 Hz pulse. Select the letter you see.'),
      const Text('Touch-based self-check; fixation and rhythm are not sensor-measured.'),
      AnimatedBuilder(animation: _pulse, builder: (_, _) => Center(
        child: Container(margin: const EdgeInsets.all(12), padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(shape: BoxShape.circle,
            border: Border.all(color: ApoloPalette.standard.lav, width: 2 + _pulse.value * 4)),
          child: Text(_letters[_total % _letters.length], style: const TextStyle(fontSize: 40))))),
      Wrap(spacing: 8, children: [
        for (final letter in _letters) OutlinedButton(onPressed: () => setState(() {
          if (letter == _letters[_total % _letters.length]) _correct++;
          _total++;
        }), child: Text(letter)),
      ]),
      CheckboxListTile(contentPadding: EdgeInsets.zero, title: const Text('I maintained central fixation'),
        value: _fixated, onChanged: (v) => setState(() => _fixated = v!)),
      Text('$_correct / $_total correct • ${(result.compositeScore * 100).toStringAsFixed(0)}% self-check'),
      FilledButton(onPressed: _total == 0 ? null : () => widget.onSubmit({
        'completed': true, 'correct_count': _correct, 'total': _total,
        'gaze_stability_pct': result.compositeScore * 100,
        'fixation_reported': _fixated,
      }), child: const Text('Complete DVA')),
    ]);
  }
}
