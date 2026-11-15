import 'dart:async';

import 'package:astramed/features/01_general_health/models/vitals_record.dart';
import 'package:astramed/features/02_radiation/agent/donki_space_weather_service.dart';
import 'package:astramed/features/02_radiation/models/radiation_dose.dart';
import 'package:astramed/features/03_microgravity/models/microgravity_data.dart';
import 'package:astramed/features/04_mental_health/models/sleep_record.dart';
import 'package:astramed/features/05_clinical_triage/agent/operational_readiness_engine.dart';
import 'package:astramed/features/05_clinical_triage/agent/proactive_monitor.dart';
import 'package:astramed/features/05_clinical_triage/agent/triage_agent_skills.dart';
import 'package:astramed/features/05_clinical_triage/models/triage_decision.dart';
import 'package:astramed/features/agent/application/agent_conversation_controller.dart';
import 'package:astramed/features/agent/application/component_registry.dart';
import 'package:astramed/features/agent/application/skill_registry.dart';
import 'package:astramed/features/agent/data/persistence/confirmation_gate_impl.dart';
import 'package:astramed/features/agent/domain/agent_contracts.dart';
import 'package:astramed/features/agent/domain/agent_exception.dart';
import 'package:astramed/features/agent/domain/agent_models.dart';
import 'package:astramed/features/agent/domain/agent_ports.dart';
import 'package:astramed/features/crew/models/astronaut_profile.dart';
import 'package:astramed/features/crew/presentation/providers/crew_provider.dart';
import 'package:flutter_test/flutter_test.dart';

class _RecordingUiSink implements AgentUiSink {
  final List<AgentComponentEvent> events = [];

  @override
  void emit(AgentComponentEvent event) => events.add(event);

  @override
  void submit(String componentId, Map<String, dynamic> result) {}
}

class _FakeMemoryStore implements MemoryStore {
  final List<MemoryEntry> entries = [];

  @override
  Future<List<MemoryEntry>> recall(
    String astronautId, {
    String? query,
    Set<MemoryKind>? kinds,
    int limit = 10,
  }) async {
    return entries
        .where((e) => e.astronautId == astronautId)
        .where((e) => kinds == null || kinds.contains(e.kind))
        .take(limit)
        .toList();
  }

  @override
  Future<List<MemoryEntry>> recentForPrompt(
    String astronautId, {
    int limit = 8,
  }) async =>
      entries.where((e) => e.astronautId == astronautId).take(limit).toList();

  @override
  Future<MemoryEntry> save(MemoryEntry entry) async {
    entries.add(entry);
    return entry;
  }
}

class _FakeAuditLog implements AuditLog {
  final List<AuditEntry> entries = [];

  @override
  Future<void> append(AuditEntry entry) async => entries.add(entry);

  @override
  Future<List<AuditEntry>> list({String? astronautId, int limit = 50}) async =>
      entries
          .where((e) => astronautId == null || e.astronautId == astronautId)
          .take(limit)
          .toList();
}

class _FakeFlagsStore implements AgentFlagsStore {
  final Map<String, Map<String, Map<String, dynamic>>> store = {};

  @override
  Future<Map<String, Map<String, dynamic>>> allForAstronaut(
    String astronautId,
  ) async {
    return Map<String, Map<String, dynamic>>.from(
      store[astronautId] ?? const {},
    );
  }

  @override
  Future<Map<String, dynamic>?> getFlag(String astronautId, String key) async =>
      store[astronautId]?[key];

  @override
  Future<void> setFlag(
    String astronautId,
    String key,
    Map<String, dynamic> value,
  ) async {
    store.putIfAbsent(astronautId, () => {})[key] = value;
  }
}

class _FakeMedicationSafety implements MedicationSafety {
  @override
  Future<MedicationCheck> validate(MedicationRequest request) async =>
      const MedicationCheck(allowed: true, reasons: []);
}

class _OfflineChatService implements AgentChatService {
  int sendCalls = 0;

