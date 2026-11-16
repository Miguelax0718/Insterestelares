import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:astramed/core/theme/space_theme.dart';
import 'package:astramed/features/agent/domain/agent_contracts.dart';
import 'package:astramed/features/agent/domain/agent_models.dart';

import '../domain/apolo_models.dart';
import 'apolo_theme.dart';

/// Kind of chat circle shown next to Apolo.
enum ApoloChatOrbKind {
  /// An answer written by the clinical agent (or the offline flow).
  reply,

  /// A clinical component injected by the agent (test, card, alert...).
  component,
}

/// Data for a chat circle: every agent reply and every injected clinical
/// component appears as a floating circle that can be opened to read or
/// interact with it, just like the health circles.
@immutable
class ApoloChatOrbData {
  const ApoloChatOrbData({
    required this.key,
    required this.kind,
    required this.title,
    required this.preview,
    required this.icon,
    this.severity,
    this.message,
    this.componentId,
    this.isLatest = false,
    this.interactive = false,
  });

  /// Stable key: `reply_<index>` for replies, `component_<id>` for components.
  final String key;
  final ApoloChatOrbKind kind;
  final String title;
  final String preview;
  final IconData icon;

  /// Severity color for alert-like components; `null` uses lavender.
  final ApoloSeverity? severity;
  final ChatMessage? message;
  final String? componentId;
  final bool isLatest;

  /// Components that wait for the astronaut (tests, questionnaires...).
  final bool interactive;

  static const int maxReplyOrbs = 3;

  /// Components that ask the astronaut to do something.
  static const Set<String> interactiveComponents = {
    ComponentIds.graybielQuestionnaire,
    ComponentIds.pvtTest,
    ComponentIds.mptTest,
    ComponentIds.sansGrid,
    ComponentIds.sansContrast,
    ComponentIds.sansFocus,
    ComponentIds.lbnpRamp,
    ComponentIds.ultrasoundGuide,
    ComponentIds.diaryRecorder,
    ComponentIds.confirmAction,
    ComponentIds.recommendations,
    'zero_g_horizon',
    'dva_gaze',
    'mission_simulator',
    'manual_vitals',
    'medical_procedures',
  };

  /// Builds the chat circles from the agent session: first the injected
  /// components (they may need action), then the latest replies (newest
  /// first). Replies the astronaut hid are skipped.
  static List<ApoloChatOrbData> fromSession({
    required List<ChatMessage> messages,
    required List<AgentViewModel> components,
    Set<int> hiddenReplyIndexes = const {},
    int maxReplies = maxReplyOrbs,
  }) {
    final out = <ApoloChatOrbData>[];
    for (final vm in components) {
      out.add(_fromComponent(vm));
    }

    final replyIdx = <int>[
      for (var i = messages.length - 1; i >= 0; i--)
        if (messages[i].role == ChatRole.assistant &&
            messages[i].content.trim().isNotEmpty)
          i,
    ];
    final latest = replyIdx.isEmpty ? -1 : replyIdx.first;
    var added = 0;
    for (final i in replyIdx) {
      if (added >= maxReplies) break;
      if (hiddenReplyIndexes.contains(i)) continue;
      final msg = messages[i];
      out.add(
        ApoloChatOrbData(
          key: 'reply_$i',
          kind: ApoloChatOrbKind.reply,
          title: i == latest ? 'Latest reply' : 'Earlier reply',
          preview: previewOf(msg.content),
          icon: Icons.chat_bubble_outline_rounded,
          message: msg,
          isLatest: i == latest,
        ),
      );
      added++;
    }
    return out;
  }

  static ApoloChatOrbData _fromComponent(AgentViewModel vm) {
    final props = _safeProps(vm);
    final rawTitle = vm.title.trim().isNotEmpty
        ? vm.title.trim()
        : (props['title']?.toString() ?? humanize(vm.componentId));
    final summary =
        (props['summary'] ?? props['message'] ?? props['instruction'])
            ?.toString();
    return ApoloChatOrbData(
      key: 'component_${vm.componentId}',
      kind: ApoloChatOrbKind.component,
      title: rawTitle,
      preview: summary != null && summary.trim().isNotEmpty
          ? previewOf(summary)
          : (interactiveComponents.contains(vm.componentId)
                ? 'Tap to start'
                : 'Tap to open'),
      icon: componentIcon(vm.componentId),
      severity: severityFromProps(props),
      componentId: vm.componentId,
      interactive: interactiveComponents.contains(vm.componentId),
    );
  }

  static Map<String, dynamic> _safeProps(AgentViewModel vm) {
    try {
      return vm.toProps();
    } catch (_) {
      return const {};
    }
  }

