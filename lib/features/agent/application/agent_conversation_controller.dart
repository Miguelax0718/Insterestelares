import 'dart:async';

import 'package:astramed/features/crew/models/astronaut_profile.dart';
import 'package:astramed/features/crew/presentation/providers/crew_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/persistence/session_summary_generator.dart';
import '../domain/agent_contracts.dart';
import '../domain/agent_exception.dart';
import '../domain/agent_models.dart';
import '../domain/agent_ports.dart';
import 'component_registry.dart';
import 'context_builder.dart';
import 'skill_registry.dart';

class AgentSessionState {
  const AgentSessionState({
    required this.astronautId,
    this.messages = const [],
    this.activeComponents = const [],
    this.pendingAction,
    this.activeOfflineFlowSkillId,
    this.busy = false,
    this.offlineMode = false,
    this.lastError,
  });

  final String astronautId;
  final List<ChatMessage> messages;
  final List<AgentViewModel> activeComponents;
  final ConsequentialAction? pendingAction;
  final String? activeOfflineFlowSkillId;
  final bool busy;
  final bool offlineMode;
  final String? lastError;

  AgentSessionState copyWith({
    String? astronautId,
    List<ChatMessage>? messages,
    List<AgentViewModel>? activeComponents,
    ConsequentialAction? pendingAction,
    bool clearPendingAction = false,
    String? activeOfflineFlowSkillId,
    bool clearActiveOfflineFlowSkillId = false,
    bool? busy,
    bool? offlineMode,
    String? lastError,
    bool clearLastError = false,
  }) {
    return AgentSessionState(
      astronautId: astronautId ?? this.astronautId,
      messages: messages ?? this.messages,
      activeComponents: activeComponents ?? this.activeComponents,
      pendingAction:
          clearPendingAction ? null : (pendingAction ?? this.pendingAction),
      activeOfflineFlowSkillId: clearActiveOfflineFlowSkillId
          ? null
          : (activeOfflineFlowSkillId ?? this.activeOfflineFlowSkillId),
      busy: busy ?? this.busy,
      offlineMode: offlineMode ?? this.offlineMode,
      lastError: clearLastError ? null : (lastError ?? this.lastError),
    );
  }
}

class _TurnUiSink implements AgentUiSink {
  _TurnUiSink({this.onSubmit});

  final void Function(String componentId, Map<String, dynamic> result)?
      onSubmit;
  final List<AgentComponentEvent> _buffer = [];

  @override
  void emit(AgentComponentEvent event) {
    _buffer.add(event);
  }

  @override
  void submit(String componentId, Map<String, dynamic> result) {
    onSubmit?.call(componentId, result);
  }

  List<AgentComponentEvent> drain() {
    if (_buffer.isEmpty) {
      return const [];
    }
    final copy = List<AgentComponentEvent>.from(_buffer);
    _buffer.clear();
    return copy;
  }
}

class AgentConversationOrchestrator {
  AgentConversationOrchestrator({
    required this.chat,
    this.tts,
    required this.skillRegistry,
    required this.componentRegistry,
    required this.contextFactory,
    this.contextBuilder = const AgentContextBuilder(),
    String initialAstronautId = 'AST-01',
    this.maxToolRounds = defaultMaxToolRounds,
    this.onStateChanged,
    this.onComponentSubmitted,
  }) : _state = AgentSessionState(astronautId: initialAstronautId) {
    _sessionsByAstronaut[initialAstronautId] = _state;
  }

  static const int defaultMaxToolRounds = 6;
  static const String _offlineUnavailableMessage =
      'Free chat is unavailable while offline. Guided clinical protocols remain available.';

  final AgentChatService chat;
  final TextToSpeechService? tts;
  final SkillRegistry skillRegistry;
  final ComponentRegistry componentRegistry;
  final ToolContext Function(String astronautId, AgentUiSink ui) contextFactory;
  final AgentContextBuilder contextBuilder;
  final int maxToolRounds;
  final void Function(AgentSessionState state)? onStateChanged;
  final void Function(String componentId, Map<String, dynamic> result)?
      onComponentSubmitted;

