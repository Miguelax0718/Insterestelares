import '../models/biomarkers/biomarker_baseline.dart';
import '../models/biomarkers/blood_sample.dart';
import '../models/biomarkers/urine_sample.dart';
import '../models/contracts/bio_summary.dart';

/// Capa 2 del motor de riesgo (parte biológica, Juan).
///
/// Compara las muestras más recientes de un astronauta con su línea base
/// previa al vuelo y produce un [BioSummary]:
///
///   rᵢ = (xᵢ − baseᵢ) / baseᵢ        cambio relativo de cada marcador
///   B  = Σ wᵢ · dᵢ / Σ wᵢ            puntaje biológico combinado
///
/// donde dᵢ es el cambio en la dirección "dañina": para el 8-OHdG, los
/// isoprostanos, el MDA y la PCR, subir es malo (dᵢ = rᵢ); para linfocitos y
/// neutrófilos, bajar es malo (dᵢ = −rᵢ). Solo se suman los marcadores que
/// tienen muestra y línea base, y los pesos se reparten entre ellos.
///
/// Los pesos y plazos son ILUSTRATIVOS para el prototipo, no clínicos.
class BiomarkerScoreCalculator {
  /// Peso de cada marcador en el puntaje B (suman 1).
  final Map<Biomarker, double> weights;

  /// Cada cuánto debe tomarse una muestra de orina de rutina.
  final Duration urineRoutineInterval;

  /// Una muestra tomada antes de este tiempo ya no cuenta como "reciente".
  final Duration maxSampleAge;

  const BiomarkerScoreCalculator({
    this.weights = defaultWeights,
    this.urineRoutineInterval = const Duration(days: 7),
    this.maxSampleAge = const Duration(days: 14),
  });

  static const Map<Biomarker, double> defaultWeights = {
    Biomarker.urineOhdg: 0.30,
    Biomarker.urineIsoprostane: 0.15,
    Biomarker.urineMda: 0.10,
    Biomarker.bloodLymphocytes: 0.25,
    Biomarker.bloodNeutrophils: 0.10,
    Biomarker.bloodCrp: 0.10,
  };

  /// Marcadores en los que una BAJADA indica daño.
  static const Set<Biomarker> lowerIsWorse = {
    Biomarker.bloodLymphocytes,
    Biomarker.bloodNeutrophils,
  };

  /// Cambio relativo r = (x − base) / base. Ejemplo: 0.4 = +40 %.
  static double relativeChange(double value, double baseline) {
    if (baseline <= 0 || baseline.isNaN) {
      throw ArgumentError.value(baseline, 'baseline', 'debe ser mayor que 0');
    }
    return (value - baseline) / baseline;
  }

  /// Resume el estado biológico de un astronauta en la fecha [date].
  ///
  /// [lastSolarEventAt] lo aporta la parte de dosimetría (María): si hubo una
  /// tormenta solar después de la última muestra de orina, se pide una nueva.
  BioSummary summarize({
    required BiomarkerBaseline baseline,
    required List<UrineSample> urineSamples,
    required List<BloodSample> bloodSamples,
    required DateTime date,
    DateTime? lastSolarEventAt,
  }) {
    final id = baseline.astronautId;
    final urine = _latest(
      urineSamples.where((s) => s.astronautId == id && !s.takenAt.isAfter(date)),
      (s) => s.takenAt,
    );
    final blood = _latest(
      bloodSamples.where((s) => s.astronautId == id && !s.takenAt.isAfter(date)),
      (s) => s.takenAt,
    );

    final values = <Biomarker, double>{};
    if (urine != null && date.difference(urine.takenAt) <= maxSampleAge) {
      values[Biomarker.urineOhdg] = urine.ohdgPerCreatinine;
      values[Biomarker.urineIsoprostane] = urine.isoprostanePerCreatinine;
      values[Biomarker.urineMda] = urine.mdaPerCreatinine;
    }
    if (blood != null && date.difference(blood.takenAt) <= maxSampleAge) {
      values[Biomarker.bloodLymphocytes] = blood.lymphocytes10e9PerL;
      values[Biomarker.bloodNeutrophils] = blood.neutrophils10e9PerL;
      values[Biomarker.bloodCrp] = blood.crpMgPerL;
    }

    final changes = <Biomarker, double>{};
    var weightedSum = 0.0;
    var weightTotal = 0.0;
    values.forEach((marker, value) {
      final base = baseline.of(marker);
      if (base == null) return;
      final r = relativeChange(value, base);
      changes[marker] = r;
      final w = weights[marker] ?? 0;
      final harmful = lowerIsWorse.contains(marker) ? -r : r;
      weightedSum += w * harmful;
      weightTotal += w;
    });

    final score = weightTotal == 0 ? 0.0 : weightedSum / weightTotal;

    return BioSummary(
      astronautId: id,
      date: date,
      changeFromBaseline: changes,
      score: score,
      samplePending: _isSamplePending(urine?.takenAt, date, lastSolarEventAt),
    );
  }

  bool _isSamplePending(
      DateTime? lastUrineAt, DateTime date, DateTime? lastSolarEventAt) {
    if (lastUrineAt == null) return true;
    if (date.difference(lastUrineAt) >= urineRoutineInterval) return true;
    if (lastSolarEventAt != null &&
        lastSolarEventAt.isAfter(lastUrineAt) &&
        !lastSolarEventAt.isAfter(date)) {
      return true;
    }
    return false;
  }

  static T? _latest<T>(Iterable<T> items, DateTime Function(T) at) {
    T? best;
    for (final item in items) {
      if (best == null || at(item).isAfter(at(best))) best = item;
    }
    return best;
  }
}
