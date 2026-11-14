import 'dart:math' as math;

import '../models/biomarkers/biomarker_baseline.dart';
import '../models/biomarkers/blood_sample.dart';
import '../models/biomarkers/urine_sample.dart';
import 'inspiration4_reference.dart';

/// Simulador de biomarcadores de orina y sangre (parte de Juan del módulo de
/// radiación de Juan y María).
///
/// No depende de ningún otro archivo del proyecto: la dosis de la tormenta
/// solar (SPE) entra como parámetro, así que cuando la dosimetría de María
/// esté lista basta con pasarle sus valores.
///
/// En qué se basa (detalle y enlaces en `DB/real/inspiration4/README.md`):
/// - SANGRE: cada astronauta simulado usa los análisis REALES previos al vuelo
///   de un tripulante de Inspiration4 (NASA OSDR) como línea base, la
///   variación real entre visitas como ruido, y el cambio real observado al
///   día siguiente del regreso (R+1).
/// - ORINA: 8-OHdG de base ≈ 3,9 ng/mg de creatinina (mediana; rango
///   intercuartílico 3–5,5) en adultos sanos, metaanálisis de Graille et al.
///   2020. En vuelo el 8-OHdG no cambia y los isoprostanos bajan ~20 % (Mir,
///   Stein y Leskiw 2000). Tras el vuelo el 8-OHdG sube ~22 % (ISS, Smith y
///   Zwart, NASA 2006).
/// - Isoprostanos, MDA, creatinina urinaria, PCR y el efecto de la dosis son
///   APROXIMADOS (no vienen de un conjunto de datos de astronautas).
///
/// Todo lo que sale de aquí es SINTÉTICO (salvo la línea base de sangre, que
/// es real) y sirve para la demo, no para decisiones clínicas.
enum SimulationScenario {
  /// Usa la dosis del SPE que se le pasa tal cual.
  realistic('synthetic_from_real'),

  /// Reemplaza la dosis del SPE por una muy fuerte (hipotética, 1 Gy fuera
  /// del refugio, 0,25 Gy dentro) para mostrar una alerta roja en la demo.
  extremeHypothetical('synthetic_hypothetical');

  const SimulationScenario(this.dataType);

  /// Etiqueta que se guarda en cada fila para no confundir los escenarios.
  final String dataType;
}

/// Fase de la misión en la que se tomó una muestra.
enum MissionPhase { preflight, inflight, postflight }

/// De dónde sale el valor de una muestra de sangre.
enum BloodOrigin {
  /// Valor medido, copiado del estudio Inspiration4.
  realInspiration4,

  /// Media real × cambio real observado en Inspiration4 (R+1).
  derivedInspiration4,

  /// Generado por el simulador.
  simulated,
}

/// Una muestra simulada con su contexto, para escribir el CSV.
class SimulatedUrine {
  /// Día respecto al lanzamiento (día 1 = primer día en vuelo; negativo =
  /// antes del vuelo).
  final int missionDay;
  final MissionPhase phase;
  final UrineSample sample;

  /// Factor de confusión aplicado ese día ('none', 'intense_exercise',
  /// 'poor_sleep'). Se guarda para poder explicar el resultado en la demo.
  final String confounder;

  const SimulatedUrine(this.missionDay, this.phase, this.sample, this.confounder);
}

class SimulatedBlood {
  final int missionDay;
  final MissionPhase phase;
  final BloodSample sample;
  final BloodOrigin origin;

  /// Tripulante de Inspiration4 usado como referencia (C001–C004).
  final String referenceSubject;

  const SimulatedBlood(this.missionDay, this.phase, this.sample, this.origin,
      this.referenceSubject);
}

class BiomarkerSimulation {
  final SimulationScenario scenario;
  final DateTime launch;
  final int missionDays;
  final int? speDay;
  final List<BiomarkerBaseline> baselines;
  final List<SimulatedUrine> urine;
  final List<SimulatedBlood> blood;

  const BiomarkerSimulation({
    required this.scenario,
    required this.launch,
    required this.missionDays,
    required this.speDay,
    required this.baselines,
    required this.urine,
    required this.blood,
  });
}

class BiomarkerSimulator {
  static const int defaultSeed = 20261114;

  /// Fecha ficticia del lanzamiento (día 0).
  static final DateTime defaultLaunch = DateTime.utc(2027, 1, 1);

  static const List<String> defaultCrew = ['AST-01', 'AST-02', 'AST-03', 'AST-04'];

  /// Visitas previas al vuelo: las mismas de Inspiration4.
  static const List<int> preflightDays = [-92, -44, -3];

