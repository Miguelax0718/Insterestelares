import 'package:astramed/features/agent/domain/agent_contracts.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ToolResult truncates wire payload above 4000 characters', () {
    final huge = 'x' * 5000;
    final result = ToolResult.ok({'text': huge});
    final wire = result.toWireJson();
    expect(wire.length, lessThanOrEqualTo(4000));
    expect(wire, contains('truncated'));
  });

  test('ConsequentialAction and MemoryEntry round-trip through JSON', () {
    final now = DateTime.utc(2026, 11, 14, 12);
    final entry = MemoryEntry(
      id: 'm1',
      astronautId: 'AST-01',
      kind: MemoryKind.fact,
      summary: 'Allergic to penicillin',
      createdAt: now,
    );
    expect(MemoryEntry.fromJson(entry.toJson()).summary, entry.summary);

    final audit = AuditEntry(
      id: 'a1',
      astronautId: 'AST-01',
      actionType: 'block_eva',
      description: 'Block EVA for 24h',
      payload: const {'hours': 24},
      decision: ConfirmationDecision.confirmed,
      timestamp: now,
    );
    expect(AuditEntry.fromJson(audit.toJson()).decision, ConfirmationDecision.confirmed);
  });

  test('ComponentIds contains every planned component id', () {
    expect(ComponentIds.all, containsAll(<String>[
      ComponentIds.vitalsCard,
      ComponentIds.evaReadiness,
      ComponentIds.graybielQuestionnaire,
      ComponentIds.pvtTest,
      ComponentIds.sansGrid,
      ComponentIds.lbnpRamp,
      ComponentIds.diaryRecorder,
      ComponentIds.confirmAction,
    ]));
  });
}
