import 'package:astramed/features/04_mental_health/agent/mental_health_skills.dart';
import 'package:astramed/features/04_mental_health/agent/pvt_mpt_engine.dart';
import 'package:astramed/features/04_mental_health/agent/voice_diary_engine.dart';
import 'package:astramed/features/04_mental_health/models/sleep_record.dart';
import 'package:astramed/features/01_general_health/models/vitals_record.dart';
import 'package:astramed/features/02_radiation/models/radiation_dose.dart';
import 'package:astramed/features/03_microgravity/models/microgravity_data.dart';
import 'package:astramed/features/agent/domain/agent_contracts.dart';
import 'package:astramed/features/crew/models/astronaut_profile.dart';
import 'package:astramed/features/crew/presentation/providers/crew_provider.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeUiSink implements AgentUiSink {
  final List<AgentComponentEvent> emitted = [];
  final List<(String, Map<String, dynamic>)> submissions = [];

  @override
  void emit(AgentComponentEvent event) => emitted.add(event);

  @override
  void submit(String componentId, Map<String, dynamic> result) {
    submissions.add((componentId, result));
  }
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
        .where((e) {
          if (e.astronautId != astronautId) return false;
          if (kinds != null && !kinds.contains(e.kind)) return false;
          if (query != null &&
              query.isNotEmpty &&
              !e.summary.toLowerCase().contains(query.toLowerCase())) {
            return false;
          }
          return true;
        })
        .take(limit)
        .toList();
  }

  @override
  Future<List<MemoryEntry>> recentForPrompt(
    String astronautId, {
    int limit = 8,
  }) async {
    return entries.where((e) => e.astronautId == astronautId).take(limit).toList();
  }

  @override
  Future<MemoryEntry> save(MemoryEntry entry) async {
    entries.add(entry);
    return entry;
  }
}

class _FakeAuditLog implements AuditLog {
  final List<AuditEntry> entries = [];

  @override
  Future<void> append(AuditEntry entry) async {
    entries.add(entry);
  }

  @override
  Future<List<AuditEntry>> list({String? astronautId, int limit = 50}) async {
    return entries
        .where((e) => astronautId == null || e.astronautId == astronautId)
        .take(limit)
        .toList();
  }
}

class _FakeFlagsStore implements AgentFlagsStore {
  final Map<String, Map<String, Map<String, dynamic>>> _data = {};

  @override
  Future<Map<String, Map<String, dynamic>>> allForAstronaut(
    String astronautId,
  ) async {
    return Map<String, Map<String, dynamic>>.from(_data[astronautId] ?? {});
  }

  @override
  Future<Map<String, dynamic>?> getFlag(String astronautId, String key) async {
    return _data[astronautId]?[key];
  }

  @override
  Future<void> setFlag(
    String astronautId,
    String key,
    Map<String, dynamic> value,
  ) async {
    _data.putIfAbsent(astronautId, () => {})[key] = value;
  }
}

class _FakeConfirmationGate implements ConfirmationGate {
  _FakeConfirmationGate({
    required this.auditLog,
    this.nextDecision = ConfirmationDecision.confirmed,
  });

  final _FakeAuditLog auditLog;
  ConfirmationDecision nextDecision;
  final List<ConsequentialAction> requested = [];

  @override
  ConsequentialAction? get pending => null;

  @override
  Future<ConfirmationDecision> request(
    ConsequentialAction action, {
    required Future<Map<String, dynamic>> Function() onConfirmed,
  }) async {
    requested.add(action);
    if (nextDecision == ConfirmationDecision.confirmed) {
      await onConfirmed();
    }
    await auditLog.append(
      AuditEntry(
        id: 'audit-${action.id}',
        astronautId: action.astronautId,
        actionType: action.actionType,
        description: action.description,
        payload: action.payload,
        decision: nextDecision,
        timestamp: DateTime.utc(2026, 11, 14, 22, 0),
      ),
    );
    return nextDecision;
  }

  @override
  Future<Map<String, dynamic>?> resolve(
    String actionId,
    ConfirmationDecision decision, {
    String? reason,
  }) async {
    return null;
  }
}

class _FakeMedicationSafety implements MedicationSafety {
  _FakeMedicationSafety({
    this.allow = true,
    this.reasons = const [],
  });

