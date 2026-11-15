import 'dart:convert';

import 'package:flutter/services.dart';

import '../domain/medication_batch.dart';
import '../domain/pharmacy_inventory_repository.dart';

class AssetPharmacyInventoryRepository implements PharmacyInventoryRepository {
  AssetPharmacyInventoryRepository({
    AssetBundle? bundle,
    this.inventoryAssetPath = 'DB/Pharmacy/medication_inventory.json',
    this.allergiesAssetPath = 'DB/Pharmacy/crew_allergies.json',
  }) : _bundle = bundle ?? rootBundle,
       _loaded = false;

  AssetPharmacyInventoryRepository.fromJsonStrings({
    required String inventoryJson,
    required String allergiesJson,
  }) : _bundle = null,
       inventoryAssetPath = '',
       allergiesAssetPath = '',
       _loaded = true {
    _loadFromDecoded(jsonDecode(inventoryJson), jsonDecode(allergiesJson));
  }

  AssetPharmacyInventoryRepository.fromMemory({
    required List<MedicationBatch> batches,
    required Map<String, CrewAllergyProfile> allergies,
    double initialRadiationMsv = 0.0,
  }) : _bundle = null,
       inventoryAssetPath = '',
       allergiesAssetPath = '',
       _loaded = true,
       _cumulativeRadiationMsv = initialRadiationMsv {
    for (final batch in batches) {
      _batches[batch.batchId] = batch;
    }
    _allergies.addAll(allergies);
  }

  final AssetBundle? _bundle;
  final String inventoryAssetPath;
  final String allergiesAssetPath;

  final Map<String, MedicationBatch> _batches = {};
  final Map<String, CrewAllergyProfile> _allergies = {};
  final Map<String, String> _flagReasons = {};
  double _cumulativeRadiationMsv = 0.0;
  bool _loaded;

  @override
  double get cumulativeRadiationMsv => _cumulativeRadiationMsv;

  String? flagReasonOf(String batchId) => _flagReasons[batchId];

  Future<void> _ensureLoaded() async {
    if (_loaded) return;
    final bundle = _bundle ?? rootBundle;
    final inventoryRaw = await bundle.loadString(inventoryAssetPath);
    final allergiesRaw = await bundle.loadString(allergiesAssetPath);
    _loadFromDecoded(jsonDecode(inventoryRaw), jsonDecode(allergiesRaw));
    _loaded = true;
  }

  void _loadFromDecoded(Object? inventoryDecoded, Object? allergiesDecoded) {
    final List<dynamic> rawBatches;
    if (inventoryDecoded is List<dynamic>) {
      rawBatches = inventoryDecoded;
    } else if (inventoryDecoded is Map<String, dynamic>) {
      rawBatches =
          inventoryDecoded['batches'] as List<dynamic>? ?? const <dynamic>[];
    } else {
      throw const FormatException('Invalid medication inventory JSON shape.');
    }

    _batches.clear();
    for (final entry in rawBatches) {
      if (entry is Map<String, dynamic>) {
        final batch = MedicationBatch.fromJson(entry);
        _batches[batch.batchId] = batch;
      }
    }

    _allergies.clear();
    if (allergiesDecoded is Map<String, dynamic>) {
      final rawAstronauts =
          allergiesDecoded['astronauts'] as Map<String, dynamic>? ??
          allergiesDecoded;
      for (final entry in rawAstronauts.entries) {
        if (entry.key == 'version') continue;
        _allergies[entry.key] = CrewAllergyProfile.fromDynamic(
          entry.key,
          entry.value,
        );
      }
    }
  }

  @override
  Future<List<MedicationBatch>> getBatches({
    String? medication,
    String? route,
  }) async {
    await _ensureLoaded();
    final medFilter = medication?.trim().toLowerCase();
    final routeFilter = route?.trim().toLowerCase();
    return _batches.values
        .where((b) {
          if (medFilter != null &&
              medFilter.isNotEmpty &&
              b.medication != medFilter) {
            return false;
          }
          if (routeFilter != null &&
              routeFilter.isNotEmpty &&
              b.route != routeFilter) {
            return false;
          }
          return true;
        })
        .toList(growable: false);
  }

  @override
  Future<MedicationBatch?> getBatchById(String batchId) async {
    await _ensureLoaded();
    return _batches[batchId];
  }

  @override
  Future<CrewAllergyProfile> getAllergies(String astronautId) async {
    await _ensureLoaded();
    return _allergies[astronautId] ??
        CrewAllergyProfile(astronautId: astronautId);
  }

  @override
  Future<MedicationBatch> flagBatch(String batchId, {String? reason}) async {
    await _ensureLoaded();
    final existing = _batches[batchId];
    if (existing == null) {
      throw StateError('Unknown batch_id: $batchId');
    }
    final updated = existing.copyWith(flagged: true);
    _batches[batchId] = updated;
    if (reason != null && reason.trim().isNotEmpty) {
      _flagReasons[batchId] = reason.trim();
    }
    return updated;
  }

  @override
  Future<MedicationBatch> updateDegradation(
    String batchId,
    double deltaPct, {
    bool autoFlagIfCompromised = false,
  }) async {
    await _ensureLoaded();
    final existing = _batches[batchId];
    if (existing == null) {
      throw StateError('Unknown batch_id: $batchId');
    }
    final nextPct = (existing.degradationPct + deltaPct).clamp(0.0, 100.0);
    final shouldFlag =
        existing.flagged ||
        (autoFlagIfCompromised &&
            nextPct >= MedicationBatch.degradationThresholdPct);
    final updated = existing.copyWith(
      degradationPct: nextPct,
      flagged: shouldFlag,
    );
    _batches[batchId] = updated;
    return updated;
  }

  @override
  Future<MedicationBatch> deductDose(String batchId, int units) async {
    await _ensureLoaded();
    if (units <= 0) {
      throw ArgumentError.value(units, 'units', 'Must be positive');
    }
    final existing = _batches[batchId];
    if (existing == null) {
      throw StateError('Unknown batch_id: $batchId');
    }
    if (existing.unitsRemaining < units) {
      throw StateError(
        'Insufficient stock in $batchId: ${existing.unitsRemaining} < $units',
      );
    }
    final updated = existing.copyWith(
      unitsRemaining: existing.unitsRemaining - units,
    );
    _batches[batchId] = updated;
    return updated;
  }

  @override
  Future<void> addRadiationExposure(double doseMsv) async {
    await _ensureLoaded();
    if (doseMsv > 0) {
      _cumulativeRadiationMsv += doseMsv;
    }
  }
}
