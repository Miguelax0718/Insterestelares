/// Muestra de sangre de un astronauta (parte de biomarcadores).
///
/// - Linfocitos: bajan rápido tras una dosis alta (por ejemplo, una tormenta
///   solar). Sirven para el triage agudo.
/// - Neutrófilos: también reflejan daño a la médula ósea.
/// - PCR (proteína C reactiva): inflamación, ligada al riesgo cardiovascular
///   crónico.
class BloodSample {
  final String astronautId;
  final DateTime takenAt;

  /// Linfocitos absolutos (×10⁹ células/L).
  final double lymphocytes10e9PerL;

  /// Neutrófilos absolutos (×10⁹ células/L).
  final double neutrophils10e9PerL;

  /// Proteína C reactiva (mg/L).
  final double crpMgPerL;

  BloodSample({
    required this.astronautId,
    required this.takenAt,
    required this.lymphocytes10e9PerL,
    required this.neutrophils10e9PerL,
    required this.crpMgPerL,
  }) {
    if (astronautId.isEmpty) {
      throw ArgumentError.value(astronautId, 'astronautId', 'no puede estar vacío');
    }
    for (final entry in {
      'lymphocytes10e9PerL': lymphocytes10e9PerL,
      'neutrophils10e9PerL': neutrophils10e9PerL,
      'crpMgPerL': crpMgPerL,
    }.entries) {
      if (entry.value.isNaN || entry.value < 0) {
        throw ArgumentError.value(
            entry.value, entry.key, 'debe ser un número mayor o igual a 0');
      }
    }
  }

  factory BloodSample.fromJson(Map<String, dynamic> json) => BloodSample(
        astronautId: json['astronautId'] as String,
        takenAt: DateTime.parse(json['takenAt'] as String),
        lymphocytes10e9PerL: (json['lymphocytes10e9PerL'] as num).toDouble(),
        neutrophils10e9PerL: (json['neutrophils10e9PerL'] as num).toDouble(),
        crpMgPerL: (json['crpMgPerL'] as num).toDouble(),
      );

  Map<String, dynamic> toJson() => {
        'astronautId': astronautId,
        'takenAt': takenAt.toIso8601String(),
        'lymphocytes10e9PerL': lymphocytes10e9PerL,
        'neutrophils10e9PerL': neutrophils10e9PerL,
        'crpMgPerL': crpMgPerL,
      };
}
