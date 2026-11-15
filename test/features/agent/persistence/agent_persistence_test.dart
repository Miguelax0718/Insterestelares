import 'dart:io';

import 'package:astramed/features/agent/data/persistence/agent_hive_boxes.dart';
import 'package:astramed/features/agent/data/persistence/confirmation_gate_impl.dart';
import 'package:astramed/features/agent/data/persistence/hive_audit_log.dart';
import 'package:astramed/features/agent/data/persistence/hive_flags_store.dart';
import 'package:astramed/features/agent/data/persistence/hive_memory_store.dart';
import 'package:astramed/features/agent/data/persistence/session_summary_generator.dart';
import 'package:astramed/features/agent/domain/agent_contracts.dart';
import 'package:astramed/features/agent/domain/agent_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

class _FakeUiSink implements AgentUiSink {
  final List<AgentComponentEvent> events = [];
  final List<(String, Map<String, dynamic>)> submissions = [];

  @override
  void emit(AgentComponentEvent event) {
    events.add(event);
  }

  @override
  void submit(String componentId, Map<String, dynamic> result) {
    submissions.add((componentId, result));
  }
}

void main() {
  late Directory tempDir;
  late AgentHiveBoxes boxes;

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('astramed_hive_test_');
    boxes = await AgentHiveBoxes.open(directoryPath: tempDir.path);
    addTearDown(() async {
      await boxes.close();
      await Hive.close();
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });
  });

  group('AgentHiveBoxes & HiveMemoryStore', () {
    test('persists MemoryEntry across box close and reopen (S1)', () async {
      final store = HiveMemoryStore(boxes.memoryBox);
      final created = DateTime.utc(2026, 11, 14, 10, 30);
      final entry = MemoryEntry(
        id: 'mem-1',
        astronautId: 'AST-01',
        kind: MemoryKind.fact,
        summary: 'Allergic to penicillin and sulfa drugs',
        createdAt: created,
        tags: const ['allergy', 'medication'],
        data: const {
          'severity': 'high',
          'nested': {'source': 'medical_record'},
        },
      );

      await store.save(entry);
      await boxes.close();

      boxes = await AgentHiveBoxes.open(directoryPath: tempDir.path);
      final reopenedStore = HiveMemoryStore(boxes.memoryBox);
      final recalled = await reopenedStore.recall('AST-01');

      expect(recalled, hasLength(1));
      expect(recalled.first.id, 'mem-1');
      expect(recalled.first.astronautId, 'AST-01');
      expect(recalled.first.kind, MemoryKind.fact);
      expect(recalled.first.summary, 'Allergic to penicillin and sulfa drugs');
      expect(recalled.first.createdAt.toUtc(), created);
      expect(recalled.first.tags, ['allergy', 'medication']);
      expect(recalled.first.data['severity'], 'high');
      expect(
        (recalled.first.data['nested'] as Map<String, dynamic>)['source'],
        'medical_record',
      );
    });

    test('opens boxes from an already-initialized Hive instance', () async {
      await boxes.close();
      Hive.init(tempDir.path);

      boxes = await AgentHiveBoxes.open();
      expect(boxes.memoryBox.isOpen, isTrue);
      expect(boxes.auditBox.isOpen, isTrue);
      expect(boxes.flagsBox.isOpen, isTrue);
    });

    test('isolates memories per astronaut (AST-01 vs AST-02)', () async {
      final store = HiveMemoryStore(boxes.memoryBox);
      final t0 = DateTime.utc(2026, 11, 14, 8);

      await store.save(
        MemoryEntry(
          id: 'shared-id',
          astronautId: 'AST-01',
          kind: MemoryKind.fact,
          summary: 'AST-01 baseline HR 58 bpm',
          createdAt: t0,
        ),
      );
      await store.save(
        MemoryEntry(
          id: 'shared-id',
          astronautId: 'AST-02',
          kind: MemoryKind.fact,
          summary: 'AST-02 wears corrective lenses',
          createdAt: t0.add(const Duration(minutes: 1)),
        ),
      );

      final ast01 = await store.recall('AST-01');
      final ast02 = await store.recall('AST-02');

      expect(ast01, hasLength(1));
      expect(ast01.single.summary, 'AST-01 baseline HR 58 bpm');
      expect(ast02, hasLength(1));
      expect(ast02.single.summary, 'AST-02 wears corrective lenses');
    });

    test('filters by query (case-insensitive summary/tags), kinds, and limit', () async {
      final store = HiveMemoryStore(boxes.memoryBox);
      final base = DateTime.utc(2026, 11, 14, 9);

      await store.save(
        MemoryEntry(
          id: 'm1',
          astronautId: 'AST-01',
          kind: MemoryKind.fact,
          summary: 'Mild headache after EVA prep',
          tags: const ['eva', 'symptom'],
          createdAt: base,
        ),
      );
      await store.save(
        MemoryEntry(
          id: 'm2',
          astronautId: 'AST-01',
          kind: MemoryKind.clinicalEvent,
          summary: 'Radiation spike alert during solar particle event',
          tags: const ['radiation', 'eva'],
          createdAt: base.add(const Duration(minutes: 10)),
        ),
      );
      await store.save(
        MemoryEntry(
          id: 'm3',
          astronautId: 'AST-01',
          kind: MemoryKind.clinicalEvent,
          summary: 'EVA readiness cleared after radiation normalization',
          tags: const ['eva', 'radiation'],
          createdAt: base.add(const Duration(minutes: 20)),
        ),
      );
      await store.save(
        MemoryEntry(
          id: 'm4',
          astronautId: 'AST-01',
          kind: MemoryKind.sessionSummary,
          summary: 'Routine sleep check normal',
          tags: const ['sleep'],
          createdAt: base.add(const Duration(minutes: 30)),
        ),
      );

      final radiationMatches = await store.recall(
        'AST-01',
        query: 'RADIATION eva',
        kinds: {MemoryKind.clinicalEvent},
      );
      expect(radiationMatches.map((e) => e.id).toList(), ['m3', 'm2']);

      final singleLimit = await store.recall(
        'AST-01',
        query: 'eva',
        limit: 2,
      );
      expect(singleLimit, hasLength(2));

      final emptyKinds = await store.recall('AST-01', kinds: const {});
      expect(emptyKinds, isEmpty);
    });

    test('recentForPrompt puts facts first (up to half budget) plus latest summaries/events', () async {
      final store = HiveMemoryStore(boxes.memoryBox);
      final base = DateTime.utc(2026, 11, 14, 10);

      for (var i = 1; i <= 6; i++) {
        await store.save(
          MemoryEntry(
            id: 'fact-$i',
            astronautId: 'AST-01',
            kind: MemoryKind.fact,
            summary: 'Fact $i',
            createdAt: base.add(Duration(minutes: i)),
          ),
        );
      }
      for (var i = 1; i <= 5; i++) {
        await store.save(
          MemoryEntry(
            id: 'event-$i',
            astronautId: 'AST-01',
            kind: i.isEven ? MemoryKind.sessionSummary : MemoryKind.clinicalEvent,
            summary: 'Event $i',
            createdAt: base.add(Duration(minutes: 10 + i)),
          ),
        );
      }

      final promptMem = await store.recentForPrompt('AST-01', limit: 8);
      expect(promptMem, hasLength(8));

      final firstHalf = promptMem.take(4).toList();
      final secondHalf = promptMem.skip(4).toList();

      expect(firstHalf.every((e) => e.kind == MemoryKind.fact), isTrue);
      expect(firstHalf.map((e) => e.id), ['fact-6', 'fact-5', 'fact-4', 'fact-3']);
      expect(secondHalf.every((e) => e.kind != MemoryKind.fact), isTrue);
      expect(secondHalf.map((e) => e.id), ['event-5', 'event-4', 'event-3', 'event-2']);
    });

    test('recentForPrompt uses remaining budget for summaries/events when few facts exist', () async {
      final store = HiveMemoryStore(boxes.memoryBox);
      final base = DateTime.utc(2026, 11, 14, 11);

      await store.save(
        MemoryEntry(
          id: 'fact-only-1',
          astronautId: 'AST-01',
          kind: MemoryKind.fact,
          summary: 'Fact 1',
          createdAt: base,
        ),
      );
      for (var i = 1; i <= 8; i++) {
        await store.save(
          MemoryEntry(
            id: 'evt-$i',
            astronautId: 'AST-01',
            kind: MemoryKind.clinicalEvent,
            summary: 'Event $i',
            createdAt: base.add(Duration(minutes: i)),
          ),
        );
      }

      final promptMem = await store.recentForPrompt('AST-01', limit: 6);
      expect(promptMem, hasLength(6));
      expect(promptMem.first.id, 'fact-only-1');
      expect(promptMem.skip(1).map((e) => e.id), [
        'evt-8',
        'evt-7',
        'evt-6',
        'evt-5',
        'evt-4',
      ]);
    });
  });

  group('HiveAuditLog', () {
    test('is append-only, orders newest-first, filters by astronaut, and rejects duplicate ids', () async {
      final log = HiveAuditLog(boxes.auditBox);
      final base = DateTime.utc(2026, 11, 14, 12);

      await log.append(
        AuditEntry(
          id: 'aud-1',
          astronautId: 'AST-01',
          actionType: 'flag_batches',
          description: 'Flag batch B-12',
          payload: const {'batch': 'B-12'},
          decision: ConfirmationDecision.confirmed,
          timestamp: base,
          reason: 'Crew approved',
        ),
      );
      await log.append(
        AuditEntry(
          id: 'aud-2',
          astronautId: 'AST-02',
          actionType: 'block_eva',
          description: 'Block EVA for AST-02',
          payload: const {'hours': 12},
          decision: ConfirmationDecision.rejected,
          timestamp: base.add(const Duration(minutes: 5)),
        ),
      );
      await log.append(
        AuditEntry(
          id: 'aud-3',
          astronautId: 'AST-01',
          actionType: 'assign_goggles',
          description: 'Assign SANS goggles',
          payload: const {'pressure': 'moderate'},
          decision: ConfirmationDecision.confirmed,
          timestamp: base.add(const Duration(minutes: 10)),
        ),
      );

      await expectLater(
        log.append(
          AuditEntry(
            id: 'aud-1',
            astronautId: 'AST-01',
            actionType: 'flag_batches',
            description: 'Overwrite attempt',
            payload: const {'batch': 'B-99'},
            decision: ConfirmationDecision.rejected,
            timestamp: base.add(const Duration(minutes: 20)),
          ),
        ),
        throwsStateError,
      );

      final all = await log.list();
      expect(all.map((e) => e.id).toList(), ['aud-3', 'aud-2', 'aud-1']);

      final ast01Only = await log.list(astronautId: 'AST-01', limit: 5);
      expect(ast01Only.map((e) => e.id).toList(), ['aud-3', 'aud-1']);
      expect(ast01Only.last.reason, 'Crew approved');

      await boxes.close();
      boxes = await AgentHiveBoxes.open(directoryPath: tempDir.path);
      final reopenedLog = HiveAuditLog(boxes.auditBox);
      final persisted = await reopenedLog.list(limit: 1);
      expect(persisted.single.id, 'aud-3');
    });
  });

  group('HiveFlagsStore', () {
    test('round-trips per-astronaut flags across box close/reopen', () async {
      final flags = HiveFlagsStore(boxes.flagsBox);

      await flags.setFlag('AST-01', 'eva_blocked', {
        'blocked': true,
        'reason': 'Vestibular disturbance',
      });
      await flags.setFlag('AST-01', 'flagged_batches', {
        'batch_ids': ['LOT-77', 'LOT-81'],
      });
      await flags.setFlag('AST-02', 'assigned_goggles', {
        'enabled': true,
      });

      await boxes.close();
      boxes = await AgentHiveBoxes.open(directoryPath: tempDir.path);
      final reopened = HiveFlagsStore(boxes.flagsBox);

      final evaBlocked = await reopened.getFlag('AST-01', 'eva_blocked');
      expect(evaBlocked, {'blocked': true, 'reason': 'Vestibular disturbance'});
      expect(await reopened.getFlag('AST-02', 'eva_blocked'), isNull);

      final ast01All = await reopened.allForAstronaut('AST-01');
      expect(ast01All.keys, containsAll(['eva_blocked', 'flagged_batches']));
      expect(ast01All.containsKey('assigned_goggles'), isFalse);
    });
  });

  group('ConfirmationGateImpl', () {
    test('executes onConfirmed only on confirmed within TTL and writes audit entry', () async {
      final auditLog = HiveAuditLog(boxes.auditBox);
      final uiSink = _FakeUiSink();
      var now = DateTime.utc(2026, 11, 14, 14, 0, 0);
      final gate = ConfirmationGateImpl(
        auditLog: auditLog,
        uiSink: uiSink,
        ttl: const Duration(minutes: 5),
        clock: () => now,
      );

      var callbackRuns = 0;
      const action = ConsequentialAction(
        id: 'act-confirm-1',
        astronautId: 'AST-01',
        actionType: 'block_eva',
        description: 'Block EVA for 24 hours',
        payload: {'hours': 24},
      );

      final decisionFuture = gate.request(
        action,
        onConfirmed: () async {
          callbackRuns++;
          return {'eva_blocked': true, 'hours': 24};
        },
      );

      expect(gate.pending?.id, 'act-confirm-1');
      expect(uiSink.events, hasLength(1));
      final shown = uiSink.events.single as ShowComponentEvent;
      expect(shown.id, ComponentIds.confirmAction);
      expect(shown.props['id'], 'act-confirm-1');

      now = now.add(const Duration(minutes: 2));
      final output = await gate.resolve(
        'act-confirm-1',
        ConfirmationDecision.confirmed,
        reason: 'Commander approved',
      );
      final decision = await decisionFuture;

      expect(decision, ConfirmationDecision.confirmed);
      expect(output, {'eva_blocked': true, 'hours': 24});
      expect(callbackRuns, 1);
      expect(gate.pending, isNull);

      final audits = await auditLog.list(astronautId: 'AST-01');
      expect(audits, hasLength(1));
      expect(audits.single.id, 'act-confirm-1');
      expect(audits.single.decision, ConfirmationDecision.confirmed);
      expect(audits.single.timestamp.toUtc(), now);
      expect(audits.single.payload, {'hours': 24});
      expect(audits.single.reason, 'Commander approved');

      // Replay attempt throws StateError and does not re-run callback or duplicate audit.
      await expectLater(
        gate.resolve('act-confirm-1', ConfirmationDecision.confirmed),
        throwsStateError,
      );
      expect(callbackRuns, 1);
      expect(await auditLog.list(astronautId: 'AST-01'), hasLength(1));
    });

    test('never runs onConfirmed on rejected, writes audit, and rejects replay', () async {
      final auditLog = HiveAuditLog(boxes.auditBox);
      final now = DateTime.utc(2026, 11, 14, 15, 0, 0);
      final gate = ConfirmationGateImpl(
        auditLog: auditLog,
        clock: () => now,
      );

      var callbackRan = false;
      const action = ConsequentialAction(
        id: 'act-reject-1',
        astronautId: 'AST-01',
        actionType: 'flag_batches',
        description: 'Quarantine medication batch',
        payload: {'batch_id': 'LOT-9'},
      );

      final decisionFuture = gate.request(
        action,
        onConfirmed: () async {
          callbackRan = true;
          return {'flagged': true};
        },
      );

      final output = await gate.resolve(
        'act-reject-1',
        ConfirmationDecision.rejected,
        reason: 'False alarm',
      );
      final decision = await decisionFuture;

      expect(decision, ConfirmationDecision.rejected);
      expect(output, isNull);
      expect(callbackRan, isFalse);
      expect(gate.pending, isNull);

      final audits = await auditLog.list();
      expect(audits, hasLength(1));
      expect(audits.single.decision, ConfirmationDecision.rejected);
      expect(audits.single.reason, 'False alarm');

      await expectLater(
        gate.resolve('act-reject-1', ConfirmationDecision.confirmed),
        throwsStateError,
      );
      expect(callbackRan, isFalse);
      expect(await auditLog.list(), hasLength(1));
    });

    test('never runs onConfirmed when TTL expired even if confirmed is passed', () async {
      final auditLog = HiveAuditLog(boxes.auditBox);
      var now = DateTime.utc(2026, 11, 14, 16, 0, 0);
      final gate = ConfirmationGateImpl(
        auditLog: auditLog,
        ttl: const Duration(minutes: 5),
        clock: () => now,
      );

      var callbackRan = false;
      const action = ConsequentialAction(
        id: 'act-expire-1',
        astronautId: 'AST-01',
        actionType: 'medication_route_override',
        description: 'Switch route to IM',
        payload: {'route': 'IM'},
      );

      final decisionFuture = gate.request(
        action,
        onConfirmed: () async {
          callbackRan = true;
          return {'route': 'IM'};
        },
      );

      now = now.add(const Duration(minutes: 6));
      final output = await gate.resolve(
        'act-expire-1',
        ConfirmationDecision.confirmed,
      );
      final decision = await decisionFuture;

      expect(decision, ConfirmationDecision.expired);
      expect(output, isNull);
      expect(callbackRan, isFalse);
      expect(gate.pending, isNull);

      final audits = await auditLog.list();
      expect(audits, hasLength(1));
      expect(audits.single.decision, ConfirmationDecision.expired);
      expect(audits.single.timestamp.toUtc(), now);

      await expectLater(
        gate.resolve('act-expire-1', ConfirmationDecision.confirmed),
        throwsStateError,
      );
      expect(callbackRan, isFalse);
    });

    test('rejects mismatched actionId without running onConfirmed or corrupting pending', () async {
      final auditLog = HiveAuditLog(boxes.auditBox);
      final gate = ConfirmationGateImpl(
        auditLog: auditLog,
        awaitResolution: false,
      );

      var callbackRuns = 0;
      const action = ConsequentialAction(
        id: 'act-real-1',
        astronautId: 'AST-01',
        actionType: 'block_eva',
        description: 'Block EVA',
        payload: {'hours': 6},
      );

      await gate.request(
        action,
        onConfirmed: () async {
          callbackRuns++;
          return {'blocked': true};
        },
      );

      await expectLater(
        gate.resolve('wrong-id', ConfirmationDecision.confirmed),
        throwsStateError,
      );
      expect(callbackRuns, 0);
      expect(gate.pending?.id, 'act-real-1');
      expect(await auditLog.list(), isEmpty);

      final output = await gate.resolve(
        'act-real-1',
        ConfirmationDecision.confirmed,
      );
      expect(output, {'blocked': true});
      expect(callbackRuns, 1);
      expect(gate.pending, isNull);
    });

    test('never runs onConfirmed on explicit expired decision and records audit reason', () async {
      final auditLog = HiveAuditLog(boxes.auditBox);
      final now = DateTime.utc(2026, 11, 14, 17, 0, 0);
      final gate = ConfirmationGateImpl(
        auditLog: auditLog,
        awaitResolution: false,
        clock: () => now,
      );

      var callbackRan = false;
      const action = ConsequentialAction(
        id: 'act-explicit-expire',
        astronautId: 'AST-01',
        actionType: 'request_raman_check',
        description: 'Run Raman check',
        payload: {'batch_id': 'LOT-3'},
      );

      await gate.request(
        action,
        onConfirmed: () async {
          callbackRan = true;
          return {'requested': true};
        },
      );

      final output = await gate.resolve(
        'act-explicit-expire',
        ConfirmationDecision.expired,
        reason: 'UI dialog dismissed on timeout',
      );

      expect(output, isNull);
      expect(callbackRan, isFalse);
      final audits = await auditLog.list(astronautId: 'AST-01');
      expect(audits, hasLength(1));
      expect(audits.single.decision, ConfirmationDecision.expired);
      expect(audits.single.reason, 'UI dialog dismissed on timeout');
    });
  });

  group('SessionSummaryGenerator', () {
    test('returns null on empty transcript without saving', () async {
      final store = HiveMemoryStore(boxes.memoryBox);
      final generator = SessionSummaryGenerator(store);

      final result = await generator.summarize(
        astronautId: 'AST-01',
        transcript: const [],
      );

      expect(result, isNull);
      expect(await store.recall('AST-01'), isEmpty);
    });

    test('generates and persists compact sessionSummary with concerns, tools, and audits', () async {
      final store = HiveMemoryStore(boxes.memoryBox);
      final generator = SessionSummaryGenerator(store);
      final now = DateTime.utc(2026, 11, 14, 18, 0);

      final transcript = [
        const ChatMessage(
          role: ChatRole.user,
          content: 'Feeling dizzy after centrifuge test and eyes feel blurry.',
        ),
        const ChatMessage.assistantToolCalls([
          ToolCall(id: 'tc-1', name: 'start_graybiel', arguments: {}),
          ToolCall(id: 'tc-2', name: 'block_eva', arguments: {'hours': 12}),
        ]),
        const ChatMessage.toolResult(
          toolCallId: 'tc-1',
          content: '{"ok":true}',
        ),
        const ChatMessage(
          role: ChatRole.assistant,
          content: 'EVA has been paused for 12 hours while symptoms settle.',
        ),
      ];

      final audits = [
        AuditEntry(
          id: 'aud-s1',
          astronautId: 'AST-01',
          actionType: 'block_eva',
          description: 'Block EVA for 12h',
          payload: const {'hours': 12},
          decision: ConfirmationDecision.confirmed,
          timestamp: now,
        ),
        AuditEntry(
          id: 'aud-s2',
          astronautId: 'AST-01',
          actionType: 'assign_goggles',
          description: 'Assign SANS goggles',
          payload: const {'level': 'low'},
          decision: ConfirmationDecision.rejected,
          timestamp: now,
          reason: 'Deferred until exam',
        ),
      ];

      final saved = await generator.summarize(
        astronautId: 'AST-01',
        transcript: transcript,
        audits: audits,
        now: now,
      );

      expect(saved, isNotNull);
      expect(saved!.kind, MemoryKind.sessionSummary);
      expect(saved.astronautId, 'AST-01');
      expect(saved.summary, contains('dizzy'));
      expect(saved.summary, contains('start_graybiel'));
      expect(saved.summary, contains('block_eva'));
      expect(saved.summary, contains('confirmed'));
      expect(saved.summary, contains('rejected'));

      await boxes.close();
      boxes = await AgentHiveBoxes.open(directoryPath: tempDir.path);
      final reopenedStore = HiveMemoryStore(boxes.memoryBox);
      final recalled = await reopenedStore.recall(
        'AST-01',
        kinds: {MemoryKind.sessionSummary},
      );

      expect(recalled, hasLength(1));
      expect(recalled.single.id, saved.id);
    });
  });
}
