import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:astramed/features/agent/application/agent_conversation_controller.dart';
import 'package:astramed/features/agent/application/hands_free_controller.dart';
import 'package:astramed/features/agent/domain/agent_contracts.dart';
import 'package:astramed/features/agent/domain/agent_models.dart';
import 'package:astramed/features/agent/providers/agent_providers.dart';
import 'package:astramed/features/crew/presentation/providers/crew_provider.dart';

import '../domain/apolo_models.dart';
import '../providers/apolo_contract_providers.dart';
import 'apolo_crew_menu_dialog.dart';
import 'apolo_detail_sheet.dart';
import 'apolo_dog_widget.dart';
import 'apolo_orb_widget.dart';
import 'apolo_sky_background.dart';
import 'apolo_theme.dart';

/// Primary APOLO home screen: astronaut dog assistant, floating health orbs,
/// speech bubble wired to `AgentConversationController`, voice/text input, and
/// dynamic clinical component tray.
class ApoloHomeScreen extends ConsumerStatefulWidget {
  const ApoloHomeScreen({
    super.key,
    this.onOpenClinicalDashboard,
    this.onOpenClinicalModule,
  });

  /// Optional callback to open the legacy 5-tab clinical modules dashboard.
  final VoidCallback? onOpenClinicalDashboard;

  /// Optional callback to open the clinical modules dashboard at a specific tab.
  final void Function(int initialIndex)? onOpenClinicalModule;

  @override
  ConsumerState<ApoloHomeScreen> createState() => _ApoloHomeScreenState();
}

