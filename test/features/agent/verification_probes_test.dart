import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:astramed/features/01_general_health/agent/general_health_skills.dart';
import 'package:astramed/features/02_radiation/agent/radiation_agent_skills.dart';
import 'package:astramed/features/03_microgravity/agent/microgravity_skills.dart';
import 'package:astramed/features/04_mental_health/agent/mental_health_skills.dart';
import 'package:astramed/features/04_mental_health/agent/pvt_mpt_engine.dart';
import 'package:astramed/features/05_clinical_triage/agent/proactive_monitor.dart';
import 'package:astramed/features/05_clinical_triage/agent/triage_agent_skills.dart';
import 'package:astramed/features/agent/application/agent_conversation_controller.dart';
import 'package:astramed/features/agent/application/component_registry.dart';
import 'package:astramed/features/agent/application/core_tools.dart';
import 'package:astramed/features/agent/application/skill_registry.dart';
import 'package:astramed/features/agent/data/persistence/agent_hive_boxes.dart';
import 'package:astramed/features/agent/data/persistence/confirmation_gate_impl.dart';
import 'package:astramed/features/agent/data/persistence/hive_audit_log.dart';
import 'package:astramed/features/agent/data/persistence/hive_flags_store.dart';
import 'package:astramed/features/agent/data/persistence/hive_memory_store.dart';
import 'package:astramed/features/agent/data/persistence/session_summary_generator.dart';
import 'package:astramed/features/agent/domain/agent_contracts.dart';
import 'package:astramed/features/agent/domain/agent_exception.dart';
import 'package:astramed/features/agent/domain/agent_models.dart';
import 'package:astramed/features/agent/domain/agent_ports.dart';
import 'package:astramed/features/agent/presentation/agent_canvas_view.dart';
import 'package:astramed/features/agent/providers/agent_providers.dart';
import 'package:astramed/features/crew/data/mock_crew_data.dart';
import 'package:astramed/features/crew/presentation/providers/crew_provider.dart';
import 'package:astramed/features/pharmacy/data/asset_pharmacy_inventory_repository.dart';
import 'package:astramed/features/pharmacy/domain/deterministic_medication_safety.dart';
import 'package:astramed/features/pharmacy/domain/medication_batch.dart';
import 'package:astramed/features/telemetry/presentation/providers/telemetry_provider.dart';

class _RecordingUiSink implements AgentUiSink {
  final List<AgentComponentEvent> emitted = [];
  @override
  void emit(AgentComponentEvent event) => emitted.add(event);
  @override
  void submit(String componentId, Map<String, dynamic> result) {}
}

class _InMemoryFlags implements AgentFlagsStore {
  final Map<String, Map<String, Map<String, dynamic>>> _data = {};
  @override
  Future<Map<String, Map<String, dynamic>>> allForAstronaut(String astronautId) async =>
      Map<String, Map<String, dynamic>>.from(_data[astronautId] ?? const {});
  @override
  Future<Map<String, dynamic>?> getFlag(String astronautId, String key) async =>
      _data[astronautId]?[key];
  @override
  Future<void> setFlag(String astronautId, String key, Map<String, dynamic> value) async {
    _data.putIfAbsent(astronautId, () => {})[key] = Map<String, dynamic>.from(value);
  }
}

class _InMemoryMemory implements MemoryStore {
  final List<MemoryEntry> _entries = [];
  @override
  Future<List<MemoryEntry>> recall(String astronautId, {String? query, Set<MemoryKind>? kinds, int limit = 10}) async =>
      _entries.where((e) => e.astronautId == astronautId && (kinds == null || kinds.contains(e.kind))).take(limit).toList();
  @override
  Future<List<MemoryEntry>> recentForPrompt(String astronautId, {int limit = 8}) async =>
      _entries.where((e) => e.astronautId == astronautId).take(limit).toList();
  @override
  Future<MemoryEntry> save(MemoryEntry entry) async {
    _entries.add(entry);
    return entry;
  }
}

class _InMemoryAudit implements AuditLog {
  final List<AuditEntry> entries = [];
  final Set<String> _ids = {};
  @override
  Future<void> append(AuditEntry entry) async {
    if (!_ids.add(entry.id)) {
      throw StateError('Duplicate AuditEntry id: ${entry.id}');
    }
    entries.add(entry);
  }
  @override
  Future<List<AuditEntry>> list({String? astronautId, int limit = 50}) async => entries;
}

class _FakeChatService implements AgentChatService {
  _FakeChatService(this._handler);
  final Future<AgentReply> Function(List<ChatMessage>, List<ToolSpec>?) _handler;
  int calls = 0;

  @override
  Future<AgentReply> send(
    List<ChatMessage> messages, {
    Map<String, dynamic>? context,
    List<ToolSpec>? tools,
    List<String>? skillInstructions,
  }) {
    calls++;
    return _handler(messages, tools);
  }