  /// Dosis (Gy) del escenario extremo. HIPOTÉTICO.
  static const double extremeSpeDoseGy = 1.0;
  static const double extremeShelteredSpeDoseGy = 0.25;

  /// Cambios de la literatura usados en orina.
  static const double inflightIsoprostaneFactor = 0.80; // Mir: −20 %
  static const double postflightOhdgFactor = 1.22; // ISS: +22 %

  /// 8-OHdG en adultos sanos (Graille 2020), ng/mg creatinina.
  static const double ohdgMedian = 3.9;

  final int seed;
  final DateTime launch;

  BiomarkerSimulator({int? seed, DateTime? launch})
      : seed = seed ?? defaultSeed,
        launch = launch ?? defaultLaunch;

  /// Simula una misión de [missionDays] días.
  ///
  /// [speDoseMsv]: dosis efectiva del SPE de cada astronauta (mSv); quien no
  /// aparece recibe 0. [sheltered]: quienes estaban en el refugio durante el
  /// SPE (solo cambia el escenario extremo).
  BiomarkerSimulation simulate({
    List<String> crewIds = defaultCrew,
    int missionDays = 180,
    int? speDay,
    Map<String, double> speDoseMsv = const {},
    Set<String> sheltered = const {},
    SimulationScenario scenario = SimulationScenario.realistic,
  }) {
    if (crewIds.isEmpty) throw ArgumentError('crewIds no puede estar vacío');
    if (missionDays < 7) throw ArgumentError('la misión debe durar 7 días o más');
    if (speDay != null && (speDay < 1 || speDay > missionDays)) {
      throw ArgumentError('speDay debe estar dentro de la misión');
    }
    if (scenario == SimulationScenario.extremeHypothetical && speDay == null) {
      throw ArgumentError('el escenario extremo necesita un speDay');
    }

    final rng = _SeededRandom(seed);
    final baselines = <BiomarkerBaseline>[];
    final urine = <SimulatedUrine>[];
    final blood = <SimulatedBlood>[];
    final returnDay = missionDays + 1;

    for (var i = 0; i < crewIds.length; i++) {
      final id = crewIds[i];
      final ref =
          Inspiration4Reference.subjects[i % Inspiration4Reference.subjects.length];
      final truth = _UrineTruth.random(rng);
      final doseGy = _speDoseGy(id, speDoseMsv, sheltered, scenario);

      // ---------- Antes del vuelo ----------
      final preUrine = <Map<Biomarker, double>>[];
      for (final day in preflightDays) {
        final u = _urine(id, day, MissionPhase.preflight, truth, rng, boost: 0);
        urine.add(u);
        preUrine.add(_normalized(u.sample));
      }
      final preBlood = <BloodSample>[];
      for (final v in ref.preflight) {
        final s = BloodSample(
          astronautId: id,
          takenAt: _dateOf(v.day),
          lymphocytes10e9PerL: v.lymphocytes10e9PerL,
          neutrophils10e9PerL: v.neutrophils10e9PerL,
          crpMgPerL: _round(truth.crp * rng.noise(0.25), 2),
        );
        preBlood.add(s);
        blood.add(SimulatedBlood(v.day, MissionPhase.preflight, s,
            BloodOrigin.realInspiration4, ref.id));
      }

      double mean(Iterable<double> xs) => xs.reduce((a, b) => a + b) / xs.length;
      baselines.add(BiomarkerBaseline(
        astronautId: id,
        preflightMean: {
          Biomarker.urineOhdg: mean(preUrine.map((m) => m[Biomarker.urineOhdg]!)),
          Biomarker.urineIsoprostane:
              mean(preUrine.map((m) => m[Biomarker.urineIsoprostane]!)),
          Biomarker.urineMda: mean(preUrine.map((m) => m[Biomarker.urineMda]!)),
          Biomarker.bloodLymphocytes:
              mean(preBlood.map((b) => b.lymphocytes10e9PerL)),
          Biomarker.bloodNeutrophils:
              mean(preBlood.map((b) => b.neutrophils10e9PerL)),
          Biomarker.bloodCrp: mean(preBlood.map((b) => b.crpMgPerL)),
        },
        sampleCount: preflightDays.length,
        measuredUntil: _dateOf(preflightDays.last),
      ));

      // ---------- En vuelo: orina semanal + 1 y 3 días tras el SPE ----------
      final urineDays = <int>{
        for (var d = 7; d <= missionDays; d += 7) d,
        if (speDay != null && speDay + 1 <= missionDays) speDay + 1,
        if (speDay != null && speDay + 3 <= missionDays) speDay + 3,
      }.toList()
        ..sort();
      for (final day in urineDays) {
        urine.add(_urine(id, day, MissionPhase.inflight, truth, rng,
            boost: _radiationOxidativeBoost(doseGy, _since(speDay, day))));
      }

      // ---------- En vuelo: sangre mensual + 1, 3 y 7 días tras el SPE ----------
      final bloodDays = <int>{
        for (var d = 30; d <= missionDays; d += 30) d,
        if (speDay != null)
          for (final k in const [1, 3, 7])
            if (speDay + k <= missionDays) speDay + k,
      }.toList()
        ..sort();
      for (final day in bloodDays) {
        final since = _since(speDay, day);
        blood.add(SimulatedBlood(
          day,
          MissionPhase.inflight,
          _blood(id, day, ref, truth, rng,
              lymphFactor: _lymphocyteFactor(doseGy, since),
              neutFactor: 1,
              crpFactor: 1 + _radiationInflammation(doseGy, since),
              noise: true),
          BloodOrigin.simulated,
          ref.id,
        ));
      }

      // ---------- Al día siguiente del regreso (R+1) ----------
      final sinceReturn = _since(speDay, returnDay);
      urine.add(_urine(id, returnDay, MissionPhase.postflight, truth, rng,
          boost: _radiationOxidativeBoost(doseGy, sinceReturn),
          ohdgFactor: postflightOhdgFactor));
      blood.add(SimulatedBlood(
        returnDay,
        MissionPhase.postflight,
        _blood(id, returnDay, ref, truth, rng,
            lymphFactor: (1 + ref.returnLymphocyteChange) *
                _lymphocyteFactor(doseGy, sinceReturn),
            neutFactor: 1 + ref.returnNeutrophilChange,
            crpFactor: 1 + _radiationInflammation(doseGy, sinceReturn),
            noise: false),
        BloodOrigin.derivedInspiration4,
        ref.id,
      ));
    }

    return BiomarkerSimulation(
      scenario: scenario,
      launch: launch,
      missionDays: missionDays,
      speDay: speDay,
      baselines: baselines,
      urine: urine,
      blood: blood,
    );
  }

