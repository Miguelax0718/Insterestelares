import 'package:astramed/features/agent/domain/agent_contracts.dart';
import 'package:astramed/features/pharmacy/data/asset_pharmacy_inventory_repository.dart';
import 'package:astramed/features/pharmacy/domain/astropharmacy_engine.dart';
import 'package:astramed/features/pharmacy/domain/deterministic_medication_safety.dart';
import 'package:astramed/features/pharmacy/domain/medication_batch.dart';
import 'package:astramed/features/pharmacy/domain/pharmacy_inventory_repository.dart';
import 'package:flutter_test/flutter_test.dart';

class _InMemoryFlagsStore implements AgentFlagsStore {
  final Map<String, Map<String, Map<String, dynamic>>> _flags = {};

  @override
  Future<Map<String, Map<String, dynamic>>> allForAstronaut(
    String astronautId,
  ) async {
    return Map<String, Map<String, dynamic>>.from(
      _flags[astronautId] ?? const {},
    );
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Seed pharmacy assets', () {
    test('loads medication_inventory.json and crew_allergies.json from DB/Pharmacy', () async {
      final repo = AssetPharmacyInventoryRepository();
      final batches = await repo.getBatches();
      expect(batches.length, greaterThanOrEqualTo(7));
      expect(
        batches.map((b) => b.medication).toSet(),
        containsAll(<String>{
          'paracetamol',
          'promethazine',
          'modafinil',
          'zolpidem',
          'ibuprofen',
          'ondansetron',
          'potassium_citrate',
        }),
      );

      final ast02Allergies = await repo.getAllergies('AST-02');
      expect(ast02Allergies.isAllergicTo('promethazine'), isTrue);

      final ast03Allergies = await repo.getAllergies('AST-03');
      expect(ast03Allergies.isAllergicTo('ibuprofen'), isTrue);
    });
  });

  group('DeterministicMedicationSafety', () {
    late PharmacyInventoryRepository repo;
    late _InMemoryFlagsStore flags;
    late DeterministicMedicationSafety safety;

    setUp(() async {
      repo = AssetPharmacyInventoryRepository();
      await repo.getBatches();
      flags = _InMemoryFlagsStore();
      safety = DeterministicMedicationSafety(repository: repo, flags: flags);
    });

    test('allows valid paracetamol dose for AST-01', () async {
      final check = await safety.validate(
        const MedicationRequest(
          astronautId: 'AST-01',
          medication: 'paracetamol',
          doseMg: 500,
          route: 'oral',
        ),
      );
      expect(check.allowed, isTrue);
      expect(check.batchId, 'BATCH-PARA-01');
      expect(check.remainingUnits, 24);
      expect(check.suggestedAlternativeRoute, isNull);
    });

    test('blocks overdose exceeding max_single_dose_mg and non-positive doses', () async {
      final over = await safety.validate(
        const MedicationRequest(
          astronautId: 'AST-01',
          medication: 'paracetamol',
          doseMg: 1500,
          route: 'oral',
        ),
      );
      expect(over.allowed, isFalse);
      expect(over.reasons.join(' ').toLowerCase(), contains('max single dose'));

      final zero = await safety.validate(
        const MedicationRequest(
          astronautId: 'AST-01',
          medication: 'paracetamol',
          doseMg: 0,
          route: 'oral',
        ),
      );
      expect(zero.allowed, isFalse);
      expect(zero.reasons.join(' ').toLowerCase(), contains('greater than 0'));
    });

    test('blocks unverified medication not present in inventory', () async {
      final check = await safety.validate(
        const MedicationRequest(
          astronautId: 'AST-01',
          medication: 'unknown_experimental_compound',
          doseMg: 100,
          route: 'oral',
        ),
      );
      expect(check.allowed, isFalse);
      expect(check.reasons.join(' ').toLowerCase(), contains('not found'));
    });

    test('blocks allergic astronaut (AST-02 + promethazine, AST-03 + ibuprofen)', () async {
      final promCheck = await safety.validate(
        const MedicationRequest(
          astronautId: 'AST-02',
          medication: 'promethazine',
          doseMg: 25,
          route: 'intramuscular',
        ),
      );
      expect(promCheck.allowed, isFalse);
      expect(promCheck.reasons.join(' ').toLowerCase(), contains('allergic'));

      final ibupCheck = await safety.validate(
        const MedicationRequest(
          astronautId: 'AST-03',
          medication: 'ibuprofen',
          doseMg: 400,
          route: 'oral',
        ),
      );
      expect(ibupCheck.allowed, isFalse);
      expect(ibupCheck.reasons.join(' ').toLowerCase(), contains('allergic'));
    });

    test('blocks flagged and radiation-degraded (>=15%) batches', () async {
      await repo.flagBatch('BATCH-MODA-01', reason: 'Raman check failed');
      final flaggedCheck = await safety.validate(
        const MedicationRequest(
          astronautId: 'AST-01',
          medication: 'modafinil',
          doseMg: 100,
          route: 'oral',
        ),
      );
      expect(flaggedCheck.allowed, isFalse);
      expect(flaggedCheck.reasons.join(' ').toLowerCase(), contains('flagged'));

      await repo.updateDegradation('BATCH-ZOLP-01', 16.5);
      final degradedCheck = await safety.validate(
        const MedicationRequest(
          astronautId: 'AST-01',
          medication: 'zolpidem',
          doseMg: 5,
          route: 'oral',
        ),
      );
      expect(degradedCheck.allowed, isFalse);
      expect(degradedCheck.reasons.join(' ').toLowerCase(), contains('degraded'));
    });

    test('blocks zero stock batches', () async {
      final depletedRepo = AssetPharmacyInventoryRepository.fromMemory(
        batches: [
          const MedicationBatch(
            batchId: 'BATCH-EMPTY-01',
            medication: 'modafinil',
            drugClass: 'stimulant',
            route: 'oral',
            unitMg: 100,
            maxSingleDoseMg: 200,
            maxDailyDoseMg: 400,
            unitsRemaining: 0,
            storageLocation: 'core_vault_B',
            shieldingFactor: 0.9,
            radiationSensitivity: 0.3,
            degradationPct: 0,
            flagged: false,
            contraindicatedWith: [],
          ),
        ],
        allergies: const {},
      );
      final depletedSafety = DeterministicMedicationSafety(
        repository: depletedRepo,
        flags: flags,
      );
      final check = await depletedSafety.validate(
        const MedicationRequest(
          astronautId: 'AST-01',
          medication: 'modafinil',
          doseMg: 100,
          route: 'oral',
        ),
      );
      expect(check.allowed, isFalse);
      expect(check.reasons.join(' ').toLowerCase(), contains('stock'));
    });

    test('blocks oral route and suggests intranasal when eva_gastric_stasis flag is set', () async {
      await flags.setFlag('AST-01', 'eva_gastric_stasis', {'active': true});

      final check = await safety.validate(
        const MedicationRequest(
          astronautId: 'AST-01',
          medication: 'paracetamol',
          doseMg: 500,
          route: 'oral',
        ),
      );
      expect(check.allowed, isFalse);
      expect(check.suggestedAlternativeRoute, 'intranasal');
      expect(check.reasons.join(' ').toLowerCase(), contains('gastric stasis'));
    });

    test('suggests non-oral alternative when only non-oral batch is unflagged', () async {
      await repo.flagBatch('BATCH-PARA-01', reason: 'SPE degradation');

      final check = await safety.validate(
        const MedicationRequest(
          astronautId: 'AST-01',
          medication: 'paracetamol',
          doseMg: 500,
          route: 'oral',
        ),
      );
      expect(check.allowed, isFalse);
      expect(check.suggestedAlternativeRoute, 'intranasal');
    });
  });

  group('PharmacyInventoryRepository & AstropharmacyEngine', () {
    test('deducts doses and tracks cumulative radiation exposure', () async {
      final repo = AssetPharmacyInventoryRepository();
      final updated = await repo.deductDose('BATCH-PARA-01', 2);
      expect(updated.unitsRemaining, 22);

      await repo.addRadiationExposure(12.5);
      await repo.addRadiationExposure(7.5);
      expect(repo.cumulativeRadiationMsv, closeTo(20.0, 0.001));
    });

    test('solar storm degrades hull locker batch above 15% while shielded vault stays safe', () async {
      final repo = AssetPharmacyInventoryRepository();
      final batches = await repo.getBatches();
      const engine = AstropharmacyEngine();
      final peak = DateTime.utc(2026, 11, 14, 12, 0);

      final assessment = engine.assessStorm(
        batches: batches,
        sepFluxPfu: 1500,
        durationHours: 24,
        eventClass: 'X2.2',
        peakTime: peak,
      );

      final hullBatch = assessment.batchAssessments.firstWhere(
        (a) => a.batch.batchId == 'BATCH-PARA-01',
      );
      final shieldedBatch = assessment.batchAssessments.firstWhere(
        (a) => a.batch.batchId == 'BATCH-PARA-02',
      );

      expect(hullBatch.batch.storageLocation, 'hull_locker_A');
      expect(hullBatch.projectedDegradationPct, greaterThanOrEqualTo(15.0));
      expect(hullBatch.compromised, isTrue);

      expect(shieldedBatch.batch.storageLocation, 'med_bay_shielded');
      expect(shieldedBatch.projectedDegradationPct, lessThan(15.0));
      expect(shieldedBatch.compromised, isFalse);

      expect(
        assessment.compromisedBatches.map((b) => b.batchId),
        contains('BATCH-PARA-01'),
      );
      expect(
        assessment.compromisedBatches.map((b) => b.batchId),
        isNot(contains('BATCH-PARA-02')),
      );
      expect(assessment.ramanVerificationRequired, isTrue);
      expect(
        assessment.leukocyteCheckTimes,
        equals([
          peak.add(const Duration(hours: 24)),
          peak.add(const Duration(hours: 72)),
        ]),
      );
    });
  });
}