  @override
  Future<AgentReply> send(
    List<ChatMessage> messages, {
    Map<String, dynamic>? context,
    List<ToolSpec>? tools,
    List<String>? skillInstructions,
  }) async {
    sendCalls++;
    throw const AgentUnavailableException(message: 'Gateway offline');
  }

  @override
  Stream<AgentStreamEvent> stream(
    List<ChatMessage> messages, {
    Map<String, dynamic>? context,
    List<ToolSpec>? tools,
    List<String>? skillInstructions,
  }) =>
      Stream.error(const AgentUnavailableException(message: 'Gateway offline'));
}

class _RecordingTts implements TextToSpeechService {
  final List<String> spoken = [];

  @override
  Future<void> speak(
    String text, {
    String? voice,
    String language = 'es-ES',
  }) async {
    spoken.add(text);
  }

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() async {}
}

AstronautProfile _makeProfile({
  String id = 'AST-01',
  String name = 'Alex Vance',
  double heartRate = 68.0,
  double systolicBP = 118.0,
  double diastolicBP = 76.0,
  double spO2 = 99.0,
  double bodyTemp = 36.6,
  double bloodGlucose = 95.0,
  double respiratoryRate = 14.0,
  double capillaryRefillSeconds = 1.4,
  String activityState = 'active_duty',
  String signalQuality = 'optimal (98%)',
  double doseRateMicroSvPerHour = 58.2,
  RadiationSeverity radiationSeverity = RadiationSeverity.normal,
  double sleepHours = 7.5,
  bool exerciseTargetReached = true,
  String exerciseActivityState = 'exercise',
}) {
  final now = DateTime.utc(2026, 11, 14, 12, 0);
  return AstronautProfile(
    id: id,
    name: name,
    role: 'Mission Commander',
    rank: 'Cmdr.',
    callsign: 'ARES-1',
    avatarInitials: 'AV',
    age: 42,
    bloodType: 'O+',
    currentZone: 'Destiny Lab',
    vitals: VitalsRecord(
      timestamp: now,
      astronautId: id,
      heartRate: heartRate,
      systolicBP: systolicBP,
      diastolicBP: diastolicBP,
      spO2: spO2,
      bodyTemp: bodyTemp,
      bloodGlucose: bloodGlucose,
      respiratoryRate: respiratoryRate,
      capillaryRefillSeconds: capillaryRefillSeconds,
      activityState: activityState,
      signalQuality: signalQuality,
    ),
    radiation: RadiationDose(
      timestamp: now,
      astronautId: id,
      doseRateMicroSvPerHour: doseRateMicroSvPerHour,
      cumulativeDoseMilliSv: 18.4,
      severity: radiationSeverity,
    ),
    sleep: SleepRecord(
      date: now,
      astronautId: id,
      sleepHours: sleepHours,
      wakeEpisodes: 0,
      morningMood: MoodLevel.great,
    ),
    exercise: ExerciseSession(
      date: now,
      astronautId: id,
      deviceName: 'ARED',
      durationMinutes: 45,
      caloriesBurned: 420.0,
      targetReached: exerciseTargetReached,
      activityState: exerciseActivityState,
    ),
    riskLevel: CrewRiskLevel.nominal,
    riskTitle: 'Nominal',
    riskDescription: 'All parameters stable.',
    activeAlerts: const [],
  );
}