  /// Fecha y hora (7:00 UTC) de un día respecto al lanzamiento.
  DateTime _dateOf(int day) => launch.add(Duration(days: day, hours: 7));

  static int? _since(int? speDay, int day) => speDay == null ? null : day - speDay;

  SimulatedUrine _urine(
    String id,
    int day,
    MissionPhase phase,
    _UrineTruth t,
    _SeededRandom rng, {
    required double boost,
    double ohdgFactor = 1,
  }) {
    final confounder =
        phase == MissionPhase.preflight ? 'none' : _pickConfounder(rng);
    final extra = confounder == 'none' ? 0.0 : 0.35 + 0.25 * rng.next();
    final b = boost + extra;
    final isoFactor =
        phase == MissionPhase.inflight ? inflightIsoprostaneFactor : 1.0;

    // Valores normalizados por creatinina…
    final ohdg = t.ohdg * ohdgFactor * (1 + b) * rng.noise(0.12);
    final iso = t.isoprostane * isoFactor * (1 + b) * rng.noise(0.15);
    final mda = t.mda * (1 + 0.5 * b) * rng.noise(0.15);
    // …y se "diluyen" con una creatinina urinaria variable (mg/dL).
    final creatinine = _round(t.creatinine * rng.noise(0.30), 1);
    final mgPerMl = creatinine / 100;

    return SimulatedUrine(
      day,
      phase,
      UrineSample(
        astronautId: id,
        takenAt: _dateOf(day),
        ohdgNgPerMl: _round(ohdg * mgPerMl, 3),
        isoprostaneNgPerMl: _round(iso * mgPerMl, 4),
        mdaUmolPerL: _round(mda * creatinine * 10 / 1000, 3),
        creatinineMgPerDl: creatinine,
      ),
      confounder,
    );
  }

  BloodSample _blood(
    String id,
    int day,
    Inspiration4Subject ref,
    _UrineTruth t,
    _SeededRandom rng, {
    required double lymphFactor,
    required double neutFactor,
    required double crpFactor,
    required bool noise,
  }) {
    final ln =
        noise ? rng.noise(Inspiration4Reference.lymphocyteWithinPersonCv) : 1.0;
    final nn =
        noise ? rng.noise(Inspiration4Reference.neutrophilWithinPersonCv) : 1.0;
    return BloodSample(
      astronautId: id,
      takenAt: _dateOf(day),
      lymphocytes10e9PerL:
          _round(ref.preflightLymphocyteMean * lymphFactor * ln, 3),
      neutrophils10e9PerL:
          _round(ref.preflightNeutrophilMean * neutFactor * nn, 3),
      crpMgPerL: _round(t.crp * crpFactor * rng.noise(0.25), 2),
    );
  }