  /// First few words of a text, for the small label inside a circle.
  static String previewOf(String text, {int maxWords = 4}) {
    final words = text
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim()
        .split(' ')
        .where((w) => w.isNotEmpty)
        .toList();
    if (words.length <= maxWords) return words.join(' ');
    return '${words.take(maxWords).join(' ')}…';
  }

  /// `graybiel_questionnaire` -> `Graybiel questionnaire`.
  static String humanize(String id) {
    final s = id.replaceAll('_', ' ').trim();
    if (s.isEmpty) return 'Clinical tool';
    return s[0].toUpperCase() + s.substring(1);
  }

  static ApoloSeverity? severityFromProps(Map<String, dynamic> props) {
    for (final key in const [
      'severity',
      'risk_level',
      'alert_level',
      'status',
      'priority',
    ]) {
      final v = props[key]?.toString().toLowerCase();
      if (v == null) continue;
      if (v.contains('crit') || v == 'red' || v == 'emergency') {
        return ApoloSeverity.crit;
      }
      if (v.contains('warn') ||
          v.contains('caution') ||
          v.contains('urgent') ||
          v == 'yellow' ||
          v == 'attention') {
        return ApoloSeverity.warn;
      }
    }
    if (props['storm_active'] == true) return ApoloSeverity.warn;
    return null;
  }

  static IconData componentIcon(String id) => switch (id) {
    ComponentIds.vitalsCard => Icons.monitor_heart_outlined,
    ComponentIds.telemetryChart => Icons.show_chart_rounded,
    ComponentIds.crewStatus => Icons.groups_outlined,
    ComponentIds.statusReport => Icons.assignment_outlined,
    ComponentIds.evaReadiness => Icons.rocket_launch_outlined,
    ComponentIds.alertBanner => Icons.campaign_outlined,
    ComponentIds.spaceWeatherAlert => Icons.wb_sunny_outlined,
    ComponentIds.pharmacyBatches => Icons.medication_outlined,
    ComponentIds.ramanRequest => Icons.science_outlined,
    ComponentIds.medicationCheck => Icons.medication_liquid_outlined,
    ComponentIds.graybielQuestionnaire => Icons.quiz_outlined,
    ComponentIds.pvtTest => Icons.timer_outlined,
    ComponentIds.mptTest => Icons.touch_app_outlined,
    ComponentIds.sansGrid => Icons.grid_on_rounded,
    ComponentIds.sansContrast => Icons.contrast_rounded,
    ComponentIds.sansFocus => Icons.visibility_outlined,
    ComponentIds.exerciseMonitor => Icons.fitness_center_outlined,
    ComponentIds.lbnpRamp => Icons.compress_rounded,
    ComponentIds.ultrasoundGuide => Icons.sensors_outlined,
    ComponentIds.diaryRecorder => Icons.mic_none_rounded,
    ComponentIds.recommendations => Icons.checklist_rounded,
    ComponentIds.confirmAction => Icons.verified_user_outlined,
    'zero_g_horizon' => Icons.explore_outlined,
    'dva_gaze' => Icons.remove_red_eye_outlined,
    'mission_simulator' => Icons.rocket_launch_outlined,
    'manual_vitals' => Icons.touch_app_outlined,
    'medical_procedures' => Icons.medical_services_outlined,
    _ => Icons.medical_services_outlined,
  };
}

/// Floating circle for an agent reply or an injected clinical component.
///
/// Pops out of Apolo when it first appears, floats like the health circles
/// and, for components that wait for the astronaut, shows a pulsing ring.
class ApoloChatOrbWidget extends StatefulWidget {
  const ApoloChatOrbWidget({
    super.key,
    required this.data,
    required this.onTap,
    this.highContrast = false,
    this.compactScale = 1.0,
  });

  final ApoloChatOrbData data;
  final VoidCallback onTap;
  final bool highContrast;
  final double compactScale;

  double get baseDiameter => data.kind == ApoloChatOrbKind.component
      ? 136.0
      : (data.isLatest ? 128.0 : 112.0);

  @override
  State<ApoloChatOrbWidget> createState() => _ApoloChatOrbWidgetState();
}

