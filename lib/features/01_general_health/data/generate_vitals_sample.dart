import 'dart:io';
import 'dart:math';

/// Genera las muestras de signos vitales de la demo (misión de 180 días).
///
/// Uso (desde la raíz del repo):
///   dart run lib/features/01_general_health/data/generate_vitals_sample.dart
///
/// Escribe en DB/samples/vitals/ (o la carpeta indicada):
///   `vitals_daily_realistic.csv`  (synthetic_from_real)
///   `vitals_daily_extreme.csv`    (synthetic_hypothetical)
///
/// Fuentes de cada valor: DB/samples/vitals/README.md.
void main(List<String> args) {
  final dir = Directory(args.isEmpty ? 'DB/samples/vitals' : args.first)
    ..createSync(recursive: true);
  for (final extreme in [false, true]) {
    final name = extreme ? 'extreme' : 'realistic';
    final rows = simulateVitals(extreme: extreme);
    File('${dir.path}/vitals_daily_$name.csv').writeAsStringSync(rows);
    stdout.writeln('Escenario $name escrito en ${dir.path}');
  }
}

/// Día 0 de la misión, igual que en las muestras de biomarcadores.
final DateTime missionDay0 = DateTime.utc(2027, 1, 1, 7);
const int missionLengthDays = 180;

/// Línea base en reposo de cada astronauta. FC y presión son del equipo
/// (perfiles de DB/Users); la glucosa sale de Inspiration4.
class VitalsBaseline {
  const VitalsBaseline(
    this.id,
    this.referenceSubject,
    this.heartRate,
    this.systolic,
    this.diastolic,
    this.bodyTemp,
    this.preflightGlucose,
    this.returnGlucoseRatio,
  );
  final String id;
  final String referenceSubject;
  final double heartRate;
  final double systolic;
  final double diastolic;
  final double bodyTemp;

  /// Glucosa REAL de Inspiration4 (OSD-575) en L-92, L-44 y L-3, mg/dL.
  final List<double> preflightGlucose;

  /// Cambio REAL de la glucosa en R+1 respecto a la media previa.
  final double returnGlucoseRatio;

  double get glucoseMean =>
      preflightGlucose.reduce((a, b) => a + b) / preflightGlucose.length;
}

// Glucosa: OSD-575, LSDS-8 CMP. C001 83/80/69 (R+1 90), C002 69/72/78 (R+1 83),
// C003 77/62/75 (R+1 103), C004 100/83/56 (R+1 97). AST-05 usa la media de
// los cuatro tripulantes.
const crewBaselines = [
  VitalsBaseline('AST-01', 'C001', 64, 118, 76, 36.6, [83, 80, 69], 90 / 77.33),
  VitalsBaseline('AST-02', 'C002', 70, 114, 72, 36.7, [69, 72, 78], 83 / 73.0),
  VitalsBaseline('AST-03', 'C003', 60, 120, 78, 36.5, [77, 62, 75], 103 / 71.33),
  VitalsBaseline('AST-04', 'C004', 66, 112, 72, 36.7, [100, 83, 56], 97 / 79.67),
  VitalsBaseline('AST-05', 'I4_mean', 72, 132, 86, 36.6,
      [82.25, 74.25, 69.5], 93.25 / 75.33),
];

const preflightDays = [-92, -44, -3];
const postflightDays = [181, 182, 187]; // R+0 (aterrizaje), R+1, R+6

/// Eventos del escenario extremo (HIPOTÉTICOS, para probar alertas).
const extremeEvents = <String, Map<int, String>>{
  'AST-01': {95: 'radiation_prodrome', 96: 'radiation_prodrome'},
  'AST-02': {140: 'febrile_infection', 141: 'febrile_infection'},
  'AST-03': {60: 'post_eva_hypoxia'},
  'AST-04': {165: 'dehydration'},
  'AST-05': {120: 'hypertensive_crisis', 121: 'hypertensive_crisis'},
};

/// En R+0, 4 de 5 con intolerancia ortostática (Meck 2001: 5 de 6 tras
/// vuelos largos).
const orthostaticOnLanding = {'AST-01', 'AST-02', 'AST-03', 'AST-05'};

