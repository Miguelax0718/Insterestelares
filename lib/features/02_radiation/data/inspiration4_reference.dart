/// Valores REALES de sangre de la tripulación de Inspiration4 (SpaceX, 2021,
/// 3 días en órbita), tomados del repositorio público de la NASA:
///
///   NASA Open Science Data Repository (OSDR), estudio OSD-569,
///   archivo `LSDS-7_Complete_Blood_Count_CBC.upload_SUBMITTED.csv`
///   (copia en `DB/real/inspiration4/`).
///
/// Los 4 tripulantes son anónimos (C001–C004). Se usan las 3 visitas previas
/// al vuelo (L-92, L-44 y L-3 días antes del lanzamiento) y la del día
/// siguiente al regreso (R+1). Las unidades del archivo son células/µL; aquí
/// se pasan a ×10⁹/L (1000 células/µL = 1 ×10⁹/L).
///
/// Corrección: en C003, visita L-92, el archivo trae neutrófilos = 10,1
/// y linfocitos = 6826 células/µL. Con los leucocitos (9,6 mil/µL) y los
/// porcentajes del mismo análisis (71,1 % neutrófilos, 20,8 % linfocitos) los
/// valores correctos son ≈ 6826 neutrófilos y ≈ 1997 linfocitos: los
/// absolutos quedaron mal cargados. Se usan los valores corregidos.
library;

/// Una visita de laboratorio real de un tripulante.
class Inspiration4Visit {
  /// Etiqueta original del estudio (L-92, L-44, L-3, R+1).
  final String timepoint;

  /// Días respecto al lanzamiento (negativo = antes) o al regreso (R+1 = 1).
  final int day;

  final double lymphocytes10e9PerL;
  final double neutrophils10e9PerL;

  const Inspiration4Visit(
      this.timepoint, this.day, this.lymphocytes10e9PerL, this.neutrophils10e9PerL);
}

class Inspiration4Subject {
  final String id;
  final String sex;

  /// Visitas antes del vuelo (L-92, L-44, L-3).
  final List<Inspiration4Visit> preflight;

  /// Visita al día siguiente del regreso (R+1).
  final Inspiration4Visit returnDay1;

  const Inspiration4Subject(this.id, this.sex, this.preflight, this.returnDay1);

  double get preflightLymphocyteMean =>
      _mean(preflight.map((v) => v.lymphocytes10e9PerL));

  double get preflightNeutrophilMean =>
      _mean(preflight.map((v) => v.neutrophils10e9PerL));

  /// Cambio relativo real de linfocitos al regresar (R+1 vs. media previa).
  double get returnLymphocyteChange =>
      returnDay1.lymphocytes10e9PerL / preflightLymphocyteMean - 1;

  double get returnNeutrophilChange =>
      returnDay1.neutrophils10e9PerL / preflightNeutrophilMean - 1;

  static double _mean(Iterable<double> xs) =>
      xs.reduce((a, b) => a + b) / xs.length;
}

class Inspiration4Reference {
  Inspiration4Reference._();

  static const String source =
      'NASA OSDR, Inspiration4 (OSD-569), LSDS-7 Complete Blood Count';

  static const List<Inspiration4Subject> subjects = [
    Inspiration4Subject('C001', 'M', [
      Inspiration4Visit('L-92', -92, 2.241, 2.349),
      Inspiration4Visit('L-44', -44, 1.859, 2.998),
      Inspiration4Visit('L-3', -3, 2.667, 3.570),
    ], Inspiration4Visit('R+1', 1, 1.640, 2.685)),
    Inspiration4Subject('C002', 'F', [
      Inspiration4Visit('L-92', -92, 2.119, 3.705),
      Inspiration4Visit('L-44', -44, 1.982, 2.873),
      Inspiration4Visit('L-3', -3, 2.873, 3.701),
    ], Inspiration4Visit('R+1', 1, 1.540, 3.328)),
    Inspiration4Subject('C003', 'F', [
      Inspiration4Visit('L-92', -92, 1.997, 6.826), // corregido, ver arriba
      Inspiration4Visit('L-44', -44, 2.083, 6.408),
      Inspiration4Visit('L-3', -3, 3.156, 5.792),
    ], Inspiration4Visit('R+1', 1, 2.086, 4.088)),
    Inspiration4Subject('C004', 'M', [
      Inspiration4Visit('L-92', -92, 1.786, 4.766),
      Inspiration4Visit('L-44', -44, 1.613, 3.699),
      Inspiration4Visit('L-3', -3, 2.947, 6.318),
    ], Inspiration4Visit('R+1', 1, 2.155, 4.528)),
  ];

  /// Variación real de una misma persona entre visitas previas al vuelo
  /// (coeficiente de variación medio de los 4 tripulantes, calculado con los
  /// valores de arriba). Es grande: un cambio de ±25 % en linfocitos entre
  /// dos análisis es normal y NO indica daño por radiación.
  static const double lymphocyteWithinPersonCv = 0.25;
  static const double neutrophilWithinPersonCv = 0.17;
}
