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
    await tester.tap(find.text(situation.label));
    await tester.pump();
    expect(find.text(situation.symptomSummary), findsOneWidget);
    final procedure = MedicalProceduresData.findById(situation.recommendedProcedureId)!;
    expect(find.text(procedure.summary), findsOneWidget);
    expect(find.text(procedure.steps.last.action), findsOneWidget);
    await tester.tap(find.text('Live Telemetry'));
    await tester.pump();
    expect(find.text(situation.symptomSummary), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('offline card exposes full selected protocol and all scenarios', (tester) async {
    final procedure = MedicalProceduresData.findById('PROC-RADIATION-ARS')!;
    await tester.pumpWidget(ProviderScope(child: MaterialApp(home: Scaffold(
      body: SingleChildScrollView(child: MedicalProceduresCockpitCard(
        initialProcedureId: procedure.id, onDismiss: () {},
      )),
    ))));
    expect(find.text(procedure.title), findsWidgets);
    expect(find.text(procedure.priority.name.toUpperCase()), findsOneWidget);
    expect(find.text('Live Telemetry'), findsOneWidget);
    expect(find.byType(ChoiceChip), findsNWidgets(
      MedicalProceduresData.getScenarios().length + 1));
    for (final step in procedure.steps) {
      expect(find.text(step.action), findsOneWidget);
      expect(find.text(step.clinicalTip), findsWidgets);
    }
    for (final warning in procedure.warnings) {
      expect(find.text(warning), findsOneWidget);
    }
    for (final supply in procedure.requiredSupplies) {
      expect(find.textContaining(supply.name), findsWidgets);
    }
    expect(tester.widget<DropdownButton<String>>(find.byType(DropdownButton<String>))
      .items, hasLength(10));
  });
}
