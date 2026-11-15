import 'dart:io';
import 'dart:math';

/// Genera las muestras de sueño de la demo (misión de 180 días).
///
/// Uso (desde la raíz del repo):
///   dart run lib/features/04_mental_health/data/generate_sleep_sample.dart
///
/// Escribe en DB/samples/sleep/ (o la carpeta indicada):
///   `sleep_nightly_realistic.csv`  (synthetic_from_real)
///   `sleep_nightly_extreme.csv`    (synthetic_hypothetical)
///
/// Las horas de sueño siguen la actigrafía real de astronautas de la ISS
/// (Barger et al. 2014, Lancet Neurol 13:904, tabla 1). Fuentes y límites
/// en DB/samples/sleep/README.md.
void main(List<String> args) {
  final dir = Directory(args.isEmpty ? 'DB/samples/sleep' : args.first)
    ..createSync(recursive: true);
  for (final extreme in [false, true]) {
    final name = extreme ? 'extreme' : 'realistic';
    File('${dir.path}/sleep_nightly_$name.csv')
        .writeAsStringSync(simulateSleep(extreme: extreme));
    stdout.writeln('Escenario $name escrito en ${dir.path}');
  }
}

final DateTime missionDay0 = DateTime.utc(2027, 1, 1);
const int missionLengthDays = 180;
const crewIds = ['AST-01', 'AST-02', 'AST-03', 'AST-04', 'AST-05'];

/// Horas de sueño por actigrafía en astronautas de la ISS, media y DE
/// (Barger 2014, tabla 1, columna ISS).
class SleepInterval {
  const SleepInterval(this.label, this.meanHours, this.sdHours);
  final String label;
  final double meanHours;
  final double sdHours;
}

const sl90 = SleepInterval('SL-90', 6.41, 0.65);
const l11 = SleepInterval('L-11', 5.86, 0.94);
const inflightIss = SleepInterval('inflight', 6.09, 0.67);
const r7 = SleepInterval('R+7', 6.95, 1.04);

/// Barger 2014: medicación para dormir en el 11 % de las noches de la ISS
/// (96/852) y en el 60 % de las noches previas a una EVA (shuttle).
const double medicationNightRate = 0.11;
const double medicationPreEvaRate = 0.60;

/// Noches previas a EVA (ejemplo) por astronauta.
const evaNights = <String, Set<int>>{
  'AST-03': {59, 110, 150},
  'AST-01': {110},
};

/// Escenario extremo (HIPOTÉTICO): insomnio por estrés en AST-02, noches en
/// el refugio durante la tormenta solar y un tripulante con privación
/// crónica antes de cada EVA.
bool inShelter(int day) => day >= 95 && day <= 97;

String simulateSleep({required bool extreme}) {
  final rng = Random(extreme ? 5202 : 5201);
  double gauss(double sd) {
    final u1 = 1 - rng.nextDouble();
    final u2 = rng.nextDouble();
    return sqrt(-2 * log(u1)) * cos(2 * pi * u2) * sd;
  }

  int poisson(double lambda) {
    final l = exp(-lambda);
    var k = 0;
    var p = 1.0;
    do {
      k++;
      p *= rng.nextDouble();
    } while (p > l);
    return k - 1;
  }

  final dataType = extreme ? 'synthetic_hypothetical' : 'synthetic_from_real';
  final out = StringBuffer()
    ..writeln('mission_day,phase,interval,night_of,astronaut_id,sleep_hours,'
        'wake_episodes,morning_mood,sleep_medication,pre_eva_night,event,'
        'origin,data_type');

  for (final id in crewIds) {
    // Parte de la DE es diferencia entre personas y parte, entre noches.
    final personOffset = gauss(0.35);
    final nights = <(int, SleepInterval, String)>[
      for (var d = -97; d <= -84; d++) (d, sl90, 'preflight'),
      for (var d = -11; d <= -1; d++) (d, l11, 'preflight'),
      for (var d = 1; d <= missionLengthDays; d++) (d, inflightIss, 'inflight'),
      for (var d = 182; d <= 188; d++) (d, r7, 'postflight'),
    ];

    for (final (day, interval, phase) in nights) {
      final nightSd = sqrt(max(interval.sdHours * interval.sdHours - 0.35 * 0.35, 0.05));
      var hours = interval.meanHours + personOffset + gauss(nightSd);
      final preEva = evaNights[id]?.contains(day) ?? false;
      var event = '';
      var origin = 'simulatedBarger2014';

      if (extreme) {
        if (id == 'AST-02' && day >= 100 && day <= 130) {
          hours = 4.4 + gauss(0.5);
          event = 'stress_insomnia';
        }
        if (inShelter(day)) {
          hours = 3.6 + gauss(0.5);
          event = 'spe_shelter';
        }
        if (id == 'AST-03' && preEva) {
          hours = 3.9 + gauss(0.4);
          event = 'pre_eva_restriction';
        }
        if (event.isNotEmpty) origin = 'hypothetical';
      }

      hours = hours.clamp(2.0, 10.0);
      // Despertares y ánimo: estimación del equipo (sin dato público
      // individual); más despertares y peor ánimo cuanto menos se duerme.
      final wakes = poisson(max(0.8, 2.2 + (6.5 - hours) * 0.6));
      final mood = hours >= 7
          ? 'great'
          : hours >= 6.2
              ? 'good'
              : hours >= 5.5
                  ? 'neutral'
                  : hours >= 4.5
                      ? 'fatigued'
                      : 'stressed';
      final medicated = phase == 'inflight' &&
          rng.nextDouble() <
              (preEva ? medicationPreEvaRate : medicationNightRate) *
                  (event == 'stress_insomnia' ? 4 : 1);

      out.writeln([
        day,
        phase,
        interval.label,
        missionDay0.add(Duration(days: day)).toIso8601String().substring(0, 10),
        id,
        hours.toStringAsFixed(2),
        wakes,
        mood,
        medicated,
        preEva,
        event,
        origin,
        dataType,
      ].join(','));
    }
  }
  return out.toString();
}
