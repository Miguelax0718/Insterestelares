import 'package:astramed/features/01_general_health/models/vitals_record.dart';
import 'package:astramed/features/02_radiation/models/radiation_dose.dart';
import 'package:astramed/features/03_microgravity/agent/exercise_guidance_engine.dart';
import 'package:astramed/features/03_microgravity/agent/graybiel_engine.dart';
import 'package:astramed/features/03_microgravity/agent/microgravity_skills.dart';
import 'package:astramed/features/03_microgravity/agent/procedures_engine.dart';
import 'package:astramed/features/03_microgravity/agent/sans_engine.dart';
import 'package:astramed/features/03_microgravity/models/microgravity_data.dart';
import 'package:astramed/features/04_mental_health/models/sleep_record.dart';
import 'package:astramed/features/agent/domain/agent_contracts.dart';
import 'package:astramed/features/crew/models/astronaut_profile.dart';
import 'package:astramed/features/crew/presentation/providers/crew_provider.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeUiSink implements AgentUiSink {
  final List<AgentComponentEvent> events = [];
  final List<(String, Map<String, dynamic>)> submissions = [];

  @override
  void emit(AgentComponentEvent event) => events.add(event);

  @override
  void submit(String componentId, Map<String, dynamic> result) {
    submissions.add((componentId, result));
  }
}

class _FakeFlagsStore implements AgentFlagsStore {
  final Map<String, Map<String, Map<String, dynamic>>> _flags = {};

  @override
  Future<Map<String, Map<String, dynamic>>> allForAstronaut(
    String astronautId,
  ) async {
    return Map<String, Map<String, dynamic>>.from(_flags[astronautId] ?? {});
  }

  @override
  Future<Map<String, dynamic>?> getFlag(String astronautId, String key) async {
    return _flags[astronautId]?[key];
  }

  @override
  Future<void> setFlag(
    String astronautId,
    String key,
    Map<String, dynamic> value,
  ) async {
    _flags.putIfAbsent(astronautId, () => {})[key] = value;
  }
}

class _FakeAuditLog implements AuditLog {
  final List<AuditEntry> entries = [];

  @override
  Future<void> append(AuditEntry entry) async => entries.add(entry);

  @override
  Future<List<AuditEntry>> list({String? astronautId, int limit = 50}) async {
    final filtered = astronautId == null
        ? entries
        : entries.where((e) => e.astronautId == astronautId).toList();
    return filtered.take(limit).toList();
  }
}

class _FakeConfirmationGate implements ConfirmationGate {
  _FakeConfirmationGate({
    required this.decision,
    required this.auditLog,
  });

  final ConfirmationDecision decision;
  final _FakeAuditLog auditLog;
  ConsequentialAction? lastAction;
  int requestCount = 0;

  @override
  ConsequentialAction? get pending => null;

