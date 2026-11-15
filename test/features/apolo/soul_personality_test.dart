import 'dart:io';

import 'package:astramed/features/agent/application/core_tools.dart';
import 'package:astramed/features/agent/domain/agent_contracts.dart';
import 'package:astramed/features/apolo/agent/apolo_urine_skill.dart';
import 'package:astramed/features/apolo/domain/apolo_models.dart';
import 'package:astramed/features/apolo/providers/apolo_contract_providers.dart';
import 'package:astramed/features/apolo/providers/apolo_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeUiSink implements AgentUiSink {
  @override
  void emit(AgentComponentEvent event) {}

  @override
  void submit(String componentId, Map<String, dynamic> result) {}
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

class _FakeAuditLog implements AuditLog {
  @override
  Future<void> append(AuditEntry entry) async {}

  @override
  Future<List<AuditEntry>> list({String? astronautId, int limit = 50}) async =>
      const [];
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
      const MedicationCheck(allowed: true, reasons: []);
}

ToolContext _makeCtx(
  ProviderContainer container, {
  String astronautId = 'AST-01',
}) {
  return ToolContext(
    astronautId: astronautId,
    read: <T>(provider) => container.read(provider as ProviderListenable<T>),
    ui: _FakeUiSink(),
    confirm: _FakeConfirmationGate(),
    audit: _FakeAuditLog(),
    memory: _FakeMemoryStore(),
    flags: _FakeFlagsStore(),
    medication: _FakeMedicationSafety(),
    now: DateTime.utc(2026, 11, 15, 10, 0),
  );
}

void main() {
  group('soul.md specification', () {
    test('exists and defines APOLO identity, Navi/TARS traits, TTS style, and critical zero-humor boundary', () {
      final file = File('soul.md');
      expect(
        file.existsSync(),
        isTrue,
        reason: 'soul.md must exist at repo root',
      );

      final text = file.readAsStringSync();
      final lower = text.toLowerCase();

      expect(text, contains('APOLO'));
      expect(lower, contains('dog'));
      expect(text, contains('Navi'));
      expect(text, contains('TARS'));
      expect(lower, contains('calm'));
      expect(lower, anyOf(contains('teas'), contains('playful')));
      expect(lower, contains('crit'));
      expect(
        lower,
        anyOf(
          contains('zero humor'),
          contains('no jokes'),
          contains('drop the jokes'),
        ),
      );
      expect(lower, contains('tts'));
    });
  });

  group('Runtime skill prompt persona wiring', () {
    test('coreSkill() keeps tool guidance and embeds APOLO Navi/TARS persona + critical safety rule', () {
      final skill = coreSkill();
      final lower = skill.instructions.toLowerCase();

      expect(skill.alwaysOn, isTrue);
      expect(
        skill.instructions,
        contains(
          'Use core tools to inspect live crew, vitals, and telemetry data, recall or save persistent astronaut memory, and show or hide UI components.',
        ),
      );
      expect(skill.instructions, contains('APOLO'));
      expect(lower, contains('calm'));
      expect(
        lower,
        anyOf(contains('teas'), contains('playful'), contains('wit')),
      );
      expect(
        lower,
        anyOf(contains('navi'), contains('nudge'), contains('persistent')),
      );
      expect(
        lower,
        anyOf(contains('tars'), contains('dry humor'), contains('dry wit')),
      );
      expect(
        lower,
        anyOf(contains('critical'), contains('emergenc'), contains('crit')),
      );
      expect(
        lower,
        anyOf(contains('no jokes'), contains('zero humor'), contains('drop')),
      );
    });

    test('ApoloUrineSkill() instructions match APOLO persona and critical safety boundary', () {
      final skill = ApoloUrineSkill();
      final lower = skill.instructions.toLowerCase();

      expect(skill.instructions, contains('APOLO'));
      expect(skill.instructions, contains('get_apolo_modules'));
      expect(skill.instructions, contains('log_water_intake'));
      expect(lower, contains('calm'));
      expect(
        lower,
        anyOf(contains('teas'), contains('playful'), contains('wit')),
      );
      expect(
        lower,
        anyOf(contains('critical'), contains('emergenc'), contains('crit')),
      );
      expect(
        lower,
        anyOf(contains('no jokes'), contains('zero humor'), contains('drop')),
      );
    });

    test('coreSkill() and ApoloUrineSkill() instructions stay within gateway 2000-char limit', () {
      expect(coreSkill().instructions.length, lessThanOrEqualTo(2000));
      expect(ApoloUrineSkill().instructions.length, lessThanOrEqualTo(2000));
    });
  });

  group('ApoloUrineOfflineFlow in character', () {
    test('greets in character for warn, stays direct without jokes on crit, and logs water + inspects module', () async {
      final container = ProviderContainer(overrides: apoloProviderOverrides);
      addTearDown(container.dispose);

      final flow = ApoloUrineSkill().offlineFlow!;

      // AST-01 (warn state: hydration + renal) -> calm, gently nudging
      final warnCtx = _makeCtx(container, astronautId: 'AST-01');
      final warnStart = await flow.start(warnCtx);
      expect(warnStart.prompt, isNotEmpty);
      expect(warnStart.prompt.toLowerCase(), contains('attention'));

      // Water logging preserves exact ml & goal progress with playful Navi/TARS touch
      final waterStep = await flow.advance('I drank 500 ml', warnCtx);
      expect(waterStep.prompt, contains('500 ml'));
      expect(container.read(apoloActiveStateProvider).waterMlToday, 2200);

      // Module inspection preserves module title, metrics, and orb reveal
      final renalStep = await flow.advance('how are my kidneys?', warnCtx);
      expect(renalStep.prompt.toLowerCase(), contains('renal'));
      expect(
        container.read(apoloActiveStateProvider).visibleOrbs,
        contains(ApoloModuleId.renal),
      );

      // AST-03 (crit state: radiation) -> direct and calm, no jokes
      final critCtx = _makeCtx(container, astronautId: 'AST-03');
      final critStart = await flow.start(critCtx);
      expect(critStart.prompt.toLowerCase(), contains('critical'));
      expect(critStart.prompt.toLowerCase(), isNot(contains('woof')));
      expect(critStart.prompt.toLowerCase(), isNot(contains('haha')));

      // AST-CUSTOM-99 (all ok state) -> warm/playful greeting
      final okCtx = _makeCtx(container, astronautId: 'AST-CUSTOM-99');
      final okStart = await flow.start(okCtx);
      expect(okStart.prompt, isNotEmpty);
    });
  });
}
