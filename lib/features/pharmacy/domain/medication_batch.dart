class MedicationBatch {
  const MedicationBatch({
    required this.batchId,
    required this.medication,
    this.drugClass = '',
    required this.route,
    required this.unitMg,
    required this.maxSingleDoseMg,
    required this.maxDailyDoseMg,
    required this.unitsRemaining,
    required this.storageLocation,
    required this.shieldingFactor,
    required this.radiationSensitivity,
    required this.degradationPct,
    required this.flagged,
    this.contraindicatedWith = const [],
  });

  static const double degradationThresholdPct = 15.0;

  factory MedicationBatch.fromJson(Map<String, dynamic> json) {
    return MedicationBatch(
      batchId: json['batch_id'] as String,
      medication: (json['medication'] as String).trim().toLowerCase(),
      drugClass: (json['drug_class'] as String? ?? '').trim().toLowerCase(),
      route: (json['route'] as String).trim().toLowerCase(),
      unitMg: (json['unit_mg'] as num).toDouble(),
      maxSingleDoseMg: (json['max_single_dose_mg'] as num).toDouble(),
      maxDailyDoseMg: (json['max_daily_dose_mg'] as num).toDouble(),
      unitsRemaining: (json['units_remaining'] as num).toInt(),
      storageLocation: json['storage_location'] as String,
      shieldingFactor: (json['shielding_factor'] as num).toDouble(),
      radiationSensitivity: (json['radiation_sensitivity'] as num).toDouble(),
      degradationPct: (json['degradation_pct'] as num? ?? 0.0).toDouble(),
      flagged: json['flagged'] as bool? ?? false,
      contraindicatedWith:
          (json['contraindicated_with'] as List<dynamic>? ?? const [])
              .map((e) => e.toString())
              .toList(growable: false),
    );
  }

  final String batchId;
  final String medication;
  final String drugClass;
  final String route;
  final double unitMg;
  final double maxSingleDoseMg;
  final double maxDailyDoseMg;
  final int unitsRemaining;
  final String storageLocation;
  final double shieldingFactor;
  final double radiationSensitivity;
  final double degradationPct;
  final bool flagged;
  final List<String> contraindicatedWith;

  bool get isCompromised => flagged || degradationPct >= degradationThresholdPct;

  bool get hasStock => unitsRemaining > 0;

  bool get isUsable => !isCompromised && hasStock;

  MedicationBatch copyWith({
    String? batchId,
    String? medication,
    String? drugClass,
    String? route,
    double? unitMg,
    double? maxSingleDoseMg,
    double? maxDailyDoseMg,
    int? unitsRemaining,
    String? storageLocation,
    double? shieldingFactor,
    double? radiationSensitivity,
    double? degradationPct,
    bool? flagged,
    List<String>? contraindicatedWith,
  }) {
    return MedicationBatch(
      batchId: batchId ?? this.batchId,
      medication: medication ?? this.medication,
      drugClass: drugClass ?? this.drugClass,
      route: route ?? this.route,
      unitMg: unitMg ?? this.unitMg,
      maxSingleDoseMg: maxSingleDoseMg ?? this.maxSingleDoseMg,
      maxDailyDoseMg: maxDailyDoseMg ?? this.maxDailyDoseMg,
      unitsRemaining: unitsRemaining ?? this.unitsRemaining,
      storageLocation: storageLocation ?? this.storageLocation,
      shieldingFactor: shieldingFactor ?? this.shieldingFactor,
      radiationSensitivity: radiationSensitivity ?? this.radiationSensitivity,
      degradationPct: degradationPct ?? this.degradationPct,
      flagged: flagged ?? this.flagged,
      contraindicatedWith: contraindicatedWith ?? this.contraindicatedWith,
    );
  }

  Map<String, dynamic> toJson() => {
    'batch_id': batchId,
    'medication': medication,
    if (drugClass.isNotEmpty) 'drug_class': drugClass,
    'route': route,
    'unit_mg': unitMg,
    'max_single_dose_mg': maxSingleDoseMg,
    'max_daily_dose_mg': maxDailyDoseMg,
    'units_remaining': unitsRemaining,
    'storage_location': storageLocation,
    'shielding_factor': shieldingFactor,
    'radiation_sensitivity': radiationSensitivity,
    'degradation_pct': degradationPct,
    'flagged': flagged,
    'contraindicated_with': contraindicatedWith,
  };
}

class CrewAllergyProfile {
  const CrewAllergyProfile({
    required this.astronautId,
    this.medications = const {},
    this.classes = const {},
    this.notes = '',
  });

  factory CrewAllergyProfile.fromDynamic(String astronautId, Object? raw) {
    if (raw is List<dynamic>) {
      return CrewAllergyProfile(
        astronautId: astronautId,
        medications: raw.map((e) => e.toString().trim().toLowerCase()).toSet(),
      );
    }
    if (raw is Map<String, dynamic>) {
      final meds = (raw['medications'] as List<dynamic>? ??
              raw['allergies'] as List<dynamic>? ??
              const [])
          .map((e) => e.toString().trim().toLowerCase())
          .toSet();
      final classes = (raw['classes'] as List<dynamic>? ??
              raw['allergic_classes'] as List<dynamic>? ??
              const [])
          .map((e) => e.toString().trim().toLowerCase())
          .toSet();
      return CrewAllergyProfile(
        astronautId: astronautId,
        medications: meds,
        classes: classes,
        notes: raw['notes'] as String? ?? '',
      );
    }
    return CrewAllergyProfile(astronautId: astronautId);
  }

  final String astronautId;
  final Set<String> medications;
  final Set<String> classes;
  final String notes;

  bool isAllergicTo(String medication, {String? drugClass}) {
    final normalizedMed = medication.trim().toLowerCase();
    if (medications.contains(normalizedMed)) {
      return true;
    }
    final normalizedClass = drugClass?.trim().toLowerCase() ?? '';
    return normalizedClass.isNotEmpty && classes.contains(normalizedClass);
  }
}
