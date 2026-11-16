import 'package:astramed/features/05_clinical_triage/data/medical_procedures_data.dart';
import 'package:astramed/features/05_clinical_triage/presentation/cockpit_widgets/medical_procedures_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('offline catalog and scenarios expose English clinical content', () {
    expect(MedicalProceduresData.getProcedures().first.title,
      'Cardiac Arrest and Microgravity CPR (Space ACLS)');
    expect(MedicalProceduresData.getScenarios().first.label, 'Cardiac Arrest (CPR)');
    expect(MedicalProceduresData.getProcedures().last.title,
      'Critical Sleep Deficit, Cognitive Fatigue and Stress');
  });
  testWidgets('situation selector switches protocols using the shared catalog', (tester) async {
    await tester.pumpWidget(ProviderScope(child: MaterialApp(home: Scaffold(
      body: SingleChildScrollView(child: MedicalProceduresCockpitCard(onDismiss: () {})),
    ))));
    final situation = MedicalProceduresData.getScenarios().last;
    final situationToggle = find.byKey(const ValueKey('procedures_situation_toggle'));
    await tester.ensureVisible(situationToggle);
    await tester.tap(situationToggle);
    await tester.pump();
    await tester.ensureVisible(find.text(situation.label));
    await tester.tap(find.text(situation.label));
    await tester.pump();
    expect(find.text(situation.symptomSummary), findsOneWidget);
    final procedure = MedicalProceduresData.findById(situation.recommendedProcedureId)!;
    expect(find.text(procedure.summary), findsOneWidget);
    expect(find.text(procedure.steps.first.action), findsOneWidget);
    await tester.ensureVisible(find.text('Live Telemetry'));
    await tester.tap(find.text('Live Telemetry'));
    await tester.pump();
    expect(find.text(situation.symptomSummary), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('compact guide navigates steps and expands references on demand', (tester) async {
    final procedure = MedicalProceduresData.findById('PROC-RADIATION-ARS')!;
    await tester.pumpWidget(ProviderScope(child: MaterialApp(home: Scaffold(
      body: SingleChildScrollView(child: MedicalProceduresCockpitCard(
        initialProcedureId: procedure.id, onDismiss: () {},
      )),
    ))));
    expect(find.text(procedure.title), findsWidgets);
    expect(find.text('CRITICAL'), findsOneWidget);
    expect(find.text('Step 1 of ${procedure.steps.length}'), findsOneWidget);
    expect(find.byType(ChoiceChip), findsNothing);
    expect(find.text(procedure.steps.last.action), findsNothing);
    for (final text in [...procedure.warnings, ...procedure.whenToActivate]) {
      expect(find.text(text), findsNothing);
    }
    for (final supply in procedure.requiredSupplies) {
      expect(find.byKey(ValueKey('procedure-supply-${supply.itemId}')), findsNothing);
    }
    final previous = find.byKey(const ValueKey('procedure_prev_step'));
    final next = find.byKey(const ValueKey('procedure_next_step'));
    expect(tester.widget<OutlinedButton>(previous).onPressed, isNull);
    for (var i = 1; i < procedure.steps.length; i++) {
      await tester.ensureVisible(next);
      await tester.tap(next);
      await tester.pump();
      expect(find.text('Step ${i + 1} of ${procedure.steps.length}'), findsOneWidget);
      expect(find.text(procedure.steps[i].action), findsOneWidget);
      expect(find.text(procedure.steps[i - 1].action), findsNothing);
    }
    expect(tester.widget<FilledButton>(next).onPressed, isNull);
    await tester.tap(previous);
    await tester.pump();
    expect(find.text(procedure.steps[procedure.steps.length - 2].action), findsOneWidget);
    final all = find.byKey(const ValueKey('procedure_all_steps_toggle'));
    await tester.ensureVisible(all);
    await tester.tap(all);
    await tester.pump();
    for (final step in procedure.steps) {
      expect(find.text(step.action), findsOneWidget);
      expect(find.text(step.clinicalTip), findsWidgets);
    }
    await tester.ensureVisible(all);
    await tester.tap(all);
    await tester.pump();
    expect(find.text(procedure.steps.first.action), findsNothing);
    for (final section in ['warnings', 'supplies', 'activate', 'reference']) {
      final toggle = find.byKey(ValueKey('procedures_${section}_toggle'));
      await tester.ensureVisible(toggle);
      await tester.tap(toggle);
      await tester.pump();
    }
    for (final warning in procedure.warnings) {
      expect(find.text(warning), findsOneWidget);
    }
    for (final supply in procedure.requiredSupplies) {
      expect(find.textContaining(supply.name), findsWidgets);
    }
    for (final trigger in procedure.whenToActivate) {
      expect(find.text(trigger), findsOneWidget);
    }
    expect(find.text(procedure.criterionReference), findsOneWidget);
    expect(tester.widget<DropdownButton<String>>(find.byType(DropdownButton<String>))
      .items, hasLength(10));
  });
  for (final width in [360.0, 700.0]) {
    for (final procedure in MedicalProceduresData.getProcedures()) {
      testWidgets('${procedure.code} is readable at ${width}px', (tester) async {
        await tester.binding.setSurfaceSize(Size(width, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(ProviderScope(child: MaterialApp(home: Scaffold(
          body: SingleChildScrollView(child: MedicalProceduresCockpitCard(
            initialProcedureId: procedure.id, onDismiss: () {},
          )),
        ))));
        expect(find.textContaining('• Offline Guide'), findsOneWidget);
        expect(find.text('Situation triage: Live Telemetry'), findsOneWidget);
        expect(find.text(procedure.code), findsOneWidget);
        expect(find.text('Step 1 of ${procedure.steps.length}'), findsOneWidget);
        for (final section in ['all_steps', 'warnings', 'supplies', 'activate', 'reference', 'situation']) {
          final key = section == 'all_steps'
            ? 'procedure_all_steps_toggle' : 'procedures_${section}_toggle';
          final toggle = find.byKey(ValueKey(key));
          await tester.ensureVisible(toggle);
          await tester.tap(toggle);
          await tester.pump();
          expect(tester.takeException(), isNull);
        }
        for (final step in procedure.steps) {
          expect(find.byKey(ValueKey('procedure-step-${step.step}')), findsOneWidget);
          expect(find.text('${step.step}'), findsOneWidget);
          expect(find.text('~${step.durationSeconds}s'), findsWidgets);
          expect(find.text(step.title), findsOneWidget);
          expect(find.text(step.action), findsOneWidget);
          expect(find.text(step.clinicalTip), findsWidgets);
        }
        expect(find.text('Clinical Tip'), findsNWidgets(procedure.steps.length));
        expect(find.byKey(const ValueKey('clinical-warnings')), findsOneWidget);
        for (final warning in procedure.warnings) {
          expect(find.text(warning), findsOneWidget);
        }
        for (final supply in procedure.requiredSupplies) {
          expect(find.byKey(ValueKey('procedure-supply-${supply.itemId}')), findsOneWidget);
          expect(find.text(supply.name), findsWidgets);
          expect(find.text(supply.location), findsWidgets);
          expect(find.text(supply.usage), findsWidgets);
        }
        final picker = tester.widget<DropdownButton<String>>(
          find.byType(DropdownButton<String>));
        expect(picker.items, hasLength(10));
        expect(picker.value, procedure.id);
        expect(find.text(procedure.criterionReference), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
    testWidgets('all situations and live telemetry switch at ${width}px', (tester) async {
      await tester.binding.setSurfaceSize(Size(width, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(ProviderScope(child: MaterialApp(home: Scaffold(
        body: SingleChildScrollView(child: MedicalProceduresCockpitCard(onDismiss: () {})),
      ))));
      await tester.tap(find.byKey(const ValueKey('procedures_situation_toggle')));
      await tester.pump();
      for (final scenario in MedicalProceduresData.getScenarios()) {
        await tester.ensureVisible(find.text(scenario.label));
        await tester.tap(find.text(scenario.label));
        await tester.pump();
        expect(find.text('First 60 Seconds'), findsOneWidget);
        expect(find.text(scenario.symptomSummary), findsOneWidget);
        for (final action in [...scenario.first60Seconds, ...scenario.verificationQuestions]) {
          expect(find.text(action), findsWidgets);
        }
        for (final supply in scenario.emergencySupplies) {
          expect(find.text(supply), findsWidgets);
        }
        final procedure = MedicalProceduresData.findById(scenario.recommendedProcedureId)!;
        expect(find.text(procedure.summary), findsOneWidget);
        expect(find.text('Step 1 of ${procedure.steps.length}'), findsOneWidget);
        final next = find.byKey(const ValueKey('procedure_next_step'));
        await tester.ensureVisible(next);
        await tester.tap(next);
        await tester.pump();
        expect(tester.takeException(), isNull);
      }
      await tester.ensureVisible(find.text('Live Telemetry'));
      await tester.tap(find.text('Live Telemetry'));
      await tester.pump();
      expect(find.text('First 60 Seconds'), findsNothing);
      expect(find.text('Matched to live telemetry'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
    testWidgets('protocol picker and dismissal work at ${width}px', (tester) async {
      await tester.binding.setSurfaceSize(Size(width, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      var dismissed = false;
      await tester.pumpWidget(ProviderScope(child: MaterialApp(home: Scaffold(
        body: SingleChildScrollView(child: MedicalProceduresCockpitCard(
          onDismiss: () => dismissed = true,
        )),
      ))));
      final catalog = MedicalProceduresData.getProcedures();
      for (final procedure in [catalog.last, catalog.first]) {
        final picker = find.byType(DropdownButton<String>);
        await tester.ensureVisible(picker);
        await tester.tap(picker);
        await tester.pumpAndSettle();
        final option = find.text(procedure.title).last;
        await tester.ensureVisible(option);
        await tester.tap(option);
        await tester.pumpAndSettle();
        expect(tester.widget<DropdownButton<String>>(picker).value, procedure.id);
        expect(find.text(procedure.summary), findsOneWidget);
        expect(find.text('Step 1 of ${procedure.steps.length}'), findsOneWidget);
        final next = find.byKey(const ValueKey('procedure_next_step'));
        await tester.ensureVisible(next);
        await tester.tap(next);
        await tester.pump();
        expect(find.text('Matched to live telemetry'), findsNothing);
        expect(tester.takeException(), isNull);
      }
      await tester.ensureVisible(find.byTooltip('Dismiss'));
      await tester.tap(find.byTooltip('Dismiss'));
      expect(dismissed, isTrue);
    });
  }
}
