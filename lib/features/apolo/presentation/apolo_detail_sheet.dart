import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../domain/apolo_models.dart';
import 'apolo_theme.dart';

/// Modal detail card (wide screens) / draggable bottom sheet (narrow screens)
/// for an opened APOLO health module.
class ApoloDetailSheet extends StatefulWidget {
  const ApoloDetailSheet({
    super.key,
    required this.astronautState,
    required this.snapshot,
    required this.onClose,
    required this.onAddWater,
    required this.onAddExercise,
    required this.onToggleRecommendation,
    required this.onAskApolo,
    required this.onHideOrb,
  });

  final ApoloAstronautState astronautState;
  final ApoloModuleSnapshot snapshot;
  final VoidCallback onClose;
  final bool Function(int ml) onAddWater;
  final bool Function(int minutes) onAddExercise;
  final void Function(String recId, bool done) onToggleRecommendation;
  final VoidCallback onAskApolo;
  final VoidCallback onHideOrb;

  @override
  State<ApoloDetailSheet> createState() => _ApoloDetailSheetState();
}

class _ApoloDetailSheetState extends State<ApoloDetailSheet> {
  final TextEditingController _customController = TextEditingController();
  String? _customError;
  bool _whyExpanded = false;
  double _dragOffsetY = 0.0;

