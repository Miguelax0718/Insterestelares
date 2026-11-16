import 'package:astramed/features/03_microgravity/agent/graybiel_engine.dart';
import 'package:astramed/features/03_microgravity/agent/sans_engine.dart';
import 'package:astramed/features/03_microgravity/agent/microgravity_skills.dart';
import 'package:astramed/features/03_microgravity/agent/procedures_engine.dart';
import 'package:astramed/features/03_microgravity/presentation/cockpit_widgets/zero_g_horizon_card.dart';
import 'package:astramed/features/03_microgravity/presentation/cockpit_widgets/dva_gaze_card.dart';
import 'package:astramed/features/03_microgravity/presentation/cockpit_widgets/graybiel_card.dart';
import 'package:astramed/features/03_microgravity/presentation/cockpit_widgets/sans_cockpit_cards.dart';
import 'package:astramed/features/03_microgravity/presentation/cockpit_widgets/clinical_cockpit_cards.dart';
import 'package:astramed/features/agent/domain/agent_contracts.dart';
import 'package:astramed/features/agent/domain/guided_assessment_catalog.dart';
import 'package:astramed/features/apolo/presentation/apolo_assessment_launcher_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _Sink implements AgentUiSink {
  final events = <AgentComponentEvent>[];
  @override
  void emit(AgentComponentEvent event) => events.add(event);
  @override
  void submit(String id, Map<String, dynamic> result) {}
}

