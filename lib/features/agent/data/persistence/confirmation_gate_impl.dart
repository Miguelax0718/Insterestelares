import 'dart:async';

import '../../domain/agent_contracts.dart';

class _PendingConfirmation {
  _PendingConfirmation({
    required this.action,
    required this.onConfirmed,
    required this.createdAt,
    required this.completer,
  });

  final ConsequentialAction action;
  final Future<Map<String, dynamic>> Function() onConfirmed;
  final DateTime createdAt;
  final Completer<ConfirmationDecision> completer;
}

/// Enforces crew confirmation and audit logging before executing consequential
/// actions.
class ConfirmationGateImpl implements ConfirmationGate {
  ConfirmationGateImpl({
    required AuditLog auditLog,
    AgentUiSink? uiSink,
    Duration ttl = const Duration(minutes: 5),
    bool awaitResolution = true,
    DateTime Function()? clock,
  }) : this._internal(
         auditLog,
         uiSink,
         ttl,
         awaitResolution,
         clock ?? (() => DateTime.now().toUtc()),
       );

  ConfirmationGateImpl._internal(
    this._auditLog,
    this._uiSink,
    this._ttl,
    this._awaitResolution,
    this._clock,
  );

  final AuditLog _auditLog;
  final AgentUiSink? _uiSink;
  final Duration _ttl;
  final bool _awaitResolution;
  final DateTime Function() _clock;

  _PendingConfirmation? _pending;
  final Set<String> _resolvedIds = <String>{};

  @override
  ConsequentialAction? get pending => _pending?.action;

  @override
  Future<ConfirmationDecision> request(
    ConsequentialAction action, {
    required Future<Map<String, dynamic>> Function() onConfirmed,
  }) async {
    if (_pending != null) {
      throw StateError(
        'Consequential action "${_pending!.action.id}" is already pending.',
      );
    }
    if (_resolvedIds.contains(action.id)) {
      throw StateError(
        'Consequential action "${action.id}" has already been resolved.',
      );
    }

    final record = _PendingConfirmation(
      action: action,
      onConfirmed: onConfirmed,
      createdAt: _clock().toUtc(),
      completer: Completer<ConfirmationDecision>(),
    );
    _pending = record;
    _uiSink?.emit(ShowComponentEvent(ComponentIds.confirmAction, action.toJson()));

    if (_awaitResolution) {
      return record.completer.future;
    }
    return ConfirmationDecision.rejected;
  }

  @override
  Future<Map<String, dynamic>?> resolve(
    String actionId,
    ConfirmationDecision decision, {
    String? reason,
  }) async {
    if (_resolvedIds.contains(actionId)) {
      throw StateError(
        'Consequential action "$actionId" has already been resolved.',
      );
    }

    final current = _pending;
    if (current == null) {
      throw StateError(
        'No pending consequential action matches id "$actionId".',
      );
    }
    if (actionId != current.action.id) {
      throw StateError(
        'Action id mismatch: expected "${current.action.id}", got "$actionId".',
      );
    }

    final now = _clock().toUtc();
    final isExpired = _ttl <= Duration.zero || now.difference(current.createdAt) >= _ttl;
    final effectiveDecision =
        (decision == ConfirmationDecision.expired || isExpired)
            ? ConfirmationDecision.expired
            : decision;
    final effectiveReason =
        effectiveDecision == ConfirmationDecision.expired && reason == null
            ? 'Confirmation expired'
            : reason;

    Map<String, dynamic>? output;
    if (effectiveDecision == ConfirmationDecision.confirmed) {
      try {
        output = await current.onConfirmed();
      } catch (error, stackTrace) {
        _pending = null;
        if (_awaitResolution && !current.completer.isCompleted) {
          current.completer.completeError(error, stackTrace);
        }
        rethrow;
      }
    }

    final auditEntry = AuditEntry(
      id: current.action.id,
      astronautId: current.action.astronautId,
      actionType: current.action.actionType,
      description: current.action.description,
      payload: Map<String, dynamic>.from(current.action.payload),
      decision: effectiveDecision,
      timestamp: now,
      reason: effectiveReason,
    );

    try {
      await _auditLog.append(auditEntry);
    } catch (error, stackTrace) {
      _pending = null;
      if (_awaitResolution && !current.completer.isCompleted) {
        current.completer.completeError(error, stackTrace);
      }
      rethrow;
    }

    _resolvedIds.add(current.action.id);
    _pending = null;
    _uiSink?.emit(const HideComponentEvent(ComponentIds.confirmAction));
    if (!current.completer.isCompleted) {
      current.completer.complete(effectiveDecision);
    }
    return output;
  }
}