class _ApoloHomeScreenState extends ConsumerState<ApoloHomeScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _inputController = TextEditingController();
  final FocusNode _inputFocusNode = FocusNode();
  final Set<AgentViewModel> _dismissedComponents =
      Set<AgentViewModel>.identity();

  late final AnimationController _samplePulseController;
  StreamSubscription<bool>? _speakingSub;
  Timer? _autoTipTimer;

  Offset _lookOffset = Offset.zero;
  bool _manualListening = false;
  bool _ttsSpeaking = false;
  bool _componentsExpanded = true;
  String? _voiceError;
  String? _localBubbleText;
  int _tipCursor = 0;

  AgentConversationController? _controllerRef;

  @override
  void initState() {
    super.initState();
    _samplePulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        final tts = ref.read(trackedTextToSpeechProvider);
        _ttsSpeaking = tts.isSpeaking;
        _speakingSub = tts.isSpeakingStream.listen((speaking) {
          if (mounted && _ttsSpeaking != speaking) {
            setState(() => _ttsSpeaking = speaking);
          }
        });
      } catch (_) {
        // Safe when TTS provider is unavailable in isolated tests.
      }
      try {
        ref.read(handsFreeControllerProvider.notifier).initialize();
      } catch (_) {
        // Safe when hands-free is not supported in test environment.
      }
      _resetAutoTipTimer();
    });
  }

  @override
  void dispose() {
    _autoTipTimer?.cancel();
    _speakingSub?.cancel();
    _samplePulseController.dispose();
    _inputController.dispose();
    _inputFocusNode.dispose();
    final controller = _controllerRef;
    if (controller != null) {
      unawaited(controller.closeSession());
    }
    super.dispose();
  }

  void _resetAutoTipTimer() {
    _autoTipTimer?.cancel();
    final apoloState = ref.read(apoloActiveStateProvider);
    if (!apoloState.autoTips || apoloState.samples.isEmpty) return;
    _autoTipTimer = Timer(const Duration(seconds: 28), () {
      if (!mounted) return;
      final current = ref.read(apoloActiveStateProvider);
      final session = ref.read(agentOrchestratorProvider);
      final busy =
          current.openModuleId != null ||
          _manualListening ||
          session.busy ||
          _inputController.text.isNotEmpty;
      if (!busy && current.autoTips) {
        _showLocalTip(current);
      }
      _resetAutoTipTimer();
    });
  }

  void _syncSamplePulse(bool isDue, bool disableAnimations) {
    if (isDue && !disableAnimations) {
      if (!_samplePulseController.isAnimating) {
        _samplePulseController.repeat();
      }
    } else {
      if (_samplePulseController.isAnimating) {
        _samplePulseController.stop();
        _samplePulseController.value = 0.0;
      }
    }
  }

  Future<void> _sendText([String? overrideText]) async {
    final raw = overrideText ?? _inputController.text;
    final text = raw.trim();
    if (text.isEmpty) return;

    if (overrideText == null) {
      _inputController.clear();
    }
    setState(() {
      _voiceError = null;
      _localBubbleText = null;
    });
    _resetAutoTipTimer();

    final speakReply = ref.read(agentVoiceRepliesEnabledProvider);
    await ref
        .read(agentOrchestratorProvider.notifier)
        .sendUserMessage(text, speakReply: speakReply);
  }

  Future<void> _toggleManualListening() async {
    final stt = ref.read(speechToTextServiceProvider);
    final tts = ref.read(trackedTextToSpeechProvider);
    final handsFree = ref.read(handsFreeControllerProvider.notifier);
    setState(() => _voiceError = null);

    try {
      if (!_manualListening) {
        await handsFree.pauseForManualInput();
        await tts.stop();
        await stt.startListening(language: 'en');
        if (mounted) {
          setState(() {
            _manualListening = true;
            _localBubbleText = 'Listening…';
          });
        }
        return;
      }

      if (mounted) {
        setState(() => _manualListening = false);
      }
      try {
        final transcript = await stt.stopListening();
        await handsFree.resumeAfterManualInput();
        if (transcript.trim().isEmpty) {
          if (mounted) {
            setState(() {
              _voiceError = 'No speech detected.';
              _localBubbleText = null;
            });
          }
          return;
        }
        await _sendText(transcript);
      } catch (e) {
        await handsFree.resumeAfterManualInput();
        rethrow;
      }
    } catch (e) {
      if (!_manualListening) {
        await handsFree.resumeAfterManualInput();
      }
      if (mounted) {
        setState(() {
          _manualListening = false;
          _voiceError = 'Voice input failed: $e';
        });
      }
    }
  }

  void _showLocalTip(ApoloAstronautState state) {
    final tips = _buildContextualTips(state);
    final tip = tips[_tipCursor % tips.length];
    _tipCursor++;
    setState(() {
      _localBubbleText = tip;
    });
  }

  List<String> _buildContextualTips(ApoloAstronautState state) {
    final list = <String>[];
    for (final mod in state.rankedModules) {
      for (final rec in mod.recommendations) {
        if (!rec.done) {
          list.add('Tip: ${rec.text}. ${rec.why}');
        }
      }
    }
    if (state.sampleSchedule.isDue && state.samples.isNotEmpty) {
      list.add(
        'Tip: Your urine sample is due now. Collecting it keeps your baselines accurate.',
      );
    }
    if (state.waterMlToday < state.waterGoalMl) {
      final remainingL = ((state.waterGoalMl - state.waterMlToday) / 1000)
          .toStringAsFixed(1);
      list.add(
        'Tip: You still need $remainingL L of water today. Thirst is blunted in microgravity.',
      );
    }
    if (state.exerciseMinToday < state.exerciseGoalMin) {
      final left = state.exerciseGoalMin - state.exerciseMinToday;
      list.add(
        'Tip: $left min of resistance exercise left today to protect your bone density.',
      );
    }
    list.addAll([
      'Woof! I am here for you, ${state.firstName}. Tap any circle to inspect your biomarkers.',
      'You can say or type "I drank 500 ml" and I will log your water intake.',
      'Stretch your neck and back for one minute every hour in microgravity.',
      'Look toward the Earth viewport for 20 seconds every 20 minutes to rest your eyes.',
    ]);
    return list;
  }

  String _initialGreeting(ApoloAstronautState state) {
    if (state.samples.isEmpty) {
      return 'Hey, listen, ${state.firstName}! Zero urine data on file yet. Submit your first sample so I can calibrate your baseline—promise not to judge.';
    }
    final ranked = state.rankedModules;
    final nonOk = ranked
        .where((m) => m.severity != ApoloSeverity.ok)
        .toList(growable: false);
    final base = StringBuffer();
    if (nonOk.isNotEmpty && nonOk.first.severity == ApoloSeverity.crit) {
      base.write(
        '${state.firstName}, listen—urgent attention needed: ${nonOk.first.title.toLowerCase()} is critical. Tap the red circle now to see what to do.',
      );
    } else if (nonOk.isNotEmpty) {
      final names = nonOk.map((m) => m.title.toLowerCase()).join(' and ');
      base.write(
        'Hey, ${state.firstName}. Mostly smooth orbit, though ${nonOk.length == 1 ? 'one circle needs' : '${nonOk.length} circles need'} a nudge: $names.',
      );
    } else {
      base.write(
        'Hey, ${state.firstName}! All systems are green and surprisingly well-behaved today. Ask me anything or tap Show all.',
      );
    }
    if (state.sampleSchedule.isDue) {
      if (nonOk.isNotEmpty && nonOk.first.severity == ApoloSeverity.crit) {
        base.write(' Your urine sample is also due.');
      } else {
        base.write(' Also, your urine sample is due—consider this your friendly nudge.');
      }
    }
    return base.toString();
  }

  void _handleSamplePillTap(
    ApoloAstronautState state,
    ApoloStateActions actions,
  ) {
    _resetAutoTipTimer();
    if (state.sampleSchedule.isDue) {
      actions.submitSample();
      setState(() {
        _localBubbleText =
            'Sample received! Updating your urine biomarkers and schedule.';
      });
    } else {
      setState(() {
        _localBubbleText =
            '${state.sampleSchedule.title}. ${state.sampleSchedule.subtitle}.';
      });
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

    ref.listen<ClinicalNavigationRequest?>(clinicalNavigationRequestProvider, (
      previous,
      next,
    ) {
      if (next == null || next.nonce == previous?.nonce) return;
      if (next.openManualVitals) {
        ref.read(pendingManualVitalsDialogProvider.notifier).state = true;
      }
      if (next.procedureId != null && next.procedureId!.isNotEmpty) {
        ref.read(pendingProcedureSelectionProvider.notifier).state =
            next.procedureId;
      }
      if (widget.onOpenClinicalModule != null) {
        widget.onOpenClinicalModule!(next.tabIndex);
      } else {
        widget.onOpenClinicalDashboard?.call();
      }
      Future.microtask(() {
        if (mounted) {
          ref.read(clinicalNavigationRequestProvider.notifier).state = null;
        }
      });
    });

    ref.listen<AgentSessionState>(agentOrchestratorProvider, (prev, next) {
      final prevLen = prev?.messages.length ?? 0;
      if (next.messages.length > prevLen) {
        if (mounted && _localBubbleText != null) {
          setState(() => _localBubbleText = null);
        }
      }
    });

    _controllerRef = ref.read(agentOrchestratorProvider.notifier);
    final apoloState = ref.watch(apoloActiveStateProvider);
    final actions = ref.watch(apoloActionsProvider);
    final session = ref.watch(agentOrchestratorProvider);
    final handsFreeState = ref.watch(handsFreeControllerProvider);
    final widgetRegistry = ref.watch(componentWidgetRegistryProvider);

    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    _syncSamplePulse(apoloState.sampleSchedule.isDue, disableAnimations);

    _dismissedComponents.removeWhere(
      (d) => !session.activeComponents.any((vm) => identical(vm, d)),
    );
    final visibleComponents = session.activeComponents
        .where((vm) => !_dismissedComponents.any((d) => identical(d, vm)))
        .toList(growable: false);

    final palette = ApoloPalette.of(apoloState.highContrast);

    final lastUserMessage = session.messages
        .where((m) => m.role == ChatRole.user && m.content.trim().isNotEmpty)
        .lastOrNull
        ?.content;

    final lastAssistantMessage = session.messages
        .where(
          (m) => m.role == ChatRole.assistant && m.content.trim().isNotEmpty,
        )
        .lastOrNull
        ?.content;

    final bubbleText =
        _localBubbleText ?? lastAssistantMessage ?? _initialGreeting(apoloState);

    final isDogListening =
        _manualListening ||
        handsFreeState.status == HandsFreeStatus.listening ||
        handsFreeState.status == HandsFreeStatus.hearingSpeech;

    final openModule = apoloState.openModuleId != null
        ? apoloState.modules[apoloState.openModuleId!]
        : null;

    return Theme(
      data: buildApoloTheme(highContrast: apoloState.highContrast),
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.escape): () {
            if (openModule != null) {
              actions.openDetail(null);
            }
          },
        },
        child: Scaffold(
          backgroundColor: palette.bg,
          body: ApoloSkyBackground(
            highContrast: apoloState.highContrast,
            child: Listener(
              onPointerHover: (e) => _updateLook(context, e.position),
              onPointerMove: (e) => _updateLook(context, e.position),
              onPointerDown: (_) => _resetAutoTipTimer(),
              child: Stack(
                children: [
                  SafeArea(
                    child: Column(
                      children: [
                        _buildTopBar(context, apoloState, actions, palette),
                        Expanded(
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final width = constraints.maxWidth;
                              final isWide = width >= 900;
                              final maxOrbs = width < 640 ? 6 : 8;
                              final visibleSnaps = apoloState.visibleOrbs
                                  .take(maxOrbs)
                                  .map((id) => apoloState.modules[id])
                                  .whereType<ApoloModuleSnapshot>()
                                  .toList(growable: false);

                              final petSection = _buildPetColumn(
                                context: context,
                                apoloState: apoloState,
                                actions: actions,
                                session: session,
                                palette: palette,
                                bubbleText: bubbleText,
                                lastUserMessage: lastUserMessage,
                                isDogListening: isDogListening,
                                visibleComponents: visibleComponents,
                                widgetRegistry: widgetRegistry,
                                maxOrbs: maxOrbs,
                                dogSize: _computeDogSize(
                                  width: width,
                                  height: constraints.maxHeight,
                                  isWide: isWide,
                                ),
                              );

                              if (isWide) {
                                final leftOrbs = <ApoloModuleSnapshot>[];
                                final rightOrbs = <ApoloModuleSnapshot>[];
                                for (var i = 0; i < visibleSnaps.length; i++) {
                                  if (i.isEven) {
                                    leftOrbs.add(visibleSnaps[i]);
                                  } else {
                                    rightOrbs.add(visibleSnaps[i]);
                                  }
                                }
                                final useTwoColumnsPerSide =
                                    width >= 1000 && visibleSnaps.length > 4;
                                final orbScale = useTwoColumnsPerSide
                                    ? 0.80
                                    : (constraints.maxHeight < 680
                                          ? 0.80
                                          : 0.94);

                                return Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    20,
                                    4,
                                    20,
                                    8,
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Expanded(
                                        child: _OrbSideColumn(
                                          orbs: leftOrbs,
                                          twoColumns: useTwoColumnsPerSide,
                                          mirrorZigzag: false,
                                          orbScale: orbScale,
                                          highContrast: apoloState.highContrast,
                                          onTapOrb: actions.openDetail,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      ConstrainedBox(
                                        constraints: BoxConstraints(
                                          maxWidth: math.min(width * 0.44, 540),
                                          minWidth: 300,
                                        ),
                                        child: SingleChildScrollView(
                                          child: petSection,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: _OrbSideColumn(
                                          orbs: rightOrbs,
                                          twoColumns: useTwoColumnsPerSide,
                                          mirrorZigzag: true,
                                          orbScale: orbScale,
                                          highContrast: apoloState.highContrast,
                                          onTapOrb: actions.openDetail,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }

                              // Narrow / mobile stacked layout
                              return SingleChildScrollView(
                                padding: const EdgeInsets.fromLTRB(
                                  14,
                                  4,
                                  14,
                                  12,
                                ),
                                child: Column(
                                  children: [
                                    petSection,
                                    if (visibleSnaps.isNotEmpty) ...[
                                      const SizedBox(height: 12),
                                      Wrap(
                                        alignment: WrapAlignment.center,
                                        spacing: 10,
                                        runSpacing: 10,
                                        children: [
                                          for (final snap in visibleSnaps)
                                            ApoloOrbWidget(
                                              snapshot: snap,
                                              compactScale: width < 400
                                                  ? 0.72
                                                  : 0.78,
                                              highContrast:
                                                  apoloState.highContrast,
                                              onTap: () =>
                                                  actions.openDetail(snap.id),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                        if (_voiceError != null ||
                            session.lastError != null ||
                            handsFreeState.errorMessage != null)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 2,
                            ),
                            child: Text(
                              _voiceError ??
                                  session.lastError ??
                                  handsFreeState.errorMessage!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: palette.crit,
                              ),
                            ),
                          ),
                        _buildAskBar(
                          context: context,
                          palette: palette,
                          session: session,
                          handsFreeState: handsFreeState,
                          highContrast: apoloState.highContrast,
                        ),
                      ],
                    ),
                  ),
                  if (openModule != null)
                    ApoloDetailSheet(
                      astronautState: apoloState,
                      snapshot: openModule,
                      onClose: () => actions.openDetail(null),
                      onAddWater: (ml) => actions.addWater(ml),
                      onAddExercise: (min) => actions.addExercise(min),
                      onToggleRecommendation: (recId, done) =>
                          actions.toggleRecommendation(recId, done),
                      onAskApolo: () {
                        actions.openDetail(null);
                        actions.showOrbs([openModule.id]);
                        unawaited(
                          _sendText(
                            'Tell me about my ${openModule.title.toLowerCase()} status and what I should do.',
                          ),
                        );
                      },
                      onHideOrb: () {
                        actions.openDetail(null);
                        actions.hideOrb(openModule.id);
                      },
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _updateLook(BuildContext context, Offset globalPosition) {
    if (MediaQuery.disableAnimationsOf(context)) return;
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final center = box.localToGlobal(box.size.center(Offset.zero));
    final dx = globalPosition.dx - center.dx;
    final dy = globalPosition.dy - center.dy;
    final dist = math.sqrt(dx * dx + dy * dy);
    if (dist < 1) return;
    final scale = math.min(1.0, dist / 300.0) * 3.0;
    final next = Offset(dx / dist * scale, dy / dist * scale);
    if ((next - _lookOffset).distance > 0.15) {
      setState(() => _lookOffset = next);
    }
  }

  double _computeDogSize({
    required double width,
    required double height,
    required bool isWide,
  }) {
    if (isWide) {
      return (height * 0.36).clamp(170.0, 290.0);
    }
    return math.min(width * 0.48, 220.0).clamp(140.0, 220.0);
  }

  Widget _buildTopBar(
    BuildContext context,
    ApoloAstronautState state,
    ApoloStateActions actions,
    ApoloPalette palette,
  ) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final showMissionText = screenWidth >= 560;
    final showPillLabel = screenWidth >= 640;
    final showCrewName = screenWidth >= 520;
    final isCompactBar = screenWidth < 480;
    final hc = state.highContrast;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        isCompactBar ? 12 : 16,
        10,
        isCompactBar ? 12 : 16,
        6,
      ),
      child: Row(
        children: [
          Container(
            width: isCompactBar ? 36 : 40,
            height: isCompactBar ? 36 : 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: palette.text,
              boxShadow: hc
                  ? null
                  : const [
                      BoxShadow(color: Color(0x22F0FFF1), spreadRadius: 4),
                      BoxShadow(color: Color(0x55F0FFF1), blurRadius: 18),
                    ],
            ),
            child: Icon(
              Icons.pets,
              size: isCompactBar ? 18 : 20,
              color: palette.bg,
            ),
          ),
          SizedBox(width: isCompactBar ? 8 : 10),
          Text(
            'APOLO',
            style: TextStyle(
              fontSize: isCompactBar ? 18 : 21,
              fontWeight: FontWeight.w700,
              letterSpacing: isCompactBar ? 1.8 : 2.8,
              color: palette.text,
            ),
          ),
          if (showMissionText) ...[
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Day ${state.missionDay} · ${state.missionName}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13.5, color: palette.text2),
              ),
            ),
          ] else
            const Spacer(),
          if (widget.onOpenClinicalDashboard != null ||
              widget.onOpenClinicalModule != null) ...[
            const SizedBox(width: 6),
            Tooltip(
              message: 'Clinical modules',
              child: showPillLabel
                  ? OutlinedButton.icon(
                      key: const ValueKey('apolo_modules_button'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: palette.text,
                        backgroundColor: hc
                            ? palette.bg
                            : const Color(0x991E2050),
                        side: BorderSide(color: palette.border),
                        minimumSize: const Size(44, 42),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(22),
                        ),
                      ),
                      onPressed:
                          widget.onOpenClinicalDashboard ??
                          () => widget.onOpenClinicalModule?.call(0),
                      icon: const Icon(Icons.grid_view_rounded, size: 18),
                      label: const Text(
                        'Modules',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    )
                  : IconButton.outlined(
                      key: const ValueKey('apolo_modules_button'),
                      style: IconButton.styleFrom(
                        foregroundColor: palette.text,
                        backgroundColor: hc
                            ? palette.bg
                            : const Color(0x991E2050),
                        side: BorderSide(color: palette.border),
                        fixedSize: const Size(42, 42),
                      ),
                      onPressed:
                          widget.onOpenClinicalDashboard ??
                          () => widget.onOpenClinicalModule?.call(0),
                      icon: const Icon(Icons.grid_view_rounded, size: 18),
                    ),
            ),
          ],
          const SizedBox(width: 6),
          AnimatedBuilder(
            animation: _samplePulseController,
            builder: (context, child) {
              final pulse = state.sampleSchedule.isDue && !hc
                  ? math.sin(_samplePulseController.value * math.pi * 2) * 0.5 +
                        0.5
                  : 0.0;
              return Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: state.sampleSchedule.isDue && !hc
                      ? [
                          BoxShadow(
                            color: palette.warn.withValues(
                              alpha: 0.45 * (1.0 - pulse),
                            ),
                            spreadRadius: pulse * 7,
                          ),
                        ]
                      : null,
                ),
                child: child,
              );
            },
            child: Semantics(
              button: true,
              label:
                  '${state.sampleSchedule.title}. ${state.sampleSchedule.subtitle}',
              child: InkWell(
                key: const ValueKey('apolo_sample_pill'),
                borderRadius: BorderRadius.circular(22),
                onTap: () => _handleSamplePillTap(state, actions),
                child: Container(
                  height: 44,
                  padding: EdgeInsets.symmetric(
                    horizontal: showPillLabel ? 14 : 12,
                  ),
                  decoration: BoxDecoration(
                    color: state.sampleSchedule.isDue
                        ? palette.warn
                        : (hc ? palette.bg : const Color(0x991E2050)),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: state.sampleSchedule.isDue
                          ? palette.warn
                          : palette.border,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        state.sampleSchedule.isDue
                            ? Icons.science_outlined
                            : Icons.schedule,
                        size: 18,
                        color: state.sampleSchedule.isDue
                            ? const Color(0xFF1B1600)
                            : palette.text,
                      ),
                      if (showPillLabel) ...[
                        const SizedBox(width: 6),
                        Text(
                          state.sampleSchedule.isDue
                              ? 'Sample due'
                              : 'Sample in',
                          style: TextStyle(
                            fontSize: 13.5,
                            color: state.sampleSchedule.isDue
                                ? const Color(0xFF1B1600)
                                : palette.text2,
                          ),
                        ),
                      ],
                      const SizedBox(width: 6),
                      Text(
                        state.sampleSchedule.isDue
                            ? 'Now'
                            : state.sampleSchedule.shortLabel,
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: state.sampleSchedule.isDue
                              ? const Color(0xFF1B1600)
                              : palette.text,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Semantics(
            button: true,
            label: 'Crew member: ${state.name}. Switch astronaut',
            child: InkWell(
              key: const ValueKey('apolo_crew_button'),
              borderRadius: BorderRadius.circular(24),
              onTap: () => ApoloCrewMenuDialog.show(context),
              child: Container(
                height: 46,
                padding: const EdgeInsets.fromLTRB(6, 0, 10, 0),
                decoration: BoxDecoration(
                  color: hc ? palette.bg : const Color(0x991E2050),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: palette.border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: Color(state.colorHex),
                      child: Text(
                        state.initials,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF14122C),
                        ),
                      ),
                    ),
                    if (showCrewName) ...[
                      const SizedBox(width: 8),
                      Text(
                        state.firstName,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: palette.text,
                          fontSize: 14.5,
                        ),
                      ),
                    ],
                    const SizedBox(width: 4),
                    Icon(
                      Icons.keyboard_arrow_down,
                      size: 18,
                      color: palette.text2,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPetColumn({
    required BuildContext context,
    required ApoloAstronautState apoloState,
    required ApoloStateActions actions,
    required AgentSessionState session,
    required ApoloPalette palette,
    required String bubbleText,
    required String? lastUserMessage,
    required bool isDogListening,
    required List<AgentViewModel> visibleComponents,
    required dynamic widgetRegistry,
    required int maxOrbs,
    required double dogSize,
  }) {
    final allShown = apoloState.visibleOrbs.length >= maxOrbs;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (lastUserMessage != null)
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              key: const ValueKey('apolo_last_heard'),
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: palette.elev,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                  bottomLeft: Radius.circular(4),
                ),
                border: apoloState.highContrast
                    ? Border.all(color: palette.border)
                    : null,
              ),
              child: Text(
                lastUserMessage,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13.5, color: palette.text),
              ),
            ),
          ),
        Container(
          key: const ValueKey('apolo_speech_bubble'),
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
          decoration: BoxDecoration(
            color: palette.text,
            borderRadius: BorderRadius.circular(30),
            border: apoloState.highContrast
                ? Border.all(color: Colors.white, width: 3)
                : null,
            boxShadow: apoloState.highContrast
                ? null
                : const [
                    BoxShadow(
                      color: Color(0x88000000),
                      blurRadius: 36,
                      offset: Offset(0, 14),
                    ),
                    BoxShadow(color: Color(0x15F0FFF1), spreadRadius: 5),
                  ],
          ),
          child: Column(
            children: [
              if (session.busy)
                const _ThinkingBubbleIndicator(
                  key: Key('apolo_thinking_indicator'),
                )
              else
                Text(
                  bubbleText,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF16142E),
                    fontSize: 16.5,
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                  ),
                ),
              const SizedBox(height: 12),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (apoloState.sampleSchedule.isDue)
                    _QuickChip(
                      key: const ValueKey('apolo_chip_submit_sample'),
                      icon: Icons.science_outlined,
                      label: 'Submit sample',
                      onTap: () => _handleSamplePillTap(apoloState, actions),
                    ),
                  _QuickChip(
                    key: const ValueKey('apolo_chip_how_am_i'),
                    label: 'How am I?',
                    onTap: () => unawaited(_sendText('How am I doing?')),
                  ),
                  _QuickChip(
                    key: const ValueKey('apolo_chip_give_tip'),
                    icon: Icons.auto_awesome_outlined,
                    label: 'Give me a tip',
                    onTap: () => _showLocalTip(apoloState),
                  ),
                  if (!allShown)
                    _QuickChip(
                      key: const ValueKey('apolo_chip_show_all'),
                      label: 'Show all',
                      onTap: () {
                        actions.showAllOrbs(maxOrbs: maxOrbs);
                        setState(() {
                          _localBubbleText = 'Here are your health circles. Tap any one for details.';
                        });
                      },
                    )
                  else
                    _QuickChip(
                      key: const ValueKey('apolo_chip_urgent_only'),
                      label: 'Urgent only',
                      onTap: () {
                        actions.resetOrbsToUrgent();
                        setState(() {
                          _localBubbleText = 'Showing urgent circles only.';
                        });
                      },
                    ),
                ],
              ),
            ],
          ),
        ),
        // Trailing thought-bubble dots toward Apolo
        const SizedBox(height: 6),
        Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: palette.text,
          ),
        ),
        const SizedBox(height: 4),
        Transform.translate(
          offset: const Offset(10, 0),
          child: Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: palette.text,
            ),
          ),
        ),
        const SizedBox(height: 6),
        ApoloDogWidget(
          key: const ValueKey('apolo_dog_widget'),
          severity: apoloState.overallSeverity,
          isListening: isDogListening,
          isSpeaking: _ttsSpeaking,
          isThinking: session.busy,
          highContrast: apoloState.highContrast,
          lookOffset: _lookOffset,
          size: dogSize,
          onTap: () => _showLocalTip(apoloState),
        ),
        if (session.pendingAction != null &&
            !visibleComponents.any(
              (vm) => vm.componentId == ComponentIds.confirmAction,
            ))
          _buildPendingActionCard(session.pendingAction!, palette),
        if (visibleComponents.isNotEmpty)
          _buildDynamicComponentsTray(
            context: context,
            visibleComponents: visibleComponents,
            widgetRegistry: widgetRegistry,
            session: session,
            palette: palette,
          ),
      ],
    );
  }

  Widget _buildPendingActionCard(
    ConsequentialAction action,
    ApoloPalette palette,
  ) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: palette.warn),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Crew Confirmation Required · ${action.actionType}',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: palette.warn,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            action.description,
            style: TextStyle(fontSize: 13, color: palette.text),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: palette.ok,
                  foregroundColor: const Color(0xFF0B2014),
                ),
                onPressed: () => ref
                    .read(agentOrchestratorProvider.notifier)
                    .resolveConfirmation(ConfirmationDecision.confirmed),
                child: const Text('Confirm'),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: palette.crit,
                  side: BorderSide(color: palette.crit),
                ),
                onPressed: () => ref
                    .read(agentOrchestratorProvider.notifier)
                    .resolveConfirmation(ConfirmationDecision.rejected),
                child: const Text('Reject'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDynamicComponentsTray({
    required BuildContext context,
    required List<AgentViewModel> visibleComponents,
    required dynamic widgetRegistry,
    required AgentSessionState session,
    required ApoloPalette palette,
  }) {
    return Container(
      key: const ValueKey('apolo_components_tray'),
      margin: const EdgeInsets.only(top: 10),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () =>
                setState(() => _componentsExpanded = !_componentsExpanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  Icon(
                    Icons.medical_services_outlined,
                    size: 16,
                    color: palette.lav2,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Clinical Tests & Tools (${visibleComponents.length})',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: palette.text,
                      ),
                    ),
                  ),
                  Icon(
                    _componentsExpanded ? Icons.expand_less : Icons.expand_more,
                    size: 18,
                    color: palette.text2,
                  ),
                ],
              ),
            ),
          ),
          if (_componentsExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final vm in visibleComponents)
                    widgetRegistry.build(
                      context,
                      vm,
                      onSubmit: (Map<String, dynamic> result) =>
                          _handleComponentSubmit(vm, result, session),
                      onDismiss: () {
                        setState(() => _dismissedComponents.add(vm));
                      },
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAskBar({
    required BuildContext context,
    required ApoloPalette palette,
    required AgentSessionState session,
    required HandsFreeState handsFreeState,
    required bool highContrast,
  }) {
    final hfActive = handsFreeState.enabled;
    final hfLabel = _manualListening
        ? 'Listening'
        : switch (handsFreeState.status) {
            HandsFreeStatus.off => 'Hands-Free Off',
            HandsFreeStatus.listening => 'Listening',
            HandsFreeStatus.hearingSpeech => 'Hearing',
            HandsFreeStatus.transcribing => 'Transcribing',
            HandsFreeStatus.pausedWhileSpeaking => 'Paused',
            HandsFreeStatus.permissionDenied => 'No Mic',
            HandsFreeStatus.error => 'Mic Error',
          };

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Container(
            padding: const EdgeInsets.fromLTRB(18, 6, 6, 6),
            decoration: BoxDecoration(
              color: highContrast ? palette.bg : const Color(0xE61E2050),
              borderRadius: BorderRadius.circular(34),
              border: Border.all(color: palette.border),
              boxShadow: highContrast
                  ? null
                  : const [
                      BoxShadow(
                        color: Color(0x88000000),
                        blurRadius: 30,
                        offset: Offset(0, 10),
                      ),
                    ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    key: const ValueKey('apolo_ask_input'),
                    controller: _inputController,
                    focusNode: _inputFocusNode,
                    enabled: !_manualListening,
                    style: TextStyle(color: palette.text, fontSize: 15.5),
                    decoration: InputDecoration(
                      hintText: _manualListening ? 'Listening…' : 'Ask Apolo…',
                      hintStyle: TextStyle(color: palette.text2),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => unawaited(_sendText()),
                  ),
                ),
                const SizedBox(width: 6),
                Tooltip(
                  message: hfActive
                      ? 'Disable hands-free listening'
                      : 'Enable hands-free listening',
                  child: InkWell(
                    key: const ValueKey('apolo_hands_free_button'),
                    borderRadius: BorderRadius.circular(20),
                    onTap: () {
                      ref.read(handsFreeControllerProvider.notifier).toggle();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: hfActive
                            ? palette.ok.withValues(alpha: 0.16)
                            : palette.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: hfActive ? palette.ok : palette.border,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            hfActive ? Icons.hearing : Icons.hearing_disabled,
                            size: 15,
                            color: hfActive ? palette.ok : palette.text2,
                          ),
                          if (MediaQuery.sizeOf(context).width >= 520) ...[
                            const SizedBox(width: 5),
                            Text(
                              hfLabel,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: hfActive ? palette.ok : palette.text2,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  key: const ValueKey('apolo_send_button'),
                  tooltip: 'Send message',
                  onPressed: session.busy ? null : () => unawaited(_sendText()),
                  style: IconButton.styleFrom(
                    foregroundColor: palette.text2,
                    fixedSize: const Size(44, 44),
                  ),
                  icon: const Icon(Icons.send_rounded, size: 21),
                ),
                const SizedBox(width: 4),
                SizedBox(
                  width: 54,
                  height: 54,
                  child: IconButton(
                    key: const ValueKey('apolo_mic_button'),
                    tooltip: _manualListening
                        ? 'Stop listening'
                        : 'Talk to Apolo',
                    onPressed: session.busy
                        ? null
                        : () => unawaited(_toggleManualListening()),
                    style: IconButton.styleFrom(
                      backgroundColor: _manualListening
                          ? palette.crit
                          : palette.text,
                      foregroundColor: _manualListening
                          ? Colors.white
                          : const Color(0xFF16142E),
                      shape: const CircleBorder(),
                    ),
                    icon: Icon(
                      _manualListening ? Icons.stop_rounded : Icons.mic_rounded,
                      size: 25,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ThinkingBubbleIndicator extends StatefulWidget {
  const _ThinkingBubbleIndicator({super.key});

  @override
  State<_ThinkingBubbleIndicator> createState() =>
      _ThinkingBubbleIndicatorState();
}

class _ThinkingBubbleIndicatorState extends State<_ThinkingBubbleIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final disableAnimations = MediaQuery.disableAnimationsOf(context);
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = disableAnimations ? 0.0 : _controller.value;
        return Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < 3; i++) ...[
              Builder(
                builder: (context) {
                  final wave = disableAnimations
                      ? 0.7
                      : (math.sin((t - i * 0.22) * math.pi * 2) * 0.5 + 0.5);
                  final scale = 0.72 + wave * 0.42;
                  final opacity = 0.35 + wave * 0.65;
                  return Transform.scale(
                    scale: scale,
                    child: Opacity(
                      opacity: opacity,
                      child: Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.symmetric(horizontal: 2.5),
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFF6B4EC7),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
            const SizedBox(width: 8),
            const Text(
              'Apolo is thinking…',
              style: TextStyle(
                color: Color(0xFF16142E),
                fontSize: 16,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _QuickChip extends StatelessWidget {
  const _QuickChip({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
  });

  final String label;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF16142E),
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 15, color: const Color(0xFFF0FFF1)),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xFFF0FFF1),
                  fontWeight: FontWeight.w600,
                  fontSize: 13.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OrbSideColumn extends StatelessWidget {
  const _OrbSideColumn({
    required this.orbs,
    required this.twoColumns,
    required this.mirrorZigzag,
    required this.orbScale,
    required this.highContrast,
    required this.onTapOrb,
  });

  final List<ApoloModuleSnapshot> orbs;
  final bool twoColumns;
  final bool mirrorZigzag;
  final double orbScale;
  final bool highContrast;
  final void Function(ApoloModuleId id) onTapOrb;

  @override
  Widget build(BuildContext context) {
    if (orbs.isEmpty) {
      return const SizedBox.shrink();
    }

    if (twoColumns) {
      final colA = <ApoloModuleSnapshot>[];
      final colB = <ApoloModuleSnapshot>[];
      for (var i = 0; i < orbs.length; i++) {
        if (i.isEven) {
          colA.add(orbs[i]);
        } else {
          colB.add(orbs[i]);
        }
      }
      return Center(
        child: SingleChildScrollView(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.only(top: mirrorZigzag ? 44 : 0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final s in colA)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: ApoloOrbWidget(
                          snapshot: s,
                          compactScale: orbScale,
                          highContrast: highContrast,
                          onTap: () => onTapOrb(s.id),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: EdgeInsets.only(top: mirrorZigzag ? 0 : 44),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final s in colB)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: ApoloOrbWidget(
                          snapshot: s,
                          compactScale: orbScale,
                          highContrast: highContrast,
                          onTap: () => onTapOrb(s.id),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < orbs.length; i++)
              Padding(
                padding: EdgeInsets.only(
                  top: 6,
                  bottom: 6,
                  left: ((i.isOdd ? 1 : -1) * (mirrorZigzag ? -1 : 1) > 0)
                      ? 22
                      : 0,
                  right: ((i.isOdd ? 1 : -1) * (mirrorZigzag ? -1 : 1) < 0)
                      ? 22
                      : 0,
                ),
                child: ApoloOrbWidget(
                  snapshot: orbs[i],
                  compactScale: orbScale,
                  highContrast: highContrast,
                  onTap: () => onTapOrb(orbs[i].id),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
