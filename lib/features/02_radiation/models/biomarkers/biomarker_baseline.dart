/// Biomarcadores que el módulo sigue. Los de orina van normalizados por
/// creatinina (ver UrineSample).
enum Biomarker {
  urineOhdg('8-OHdG (orina)', 'ng/mg creatinina'),
  urineIsoprostane('Isoprostanos (orina)', 'ng/mg creatinina'),
  urineMda('MDA (orina)', 'µmol/g creatinina'),
  bloodLymphocytes('Linfocitos (sangre)', '×10⁹/L'),
  bloodNeutrophils('Neutrófilos (sangre)', '×10⁹/L'),
  bloodCrp('PCR (sangre)', 'mg/L');

  const Biomarker(this.label, this.unit);

  /// Nombre para mostrar en la app.
  final String label;

  /// Unidad en la que se guarda el valor.
  final String unit;
}

/// Línea base personal de un astronauta: sus valores normales medidos antes
/// del vuelo. El módulo no usa rangos fijos de población, sino el cambio de
/// cada persona respecto a su propia línea base.
class BiomarkerBaseline {
  final String astronautId;

  /// Promedio previo al vuelo de cada biomarcador.
  final Map<Biomarker, double> preflightMean;

  /// Número de muestras usadas para calcular cada promedio.
  final int sampleCount;

  /// Fecha de la última muestra incluida en la línea base.
  final DateTime measuredUntil;

  BiomarkerBaseline({
    required this.astronautId,
    required Map<Biomarker, double> preflightMean,
    required this.sampleCount,
    required this.measuredUntil,
  }) : preflightMean = Map.unmodifiable(preflightMean) {
    if (sampleCount < 1) {
      throw ArgumentError.value(sampleCount, 'sampleCount', 'debe ser al menos 1');
    }
    preflightMean.forEach((marker, value) {
      if (value.isNaN || value <= 0) {
        throw ArgumentError.value(
            value, marker.name, 'la línea base debe ser mayor que 0');
      }
    });
  }

  /// Valor base de un marcador, o null si no se midió antes del vuelo.
  double? of(Biomarker marker) => preflightMean[marker];

  factory BiomarkerBaseline.fromJson(Map<String, dynamic> json) =>
      BiomarkerBaseline(
        astronautId: json['astronautId'] as String,
        preflightMean: (json['preflightMean'] as Map<String, dynamic>).map(
          (key, value) =>
              MapEntry(Biomarker.values.byName(key), (value as num).toDouble()),
        ),
        sampleCount: json['sampleCount'] as int,
        measuredUntil: DateTime.parse(json['measuredUntil'] as String),
      );

  Map<String, dynamic> toJson() => {
        'astronautId': astronautId,
        'preflightMean':
            preflightMean.map((key, value) => MapEntry(key.name, value)),
        'sampleCount': sampleCount,
        'measuredUntil': measuredUntil.toIso8601String(),
      };
}
