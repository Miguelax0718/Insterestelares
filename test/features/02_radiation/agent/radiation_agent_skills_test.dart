import 'dart:convert';

import 'package:astramed/features/02_radiation/agent/donki_space_weather_service.dart';
import 'package:astramed/features/02_radiation/agent/radiation_agent_skills.dart';
import 'package:astramed/features/agent/domain/agent_contracts.dart';
import 'package:astramed/features/pharmacy/data/asset_pharmacy_inventory_repository.dart';
import 'package:astramed/features/pharmacy/domain/deterministic_medication_safety.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class _FakeUiSink implements AgentUiSink {
  final List<AgentComponentEvent> events = [];

  @override
  void emit(AgentComponentEvent event) => events.add(event);

  @override
  void submit(String componentId, Map<String, dynamic> result) {}
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
  Future<Map<String, dynamic>?> getFlag(String astronautId, String key) async {
    return store[astronautId]?[key];
  }

  @override
  Future<void> setFlag(
    String astronautId,
    String key,
    Map<String, dynamic> value,
  ) async {
    store.putIfAbsent(astronautId, () => {})[key] = value;
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
  _FakeConfirmationGate(this.decision);

  final ConfirmationDecision decision;
  final List<ConsequentialAction> requested = [];
  ConsequentialAction? _pending;

  @override
  ConsequentialAction? get pending => _pending;

  @override
  Future<ConfirmationDecision> request(
    ConsequentialAction action, {
    required Future<Map<String, dynamic>> Function() onConfirmed,
  }) async {
    requested.add(action);
    _pending = action;
    if (decision == ConfirmationDecision.confirmed) {
      await onConfirmed();
    }
    _pending = null;
    return decision;
  }

  @override
  Future<Map<String, dynamic>?> resolve(
    String actionId,
    ConfirmationDecision decision, {
    String? reason,
  }) async => null;
}

ToolContext _makeContext({
  required ConfirmationDecision decision,
  required AssetPharmacyInventoryRepository repo,
  _FakeFlagsStore? flags,
  _FakeAuditLog? audit,
  _FakeUiSink? ui,
}) {
  final f = flags ?? _FakeFlagsStore();
  return ToolContext(
    astronautId: 'AST-01',
    read: <T>(provider) => throw UnimplementedError(),
    ui: ui ?? _FakeUiSink(),
    confirm: _FakeConfirmationGate(decision),
    audit: audit ?? _FakeAuditLog(),
    memory: _NoopMemoryStore(),
    flags: f,
    medication: DeterministicMedicationSafety(repository: repo, flags: f),
    now: DateTime.utc(2026, 11, 14, 12, 0),
  );
}

class _NoopMemoryStore implements MemoryStore {
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DonkiSpaceWeatherService', () {
    test('parses online DONKI FLR and SEP responses and caches snapshot', () async {
      var calls = 0;
      final client = MockClient((request) async {
        calls++;
        expect(request.url.queryParameters['api_key'], 'TEST_KEY');
        if (request.url.path.endsWith('/DONKI/FLR')) {
          return http.Response(
            jsonEncode([
              {
                'flrID': '2026-11-14T10:00:00-FLR-001',
                'beginTime': '2026-11-14T10:00Z',
                'peakTime': '2026-11-14T10:20Z',
                'endTime': '2026-11-14T10:45Z',
                'classType': 'X2.4',
                'sourceLocation': 'S15W40',
                'activeRegionNum': 13842,
              },
            ]),
            200,
          );
        }
        if (request.url.path.endsWith('/DONKI/SEP')) {
          return http.Response(
            jsonEncode([
              {
                'sepID': '2026-11-14T11:00:00-SEP-001',
                'eventTime': '2026-11-14T11:00Z',
                'peakFluxPfu': 1800.0,
                'durationHours': 20.0,
                'instruments': [
                  {'displayName': 'SOHO: COSTEP'},
                ],
              },
            ]),
            200,
          );
        }
        return http.Response('Not Found', 404);
      });

      final service = DonkiSpaceWeatherService(
        client: client,
        apiKey: 'TEST_KEY',
      );
      final snapshot = await service.fetchLatest(
        now: DateTime.utc(2026, 11, 14, 12, 0),
      );

      expect(calls, 2);
      expect(snapshot.isOfflineFallback, isFalse);
      expect(snapshot.source, 'donki_live');
      expect(snapshot.stormActive, isTrue);
      expect(snapshot.maxEventClass, 'X2.4');
      expect(snapshot.peakFluxPfu, 1800.0);
      expect(snapshot.durationHours, 20.0);
      expect(snapshot.flares.length, 1);
      expect(snapshot.sepEvents.length, 1);
      expect(service.cachedSnapshot, isNotNull);
    });

