import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:astramed/features/agent/providers/agent_providers.dart';
import 'package:astramed/features/crew/models/astronaut_profile.dart';
import 'package:astramed/features/crew/presentation/providers/crew_provider.dart';

import '../domain/apolo_models.dart';
import '../providers/apolo_contract_providers.dart';
import '../providers/apolo_alert_state_provider.dart';
import 'apolo_theme.dart';

/// Crew selector & cockpit preference menu opened from the top bar crew button.
class ApoloCrewMenuDialog extends ConsumerWidget {
  const ApoloCrewMenuDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (_) => const ApoloCrewMenuDialog(),
    );
  }

  ApoloSeverity _fallbackSeverity(CrewRiskLevel level) => switch (level) {
    CrewRiskLevel.nominal => ApoloSeverity.ok,
    CrewRiskLevel.warning => ApoloSeverity.warn,
    CrewRiskLevel.critical => ApoloSeverity.crit,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final apoloState = ref.watch(apoloActiveStateProvider);
    final actions = ref.watch(apoloActionsProvider);
    final crew = ref.watch(crewMembersProvider);
    final selectedId = ref.watch(selectedAstronautIdProvider);
    final voiceEnabled = ref.watch(agentVoiceRepliesEnabledProvider);
    final handsFreeState = ref.watch(handsFreeControllerProvider);

    final palette = ApoloPalette.of(apoloState.highContrast);

    return Dialog(
      backgroundColor: palette.bg2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
        side: BorderSide(color: palette.border),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400, maxHeight: 620),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'CREW',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.1,
                        color: palette.text2,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close crew menu',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.close, color: palette.text2, size: 20),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              for (final member in crew)
                _buildCrewRow(
                  context: context,
                  ref: ref,
                  member: member,
                  selectedId: selectedId,
                  actions: actions,
                  palette: palette,
                  highContrast: apoloState.highContrast,
                ),
              Divider(color: palette.border, height: 22),
              _SwitchRow(
                switchKey: const ValueKey('apolo_switch_autotips'),
                icon: Icons.auto_awesome_outlined,
                label: 'Auto-tips (spontaneous)',
                value: apoloState.autoTips,
                palette: palette,
                onChanged: (val) => actions.setAutoTips(val),
              ),
              _SwitchRow(
                switchKey: const ValueKey('apolo_switch_high_contrast'),
                icon: Icons.contrast,
                label: 'Cockpit mode (high contrast)',
                value: apoloState.highContrast,
                palette: palette,
                onChanged: (val) => actions.setHighContrast(val),
              ),
              _SwitchRow(
                switchKey: const ValueKey('apolo_switch_voice_replies'),
                icon: Icons.volume_up_outlined,
                label: 'Voice replies (TTS)',
                value: voiceEnabled,
                palette: palette,
                onChanged: (val) {
                  ref.read(agentVoiceRepliesEnabledProvider.notifier).state =
                      val;
                  if (!val) {
                    ref.read(trackedTextToSpeechProvider).stop();
                  }
                },
              ),
              _SwitchRow(
                switchKey: const ValueKey('apolo_switch_hands_free'),
                icon: Icons.hearing_outlined,
                label: 'Hands-free active listening',
                value: handsFreeState.enabled,
                palette: palette,
                onChanged: (val) {
                  ref
                      .read(handsFreeControllerProvider.notifier)
                      .setEnabled(val);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCrewRow({
    required BuildContext context,
    required WidgetRef ref,
    required AstronautProfile member,
    required String selectedId,
    required ApoloStateActions actions,
    required ApoloPalette palette,
    required bool highContrast,
  }) {
    final isSelected = member.id == selectedId;
    final severity = ref.watch(crewEffectiveStatusesProvider)[member.id]?.severity
        ?? _fallbackSeverity(member.riskLevel);
    int avatarColorHex = 0xFFB3E9C7;
    try {
      final s = actions.stateFor(member.id);
      if (s.astronautId == member.id) {
        avatarColorHex = s.colorHex;
      }
    } catch (_) {
      // Keep the profile avatar color when an isolated controller is unavailable.
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: InkWell(
        key: ValueKey('apolo_crew_member_${member.id}'),
        borderRadius: BorderRadius.circular(18),
        onTap: () {
          actions.openDetail(null);
          if (member.id != selectedId) {
            ref.read(selectedAstronautIdProvider.notifier).state = member.id;
            ref
                .read(agentOrchestratorProvider.notifier)
                .switchAstronaut(member.id);
          }
          Navigator.of(context).pop();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? palette.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(18),
            border: isSelected && highContrast
                ? Border.all(color: palette.border)
                : null,
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: Color(avatarColorHex),
                child: Text(
                  member.avatarInitials,
                  style: const TextStyle(
                    color: Color(0xFF14122C),
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      member.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: palette.text,
                        fontSize: 14.5,
                      ),
                    ),
                    Text(
                      member.role,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12.5, color: palette.text2),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ApoloStatusChip(
                severity: severity,
                highContrast: highContrast,
                compact: true,
              ),
              if (isSelected) ...[
                const SizedBox(width: 6),
                Icon(Icons.check, size: 18, color: palette.ok),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.switchKey,
    required this.icon,
    required this.label,
    required this.value,
    required this.palette,
    required this.onChanged,
  });

  final Key switchKey;
  final IconData icon;
  final String label;
  final bool value;
  final ApoloPalette palette;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(icon, size: 20, color: palette.text2),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: 14, color: palette.text),
            ),
          ),
          Switch(
            key: switchKey,
            value: value,
            activeThumbColor: palette.bg2,
            activeTrackColor: palette.ok,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
