import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../agent/sans_engine.dart';
import 'cockpit_card.dart';

class StarfieldDistortionCard extends StatefulWidget {
  const StarfieldDistortionCard({super.key, required this.onSubmit, required this.onDismiss});
  final CockpitSubmit onSubmit;
  final VoidCallback onDismiss;
  @override
  State<StarfieldDistortionCard> createState() => _StarfieldDistortionCardState();
}

class _StarfieldDistortionCardState extends State<StarfieldDistortionCard> {
  final _cells = <int>{};
  double _distortion = 0;
  int _flashes = 0, _misses = 0;
  bool _visible = false;
  Timer? _flash;
  void _startFlash() {
    setState(() => _visible = true);
    _flash = Timer(const Duration(seconds: 2), () {
      if (!mounted) return;
      setState(() { _visible = false; _flashes++; _misses++; });
    });
  }
  @override
  void dispose() { _flash?.cancel(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    final result = StarfieldDistortionAnalyzer.evaluate(
      distortionIndex: math.max(_distortion, _cells.length / 64),
      scotomaMisses: _misses, totalFlashes: _flashes);
    return CockpitCard(title: 'Starfield Distortion', onDismiss: widget.onDismiss,
      critical: result.grade == SansGrade.grade2, status: 'Functional ${result.grade.wireName}',
      children: [
        const Text('Cover one eye. Fixate on the center at 30 cm. Tap cells that appear distorted or missing.'),
        LayoutBuilder(builder: (_, constraints) => GestureDetector(
          key: const ValueKey('amsler_grid'),
          onTapUp: (d) => setState(() {
            final col = (d.localPosition.dx / constraints.maxWidth * 8).floor().clamp(0, 7);
            final row = (d.localPosition.dy / 160 * 8).floor().clamp(0, 7);
            final cell = row * 8 + col;
            if (!_cells.add(cell)) _cells.remove(cell);
          }),
          child: SizedBox(height: 160, width: double.infinity,
            child: CustomPaint(painter: _AmslerPainter(Set.of(_cells)))))),
        Text('Distortion ${(result.distortionIndex * 100).toStringAsFixed(0)}%'),
        Slider(value: _distortion, onChanged: (v) => setState(() => _distortion = v)),
        const Text('Keep central fixation; tap the peripheral flash when it appears.'),
        SizedBox(height: 48, child: Align(
          alignment: _flashes.isEven ? Alignment.centerRight : Alignment.centerLeft,
          child: _visible ? IconButton(tooltip: 'Peripheral flash',
            onPressed: () {
              _flash?.cancel();
              setState(() { _visible = false; _flashes++; });
            }, icon: Icon(Icons.star, color: ApoloPalette.standard.warn)) :
            TextButton(onPressed: _startFlash, child: const Text('Start peripheral flash')))),
        Text('$_misses misses / $_flashes flashes • Not a calibrated visual field exam'),
        FilledButton(onPressed: () => widget.onSubmit({
          'completed': true, 'distorted_cells': _cells.toList()..sort(),
          'wavy_lines': result.distortionIndex > 0, 'distortion_index': result.distortionIndex,
          'scotoma_misses': _misses, 'total_flashes': _flashes,
        }), child: const Text('Submit Starfield')),
      ]);
  }
}

class _AmslerPainter extends CustomPainter {
  _AmslerPainter(this.cells);
  final Set<int> cells;
  @override
  void paint(Canvas canvas, Size size) {
    const p = ApoloPalette.standard;
    canvas.drawRect(Offset.zero & size, Paint()..color = p.bg);
    for (final cell in cells) {
      canvas.drawRect(Rect.fromLTWH(cell % 8 * size.width / 8, cell ~/ 8 * size.height / 8,
        size.width / 8, size.height / 8), Paint()..color = p.warn.withValues(alpha: .4));
    }
    for (var i = 0; i <= 8; i++) {
      final paint = Paint()..color = p.lav;
      canvas.drawLine(Offset(i * size.width / 8, 0), Offset(i * size.width / 8, size.height), paint);
      canvas.drawLine(Offset(0, i * size.height / 8), Offset(size.width, i * size.height / 8), paint);
    }
    canvas.drawCircle(size.center(Offset.zero), 4, Paint()..color = p.text);
  }
  @override
  bool shouldRepaint(covariant _AmslerPainter old) => true;
}

class NearPointDiopterCard extends StatefulWidget {
  const NearPointDiopterCard({super.key, required this.onSubmit, required this.onDismiss,
    this.baselineCm = 25});
  final CockpitSubmit onSubmit;
  final VoidCallback onDismiss;
  final double baselineCm;
  @override
  State<NearPointDiopterCard> createState() => _NearPointDiopterCardState();
}

class _NearPointDiopterCardState extends State<NearPointDiopterCard> {
  double _cm = 25;
  bool _crisp = false;
  @override
  Widget build(BuildContext context) {
    final result = NearPointDiopterCalculator.evaluate(distanceCm: _cm, baselineCm: widget.baselineCm);
    return CockpitCard(title: 'Near-Point Diopter', onDismiss: widget.onDismiss, children: [
      const Text('Cover one eye. Measure the eye-to-screen distance where this target first becomes clear.'),
      const Center(child: Text('E F P T O', style: TextStyle(fontSize: 32, letterSpacing: 4))),
      CheckboxListTile(contentPadding: EdgeInsets.zero, title: const Text('Target is crisp'),
        value: _crisp, onChanged: (v) => setState(() => _crisp = v!)),
      Text('${_cm.toStringAsFixed(0)} cm • Personal baseline ${widget.baselineCm.toStringAsFixed(0)} cm'),
      Slider(value: _cm, min: 18, max: 65, divisions: 47,
        label: '${_cm.toStringAsFixed(0)} cm', onChanged: (v) => setState(() => _cm = v)),
      Text('ΔD +${result.deltaDiopters.toStringAsFixed(2)} D ±${result.confidenceBand.toStringAsFixed(2)} D'),
      Text('Space Anticipation Glasses: ${switch (result.tier) {
        SpaceAnticipationGlassesTier.none => 'None',
        SpaceAnticipationGlassesTier.pairA_plus0_75 => 'Pair A +0.75 D',
        SpaceAnticipationGlassesTier.pairB_plus1_50 => 'Pair B +1.50 D',
        SpaceAnticipationGlassesTier.pairC_plus2_25 => 'Pair C +2.25 D',
      }}'),
      const Text('Screening suggestion only, not an optical prescription. Confirm with flight surgeon and available inventory.'),
      FilledButton(onPressed: () => widget.onSubmit({
        'completed': true, 'near_focus_cm': _cm, 'delta_diopters': result.deltaDiopters,
        'glasses_tier': result.tier.name, 'target_crisp': _crisp,
      }), child: const Text('Submit Near Point')),
    ]);
  }
}