  final Map<String, AgentSessionState> _sessionsByAstronaut = {};
  final List<ChatMessage> _midTurnConfirmationMessages = [];
  AgentSessionState _state;

  AgentSessionState get state => _state;

  void _emitState(AgentSessionState next) {
    _state = next;
    _sessionsByAstronaut[next.astronautId] = next;
    onStateChanged?.call(next);
  }

  void syncPendingAction(ConsequentialAction? pending) {
    final components = pending != null
        ? _applyUiEvents(
            _state.activeComponents,
            [ShowComponentEvent(ComponentIds.confirmAction, pending.toJson())],
          )
        : _applyUiEvents(
            _state.activeComponents,
            const [HideComponentEvent(ComponentIds.confirmAction)],
          );
    _emitState(
      _state.copyWith(
        activeComponents: components,
        pendingAction: pending,
        clearPendingAction: pending == null,
      ),
    );
  }

  void submitComponentResult(String componentId, Map<String, dynamic> result) {
    onComponentSubmitted?.call(componentId, result);
  }

  Future<MemoryEntry?> closeSession({
    String? astronautId,
    DateTime? now,
  }) async {
    final targetId = astronautId ?? _state.astronautId;
    final session = targetId == _state.astronautId
        ? _state
        : _sessionsByAstronaut[targetId];
    if (session == null || session.messages.isEmpty) {
      return null;
    }
    final sink = _TurnUiSink(onSubmit: submitComponentResult);
    final ctx = contextFactory(targetId, sink);
    final audits = await ctx.audit.list(astronautId: targetId);
    final generator = SessionSummaryGenerator(ctx.memory);
    return generator.summarize(
      astronautId: targetId,
      transcript: session.messages,
      audits: audits,
      now: now ?? ctx.now,
    );
  }

  AgentSessionState switchAstronaut(String astronautId) {
    if (astronautId == _state.astronautId) {
      return _state;
    }
    final previousId = _state.astronautId;
    _sessionsByAstronaut[previousId] = _state;
    if (_state.messages.isNotEmpty) {
      unawaited(closeSession(astronautId: previousId));
    }
    final restored = _sessionsByAstronaut[astronautId] ??
        AgentSessionState(astronautId: astronautId);
    _emitState(restored);
    return _state;
  }

  Future<AgentSessionState> sendUserMessage(
    String text, {
    bool speakReply = false,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return _state;
    }

    final userMessage = ChatMessage(role: ChatRole.user, content: trimmed);
    final updatedMessages = [..._state.messages, userMessage];
    _emitState(
      _state.copyWith(
        messages: List<ChatMessage>.unmodifiable(updatedMessages),
        busy: true,
        clearLastError: true,
      ),
    );

    final sink = _TurnUiSink(onSubmit: submitComponentResult);
    final ctx = contextFactory(_state.astronautId, sink);

    try {
      return await _runOnlineTurn(
        query: trimmed,
        conversation: updatedMessages,
        ctx: ctx,
        sink: sink,
        speakReply: speakReply,
      );
    } on AgentUnavailableException {
      return await _runOfflineFallback(
        query: trimmed,
        conversation: updatedMessages,
        ctx: ctx,
        speakReply: speakReply,
      );
    } catch (e) {
      _emitState(
        _state.copyWith(
          busy: false,
          lastError: e.toString(),
        ),
      );
      return _state;
    }
  }

