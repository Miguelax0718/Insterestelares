import 'dart:io';
import 'dart:math';

/// Genera las muestras de microgravedad de la demo (misión de 180 días):
/// densidad ósea, volumen muscular y sesiones de ejercicio.
///
/// Uso (desde la raíz del repo):
///   dart run lib/features/03_microgravity/data/generate_microgravity_sample.dart
///
/// Escribe en DB/samples/microgravity/ (o la carpeta indicada), para cada
/// escenario (realistic / extreme):
///   `bone_density_ESCENARIO.csv`
///   `muscle_volume_ESCENARIO.csv`
///   `exercise_sessions_ESCENARIO.csv`
///
/// Fuentes y límites en DB/samples/microgravity/README.md.
void main(List<String> args) {
  final dir = Directory(args.isEmpty ? 'DB/samples/microgravity' : args.first)
    ..createSync(recursive: true);
  for (final extreme in [false, true]) {
    final name = extreme ? 'extreme' : 'realistic';
    final sim = simulateMicrogravity(extreme: extreme);
    File('${dir.path}/bone_density_$name.csv').writeAsStringSync(sim.bone);
    File('${dir.path}/muscle_volume_$name.csv').writeAsStringSync(sim.muscle);
    File('${dir.path}/exercise_sessions_$name.csv')
        .writeAsStringSync(sim.exercise);
    stdout.writeln('Escenario $name escrito en ${dir.path}');
  }
}

final DateTime missionDay0 = DateTime.utc(2027, 1, 1, 7);
const int missionLengthDays = 180;

/// Masa corporal (kg) de cada astronauta: estimación del equipo, solo para
/// calcular calorías.
const crewMassKg = {
  'AST-01': 78.0,
  'AST-02': 62.0,
  'AST-03': 80.0,
  'AST-04': 58.0,
  'AST-05': 82.0,
};

/// DMO de partida (g/cm², DXA): valores típicos de adulto sano, estimación
/// del equipo. Lo que sale de la literatura es la VELOCIDAD de pérdida.
const boneSitesBaseline = {
  'lumbar_spine': 1.10,
  'femoral_neck': 0.95,
  'trochanter': 0.80,
  'total_hip': 1.02,
};

/// Pérdida mensual de DMO (%/mes) en vuelos largos con ejercicio:
/// ~1 %/mes en columna y 1–1,5 %/mes en cadera (LeBlanc et al. 2000, Mir).
const boneLossRangePerMonth = {
  'lumbar_spine': (0.8, 1.2),
  'femoral_neck': (1.0, 1.5),
  'trochanter': (1.0, 1.5),
  'total_hip': (1.0, 1.5),
};

/// Cambio de volumen muscular al final de 6 meses (Genc et al. 2010):
/// pantorrilla −10 a −16 %, muslo −4 a −7 %, brazo sin cambio.
const muscleLossRange = {
  'calf': (10.0, 16.0),
  'thigh': (4.0, 7.0),
  'upper_arm': (0.0, 0.0),
};

/// Escenario extremo (HIPOTÉTICO): el ARED se avería el día 60 y no se
/// repara; las pérdidas se aceleran.
const int aredFailureDay = 60;

/// Equipos de contramedidas, objetivo diario (min) y MET de la actividad
/// equivalente en tierra (Compendium of Physical Activities; estimación).
const devices = {
  'ARED': (50, 6.0),
  'T2': (40, 8.0),
  'CEVIS': (40, 7.0),
};

typedef MicrogravitySim = ({String bone, String muscle, String exercise});