    test('falls back deterministically to bundled snapshot when offline or on HTTP error', () async {
      final failingClient = MockClient(
        (_) async => http.Response('Service Unavailable', 503),
      );
      final service = DonkiSpaceWeatherService(client: failingClient);
      final snapshot = await service.fetchLatest(
        now: DateTime.utc(2026, 11, 14, 12, 0),
      );

      expect(snapshot.isOfflineFallback, isTrue);
      expect(snapshot.source, 'offline_fallback');
      expect(snapshot.stormActive, isTrue);
      expect(snapshot.peakFluxPfu, greaterThan(0));
      expect(snapshot.maxEventClass, isNotEmpty);
    });

    test('uses cached snapshot when a subsequent fetch fails', () async {
      var fail = false;
      final client = MockClient((request) async {
        if (fail) {
          throw Exception('Network unreachable');
        }
        if (request.url.path.endsWith('/DONKI/FLR')) {
          return http.Response(
            jsonEncode([
              {
                'flrID': 'FLR-CACHED',
                'beginTime': '2026-11-14T08:00Z',
                'peakTime': '2026-11-14T08:15Z',
                'classType': 'M6.5',
              },
            ]),
            200,
          );
        }
        return http.Response(
          jsonEncode([
            {
              'sepID': 'SEP-CACHED',
              'eventTime': '2026-11-14T08:30Z',
              'peakFluxPfu': 450.0,
              'durationHours': 12.0,
            },
          ]),
          200,
        );
      });

      final service = DonkiSpaceWeatherService(client: client);
      final first = await service.fetchLatest();
      expect(first.maxEventClass, 'M6.5');

      fail = true;
      final second = await service.fetchLatest();
      expect(second.isOfflineFallback, isTrue);
      expect(second.source, 'cache');
      expect(second.maxEventClass, 'M6.5');
      expect(second.peakFluxPfu, 450.0);
    });
  });

  group('radiationAndPharmacySkills', () {
    late AssetPharmacyInventoryRepository repo;
    late DonkiSpaceWeatherService weatherService;
    late List<AgentSkill> skills;
    late AgentSkill spaceWeatherSkill;
    late AgentSkill medicationSkill;

    setUp(() async {
      repo = AssetPharmacyInventoryRepository();
      await repo.getBatches();
      weatherService = DonkiSpaceWeatherService(
        client: MockClient((_) async => http.Response('offline', 503)),
      );
      skills = radiationAndPharmacySkills(
        spaceWeatherService: weatherService,
        pharmacyRepository: repo,
      );
      spaceWeatherSkill = skills.firstWhere((s) => s.id == 'space_weather');
      medicationSkill = skills.firstWhere((s) => s.id == 'medication');
    });

    AgentTool toolNamed(AgentSkill skill, String name) =>
        skill.tools.firstWhere((t) => t.name == name);

    test('get_space_weather and assess_pharmacy_radiation emit typed view-models without mutating repo', () async {
      final ctx = _makeContext(
        decision: ConfirmationDecision.confirmed,
        repo: repo,
      );

      final weatherRes = await toolNamed(
        spaceWeatherSkill,
        'get_space_weather',
      ).call(const {}, ctx);
      expect(weatherRes.ok, isTrue);
      expect(weatherRes.uiEvents, isNotEmpty);
      final weatherEvent = weatherRes.uiEvents.first as ShowComponentEvent;
      expect(weatherEvent.id, ComponentIds.spaceWeatherAlert);
      final weatherVm = SpaceWeatherAlertViewModel.fromProps(weatherEvent.props);
      expect(weatherVm.stormActive, isTrue);

      final assessRes = await toolNamed(
        spaceWeatherSkill,
        'assess_pharmacy_radiation',
      ).call({'sep_flux_pfu': 1500, 'duration_hours': 24, 'event_class': 'X2.2'}, ctx);
      expect(assessRes.ok, isTrue);
      final batchesEvent = assessRes.uiEvents.first as ShowComponentEvent;
      expect(batchesEvent.id, ComponentIds.pharmacyBatches);
      final batchesVm = PharmacyBatchesViewModel.fromProps(batchesEvent.props);
      expect(batchesVm.ramanVerificationRequired, isTrue);

      final hullBatch = await repo.getBatchById('BATCH-PARA-01');
      expect(hullBatch!.flagged, isFalse);
    });

    test('consequential tools do NOT mutate state when confirmation is rejected', () async {
      final flags = _FakeFlagsStore();
      final audit = _FakeAuditLog();
      final ctx = _makeContext(
        decision: ConfirmationDecision.rejected,
        repo: repo,
        flags: flags,
        audit: audit,
      );

      final flagRes = await toolNamed(
        spaceWeatherSkill,
        'flag_batches',
      ).call({
        'batch_ids': ['BATCH-PARA-01'],
        'reason': 'SPE degradation >= 15%',
      }, ctx);
      expect(flagRes.ok, isTrue);
      expect(flagRes.data['confirmed'], isFalse);
      expect((await repo.getBatchById('BATCH-PARA-01'))!.flagged, isFalse);
      expect(await flags.getFlag('AST-01', 'flagged_batches'), isNull);

      final ramanRes = await toolNamed(
        spaceWeatherSkill,
        'request_raman_check',
      ).call({
        'batch_ids': ['BATCH-PARA-01'],
        'reason': 'Post-storm potency verification',
      }, ctx);
      expect(ramanRes.data['confirmed'], isFalse);
      expect(ramanRes.uiEvents, isEmpty);
      expect(await flags.getFlag('AST-01', 'raman_check_requested'), isNull);

      final leukRes = await toolNamed(
        spaceWeatherSkill,
        'schedule_leukocyte_count',
      ).call({'hours_after_peak': [24, 72]}, ctx);
      expect(leukRes.data['confirmed'], isFalse);
      expect(await flags.getFlag('AST-01', 'leukocyte_check_scheduled'), isNull);
      expect(audit.entries, isEmpty);
    });

    test('consequential tools DO mutate state, emit UI, and audit when confirmed', () async {
      final flags = _FakeFlagsStore();
      final audit = _FakeAuditLog();
      final ctx = _makeContext(
        decision: ConfirmationDecision.confirmed,
        repo: repo,
        flags: flags,
        audit: audit,
      );

      final flagRes = await toolNamed(
        spaceWeatherSkill,
        'flag_batches',
      ).call({
        'batch_ids': ['BATCH-PARA-01', 'BATCH-IBUP-01'],
        'reason': 'SPE degradation >= 15%',
      }, ctx);
      expect(flagRes.ok, isTrue);
      expect(flagRes.data['confirmed'], isTrue);
      expect((await repo.getBatchById('BATCH-PARA-01'))!.flagged, isTrue);
      expect((await repo.getBatchById('BATCH-IBUP-01'))!.flagged, isTrue);
      final flaggedFlag = await flags.getFlag('AST-01', 'flagged_batches');
      expect(flaggedFlag?['batch_ids'], containsAll(['BATCH-PARA-01', 'BATCH-IBUP-01']));

      final ramanRes = await toolNamed(
        spaceWeatherSkill,
        'request_raman_check',
      ).call({
        'batch_ids': ['BATCH-PARA-01'],
        'reason': 'Verify potency after SPE',
      }, ctx);
      expect(ramanRes.data['confirmed'], isTrue);
      final ramanEvent = ramanRes.uiEvents.first as ShowComponentEvent;
      expect(ramanEvent.id, ComponentIds.ramanRequest);
      final ramanVm = RamanRequestViewModel.fromProps(ramanEvent.props);
      expect(ramanVm.batchIds, ['BATCH-PARA-01']);
      expect(await flags.getFlag('AST-01', 'raman_check_requested'), isNotNull);

      final leukRes = await toolNamed(
        spaceWeatherSkill,
        'schedule_leukocyte_count',
      ).call({'hours_after_peak': [24, 72]}, ctx);
      expect(leukRes.data['confirmed'], isTrue);
      expect(await flags.getFlag('AST-01', 'leukocyte_check_scheduled'), isNotNull);

      expect(audit.entries.length, 3);
      expect(
        audit.entries.map((e) => e.actionType),
        containsAll(['flag_batches', 'request_raman_check', 'schedule_leukocyte_count']),
      );
    });

    test('check_medication delegates to MedicationSafety and emits medication_check view-model', () async {
      final ctx = _makeContext(
        decision: ConfirmationDecision.confirmed,
        repo: repo,
      );

      final res = await toolNamed(
        medicationSkill,
        'check_medication',
      ).call({
        'astronaut_id': 'AST-02',
        'medication': 'promethazine',
        'dose_mg': 25,
        'route': 'oral',
      }, ctx);

      expect(res.ok, isTrue);
      expect(res.data['allowed'], isFalse);
      final event = res.uiEvents.first as ShowComponentEvent;
      expect(event.id, ComponentIds.medicationCheck);
      final vm = MedicationCheckViewModel.fromProps(event.props);
      expect(vm.allowed, isFalse);
      expect(vm.reasons.join(' ').toLowerCase(), contains('allergic'));
    });

    test('space_weather offlineFlow assesses storm and gates consequential actions without LLM', () async {
      final flags = _FakeFlagsStore();
      final audit = _FakeAuditLog();
      final ctx = _makeContext(
        decision: ConfirmationDecision.confirmed,
        repo: repo,
        flags: flags,
        audit: audit,
      );

      final flow = spaceWeatherSkill.offlineFlow;
      expect(flow, isNotNull);

      final startStep = await flow!.start(ctx);
      expect(startStep.isTerminal, isFalse);
      expect(
        startStep.uiEvents.whereType<ShowComponentEvent>().map((e) => e.id),
        containsAll([ComponentIds.spaceWeatherAlert, ComponentIds.pharmacyBatches]),
      );

      final endStep = await flow.advance('Confirm all actions', ctx);
      expect(endStep.isTerminal, isTrue);
      expect(endStep.verdict?['confirmed'], isTrue);
      expect((await repo.getBatchById('BATCH-PARA-01'))!.flagged, isTrue);
      expect(audit.entries.length, 3);
    });
  });
}
