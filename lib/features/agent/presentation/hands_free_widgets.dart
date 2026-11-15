import 'package:flutter/material.dart';

import 'package:astramed/core/theme/space_theme.dart';

import '../application/hands_free_controller.dart';
import '../domain/agent_contracts.dart';

/// Replaceable widget registry ids for hands-free voice controls (S4).
abstract final class HandsFreeWidgetIds {
  static const String toggle = 'hands_free_toggle';
  static const String listeningIndicator = 'listening_indicator';
}

class HandsFreeToggleViewModel extends AgentViewModel {
  HandsFreeToggleViewModel({
    required this.enabled,
    required this.status,
    required this.permissionDenied,
    required this.supported,
    this.errorMessage,
  }) : super(
         componentId: HandsFreeWidgetIds.toggle,
         title: 'Hands-Free Listening',
       );

  final bool enabled;
  final HandsFreeStatus status;
  final bool permissionDenied;
  final bool supported;
  final String? errorMessage;

  @override
  Map<String, dynamic> toProps() => {
    'component_id': componentId,
    'title': title,
    'enabled': enabled,
    'status': status.name,
    'permission_denied': permissionDenied,
    'supported': supported,
    if (errorMessage != null) 'error_message': errorMessage,
  };
}

class ListeningIndicatorViewModel extends AgentViewModel {
  ListeningIndicatorViewModel({
    required this.status,
    required this.handsFreeEnabled,
    required this.manualListening,
    this.usingLocalFallback = false,
    this.errorMessage,
  }) : super(
         componentId: HandsFreeWidgetIds.listeningIndicator,
         title: _labelFor(status, manualListening: manualListening),
       );

  final HandsFreeStatus status;
  final bool handsFreeEnabled;
  final bool manualListening;
  final bool usingLocalFallback;
  final String? errorMessage;

  static String _labelFor(
    HandsFreeStatus status, {
    required bool manualListening,
  }) {
    if (manualListening) {
      return 'Push-to-talk listening';
    }
    return switch (status) {
      HandsFreeStatus.off => 'Off (manual mode)',
      HandsFreeStatus.listening => 'Listening',
      HandsFreeStatus.hearingSpeech => 'Hearing speech',
      HandsFreeStatus.transcribing => 'Transcribing',
      HandsFreeStatus.pausedWhileSpeaking => 'Paused while speaking',
      HandsFreeStatus.permissionDenied => 'Mic permission denied',
      HandsFreeStatus.error => 'Voice error',
    };
  }

  @override
  Map<String, dynamic> toProps() => {
    'component_id': componentId,
    'title': title,
    'status': status.name,
    'hands_free_enabled': handsFreeEnabled,
    'manual_listening': manualListening,
    'using_local_fallback': usingLocalFallback,
    if (errorMessage != null) 'error_message': errorMessage,
  };
}

class HandsFreeTogglePlaceholder extends StatelessWidget {
  const HandsFreeTogglePlaceholder({
    super.key,
    required this.viewModel,
    required this.onToggle,
  });

  final HandsFreeToggleViewModel viewModel;
  final void Function(bool nextEnabled) onToggle;

  @override
  Widget build(BuildContext context) {
    final active = viewModel.enabled;
    final accent = viewModel.permissionDenied
        ? SpaceTheme.dangerRed
        : (active ? SpaceTheme.cyan : Colors.white54);

    return Tooltip(
      message: active
          ? 'Disable hands-free listening'
          : 'Enable hands-free listening',
      child: InkWell(
        key: const ValueKey(HandsFreeWidgetIds.toggle),
        borderRadius: BorderRadius.circular(999),
        onTap: () => onToggle(!active),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: active
                ? SpaceTheme.cyan.withValues(alpha: 0.14)
                : SpaceTheme.card,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: accent.withValues(alpha: active ? 0.8 : 0.35),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                active ? Icons.hearing : Icons.hearing_disabled,
                size: 15,
                color: accent,
              ),
              const SizedBox(width: 6),
              Text(
                active ? 'Hands-Free ON' : 'Hands-Free Off',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: active ? Colors.white : Colors.white70,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ListeningIndicatorPlaceholder extends StatelessWidget {
  const ListeningIndicatorPlaceholder({super.key, required this.viewModel});

  final ListeningIndicatorViewModel viewModel;

  Color _statusColor() {
    if (viewModel.manualListening) {
      return SpaceTheme.green;
    }
    return switch (viewModel.status) {
      HandsFreeStatus.off => Colors.white54,
      HandsFreeStatus.listening => SpaceTheme.cyan,
      HandsFreeStatus.hearingSpeech => SpaceTheme.green,
      HandsFreeStatus.transcribing => SpaceTheme.warningYellow,
      HandsFreeStatus.pausedWhileSpeaking => Colors.amberAccent,
      HandsFreeStatus.permissionDenied ||
      HandsFreeStatus.error => SpaceTheme.dangerRed,
    };
  }

  IconData _statusIcon() {
    if (viewModel.manualListening) {
      return Icons.mic;
    }
    return switch (viewModel.status) {
      HandsFreeStatus.off => Icons.mic_off_outlined,
      HandsFreeStatus.listening => Icons.graphic_eq,
      HandsFreeStatus.hearingSpeech => Icons.record_voice_over,
      HandsFreeStatus.transcribing => Icons.hourglass_top,
      HandsFreeStatus.pausedWhileSpeaking => Icons.volume_up_outlined,
      HandsFreeStatus.permissionDenied => Icons.no_encryption_gmailerrorred,
      HandsFreeStatus.error => Icons.error_outline,
    };
  }

  @override
  Widget build(BuildContext context) {
    final color = _statusColor();
    final label =
        viewModel.usingLocalFallback &&
            viewModel.status == HandsFreeStatus.listening
        ? '${viewModel.title} · Local'
        : viewModel.title;

    return Container(
      key: const ValueKey(HandsFreeWidgetIds.listeningIndicator),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color),
          ),
          const SizedBox(width: 6),
          Icon(_statusIcon(), size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
