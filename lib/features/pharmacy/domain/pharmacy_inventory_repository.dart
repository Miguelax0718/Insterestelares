import 'medication_batch.dart';

abstract interface class PharmacyInventoryRepository {
  double get cumulativeRadiationMsv;

  Future<List<MedicationBatch>> getBatches({String? medication, String? route});

  Future<MedicationBatch?> getBatchById(String batchId);

  Future<CrewAllergyProfile> getAllergies(String astronautId);

  Future<MedicationBatch> flagBatch(String batchId, {String? reason});

  Future<MedicationBatch> updateDegradation(
    String batchId,
    double deltaPct, {
    bool autoFlagIfCompromised = false,
  });

  Future<MedicationBatch> deductDose(String batchId, int units);

  Future<void> addRadiationExposure(double doseMsv);
}
