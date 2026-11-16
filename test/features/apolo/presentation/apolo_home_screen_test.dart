import 'dart:async';

import 'package:astramed/features/agent/application/hands_free_controller.dart';
import 'package:astramed/features/agent/domain/agent_contracts.dart';
import 'package:astramed/features/agent/domain/agent_models.dart';
import 'package:astramed/features/agent/domain/agent_ports.dart';
import 'package:astramed/features/agent/providers/agent_providers.dart';
import 'package:astramed/features/apolo/domain/apolo_models.dart';
import 'package:astramed/features/apolo/presentation/apolo_detail_sheet.dart';
import 'package:astramed/features/apolo/presentation/apolo_dog_widget.dart';
import 'package:astramed/features/apolo/presentation/apolo_home_screen.dart';
import 'package:astramed/features/apolo/presentation/apolo_orb_widget.dart';
import 'package:astramed/features/apolo/providers/apolo_contract_providers.dart';
import 'package:astramed/features/crew/presentation/providers/crew_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeApoloController extends StateNotifier<ApoloAstronautState>
    implements ApoloStateActions {
  _FakeApoloController(super.initialState);

  int showAllOrbsCalls = 0;
  int resetOrbsToUrgentCalls = 0;
  final List<int> addedWaterMl = [];
  final List<int> addedExerciseMin = [];
  final List<bool> highContrastChanges = [];
  final List<bool> autoTipsChanges = [];
  final List<(String, bool)> toggledRecs = [];
  final List<ApoloModuleId> hiddenOrbs = [];
  int submitSampleCalls = 0;

  @override
  ApoloAstronautState stateFor(String astronautId) => state;

  @override
  void showOrbs(Iterable<ApoloModuleId> ids, {int maxOrbs = 8}) {
    final next = List<ApoloModuleId>.from(state.visibleOrbs);
    for (final id in ids) {
      if (!next.contains(id)) next.add(id);
    }
    state = _copyState(visibleOrbs: next.take(maxOrbs).toList());
  }

  @override
  void resetOrbsToUrgent() {
    resetOrbsToUrgentCalls++;
    final urgent = state.rankedModules
        .where((m) => m.severity != ApoloSeverity.ok)
        .take(4)
        .map((m) => m.id)
        .toList();
    state = _copyState(visibleOrbs: urgent);
  }

  @override
  void showAllOrbs({int maxOrbs = 8}) {
    showAllOrbsCalls++;
    final all = state.rankedModules.take(maxOrbs).map((m) => m.id).toList();
    state = _copyState(visibleOrbs: all);
  }

  @override
  void hideOrb(ApoloModuleId id) {
    hiddenOrbs.add(id);
    state = _copyState(
      visibleOrbs: state.visibleOrbs.where((x) => x != id).toList(),
    );
  }

  @override
  void openDetail(ApoloModuleId? id) {
    state = _copyState(openModuleId: id, clearOpenModuleId: id == null);
  }

  @override
  bool addWater(int ml, {String? astronautId}) {
    if (ml < 50 || ml > 2000) return false;
    addedWaterMl.add(ml);
    final nextWater = state.waterMlToday + ml;
    final currentHydration = state.modules[ApoloModuleId.hidratacion]!;
    final nextSeverity = nextWater >= state.waterGoalMl
        ? ApoloSeverity.ok
        : currentHydration.severity;
    final nextModules = Map<ApoloModuleId, ApoloModuleSnapshot>.from(
      state.modules,
    );
    nextModules[ApoloModuleId.hidratacion] = ApoloModuleSnapshot(
      id: currentHydration.id,
      title: currentHydration.title,
      shortLabel: currentHydration.shortLabel,
      measures: currentHydration.measures,
      whyItMatters: currentHydration.whyItMatters,
      severity: nextSeverity,
      keyMetric: '${(nextWater / 1000).toStringAsFixed(1)} L',
      subMetric: currentHydration.subMetric,
      primaryBiomarkerId: currentHydration.primaryBiomarkerId,
      primaryBiomarkerName: currentHydration.primaryBiomarkerName,
      biomarkers: currentHydration.biomarkers,
      trendValues: currentHydration.trendValues,
      recommendations: currentHydration.recommendations,
      relatedModules: currentHydration.relatedModules,
    );
    state = _copyState(waterMlToday: nextWater, modules: nextModules);
    return true;
  }

  @override
  bool addExercise(int minutes, {String? astronautId}) {
    if (minutes < 1 || minutes > 300) return false;
    addedExerciseMin.add(minutes);
    state = _copyState(exerciseMinToday: state.exerciseMinToday + minutes);
    return true;
  }

  @override
  void toggleRecommendation(String recId, bool done, {String? astronautId}) {
    toggledRecs.add((recId, done));
  }

  @override
  ApoloUrineSample submitSample({
    String method = 'sensor',
    String? astronautId,
  }) {
    submitSampleCalls++;
    final sample = ApoloUrineSample(
      id: 'sample-new',
      astronautId: state.astronautId,
      missionDay: state.missionDay,
      takenAt: DateTime.utc(2026, 11, 15, 12),
      method: method,
      values: const {'vol': 1.4},
    );
    state = _copyState(
      samples: [...state.samples, sample],
      sampleSchedule: ApoloSampleScheduleState(
        isDue: false,
        isFirstSample: false,
        previousSlot: DateTime.utc(2026, 11, 15, 12),
        nextSlot: DateTime.utc(2026, 11, 15, 20),
        progress: 0.0,
        shortLabel: '8h 00m',
        title: 'Next sample in 8h',
        subtitle: 'Scheduled for 20:00 UTC',
      ),
    );
    return sample;
  }

  @override
  void setHighContrast(bool enabled) {
    highContrastChanges.add(enabled);
    state = _copyState(highContrast: enabled);
  }

  @override
  void setAutoTips(bool enabled) {
    autoTipsChanges.add(enabled);
    state = _copyState(autoTips: enabled);
  }

  @override
  void setSolarStorm(bool active) {
    state = _copyState(solarStormActive: active);
  }

  ApoloAstronautState _copyState({
    int? waterMlToday,
    int? exerciseMinToday,
    Map<ApoloModuleId, ApoloModuleSnapshot>? modules,
    List<ApoloModuleId>? visibleOrbs,
    ApoloModuleId? openModuleId,
    bool clearOpenModuleId = false,
    ApoloSampleScheduleState? sampleSchedule,
    List<ApoloUrineSample>? samples,
    bool? highContrast,
    bool? autoTips,
    bool? solarStormActive,
  }) {
    return ApoloAstronautState(
      astronautId: state.astronautId,
      apoloCrewKey: state.apoloCrewKey,
      name: state.name,
      role: state.role,
      initials: state.initials,
      colorHex: state.colorHex,
      missionName: state.missionName,
      missionDay: state.missionDay,
      totalMissionDays: state.totalMissionDays,
      doseMsv: state.doseMsv,
      doseLimitMsv: state.doseLimitMsv,
      waterMlToday: waterMlToday ?? state.waterMlToday,
      waterGoalMl: state.waterGoalMl,
      exerciseMinToday: exerciseMinToday ?? state.exerciseMinToday,
      exerciseGoalMin: state.exerciseGoalMin,
      sleepHours: state.sleepHours,
      resistanceSessionsWeek: state.resistanceSessionsWeek,
      overallSeverity: state.overallSeverity,
      modules: modules ?? state.modules,
      visibleOrbs: visibleOrbs ?? state.visibleOrbs,
      openModuleId: clearOpenModuleId
          ? null
          : (openModuleId ?? state.openModuleId),
      sampleSchedule: sampleSchedule ?? state.sampleSchedule,
      samples: samples ?? state.samples,
      highContrast: highContrast ?? state.highContrast,
      autoTips: autoTips ?? state.autoTips,
      solarStormActive: solarStormActive ?? state.solarStormActive,
    );
  }
}