String simulateVitals({required bool extreme}) {
  final rng = Random(extreme ? 4202 : 4201);
  double gauss(double sd) {
    final u1 = 1 - rng.nextDouble();
    final u2 = rng.nextDouble();
    return sqrt(-2 * log(u1)) * cos(2 * pi * u2) * sd;
  }

  String f(double v, [int d = 1]) => v.toStringAsFixed(d);
  final dataType = extreme ? 'synthetic_hypothetical' : 'synthetic_from_real';

  final out = StringBuffer()
    ..writeln('mission_day,phase,measured_at,astronaut_id,activity_state,'
        'heart_rate_bpm,systolic_bp_mmhg,diastolic_bp_mmhg,spo2_pct,'
        'body_temp_c,blood_glucose_mg_dl,respiratory_rate_rpm,'
        'capillary_refill_s,orthostatic_intolerance,event,glucose_origin,'
        'reference_subject,data_type');

  for (final b in crewBaselines) {
    final days = [
      ...preflightDays,
      for (var d = 1; d <= missionLengthDays; d++) d,
      ...postflightDays,
    ];
    for (final day in days) {
      final phase = day < 1
          ? 'preflight'
          : day <= missionLengthDays
              ? 'inflight'
              : 'postflight';
      final inflight = phase == 'inflight';

      // Norsk 2015: en vuelo la presión de 24 h baja 8 (sistólica) y
      // 9 mmHg (diastólica); la FC no cambia. Ajuste en ~2 semanas.
      final adapt = inflight ? min(day / 14, 1.0) : 0.0;
      var hr = b.heartRate + gauss(3);
      var sys = b.systolic - 8 * adapt + gauss(4);
      var dia = b.diastolic - 9 * adapt + gauss(3);

      // Stahn 2017: la temperatura central sube ~1 °C en ~2,5 meses.
      final tempRise = inflight ? (extreme ? 1.3 : 1.0) * min(day / 75, 1.0) : 0.0;
      var temp = b.bodyTemp + tempRise + gauss(0.12);

      var spo2 = 98 + gauss(0.6);
      var rr = 14 + gauss(1.2);
      var refill = 1.4 + gauss(0.2);

      // Glucosa: valor real antes del vuelo; en vuelo, media real + la
      // variación real entre visitas; al regresar, cambio real de R+1.
      double glucose;
      String glucoseOrigin;
      final pre = preflightDays.indexOf(day);
      if (pre >= 0) {
        glucose = b.preflightGlucose[pre];
        glucoseOrigin = b.referenceSubject == 'I4_mean'
            ? 'derivedInspiration4'
            : 'realInspiration4';
      } else if (day == 182) {
        glucose = b.glucoseMean * b.returnGlucoseRatio;
        glucoseOrigin = 'derivedInspiration4';
      } else {
        glucose = b.glucoseMean + gauss(7);
        glucoseOrigin = 'simulated';
      }

      var activity = 'resting';
      var orthostatic = false;
      if (day == 181) {
        activity = 'post_landing';
        orthostatic = orthostaticOnLanding.contains(b.id);
        if (orthostatic) {
          // Tilt/bipedestación tras aterrizar: FC alta y presión baja.
          hr += 25 + gauss(5);
          sys -= 15 + gauss(4);
          dia -= 6 + gauss(3);
        }
      }

      var event = '';
      if (extreme) {
        event = extremeEvents[b.id]?[day] ?? '';
        switch (event) {
          case 'post_eva_hypoxia':
            activity = 'post_eva';
            hr = 118;
            sys = 92;
            dia = 58;
            spo2 = 89;
            rr = 26;
            refill = 3.5;
          case 'radiation_prodrome':
            hr = 104 + gauss(3);
            temp = 38.6 + gauss(0.2);
            rr = 20;
          case 'febrile_infection':
            hr = 110 + gauss(3);
            temp = 38.9 + gauss(0.2);
            rr = 22;
            glucose = 130 + gauss(5);
            spo2 = 95;
          case 'dehydration':
            hr = 112;
            sys = 88;
            dia = 56;
            refill = 3.2;
          case 'hypertensive_crisis':
            hr = 98;
            sys = 168 + gauss(3);
            dia = 104 + gauss(2);
            glucose = 182;
        }
        if (event.isNotEmpty) {
          activity = activity == 'resting' ? 'emergency_triage' : activity;
          glucoseOrigin = event == 'febrile_infection' ||
                  event == 'hypertensive_crisis'
              ? 'hypothetical'
              : glucoseOrigin;
        }
      }

      out.writeln([
        day,
        phase,
        missionDay0.add(Duration(days: day)).toIso8601String(),
        b.id,
        activity,
        f(hr, 0),
        f(sys, 0),
        f(dia, 0),
        f(min(spo2, 100), 0),
        f(temp),
        f(glucose, 0),
        f(rr, 0),
        f(max(refill, 0.8)),
        orthostatic,
        event,
        glucoseOrigin,
        b.referenceSubject,
        dataType,
      ].join(','));
    }
  }
  return out.toString();
}
