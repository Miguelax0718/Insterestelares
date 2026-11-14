import '../biomarkers/biomarker_baseline.dart';

/// Resumen diario de la parte BIOLÓGICA (Juan) para un astronauta.
///
/// Es el punto de unión con la parte de dosimetría (María), que entrega su
/// propio `DoseSummary` en `contracts/dose_summary.dart`. El motor de riesgo
/// combina ambos resúmenes; ninguna de las dos partes necesita conocer los
/// detalles internos de la otra.
class BioSummary {
  final String astronautId;
  final DateTime date;

  /// Cambio relativo de cada marcador sobre la línea base personal.
  /// Ejemplo: 0.40 significa +40 % sobre lo normal de esa persona.
  final Map<Biomarker, double> changeFromBaseline;

  /// Puntaje biológico combinado B = Σ wᵢ · rᵢ (ver documento de diseño).
  final double score;

  /// true si toca tomar una muestra (rutina semanal o tras una tormenta solar).
  final bool samplePending;

  BioSummary({
    required this.astronautId,
    required this.date,
    required Map<Biomarker, double> changeFromBaseline,
    required this.score,
    required this.samplePending,
  }) : changeFromBaseline = Map.unmodifiable(changeFromBaseline);

  /// Cambio de un marcador, o null si no hay dato ese día.
  double? changeOf(Biomarker marker) => changeFromBaseline[marker];

  factory BioSummary.fromJson(Map<String, dynamic> json) => BioSummary(
        astronautId: json['astronautId'] as String,
        date: DateTime.parse(json['date'] as String),
        changeFromBaseline:
            (json['changeFromBaseline'] as Map<String, dynamic>).map(
          (key, value) =>
              MapEntry(Biomarker.values.byName(key), (value as num).toDouble()),
        ),
        score: (json['score'] as num).toDouble(),
        samplePending: json['samplePending'] as bool,
      );

  Map<String, dynamic> toJson() => {
        'astronautId': astronautId,
        'date': date.toIso8601String(),
        'changeFromBaseline':
            changeFromBaseline.map((key, value) => MapEntry(key.name, value)),
        'score': score,
        'samplePending': samplePending,
      };
}
