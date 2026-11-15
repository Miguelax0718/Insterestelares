import '../../agent/domain/agent_contracts.dart';
import 'medication_batch.dart';
import 'pharmacy_inventory_repository.dart';

class DeterministicMedicationSafety implements MedicationSafety {
  const DeterministicMedicationSafety({
    required this.repository,
    this.flags,
  });

  final PharmacyInventoryRepository repository;
  final AgentFlagsStore? flags;

  @override
  Future<MedicationCheck> validate(MedicationRequest request) async {
    final med = request.medication.trim().toLowerCase();
    final route = request.route.trim().toLowerCase();
    final astronautId = request.astronautId.trim();
    final reasons = <String>[];

    if (med.isEmpty) {
      return const MedicationCheck(
        allowed: false,
        reasons: ['Medication name is required'],
      );
    }

    final allMedBatches = await repository.getBatches(medication: med);
    if (allMedBatches.isEmpty) {
      return MedicationCheck(
        allowed: false,
        reasons: ['Medication "$med" not found in pharmacy inventory'],
      );
    }

    final externallyFlagged = await _flaggedBatchIdsFor(astronautId);
    bool isBatchFlagged(MedicationBatch b) =>
        b.flagged || externallyFlagged.contains(b.batchId);
    bool isBatchDegraded(MedicationBatch b) =>
        b.degradationPct >= MedicationBatch.degradationThresholdPct;
    bool isBatchUsable(MedicationBatch b) =>
        !isBatchFlagged(b) && !isBatchDegraded(b) && b.unitsRemaining > 0;

    final allergyProfile = await repository.getAllergies(astronautId);
    final drugClass = allMedBatches
        .map((b) => b.drugClass)
        .firstWhere((c) => c.isNotEmpty, orElse: () => '');
    if (allergyProfile.isAllergicTo(med, drugClass: drugClass)) {
      reasons.add(
        'Astronaut $astronautId is allergic to $med'
        '${drugClass.isNotEmpty ? ' ($drugClass)' : ''}',
      );
    }

    final routeMatching = allMedBatches
        .where((b) => b.route == route)
        .toList(growable: false);
    final doseReferenceBatch =
        routeMatching.isNotEmpty ? routeMatching.first : allMedBatches.first;

    if (request.doseMg <= 0) {
      reasons.add(
        'Requested dose (${request.doseMg} mg) must be greater than 0 mg',
      );
    } else if (request.doseMg > doseReferenceBatch.maxSingleDoseMg) {
      reasons.add(
        'Requested dose (${request.doseMg} mg) exceeds max single dose '
        '(${doseReferenceBatch.maxSingleDoseMg} mg) for $med',
      );
    }

    final gastricStasis = await _isGastricStasisActive(astronautId);
    final preferredNonOral = _pickAlternativeNonOralRoute(
      allMedBatches,
      isBatchUsable: isBatchUsable,
      explicitRoute: gastricStasis.preferredRoute,
    );

    String? suggestedAlternativeRoute;
    MedicationBatch? selectedBatch;

    if (route == 'oral' && gastricStasis.active) {
      reasons.add(
        'Oral route blocked due to active EVA gastric stasis / route override',
      );
      suggestedAlternativeRoute = preferredNonOral ?? 'intranasal';
    } else if (routeMatching.isEmpty) {
      reasons.add('No inventory batch available for $med via "$route" route');
      if (route == 'oral' && preferredNonOral != null) {
        suggestedAlternativeRoute = preferredNonOral;
      }
    } else {
      final usableMatching =
          routeMatching.where(isBatchUsable).toList(growable: false);
      if (usableMatching.isEmpty) {
        final anyFlagged = routeMatching.any(isBatchFlagged);
        final anyDegraded = routeMatching.any(isBatchDegraded);
        final anyOutOfStock = routeMatching.every((b) => b.unitsRemaining <= 0);

        if (anyFlagged) {
          reasons.add(
            'Batch for $med ($route) is flagged and blocked from dispensing',
          );
        }
        if (anyDegraded) {
          reasons.add(
            'Batch for $med ($route) is radiation-degraded (>=15%) and blocked',
          );
        }
        if (anyOutOfStock) {
          reasons.add('Batch for $med ($route) is out of stock (0 units remaining)');
        }
        if (!anyFlagged && !anyDegraded && !anyOutOfStock) {
          reasons.add('No usable batch available for $med ($route)');
        }

        if (route == 'oral' && preferredNonOral != null) {
          suggestedAlternativeRoute = preferredNonOral;
        }
        selectedBatch = routeMatching.first;
      } else {
        selectedBatch = usableMatching.first;
      }
    }

    if (reasons.isNotEmpty || selectedBatch == null) {
      return MedicationCheck(
        allowed: false,
        reasons: reasons,
        batchId: selectedBatch?.batchId,
        remainingUnits: selectedBatch?.unitsRemaining,
        suggestedAlternativeRoute: suggestedAlternativeRoute,
      );
    }

    return MedicationCheck(
      allowed: true,
      reasons: const [
        'Verified against inventory, allergies, radiation status, and dose limits',
      ],
      batchId: selectedBatch.batchId,
      remainingUnits: selectedBatch.unitsRemaining,
    );
  }

  Future<({bool active, String? preferredRoute})> _isGastricStasisActive(
    String astronautId,
  ) async {
    final store = flags;
    if (store == null) return (active: false, preferredRoute: null);

    for (final key in const [
      'eva_gastric_stasis',
      'medication_route_override',
      'route_override',
    ]) {
      final flag = await store.getFlag(astronautId, key);
      if (flag == null) continue;
      final isActive = flag['active'] as bool? ?? true;
      if (isActive) {
        final preferred =
            (flag['preferred_route'] ?? flag['route']) as String?;
        return (
          active: true,
          preferredRoute: preferred?.trim().toLowerCase(),
        );
      }
    }
    return (active: false, preferredRoute: null);
  }

  Future<Set<String>> _flaggedBatchIdsFor(String astronautId) async {
    final store = flags;
    if (store == null) return const {};
    final flag = await store.getFlag(astronautId, 'flagged_batches');
    final raw = flag?['batch_ids'] as List<dynamic>?;
    if (raw == null) return const {};
    return raw.map((e) => e.toString()).toSet();
  }

  String? _pickAlternativeNonOralRoute(
    List<MedicationBatch> batches, {
    required bool Function(MedicationBatch) isBatchUsable,
    String? explicitRoute,
  }) {
    if (explicitRoute == 'intranasal' || explicitRoute == 'intramuscular') {
      return explicitRoute;
    }
    final usableNonOral = batches
        .where((b) => b.route != 'oral' && isBatchUsable(b))
        .toList(growable: false);
    if (usableNonOral.any((b) => b.route == 'intranasal')) {
      return 'intranasal';
    }
    if (usableNonOral.any((b) => b.route == 'intramuscular')) {
      return 'intramuscular';
    }
    return null;
  }
}