  Future<AgentSessionState> handleProactiveEvent(ProactiveEvent event) async {
    final targetId = event.astronautId;
    final targetState = targetId == _state.astronautId
        ? _state
        : (_sessionsByAstronaut[targetId] ??
            AgentSessionState(astronautId: targetId));

    var nextComponents = _applyUiEvents(
      targetState.activeComponents,
      event.uiEvents,
    );

    if (event.severity == ProactiveSeverity.critical) {
      final criticalMessage = ChatMessage(
        role: ChatRole.assistant,
        content: event.spokenMessage,
      );
      final updated = targetState.copyWith(
        messages: List<ChatMessage>.unmodifiable([
          ...targetState.messages,
          criticalMessage,
        ]),
        activeComponents: nextComponents,
        clearLastError: true,
      );
      _sessionsByAstronaut[targetId] = updated;
      if (targetId == _state.astronautId) {
        _emitState(updated);
      }
      await _safeSpeak(event.spokenMessage);
      return updated;
    }

    final summaryPrompt =
        '[Proactive ${event.severity.name}: ${event.kind}] ${event.spokenMessage}';
    final sink = _TurnUiSink(onSubmit: submitComponentResult);
    final ctx = contextFactory(targetId, sink);
    final workingMessages = [
      ...targetState.messages,
      ChatMessage(role: ChatRole.user, content: summaryPrompt),
    ];

    var workingState = targetState.copyWith(
      messages: List<ChatMessage>.unmodifiable(workingMessages),
      activeComponents: nextComponents,
      busy: true,
      clearLastError: true,
    );
    _sessionsByAstronaut[targetId] = workingState;
    if (targetId == _state.astronautId) {
      _emitState(workingState);
    }

    try {
      final resultState = await _runOnlineTurn(
        query: '${event.kind} ${event.spokenMessage}',
        forcedSkillId: event.skillId,
        conversation: workingMessages,
        ctx: ctx,
        sink: sink,
        speakReply: true,
        baseState: workingState,
      );
      return resultState;
    } on AgentUnavailableException {
      final fallbackMsg = ChatMessage(
        role: ChatRole.assistant,
        content: event.spokenMessage,
      );
      final offlineUpdated = workingState.copyWith(
        messages: List<ChatMessage>.unmodifiable([
          ...targetState.messages,
          fallbackMsg,
        ]),
        activeComponents: nextComponents,
        busy: false,
        offlineMode: true,
      );
      _sessionsByAstronaut[targetId] = offlineUpdated;
      if (targetId == _state.astronautId) {
        _emitState(offlineUpdated);
      }
      await _safeSpeak(event.spokenMessage);
      return offlineUpdated;
    } catch (e) {
      final errored = workingState.copyWith(
        busy: false,
        lastError: e.toString(),
      );
      _sessionsByAstronaut[targetId] = errored;
      if (targetId == _state.astronautId) {
        _emitState(errored);
      }
      return errored;
    }
  }

  Future<AgentSessionState> resolveConfirmation(
    ConfirmationDecision decision, {
    String? reason,
  }) async {
    final pending = _state.pendingAction;
    if (pending == null) {
      return _state;
    }

    final sink = _TurnUiSink(onSubmit: submitComponentResult);
    final ctx = contextFactory(_state.astronautId, sink);
    final outcome = await ctx.confirm.resolve(
      pending.id,
      decision,
      reason: reason,
    );

    final sinkEvents = sink.drain();
    var components = _applyUiEvents(_state.activeComponents, sinkEvents);
    components = _applyUiEvents(
      components,
      const [HideComponentEvent(ComponentIds.confirmAction)],
    );

    final outcomeText = switch (decision) {
      ConfirmationDecision.confirmed =>
        outcome != null && outcome.isNotEmpty
            ? 'Confirmed: ${pending.description}.'
            : 'Confirmed: ${pending.description}.',
      ConfirmationDecision.rejected =>
        'Rejected: ${pending.description}${reason != null && reason.trim().isNotEmpty ? ' (${reason.trim()})' : ''}.',
      ConfirmationDecision.expired => 'Expired: ${pending.description}.',
    };

    final outcomeMessage = ChatMessage(
      role: ChatRole.assistant,
      content: outcomeText,
    );
    if (_state.busy) {
      _midTurnConfirmationMessages.add(outcomeMessage);
    }

    final nextPending = ctx.confirm.pending;
    _emitState(
      _state.copyWith(
        messages: List<ChatMessage>.unmodifiable([
          ..._state.messages,
          outcomeMessage,
        ]),
        activeComponents: components,
        pendingAction: nextPending,
        clearPendingAction: nextPending == null,
      ),
    );
    return _state;
  }