ApoloAstronautState _buildFakeApoloState() {
  const volDef = ApoloBiomarkerDef(
    id: 'vol',
    name: 'Urine volume',
    unit: 'L/day',
    decimals: 1,
    min: 0.4,
    max: 3.0,
    lo: 1.2,
    hi: 2.4,
  );
  const caDef = ApoloBiomarkerDef(
    id: 'ca',
    name: 'Urine calcium',
    unit: 'mg/day',
    decimals: 0,
    min: 50,
    max: 450,
    lo: 100,
    hi: 250,
  );

  ApoloModuleSnapshot makeSnap(
    ApoloModuleId id,
    ApoloSeverity sev,
    String key,
    String sub, {
    List<ApoloRecommendation> recs = const [],
  }) {
    return ApoloModuleSnapshot(
      id: id,
      title: id.title,
      shortLabel: id.shortLabel,
      measures: 'Measures ${id.title.toLowerCase()} indicators',
      whyItMatters: '${id.title} matters in microgravity.',
      severity: sev,
      keyMetric: key,
      subMetric: sub,
      primaryBiomarkerId: 'vol',
      primaryBiomarkerName: 'Urine volume',
      biomarkers: const [
        ApoloBiomarkerReading(
          def: volDef,
          value: 0.9,
          personalLo: 1.2,
          personalHi: 2.4,
          severity: ApoloSeverity.warn,
          formattedValue: '0.9',
        ),
        ApoloBiomarkerReading(
          def: caDef,
          value: 290,
          personalLo: 100,
          personalHi: 250,
          severity: ApoloSeverity.crit,
          formattedValue: '290',
        ),
      ],
      trendValues: const [1.3, 1.2, 1.1, 1.0, 0.95, 0.9],
      recommendations: recs,
      relatedModules: const [ApoloModuleId.renal],
    );
  }

  final modules = <ApoloModuleId, ApoloModuleSnapshot>{
    ApoloModuleId.hidratacion: makeSnap(
      ApoloModuleId.hidratacion,
      ApoloSeverity.warn,
      '1.2 L',
      'of 2.5 L today',
      recs: const [
        ApoloRecommendation(
          id: 'rec-water',
          moduleId: ApoloModuleId.hidratacion,
          priority: 'High',
          text: 'Drink 500 ml of water now',
          why: 'Reduces urine concentration.',
        ),
      ],
    ),
    ApoloModuleId.renal: makeSnap(
      ApoloModuleId.renal,
      ApoloSeverity.crit,
      'High',
      '2 factors out of range',
    ),
    ApoloModuleId.osea: makeSnap(
      ApoloModuleId.osea,
      ApoloSeverity.ok,
      '+4 %',
      'resorption vs baseline',
    ),
    ApoloModuleId.radiacion: makeSnap(
      ApoloModuleId.radiacion,
      ApoloSeverity.ok,
      '18 mSv',
      'of 50 mSv limit',
    ),
    ApoloModuleId.inmunidad: makeSnap(
      ApoloModuleId.inmunidad,
      ApoloSeverity.ok,
      'Stable',
      'no signs of infection',
    ),
    ApoloModuleId.cardio: makeSnap(
      ApoloModuleId.cardio,
      ApoloSeverity.ok,
      'Na/K 2.1',
      'electrolyte balance',
    ),
    ApoloModuleId.estres: makeSnap(
      ApoloModuleId.estres,
      ApoloSeverity.ok,
      '7 h 10 m',
      'good sleep · low stress',
    ),
    ApoloModuleId.metabolismo: makeSnap(
      ApoloModuleId.metabolismo,
      ApoloSeverity.ok,
      'No ketones',
      'adequate energy',
    ),
  };

  return ApoloAstronautState(
    astronautId: 'AST-01',
    apoloCrewKey: 'ana',
    name: 'Alex Vance',
    role: 'Commander',
    initials: 'AV',
    colorHex: 0xFFB3E9C7,
    missionName: 'Artemis Gateway',
    missionDay: 142,
    totalMissionDays: 180,
    doseMsv: 18.0,
    doseLimitMsv: 50.0,
    waterMlToday: 1200,
    waterGoalMl: 2500,
    exerciseMinToday: 30,
    exerciseGoalMin: 90,
    sleepHours: 7.2,
    resistanceSessionsWeek: 4,
    overallSeverity: ApoloSeverity.crit,
    modules: modules,
    visibleOrbs: const [ApoloModuleId.renal, ApoloModuleId.hidratacion],
    openModuleId: null,
    sampleSchedule: ApoloSampleScheduleState(
      isDue: true,
      isFirstSample: false,
      previousSlot: DateTime.utc(2026, 11, 15, 4),
      nextSlot: DateTime.utc(2026, 11, 15, 12),
      progress: 1.0,
      shortLabel: 'Due now',
      title: 'Sample due',
      subtitle: 'Mid-stream urine sample ready',
    ),
    samples: [
      ApoloUrineSample(
        id: 's1',
        astronautId: 'AST-01',
        missionDay: 142,
        takenAt: DateTime.utc(2026, 11, 15, 4),
        method: 'sensor',
        values: const {'vol': 0.9, 'ca': 290},
      ),
    ],
  );
}