  @override
  Stream<AgentStreamEvent> stream(
    List<ChatMessage> messages, {
    Map<String, dynamic>? context,
    List<ToolSpec>? tools,
    List<String>? skillInstructions,
  }) => const Stream.empty();
}

class _OfflineChatService implements AgentChatService {
  int calls = 0;
  @override
  Future<AgentReply> send(
    List<ChatMessage> messages, {
    Map<String, dynamic>? context,
    List<ToolSpec>? tools,
    List<String>? skillInstructions,
  }) {
    calls++;
    throw const AgentUnavailableException();
  }

  @override
  Stream<AgentStreamEvent> stream(
    List<ChatMessage> messages, {
    Map<String, dynamic>? context,
    List<ToolSpec>? tools,
    List<String>? skillInstructions,
  }) => const Stream.empty();
}

class _FakeTts implements TextToSpeechService {
  final List<String> spoken = [];
  @override
  Future<void> speak(String text, {String? voice, String language = 'es-ES'}) async => spoken.add(text);
  @override
  Future<void> stop() async {}
  @override
  Future<void> dispose() async {}
}

class _FakeStt implements SpeechToTextService {
  @override
  Future<bool> isAvailable() async => true;
  @override
  Future<void> startListening({String language = 'es'}) async {}
  @override
  Future<String> stopListening() async => '';
  @override
  Future<String> listen({String language = 'es', Duration maxDuration = const Duration(seconds: 15)}) async => '';
  @override
  Future<void> cancel() async {}
  @override
  Future<void> dispose() async {}
}