  Future<AgentSessionState> _runOnlineTurn({
    required String query,
    String? forcedSkillId,
    required List<ChatMessage> conversation,
    required ToolContext ctx,
    required _TurnUiSink sink,
    required bool speakReply,
    AgentSessionState? baseState,
  }) async {
    final targetState = baseState ?? _state;
    final selectedSkills = skillRegistry.select(
      query: query,
      forcedSkillId: forcedSkillId,
    );
    final tools = skillRegistry.toolsFor(selectedSkills);
    final toolMap = <String, AgentTool>{
      for (final tool in tools) tool.name: tool,
    };
    final toolSpecs =
        tools.take(32).map((t) => t.toSpec()).toList(growable: false);
    final skillInstructions = selectedSkills
        .map((s) => s.instructions.trim())
        .where((s) => s.isNotEmpty)
        .take(8)
        .toList(growable: false);

    var workingMessages = List<ChatMessage>.from(conversation);
    var activeComponents = targetState.activeComponents;
    String? capturedError;

    var ctxMap = await _buildContextMap(ctx, activeComponents);

    for (var round = 0; round < maxToolRounds; round++) {
      final reply = await chat.send(
        workingMessages,
        context: ctxMap,
        tools: toolSpecs,
        skillInstructions: skillInstructions,
      );

      if (!reply.hasToolCalls) {
        if (_midTurnConfirmationMessages.isNotEmpty) {
          workingMessages.addAll(_midTurnConfirmationMessages);
          _midTurnConfirmationMessages.clear();
        }
        if (reply.reply.isNotEmpty) {
          workingMessages.add(
            ChatMessage(role: ChatRole.assistant, content: reply.reply),
          );
        }
        final nextPending = ctx.confirm.pending;
        if (nextPending == null) {
          activeComponents = _applyUiEvents(
            activeComponents,
            const [HideComponentEvent(ComponentIds.confirmAction)],
          );
        }
        final done = targetState.copyWith(
          messages: List<ChatMessage>.unmodifiable(workingMessages),
          activeComponents: activeComponents,
          pendingAction: nextPending,
          clearPendingAction: nextPending == null,
          clearActiveOfflineFlowSkillId: true,
          busy: false,
          offlineMode: false,
          lastError: capturedError,
          clearLastError: capturedError == null,
        );
        _commitTargetState(done);
        if (speakReply && reply.reply.isNotEmpty) {
          await _safeSpeak(reply.reply);
        }
        return done;
      }

      workingMessages.add(
        ChatMessage.assistantToolCalls(
          reply.toolCalls,
          content: reply.reply.isEmpty ? null : reply.reply,
        ),
      );

      for (final call in reply.toolCalls) {
        final ToolResult result;
        if (call.invalidArguments) {
          result = const ToolResult.fail('Invalid JSON arguments');
        } else {
          final tool = toolMap[call.name];
          if (tool == null) {
            result = ToolResult.fail('Unknown tool: ${call.name}');
          } else {
            ToolResult executed;
            try {
              executed = await tool.call(call.arguments, ctx);
            } catch (e) {
              executed = ToolResult.fail('Tool execution failed: $e');
            }
            result = executed;
          }
        }

        final sinkEvents = sink.drain();
        final combinedEvents = <AgentComponentEvent>[...sinkEvents];
        for (final event in result.uiEvents) {
          if (!combinedEvents.any((e) => identical(e, event))) {
            combinedEvents.add(event);
          }
        }
        if (ctx.confirm.pending == null) {
          combinedEvents.add(
            const HideComponentEvent(ComponentIds.confirmAction),
          );
        }
        activeComponents = _applyUiEvents(
          activeComponents,
          combinedEvents,
          onResolveError: (err) => capturedError = err,
        );

        workingMessages.add(
          ChatMessage.toolResult(
            toolCallId: call.id,
            content: result.toWireJson(),
          ),
        );
      }

      ctxMap = await _buildContextMap(ctx, activeComponents);
    }

    final finalReply = await chat.send(
      workingMessages,
      context: ctxMap,
      tools: const [],
      skillInstructions: skillInstructions,
    );
    if (_midTurnConfirmationMessages.isNotEmpty) {
      workingMessages.addAll(_midTurnConfirmationMessages);
      _midTurnConfirmationMessages.clear();
    }
    if (finalReply.reply.isNotEmpty) {
      workingMessages.add(
        ChatMessage(role: ChatRole.assistant, content: finalReply.reply),
      );
    }
    final nextPending = ctx.confirm.pending;
    if (nextPending == null) {
      activeComponents = _applyUiEvents(
        activeComponents,
        const [HideComponentEvent(ComponentIds.confirmAction)],
      );
    }
    final done = targetState.copyWith(
      messages: List<ChatMessage>.unmodifiable(workingMessages),
      activeComponents: activeComponents,
      pendingAction: nextPending,
      clearPendingAction: nextPending == null,
      clearActiveOfflineFlowSkillId: true,
      busy: false,
      offlineMode: false,
      lastError: capturedError,
      clearLastError: capturedError == null,
    );
    _commitTargetState(done);
    if (speakReply && finalReply.reply.isNotEmpty) {
      await _safeSpeak(finalReply.reply);
    }
    return done;
  }