class _FakeChatService implements AgentChatService {
  _FakeChatService(this._handler);

  final Future<AgentReply> Function(
    List<ChatMessage> messages,
    Map<String, dynamic>? context,
    List<ToolSpec>? tools,
    List<String>? skillInstructions,
  )
  _handler;

  @override
  Future<AgentReply> send(
    List<ChatMessage> messages, {
    Map<String, dynamic>? context,
    List<ToolSpec>? tools,
    List<String>? skillInstructions,
  }) => _handler(messages, context, tools, skillInstructions);

  @override
  Stream<AgentStreamEvent> stream(
    List<ChatMessage> messages, {
    Map<String, dynamic>? context,
    List<ToolSpec>? tools,
    List<String>? skillInstructions,
  }) => const Stream.empty();
}

class _FakeSpeechToTextService implements SpeechToTextService {
  @override
  Future<void> cancel() async {}

  @override
  Future<void> dispose() async {}

  @override
  Future<bool> isAvailable() async => false;

  @override
  Future<String> listen({
    String language = 'en',
    Duration maxDuration = const Duration(seconds: 15),
  }) async => '';

  @override
  Future<void> startListening({String language = 'en'}) async {}

  @override
  Future<String> stopListening() async => '';
}

class _FakeTextToSpeechService implements TextToSpeechService {
  @override
  Future<void> dispose() async {}