void main() {
  group('S8 High-risk Item 2: ConfirmationGateImpl & Orchestrator flow', () {
    test('ConfirmationGateImpl enforces TTL expiry, rejection, single-pending, and no onConfirmed bypass', () async {
      var now = DateTime.utc(2026, 11, 14, 12, 0, 0);
      final audit = _InMemoryAudit();
      final ui = _RecordingUiSink();
      final gate = ConfirmationGateImpl(
        auditLog: audit,
        uiSink: ui,
        ttl: const Duration(minutes: 5),
        clock: () => now,
      );

      var executed = false;
      const action1 = ConsequentialAction(
        id: 'act-1',
        astronautId: 'AST-01',
        actionType: 'block_eva',
        description: 'Block EVA for AST-01',
        payload: {'reason': 'vertigo'},
      );

      final pendingFuture = gate.request(action1, onConfirmed: () async {
        executed = true;
        return {'ok': true};
      });

      expect(gate.pending?.id, 'act-1');
      // Cannot request another while pending
      await expectLater(
        () => gate.request(
          const ConsequentialAction(
            id: 'act-2',
            astronautId: 'AST-01',
            actionType: 'block_eva',
            description: 'Second',
            payload: {},
          ),
          onConfirmed: () async => {},
        ),
        throwsStateError,
      );
      // Mismatched id fails
      await expectLater(
        () => gate.resolve('wrong-id', ConfirmationDecision.confirmed),
        throwsStateError,
      );

      // Advance clock past TTL -> confirmed request becomes expired and does NOT run onConfirmed
      now = now.add(const Duration(minutes: 5));
      await gate.resolve('act-1', ConfirmationDecision.confirmed);
      expect(await pendingFuture, ConfirmationDecision.expired);
      expect(executed, isFalse);
      expect(gate.pending, isNull);
      expect(audit.entries.single.decision, ConfirmationDecision.expired);

      // Re-resolving or reusing id throws StateError
      await expectLater(
        () => gate.resolve('act-1', ConfirmationDecision.confirmed),
        throwsStateError,
      );
      await expectLater(
        () => gate.request(action1, onConfirmed: () async => {}),
        throwsStateError,
      );

      // Rejection never executes onConfirmed and logs reason
      const action3 = ConsequentialAction(
        id: 'act-3',
        astronautId: 'AST-01',
        actionType: 'flag_batches',
        description: 'Flag batch',
        payload: {},
      );
      final f3 = gate.request(action3, onConfirmed: () async {
        executed = true;
        return {};
      });
      await gate.resolve('act-3', ConfirmationDecision.rejected, reason: 'Crew declined');
      expect(await f3, ConfirmationDecision.rejected);
      expect(executed, isFalse);
      expect(audit.entries.last.decision, ConfirmationDecision.rejected);
      expect(audit.entries.last.reason, 'Crew declined');
    });

    test('PROBE: AgentConversationOrchestrator + ConfirmationGateImpl(awaitResolution:true) post-resolution state', () async {
      final audit = _InMemoryAudit();
      final memory = _InMemoryMemory();
      final flags = _InMemoryFlags();
      final repo = AssetPharmacyInventoryRepository.fromMemory(batches: const [], allergies: const {});
      final medSafety = DeterministicMedicationSafety(repository: repo, flags: flags);
      late AgentConversationOrchestrator orchestrator;

      var round = 0;
      final chat = _FakeChatService((msgs, tools) async {
        round++;
        if (round == 1) {
          return const AgentReply(
            reply: '',
            model: 'fake',
            toolCalls: [
              ToolCall(
                id: 'tc_1',
                name: 'block_eva',
                arguments: {'reason': 'Graybiel >= 5'},
              ),
            ],
          );
        }
        return const AgentReply(reply: 'EVA blocked and logged.', model: 'fake');
      });

      final crew = MockCrewData.getInitialCrew();
      final container = ProviderContainer(overrides: [
        crewMembersProvider.overrideWith((ref) => CrewNotifier()..state = crew),
      ]);
      addTearDown(container.dispose);

      // Use delegating sink so ConfirmationGateImpl emits to the active turn sink just like agent_providers.dart does
      final delegatingSink = _TestDelegatingSink();
      final wiredGate = ConfirmationGateImpl(auditLog: audit, uiSink: delegatingSink);
      final wiredSyncGate = _TestSyncGate(wiredGate, (p) => orchestrator.syncPendingAction(p));

      orchestrator = AgentConversationOrchestrator(
        chat: chat,
        skillRegistry: SkillRegistry([coreSkill(), ...triageAgentSkills()]),
        componentRegistry: ComponentRegistry(),
        contextFactory: (astronautId, ui) {
          delegatingSink.delegate = ui;
          return ToolContext(
            astronautId: astronautId,
            read: <T>(p) => container.read(p as ProviderListenable<T>),
            ui: ui,
            confirm: wiredSyncGate,
            audit: audit,
            memory: memory,
            flags: flags,
            medication: medSafety,
          );
        },
      );

      final turnFuture = orchestrator.sendUserMessage('block eva for AST-01');
      // Yield microtasks until pendingAction is set
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(orchestrator.state.pendingAction, isNotNull);

      await orchestrator.resolveConfirmation(ConfirmationDecision.confirmed);
      final finalState = await turnFuture;

      expect(finalState.pendingAction, isNull);
      expect(audit.entries.length, 1);
      expect(audit.entries.single.decision, ConfirmationDecision.confirmed);
      // BUG CHECK: Does confirm_action leak into final activeComponents after resolution?
      final hasStaleConfirm = finalState.activeComponents.any(
        (c) => c.componentId == ComponentIds.confirmAction,
      );
      expect(hasStaleConfirm, isFalse, reason: 'confirm_action leaked into activeComponents after confirmation was already resolved!');
      expect(
        finalState.messages.any((m) => m.content.startsWith('Confirmed:')),
        isTrue,
      );
    });
  });

  group('S8 High-risk Item 2: DeterministicMedicationSafety & Hypnotic second-dose block', () {
    test('Real DB/Pharmacy assets enforce allergies, dose limits, degradation >=15%, flags, and gastric stasis route', () async {
      final invJson = File('DB/Pharmacy/medication_inventory.json').readAsStringSync();
      final allergyJson = File('DB/Pharmacy/crew_allergies.json').readAsStringSync();
      final repo = AssetPharmacyInventoryRepository.fromJsonStrings(
        inventoryJson: invJson,
        allergiesJson: allergyJson,
      );
      final flags = _InMemoryFlags();
      final safety = DeterministicMedicationSafety(repository: repo, flags: flags);

      // AST-01 paracetamol 500mg oral -> allowed
      final ok = await safety.validate(const MedicationRequest(
        astronautId: 'AST-01',
        medication: 'paracetamol',
        doseMg: 500,
        route: 'oral',
      ));
      expect(ok.allowed, isTrue);
      expect(ok.batchId, 'BATCH-PARA-01');

      // AST-01 paracetamol 1500mg oral -> blocked (> 1000mg maxSingleDoseMg)
      final overdose = await safety.validate(const MedicationRequest(
        astronautId: 'AST-01',
        medication: 'paracetamol',
        doseMg: 1500,
        route: 'oral',
      ));
      expect(overdose.allowed, isFalse);

      // AST-01 paracetamol 0mg -> blocked
      final zeroDose = await safety.validate(const MedicationRequest(
        astronautId: 'AST-01',
        medication: 'paracetamol',
        doseMg: 0,
        route: 'oral',
      ));
      expect(zeroDose.allowed, isFalse);

      // AST-02 promethazine -> blocked by direct allergy
      final allergicMed = await safety.validate(const MedicationRequest(
        astronautId: 'AST-02',
        medication: 'promethazine',
        doseMg: 25,
        route: 'intramuscular',
      ));
      expect(allergicMed.allowed, isFalse);

      // AST-03 ibuprofen -> blocked by allergy
      final nsaidAllergy = await safety.validate(const MedicationRequest(
        astronautId: 'AST-03',
        medication: 'ibuprofen',
        doseMg: 400,
        route: 'oral',
      ));
      expect(nsaidAllergy.allowed, isFalse);

      // Gastric stasis active on AST-01 -> oral paracetamol blocked with intranasal suggestion
      await flags.setFlag('AST-01', 'eva_gastric_stasis', {'suspected': true});
      final stasis = await safety.validate(const MedicationRequest(
        astronautId: 'AST-01',
        medication: 'paracetamol',
        doseMg: 500,
        route: 'oral',
      ));
      expect(stasis.allowed, isFalse);
      expect(stasis.suggestedAlternativeRoute, 'intranasal');

      // Flagging BATCH-PARA-02 blocks intranasal paracetamol
      await repo.flagBatch('BATCH-PARA-02', reason: 'SPE compromised');
      final flagged = await safety.validate(const MedicationRequest(
        astronautId: 'AST-01',
        medication: 'paracetamol',
        doseMg: 250,
        route: 'intranasal',
      ));
      expect(flagged.allowed, isFalse);
    });

    test('Degradation boundary 14.9% allowed vs 15.0% blocked, plus drug class allergy', () async {
      final repo = AssetPharmacyInventoryRepository.fromMemory(
        batches: [
          const MedicationBatch(
            batchId: 'B-149',
            medication: 'naproxen',
            drugClass: 'nsaid',
            route: 'oral',
            unitMg: 250,
            maxSingleDoseMg: 500,
            maxDailyDoseMg: 1000,
            unitsRemaining: 10,
            storageLocation: 'vault',
            shieldingFactor: 0.9,
            radiationSensitivity: 0.2,
            degradationPct: 14.9,
            flagged: false,
          ),
          const MedicationBatch(
            batchId: 'B-150',
            medication: 'acetaminophen_x',
            drugClass: 'analgesic',
            route: 'oral',
            unitMg: 500,
            maxSingleDoseMg: 1000,
            maxDailyDoseMg: 4000,
            unitsRemaining: 10,
            storageLocation: 'hull',
            shieldingFactor: 0.2,
            radiationSensitivity: 0.9,
            degradationPct: 15.0,
            flagged: false,
          ),
        ],
        allergies: {
          'AST-03': const CrewAllergyProfile(
            astronautId: 'AST-03',
            medications: {'ibuprofen'},
            classes: {'nsaid'},
          ),
        },
      );
      final safety = DeterministicMedicationSafety(repository: repo);

      // AST-01 can take B-149 (14.9% < 15.0%)
      expect(
        (await safety.validate(const MedicationRequest(
          astronautId: 'AST-01',
          medication: 'naproxen',
          doseMg: 250,
          route: 'oral',
        ))).allowed,
        isTrue,
      );

      // AST-03 blocked on naproxen via nsaid drugClass allergy
      expect(
        (await safety.validate(const MedicationRequest(
          astronautId: 'AST-03',
          medication: 'naproxen',
          doseMg: 250,
          route: 'oral',
        ))).allowed,
        isFalse,
      );

      // B-150 blocked at exact 15.0% degradation threshold
      expect(
        (await safety.validate(const MedicationRequest(
          astronautId: 'AST-01',
          medication: 'acetaminophen_x',
          doseMg: 500,
          route: 'oral',
        ))).allowed,
        isFalse,
      );
    });

    test('Nocturnal hypnotic 8h boundary & double-block at same millisecond', () async {
      final invJson = File('DB/Pharmacy/medication_inventory.json').readAsStringSync();
      final allergyJson = File('DB/Pharmacy/crew_allergies.json').readAsStringSync();
      final repo = AssetPharmacyInventoryRepository.fromJsonStrings(
        inventoryJson: invJson,
        allergiesJson: allergyJson,
      );
      final flags = _InMemoryFlags();
      final audit = _InMemoryAudit();
      final memory = _InMemoryMemory();
      final safety = DeterministicMedicationSafety(repository: repo, flags: flags);
      final gate = _AutoConfirmGate(audit);

      ToolContext makeCtx(DateTime now) => ToolContext(
        astronautId: 'AST-01',
        read: <T>(p) => throw UnimplementedError(),
        ui: _RecordingUiSink(),
        confirm: gate,
        audit: audit,
        memory: memory,
        flags: flags,
        medication: safety,
        now: now,
      );

      final t0 = DateTime.utc(2026, 11, 14, 22, 0, 0);
      final first = await PvtMptEngine.evaluateHypnoticDose(
        ctx: makeCtx(t0),
        sleepWindowId: 'night-1',
      );
      expect(first.authorized, isTrue);
      expect(first.secondNightDoseBlocked, isFalse);

      // At +7h59m59s: blocked without calling ConfirmationGate
      final callsBefore = gate.requests;
      final t7h59 = t0.add(const Duration(hours: 7, minutes: 59, seconds: 59));
      final blocked1 = await PvtMptEngine.evaluateHypnoticDose(ctx: makeCtx(t7h59));
      expect(blocked1.authorized, isFalse);
      expect(blocked1.secondNightDoseBlocked, isTrue);
      expect(gate.requests, callsBefore);

      // PROBE: Double block in the SAME millisecond (same ctx.now)
      final blocked2 = await PvtMptEngine.evaluateHypnoticDose(ctx: makeCtx(t7h59));
      expect(blocked2.secondNightDoseBlocked, isTrue);

      // At exact +8h00m00s with new sleep window: allowed
      final t8h = t0.add(const Duration(hours: 8));
      final nextNight = await PvtMptEngine.evaluateHypnoticDose(
        ctx: makeCtx(t8h),
        sleepWindowId: 'night-2',
      );
      expect(nextNight.authorized, isTrue);
    });
  });

  group('S1 Memory & Invariants (Hive reopen + byte-identical rejected audit)', () {
    test('Hive memory/flags persist across box reopen and rejected duplicate audit keeps file byte-identical', () async {
      final dir = await Directory.systemTemp.createTemp('astramed_verify_hive_');
      addTearDown(() async {
        await Hive.close();
        if (dir.existsSync()) await dir.delete(recursive: true);
      });

      Hive.init(dir.path);
      var boxes = await AgentHiveBoxes.open();
      var memStore = HiveMemoryStore(boxes.memoryBox);
      var auditLog = HiveAuditLog(boxes.auditBox);
      var flagsStore = HiveFlagsStore(boxes.flagsBox);

      await memStore.save(MemoryEntry(
        id: 'm1',
        astronautId: 'AST-01',
        kind: MemoryKind.fact,
        summary: 'Prefers nasal route during EVA prep',
        createdAt: DateTime.utc(2026, 11, 14, 10),
        tags: const ['preference'],
      ));
      await memStore.save(MemoryEntry(
        id: 'm2',
        astronautId: 'AST-02',
        kind: MemoryKind.fact,
        summary: 'Promethazine allergy',
        createdAt: DateTime.utc(2026, 11, 14, 10),
        tags: const ['allergy'],
      ));
      await flagsStore.setFlag('AST-01', 'eva_blocked', {'blocked': true});
      await auditLog.append(AuditEntry(
        id: 'a1',
        astronautId: 'AST-01',
        actionType: 'block_eva',
        description: 'Hold EVA',
        payload: const {},
        decision: ConfirmationDecision.confirmed,
        timestamp: DateTime.utc(2026, 11, 14, 10),
      ));

      await Hive.close();

      // Snapshot audit box bytes before rejected duplicate append
      final auditFile = File('${dir.path}/${AgentHiveBoxes.auditBoxName}.hive');
      final bytesBefore = auditFile.readAsBytesSync();

      boxes = await AgentHiveBoxes.open();
      memStore = HiveMemoryStore(boxes.memoryBox);
      auditLog = HiveAuditLog(boxes.auditBox);
      flagsStore = HiveFlagsStore(boxes.flagsBox);

      // Cross-session recall & astronaut isolation
      final ast1Mem = await memStore.recall('AST-01');
      expect(ast1Mem.map((e) => e.id), ['m1']);
      final ast2Mem = await memStore.recall('AST-02');
      expect(ast2Mem.map((e) => e.id), ['m2']);
      expect((await flagsStore.getFlag('AST-01', 'eva_blocked'))?['blocked'], isTrue);

      // Append duplicate id must fail and leave box file byte-identical
      await expectLater(
        () => auditLog.append(AuditEntry(
          id: 'a1',
          astronautId: 'AST-01',
          actionType: 'block_eva',
          description: 'Overwrite attempt',
          payload: const {},
          decision: ConfirmationDecision.rejected,
          timestamp: DateTime.utc(2026, 11, 14, 11),
        )),
        throwsStateError,
      );
      await Hive.close();
      final bytesAfter = auditFile.readAsBytesSync();
      expect(bytesAfter, bytesBefore);
    });
  });

  group('S2, S3, S4, S5, S7, S9 Integration & Spec Coverage', () {
    test('All D5 skills, tools, and all 22 ComponentIds are registered in default registries/providers', () {
      final skillRegistry = SkillRegistry([
        coreSkill(),
        ...generalHealthSkills(),
        ...radiationAndPharmacySkills(),
        ...microgravitySkills(),
        ...mentalHealthSkills(),
        ...triageAgentSkills(),
      ]);

      const expectedSkillIds = [
        'core',
        'status_report',
        'telemetry',
        'artifact_filter',
        'correlation',
        'space_weather',
        'medication',
        'graybiel',
        'sans',
        'exercise',
        'procedures',
        'cognition',
        'diary',
        'readiness',
      ];
      for (final id in expectedSkillIds) {
        expect(skillRegistry.byId(id), isNotNull, reason: 'Missing skill $id');
      }

      final container = ProviderContainer();
      addTearDown(container.dispose);
      final compRegistry = container.read(componentRegistryProvider);
      final widgetRegistry = container.read(componentWidgetRegistryProvider);
      for (final cid in ComponentIds.all) {
        expect(compRegistry.has(cid), isTrue, reason: 'Missing ComponentSpec $cid');
        expect(widgetRegistry.has(cid), isTrue, reason: 'Missing WidgetBuilder $cid');
      }
      expect(ComponentIds.all.length, 22);
    });

    test('S4 ProactiveMonitor: critical alert speaks & notifies offline without LLM; exercise artifact suppressed', () async {
      final crew = MockCrewData.getInitialCrew();
      final now = DateTime.now().toUtc();
      final criticalAst = crew.first.copyWith(
        vitals: crew.first.vitals.copyWith(spO2: 86.0, activityState: 'rest'),
        exercise: crew.first.exercise.copyWith(targetReached: true),
        sleep: crew.first.sleep.copyWith(date: now),
      );
      final exercisingAst = crew[1].copyWith(
        vitals: crew[1].vitals.copyWith(heartRate: 142.0, activityState: 'exercise'),
        exercise: crew[1].exercise.copyWith(targetReached: true),
        sleep: crew[1].sleep.copyWith(date: now),
      );

      final offlineChat = _OfflineChatService();
      final tts = _FakeTts();
      final notifier = InAppAgentNotifier();
      final orchestrator = AgentConversationOrchestrator(
        chat: offlineChat,
        tts: tts,
        skillRegistry: SkillRegistry([coreSkill(), ...triageAgentSkills()]),
        componentRegistry: ComponentRegistry(),
        contextFactory: (id, ui) => ToolContext(
          astronautId: id,
          read: <T>(p) => throw UnimplementedError(),
          ui: ui,
          confirm: _AutoConfirmGate(_InMemoryAudit()),
          audit: _InMemoryAudit(),
          memory: _InMemoryMemory(),
          flags: _InMemoryFlags(),
          medication: DeterministicMedicationSafety(
            repository: AssetPharmacyInventoryRepository.fromMemory(batches: const [], allergies: const {}),
          ),
        ),
      );

      final monitor = ProactiveMonitor(
        notifier: notifier,
        orchestrator: orchestrator,
      );

      final events = await monitor.evaluate(crew: [criticalAst, exercisingAst]);
      expect(events.any((e) => e.astronautId == criticalAst.id && e.severity == ProactiveSeverity.critical), isTrue);
      // Exercising astronaut HR 142 with activityState=exercise should NOT fire tachycardia_alert
      expect(events.any((e) => e.astronautId == exercisingAst.id && e.kind == 'tachycardia_alert'), isFalse);
      // Critical alert bypassed LLM completely
      expect(offlineChat.calls, 0);
      expect(tts.spoken, isNotEmpty);
      expect(notifier.notifications, isNotEmpty);
    });

    test('S9 Offline: free chat reports unavailable, matched offlineFlow advances deterministically', () async {
      final crew = MockCrewData.getInitialCrew();
      final container = ProviderContainer(overrides: [
        crewMembersProvider.overrideWith((ref) => CrewNotifier()..state = crew),
      ]);
      addTearDown(container.dispose);

      final tts = _FakeTts();
      final orchestrator = AgentConversationOrchestrator(
        chat: _OfflineChatService(),
        tts: tts,
        skillRegistry: SkillRegistry([coreSkill(), ...triageAgentSkills()]),
        componentRegistry: ComponentRegistry(),
        contextFactory: (id, ui) => ToolContext(
          astronautId: id,
          read: <T>(p) => container.read(p as ProviderListenable<T>),
          ui: ui,
          confirm: _AutoConfirmGate(_InMemoryAudit()),
          audit: _InMemoryAudit(),
          memory: _InMemoryMemory(),
          flags: _InMemoryFlags(),
          medication: DeterministicMedicationSafety(
            repository: AssetPharmacyInventoryRepository.fromMemory(batches: const [], allergies: const {}),
          ),
        ),
      );

      // Free chat offline -> reports unavailable
      final freeState = await orchestrator.sendUserMessage('hello how are stars formed');
      expect(freeState.offlineMode, isTrue);
      expect(freeState.messages.last.content.toLowerCase(), contains('unavailable'));

      // Matched readiness offline flow -> starts & finishes deterministically
      final step1 = await orchestrator.sendUserMessage('check pre-eva readiness');
      expect(step1.activeOfflineFlowSkillId, 'readiness');
      await orchestrator.sendUserMessage('Pre-EVA');
      final step3 = await orchestrator.sendUserMessage('Nominal');
      expect(step3.activeOfflineFlowSkillId, isNull);
      expect(step3.activeComponents.any((c) => c.componentId == ComponentIds.evaReadiness), isTrue);
    });

    testWidgets('S7 AgentCanvasView: visually silent initially & supports componentWidgetOverridesProvider', (tester) async {
      final crew = MockCrewData.getInitialCrew();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            crewMembersProvider.overrideWith((ref) => CrewNotifier()..state = crew),
            telemetryProvider.overrideWith((ref) => TelemetryNotifier(ref)..syncWithCrewData(crew)),
            speechToTextServiceProvider.overrideWithValue(_FakeStt()),
            textToSpeechServiceProvider.overrideWithValue(_FakeTts()),
            agentChatServiceProvider.overrideWithValue(_OfflineChatService()),
            componentWidgetOverridesProvider.overrideWithValue({
              ComponentIds.evaReadiness: (context, vm, onSubmit, onDismiss) =>
                  const Text('CUSTOM_DESIGNER_EVA_WIDGET'),
            }),
          ],
          child: const MaterialApp(home: AgentCanvasView()),
        ),
      );
      await tester.pumpAndSettle();

      // Visually quiet when nominal / no active components
      final injectionFinder = find.byKey(AgentCanvasView.injectionZoneKey);
      expect(injectionFinder, findsOneWidget);
      expect(
        find.descendant(of: injectionFinder, matching: find.byType(SizedBox)),
        findsOneWidget,
      );

      // Trigger offline readiness flow via UI text bar -> designer custom widget replaces placeholder
      await tester.enterText(find.byKey(AgentCanvasView.textInputKey), 'pre-eva readiness');
      await tester.tap(find.byKey(AgentCanvasView.sendButtonKey));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(AgentCanvasView.textInputKey), 'Pre-EVA');
      await tester.tap(find.byKey(AgentCanvasView.sendButtonKey));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(AgentCanvasView.textInputKey), 'Nominal');
      await tester.tap(find.byKey(AgentCanvasView.sendButtonKey));
      await tester.pumpAndSettle();

      expect(find.text('CUSTOM_DESIGNER_EVA_WIDGET'), findsOneWidget);
    });

    test('S3 & D1: Live data reads Riverpod at call time & tool loop enforces 6-round cap', () async {
      final crew = MockCrewData.getInitialCrew();
      final container = ProviderContainer(overrides: [
        crewMembersProvider.overrideWith((ref) => CrewNotifier()..state = crew),
        telemetryProvider.overrideWith((ref) => TelemetryNotifier(ref)..syncWithCrewData(crew)),
      ]);
      addTearDown(container.dispose);

      // Mutate vitals in Riverpod -> get_vitals must read updated HR
      container.read(crewMembersProvider.notifier).updateVitals(
        crew.first.id,
        crew.first.vitals.copyWith(heartRate: 112.0),
      );

      var calls = 0;
      List<ToolSpec>? seventhCallTools;
      final chat = _FakeChatService((msgs, tools) async {
        calls++;
        if (calls <= 6) {
          return AgentReply(
            reply: '',
            model: 'fake',
            toolCalls: [
              ToolCall(id: 'c_\$calls', name: 'get_vitals', arguments: const {}),
            ],
          );
        }
        seventhCallTools = tools;
        return const AgentReply(reply: 'Done after 6 tool rounds.', model: 'fake');
      });

      final orchestrator = AgentConversationOrchestrator(
        chat: chat,
        skillRegistry: SkillRegistry([coreSkill()]),
        componentRegistry: ComponentRegistry(),
        contextFactory: (id, ui) => ToolContext(
          astronautId: id,
          read: <T>(p) => container.read(p as ProviderListenable<T>),
          ui: ui,
          confirm: _AutoConfirmGate(_InMemoryAudit()),
          audit: _InMemoryAudit(),
          memory: _InMemoryMemory(),
          flags: _InMemoryFlags(),
          medication: DeterministicMedicationSafety(
            repository: AssetPharmacyInventoryRepository.fromMemory(batches: const [], allergies: const {}),
          ),
        ),
      );

      final res = await orchestrator.sendUserMessage('check vitals');
      expect(calls, 7);
      expect(seventhCallTools, isEmpty);
      expect(res.messages.last.content, 'Done after 6 tool rounds.');
      // Tool result message in transcript should contain updated HR 112.0
      final toolMsg = res.messages.firstWhere((m) => m.role == ChatRole.tool);
      expect(toolMsg.content, contains('112.0'));
    });

    test('S1: SessionSummaryGenerator persists session_summary into HiveMemoryStore', () async {
      final dir = await Directory.systemTemp.createTemp('astramed_verify_sum_');
      addTearDown(() async {
        await Hive.close();
        if (dir.existsSync()) await dir.delete(recursive: true);
      });
      Hive.init(dir.path);
      final boxes = await AgentHiveBoxes.open();
      final memStore = HiveMemoryStore(boxes.memoryBox);
      final gen = SessionSummaryGenerator(memStore);
      final entry = await gen.summarize(
        astronautId: 'AST-01',
        transcript: const [
          ChatMessage(role: ChatRole.user, content: 'Feeling dizzy before EVA'),
          ChatMessage.assistantToolCalls([ToolCall(id: 't1', name: 'evaluate_readiness', arguments: {})]),
        ],
        now: DateTime.utc(2026, 11, 14, 15),
      );
      expect(entry, isNotNull);
      final recalled = await memStore.recall('AST-01', kinds: {MemoryKind.sessionSummary});
      expect(recalled.length, 1);
      expect(recalled.first.summary, contains('Feeling dizzy before EVA'));

      // Also verify orchestrator.closeSession() and switchAstronaut() persist session summaries
      final chat = _FakeChatService((msgs, tools) async => const AgentReply(reply: 'Rest now.', model: 'm'));
      final emptyRepo = AssetPharmacyInventoryRepository.fromMemory(batches: const [], allergies: const {});
      final orch = AgentConversationOrchestrator(
        chat: chat,
        skillRegistry: SkillRegistry([coreSkill()]),
        componentRegistry: ComponentRegistry(),
        contextFactory: (astronautId, ui) => ToolContext(
          astronautId: astronautId,
          read: <T>(p) => throw UnimplementedError(),
          ui: ui,
          confirm: _AutoConfirmGate(_InMemoryAudit()),
          audit: _InMemoryAudit(),
          memory: memStore,
          flags: _InMemoryFlags(),
          medication: DeterministicMedicationSafety(repository: emptyRepo, flags: _InMemoryFlags()),
        ),
      );
      await orch.sendUserMessage('Headache after EVA prep');
      final closedSummary = await orch.closeSession(astronautId: 'AST-01');
      expect(closedSummary, isNotNull);
      final afterClose = await memStore.recall('AST-01', kinds: {MemoryKind.sessionSummary});
      expect(afterClose.length, 2);
      expect(afterClose.any((e) => e.summary.contains('Headache after EVA prep')), isTrue);
    });
  });
}