  Future<AgentSessionState> _runOfflineFallback({
    required String query,
    required List<ChatMessage> conversation,
    required ToolContext ctx,
    required bool speakReply,
  }) async {
    final activeSkillId = _state.activeOfflineFlowSkillId;
    DeterministicFlow? activeFlow;
    var isContinuing = false;

    if (activeSkillId != null) {
      activeFlow = skillRegistry.byId(activeSkillId)?.offlineFlow;
      if (activeFlow != null) {
        isContinuing = true;
      }
    }

    activeFlow ??= skillRegistry.findOfflineFlow(query);

    if (activeFlow == null) {
      final updated = _state.copyWith(
        messages: List<ChatMessage>.unmodifiable([
          ...conversation,
          const ChatMessage(
            role: ChatRole.assistant,
            content: _offlineUnavailableMessage,
          ),
        ]),
        clearActiveOfflineFlowSkillId: true,
        busy: false,
        offlineMode: true,
      );
      _emitState(updated);
      if (speakReply) {
        await _safeSpeak(_offlineUnavailableMessage);
      }
      return updated;
    }

    final step = isContinuing
        ? await activeFlow.advance(query, ctx)
        : await activeFlow.start(ctx);

    final nextComponents = _applyUiEvents(
      _state.activeComponents,
      step.uiEvents,
    );

    final updated = _state.copyWith(
      messages: List<ChatMessage>.unmodifiable([
        ...conversation,
        ChatMessage(role: ChatRole.assistant, content: step.prompt),
      ]),
      activeComponents: nextComponents,
      activeOfflineFlowSkillId: step.isTerminal ? null : activeFlow.skillId,
      clearActiveOfflineFlowSkillId: step.isTerminal,
      busy: false,
      offlineMode: true,
      clearLastError: true,
    );
    _emitState(updated);
    await _safeSpeak(step.prompt);
    return updated;
  }

  void _commitTargetState(AgentSessionState next) {
    _sessionsByAstronaut[next.astronautId] = next;
    if (next.astronautId == _state.astronautId) {
      _emitState(next);
    }
  }