ToolContext _makeContext({
  required List<AstronautProfile> crew,
  String astronautId = 'AST-01',
  _FakeFlagsStore? flags,
  _FakeAuditLog? audit,
  ConfirmationGate? confirm,
  AgentUiSink? ui,
  _FakeMemoryStore? memory,
  DateTime? now,
}) {
  final resolvedAudit = audit ?? _FakeAuditLog();
  final resolvedUi = ui ?? _RecordingUiSink();
  return ToolContext(
    astronautId: astronautId,
    read: <T>(Object provider) {
      if (provider == crewMembersProvider) {
        return crew as T;
      }
      if (provider == selectedAstronautIdProvider) {
        return astronautId as T;
      }
      throw UnimplementedError('Provider not stubbed in test: $provider');
    },
    ui: resolvedUi,
    confirm: confirm ??
        ConfirmationGateImpl(
          auditLog: resolvedAudit,
          uiSink: resolvedUi,
          awaitResolution: false,
        ),
    audit: resolvedAudit,
    memory: memory ?? _FakeMemoryStore(),
    flags: flags ?? _FakeFlagsStore(),
    medication: _FakeMedicationSafety(),
    now: now ?? DateTime.utc(2026, 11, 14, 12, 0),
  );
}

void main() {
  group('OperationalReadinessEngine', () {
    const engine = OperationalReadinessEngine();

    test('authorizes nominal crew member as green for Pre-EVA and Landing', () {
      final profile = _makeProfile();

      final evaVerdict = engine.evaluate(
        profile: profile,
        activityType: 'pre_eva',
        graybielScore: 0,
        lrm50Ms: 245.0,
        pvtLapses: 0,
      );
      expect(evaVerdict.authorized, isTrue);
      expect(evaVerdict.priority, TriagePriority.green);
      expect(evaVerdict.blockingReasons, isEmpty);
      expect(evaVerdict.cautionReasons, isEmpty);

      final landingVerdict = engine.evaluate(
        profile: profile,
        activityType: 'landing',
      );
      expect(landingVerdict.authorized, isTrue);
      expect(landingVerdict.priority, TriagePriority.green);
      expect(landingVerdict.toTriageResult().priority, TriagePriority.green);
    });

    test('blocks Pre-EVA (red) when Graybiel score >= 5', () {
      final verdict = engine.evaluate(
        profile: _makeProfile(),
        activityType: 'pre_eva',
        graybielScore: 5,
      );

      expect(verdict.authorized, isFalse);
      expect(verdict.priority, TriagePriority.red);
      expect(
        verdict.blockingReasons.any((r) => r.toLowerCase().contains('graybiel')),
        isTrue,
      );
    });

    test('blocks Pre-EVA (red) when eva_blocked or eva_blocked_by_graybiel flag is active', () {
      final evaFlagVerdict = engine.evaluate(
        profile: _makeProfile(),
        activityType: 'pre_eva',
        activeFlags: {
          'eva_blocked': {
            'blocked': true,
            'reason': 'Vestibular instability observed',
            'activity_type': 'pre_eva',
            'duration_hours': 12.0,
            'timestamp': '2026-11-14T10:00:00.000Z',
          },
        },
        now: DateTime.utc(2026, 11, 14, 12, 0),
      );
      expect(evaFlagVerdict.authorized, isFalse);
      expect(evaFlagVerdict.priority, TriagePriority.red);
      expect(
        evaFlagVerdict.blockingReasons.any(
          (r) => r.contains('Vestibular instability observed'),
        ),
        isTrue,
      );

      final expiredFlagVerdict = engine.evaluate(
        profile: _makeProfile(),
        activityType: 'pre_eva',
        activeFlags: {
          'eva_blocked': {
            'blocked': true,
            'reason': 'Vestibular instability observed',
            'activity_type': 'pre_eva',
            'duration_hours': 12.0,
            'timestamp': '2026-11-14T10:00:00.000Z',
          },
        },
        now: DateTime.utc(2026, 11, 14, 23, 0),
      );
      expect(expiredFlagVerdict.authorized, isTrue);
      expect(expiredFlagVerdict.priority, TriagePriority.green);

      final graybielFlagVerdict = engine.evaluate(
        profile: _makeProfile(),
        activityType: 'pre_eva',
        activeFlags: {
          'eva_blocked_by_graybiel': {
            'blocked': true,
            'graybiel_score': 8,
          },
        },
      );
      expect(graybielFlagVerdict.authorized, isFalse);
      expect(graybielFlagVerdict.priority, TriagePriority.red);
      expect(graybielFlagVerdict.blockingReasons, isNotEmpty);
    });

    test('blocks Pre-EVA (red) on LRM-50 > 300, PVT lapses >= 3, sleep < 6.0, or uncompensated sedative', () {
      final lrmVerdict = engine.evaluate(
        profile: _makeProfile(),
        lrm50Ms: 315.0,
      );
      expect(lrmVerdict.authorized, isFalse);
      expect(lrmVerdict.priority, TriagePriority.red);
      expect(
        lrmVerdict.blockingReasons.any((r) => r.contains('LRM-50')),
        isTrue,
      );

      final lapsesVerdict = engine.evaluate(
        profile: _makeProfile(),
        pvtLapses: 3,
      );
      expect(lapsesVerdict.authorized, isFalse);
      expect(lapsesVerdict.priority, TriagePriority.red);

      final sleepVerdict = engine.evaluate(
        profile: _makeProfile(sleepHours: 5.5),
      );
      expect(sleepVerdict.authorized, isFalse);
      expect(sleepVerdict.priority, TriagePriority.red);

      final uncompensatedSedative = engine.evaluate(
        profile: _makeProfile(),
        activeFlags: {
          'recent_sedative_use': {
            'medication': 'promethazine',
            'timestamp': '2026-11-14T08:00:00.000Z',
          },
        },
        now: DateTime.utc(2026, 11, 14, 12, 0),
      );
      expect(uncompensatedSedative.authorized, isFalse);
      expect(uncompensatedSedative.priority, TriagePriority.red);
      expect(
        uncompensatedSedative.blockingReasons.any(
          (r) => r.toLowerCase().contains('sedative'),
        ),
        isTrue,
      );

      final compensatedSedative = engine.evaluate(
        profile: _makeProfile(),
        activeFlags: {
          'recent_sedative_use': {
            'medication': 'promethazine',
            'timestamp': '2026-11-14T08:00:00.000Z',
          },
          'stimulant_compensation_authorized': {
            'medication': 'modafinil',
            'authorized_at': '2026-11-14T10:00:00.000Z',
          },
        },
        now: DateTime.utc(2026, 11, 14, 12, 0),
      );
      expect(compensatedSedative.authorized, isTrue);
      expect(compensatedSedative.priority, TriagePriority.yellow);
    });

    test('blocks Pre-EVA (red) on SpO2 < 94, unstable vitals, or critical radiation', () {
      final hypoxiaVerdict = engine.evaluate(
        profile: _makeProfile(spO2: 92.0),
      );
      expect(hypoxiaVerdict.authorized, isFalse);
      expect(hypoxiaVerdict.priority, TriagePriority.red);
      expect(
        hypoxiaVerdict.blockingReasons.any((r) => r.contains('SpO2')),
        isTrue,
      );
      expect(hypoxiaVerdict.requiredSupplies, isNotEmpty);

      final vitalsVerdict = engine.evaluate(
        profile: _makeProfile(
          systolicBP: 155.0,
          heartRate: 115.0,
          respiratoryRate: 24.0,
          bodyTemp: 38.1,
          doseRateMicroSvPerHour: 175.0,
          radiationSeverity: RadiationSeverity.critical,
        ),
      );
      expect(vitalsVerdict.authorized, isFalse);
      expect(vitalsVerdict.priority, TriagePriority.red);
      expect(vitalsVerdict.blockingReasons.length, greaterThanOrEqualTo(5));
    });
  });

  group('triageAgentSkills & confirmation gate', () {
    test('evaluate_readiness emits typed EvaReadinessViewModel props', () async {
      final skills = triageAgentSkills();
      expect(skills.map((s) => s.id), ['readiness']);
      final skill = skills.first;
      expect(skill.componentIds, [ComponentIds.evaReadiness]);

      final evalTool = skill.tools.firstWhere((t) => t.name == 'evaluate_readiness');
      final ui = _RecordingUiSink();
      final ctx = _makeContext(crew: [_makeProfile()], ui: ui);

      final result = await evalTool.call({'activity_type': 'pre_eva'}, ctx);
      expect(result.ok, isTrue);
      expect(result.data['authorized'], isTrue);
      expect(result.uiEvents, hasLength(1));

      final showEvent = result.uiEvents.first as ShowComponentEvent;
      expect(showEvent.id, ComponentIds.evaReadiness);
      final vm = EvaReadinessViewModel.fromProps(showEvent.props);
      expect(vm.authorized, isTrue);
      expect(vm.priority, TriagePriority.green);
      expect(vm.activityType, 'pre_eva');

      expect(
        () => EvaReadinessViewModel.fromProps({'astronaut_id': ''}),
        throwsFormatException,
      );
    });

    test('block_eva requires confirmation and does NOT write eva_blocked when rejected', () async {
      final skills = triageAgentSkills();
      final blockTool = skills.first.tools.firstWhere((t) => t.name == 'block_eva');
      expect(blockTool.effect, ToolEffect.consequential);

      final flags = _FakeFlagsStore();
      final audit = _FakeAuditLog();
      final ui = _RecordingUiSink();
      final gate = ConfirmationGateImpl(auditLog: audit, uiSink: ui);
      final ctx = _makeContext(
        crew: [_makeProfile()],
        flags: flags,
        audit: audit,
        confirm: gate,
        ui: ui,
      );

      final rejectFuture = blockTool.call({
        'reason': 'Suspected acute SMS prior to EVA',
        'activity_type': 'pre_eva',
        'duration_hours': 12,
      }, ctx);

      await Future<void>.delayed(Duration.zero);
      expect(gate.pending, isNotNull);
      await gate.resolve(
        gate.pending!.id,
        ConfirmationDecision.rejected,
        reason: 'Crew requested recheck first',
      );
      final rejectResult = await rejectFuture;
      expect(rejectResult.ok, isTrue);
      expect(rejectResult.data['confirmed'], isFalse);
      expect(await flags.getFlag('AST-01', 'eva_blocked'), isNull);
      expect(audit.entries.last.decision, ConfirmationDecision.rejected);

      final confirmFuture = blockTool.call({
        'reason': 'Confirmed moderate Graybiel malaise',
        'activity_type': 'pre_eva',
        'duration_hours': 24,
      }, ctx);

      await Future<void>.delayed(Duration.zero);
      expect(gate.pending, isNotNull);
      await gate.resolve(gate.pending!.id, ConfirmationDecision.confirmed);
      final confirmResult = await confirmFuture;
      expect(confirmResult.ok, isTrue);
      expect(confirmResult.data['confirmed'], isTrue);

      final flag = await flags.getFlag('AST-01', 'eva_blocked');
      expect(flag, isNotNull);
      expect(flag!['blocked'], isTrue);
      expect(flag['reason'], 'Confirmed moderate Graybiel malaise');
      expect(flag['activity_type'], 'pre_eva');
      expect(flag['duration_hours'], 24.0);
      expect(flag['timestamp'], isA<String>());
      expect(audit.entries.last.decision, ConfirmationDecision.confirmed);
    });

    test('offline readiness DeterministicFlow runs end to end in offline mode', () async {
      final skills = triageAgentSkills();
      final registry = SkillRegistry(skills);
      final chat = _OfflineChatService();
      final tts = _RecordingTts();
      final crew = [_makeProfile()];
      final flags = _FakeFlagsStore();

      final orchestrator = AgentConversationOrchestrator(
        chat: chat,
        tts: tts,
        skillRegistry: registry,
        componentRegistry: ComponentRegistry(),
        contextFactory: (astronautId, ui) => _makeContext(
          crew: crew,
          astronautId: astronautId,
          flags: flags,
          ui: ui,
        ),
      );

      final step1 = await orchestrator.sendUserMessage('Check pre-eva readiness');
      expect(step1.offlineMode, isTrue);
      expect(step1.activeOfflineFlowSkillId, 'readiness');
      expect(tts.spoken, isNotEmpty);

      final step2 = await orchestrator.sendUserMessage('Pre-EVA');
      expect(step2.offlineMode, isTrue);
      expect(step2.activeOfflineFlowSkillId, 'readiness');

      final step3 = await orchestrator.sendUserMessage('Nominal');
      expect(step3.offlineMode, isTrue);
      expect(step3.activeOfflineFlowSkillId, isNull);
      expect(
        step3.activeComponents.any((c) => c.componentId == ComponentIds.evaReadiness),
        isTrue,
      );
      expect(step3.messages.last.content.toLowerCase(), contains('authorized'));
    });
  });

  group('ProactiveMonitor & InAppAgentNotifier', () {
    test('suppresses false hypoxia during high-motion exercise with degraded optical signal', () async {
      final notifier = InAppAgentNotifier();
      final monitor = ProactiveMonitor(notifier: notifier);
      final exerciseProfile = _makeProfile(
        spO2: 90.0,
        heartRate: 148.0,
        activityState: 'exercise',
        signalQuality: 'degraded (52%)',
      );

      final emitted = await monitor.evaluate(
        crew: [exerciseProfile],
        accelerationRmsGByAstronaut: {'AST-01': 0.72},
        motionArtifactIndexByAstronaut: {'AST-01': 0.85},
      );

      expect(emitted, isEmpty);
      expect(notifier.notifications, isEmpty);
    });

    test('fires critical ProactiveEvent on true hypoxia (SpO2 86% at rest) and speaks offline without calling LLM', () async {
      final notifier = InAppAgentNotifier();
      final receivedStream = <ProactiveEvent>[];
      final sub = notifier.stream.listen(receivedStream.add);

      final chat = _OfflineChatService();
      final tts = _RecordingTts();
      final hypoxicProfile = _makeProfile(
        spO2: 86.0,
        heartRate: 112.0,
        activityState: 'resting',
        signalQuality: 'optimal (98%)',
      );

      final orchestrator = AgentConversationOrchestrator(
        chat: chat,
        tts: tts,
        skillRegistry: SkillRegistry(triageAgentSkills()),
        componentRegistry: ComponentRegistry(),
        contextFactory: (id, ui) => _makeContext(
          crew: [hypoxicProfile],
          astronautId: id,
          ui: ui,
        ),
      );

      final monitor = ProactiveMonitor(
        notifier: notifier,
        orchestrator: orchestrator,
      );

      final emitted = await monitor.evaluate(crew: [hypoxicProfile]);

      expect(emitted, hasLength(1));
      final event = emitted.first;
      expect(event.severity, ProactiveSeverity.critical);
      expect(event.uiEvents.first, isA<ShowComponentEvent>());
      expect(
        (event.uiEvents.first as ShowComponentEvent).id,
        ComponentIds.alertBanner,
      );

      expect(notifier.notifications, hasLength(1));
      await Future<void>.delayed(Duration.zero);
      expect(receivedStream, hasLength(1));

      expect(chat.sendCalls, 0);
      expect(tts.spoken, [event.spokenMessage]);
      expect(
        orchestrator.state.activeComponents.any(
          (c) => c.componentId == ComponentIds.alertBanner,
        ),
        isTrue,
      );

      await sub.cancel();
      await notifier.dispose();
    });

    test('fires space-weather and scheduled-check proactive events', () async {
      final now = DateTime.utc(2026, 11, 14, 18, 0);
      final notifier = InAppAgentNotifier();
      final monitor = ProactiveMonitor(notifier: notifier);

      final stressedCrew = _makeProfile(
        doseRateMicroSvPerHour: 175.0,
        radiationSeverity: RadiationSeverity.critical,
        exerciseTargetReached: false,
      );

      final snapshot = SpaceWeatherSnapshot(
        fetchedAt: now,
        source: 'donki_live',
        isOfflineFallback: false,
        flares: const [],
        sepEvents: [
          SepEvent(
            sepId: 'SEP-2026-01',
            eventTime: now.subtract(const Duration(hours: 1)),
            peakFluxPfu: 1500.0,
            durationHours: 12.0,
          ),
        ],
        stormActive: true,
        alertLevel: 'warning',
        maxEventClass: 'X2.0',
        peakFluxPfu: 1500.0,
        durationHours: 12.0,
        summary: 'X2.0 flare with 1500 pfu SEP event.',
      );

      final emitted = await monitor.evaluate(
        crew: [stressedCrew],
        spaceWeather: snapshot,
        flagsByAstronaut: {
          'AST-01': {
            'leukocyte_check_scheduled': {
              'scheduled_times': ['2026-11-14T17:00:00.000Z'],
            },
            'lbnp_scheduled': {
              'due_at': '2026-11-14T16:00:00.000Z',
            },
            'space_motion_sickness': {'emesis_episodes': 2},
            'hydration': {'ml_per_day': 1200.0},
            'bone_resorption': {'elevated': true},
          },
        },
        memoriesByAstronaut: {
          'AST-01': [
            MemoryEntry(
              id: 'diary-old',
              astronautId: 'AST-01',
              kind: MemoryKind.clinicalEvent,
              summary: 'Previous voice diary check-in',
              createdAt: now.subtract(const Duration(hours: 30)),
              tags: const ['voice_diary'],
            ),
          ],
        },
        now: now,
      );

      final kinds = emitted.map((e) => e.kind).toSet();
      expect(kinds, containsAll([
        'radiation_dose_rate',
        'space_weather_sep',
        'leukocyte_check_due',
        'daily_diary_overdue',
        'exercise_target_missed',
        'lbnp_target_missed',
        'renal_stone_high_risk',
      ]));

      final radEvent = emitted.firstWhere((e) => e.kind == 'radiation_dose_rate');
      expect(radEvent.severity, ProactiveSeverity.critical);
    });

    test('deduplicates within 5-minute cooldown and allows warning->critical escalation', () async {
      var currentTime = DateTime.utc(2026, 11, 14, 12, 0);
      final notifier = InAppAgentNotifier();
      final monitor = ProactiveMonitor(
        notifier: notifier,
        cooldown: const Duration(minutes: 5),
        clock: () => currentTime,
      );

      final mildHypoxia = _makeProfile(
        spO2: 92.0,
        activityState: 'resting',
        signalQuality: 'optimal (98%)',
      );
      final first = await monitor.evaluate(crew: [mildHypoxia], now: currentTime);
      expect(first, hasLength(1));
      expect(first.first.severity, ProactiveSeverity.warning);

      // Identical reading 2 minutes later is deduplicated.
      currentTime = currentTime.add(const Duration(minutes: 2));
      final second = await monitor.evaluate(crew: [mildHypoxia], now: currentTime);
      expect(second, isEmpty);

      // Escalation warning -> critical 1 minute later bypasses cooldown.
      currentTime = currentTime.add(const Duration(minutes: 1));
      final severeHypoxia = _makeProfile(
        spO2: 86.0,
        activityState: 'resting',
        signalQuality: 'optimal (98%)',
      );
      final escalated = await monitor.evaluate(crew: [severeHypoxia], now: currentTime);
      expect(escalated, hasLength(1));
      expect(escalated.first.severity, ProactiveSeverity.critical);

      // Identical critical reading 1 minute later is suppressed within cooldown.
      currentTime = currentTime.add(const Duration(minutes: 1));
      final duplicateCritical = await monitor.evaluate(
        crew: [severeHypoxia],
        now: currentTime,
      );
      expect(duplicateCritical, isEmpty);

      // After 5 minutes from last emission, it emits again.
      currentTime = currentTime.add(const Duration(minutes: 5));
      final afterCooldown = await monitor.evaluate(
        crew: [severeHypoxia],
        now: currentTime,
      );
      expect(afterCooldown, hasLength(1));
    });
  });
}