MicrogravitySim simulateMicrogravity({required bool extreme}) {
  final rng = Random(extreme ? 6202 : 6201);
  double gauss(double sd) {
    final u1 = 1 - rng.nextDouble();
    final u2 = rng.nextDouble();
    return sqrt(-2 * log(u1)) * cos(2 * pi * u2) * sd;
  }

  double between((double, double) r) => r.$1 + rng.nextDouble() * (r.$2 - r.$1);
  final dataType = extreme ? 'synthetic_hypothetical' : 'synthetic_from_real';

  final bone = StringBuffer()
    ..writeln('mission_day,phase,measured_at,astronaut_id,site,bmd_g_cm2,'
        'change_from_baseline_pct,loss_rate_pct_per_month,measurement_type,'
        'event,data_type');
  final muscle = StringBuffer()
    ..writeln('mission_day,phase,measured_at,astronaut_id,region,'
        'volume_change_pct,measurement_type,event,data_type');
  final exercise = StringBuffer()
    ..writeln('mission_day,date,astronaut_id,device_name,duration_minutes,'
        'target_minutes,calories_burned,target_reached,event,data_type');

  String stamp(int day) => missionDay0.add(Duration(days: day)).toIso8601String();
  final checkpoints = [-30, for (var d = 30; d <= 180; d += 30) d, 182];

  for (final id in crewMassKg.keys) {
    // --- Densidad ósea: DXA antes (−30) y después (182); estimación mensual
    // en vuelo (no hay DXA a bordo).
    final rates = {
      for (final s in boneSitesBaseline.keys)
        s: between(boneLossRangePerMonth[s]!),
    };
    for (final day in checkpoints) {
      final months = day < 0 ? 0.0 : min(day, missionLengthDays) / 30.44;
      final phase = day < 0 ? 'preflight' : day > 180 ? 'postflight' : 'inflight';
      final type = day < 0 || day > 180 ? 'dxa' : 'model_estimate';
      for (final site in boneSitesBaseline.keys) {
        var monthsEffective = months;
        var event = '';
        if (extreme && day > aredFailureDay) {
          // Sin ARED la pérdida es 1,8 veces más rápida (hipotético).
          final before = aredFailureDay / 30.44;
          monthsEffective = before + (months - before) * 1.8;
          event = 'ared_out_of_service';
        }
        final change = -rates[site]! * monthsEffective + (day > 180 ? gauss(0.6) : 0);
        final bmd = boneSitesBaseline[site]! * (1 + change / 100);
        bone.writeln([
          day, phase, stamp(day), id, site,
          bmd.toStringAsFixed(3), change.toStringAsFixed(2),
          rates[site]!.toStringAsFixed(2), type, event, dataType,
        ].join(','));
      }
    }

    // --- Volumen muscular (RM antes y después; curva en vuelo estimada).
    final finalLoss = {
      for (final r in muscleLossRange.keys)
        r: between(muscleLossRange[r]!) * (extreme && r != 'upper_arm' ? 1.6 : 1),
    };
    for (final day in checkpoints) {
      final phase = day < 0 ? 'preflight' : day > 180 ? 'postflight' : 'inflight';
      final type = day < 0 || day > 180 ? 'mri' : 'model_estimate';
      final t = day < 0 ? 0.0 : min(day, missionLengthDays).toDouble();
      // La atrofia es más rápida al inicio: 1 − e^(−t/60), normalizada.
      final shape = (1 - exp(-t / 60)) / (1 - exp(-3));
      for (final region in muscleLossRange.keys) {
        final change = -finalLoss[region]! * shape +
            (type == 'mri' && day > 0 ? gauss(0.8) : 0);
        muscle.writeln([
          day, phase, stamp(day), id, region, change.toStringAsFixed(2), type,
          extreme && day > aredFailureDay ? 'ared_out_of_service' : '',
          dataType,
        ].join(','));
      }
    }

    // --- Sesiones diarias: 6 días por semana, ARED + aeróbico (T2/CEVIS).
    // Total real en la ISS: ~600 min/semana (450–720).
    final lowCompliance = extreme && id == 'AST-03';
    for (var day = 1; day <= missionLengthDays; day++) {
      if (day % 7 == 0) continue; // día de descanso
      final aerobic = day.isEven ? 'T2' : 'CEVIS';
      for (final device in ['ARED', aerobic]) {
        var event = '';
        if (extreme && device == 'ARED' && day >= aredFailureDay) {
          event = 'ared_out_of_service';
        }
        final (target, met) = devices[device]!;
        var minutes = event.isNotEmpty
            ? 0
            : (target + gauss(6) - (lowCompliance ? 18 : 0)).round();
        minutes = minutes.clamp(0, 90);
        final kcal = met * crewMassKg[id]! * minutes / 60;
        exercise.writeln([
          day,
          stamp(day).substring(0, 10),
          id,
          device,
          minutes,
          target,
          kcal.toStringAsFixed(0),
          minutes >= target * 0.9,
          event.isNotEmpty ? event : (lowCompliance ? 'low_compliance' : ''),
          dataType,
        ].join(','));
      }
    }
  }
  return (
    bone: bone.toString(),
    muscle: muscle.toString(),
    exercise: exercise.toString(),
  );
}
