import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:astramed/core/theme/space_theme.dart';
import 'package:astramed/features/crew/models/astronaut_profile.dart';
import 'package:astramed/features/crew/presentation/providers/crew_provider.dart';

import '../application/agent_conversation_controller.dart';
import '../domain/agent_contracts.dart';
import '../domain/agent_models.dart';
import '../providers/agent_providers.dart';

/// Primary autonomous clinical agent canvas (`Plan de Arquitectura Agente.md` §2).
///
/// Remains visually quiet when parameters are nominal and dynamically injects
/// replaceable component widgets when skills or proactive rules emit them.
class AgentCanvasView extends ConsumerStatefulWidget {
  const AgentCanvasView({super.key});

  static const ValueKey<String> injectionZoneKey = ValueKey(
    'agent_injection_zone',
  );
  static const ValueKey<String> textInputKey = ValueKey('agent_text_input');
  static const ValueKey<String> sendButtonKey = ValueKey('agent_send_button');
  static const ValueKey<String> micButtonKey = ValueKey('agent_mic_button');
  static const ValueKey<String> ttsToggleKey = ValueKey('agent_tts_toggle');
  static const ValueKey<String> statusIndicatorKey = ValueKey(
    'agent_status_indicator',
  );
  static const ValueKey<String> transcriptToggleKey = ValueKey(
    'agent_transcript_toggle',
  );
  static const ValueKey<String> confirmationBannerKey = ValueKey(
    'agent_confirmation_banner',
  );
  static const ValueKey<String> crewSidebarKey = ValueKey('agent_crew_sidebar');

  static const double wideBreakpoint = 900.0;

  @override
  ConsumerState<AgentCanvasView> createState() => _AgentCanvasViewState();
}

class _AgentCanvasViewState extends ConsumerState<AgentCanvasView> {
  final TextEditingController _inputController = TextEditingController();
  final Set<AgentViewModel> _dismissedViewModels =
      Set<AgentViewModel>.identity();

  bool _listening = false;
  bool _speakReplies = true;
  bool _transcriptExpanded = false;
  String? _voiceError;

  AgentConversationController? _controllerRef;

  @override
  void dispose() {
    final controller = _controllerRef;
    if (controller != null) {
      controller.closeSession();
    }
    _inputController.dispose();
    super.dispose();
  }

  void _pruneDismissed(List<AgentViewModel> active) {
    _dismissedViewModels.removeWhere(
      (dismissed) => !active.any((vm) => identical(vm, dismissed)),
    );
  }

  Future<void> _sendText() async {
    final text = _inputController.text.trim();
    if (text.isEmpty) {
      return;
    }
    _inputController.clear();
    setState(() => _voiceError = null);
    await ref
        .read(agentOrchestratorProvider.notifier)
        .sendUserMessage(text, speakReply: _speakReplies);
  }

  Future<void> _toggleListening() async {
    final stt = ref.read(speechToTextServiceProvider);
    final tts = ref.read(textToSpeechServiceProvider);
    setState(() => _voiceError = null);

    try {
      if (!_listening) {
        await tts.stop();
        await stt.startListening(language: 'en');
        if (mounted) {
          setState(() => _listening = true);
        }
        return;
      }

      if (mounted) {
        setState(() => _listening = false);
      }
      final transcript = await stt.stopListening();
      if (transcript.trim().isEmpty) {
        if (mounted) {
          setState(() => _voiceError = 'No speech detected.');
        }
        return;
      }
      await ref
          .read(agentOrchestratorProvider.notifier)
          .sendUserMessage(transcript, speakReply: _speakReplies);
    } catch (e) {
      if (mounted) {
        setState(() {
          _listening = false;
          _voiceError = 'Voice input failed: $e';
        });
      }
    }
  }

  Future<void> _toggleTtsMute() async {
    final next = !_speakReplies;
    setState(() => _speakReplies = next);
    if (!next) {
      try {
        await ref.read(textToSpeechServiceProvider).stop();
      } catch (_) {
        // Ignore stop errors when muting.
      }
    }
  }

