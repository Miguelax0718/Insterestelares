import 'dart:convert';
import 'dart:io';

/// Generates a deterministic, illustrative 180-day Mars-transit scenario.
/// All measurements are synthetic and are not suitable for clinical decisions.
void main(List<String> args) {
  final outputDirectory = Directory(
    args.isEmpty ? 'DB/samples/radiation' : args.first,
  );
  outputDirectory.createSync(recursive: true);

  final random = _SeededRandom(20261114);
  final crew = <_CrewProfile>[
    _CrewProfile('AST-01', 'Alex Vance', 46, 'unspecified', 40),
    _CrewProfile('AST-02', 'Dra. Elena Ramos', 38, 'unspecified', 120),
    _CrewProfile('AST-03', 'Ing. Mateo Torres', 34, 'unspecified', 80),
    _CrewProfile('AST-04', 'Dra. Sarah Chen', 31, 'unspecified', 300),
  ];

  _writeProfiles(outputDirectory, crew);
  _writeMissionData(outputDirectory, crew, random);
}

void _writeProfiles(Directory outputDirectory, List<_CrewProfile> crew) {
  final json = crew
      .map((member) => {
            'id': member.id,
            'name': member.name,
            'ageYears': member.ageYears,
            'sex': member.sex,
            'priorCareerEffectiveDoseMsv': member.priorCareerDoseMsv,
            'dataType': 'synthetic_demo',
          })
      .toList();
  File('${outputDirectory.path}/crew_profiles.json').writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert(json),
  );
}

void _writeMissionData(
  Directory outputDirectory,
  List<_CrewProfile> crew,
  _SeededRandom random,
) {
  final dosimetry = StringBuffer()
    ..writeln(
      'mission_day,astronaut_id,module,effective_dose_mSv,skin_mGy_eq,blood_forming_organs_mGy_eq,lens_mGy_eq,circulatory_system_mGy_eq,central_nervous_system_mGy,spe_event_dose_mSv,data_type',
    );
  final spaceWeather = StringBuffer()
    ..writeln('mission_day,proton_flux_pfu,alert_level,event_spe,data_type');

  for (var day = 1; day <= 180; day++) {
    final isSpeDay = day == 95;
    spaceWeather.writeln(
      '$day,${isSpeDay ? 12000 : _round(2 + random.nextDouble() * 18, 2)},${isSpeDay ? 'alert' : 'nominal'},$isSpeDay,synthetic_demo',
    );

    for (var crewIndex = 0; crewIndex < crew.length; crewIndex++) {
      final member = crew[crewIndex];
      final isSheltered = isSpeDay && (crewIndex == 1 || crewIndex == 3);
      final module = isSheltered ? 'storm_shelter' : 'habitat';
      final dailyVariation = (random.nextDouble() +
              random.nextDouble() +
              random.nextDouble()) /
          3;
      final baselineEffectiveDose =
          1.65 + (dailyVariation - 0.5) * 0.3;
      final eventDose = isSpeDay
          ? (isSheltered ? 18.0 : 72.0) + (random.nextDouble() - 0.5) * 8
          : 0.0;
      final effectiveDose = baselineEffectiveDose + eventDose;

      // Organ doses are independently generated scenario values. They are not
      // converted from effective dose because the two dose quantities are not
      // interchangeable and require radiation-spectrum/tissue information.
      final organFactor = isSpeDay ? (isSheltered ? 1.5 : 4.0) : 1.0;
      final skin = (0.42 + random.nextDouble() * 0.16) * organFactor;
      final bloodForming = (0.16 + random.nextDouble() * 0.08) * organFactor;
      final lens = (0.30 + random.nextDouble() * 0.12) * organFactor;
      final circulatory = (0.12 + random.nextDouble() * 0.06) * organFactor;
      final centralNervous = (0.07 + random.nextDouble() * 0.04) * organFactor;

      dosimetry.writeln([
        day,
        member.id,
        module,
        _round(effectiveDose, 3),
        _round(skin, 3),
        _round(bloodForming, 3),
        _round(lens, 3),
        _round(circulatory, 3),
        _round(centralNervous, 3),
        _round(eventDose, 3),
        'synthetic_demo',
      ].join(','));
    }
  }

  File('${outputDirectory.path}/dosimetry_daily.csv')
      .writeAsStringSync(dosimetry.toString());
  File('${outputDirectory.path}/space_weather.csv')
      .writeAsStringSync(spaceWeather.toString());
}

double _round(double value, int places) {
  var factor = 1.0;
  for (var index = 0; index < places; index++) {
    factor *= 10;
  }
  return (value * factor).round() / factor;
}

class _CrewProfile {
  const _CrewProfile(
    this.id,
    this.name,
    this.ageYears,
    this.sex,
    this.priorCareerDoseMsv,
  );

  final String id;
  final String name;
  final int ageYears;
  final String sex;
  final double priorCareerDoseMsv;
}

/// Small fixed algorithm so generated values do not depend on dart:math RNG
/// implementation details or platform-specific random seeds.
class _SeededRandom {
  _SeededRandom(int seed) : _state = seed & 0xFFFFFFFF;

  int _state;

  double nextDouble() {
    _state = (1664525 * _state + 1013904223) & 0xFFFFFFFF;
    return _state / 4294967296;
  }
}