class _ApoloChatOrbWidgetState extends State<ApoloChatOrbWidget>
    with TickerProviderStateMixin {
  late final AnimationController _float;
  late final AnimationController _enter;
  bool _hovered = false;

  int get _seed => widget.data.key.codeUnits.fold(0, (a, b) => a + b);

  @override
  void initState() {
    super.initState();
    _float = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 6000 + (_seed % 4) * 700),
    );
    _enter = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final disabled = MediaQuery.disableAnimationsOf(context);
    if (disabled) {
      _float.stop();
      _enter.value = 1.0;
    } else {
      if (!_float.isAnimating) _float.repeat();
      if (_enter.value == 0.0 && !_enter.isAnimating) _enter.forward();
    }
  }

  @override
  void dispose() {
    _float.dispose();
    _enter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = ApoloPalette.of(widget.highContrast);
    final data = widget.data;
    final accent = data.severity != null
        ? palette.forSeverity(data.severity!)
        : (data.kind == ApoloChatOrbKind.reply ? palette.lav2 : palette.mint);
    final diameter = (widget.baseDiameter * widget.compactScale).clamp(
      88.0,
      170.0,
    );
    final disable = MediaQuery.disableAnimationsOf(context);
    final pulse = data.interactive || data.severity == ApoloSeverity.crit;
    final seed = _seed;

    final body = Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        key: ValueKey('apolo_chat_orb_${data.key}'),
        customBorder: const CircleBorder(),
        onTap: widget.onTap,
        child: Container(
          width: diameter,
          height: diameter,
          padding: EdgeInsets.all(diameter * 0.1),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
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
                      accent.withValues(alpha: 0.26),
                    ],
                    stops: const [0.0, 0.55, 1.0],
                  ),
            border: Border.all(
              color: widget.highContrast
                  ? accent
                  : accent.withValues(alpha: 0.8),
              width: widget.highContrast ? 3 : 2,
              // Replies use a dashed-looking thinner ring through opacity;
              // components use the solid accent ring.
            ),
            boxShadow: widget.highContrast
                ? null
                : [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.12),
                      spreadRadius: 4,
                    ),
                    BoxShadow(
                      color: accent.withValues(alpha: 0.22),
                      blurRadius: 22,
                    ),
                  ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: (diameter * 0.26).clamp(24.0, 40.0),
                height: (diameter * 0.26).clamp(24.0, 40.0),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accent.withValues(alpha: 0.18),
                ),
                child: Icon(
                  data.icon,
                  size: (diameter * 0.15).clamp(14.0, 22.0),
                  color: accent,
                ),
              ),
              const SizedBox(height: 4),
              Flexible(
                child: Text(
                  data.kind == ApoloChatOrbKind.reply
                      ? data.preview
                      : data.title,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: (diameter * 0.095).clamp(11.0, 14.5),
                    fontWeight: FontWeight.w700,
                    color: palette.text,
                    height: 1.15,
                  ),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                data.kind == ApoloChatOrbKind.reply
                    ? (data.isLatest ? 'Apolo · new' : 'Apolo')
                    : (data.interactive ? 'Tap to start' : 'Apolo'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: (diameter * 0.078).clamp(10.0, 12.5),
                  fontWeight: FontWeight.w600,
                  color: accent,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return Semantics(
      button: true,
      label: data.kind == ApoloChatOrbKind.reply
          ? 'Apolo reply: ${data.message?.content ?? data.preview}. Open to read'
          : '${data.title}. ${data.interactive ? 'Needs your input. ' : ''}Open',
      child: AnimatedBuilder(
        animation: Listenable.merge([_float, _enter]),
        builder: (context, child) {
          final t = disable ? 0.0 : _float.value;
          final dx = disable
              ? 0.0
              : math.sin((t + seed * 0.13) * math.pi * 2) * 4.0;
          final dy = disable
              ? 0.0
              : math.cos((t + seed * 0.19) * math.pi * 2) * 5.0;
          final e = Curves.easeOutBack.transform(_enter.value.clamp(0.0, 1.0));
          final phase = disable ? 0.0 : (t * 2.0) % 1.0;
          return Opacity(
            opacity: _enter.value.clamp(0.0, 1.0),
            child: Transform.translate(
              offset: Offset(dx, dy),
              child: Transform.scale(
                scale: 0.2 + 0.8 * e,
                child: SizedBox(
                  width: diameter + 16,
                  height: diameter + 16,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      if (pulse && !disable)
                        IgnorePointer(
                          child: Transform.scale(
                            scale: 1.0 + phase * 0.28,
                            child: Container(
                              width: diameter,
                              height: diameter,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: accent.withValues(
                                    alpha: (1.0 - phase) * 0.6,
                                  ),
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                        ),
                      child!,
                    ],
                  ),
                ),
              ),
            ),
          );
        },
        child: MouseRegion(
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: AnimatedScale(
            scale: _hovered ? 1.06 : 1.0,
            duration: disable
                ? Duration.zero
                : const Duration(milliseconds: 200),
            curve: Curves.easeOutBack,
            child: body,
          ),
        ),
      ),
    );
  }
}

/// Overlay card that opens when a chat circle is tapped: shows the full
/// reply text, or hosts the clinical component widget so the astronaut can
/// read it or complete the test.
class ApoloChatSheet extends StatelessWidget {
  const ApoloChatSheet({
    super.key,
    required this.data,
    required this.highContrast,
    required this.onClose,
    this.componentBody,
    this.onReadAloud,
    this.onHide,
    this.onAskMore,
  });