  static Map<Biomarker, double> _normalized(UrineSample s) => {
        Biomarker.urineOhdg: s.ohdgPerCreatinine,
        Biomarker.urineIsoprostane: s.isoprostanePerCreatinine,
        Biomarker.urineMda: s.mdaPerCreatinine,
      };

  /// Dosis del SPE en Gy. En el escenario realista se usa la dosis efectiva
  /// (mSv) como aproximación de la absorbida (1 mSv ≈ 1 mGy para este fin).
  static double _speDoseGy(String id, Map<String, double> speDoseMsv,
      Set<String> sheltered, SimulationScenario scenario) {
    if (scenario == SimulationScenario.extremeHypothetical) {
      return sheltered.contains(id) ? extremeShelteredSpeDoseGy : extremeSpeDoseGy;
    }
    return (speDoseMsv[id] ?? 0) / 1000;
  }

  /// Linfocitos: caída proporcional a la dosis (≈ −50 % por Gy, máx. −90 %)
  /// desde el día siguiente, con recuperación en ~3 semanas. APROXIMADO.
  static double _lymphocyteFactor(double doseGy, int? daysSinceSpe) {
    if (daysSinceSpe == null || daysSinceSpe < 1 || doseGy <= 0) return 1;
    final drop = math.min(0.9, 0.5 * doseGy);
    return 1 - drop * math.exp(-(daysSinceSpe - 1) / 21);
  }

  /// Estrés oxidativo extra por radiación (≈ +60 % por Gy), se disipa en
  /// pocos días. APROXIMADO.
  static double _radiationOxidativeBoost(double doseGy, int? daysSinceSpe) {
    if (daysSinceSpe == null || daysSinceSpe < 0 || doseGy <= 0) return 0;
    return 0.6 * doseGy * math.exp(-daysSinceSpe / 3);
  }

  /// Inflamación (PCR) por radiación (≈ +100 % por Gy), baja en ~1 semana.
  static double _radiationInflammation(double doseGy, int? daysSinceSpe) {
    if (daysSinceSpe == null || daysSinceSpe < 0 || doseGy <= 0) return 0;
    return 1.0 * doseGy * math.exp(-daysSinceSpe / 7);
  }

  static String _pickConfounder(_SeededRandom rng) {
    final x = rng.next();
    if (x < 0.06) return 'intense_exercise';
    if (x < 0.10) return 'poor_sleep';
    return 'none';
  }

  static double _round(double v, int places) {
    final f = math.pow(10, places).toDouble();
    return (v * f).round() / f;
  }
}

/// Valores "verdaderos" de orina (y PCR) de cada persona.
class _UrineTruth {
  final double ohdg; // ng/mg creatinina — Graille 2020
  final double isoprostane; // ng/mg creatinina — aproximado
  final double mda; // µmol/g creatinina — aproximado
  final double creatinine; // mg/dL en orina — aproximado
  final double crp; // mg/L — aproximado (adultos sanos suelen estar < 3)

  _UrineTruth(this.ohdg, this.isoprostane, this.mda, this.creatinine, this.crp);

  /// 8-OHdG: distribución log-normal con la mediana y el rango intercuartílico
  /// de Graille 2020 (σ = ln(5,5/3) / 1,349 ≈ 0,449).
  factory _UrineTruth.random(_SeededRandom r) {
    const sigma = 0.449;
    final z = (r.next() + r.next() + r.next() - 1.5) / 0.5;
    final ohdg = BiomarkerSimulator.ohdgMedian * math.exp(sigma * z);
    return _UrineTruth(
      ohdg.clamp(1.5, 12.0).toDouble(),
      0.25 + 0.20 * r.next(),
      1.5 + 1.0 * r.next(),
      80 + 80 * r.next(),
      0.5 + 1.5 * r.next(),
    );
  }
}

/// Generador congruencial lineal propio, para que los datos no dependan de la
/// implementación de dart:math Random y salgan iguales en cualquier PC.
class _SeededRandom {
  _SeededRandom(int seed) : _state = seed & 0xFFFFFFFF;

  int _state;

  double next() {
    _state = (1664525 * _state + 1013904223) & 0xFFFFFFFF;
    return _state / 4294967296;
  }

  /// Factor multiplicativo ~ 1 ± cv (aprox. normal por suma de 3 uniformes).
  double noise(double cv) {
    final z = (next() + next() + next() - 1.5) / 0.5; // media 0, de ≈ 1
    return math.max(0.05, 1 + cv * z);
  }
}