  @override
  void didUpdateWidget(covariant ApoloDetailSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.snapshot.id != widget.snapshot.id) {
      _customController.clear();
      _customError = null;
      _whyExpanded = false;
      _dragOffsetY = 0.0;
    }
  }

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  void _submitCustomLog() {
    final raw = int.tryParse(_customController.text.trim());
    if (widget.snapshot.id == ApoloModuleId.hidratacion) {
      if (raw == null || raw < 50 || raw > 2000) {
        setState(() {
          _customError = 'Enter an amount between 50 and 2000 ml.';
        });
        return;
      }
      final ok = widget.onAddWater(raw);
      setState(() {
        _customError = ok ? null : 'Could not log water amount.';
        if (ok) _customController.clear();
      });
    } else if (widget.snapshot.id == ApoloModuleId.osea) {
      if (raw == null || raw < 1 || raw > 300) {
        setState(() {
          _customError = 'Enter a duration between 1 and 300 min.';
        });
        return;
      }
      final ok = widget.onAddExercise(raw);
      setState(() {
        _customError = ok ? null : 'Could not log exercise duration.';
        if (ok) _customController.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final hc = widget.astronautState.highContrast;
    final palette = ApoloPalette.of(hc);
    final severityColor = palette.forSeverity(widget.snapshot.severity);
    final screenSize = MediaQuery.sizeOf(context);
    final isNarrow = screenSize.width < 760;
    final trend = widget.snapshot.trendValues.length > 14
        ? widget.snapshot.trendValues.sublist(
            widget.snapshot.trendValues.length - 14,
          )
        : widget.snapshot.trendValues;

    final cardContent = Material(
      color: Colors.transparent,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: isNarrow ? double.infinity : 560,
          maxHeight: isNarrow
              ? screenSize.height * 0.88
              : math.min(screenSize.height * 0.86, 820),
        ),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: palette.bg2,
          borderRadius: isNarrow
              ? const BorderRadius.vertical(top: Radius.circular(30))
              : BorderRadius.circular(32),
          border: Border.all(color: palette.border),
          boxShadow: hc
              ? null
              : const [
                  BoxShadow(
                    color: Color(0xAA000000),
                    blurRadius: 50,
                    offset: Offset(0, 20),
                  ),
                ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(height: 4, color: severityColor),
            if (isNarrow)
              GestureDetector(
                onVerticalDragUpdate: (d) {
                  setState(() {
                    _dragOffsetY = math.max(0.0, _dragOffsetY + d.delta.dy);
                  });
                },
                onVerticalDragEnd: (_) {
                  if (_dragOffsetY > 90) {
                    widget.onClose();
                  } else {
                    setState(() => _dragOffsetY = 0.0);
                  }
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  color: Colors.transparent,
                  child: Center(
                    child: Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: palette.border,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ),
              ),
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  22,
                  isNarrow ? 4 : 20,
                  22,
                  22 + MediaQuery.paddingOf(context).bottom,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildHeader(palette, severityColor),
                    const SizedBox(height: 14),
                    _buildKeyMetricCard(palette),
                    if (widget.snapshot.id == ApoloModuleId.hidratacion) ...[
                      const SizedBox(height: 14),
                      _buildWaterLogBox(palette),
                    ] else if (widget.snapshot.id == ApoloModuleId.osea) ...[
                      const SizedBox(height: 14),
                      _buildExerciseLogBox(palette),
                    ],
                    const SizedBox(height: 16),
                    _buildRecommendationsSection(palette),
                    if (widget.astronautState.samples.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _buildBiomarkersSection(palette),
                    ],
                    if (trend.length > 1) ...[
                      const SizedBox(height: 12),
                      _buildTrendCard(palette, trend),
                    ],
                    const SizedBox(height: 12),
                    _buildWhyItMatters(palette),
                    const SizedBox(height: 16),
                    _buildActionButtons(palette),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );

    return Positioned.fill(
      child: Stack(
        children: [
          GestureDetector(
            key: const ValueKey('apolo_detail_scrim'),
            onTap: widget.onClose,
            child: Container(
              color: hc ? const Color(0xCC000000) : const Color(0x99050612),
            ),
          ),
          if (isNarrow)
            Align(
              alignment: Alignment.bottomCenter,
              child: Transform.translate(
                offset: Offset(0, _dragOffsetY),
                child: cardContent,
              ),
            )
          else
            Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: cardContent,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader(ApoloPalette palette, Color severityColor) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: severityColor.withValues(alpha: 0.18),
          ),
          child: Icon(
            apoloModuleIcon(widget.snapshot.id),
            color: severityColor,
            size: 26,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.snapshot.title,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: palette.text,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                widget.snapshot.measures,
                style: TextStyle(fontSize: 13.5, color: palette.text2),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          key: const ValueKey('apolo_detail_close'),
          tooltip: 'Close',
          onPressed: widget.onClose,
          style: IconButton.styleFrom(
            backgroundColor: palette.surface,
            foregroundColor: palette.text,
            fixedSize: const Size(44, 44),
          ),
          icon: const Icon(Icons.close, size: 22),
        ),
      ],
    );
  }

  Widget _buildKeyMetricCard(ApoloPalette palette) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(22),
        border: widget.astronautState.highContrast
            ? Border.all(color: palette.border)
            : null,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.snapshot.keyMetric,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: palette.text,
                    fontFeatures: const [FontFeature.tabularFigures()],
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.snapshot.subMetric,
                  style: TextStyle(fontSize: 14, color: palette.text2),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          ApoloStatusChip(
            severity: widget.snapshot.severity,
            highContrast: widget.astronautState.highContrast,
          ),
        ],
      ),
    );
  }

  Widget _buildWaterLogBox(ApoloPalette palette) {
    final s = widget.astronautState;
    final pct = s.waterGoalMl > 0
        ? (s.waterMlToday / s.waterGoalMl).clamp(0.0, 1.0)
        : 0.0;
    return _buildQuickLogShell(
      palette: palette,
      title: "Today's water",
      progressText:
          '${(s.waterMlToday / 1000).toStringAsFixed(1)} / ${(s.waterGoalMl / 1000).toStringAsFixed(1)} L',
      progress: pct,
      hint: 'Other (50–2000 ml)',
      buttons: [
        _QuickLogButton(
          key: const ValueKey('apolo_water_250'),
          label: '+250 ml',
          palette: palette,
          onTap: () => widget.onAddWater(250),
        ),
        _QuickLogButton(
          key: const ValueKey('apolo_water_500'),
          label: '+500 ml',
          palette: palette,
          onTap: () => widget.onAddWater(500),
        ),
      ],
    );
  }

  Widget _buildExerciseLogBox(ApoloPalette palette) {
    final s = widget.astronautState;
    final pct = s.exerciseGoalMin > 0
        ? (s.exerciseMinToday / s.exerciseGoalMin).clamp(0.0, 1.0)
        : 0.0;
    return _buildQuickLogShell(
      palette: palette,
      title: "Today's exercise",
      progressText: '${s.exerciseMinToday} / ${s.exerciseGoalMin} min',
      progress: pct,
      hint: 'Other (1–300 min)',
      buttons: [
        _QuickLogButton(
          key: const ValueKey('apolo_exercise_15'),
          label: '+15 min',
          palette: palette,
          onTap: () => widget.onAddExercise(15),
        ),
        _QuickLogButton(
          key: const ValueKey('apolo_exercise_30'),
          label: '+30 min',
          palette: palette,
          onTap: () => widget.onAddExercise(30),
        ),
      ],
    );
  }

  Widget _buildQuickLogShell({
    required ApoloPalette palette,
    required String title,
    required String progressText,
    required double progress,
    required String hint,
    required List<Widget> buttons,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(22),
        border: widget.astronautState.highContrast
            ? Border.all(color: palette.border)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: palette.text,
                  fontSize: 15,
                ),
              ),
              Text(
                progressText,
                style: TextStyle(
                  color: palette.text,
                  fontWeight: FontWeight.w600,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 10,
              backgroundColor: palette.bg2,
              valueColor: AlwaysStoppedAnimation<Color>(palette.mint),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ...buttons,
              SizedBox(
                width: 210,
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        key: const ValueKey('apolo_custom_log_input'),
                        controller: _customController,
                        keyboardType: TextInputType.number,
                        style: TextStyle(fontSize: 14, color: palette.text),
                        decoration: InputDecoration(
                          hintText: hint,
                          hintStyle: TextStyle(
                            fontSize: 13,
                            color: palette.text2,
                          ),
                          isDense: true,
                          filled: true,
                          fillColor: palette.bg2,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 11,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(22),
                            borderSide: BorderSide(color: palette.border),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(22),
                            borderSide: BorderSide(color: palette.border),
                          ),
                        ),
                        onSubmitted: (_) => _submitCustomLog(),
                      ),
                    ),
                    const SizedBox(width: 6),
                    _QuickLogButton(
                      key: const ValueKey('apolo_custom_log_submit'),
                      label: 'Log',
                      palette: palette,
                      onTap: _submitCustomLog,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_customError != null) ...[
            const SizedBox(height: 6),
            Text(
              _customError!,
              style: TextStyle(color: palette.warn, fontSize: 13),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRecommendationsSection(ApoloPalette palette) {
    final recs = widget.snapshot.recommendations;
    if (recs.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          widget.snapshot.severity == ApoloSeverity.ok
              ? 'Everything looks stable here. Keep up your mission routine.'
              : 'Review the urine values below and consult your medical officer if symptoms develop.',
          style: TextStyle(fontSize: 14.5, color: palette.text),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'What to do',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: palette.text,
          ),
        ),
        const SizedBox(height: 8),
        for (final rec in recs)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: BorderRadius.circular(20),
              border: widget.astronautState.highContrast
                  ? Border.all(color: palette.border)
                  : null,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  key: ValueKey('apolo_rec_toggle_${rec.id}'),
                  customBorder: const CircleBorder(),
                  onTap: () => widget.onToggleRecommendation(rec.id, !rec.done),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: rec.done ? palette.ok : Colors.transparent,
                      border: Border.all(
                        color: rec.done ? palette.ok : palette.border,
                        width: 2,
                      ),
                    ),
                    child: rec.done
                        ? const Icon(
                            Icons.check,
                            size: 20,
                            color: Color(0xFF0B2014),
                          )
                        : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        rec.text,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14.5,
                          color: rec.done ? palette.text2 : palette.text,
                          decoration: rec.done
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        rec.why,
                        style: TextStyle(fontSize: 13, color: palette.text2),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildBiomarkersSection(ApoloPalette palette) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'What your urine says',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: palette.text,
          ),
        ),
        const SizedBox(height: 8),
        for (final bm in widget.snapshot.biomarkers)
          _BiomarkerRow(
            reading: bm,
            palette: palette,
            highContrast: widget.astronautState.highContrast,
          ),
      ],
    );
  }

  Widget _buildTrendCard(ApoloPalette palette, List<double> values) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(20),
        border: widget.astronautState.highContrast
            ? Border.all(color: palette.border)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${widget.snapshot.primaryBiomarkerName} · last ${values.length} samples',
            style: TextStyle(fontSize: 13, color: palette.text2),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 56,
            width: double.infinity,
            child: CustomPaint(
              painter: ApoloSparklinePainter(
                values: values,
                color: palette.lav2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWhyItMatters(ApoloPalette palette) {
    return Container(
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(20),
        border: widget.astronautState.highContrast
            ? Border.all(color: palette.border)
            : null,
      ),
      child: InkWell(
        key: const ValueKey('apolo_why_toggle'),
        borderRadius: BorderRadius.circular(20),
        onTap: () => setState(() => _whyExpanded = !_whyExpanded),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Why does it matter in space?',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: palette.text,
                        fontSize: 14.5,
                      ),
                    ),
                  ),
                  Icon(
                    _whyExpanded ? Icons.expand_less : Icons.expand_more,
                    color: palette.text2,
                  ),
                ],
              ),
              if (_whyExpanded) ...[
                const SizedBox(height: 8),
                Text(
                  widget.snapshot.whyItMatters,
                  style: TextStyle(fontSize: 14, color: palette.text2),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons(ApoloPalette palette) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        FilledButton.icon(
          key: const ValueKey('apolo_detail_ask_button'),
          style: FilledButton.styleFrom(
            backgroundColor: palette.text,
            foregroundColor: const Color(0xFF16142E),
            minimumSize: const Size(150, 50),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(26),
            ),
          ),
          onPressed: widget.onAskApolo,
          icon: const Icon(Icons.pets, size: 19),
          label: const Text(
            'Ask Apolo',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        if (widget.snapshot.severity == ApoloSeverity.ok)
          FilledButton.tonalIcon(
            key: const ValueKey('apolo_detail_hide_button'),
            style: FilledButton.styleFrom(
              backgroundColor: palette.surface,
              foregroundColor: palette.text,
              minimumSize: const Size(130, 50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(26),
                side: BorderSide(color: palette.border),
              ),
            ),
            onPressed: widget.onHideOrb,
            icon: const Icon(Icons.visibility_off_outlined, size: 19),
            label: const Text(
              'Hide',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
      ],
    );
  }
}

class _QuickLogButton extends StatelessWidget {
  const _QuickLogButton({
    super.key,
    required this.label,
    required this.palette,
    required this.onTap,
  });

  final String label;
  final ApoloPalette palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      style: FilledButton.styleFrom(
        backgroundColor: palette.elev,
        foregroundColor: palette.text,
        minimumSize: const Size(0, 44),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      ),
      onPressed: onTap,
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
    );
  }
}