  void _selectAstronaut(String astronautId, {bool closeDrawer = false}) {
    ref.read(selectedAstronautIdProvider.notifier).state = astronautId;
    ref.read(agentOrchestratorProvider.notifier).switchAstronaut(astronautId);
    if (closeDrawer && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  void _handleComponentSubmit(
    AgentViewModel vm,
    Map<String, dynamic> result,
    AgentSessionState session,
  ) {
    final controller = ref.read(agentOrchestratorProvider.notifier);
    controller.submitComponentResult(vm.componentId, result);

    if (vm.componentId == ComponentIds.confirmAction &&
        session.pendingAction != null) {
      final rawDecision = result['decision']?.toString();
      final decision = rawDecision != null
          ? ConfirmationDecision.fromWire(rawDecision)
          : (result['confirmed'] == true
                ? ConfirmationDecision.confirmed
                : ConfirmationDecision.rejected);
      controller.resolveConfirmation(
        decision,
        reason: result['reason'] as String?,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<String>(selectedAstronautIdProvider, (previous, nextId) {
      final currentId = ref.read(agentOrchestratorProvider).astronautId;
      if (currentId != nextId) {
        ref.read(agentOrchestratorProvider.notifier).switchAstronaut(nextId);
      }
    });

    _controllerRef = ref.read(agentOrchestratorProvider.notifier);
    ref.watch(proactiveMonitorProvider);
    ref.watch(agentNotifierProvider);
    final session = ref.watch(agentOrchestratorProvider);
    final crew = ref.watch(crewMembersProvider);
    final activeAstronaut = ref.watch(selectedAstronautProvider);
    final mission = ref.watch(missionContextProvider);
    final widgetRegistry = ref.watch(componentWidgetRegistryProvider);

    _pruneDismissed(session.activeComponents);
    final visibleComponents = session.activeComponents
        .where((vm) => !_dismissedViewModels.any((d) => identical(d, vm)))
        .toList(growable: false);

    final hasVisibleConfirmCard = visibleComponents.any(
      (vm) => vm.componentId == ComponentIds.confirmAction,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= AgentCanvasView.wideBreakpoint;
        return Scaffold(
          backgroundColor: SpaceTheme.background,
          drawer: isWide
              ? null
              : Drawer(
                  backgroundColor: SpaceTheme.surface,
                  child: SafeArea(
                    child: _CrewSidebar(
                      crew: crew,
                      selectedId: activeAstronaut.id,
                      onSelect: (id) => _selectAstronaut(id, closeDrawer: true),
                    ),
                  ),
                ),
          body: SafeArea(
            child: Row(
              children: [
                if (isWide)
                  SizedBox(
                    width: 300,
                    child: _CrewSidebar(
                      crew: crew,
                      selectedId: activeAstronaut.id,
                      onSelect: (id) => _selectAstronaut(id),
                    ),
                  ),
                Expanded(
                  child: Column(
                    children: [
                      _MissionContextHeader(
                        astronaut: activeAstronaut,
                        mission: mission,
                        offlineMode: session.offlineMode,
                        showMenuButton: !isWide,
                      ),
                      const Divider(height: 1, color: Colors.white12),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 16,
                          ),
                          child: Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 780),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _SystemStatusIndicator(
                                    key: AgentCanvasView.statusIndicatorKey,
                                    session: session,
                                    riskLevel: activeAstronaut.riskLevel,
                                    astronautName: activeAstronaut.name,
                                  ),
                                  const SizedBox(height: 16),
                                  if (session.pendingAction != null &&
                                      !hasVisibleConfirmCard)
                                    _ConfirmationBanner(
                                      key:
                                          AgentCanvasView.confirmationBannerKey,
                                      action: session.pendingAction!,
                                      onConfirm: () => ref
                                          .read(
                                            agentOrchestratorProvider.notifier,
                                          )
                                          .resolveConfirmation(
                                            ConfirmationDecision.confirmed,
                                          ),
                                      onReject: () => ref
                                          .read(
                                            agentOrchestratorProvider.notifier,
                                          )
                                          .resolveConfirmation(
                                            ConfirmationDecision.rejected,
                                          ),
                                    ),
                                  KeyedSubtree(
                                    key: AgentCanvasView.injectionZoneKey,
                                    child: visibleComponents.isEmpty
                                        ? const SizedBox.shrink()
                                        : Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.stretch,
                                            children: [
                                              for (final vm
                                                  in visibleComponents)
                                                widgetRegistry.build(
                                                  context,
                                                  vm,
                                                  onSubmit: (result) =>
                                                      _handleComponentSubmit(
                                                        vm,
                                                        result,
                                                        session,
                                                      ),
                                                  onDismiss: () {
                                                    setState(() {
                                                      _dismissedViewModels.add(
                                                        vm,
                                                      );
                                                    });
                                                  },
                                                ),
                                            ],
                                          ),
                                  ),
                                  _CollapsibleTranscript(
                                    messages: session.messages,
                                    expanded: _transcriptExpanded,
                                    onToggle: () => setState(
                                      () => _transcriptExpanded =
                                          !_transcriptExpanded,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (_voiceError != null || session.lastError != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 4,
                          ),
                          child: Text(
                            _voiceError ?? session.lastError!,
                            style: const TextStyle(
                              fontSize: 12,
                              color: SpaceTheme.dangerRed,
                            ),
                          ),
                        ),
                      _VoiceAndTextBar(
                        controller: _inputController,
                        busy: session.busy,
                        listening: _listening,
                        speakReplies: _speakReplies,
                        onToggleMic: _toggleListening,
                        onToggleTts: _toggleTtsMute,
                        onSend: _sendText,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

enum _AgentVisualStatus {
  nominal(
    'NOMINAL',
    'All monitored systems nominal',
    SpaceTheme.green,
    Icons.check_circle_outline,
  ),
  caution(
    'CAUTION',
    'Clinical parameters require attention',
    SpaceTheme.warningYellow,
    Icons.warning_amber_rounded,
  ),
  critical(
    'CRITICAL',
    'Immediate clinical intervention required',
    SpaceTheme.dangerRed,
    Icons.emergency_outlined,
  ),
  offline(
    'OFFLINE',
    'Gateway unreachable · Local protocols active',
    Colors.amberAccent,
    Icons.cloud_off_outlined,
  ),
  busy(
    'BUSY',
    'Processing telemetry and clinical tools',
    SpaceTheme.cyan,
    Icons.graphic_eq,
  );

  const _AgentVisualStatus(this.label, this.subtitle, this.color, this.icon);

  final String label;
  final String subtitle;
  final Color color;
  final IconData icon;
}

class _SystemStatusIndicator extends StatelessWidget {
  const _SystemStatusIndicator({
    super.key,
    required this.session,
    required this.riskLevel,
    required this.astronautName,
  });

  final AgentSessionState session;
  final CrewRiskLevel riskLevel;
  final String astronautName;

  _AgentVisualStatus _resolveStatus() {
    if (session.busy) {
      return _AgentVisualStatus.busy;
    }
    if (riskLevel == CrewRiskLevel.critical) {
      return _AgentVisualStatus.critical;
    }
    if (riskLevel == CrewRiskLevel.warning) {
      return _AgentVisualStatus.caution;
    }
    if (session.offlineMode) {
      return _AgentVisualStatus.offline;
    }
    return _AgentVisualStatus.nominal;
  }

  @override
  Widget build(BuildContext context) {
    final status = _resolveStatus();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: SpaceTheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: status.color.withValues(alpha: 0.45)),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: status.color.withValues(alpha: 0.16),
              border: Border.all(color: status.color, width: 1.8),
            ),
            child: session.busy
                ? Padding(
                    padding: const EdgeInsets.all(14),
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: status.color,
                    ),
                  )
                : Icon(status.icon, color: status.color, size: 26),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      status.label,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.1,
                        color: status.color,
                      ),
                    ),
                    if (session.offlineMode &&
                        status != _AgentVisualStatus.offline) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.amberAccent.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          'OFFLINE',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Colors.amberAccent,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  '${status.subtitle} · $astronautName',
                  style: const TextStyle(fontSize: 12, color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MissionContextHeader extends StatelessWidget {
  const _MissionContextHeader({
    required this.astronaut,
    required this.mission,
    required this.offlineMode,
    required this.showMenuButton,
  });

  final AstronautProfile astronaut;
  final MissionContextMetadata mission;
  final bool offlineMode;
  final bool showMenuButton;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: SpaceTheme.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          if (showMenuButton) ...[
            Builder(
              builder: (drawerContext) => IconButton(
                tooltip: 'Open Crew Sidebar',
                icon: const Icon(Icons.groups_outlined, color: SpaceTheme.cyan),
                onPressed: () => Scaffold.of(drawerContext).openDrawer(),
              ),
            ),
            const SizedBox(width: 4),
          ],
          Expanded(
            child: Wrap(
              spacing: 12,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  '${astronaut.name} (${astronaut.callsign})',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                _HeaderMetaPill(
                  icon: Icons.calendar_today_outlined,
                  label: 'Mission Day ${mission.missionDay}',
                ),
                _HeaderMetaPill(
                  icon: Icons.public_outlined,
                  label: mission.gravityLabel,
                ),
                _HeaderMetaPill(
                  icon: Icons.settings_input_antenna,
                  label: offlineMode
                      ? 'Earth Comm: Offline'
                      : 'Earth Comm: ${mission.earthLatencyLabel}',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderMetaPill extends StatelessWidget {
  const _HeaderMetaPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: SpaceTheme.card,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: SpaceTheme.cyan),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: Colors.white70),
          ),
        ],
      ),
    );
  }
}

class _ConfirmationBanner extends StatelessWidget {
  const _ConfirmationBanner({
    super.key,
    required this.action,
    required this.onConfirm,
    required this.onReject,
  });

  final ConsequentialAction action;
  final VoidCallback onConfirm;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: SpaceTheme.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: SpaceTheme.warningYellow),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.shield_outlined,
                  color: SpaceTheme.warningYellow,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Crew Confirmation Required · ${action.actionType}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: SpaceTheme.warningYellow,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              action.description,
              style: const TextStyle(fontSize: 13, color: Colors.white),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                FilledButton.icon(
                  key: const ValueKey('confirm_action_confirm_button'),
                  style: FilledButton.styleFrom(
                    backgroundColor: SpaceTheme.green,
                    foregroundColor: Colors.black,
                  ),
                  onPressed: onConfirm,
                  icon: const Icon(Icons.check, size: 18),
                  label: const Text('Confirm'),
                ),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  key: const ValueKey('confirm_action_reject_button'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: SpaceTheme.dangerRed,
                    side: const BorderSide(color: SpaceTheme.dangerRed),
                  ),
                  onPressed: onReject,
                  icon: const Icon(Icons.close, size: 18),
                  label: const Text('Reject'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CollapsibleTranscript extends StatelessWidget {
  const _CollapsibleTranscript({
    required this.messages,
    required this.expanded,
    required this.onToggle,
  });

  final List<ChatMessage> messages;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final visible = messages
        .where(
          (m) =>
              (m.role == ChatRole.user || m.role == ChatRole.assistant) &&
              m.content.trim().isNotEmpty,
        )
        .toList(growable: false);
    if (visible.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(top: 4),
      decoration: BoxDecoration(
        color: SpaceTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        children: [
          InkWell(
            key: AgentCanvasView.transcriptToggleKey,
            borderRadius: BorderRadius.circular(12),
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  const Icon(
                    Icons.forum_outlined,
                    size: 16,
                    color: SpaceTheme.cyan,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Conversation Transcript (${visible.length})',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white70,
                      ),
                    ),
                  ),
                  Icon(
                    expanded ? Icons.expand_less : Icons.expand_more,
                    size: 18,
                    color: Colors.white54,
                  ),
                ],
              ),
            ),
          ),
          if (expanded) ...[
            const Divider(height: 1, color: Colors.white12),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final msg in visible)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Align(
                        alignment: msg.role == ChatRole.user
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: msg.role == ChatRole.user
                                ? SpaceTheme.cyan.withValues(alpha: 0.16)
                                : SpaceTheme.card,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            msg.content,
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _VoiceAndTextBar extends StatelessWidget {
  const _VoiceAndTextBar({
    required this.controller,
    required this.busy,
    required this.listening,
    required this.speakReplies,
    required this.onToggleMic,
    required this.onToggleTts,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool busy;
  final bool listening;
  final bool speakReplies;
  final VoidCallback onToggleMic;
  final VoidCallback onToggleTts;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: SpaceTheme.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          IconButton.filled(
            key: AgentCanvasView.micButtonKey,
            tooltip: listening ? 'Stop listening' : 'Push to talk',
            style: IconButton.styleFrom(
              backgroundColor: listening
                  ? SpaceTheme.dangerRed
                  : SpaceTheme.cyan,
              foregroundColor: Colors.black,
            ),
            onPressed: busy ? null : onToggleMic,
            icon: Icon(listening ? Icons.stop : Icons.mic),
          ),
          const SizedBox(width: 8),
          IconButton(
            key: AgentCanvasView.ttsToggleKey,
            tooltip: speakReplies ? 'Mute voice output' : 'Enable voice output',
            onPressed: onToggleTts,
            icon: Icon(
              speakReplies
                  ? Icons.volume_up_outlined
                  : Icons.volume_off_outlined,
              color: speakReplies ? SpaceTheme.cyan : Colors.white54,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              key: AgentCanvasView.textInputKey,
              controller: controller,
              enabled: !listening,
              decoration: InputDecoration(
                hintText: listening
                    ? 'Listening...'
                    : 'Ask the clinical agent or report symptoms...',
                isDense: true,
                filled: true,
                fillColor: SpaceTheme.card,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.white12),
                ),
              ),
              onSubmitted: (_) => onSend(),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filledTonal(
            key: AgentCanvasView.sendButtonKey,
            tooltip: 'Send message',
            onPressed: busy ? null : onSend,
            icon: const Icon(Icons.send),
          ),
        ],
      ),
    );
  }
}

class _CrewSidebar extends StatelessWidget {
  const _CrewSidebar({
    required this.crew,
    required this.selectedId,
    required this.onSelect,
  });

  final List<AstronautProfile> crew;
  final String selectedId;
  final void Function(String astronautId) onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: AgentCanvasView.crewSidebarKey,
      decoration: const BoxDecoration(
        color: SpaceTheme.surface,
        border: Border(right: BorderSide(color: Colors.white12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 10),
            child: Row(
              children: [
                Icon(Icons.groups_outlined, color: SpaceTheme.cyan, size: 20),
                SizedBox(width: 8),
                Text(
                  'CREW COHORT',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.1,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Colors.white12),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(10),
              itemCount: crew.length,
              itemBuilder: (context, index) {
                final member = crew[index];
                final isSelected = member.id == selectedId;
                final statusColor = _riskColor(member.riskLevel);
                final pendingCountermeasures = member.exercise.targetReached
                    ? 0
                    : 1;
                final alertAndCmCount =
                    member.activeAlerts.length + pendingCountermeasures;
                final diaryLogged =
                    member.sleep.sleepHours > 0 &&
                    member.sleep.date.year > 2000;

                return Card(
                  key: ValueKey('crew_sidebar_item_${member.id}'),
                  margin: const EdgeInsets.only(bottom: 8),
                  color: isSelected
                      ? SpaceTheme.cyan.withValues(alpha: 0.12)
                      : SpaceTheme.card,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: isSelected ? SpaceTheme.cyan : Colors.white12,
                      width: isSelected ? 1.6 : 1.0,
                    ),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => onSelect(member.id),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  member.name,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: statusColor.withValues(alpha: 0.16),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                    color: statusColor.withValues(alpha: 0.5),
                                  ),
                                ),
                                child: Text(
                                  member.riskLevel.name.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: statusColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            member.role,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.white60,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              Text(
                                'HR ${member.vitals.heartRate.toStringAsFixed(0)} bpm',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.white70,
                                ),
                              ),
                              Text(
                                'Sleep ${member.sleep.sleepHours.toStringAsFixed(1)}h',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.white70,
                                ),
                              ),
                              Text(
                                diaryLogged
                                    ? 'Diary: Logged'
                                    : 'Diary: Pending',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: diaryLogged
                                      ? SpaceTheme.green
                                      : SpaceTheme.warningYellow,
                                ),
                              ),
                              Text(
                                'Alerts/CM: $alertAndCmCount',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: alertAndCmCount > 0
                                      ? SpaceTheme.warningYellow
                                      : Colors.white60,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Color _riskColor(CrewRiskLevel level) {
    return switch (level) {
      CrewRiskLevel.nominal => SpaceTheme.green,
      CrewRiskLevel.warning => SpaceTheme.warningYellow,
      CrewRiskLevel.critical => SpaceTheme.dangerRed,
    };
  }
}