class _Context implements ToolContext {
  @override
  final _Sink ui = _Sink();
  @override
  String get astronautId => 'AST-01';
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _mount(WidgetTester tester, Widget child) => tester.pumpWidget(
  MaterialApp(home: Scaffold(body: SingleChildScrollView(child: child))),
);

void main() {
  test('relative greenness uses baseline and rejects invalid measurements', () {
    expect(FacialGreennessAnalyzer.analyze(baselineGR: 1, currentGR: 1.01).status,
        ChromaticityStatus.nominal);
    expect(FacialGreennessAnalyzer.analyze(baselineGR: 1, currentGR: 1.08).status,
        ChromaticityStatus.critical);
    expect(() => FacialGreennessAnalyzer.analyze(baselineGR: 0, currentGR: 1),
        throwsArgumentError);
  });
  test('DVA weights optotype accuracy and reported fixation; empty is not stable', () {
    final result = GazeStabilityAnalyzer.analyze(
        correctCount: 4, total: 5, fixationRatio: 1);
    expect(result.optotypeAccuracy, .8);
    expect(result.compositeScore, closeTo(.95, .001));
    expect(result.isStable, isTrue);
    expect(GazeStabilityAnalyzer.analyze(correctCount: 0, total: 0,
        fixationRatio: 1).isStable, isFalse);
  });
  test('horizon RMS and EVA threshold boundaries', () {
    expect(ZeroGHorizonScorer.evaluate(pitch: 0, roll: 0, yaw: 0).alignmentPct, 100);
    final drift = ZeroGHorizonScorer.evaluate(pitch: 30, roll: 30, yaw: 30);
    expect(drift.rmsErrorDeg, 30);
    expect(drift.severeDrift, isTrue);
    expect(EvaSafetyAdvisory.evaluate(graybielScore: 4).evaNoGoRecommended, isFalse);
    expect(EvaSafetyAdvisory.evaluate(graybielScore: 5).evaNoGoRecommended, isTrue);
    expect(EvaSafetyAdvisory.evaluate(graybielScore: 0, horizon: drift)
        .evaNoGoRecommended, isTrue);
  });
  test('near-point reciprocal optics and glasses bands', () {
    final result = NearPointDiopterCalculator.evaluate(
        distanceCm: 50, baselineCm: 25);
    expect(result.deltaDiopters, 2);
    expect(result.confidenceBand, closeTo(.16, .001));
    expect(result.tier, SpaceAnticipationGlassesTier.pairB_plus1_50);
    expect(NearPointDiopterCalculator.evaluate(distanceCm: 25).tier,
        SpaceAnticipationGlassesTier.none);
    expect(() => NearPointDiopterCalculator.evaluate(distanceCm: double.nan),
        throwsArgumentError);
  });
  test('starfield distortion and peripheral misses grade functional risk', () {
    expect(StarfieldDistortionAnalyzer.evaluate(distortionIndex: 0,
        scotomaMisses: 0, totalFlashes: 8).grade, SansGrade.nominal);
    expect(StarfieldDistortionAnalyzer.evaluate(distortionIndex: .4,
        scotomaMisses: 0, totalFlashes: 8).grade, SansGrade.grade2);
    expect(StarfieldDistortionAnalyzer.evaluate(distortionIndex: 0,
        scotomaMisses: 3, totalFlashes: 8).grade, SansGrade.grade2);
  });
  test('LBNP timed adapter preserves engine phases and rejects repeated release', () {
    final protocol = LbnpProtocolMachine();
    expect(protocol.advance().state.pressureMmHg, -10);
    expect(protocol.advance().ok, isFalse);
    protocol.tick(deltaSeconds: 180);
    expect(protocol.advance().state.pressureMmHg, -20);
    expect(protocol.abort().state.phase, LbnpPhase.gradualDecompressionMinus10_3min);
    expect(protocol.abort().ok, isFalse);
    expect(protocol.state.pressureMmHg, -10);
    expect(protocol.advance().ok, isFalse);
    protocol.tick(deltaSeconds: 180);
    expect(protocol.advance().state.phase, LbnpPhase.aborted);
    expect(protocol.state.pressureMmHg, 0);
  });
  test('existing scoring and four skill IDs remain compatible', () {
    expect(GraybielEngine.evaluate({GraybielSymptom.nausea: GraybielLevel.moderate})
        .totalScore, 4);
    expect(SansEngine.evaluate(nearFocusCm: 46).recommendedGoggles,
        SansGogglePair.pairB);
    expect(microgravitySkills().map((s) => s.id),
        ['graybiel', 'sans', 'exercise', 'procedures']);
  });
  test('launch tools emit exact extra component IDs without clinical mutation', () async {
    for (final (tool, id) in <(AgentTool, String)>[
      (StartZeroGHorizonTool(), MicrogravityCockpitIds.zeroGHorizon),
      (StartDvaGazeTool(), MicrogravityCockpitIds.dvaGaze),
    ]) {
      final context = _Context();
      final result = await tool.call({}, context);
      expect((result.uiEvents.single as ShowComponentEvent).id, id);
      expect((context.ui.events.single as ShowComponentEvent).id, id);
    }
  });
  testWidgets('horizon controls submit actual RMS alignment and dismiss', (tester) async {
    Map<String, dynamic>? payload;
    var dismissed = false;
    await _mount(tester, ZeroGHorizonCard(onSubmit: (p) => payload = p,
        onDismiss: () => dismissed = true));
    await tester.tap(find.text('Complete Alignment'));
    expect(payload!['completed'], true);
    expect(payload!['rms_error_deg'], isA<double>());
    expect(payload!['alignment_pct'], inInclusiveRange(0, 100));
    await tester.tap(find.byTooltip('Dismiss'));
    expect(dismissed, isTrue);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('DVA counts actual answers and submits reported fixation', (tester) async {
    Map<String, dynamic>? payload;
    await _mount(tester, DvaGazeCard(onSubmit: (p) => payload = p, onDismiss: () {}));
    await tester.tap(find.widgetWithText(OutlinedButton, 'E'));
    await tester.pump();
    await tester.tap(find.text('Complete DVA'));
    expect(payload!['correct_count'], 1);
    expect(payload!['total'], 1);
    expect(payload!['gaze_stability_pct'], isA<double>());
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('Graybiel emesis blocks EVA and submits structured responses', (tester) async {
    Map<String, dynamic>? payload;
    await _mount(tester, GraybielCard(onSubmit: (p) => payload = p, onDismiss: () {}));
    await tester.tap(find.byType(Switch));
    await tester.pump();
    expect(find.text('NO-GO EVA'), findsOneWidget);
    await tester.ensureVisible(find.text('Submit Assessment'));
    await tester.tap(find.text('Submit Assessment'));
    expect(payload!['emesis'], true);
    expect(payload!['responses'], isA<Map>());
    expect(payload!['facial_pallor'], isNotNull);
  });
  testWidgets('exact Graybiel score five displays NO-GO and serializes all symptoms', (tester) async {
    Map<String, dynamic>? payload;
    await _mount(tester, GraybielCard(onSubmit: (p) => payload = p,
      onDismiss: () {}, initialResponses: const {
        GraybielSymptom.nausea: GraybielLevel.moderate,
        GraybielSymptom.pallor: GraybielLevel.minimal,
      }));
    expect(find.text('NO-GO EVA'), findsOneWidget);
    await tester.ensureVisible(find.text('Submit Assessment'));
    await tester.tap(find.text('Submit Assessment'));
    expect(payload, {
      'completed': true,
      'responses': {
        'nausea': 'moderate', 'pallor': 'minimal', 'cold_sweating': 'none',
        'salivation': 'none', 'drowsiness': 'none', 'headache': 'none', 'dizziness': 'none',
      },
      'emesis': false, 'epigastric': 'none', 'facial_pallor': 'minimal',
    });
  });
  testWidgets('DVA respects reduced motion and disallows empty completion', (tester) async {
    await tester.pumpWidget(MaterialApp(home: MediaQuery(
      data: const MediaQueryData(disableAnimations: true),
      child: Scaffold(body: DvaGazeCard(onSubmit: (_) => fail('Empty result'),
        onDismiss: () {})))));
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Complete DVA')).onPressed, isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('starfield marks cells and submits distortion/misses', (tester) async {
    Map<String, dynamic>? payload;
    await _mount(tester, StarfieldDistortionCard(
        onSubmit: (p) => payload = p, onDismiss: () {}));
    await tester.tap(find.byKey(const ValueKey('amsler_grid')));
    await tester.pump();
    await tester.tap(find.text('Submit Starfield'));
    expect(payload!['distorted_cells'], isNotEmpty);
    expect(payload!['scotoma_misses'], 0);
    expect(payload!['distortion_index'], greaterThan(0));
  });
  testWidgets('near point slider submits reciprocal diopters and tier', (tester) async {
    Map<String, dynamic>? payload;
    await _mount(tester, NearPointDiopterCard(
        onSubmit: (p) => payload = p, onDismiss: () {}));
    await tester.drag(find.byType(Slider), const Offset(180, 0));
    await tester.pump();
    await tester.tap(find.text('Submit Near Point'));
    expect(payload!['near_focus_cm'], greaterThan(25));
    expect(payload!['delta_diopters'], greaterThan(0));
    expect(payload!['glasses_tier'], isA<String>());
  });
  testWidgets('LBNP cannot complete at -20; requires decompression', (tester) async {
    final payloads = <Map<String, dynamic>>[];
    await _mount(tester, LbnpRampCard(onSubmit: payloads.add, onDismiss: () {}));
    await tester.tap(find.text('Ramp -10'));
    await tester.pump();
    await tester.pump(const Duration(minutes: 3));
    await tester.tap(find.text('Hold -20'));
    await tester.pump();
    await tester.tap(find.text('Complete'));
    await tester.pump();
    expect(payloads.where((p) => p['completed'] == true), isEmpty);
    expect(find.textContaining('Safety lock'), findsOneWidget);
    await tester.pump(const Duration(minutes: 15));
    await tester.tap(find.text('Decompress -10'));
    await tester.pump();
    await tester.pump(const Duration(minutes: 3));
    await tester.tap(find.text('Complete'));
    await tester.pump();
    await tester.pump(const Duration(minutes: 2));
    await tester.tap(find.text('Complete'));
    await tester.pump();
    expect(payloads.last['completed'], true);
    expect(payloads.last['pressure_mmhg'], 0);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('launcher groups catalog and starts then closes', (tester) async {
    GuidedAssessmentDescriptor? launched;
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) =>
      Scaffold(body: TextButton(onPressed: () =>
        ApoloAssessmentLauncherSheet.show(context, onLaunch: (d) => launched = d),
        child: const Text('Open'))))));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('Microgravity / SMS'), findsOneWidget);
    await tester.tap(find.text('Start').first);
    await tester.pumpAndSettle();
    expect(launched!.id, GuidedAssessmentCatalog.all.first.id);
    expect(find.byType(ApoloAssessmentLauncherSheet), findsNothing);
  });
  testWidgets('LBNP emergency emits critical abort without claiming completion', (tester) async {
    Map<String, dynamic>? payload;
    await _mount(tester, LbnpRampCard(onSubmit: (p) => payload = p, onDismiss: () {}));
    await tester.tap(find.text('Emergency Release'));
    await tester.pump();
    expect(payload!['emergency_release'], true);
    expect(payload!['completed'], false);
    expect(payload!['pressure_mmhg'], 0);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('PVT measures elapsed tap latency rather than a preset result', (tester) async {
    Map<String, dynamic>? payload;
    await _mount(tester, PvtTestCard(onSubmit: (p) => payload = p, onDismiss: () {}));
    await tester.tap(find.text('Start reaction trial'));
    await tester.pump(const Duration(seconds: 5));
    expect(find.text('TAP NOW'), findsOneWidget);
    await tester.tap(find.text('TAP NOW'));
    await tester.pump();
    await tester.tap(find.text('Submit Reaction Test'));
    expect(payload!['reaction_times_ms'], hasLength(1));
    expect(payload!['mean_reaction_ms'], isNonNegative);
    expect(payload!['completed'], true);
    await tester.pumpWidget(const SizedBox());
  });
}
