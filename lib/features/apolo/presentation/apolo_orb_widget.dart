import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../domain/apolo_models.dart';
import 'apolo_theme.dart';

/// Circular floating health orb button (`S` / `M` / `L` by severity, pulsing
/// alert halo on `warn` / `crit`, icon, `keyMetric` in tabular figures,
/// `shortLabel`, and accessible status chip).
class ApoloOrbWidget extends StatefulWidget {
  const ApoloOrbWidget({
    super.key,
    required this.snapshot,
    required this.onTap,
    this.highContrast = false,
    this.compactScale = 1.0,
    this.highlighted = false,
  });

  final ApoloModuleSnapshot snapshot;
  final VoidCallback onTap;
  final bool highContrast;
  final double compactScale;
  final bool highlighted;

  double get baseDiameter => switch (snapshot.severity) {
    ApoloSeverity.crit => 164.0,
    ApoloSeverity.warn => 144.0,
    ApoloSeverity.ok => 124.0,
  };

  @override
  State<ApoloOrbWidget> createState() => _ApoloOrbWidgetState();
}

class _ApoloOrbWidgetState extends State<ApoloOrbWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _animationsDisabled = false;
  bool _hovered = false;

  @override
  void initState() {
    super.initState();
    final seed = widget.snapshot.id.index;
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 5600 + (seed % 3) * 1000),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _animationsDisabled = MediaQuery.disableAnimationsOf(context);
    _syncTicker();
  }

  void _syncTicker() {
    if (_animationsDisabled) {
      if (_controller.isAnimating) _controller.stop();
    } else {
      if (!_controller.isAnimating) {
        _controller.repeat();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: _buildOrb);

  Widget _buildOrb(BuildContext context, BoxConstraints constraints) {
    final palette = ApoloPalette.of(widget.highContrast);
    final severityColor = palette.forSeverity(widget.snapshot.severity);
    final diameter = (widget.baseDiameter * widget.compactScale).clamp(
      92.0,
      192.0,
    );
    final isAlert = widget.snapshot.severity != ApoloSeverity.ok;
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    final seed = widget.snapshot.id.index + 1;
    final expanded = _hovered || widget.highlighted;

    return Semantics(
      button: true,
      label:
          '${widget.snapshot.title}: ${widget.snapshot.severity.label}. ${widget.snapshot.keyMetric}, ${widget.snapshot.subMetric}. Open details',
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final t = disableAnimations ? 0.0 : _controller.value;
          final dx = disableAnimations
              ? 0.0
              : math.sin((t + seed * 0.17) * math.pi * 2) * 4.5;
          final dy = disableAnimations
              ? 0.0
              : math.cos((t + seed * 0.23) * math.pi * 2) * 5.5;
          final haloPhase = disableAnimations
              ? 0.0
              : ((t *
                        (widget.snapshot.severity == ApoloSeverity.crit
                            ? 2.4
                            : 1.7)) %
                    1.0);

          return Transform.translate(
            offset: Offset(dx, dy),
            child: Padding(
              padding: const EdgeInsets.all(9),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (isAlert && !disableAnimations && !expanded)
                    Positioned.fill(child: IgnorePointer(
                      child: Transform.scale(
                        scale: 1.0 + haloPhase * 0.30,
                        child: Container(
                          width: diameter,
                          height: diameter,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: severityColor.withValues(
                                alpha: (1.0 - haloPhase) * 0.65,
                              ),
                              width: 2.0,
                            ),
                          ),
                        ),
                      ),
                    )),
                  child!,
                ],
              ),
            ),
          );
        },
        child: MouseRegion(
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: AnimatedSize(
            duration: disableAnimations
                ? Duration.zero
                : const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(expanded ? 28 : diameter),
              child: InkWell(
                key: ValueKey('apolo_orb_${widget.snapshot.id.name}'),
                borderRadius: BorderRadius.circular(expanded ? 28 : diameter),
                onTap: widget.onTap,
                child: Container(
                  // A non-flex Row (the two-column orb rail) gives unbounded
                  // width. Expand vertically there without widening its columns.
                  width: expanded && constraints.hasBoundedWidth ? 300 : diameter,
                  height: expanded ? 250 : diameter,
                  padding: EdgeInsets.all(diameter * 0.075),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(expanded ? 28 : diameter),
                    color: widget.highContrast
                        ? const Color(0xFF000000)
                        : const Color(0xE61A1C46),
                    gradient: widget.highContrast
                        ? null
                        : RadialGradient(
                            center: const Alignment(-0.36, -0.48),
                            radius: 0.95,
                            colors: [
                              const Color(0x1FF0FFF1),
                              const Color(0xE61A1C46),
                              severityColor.withValues(alpha: 0.24),
                            ],
                            stops: const [0.0, 0.55, 1.0],
                          ),
                    border: Border.all(
                      color: widget.highContrast
                          ? severityColor
                          : severityColor.withValues(alpha: 0.72),
                      width:
                          widget.highContrast ||
                              widget.snapshot.severity == ApoloSeverity.crit
                          ? 3.0
                          : 2.0,
                    ),
                    boxShadow: widget.highContrast
                        ? null
                        : [
                            BoxShadow(
                              color: severityColor.withValues(alpha: 0.12),
                              spreadRadius: 5,
                            ),
                            BoxShadow(
                              color: severityColor.withValues(alpha: 0.22),
                              blurRadius: 26,
                            ),
                          ],
                  ),
                  child: expanded ? SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(apoloModuleIcon(widget.snapshot.id), color: severityColor),
                        const SizedBox(height: 8),
                        Text(widget.snapshot.title, style: TextStyle(
                          color: palette.text, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 6),
                        FittedBox(fit: BoxFit.scaleDown,
                          child: ApoloStatusChip(severity: widget.snapshot.severity,
                            highContrast: widget.highContrast, compact: true)),
                        const SizedBox(height: 10),
                        Text(widget.snapshot.keyMetric, style: TextStyle(
                          color: palette.text, fontSize: 20, fontWeight: FontWeight.w700)),
                        Text(widget.snapshot.subMetric, style: TextStyle(color: palette.text2)),
                        const SizedBox(height: 8),
                        Text(widget.snapshot.measures.isNotEmpty
                          ? widget.snapshot.measures
                          : widget.snapshot.recommendations.where((r) => !r.done).firstOrNull?.text ?? '',
                          style: TextStyle(color: palette.text2)),
                        const SizedBox(height: 10),
                        Text('Click for details', style: TextStyle(
                          color: severityColor, fontSize: 11)),
                      ],
                    ),
                  ) : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: (diameter * 0.25).clamp(26.0, 42.0),
                        height: (diameter * 0.25).clamp(26.0, 42.0),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: severityColor.withValues(alpha: 0.18),
                        ),
                        child: Icon(
                          apoloModuleIcon(widget.snapshot.id),
                          size: (diameter * 0.15).clamp(16.0, 24.0),
                          color: severityColor,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            widget.snapshot.keyMetric,
                            maxLines: 1,
                            style: TextStyle(
                              fontSize: (diameter * 0.135).clamp(13.0, 22.0),
                              fontWeight: FontWeight.w700,
                              color: palette.text,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                              height: 1.1,
                            ),
                          ),
                        ),
                      ),
                      Text(
                        widget.snapshot.shortLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: (diameter * 0.085).clamp(10.5, 14.0),
                          fontWeight: FontWeight.w600,
                          color: palette.text2,
                          height: 1.15,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: ApoloStatusChip(
                            severity: widget.snapshot.severity,
                            highContrast: widget.highContrast,
                            compact: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
