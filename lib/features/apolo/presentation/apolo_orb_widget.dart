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
    this.diameter = 144.0,
    required this.content,
    required this.child,
  });

  final bool visible;
  final Key windowKey;
  final Color accent;
  final bool highContrast;
  final double diameter;
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
        final renderObject = this.context.findRenderObject();
        if (renderObject is! RenderBox || !renderObject.hasSize) {
          return const SizedBox.shrink();
        }
        final screen = MediaQuery.sizeOf(context);
        final maxAllowed = math.max(
          0.0,
          math.min(screen.width - 32.0, screen.height - 32.0),
        );
        final expandedDiameter = math.min(widget.diameter * 2.0, maxAllowed);
        if (expandedDiameter <= 0) {
          return const SizedBox.shrink();
        }
        final overlay =
            Overlay.of(context).context.findRenderObject()! as RenderBox;
        final orbCenter = renderObject.localToGlobal(
          renderObject.size.center(Offset.zero),
        );
        final maxLeft = math.max(16.0, screen.width - expandedDiameter - 16.0);
        final maxTop = math.max(16.0, screen.height - expandedDiameter - 16.0);
        final left = (orbCenter.dx - expandedDiameter / 2).clamp(16.0, maxLeft);
        final top = (orbCenter.dy - expandedDiameter / 2).clamp(16.0, maxTop);
        final position = overlay.globalToLocal(Offset(left, top));
        return Positioned(
          left: position.dx,
          top: position.dy,
          width: expandedDiameter,
          height: expandedDiameter,
          child: IgnorePointer(
            child: Material(
              color: Colors.transparent,
              child: Container(
                key: widget.windowKey,
                width: expandedDiameter,
                height: expandedDiameter,
                clipBehavior: Clip.antiAlias,
                padding: EdgeInsets.symmetric(
                  horizontal: expandedDiameter * 0.13,
                  vertical: expandedDiameter * 0.12,
                ),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.highContrast
                      ? const Color(0xFF000000)
                      : const Color(0xF215173A),
                  gradient: widget.highContrast
                      ? null
                      : RadialGradient(
                          center: const Alignment(-0.55, -0.7),
                          radius: 1.35,
                          colors: [
                            widget.accent.withValues(alpha: 0.22),
                            const Color(0xF215173A),
                            const Color(0xF70D0E26),
                          ],
                          stops: const [0.0, 0.55, 1.0],
                        ),
                  border: Border.all(
                    color: widget.accent,
                    width: widget.highContrast ? 3 : 2,
                  ),
                  boxShadow: widget.highContrast
                      ? null
                      : [
                          BoxShadow(
                            color: widget.accent.withValues(alpha: 0.28),
                            blurRadius: 36,
                            spreadRadius: 2,
                          ),
                          const BoxShadow(
                            color: Color(0xAA000000),
                            blurRadius: 48,
                            offset: Offset(0, 18),
                          ),
                        ],
                ),
                child: Center(
                  child: SingleChildScrollView(child: widget.content),
                ),
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
    final pendingRecommendations = widget.snapshot.recommendations
        .where((r) => !r.done)
        .take(3)
        .toList();

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
          diameter: diameter,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: (diameter * 0.055).clamp(5.0, 9.0),
                runSpacing: (diameter * 0.035).clamp(4.0, 6.0),
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Container(
                    width: (diameter * 0.20).clamp(22.0, 32.0),
                    height: (diameter * 0.20).clamp(22.0, 32.0),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: severityColor.withValues(alpha: 0.18),
                      border: Border.all(
                        color: severityColor.withValues(alpha: 0.5),
                      ),
                    ),
                    child: Icon(
                      apoloModuleIcon(widget.snapshot.id),
                      color: severityColor,
                      size: (diameter * 0.11).clamp(13.0, 18.0),
                    ),
                  ),
                  Text(
                    widget.snapshot.title,
                    style: TextStyle(
                      color: palette.text,
                      fontSize: (diameter * 0.105).clamp(13.0, 17.0),
                      fontWeight: FontWeight.w700,
                      height: 1.15,
                    ),
                  ),
                  ApoloStatusChip(
                    severity: widget.snapshot.severity,
                    highContrast: widget.highContrast,
                    compact: true,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                widget.snapshot.keyMetric,
                style: TextStyle(
                  color: palette.text,
                  fontSize: (diameter * 0.16).clamp(17.0, 26.0),
                  fontWeight: FontWeight.w800,
                  height: 1.1,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(height: 2),
              Text(
                widget.snapshot.subMetric,
                style: TextStyle(
                  color: palette.text2,
                  fontSize: (diameter * 0.085).clamp(11.0, 13.5),
                  height: 1.3,
                ),
              ),
              if (widget.snapshot.measures.trim().isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  'WHAT THIS MEASURES',
                  style: TextStyle(
                    color: severityColor,
                    fontSize: (diameter * 0.07).clamp(9.5, 11.0),
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.85,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  widget.snapshot.measures,
                  style: TextStyle(
                    color: palette.text,
                    fontSize: (diameter * 0.085).clamp(11.0, 13.5),
                    height: 1.35,
                  ),
                ),
              ],
              if (widget.snapshot.whyItMatters.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'WHY IT MATTERS',
                  style: TextStyle(
                    color: severityColor,
                    fontSize: (diameter * 0.07).clamp(9.5, 11.0),
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.85,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  widget.snapshot.whyItMatters,
                  style: TextStyle(
                    color: palette.text2,
                    fontSize: (diameter * 0.08).clamp(10.5, 12.5),
                    height: 1.35,
                  ),
                ),
              ],
              if (pendingRecommendations.isNotEmpty) ...[
                const SizedBox(height: 9),
                Text(
                  'PENDING ACTIONS',
                  style: TextStyle(
                    color: severityColor,
                    fontSize: (diameter * 0.07).clamp(9.5, 11.0),
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.85,
                  ),
                ),
                const SizedBox(height: 4),
                for (final rec in pendingRecommendations)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 5),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 1),
                          child: Icon(
                            Icons.arrow_right_rounded,
                            color: severityColor,
                            size: 15,
                          ),
                        ),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                rec.text,
                                style: TextStyle(
                                  color: palette.text,
                                  fontSize: (diameter * 0.082).clamp(11.0, 12.5),
                                  fontWeight: FontWeight.w600,
                                  height: 1.3,
                                ),
                              ),
                              if (rec.why.trim().isNotEmpty)
                                Text(
                                  rec.why,
                                  style: TextStyle(
                                    color: palette.text2,
                                    fontSize: (diameter * 0.075).clamp(10.0, 11.5),
                                    height: 1.3,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
              const SizedBox(height: 10),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.touch_app_outlined,
                    color: severityColor,
                    size: (diameter * 0.095).clamp(12.0, 15.0),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'Click orb for interactive actions',
                      style: TextStyle(
                        color: severityColor,
                        fontSize: (diameter * 0.08).clamp(10.5, 12.5),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          child: MouseRegion(
            onEnter: (_) => setState(() {
              _hovered = true;
              _dismissed = false;
            }),
            onExit: (_) => setState(() => _hovered = false),
            child: AnimatedScale(
              scale: expanded ? 2.0 : 1.0,
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
                    setState(() {
                      _hovered = false;
                      _dismissed = true;
                    });
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
                            : severityColor.withValues(
                                alpha: expanded ? 1.0 : 0.72,
                              ),
                        width:
                            widget.highContrast ||
                                widget.snapshot.severity == ApoloSeverity.crit ||
                                expanded
                            ? 3.0
                            : 2.0,
                      ),
                      boxShadow: widget.highContrast
                          ? null
                          : [
                              BoxShadow(
                                color: severityColor.withValues(
                                  alpha: expanded ? 0.24 : 0.12,
                                ),
                                spreadRadius: expanded ? 8 : 5,
                              ),
                              BoxShadow(
                                color: severityColor.withValues(
                                  alpha: expanded ? 0.42 : 0.22,
                                ),
                                blurRadius: expanded ? 36 : 26,
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