class SansContrastCard extends StatefulWidget {
  const SansContrastCard({super.key, required this.onSubmit, required this.onDismiss});
  final CockpitSubmit onSubmit;
  final VoidCallback onDismiss;
  @override
  State<SansContrastCard> createState() => _SansContrastCardState();
}

class _SansContrastCardState extends State<SansContrastCard> {
  double? _logCs;
  @override
  Widget build(BuildContext context) => CockpitCard(title: 'Contrast Sensitivity',
    onDismiss: widget.onDismiss, children: [
      const Text('Select the faintest triplet you can read. Display contrast is not clinically calibrated.'),
      for (final level in [2.0, 1.85, 1.7, 1.55, 1.4, 1.25, 1.1])
        TextButton(onPressed: () => setState(() => _logCs = level),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(level.toStringAsFixed(2)),
            Text('F P T', style: TextStyle(fontSize: 24,
              color: ApoloPalette.standard.text.withValues(alpha: math.pow(10, -level).toDouble()))),
            if (_logCs == level) const Icon(Icons.check),
          ])),
      FilledButton(onPressed: _logCs == null ? null : () => widget.onSubmit({
        'completed': true, 'log_cs': _logCs, 'contrast_log_cs': _logCs,
      }), child: const Text('Submit Contrast')),
    ]);
}