  final ApoloChatOrbData data;
  final bool highContrast;
  final VoidCallback onClose;

  /// The component widget (built by the agent's widget registry).
  final Widget? componentBody;
  final VoidCallback? onReadAloud;
  final VoidCallback? onHide;
  final VoidCallback? onAskMore;

  @override
  Widget build(BuildContext context) {
    final palette = ApoloPalette.of(highContrast);
    final size = MediaQuery.sizeOf(context);
    final narrow = size.width < 760;
    final accent = data.severity != null
        ? palette.forSeverity(data.severity!)
        : (data.kind == ApoloChatOrbKind.reply ? palette.lav2 : palette.mint);

    final card = Material(
      color: Colors.transparent,
      child: Container(
        key: const ValueKey('apolo_chat_sheet'),
        constraints: BoxConstraints(
          maxWidth: narrow ? double.infinity : 600,
          maxHeight: narrow
              ? size.height * 0.88
              : math.min(size.height * 0.86, 820),
        ),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: palette.bg2,
          borderRadius: narrow
              ? const BorderRadius.vertical(top: Radius.circular(30))
              : BorderRadius.circular(32),
          border: Border.all(color: palette.border),
          boxShadow: highContrast
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
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(height: 4, color: accent),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: accent.withValues(alpha: 0.18),
                    ),
                    child: Icon(data.icon, color: accent, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          data.kind == ApoloChatOrbKind.reply
                              ? 'Apolo says'
                              : data.title,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: palette.text,
                          ),
                        ),
                        Text(
                          data.kind == ApoloChatOrbKind.reply
                              ? (data.isLatest
                                    ? 'Latest reply'
                                    : 'Earlier reply')
                              : (data.interactive
                                    ? 'Clinical test · needs your input'
                                    : 'Clinical information'),
                          style: TextStyle(fontSize: 13, color: palette.text2),
                        ),
                      ],
                    ),
                  ),
                  if (data.severity != null) ...[
                    ApoloStatusChip(
                      severity: data.severity!,
                      highContrast: highContrast,
                    ),
                    const SizedBox(width: 6),
                  ],
                  IconButton(
                    key: const ValueKey('apolo_chat_sheet_close'),
                    tooltip: 'Close',
                    onPressed: onClose,
                    style: IconButton.styleFrom(
                      backgroundColor: palette.surface,
                      foregroundColor: palette.text,
                      fixedSize: const Size(44, 44),
                    ),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                child: data.kind == ApoloChatOrbKind.reply
                    ? SelectableText(
                        data.message?.content ?? data.preview,
                        key: const ValueKey('apolo_chat_sheet_text'),
                        style: TextStyle(
                          fontSize: 16.5,
                          height: 1.5,
                          color: palette.text,
                        ),
                      )
                    : Theme(
                        // Clinical components were designed for the cockpit
                        // dark theme; keep them readable inside the sheet.
                        data: Theme.of(context).brightness == Brightness.dark
                            ? Theme.of(context)
                            : SpaceTheme.darkTheme,
                        child: componentBody ?? const SizedBox.shrink(),
                      ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                8,
                20,
                16 + MediaQuery.paddingOf(context).bottom,
              ),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (onReadAloud != null)
                    _SheetButton(
                      key: const ValueKey('apolo_chat_sheet_read_aloud'),
                      icon: Icons.volume_up_outlined,
                      label: 'Read aloud',
                      palette: palette,
                      onTap: onReadAloud!,
                    ),
                  if (onAskMore != null)
                    _SheetButton(
                      key: const ValueKey('apolo_chat_sheet_ask_more'),
                      icon: Icons.pets_outlined,
                      label: 'Tell me more',
                      palette: palette,
                      onTap: onAskMore!,
                    ),
                  if (onHide != null)
                    _SheetButton(
                      key: const ValueKey('apolo_chat_sheet_hide'),
                      icon: Icons.visibility_off_outlined,
                      label: 'Hide circle',
                      palette: palette,
                      onTap: onHide!,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    return Positioned.fill(
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              key: const ValueKey('apolo_chat_sheet_scrim'),
              onTap: onClose,
              child: Container(color: const Color(0x99050612)),
            ),
          ),
          if (narrow)
            Align(alignment: Alignment.bottomCenter, child: card)
          else
            Center(
              child: Padding(padding: const EdgeInsets.all(24), child: card),
            ),
        ],
      ),
    );
  }
}

class _SheetButton extends StatelessWidget {
  const _SheetButton({
    super.key,
    required this.icon,
    required this.label,
    required this.palette,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final ApoloPalette palette;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      style: FilledButton.styleFrom(
        backgroundColor: palette.elev,
        foregroundColor: palette.text,
        minimumSize: const Size(0, 46),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(23)),
      ),
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
    );
  }
}