class _BiomarkerRow extends StatelessWidget {
  const _BiomarkerRow({
    required this.reading,
    required this.palette,
    required this.highContrast,
  });

  final ApoloBiomarkerReading reading;
  final ApoloPalette palette;
  final bool highContrast;

  @override
  Widget build(BuildContext context) {
    final dotColor = palette.forSeverity(reading.severity);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: palette.border.withValues(alpha: 0.35)),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                flex: 3,
                child: Text(
                  reading.def.name,
                  style: TextStyle(fontSize: 14, color: palette.text),
                ),
              ),
              const SizedBox(width: 8),
              Text.rich(
                TextSpan(
                  text: reading.formattedValue,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14.5,
                    color: palette.text,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                  children: [
                    if (reading.def.unit.isNotEmpty)
                      TextSpan(
                        text: ' ${reading.def.unit}',
                        style: TextStyle(
                          fontWeight: FontWeight.w400,
                          fontSize: 12,
                          color: palette.text2,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              ApoloStatusChip(
                severity: reading.severity,
                highContrast: highContrast,
                compact: true,
              ),
            ],
          ),
          if (!reading.def.isBoolean) ...[
            const SizedBox(height: 6),
            LayoutBuilder(
              builder: (context, constraints) {
                final w = constraints.maxWidth;
                final bandLeft = reading.normalizedBandStart * w;
                final bandWidth = (reading.normalizedBandWidth * w).clamp(
                  4.0,
                  w,
                );
                final dotX = (reading.normalizedPosition * w).clamp(
                  7.0,
                  w - 7.0,
                );
                return SizedBox(
                  height: 14,
                  width: double.infinity,
                  child: Stack(
                    alignment: Alignment.centerLeft,
                    children: [
                      Container(
                        height: 8,
                        decoration: BoxDecoration(
                          color: palette.surface,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      Positioned(
                        left: bandLeft,
                        width: bandWidth,
                        child: Container(
                          height: 8,
                          decoration: BoxDecoration(
                            color: palette.ok.withValues(alpha: 0.28),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                      Positioned(
                        left: dotX - 7,
                        child: Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: dotColor,
                            border: Border.all(color: palette.bg2, width: 2),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

/// 14-sample sparkline `CustomPainter` for the opened module's primary biomarker.
class ApoloSparklinePainter extends CustomPainter {
  const ApoloSparklinePainter({required this.values, required this.color});

  final List<double> values;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty || size.isEmpty) return;
    final pts = values.length < 2 ? [values.first, values.first] : values;
    var minVal = pts.first;
    var maxVal = pts.first;
    for (final v in pts) {
      if (v < minVal) minVal = v;
      if (v > maxVal) maxVal = v;
    }
    final span = (maxVal - minVal).abs() < 1e-9 ? 1.0 : (maxVal - minVal);
    final padY = 5.0;
    final usableH = math.max(1.0, size.height - padY * 2);

    final path = Path();
    Offset? lastPoint;
    for (var i = 0; i < pts.length; i++) {
      final x = i * (size.width / (pts.length - 1));
      final y = size.height - padY - ((pts[i] - minVal) / span) * usableH;
      final p = Offset(x, y);
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
      lastPoint = p;
    }

    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = color,
    );

    if (lastPoint != null) {
      canvas.drawCircle(lastPoint, 3.6, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(covariant ApoloSparklinePainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.values != values;
  }
}