  @override
  Future<void> speak(
    String text, {
    String? voice,
    String language = 'en-US',
  }) async {}

  @override
  Future<void> stop() async {}
}

class _ControllableSynchronizedTts implements SynchronizedTextToSpeechService {
  final Completer<void> synthGate = Completer<void>();
  final Completer<void> playGate = Completer<void>();

  @override
  Future<void> speakSynchronized(
    String text, {
    String? voice,
    String language = 'en-US',
    required void Function() onAudioReady,
  }) async {
    await synthGate.future;
    onAudioReady();
    await playGate.future;
  }

  @override
  Future<void> speak(
    String text, {
    String? voice,
    String language = 'en-US',
  }) => speakSynchronized(
    text,
    voice: voice,
    language: language,
    onAudioReady: () {},
  );

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() async {}
}

class _FakeMemoryStore implements MemoryStore {
  @override
  Future<List<MemoryEntry>> recall(
    String astronautId, {
    String? query,
    Set<MemoryKind>? kinds,
    int limit = 10,
  }) async => const [];

  @override
  Future<List<MemoryEntry>> recentForPrompt(
    String astronautId, {
    int limit = 8,
  }) async => const [];

  @override
  Future<MemoryEntry> save(MemoryEntry entry) async => entry;
}

class _FakeAuditLog implements AuditLog {
  @override
  Future<void> append(AuditEntry entry) async {}

  @override
  Future<List<AuditEntry>> list({String? astronautId, int limit = 50}) async =>
      const [];
}

class _FakeFlagsStore implements AgentFlagsStore {
  @override
  Future<Map<String, Map<String, dynamic>>> allForAstronaut(
    String astronautId,
  ) async => const {};

  @override
  Future<Map<String, dynamic>?> getFlag(String astronautId, String key) async =>
      null;

  @override
  Future<void> setFlag(
    String astronautId,
    String key,
    Map<String, dynamic> value,
  ) async {}
}

class _FakeMedicationSafety implements MedicationSafety {
  @override
  Future<MedicationCheck> validate(MedicationRequest request) async =>
      const MedicationCheck(allowed: true, reasons: ['ok']);
}

class _FakeConfirmationGate implements ConfirmationGate {
  @override
  ConsequentialAction? get pending => null;

