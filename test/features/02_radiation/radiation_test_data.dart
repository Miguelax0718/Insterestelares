import 'dart:convert';
import 'dart:io';

import 'package:astramed/features/02_radiation/data/radiation_csv_parser.dart';
import 'package:astramed/features/02_radiation/data/radiation_sample_repository.dart';
import 'package:astramed/features/02_radiation/models/crew_profile.dart';

/// Synchronous local fixtures keep widget tests independent of asset-channel IO.
RadiationMissionData loadRadiationTestMission() {
  const root = 'DB/samples/radiation';
  final profiles =
      jsonDecode(File('$root/crew_profiles.json').readAsStringSync()) as List;
  return RadiationMissionData(
    crewProfiles: [
      for (final p in profiles)
        CrewProfile(
          id: p['id'] as String,
          name: p['name'] as String,
          ageYears: p['ageYears'] as int,
          sex: p['sex'] as String,
          priorCareerEffectiveDoseMsv: (p['priorCareerEffectiveDoseMsv'] as num)
              .toDouble(),
        ),
    ],
    dosimetry: RadiationCsvParser.parseDosimetry(
      File('$root/dosimetry_daily.csv').readAsStringSync(),
    ),
    spaceWeather: RadiationCsvParser.parseSpaceWeather(
      File('$root/space_weather.csv').readAsStringSync(),
    ),
  );
}
