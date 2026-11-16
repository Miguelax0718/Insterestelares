import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../domain/apolo_models.dart';
import 'apolo_theme.dart';

/// Shared non-interactive preview; the portal owns its overlay's lifecycle.
class ApoloOrbHoverWindow extends StatefulWidget {
  const ApoloOrbHoverWindow({
    super.key,
    required this.visible,
    required this.windowKey,
    required this.accent,
    required this.highContrast,
    required this.content,
    required this.child,
  });

  final bool visible;
  final Key windowKey;
  final Color accent;
  final bool highContrast;
  final Widget content;
  final Widget child;

  @override
  State<ApoloOrbHoverWindow> createState() => _ApoloOrbHoverWindowState();
}

class _ApoloOrbHoverWindowState extends State<ApoloOrbHoverWindow> {
  final _portal = OverlayPortalController();

  @override
  Widget build(BuildContext context) {
    // Minimal widget harnesses may deliberately omit an Overlay.
    if (Overlay.maybeOf(context) == null) return widget.child;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (widget.visible && !_portal.isShowing) {
        _portal.show();
      } else if (!widget.visible && _portal.isShowing) {
        _portal.hide();
      }
    });
    return OverlayPortal(
      controller: _portal,
      overlayChildBuilder: (context) {
        final screen = MediaQuery.sizeOf(context);
        final box = this.context.findRenderObject()! as RenderBox;
        final overlay = Overlay.of(context).context.findRenderObject()! as RenderBox;
        final anchor = box.localToGlobal(Offset.zero);
        final width = math.min(290.0, math.max(0.0, screen.width - 32));
        final height = math.min(270.0, math.max(0.0, screen.height - 32));
        final desiredX = anchor.dx + box.size.width / 2 < screen.width / 2
            ? anchor.dx + box.size.width + 16
            : anchor.dx - width - 16;
        final x = desiredX.clamp(16.0, math.max(16.0, screen.width - width - 16));
        final y = (anchor.dy + (box.size.height - height) / 2)
            .clamp(16.0, math.max(16.0, screen.height - height - 16));
        final position = overlay.globalToLocal(Offset(x.toDouble(), y.toDouble()));
        return Positioned(
          left: position.dx,
          top: position.dy,
          width: width,
          height: height,
          child: IgnorePointer(
            child: Material(
              color: Colors.transparent,
              child: Container(
                key: widget.windowKey,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  color: widget.highContrast
                      ? const Color(0xFF000000) : const Color(0xF017193D),
                  gradient: widget.highContrast ? null : RadialGradient(
                    center: const Alignment(-0.5, -0.7),
                    radius: 1.4,
                    colors: [widget.accent.withValues(alpha: 0.18), const Color(0xF017193D)],
                  ),
                  border: Border.all(color: widget.accent,
                    width: widget.highContrast ? 3 : 2),
                  boxShadow: [
                    BoxShadow(color: widget.accent.withValues(alpha: 0.24), blurRadius: 26),
                  ],
                ),
                child: SingleChildScrollView(child: widget.content),
              ),
            ),
          ),
        );
      },
      child: widget.child,
    );
  }
}

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
  bool _dismissed = false;

  @override
  void didUpdateWidget(ApoloOrbWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.highlighted != widget.highlighted) _dismissed = false;
  }

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
    final expanded = (_hovered || widget.highlighted) && !_dismissed;

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
        child: ApoloOrbHoverWindow(
          visible: expanded,
          windowKey: ValueKey('apolo_orb_hover_window_${widget.snapshot.id.name}'),
          accent: severityColor,
          highContrast: widget.highContrast,
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(apoloModuleIcon(widget.snapshot.id), color: severityColor),
              const SizedBox(height: 8),
              Text(widget.snapshot.title, style: TextStyle(
                color: palette.text, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              ApoloStatusChip(severity: widget.snapshot.severity,
                highContrast: widget.highContrast, compact: true),
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
              Text('Click orb for details', style: TextStyle(
                color: severityColor, fontSize: 11)),
            ],
          ),
          child: MouseRegion(
          onEnter: (_) => setState(() { _hovered = true; _dismissed = false; }),
          onExit: (_) => setState(() => _hovered = false),
          child: AnimatedScale(
            scale: expanded ? 1.06 : 1.0,
            duration: disableAnimations
                ? Duration.zero
                : const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(diameter),
              child: InkWell(
                key: ValueKey('apolo_orb_${widget.snapshot.id.name}'),
                borderRadius: BorderRadius.circular(diameter),
                onTap: () {
                  setState(() { _hovered = false; _dismissed = true; });
                  widget.onTap();
                },
                child: Container(
                  width: diameter,
                  height: diameter,
                  padding: EdgeInsets.all(diameter * 0.075),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(diameter),
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
                  child: Column(
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
      ),
    );
  }
}