class _TestDelegatingSink implements AgentUiSink {
  AgentUiSink? delegate;
  @override
  void emit(AgentComponentEvent event) => delegate?.emit(event);
  @override
  void submit(String componentId, Map<String, dynamic> result) =>
      delegate?.submit(componentId, result);
}

class _TestSyncGate implements ConfirmationGate {
  _TestSyncGate(this.inner, this.onPendingChanged);
  final ConfirmationGate inner;
  final void Function(ConsequentialAction?) onPendingChanged;
  @override
  ConsequentialAction? get pending => inner.pending;
  @override
  Future<ConfirmationDecision> request(
    ConsequentialAction action, {
    required Future<Map<String, dynamic>> Function() onConfirmed,
  }) {
    final future = inner.request(action, onConfirmed: onConfirmed);
    onPendingChanged(inner.pending);
    return future;
  }
  @override
  Future<Map<String, dynamic>?> resolve(
    String actionId,
    ConfirmationDecision decision, {
    String? reason,
  }) async {
    final res = await inner.resolve(actionId, decision, reason: reason);
    onPendingChanged(inner.pending);
    return res;
  }
}

class _AutoConfirmGate implements ConfirmationGate {
  _AutoConfirmGate(this._audit);
  final AuditLog _audit;
  int requests = 0;
  @override
  ConsequentialAction? get pending => null;
  @override
  Future<ConfirmationDecision> request(
    ConsequentialAction action, {
    required Future<Map<String, dynamic>> Function() onConfirmed,
  }) async {
    requests++;
    await onConfirmed();
    await _audit.append(AuditEntry(
      id: action.id,
      astronautId: action.astronautId,
      actionType: action.actionType,
      description: action.description,
      payload: action.payload,
      decision: ConfirmationDecision.confirmed,
      timestamp: DateTime.utc(2026, 11, 14, 22),
    ));
    return ConfirmationDecision.confirmed;
  }
  @override
  Future<Map<String, dynamic>?> resolve(String actionId, ConfirmationDecision decision, {String? reason}) async => null;
}