  @override
  Future<ConfirmationDecision> request(
    ConsequentialAction action, {
    required Future<Map<String, dynamic>> Function() onConfirmed,
  }) async {
    requestCount++;
    lastAction = action;
    if (decision == ConfirmationDecision.confirmed) {
      await onConfirmed();
    }
    await auditLog.append(
      AuditEntry(
        id: action.id,
        astronautId: action.astronautId,
        actionType: action.actionType,
        description: action.description,
        payload: action.payload,
        decision: decision,
        timestamp: DateTime.utc(2026, 11, 14, 12, 0),
      ),
    );
    return decision;
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

class _FakeMemoryStore implements MemoryStore {
  @override
  Future<List<MemoryEntry>> recall(
    String astronautId, {
    String? query,
    Set<MemoryKind>? kinds,
    int limit = 10,
  }) async {
    return const [];
  }

  @override
  Future<List<MemoryEntry>> recentForPrompt(
    String astronautId, {
    int limit = 8,
  }) async {
    return const [];
  }

  @override
  Future<MemoryEntry> save(MemoryEntry entry) async => entry;
}

class _FakeMedicationSafety implements MedicationSafety {
  _FakeMedicationSafety({required this.result});

  final MedicationCheck result;
  MedicationRequest? lastRequest;

  @override
  Future<MedicationCheck> validate(MedicationRequest request) async {
    lastRequest = request;
    return result;
  }
}

AstronautProfile _sampleAstronaut({
  String id = 'AST-01',
  double heartRate = 128,
  double systolicBP = 132,
  double spO2 = 97,
  String deviceName = 'ARED',
  int durationMinutes = 35,
  bool targetReached = false,
}) {
  final now = DateTime.utc(2026, 11, 14, 12);
  return AstronautProfile(
    id: id,
    name: 'Alex Vance',
    role: 'Commander',
    rank: 'Cmdr.',
    callsign: 'VANCE-01',
    avatarInitials: 'AV',
    age: 38,
    bloodType: 'O+',
    currentZone: 'Habitat',
    vitals: VitalsRecord(
      timestamp: now,
      astronautId: id,
      heartRate: heartRate,
      systolicBP: systolicBP,
      diastolicBP: 82,
      spO2: spO2,
      bodyTemp: 36.8,
      bloodGlucose: 95,
    ),
    radiation: RadiationDose(
      timestamp: now,
      astronautId: id,
      doseRateMicroSvPerHour: 24,
      cumulativeDoseMilliSv: 18,
      severity: RadiationSeverity.normal,
    ),
    sleep: SleepRecord(
      date: now,
      astronautId: id,
      sleepHours: 7.2,
      wakeEpisodes: 1,
      morningMood: MoodLevel.good,
    ),
    exercise: ExerciseSession(
      date: now,
      astronautId: id,
      deviceName: deviceName,
      durationMinutes: durationMinutes,
      caloriesBurned: 310,
      targetReached: targetReached,
    ),
    riskLevel: CrewRiskLevel.nominal,
    riskTitle: 'Nominal',
    riskDescription: 'All nominal',
    activeAlerts: const [],
  );
}

ToolContext _makeContext({
  String astronautId = 'AST-01',
  ConfirmationDecision confirmDecision = ConfirmationDecision.confirmed,
  MedicationCheck? medCheck,
  List<AstronautProfile>? crew,
  _FakeUiSink? uiSink,
  _FakeFlagsStore? flagsStore,
  _FakeAuditLog? auditLog,
}) {
  final ui = uiSink ?? _FakeUiSink();
  final flags = flagsStore ?? _FakeFlagsStore();
  final audit = auditLog ?? _FakeAuditLog();
  final profiles = crew ?? [_sampleAstronaut(id: astronautId)];

  return ToolContext(
    astronautId: astronautId,
    read: <T>(Object provider) {
      if (identical(provider, crewMembersProvider)) {
        return profiles as T;
      }
      if (identical(provider, selectedAstronautProvider)) {
        return profiles.firstWhere(
              (p) => p.id == astronautId,
              orElse: () => profiles.first,
            )
            as T;
      }
      throw StateError('Unexpected provider: $provider');
    },
    ui: ui,
    confirm: _FakeConfirmationGate(decision: confirmDecision, auditLog: audit),
    audit: audit,
    memory: _FakeMemoryStore(),
    flags: flags,
    medication: _FakeMedicationSafety(
      result:
          medCheck ??
          const MedicationCheck(
            allowed: true,
            reasons: [],
            batchId: 'LOT-PROM-01',
            remainingUnits: 8,
          ),
    ),
    now: DateTime.utc(2026, 11, 14, 12, 0),
  );
}

AgentSkill _findSkill(List<AgentSkill> skills, String id) {
  return skills.firstWhere((s) => s.id == id);
}

AgentTool _findTool(List<AgentSkill> skills, String skillId, String toolName) {
  return _findSkill(skills, skillId).tools.firstWhere((t) => t.name == toolName);
}

void main() {
  group('GraybielEngine', () {
    test('scores across all Graybiel categories (0, 2, 6, 12, 18)', () {
      final score0 = GraybielEngine.evaluate(const {});
      expect(score0.totalScore, 0);
      expect(score0.category, GraybielCategory.none);
      expect(score0.evaBlockedRecommended, isFalse);
      expect(score0.gastricStasisSuspected, isFalse);
      expect(score0.recommendedRoute, 'oral');

      final score2 = GraybielEngine.evaluate(const {
        GraybielSymptom.pallor: GraybielLevel.minor,
      });
      expect(score2.totalScore, 2);
      expect(score2.category, GraybielCategory.minimal);
      expect(score2.evaBlockedRecommended, isFalse);

      final score6 = GraybielEngine.evaluate(const {
        GraybielSymptom.nausea: GraybielLevel.moderate,
        GraybielSymptom.pallor: GraybielLevel.minor,
      });
      expect(score6.totalScore, 6);
      expect(score6.category, GraybielCategory.moderateMalaise);
      expect(score6.evaBlockedRecommended, isTrue);
      expect(score6.gastricStasisSuspected, isFalse);
      expect(score6.recommendedRoute, 'oral');

      final score12 = GraybielEngine.evaluate(const {
        GraybielSymptom.nausea: GraybielLevel.severe,
        GraybielSymptom.drowsiness: GraybielLevel.moderate,
      });
      expect(score12.totalScore, 12);
      expect(score12.category, GraybielCategory.severeMalaise);
      expect(score12.evaBlockedRecommended, isTrue);
      expect(score12.gastricStasisSuspected, isTrue);
      expect(score12.recommendedRoute, 'intranasal');

      final score18 = GraybielEngine.evaluate(
        const {
          GraybielSymptom.pallor: GraybielLevel.minor,
        },
        emesis: true,
      );
      expect(score18.totalScore, 18);
      expect(score18.category, GraybielCategory.frankSickness);
      expect(score18.evaBlockedRecommended, isTrue);
      expect(score18.gastricStasisSuspected, isTrue);
      expect(score18.recommendedRoute, 'intranasal');
    });

    test('offline DeterministicFlow runs start -> 7 advances -> terminal verdict', () async {
      final skills = microgravitySkills();
      final graybielSkill = _findSkill(skills, 'graybiel');
      final flow = graybielSkill.offlineFlow!;
      final ui = _FakeUiSink();
      final ctx = _makeContext(uiSink: ui);

      final first = await flow.start(ctx);
      expect(first.isTerminal, isFalse);
      expect(first.options, containsAll(['none', 'minimal', 'minor', 'moderate', 'severe']));
      expect(first.uiEvents.single, isA<ShowComponentEvent>());

      final inputs = [
        'severe', // nausea -> 8
        'moderate', // pallor -> 4
        'none', // cold_sweating -> 0
        'none', // salivation -> 0
        'none', // drowsiness -> 0
        'none', // headache -> 0
        'none', // dizziness -> 0
      ];

      DeterministicStep step = first;
      for (final input in inputs) {
        step = await flow.advance(input, ctx);
      }

      expect(step.isTerminal, isTrue);
      expect(step.verdict, isNotNull);
      expect(step.verdict!['total_score'], 12);
      expect(step.verdict!['category'], 'severe_malaise');
      expect(step.verdict!['eva_blocked_recommended'], isTrue);
      expect(step.verdict!['gastric_stasis_suspected'], isTrue);
      expect(step.verdict!['recommended_route'], 'intranasal');
    });
  });

  group('Graybiel tools and medication route confirmation', () {
    test('start_graybiel -> record_graybiel_answer -> score_graybiel emits UI and scores', () async {
      final skills = microgravitySkills();
      final ctx = _makeContext();

      final startTool = _findTool(skills, 'graybiel', 'start_graybiel');
      final startRes = await startTool.call({}, ctx);
      expect(startRes.ok, isTrue);
      expect(startRes.uiEvents.first, isA<ShowComponentEvent>());
      expect(
        (startRes.uiEvents.first as ShowComponentEvent).id,
        ComponentIds.graybielQuestionnaire,
      );

      final recTool = _findTool(skills, 'graybiel', 'record_graybiel_answer');
      await recTool.call({'symptom': 'nausea', 'level': 'moderate'}, ctx);
      await recTool.call({'symptom': 'pallor', 'level': 'minor'}, ctx);

      final scoreTool = _findTool(skills, 'graybiel', 'score_graybiel');
      final scoreRes = await scoreTool.call({}, ctx);
      expect(scoreRes.ok, isTrue);
      expect(scoreRes.data['total_score'], 6);
      expect(scoreRes.data['category'], 'moderate_malaise');
      expect(scoreRes.data['eva_blocked_recommended'], isTrue);
    });

    test('change_medication_route validates medication, requires confirmation, and writes flags', () async {
      final skills = microgravitySkills();
      final flags = _FakeFlagsStore();
      final audit = _FakeAuditLog();
      final ctx = _makeContext(
        flagsStore: flags,
        auditLog: audit,
        confirmDecision: ConfirmationDecision.confirmed,
      );

      await _findTool(skills, 'graybiel', 'record_graybiel_answer').call(
        {'symptom': 'nausea', 'level': 'severe'},
        ctx,
      );
      await _findTool(skills, 'graybiel', 'score_graybiel').call({}, ctx);

      final changeTool = _findTool(skills, 'graybiel', 'change_medication_route');
      expect(changeTool.effect, ToolEffect.consequential);

      final res = await changeTool.call({
        'medication': 'promethazine',
        'dose_mg': 25,
        'route': 'intranasal',
      }, ctx);

      expect(res.ok, isTrue);
      expect(res.data['confirmed'], isTrue);
      expect(audit.entries, hasLength(1));
      expect(audit.entries.single.decision, ConfirmationDecision.confirmed);

      final routeFlag = await flags.getFlag('AST-01', 'medication_route_override');
      expect(routeFlag?['route'], 'intranasal');
      final stasisFlag = await flags.getFlag('AST-01', 'eva_gastric_stasis');
      expect(stasisFlag?['suspected'], isTrue);
      final evaFlag = await flags.getFlag('AST-01', 'eva_blocked_by_graybiel');
      expect(evaFlag?['blocked'], isTrue);
    });

    test('change_medication_route rejects disallowed medication before confirmation', () async {
      final skills = microgravitySkills();
      final flags = _FakeFlagsStore();
      final audit = _FakeAuditLog();
      final ctx = _makeContext(
        flagsStore: flags,
        auditLog: audit,
        medCheck: const MedicationCheck(
          allowed: false,
          reasons: ['Astronaut allergic to promethazine'],
          suggestedAlternativeRoute: 'intramuscular',
        ),
      );

      final changeTool = _findTool(skills, 'graybiel', 'change_medication_route');
      final res = await changeTool.call({
        'medication': 'promethazine',
        'dose_mg': 25,
        'route': 'intranasal',
      }, ctx);

      expect(res.ok, isFalse);
      expect(audit.entries, isEmpty);
      expect(await flags.getFlag('AST-01', 'medication_route_override'), isNull);
    });

    test('change_medication_route does not write flags when crew rejects confirmation', () async {
      final skills = microgravitySkills();
      final flags = _FakeFlagsStore();
      final audit = _FakeAuditLog();
      final ctx = _makeContext(
        flagsStore: flags,
        auditLog: audit,
        confirmDecision: ConfirmationDecision.rejected,
      );

      final changeTool = _findTool(skills, 'graybiel', 'change_medication_route');
      final res = await changeTool.call({
        'medication': 'ondansetron',
        'dose_mg': 4,
        'route': 'intramuscular',
      }, ctx);

      expect(res.ok, isTrue);
      expect(res.data['confirmed'], isFalse);
      expect(audit.entries.single.decision, ConfirmationDecision.rejected);
      expect(await flags.getFlag('AST-01', 'medication_route_override'), isNull);
    });
  });

  group('SANS evaluation and goggle assignment', () {
    test('classifies nominal, borderline, grade_1, and grade_2 with hyperopic shift & pair assignment', () {
      final nominal = SansEngine.evaluate(nearFocusCm: 25);
      expect(nominal.hyperopicShiftDiopters, 0.0);
      expect(nominal.grade, SansGrade.nominal);
      expect(nominal.recommendedGoggles, isNull);

      final borderline = SansEngine.evaluate(nearFocusCm: 40);
      expect(borderline.hyperopicShiftDiopters, 0.75);
      expect(borderline.grade, SansGrade.borderline);
      expect(borderline.recommendedGoggles?.label, 'PAIR-A +0.75D');

      final grade1 = SansEngine.evaluate(nearFocusCm: 50);
      expect(grade1.hyperopicShiftDiopters, 1.25);
      expect(grade1.grade, SansGrade.grade1);
      expect(grade1.recommendedGoggles?.label, 'PAIR-B +1.25D');

      final grade2Contrast = SansEngine.evaluate(
        nearFocusCm: 60,
        contrastLogCs: 1.20,
      );
      expect(grade2Contrast.hyperopicShiftDiopters, 1.75);
      expect(grade2Contrast.grade, SansGrade.grade2);
      expect(grade2Contrast.recommendedGoggles?.label, 'PAIR-C +1.75D');

      final grade2Grid = SansEngine.evaluate(
        nearFocusCm: 38,
        gridMetamorphopsia: true,
      );
      expect(grade2Grid.grade, SansGrade.grade2);
      expect(grade2Grid.recommendedGoggles?.label, 'PAIR-A +0.75D');
    });

    test('start_sans_test emits component events and assign_goggles requires confirmation', () async {
      final skills = microgravitySkills();
      final flags = _FakeFlagsStore();
      final audit = _FakeAuditLog();
      final ctx = _makeContext(flagsStore: flags, auditLog: audit);

      final startRes = await _findTool(skills, 'sans', 'start_sans_test').call(
        {'test': 'sans_grid'},
        ctx,
      );
      expect(startRes.ok, isTrue);
      final gridEvent = startRes.uiEvents.single as ShowComponentEvent;
      expect(gridEvent.id, ComponentIds.sansGrid);
      expect(SansGridViewModel.fromProps(gridEvent.props).astronautId, 'AST-01');

      final contrastRes = await _findTool(skills, 'sans', 'start_sans_test').call(
        {'test': 'sans_contrast'},
        ctx,
      );
      final contrastEvent = contrastRes.uiEvents.single as ShowComponentEvent;
      expect(contrastEvent.id, ComponentIds.sansContrast);
      expect(SansContrastViewModel.fromProps(contrastEvent.props).astronautId, 'AST-01');

      final focusRes = await _findTool(skills, 'sans', 'start_sans_test').call(
        {'test': 'sans_focus'},
        ctx,
      );
      final focusEvent = focusRes.uiEvents.single as ShowComponentEvent;
      expect(focusEvent.id, ComponentIds.sansFocus);
      expect(SansFocusViewModel.fromProps(focusEvent.props).astronautId, 'AST-01');

      final classifyRes = await _findTool(skills, 'sans', 'classify_sans').call({
        'near_focus_cm': 52,
        'grid_metamorphopsia': false,
        'contrast_log_cs': 1.75,
      }, ctx);
      expect(classifyRes.ok, isTrue);
      expect(classifyRes.data['grade'], 'grade_1');
      expect(classifyRes.data['recommended_goggles'], 'PAIR-B +1.25D');

      final assignTool = _findTool(skills, 'sans', 'assign_goggles');
      expect(assignTool.effect, ToolEffect.consequential);
      final assignRes = await assignTool.call({'pair': 'PAIR-B +1.25D'}, ctx);
      expect(assignRes.ok, isTrue);
      expect(assignRes.data['confirmed'], isTrue);
      expect(audit.entries, hasLength(1));

      final gogglesFlag = await flags.getFlag('AST-01', 'assigned_goggles');
      expect(gogglesFlag?['pair'], 'PAIR-B +1.25D');
    });
  });

  group('Exercise guidance', () {
    test('flags unsafe vitals (SpO2 < 92, HR > 175, SBP > 180) vs nominal response', () async {
      final skills = microgravitySkills();
      final tool = _findTool(skills, 'exercise', 'get_exercise_guidance');

      final nominalCtx = _makeContext(
        crew: [
          _sampleAstronaut(
            heartRate: 138,
            systolicBP: 140,
            spO2: 97,
            deviceName: 'ARED',
          ),
        ],
      );
      final nominalRes = await tool.call({}, nominalCtx);
      expect(nominalRes.ok, isTrue);
      expect(nominalRes.data['unsafe_vitals'], isFalse);
      expect(nominalRes.data['status'], 'nominal_active');
      final monitorEvent = nominalRes.uiEvents.single as ShowComponentEvent;
      expect(monitorEvent.id, ComponentIds.exerciseMonitor);
      expect(
        ExerciseMonitorViewModel.fromProps(monitorEvent.props).result.status,
        ExerciseSafetyStatus.nominalActive,
      );

      final unsafeCtx = _makeContext(
        crew: [
          _sampleAstronaut(
            heartRate: 182,
            systolicBP: 188,
            spO2: 90,
            deviceName: 'T2 Treadmill',
          ),
        ],
      );
      final unsafeRes = await tool.call({}, unsafeCtx);
      expect(unsafeRes.ok, isTrue);
      expect(unsafeRes.data['unsafe_vitals'], isTrue);
      expect(unsafeRes.data['status'], 'unsafe_abort');
      expect(unsafeRes.data['alerts'] as List, hasLength(3));
    });
  });

  group('LBNP & Ultrasound procedures', () {
    test('LBNP ramp enforces gradual decompression from -20 mmHg through -10 mmHg before 0', () async {
      final skills = microgravitySkills();
      final ctx = _makeContext();

      final startTool = _findTool(skills, 'procedures', 'start_lbnp');
      final advTool = _findTool(skills, 'procedures', 'advance_lbnp');
      final abortTool = _findTool(skills, 'procedures', 'abort_lbnp');

      var res = await startTool.call({}, ctx);
      expect(res.data['phase'], 'prep_sealCheck');
      expect(res.data['pressure_mmhg'], 0);
      final lbnpEvent = res.uiEvents.single as ShowComponentEvent;
      expect(lbnpEvent.id, ComponentIds.lbnpRamp);
      expect(
        LbnpRampViewModel.fromProps(lbnpEvent.props).state.phase,
        LbnpPhase.prepSealCheck,
      );

      res = await advTool.call({'seal_checked': true}, ctx);
      expect(res.data['phase'], 'step_minus10_3min');
      expect(res.data['pressure_mmhg'], -10);

      res = await advTool.call({}, ctx);
      expect(res.data['phase'], 'target_minus20_15min');
      expect(res.data['pressure_mmhg'], -20);

      // Trying to jump directly from -20 to 0 is rejected.
      final jumpRes = await advTool.call({'target_pressure_mmhg': 0}, ctx);
      expect(jumpRes.ok, isFalse);

      // Non-emergency abort at -20 mmHg must step through -10 mmHg first.
      res = await abortTool.call({'systolic_bp': 110, 'hr_drop_bpm': 4}, ctx);
      expect(res.ok, isTrue);
      expect(res.data['phase'], 'gradual_decompression_minus10_3min');
      expect(res.data['pressure_mmhg'], -10);

      // Advancing from the intermediate -10 mmHg abort step completes release to 0.
      res = await advTool.call({}, ctx);
      expect(res.data['phase'], 'aborted');
      expect(res.data['pressure_mmhg'], 0);
    });

    test('LBNP normal completion goes through -10 mmHg and 0_2min before completed', () async {
      final skills = microgravitySkills();
      final ctx = _makeContext();
      final startTool = _findTool(skills, 'procedures', 'start_lbnp');
      final advTool = _findTool(skills, 'procedures', 'advance_lbnp');

      await startTool.call({}, ctx);
      await advTool.call({'seal_checked': true}, ctx); // -10
      await advTool.call({}, ctx); // -20
      var res = await advTool.call({}, ctx);
      expect(res.data['phase'], 'gradual_decompression_minus10_3min');
      expect(res.data['pressure_mmhg'], -10);

      res = await advTool.call({}, ctx);
      expect(res.data['phase'], 'gradual_decompression_0_2min');
      expect(res.data['pressure_mmhg'], 0);

      res = await advTool.call({}, ctx);
      expect(res.data['phase'], 'completed');
      expect(res.data['pressure_mmhg'], 0);
    });

    test('LBNP triggers immediate release + supine fluid load alert on hypotension SBP < 85 or HR drop > 20', () async {
      final skills = microgravitySkills();
      final ctx = _makeContext();
      await _findTool(skills, 'procedures', 'start_lbnp').call({}, ctx);
      await _findTool(skills, 'procedures', 'advance_lbnp').call({'seal_checked': true}, ctx);
      await _findTool(skills, 'procedures', 'advance_lbnp').call({}, ctx); // at -20

      final res = await _findTool(skills, 'procedures', 'advance_lbnp').call({
        'systolic_bp': 80,
        'hr_drop_bpm': 24,
      }, ctx);

      expect(res.ok, isTrue);
      expect(res.data['phase'], 'aborted');
      expect(res.data['pressure_mmhg'], 0);
      expect(res.data['emergency_release'], isTrue);
      expect(res.data['supine_fluid_load_alert'], isTrue);
    });

    test('ultrasound guide advances through windows, checklist, and residual bladder volume', () async {
      final skills = microgravitySkills();
      final ctx = _makeContext();
      final usTool = _findTool(skills, 'procedures', 'start_ultrasound_guide');

      final prep = await usTool.call({}, ctx);
      expect(prep.ok, isTrue);
      expect(prep.data['step'], 'prep_gel_and_probe');
      final usEvent = prep.uiEvents.single as ShowComponentEvent;
      expect(usEvent.id, ComponentIds.ultrasoundGuide);
      expect(
        UltrasoundGuideViewModel.fromProps(usEvent.props).evaluation.step,
        UltrasoundStep.prepGelAndProbe,
      );

      final stoneCheck = await usTool.call({
        'step': 'hydronephrosis_stone_check',
        'acoustic_window_ok': true,
        'hydronephrosis_present': true,
        'stone_shadow_present': true,
      }, ctx);
      expect(stoneCheck.ok, isTrue);
      expect(stoneCheck.data['hydronephrosis_present'], isTrue);
      expect(stoneCheck.data['stone_shadow_present'], isTrue);

      final bladder = await usTool.call({
        'step': 'bladder_volume_scan',
        'bladder_width_cm': 8.0,
        'bladder_height_cm': 7.0,
        'bladder_length_cm': 7.0,
      }, ctx);
      expect(bladder.ok, isTrue);
      // 0.52 * 8 * 7 * 7 = 203.84 mL (> 150 mL elevated residual)
      expect(bladder.data['residual_bladder_volume_ml'], closeTo(203.84, 0.1));
      expect(bladder.data['urinary_retention_risk'], isTrue);
    });
  });
}