  List<AgentViewModel> _applyUiEvents(
    List<AgentViewModel> current,
    List<AgentComponentEvent> events, {
    void Function(String error)? onResolveError,
  }) {
    if (events.isEmpty) {
      return current;
    }
    final next = List<AgentViewModel>.from(current);
    for (final event in events) {
      switch (event) {
        case ShowComponentEvent(:final id, :final props):
          try {
            final vm = componentRegistry.resolve(id, props);
            final idx = next.indexWhere((c) => c.componentId == vm.componentId);
            if (idx >= 0) {
              next[idx] = vm;
            } else {
              next.add(vm);
            }
          } on FormatException catch (e) {
            onResolveError?.call(e.message);
          }
        case HideComponentEvent(:final id):
          next.removeWhere((c) => c.componentId == id);
      }
    }
    return List<AgentViewModel>.unmodifiable(next);
  }

  Future<Map<String, dynamic>> _buildContextMap(
    ToolContext ctx,
    List<AgentViewModel> activeComponents,
  ) async {
    final activeIds =
        activeComponents.map((c) => c.componentId).toList(growable: false);
    AstronautProfile? astronaut;
    try {
      final crew = ctx.read<List<AstronautProfile>>(crewMembersProvider);
      for (final member in crew) {
        if (member.id == ctx.astronautId) {
          astronaut = member;
          break;
        }
      }
    } catch (_) {
      astronaut = null;
    }

    if (astronaut != null) {
      return contextBuilder.build(
        astronaut: astronaut,
        memory: ctx.memory,
        flags: ctx.flags,
        activeComponentIds: activeIds,
      );
    }
    return contextBuilder.buildMinimal(
      astronautId: ctx.astronautId,
      memory: ctx.memory,
      flags: ctx.flags,
      activeComponentIds: activeIds,
    );
  }

  Future<void> _safeSpeak(String text) async {
    final ttsService = tts;
    if (ttsService == null || text.trim().isEmpty) {
      return;
    }
    try {
      await ttsService.speak(text);
    } catch (_) {
      // TTS failures must not break clinical state updates.
    }
  }
}

class AgentConversationController extends StateNotifier<AgentSessionState> {
  AgentConversationController({
    required AgentChatService chat,
    TextToSpeechService? tts,
    required SkillRegistry skillRegistry,
    required ComponentRegistry componentRegistry,
    required ToolContext Function(String astronautId, AgentUiSink ui)
        contextFactory,
    AgentContextBuilder contextBuilder = const AgentContextBuilder(),
    String initialAstronautId = 'AST-01',
    int maxToolRounds = AgentConversationOrchestrator.defaultMaxToolRounds,
  }) : super(AgentSessionState(astronautId: initialAstronautId)) {
    _orchestrator = AgentConversationOrchestrator(
      chat: chat,
      tts: tts,
      skillRegistry: skillRegistry,
      componentRegistry: componentRegistry,
      contextFactory: contextFactory,
      contextBuilder: contextBuilder,
      initialAstronautId: initialAstronautId,
      maxToolRounds: maxToolRounds,
      onStateChanged: (next) {
        if (mounted) {
          state = next;
        }
      },
    );
  }

  late final AgentConversationOrchestrator _orchestrator;

  AgentConversationOrchestrator get orchestrator => _orchestrator;

  Future<AgentSessionState> sendUserMessage(
    String text, {
    bool speakReply = false,
  }) =>
      _orchestrator.sendUserMessage(text, speakReply: speakReply);

  Future<AgentSessionState> handleProactiveEvent(ProactiveEvent event) =>
      _orchestrator.handleProactiveEvent(event);

  Future<AgentSessionState> resolveConfirmation(
    ConfirmationDecision decision, {
    String? reason,
  }) =>
      _orchestrator.resolveConfirmation(decision, reason: reason);

  AgentSessionState switchAstronaut(String astronautId) =>
      _orchestrator.switchAstronaut(astronautId);

  Future<MemoryEntry?> closeSession({String? astronautId, DateTime? now}) =>
      _orchestrator.closeSession(astronautId: astronautId, now: now);

  void submitComponentResult(String componentId, Map<String, dynamic> result) =>
      _orchestrator.submitComponentResult(componentId, result);
}
