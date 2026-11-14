/// Muestra de orina de un astronauta (parte de biomarcadores).
///
/// Las concentraciones crudas varían según lo diluida que esté la orina,
/// por eso cada marcador se normaliza por la creatinina de la misma muestra
/// (unidades: ng de marcador por mg de creatinina).
///
/// Nota científica: el 8-OHdG es un marcador EXPERIMENTAL de daño oxidativo
/// al ADN. En astronautas de Mir no cambió durante el vuelo y subió tras el
/// regreso, sin relación clara con la dosis (Stein y Leskiw, 2000). Debe
/// interpretarse siempre junto con la dosis y la dieta.
class UrineSample {
  final String astronautId;
  final DateTime takenAt;

  /// 8-hidroxi-2'-desoxiguanosina (ng/mL). Daño oxidativo al ADN.
  final double ohdgNgPerMl;

  /// 8-iso-PGF2α / isoprostanos (ng/mL). Peroxidación de lípidos.
  final double isoprostaneNgPerMl;

  /// Malondialdehído (µmol/L). Peroxidación de lípidos.
  final double mdaUmolPerL;

  /// Creatinina (mg/dL). Sirve para normalizar los demás valores.
  final double creatinineMgPerDl;

  UrineSample({
    required this.astronautId,
    required this.takenAt,
    required this.ohdgNgPerMl,
    required this.isoprostaneNgPerMl,
    required this.mdaUmolPerL,
    required this.creatinineMgPerDl,
  }) {
    if (astronautId.isEmpty) {
      throw ArgumentError.value(astronautId, 'astronautId', 'no puede estar vacío');
    }
    _checkNonNegative(ohdgNgPerMl, 'ohdgNgPerMl');
    _checkNonNegative(isoprostaneNgPerMl, 'isoprostaneNgPerMl');
    _checkNonNegative(mdaUmolPerL, 'mdaUmolPerL');
    if (creatinineMgPerDl <= 0) {
      throw ArgumentError.value(
          creatinineMgPerDl, 'creatinineMgPerDl', 'debe ser mayor que 0');
    }
  }

  /// Creatinina en mg/mL (1 dL = 100 mL).
  double get _creatinineMgPerMl => creatinineMgPerDl / 100;

  /// 8-OHdG normalizado: ng por mg de creatinina.
  double get ohdgPerCreatinine => ohdgNgPerMl / _creatinineMgPerMl;

  /// Isoprostanos normalizados: ng por mg de creatinina.
  double get isoprostanePerCreatinine =>
      isoprostaneNgPerMl / _creatinineMgPerMl;

  /// MDA normalizado: µmol por g de creatinina.
  /// (µmol/L) / (g/L); creatinina mg/dL × 10 = mg/L, ÷ 1000 = g/L.
  double get mdaPerCreatinine => mdaUmolPerL / (creatinineMgPerDl * 10 / 1000);

  factory UrineSample.fromJson(Map<String, dynamic> json) => UrineSample(
        astronautId: json['astronautId'] as String,
        takenAt: DateTime.parse(json['takenAt'] as String),
        ohdgNgPerMl: (json['ohdgNgPerMl'] as num).toDouble(),
        isoprostaneNgPerMl: (json['isoprostaneNgPerMl'] as num).toDouble(),
        mdaUmolPerL: (json['mdaUmolPerL'] as num).toDouble(),
        creatinineMgPerDl: (json['creatinineMgPerDl'] as num).toDouble(),
      );

  Map<String, dynamic> toJson() => {
        'astronautId': astronautId,
        'takenAt': takenAt.toIso8601String(),
        'ohdgNgPerMl': ohdgNgPerMl,
        'isoprostaneNgPerMl': isoprostaneNgPerMl,
        'mdaUmolPerL': mdaUmolPerL,
        'creatinineMgPerDl': creatinineMgPerDl,
      };
}

void _checkNonNegative(double value, String name) {
  if (value.isNaN || value < 0) {
    throw ArgumentError.value(value, name, 'debe ser un número mayor o igual a 0');
  }
}