  bool allow;
  List<String> reasons;
  final List<MedicationRequest> requests = [];

  @override
  Future<MedicationCheck> validate(MedicationRequest request) async {
    requests.add(request);
    return MedicationCheck(
      allowed: allow,
      reasons: reasons,
      batchId: allow ? 'BATCH-04' : null,
      remainingUnits: allow ? 12 : 0,
    );
  }
}

AstronautProfile _sampleAstronaut({
  String id = 'AST-01',
  double sleepHours = 7.5,
  int wakeEpisodes = 0,
  MoodLevel mood = MoodLevel.good,
}) {
  final now = DateTime.utc(2026, 11, 14, 8, 0);
  return AstronautProfile(
    id: id,
    name: 'Alex Vance',
    role: 'Commander',
    rank: 'Cmdr',
    callsign: 'ARES-1',
    avatarInitials: 'AV',
    age: 46,
    bloodType: 'O+',
    currentZone: 'Destiny',
    vitals: VitalsRecord(
      timestamp: now,
      heartRate: 68,
      systolicBP: 118,
      diastolicBP: 76,
      spO2: 99,
      bodyTemp: 36.6,
      bloodGlucose: 95,
      respiratoryRate: 14,
      capillaryRefillSeconds: 1.4,
    ),
    radiation: RadiationDose(
      timestamp: now,
      doseRateMicroSvPerHour: 50,
      cumulativeDoseMilliSv: 18,
      severity: RadiationSeverity.normal,
    ),
    sleep: SleepRecord(
      date: now,
      astronautId: id,
      sleepHours: sleepHours,
      wakeEpisodes: wakeEpisodes,
      morningMood: mood,
    ),
    exercise: ExerciseSession(
      date: now,
      deviceName: 'ARED',
      durationMinutes: 45,
      caloriesBurned: 300,
      targetReached: true,
    ),
    riskLevel: CrewRiskLevel.nominal,
    riskTitle: 'Nominal',
    riskDescription: 'All parameters nominal',
    activeAlerts: const [],
  );
}

ToolContext _makeContext({
  DateTime? now,
  double sleepHours = 7.5,
  int wakeEpisodes = 0,
  MoodLevel mood = MoodLevel.good,
  _FakeUiSink? ui,
  _FakeMemoryStore? memory,
  _FakeAuditLog? audit,
  _FakeFlagsStore? flags,
  _FakeConfirmationGate? confirm,
  _FakeMedicationSafety? medication,
}) {
  final auditLog = audit ?? _FakeAuditLog();
  final astronaut = _sampleAstronaut(
    sleepHours: sleepHours,
    wakeEpisodes: wakeEpisodes,
    mood: mood,
  );
  return ToolContext(
    astronautId: astronaut.id,
    read: <T>(Object provider) {
      if (identical(provider, crewMembersProvider)) {
        return [astronaut] as T;
      }
      throw StateError('Unexpected provider: $provider');
    },
    ui: ui ?? _FakeUiSink(),
    confirm: confirm ?? _FakeConfirmationGate(auditLog: auditLog),
    audit: auditLog,
    memory: memory ?? _FakeMemoryStore(),
    flags: flags ?? _FakeFlagsStore(),
    medication: medication ?? _FakeMedicationSafety(),
    now: now ?? DateTime.utc(2026, 11, 14, 22, 0),
  );
}

AgentTool _toolByName(List<AgentSkill> skills, String name) {
  for (final skill in skills) {
    for (final tool in skill.tools) {
      if (tool.name == name) return tool;
    }
  }
  throw StateError('Tool $name not found');
}