  @override
  Future<ConfirmationDecision> request(
    ConsequentialAction action, {
    required Future<Map<String, dynamic>> Function() onConfirmed,
  }) async => ConfirmationDecision.confirmed;

  @override
  Future<Map<String, dynamic>?> resolve(
    String actionId,
    ConfirmationDecision decision, {
    String? reason,
  }) async => null;
}

final _fakeApoloProvider =
    StateNotifierProvider<_FakeApoloController, ApoloAstronautState>(
      (ref) => _FakeApoloController(_buildFakeApoloState()),
    );

void main() {
  List<Override> buildOverrides({
    required _FakeApoloController controller,
    AgentChatService? chatService,
    TextToSpeechService? ttsService,
  }) {
    final chat =
        chatService ??
        _FakeChatService(
          (messages, _, _, _) async => AgentReply(
            reply: 'Echo: ${messages.last.content}',
            model: 'test',
          ),
        );
    return [
      apoloActiveStateProvider.overrideWith((ref) {
        return ref.watch(_fakeApoloProvider);
      }),
      apoloActionsProvider.overrideWith((ref) {
        return ref.read(_fakeApoloProvider.notifier);
      }),
      _fakeApoloProvider.overrideWith((ref) => controller),
      agentChatServiceProvider.overrideWithValue(chat),
      speechToTextServiceProvider.overrideWithValue(_FakeSpeechToTextService()),
      textToSpeechServiceProvider.overrideWithValue(
        ttsService ?? _FakeTextToSpeechService(),
      ),
      agentMemoryStoreProvider.overrideWithValue(_FakeMemoryStore()),
      agentAuditLogProvider.overrideWithValue(_FakeAuditLog()),
      agentFlagsStoreProvider.overrideWithValue(_FakeFlagsStore()),
      agentConfirmationGateProvider.overrideWithValue(_FakeConfirmationGate()),
      medicationSafetyProvider.overrideWithValue(_FakeMedicationSafety()),
      handsFreeControllerProvider.overrideWith(
        (ref) => HandsFreeController(onTranscript: (_) {}),
      ),
    ];
  }

  Widget buildTestApp(
    WidgetTester tester, {
    required List<Override> overrides,
    Size size = const Size(1280, 800),
    VoidCallback? onOpenClinicalDashboard,
    bool disableAnimations = true,
  }) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    return ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            size: size,
            disableAnimations: disableAnimations,
          ),
          child: ApoloHomeScreen(
            onOpenClinicalDashboard: onOpenClinicalDashboard,
          ),
        ),
      ),
    );
  }

  testWidgets(
    'renders APOLO header, dog widget, initial urgent orbs, and Show all chip calls showAllOrbs()',
    (tester) async {
      final controller = _FakeApoloController(_buildFakeApoloState());
      await tester.pumpWidget(
        buildTestApp(tester, overrides: buildOverrides(controller: controller)),
      );
      await tester.pumpAndSettle();

      expect(find.text('APOLO'), findsOneWidget);
      expect(find.textContaining('Day 142'), findsOneWidget);
      expect(find.byType(ApoloDogWidget), findsOneWidget);

      // Initially only the 2 non-ok orbs (renal + hidratacion) are rendered.
      expect(find.byType(ApoloOrbWidget), findsNWidgets(2));
      expect(find.byKey(const ValueKey('apolo_orb_renal')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('apolo_orb_hidratacion')),
        findsOneWidget,
      );

      // Tap "Show all" quick chip -> calls showAllOrbs() and reveals all 8 orbs.
      await tester.tap(find.text('Show all'));
      await tester.pumpAndSettle();

      expect(controller.showAllOrbsCalls, 1);
      expect(find.byType(ApoloOrbWidget), findsNWidgets(8));
    },
  );

  testWidgets(
    'tapping an orb opens detail sheet and +250 ml calls addWater(250)',
    (tester) async {
      final controller = _FakeApoloController(_buildFakeApoloState());
      await tester.pumpWidget(
        buildTestApp(tester, overrides: buildOverrides(controller: controller)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('apolo_orb_hidratacion')));
      await tester.pumpAndSettle();

      expect(find.byType(ApoloDetailSheet), findsOneWidget);
      expect(find.text('Hydration'), findsOneWidget);
      expect(find.text('What your urine says'), findsOneWidget);

      await tester.tap(find.text('+250 ml'));
      await tester.pumpAndSettle();

      expect(controller.addedWaterMl, [250]);
      expect(find.text('1.4 / 2.5 L'), findsOneWidget);
    },
  );

  testWidgets(
    'typing a question and tapping send dispatches to AgentConversationController and displays reply in speech bubble',
    (tester) async {
      final controller = _FakeApoloController(_buildFakeApoloState());
      final chat = _FakeChatService((messages, _, _, _) async {
        return const AgentReply(
          reply: 'Your hydration is at 1.2 L today. Drink 500 ml soon.',
          model: 'test-model',
        );
      });

      await tester.pumpWidget(
        buildTestApp(
          tester,
          overrides: buildOverrides(controller: controller, chatService: chat),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const ValueKey('apolo_ask_input')),
        'How is my water intake?',
      );
      await tester.tap(find.byKey(const ValueKey('apolo_send_button')));
      await tester.pumpAndSettle();

      final bubble = find.byKey(const ValueKey('apolo_speech_bubble'));
      expect(bubble, findsOneWidget);
      expect(
        find.descendant(
          of: bubble,
          matching: find.text(
            'Your hydration is at 1.2 L today. Drink 500 ml soon.',
          ),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'crew menu opens, switches astronaut, and high-contrast switch calls setHighContrast(true)',
    (tester) async {
      final controller = _FakeApoloController(_buildFakeApoloState());
      await tester.pumpWidget(
        buildTestApp(tester, overrides: buildOverrides(controller: controller)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('apolo_crew_button')));
      await tester.pumpAndSettle();

      final hcSwitch = find.byKey(const ValueKey('apolo_switch_high_contrast'));
      expect(hcSwitch, findsOneWidget);

      await tester.tap(hcSwitch);
      await tester.pumpAndSettle();

      expect(controller.highContrastChanges, [true]);

      // Switch to second crew member AST-02.
      final secondCrew = find.byKey(const ValueKey('apolo_crew_member_AST-02'));
      expect(secondCrew, findsOneWidget);
      await tester.tap(secondCrew);
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(ApoloHomeScreen)),
      );
      expect(container.read(selectedAstronautIdProvider), 'AST-02');
      expect(container.read(agentOrchestratorProvider).astronautId, 'AST-02');
    },
  );

  testWidgets(
    'detail sheet Ask Apolo dispatches to agent, Hide appears only for ok, and sample pill submits sample',
    (tester) async {
      final controller = _FakeApoloController(_buildFakeApoloState());
      final chat = _FakeChatService((messages, _, _, _) async {
        return AgentReply(
          reply: 'Module guidance for: ${messages.last.content}',
          model: 'test-model',
        );
      });

      await tester.pumpWidget(
        buildTestApp(
          tester,
          overrides: buildOverrides(controller: controller, chatService: chat),
        ),
      );
      await tester.pumpAndSettle();

      // Open hydration (warn) -> Hide button should NOT be shown.
      await tester.tap(find.byKey(const ValueKey('apolo_orb_hidratacion')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('apolo_detail_hide_button')),
        findsNothing,
      );

      // Tap Ask Apolo -> closes sheet and sends module question to agent.
      final askBtn = find.byKey(const ValueKey('apolo_detail_ask_button'));
      await tester.ensureVisible(askBtn);
      await tester.pumpAndSettle();
      await tester.tap(askBtn);
      await tester.pumpAndSettle();
      expect(find.byType(ApoloDetailSheet), findsNothing);
      expect(
        find.textContaining('Module guidance for: Tell me about my hydration'),
        findsOneWidget,
      );

      // Show all orbs, open an ok orb (osea), verify Hide button hides it.
      await tester.tap(find.text('Show all'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('apolo_orb_osea')));
      await tester.pumpAndSettle();
      final hideBtn = find.byKey(const ValueKey('apolo_detail_hide_button'));
      expect(hideBtn, findsOneWidget);
      await tester.ensureVisible(hideBtn);
      await tester.pumpAndSettle();
      await tester.tap(hideBtn);
      await tester.pumpAndSettle();
      expect(controller.hiddenOrbs, [ApoloModuleId.osea]);

      // Tap sample pill while due -> calls submitSample().
      await tester.tap(find.byKey(const ValueKey('apolo_sample_pill')));
      await tester.pumpAndSettle();
      expect(controller.submitSampleCalls, 1);
    },
  );

  testWidgets(
    'renders with animations enabled without layout or painter errors',
    (tester) async {
      final controller = _FakeApoloController(_buildFakeApoloState());
      await tester.pumpWidget(
        buildTestApp(
          tester,
          disableAnimations: false,
          overrides: buildOverrides(controller: controller),
        ),
      );
      await tester.pump(const Duration(milliseconds: 120));
      await tester.pump(const Duration(milliseconds: 240));
      expect(find.byType(ApoloDogWidget), findsOneWidget);
      expect(find.byType(ApoloOrbWidget), findsNWidgets(2));
    },
  );

  testWidgets(
    'onOpenClinicalDashboard callback fires and responsive narrow layout stacks orbs',
    (tester) async {
      final controller = _FakeApoloController(_buildFakeApoloState());
      var openedDashboard = false;
      await tester.pumpWidget(
        buildTestApp(
          tester,
          size: const Size(420, 820),
          overrides: buildOverrides(controller: controller),
          onOpenClinicalDashboard: () => openedDashboard = true,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ApoloDogWidget), findsOneWidget);
      expect(find.byType(ApoloOrbWidget), findsNWidgets(2));

      await tester.tap(find.byKey(const ValueKey('apolo_modules_button')));
      await tester.pumpAndSettle();
      expect(openedDashboard, isTrue);
    },
  );

  testWidgets(
    'S4: shows apolo_thinking_indicator and isThinking=true while waiting for voice, then reveals reply text and isSpeaking=true together',
    (tester) async {
      final controller = _FakeApoloController(_buildFakeApoloState());
      final chat = _FakeChatService((messages, _, _, _) async {
        return const AgentReply(
          reply: 'Listen! Drink 500 ml of water right away.',
          model: 'test-model',
        );
      });
      final syncTts = _ControllableSynchronizedTts();

      await tester.pumpWidget(
        buildTestApp(
          tester,
          disableAnimations: false,
          overrides: buildOverrides(
            controller: controller,
            chatService: chat,
            ttsService: syncTts,
          ),
        ),
      );
      await tester.pump();

      await tester.enterText(
        find.byKey(const ValueKey('apolo_ask_input')),
        'Check hydration',
      );
      await tester.tap(find.byKey(const ValueKey('apolo_send_button')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // While TTS synthesis is pending: thinking indicator is shown, reply text is withheld,
      // ApoloDogWidget is thinking and NOT speaking yet.
      expect(
        find.byKey(const Key('apolo_thinking_indicator')),
        findsOneWidget,
      );
      expect(
        find.text('Listen! Drink 500 ml of water right away.'),
        findsNothing,
      );
      final thinkingDog = tester.widget<ApoloDogWidget>(
        find.byType(ApoloDogWidget),
      );
      expect(thinkingDog.isThinking, isTrue);
      expect(thinkingDog.isSpeaking, isFalse);

      // Complete synthesis -> onAudioReady fires -> text & isSpeaking appear synchronously!
      syncTts.synthGate.complete();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(
        find.byKey(const Key('apolo_thinking_indicator')),
        findsNothing,
      );
      final bubble = find.byKey(const ValueKey('apolo_speech_bubble'));
      expect(
        find.descendant(
          of: bubble,
          matching: find.text('Listen! Drink 500 ml of water right away.'),
        ),
        findsOneWidget,
      );
      final speakingDog = tester.widget<ApoloDogWidget>(
        find.byType(ApoloDogWidget),
      );
      expect(speakingDog.isThinking, isFalse);
      expect(speakingDog.isSpeaking, isTrue);

      // Complete playback -> isSpeaking returns to false.
      syncTts.playGate.complete();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      final idleDog = tester.widget<ApoloDogWidget>(
        find.byType(ApoloDogWidget),
      );
      expect(idleDog.isSpeaking, isFalse);
      expect(idleDog.isThinking, isFalse);
    },
  );
}