void main() {
  group('PvtMptEngine LRM-50 and fatigue classification', () {
    test('calculates LRM-50 median over valid trials >=100ms, counting false starts and lapses separately', () {
      // False starts (<100ms): 50, 99 -> 2 false starts
      // Valid trials (>=100ms): 220, 240, 250, 260, 520, 610 (even count: 6)
      // Median of [220, 240, 250, 260, 520, 610] = (250 + 260) / 2 = 255.0
      // Lapses (>500ms): 520, 610 -> 2 lapses => mild_fatigue
      final result = PvtMptEngine.evaluatePvt([
        50,
        99,
        610,
        240,
        220,
        520,
        260,
        250,
      ]);

      expect(result.falseStarts, 2);
      expect(result.validTrialCount, 6);
      expect(result.lapses, 2);
      expect(result.lrm50Ms, closeTo(255.0, 0.001));
      expect(result.fatigueLevel, FatigueLevel.mildFatigue);
    });

    test('classifies nominal, mild_fatigue, and significant_fatigue boundaries accurately', () {
      final nominal = PvtMptEngine.evaluatePvt([220, 240, 260, 250, 510]);
      expect(nominal.lrm50Ms, 250);
      expect(nominal.lapses, 1);
      expect(nominal.fatigueLevel, FatigueLevel.nominal);

      final mildByMedian = PvtMptEngine.evaluatePvt([265, 280, 295]);
      expect(mildByMedian.lrm50Ms, 280);
      expect(mildByMedian.lapses, 0);
      expect(mildByMedian.fatigueLevel, FatigueLevel.mildFatigue);

      final significantByMedian = PvtMptEngine.evaluatePvt([301, 310, 320]);
      expect(significantByMedian.lrm50Ms, 310);
      expect(significantByMedian.fatigueLevel, FatigueLevel.significantFatigue);

      final significantByLapses = PvtMptEngine.evaluatePvt([
        200,
        210,
        220,
        230,
        505,
        520,
        550,
      ]);
      expect(significantByLapses.lrm50Ms, 230);
      expect(significantByLapses.lapses, 3);
      expect(significantByLapses.fatigueLevel, FatigueLevel.significantFatigue);
    });

    test('evaluates MPT hit accuracy percentage and path deviation in mm', () {
      final mpt = PvtMptEngine.evaluateMpt(
        targetsHit: 18,
        totalTargets: 20,
        pathDeviationsMm: [1.5, 2.5, 2.0, 4.0],
      );
      expect(mpt.hitAccuracyPercent, closeTo(90.0, 0.001));
      expect(mpt.pathDeviationMm, closeTo(2.5, 0.001));
      expect(mpt.motorStatus, MotorStatus.nominal);
    });
  });

  group('Pharmacological calibration (stimulant & hypnotic rules)', () {
    test('rejects stimulant compensation when LRM-50 is nominal or sedative history is absent', () async {
      final skills = mentalHealthSkills();
      final checkStimulant = _toolByName(skills, 'check_stimulant_dose');

      final flagsWithSedative = _FakeFlagsStore();
      await flagsWithSedative.setFlag('AST-01', 'recent_sedative_use', {
        'medication': 'promethazine',
        'timestamp': DateTime.utc(2026, 11, 14, 18, 0).toIso8601String(),
      });
      final confirm1 = _FakeConfirmationGate(auditLog: _FakeAuditLog());
      final ctxNominal = _makeContext(
        flags: flagsWithSedative,
        confirm: confirm1,
      );

      final nominalResult = await checkStimulant.call({
        'lrm50_ms': 240.0,
        'lapses': 0,
      }, ctxNominal);
      expect(nominalResult.ok, isTrue);
      expect(nominalResult.data['authorized'], isFalse);
      expect(confirm1.requested, isEmpty);

      final confirm2 = _FakeConfirmationGate(auditLog: _FakeAuditLog());
      final ctxNoSedative = _makeContext(confirm: confirm2);
      final noSedativeResult = await checkStimulant.call({
        'lrm50_ms': 340.0,
        'lapses': 3,
      }, ctxNoSedative);
      expect(noSedativeResult.ok, isTrue);
      expect(noSedativeResult.data['authorized'], isFalse);
      expect(confirm2.requested, isEmpty);
    });

    test('rejects stimulant compensation when MedicationSafety fails and skips confirmation', () async {
      final flags = _FakeFlagsStore();
      await flags.setFlag('AST-01', 'recent_sedative_use', {
        'medication': 'promethazine',
        'timestamp': DateTime.utc(2026, 11, 14, 18, 0).toIso8601String(),
      });
      final audit = _FakeAuditLog();
      final confirm = _FakeConfirmationGate(auditLog: audit);
      final medSafety = _FakeMedicationSafety(
        allow: false,
        reasons: ['Insufficient modafinil inventory'],
      );
      final ctx = _makeContext(
        flags: flags,
        audit: audit,
        confirm: confirm,
        medication: medSafety,
      );

      final checkStimulant = _toolByName(mentalHealthSkills(), 'check_stimulant_dose');
      final res = await checkStimulant.call({
        'lrm50_ms': 330.0,
        'lapses': 3,
      }, ctx);

      expect(res.ok, isTrue);
      expect(res.data['authorized'], isFalse);
      expect(medSafety.requests, hasLength(1));
      expect(confirm.requested, isEmpty);
    });

    test('authorizes stimulant dose only after antihistamine + elevated LRM-50 + MedicationSafety + ConfirmationGate', () async {
      final memory = _FakeMemoryStore();
      await memory.save(
        MemoryEntry(
          id: 'mem-sed-1',
          astronautId: 'AST-01',
          kind: MemoryKind.clinicalEvent,
          summary: 'Administered promethazine 25mg IM for space motion sickness',
          createdAt: DateTime.utc(2026, 11, 14, 16, 0),
          tags: const ['antihistamine', 'promethazine', 'sedative'],
        ),
      );
      final audit = _FakeAuditLog();
      final flags = _FakeFlagsStore();
      final confirm = _FakeConfirmationGate(auditLog: audit);
      final medSafety = _FakeMedicationSafety(allow: true);
      final ctx = _makeContext(
        memory: memory,
        audit: audit,
        flags: flags,
        confirm: confirm,
        medication: medSafety,
      );

      final checkStimulant = _toolByName(mentalHealthSkills(), 'check_stimulant_dose');
      final res = await checkStimulant.call({
        'lrm50_ms': 325.0,
        'lapses': 4,
      }, ctx);

      expect(res.ok, isTrue);
      expect(res.data['authorized'], isTrue);
      expect(res.data['medication'], 'modafinil');
      expect(res.data['dose_mg'], 100.0);
      expect(medSafety.requests, hasLength(1));
      expect(confirm.requested, hasLength(1));
      final flag = await flags.getFlag('AST-01', 'stimulant_compensation_authorized');
      expect(flag, isNotNull);
    });

    test('does not authorize or set flag when crew rejects stimulant confirmation', () async {
      final flags = _FakeFlagsStore();
      await flags.setFlag('AST-01', 'recent_sedative_use', {
        'medication': 'promethazine',
        'timestamp': DateTime.utc(2026, 11, 14, 18, 0).toIso8601String(),
      });
      final audit = _FakeAuditLog();
      final confirm = _FakeConfirmationGate(
        auditLog: audit,
        nextDecision: ConfirmationDecision.rejected,
      );
      final ctx = _makeContext(flags: flags, audit: audit, confirm: confirm);

      final checkStimulant = _toolByName(mentalHealthSkills(), 'check_stimulant_dose');
      final res = await checkStimulant.call({
        'lrm50_ms': 340.0,
        'lapses': 4,
      }, ctx);

      expect(res.ok, isTrue);
      expect(res.data['authorized'], isFalse);
      expect(confirm.requested, hasLength(1));
      expect(await flags.getFlag('AST-01', 'stimulant_compensation_authorized'), isNull);
    });

    test('compute_lrm50 tool fails gracefully when only false starts are provided', () async {
      final ctx = _makeContext();
      final computeTool = _toolByName(mentalHealthSkills(), 'compute_lrm50');
      final res = await computeTool.call({
        'reaction_times_ms': [45, 80, 99],
      }, ctx);
      expect(res.ok, isFalse);
      expect(res.error, isNotNull);
    });

    test('records and audits first hypnotic dose, then deterministically blocks second night dose within 8h', () async {
      final audit = _FakeAuditLog();
      final flags = _FakeFlagsStore();
      final confirm = _FakeConfirmationGate(auditLog: audit);
      final medSafety = _FakeMedicationSafety(allow: true);
      final checkHypnotic = _toolByName(mentalHealthSkills(), 'check_hypnotic_dose');

      final t0 = DateTime.utc(2026, 11, 14, 22, 0);
      final ctxFirst = _makeContext(
        now: t0,
        audit: audit,
        flags: flags,
        confirm: confirm,
        medication: medSafety,
      );

      final firstRes = await checkHypnotic.call({
        'medication': 'zolpidem',
        'dose_mg': 5.0,
      }, ctxFirst);

      expect(firstRes.ok, isTrue);
      expect(firstRes.data['authorized'], isTrue);
      expect(firstRes.data['secondNightDoseBlocked'], isFalse);
      expect(medSafety.requests, hasLength(1));
      expect(confirm.requested, hasLength(1));
      expect(audit.entries, hasLength(1));
      expect(audit.entries.first.decision, ConfirmationDecision.confirmed);
      final recordedFlag = await flags.getFlag('AST-01', 'last_hypnotic_dose');
      expect(recordedFlag, isNotNull);

      // Attempt second dose 3 hours later in the same sleep window
      final ctxSecond = _makeContext(
        now: t0.add(const Duration(hours: 3)),
        audit: audit,
        flags: flags,
        confirm: confirm,
        medication: medSafety,
      );

      final secondRes = await checkHypnotic.call({
        'medication': 'zolpidem',
        'dose_mg': 5.0,
      }, ctxSecond);

      expect(secondRes.ok, isTrue);
      expect(secondRes.data['authorized'], isFalse);
      expect(secondRes.data['secondNightDoseBlocked'], isTrue);
      // Must NOT ask ConfirmationGate or MedicationSafety again
      expect(confirm.requested, hasLength(1));
      expect(medSafety.requests, hasLength(1));
      // Must log the deterministic block to AuditLog
      expect(audit.entries, hasLength(2));
      expect(audit.entries.last.decision, ConfirmationDecision.rejected);
      expect(audit.entries.last.payload['secondNightDoseBlocked'], isTrue);

      // Next sleep window (>8h later) is allowed again
      final ctxNextNight = _makeContext(
        now: t0.add(const Duration(hours: 9)),
        audit: audit,
        flags: flags,
        confirm: confirm,
        medication: medSafety,
      );
      final nextRes = await checkHypnotic.call({
        'medication': 'zolpidem',
        'dose_mg': 5.0,
      }, ctxNextNight);
      expect(nextRes.data['authorized'], isTrue);
      expect(nextRes.data['secondNightDoseBlocked'], isFalse);
    });
  });

  group('VoiceDiaryEngine & diary skill', () {
    test('detects stress, isolation, conflict, and Sopite markers across English & Spanish + cadence central fatigue', () async {
      final memory = _FakeMemoryStore();
      final ui = _FakeUiSink();
      final ctx = _makeContext(
        sleepHours: 5.0,
        wakeEpisodes: 4,
        mood: MoodLevel.fatigued,
        memory: memory,
        ui: ui,
      );

      final skills = mentalHealthSkills();
      final analyzeDiary = _toolByName(skills, 'analyze_diary');
      final getRecs = _toolByName(skills, 'get_recommendations');

      final analysisRes = await analyzeDiary.call({
        'transcript':
            'Me siento muy estresado y aislado hoy. Tuve un conflicto con mi compañero, '
            'estoy cansado todo el día, sin ganas, y bostezando mucho sin náuseas.',
        'words_per_minute': 88.0,
        'pause_ratio': 0.36,
        'mean_pause_ms': 780.0,
        'pitch_monotony': 0.82,
      }, ctx);

      expect(analysisRes.ok, isTrue);
      final markers = (analysisRes.data['semantic_markers'] as List).cast<String>();
      expect(markers, containsAll(['stress', 'isolation', 'interpersonal_conflict', 'sopite_syndrome']));
      expect(analysisRes.data['central_fatigue_detected'], isTrue);
      expect(analysisRes.data['sleep_debt_hours'], greaterThan(0));

      // Clinical event saved in MemoryStore
      expect(memory.entries, hasLength(1));
      expect(memory.entries.first.kind, MemoryKind.clinicalEvent);
      expect(memory.entries.first.astronautId, 'AST-01');

      // Adaptive recommendations generated and UI emitted
      final recsRes = await getRecs.call({
        'semantic_markers': markers,
        'central_fatigue_detected': true,
        'sleep_hours': 5.0,
      }, ctx);

      expect(recsRes.ok, isTrue);
      expect(
        recsRes.uiEvents.whereType<ShowComponentEvent>().map((e) => e.id),
        contains(ComponentIds.recommendations),
      );
      final recs = (recsRes.data['recommendations'] as List)
          .cast<Map<String, dynamic>>();
      final categories = recs.map((r) => r['category'] as String).toSet();
      expect(
        categories,
        containsAll([
          'sleep_schedule',
          'nap_window',
          'nutrition_hydration',
          'disconnection_social',
        ]),
      );
    });

    test('UI tools emit typed ViewModels that round-trip via fromProps', () async {
      final ui = _FakeUiSink();
      final ctx = _makeContext(ui: ui);
      final skills = mentalHealthSkills();

      final pvtRes = await _toolByName(skills, 'start_pvt').call({}, ctx);
      final mptRes = await _toolByName(skills, 'start_mpt').call({}, ctx);
      final diaryRes = await _toolByName(skills, 'start_diary').call({}, ctx);

      final pvtEvent = pvtRes.uiEvents.single as ShowComponentEvent;
      final mptEvent = mptRes.uiEvents.single as ShowComponentEvent;
      final diaryEvent = diaryRes.uiEvents.single as ShowComponentEvent;

      expect(pvtEvent.id, ComponentIds.pvtTest);
      expect(mptEvent.id, ComponentIds.mptTest);
      expect(diaryEvent.id, ComponentIds.diaryRecorder);

      expect(PvtTestViewModel.fromProps(pvtEvent.props).componentId, ComponentIds.pvtTest);
      expect(MptTestViewModel.fromProps(mptEvent.props).componentId, ComponentIds.mptTest);
      expect(DiaryRecorderViewModel.fromProps(diaryEvent.props).componentId, ComponentIds.diaryRecorder);

      final recsRes = await _toolByName(skills, 'get_recommendations').call({}, ctx);
      final recEvent = recsRes.uiEvents.single as ShowComponentEvent;
      expect(
        RecommendationsViewModel.fromProps(recEvent.props).componentId,
        ComponentIds.recommendations,
      );
      expect(
        () => PvtTestViewModel.fromProps(const {}),
        throwsFormatException,
      );
    });

    test('VoiceDiaryEngine classifies nominal transcript and cadence without false central fatigue', () {
      final sleep = SleepRecord(
        date: DateTime.utc(2026, 11, 14, 8),
        sleepHours: 7.8,
        wakeEpisodes: 0,
        morningMood: MoodLevel.great,
      );
      final nominal = VoiceDiaryEngine.analyze(
        transcript: 'Slept well, finished habitat maintenance with the crew and feel energized.',
        cadence: const SpeechCadenceMetrics(
          wordsPerMinute: 138,
          pauseRatio: 0.14,
          meanPauseMs: 320,
          pitchMonotony: 0.28,
        ),
        sleepRecord: sleep,
      );

      expect(nominal.semanticMarkers, isEmpty);
      expect(nominal.centralFatigueDetected, isFalse);
      expect(nominal.riskLevel, 'nominal');
    });

    test('offline DeterministicFlow runs daily diary check-in and saves clinical event', () async {
      final memory = _FakeMemoryStore();
      final ctx = _makeContext(sleepHours: 5.5, memory: memory);
      final diarySkill = mentalHealthSkills().firstWhere((s) => s.id == 'diary');
      final flow = diarySkill.offlineFlow;
      expect(flow, isNotNull);

      final step1 = await flow!.start(ctx);
      expect(step1.isTerminal, isFalse);
      expect(
        step1.uiEvents.whereType<ShowComponentEvent>().map((e) => e.id),
        contains(ComponentIds.diaryRecorder),
      );

      final step2 = await flow.advance(
        'Feeling overwhelmed, isolated, and yawning with apathy all day',
        ctx,
      );
      expect(step2.isTerminal, isFalse);

      final terminal = await flow.advance('5.5', ctx);
      expect(terminal.isTerminal, isTrue);
      expect(terminal.verdict, isNotNull);
      expect(
        terminal.uiEvents.whereType<ShowComponentEvent>().map((e) => e.id),
        contains(ComponentIds.recommendations),
      );
      expect(memory.entries, hasLength(1));
      expect(memory.entries.first.kind, MemoryKind.clinicalEvent);
    });
  });
}
