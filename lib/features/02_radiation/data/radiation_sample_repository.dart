import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/crew_profile.dart';
import '../models/daily_radiation_record.dart';
import '../models/space_weather_reading.dart';
import 'radiation_csv_parser.dart';

/// All locally bundled radiation-demo data needed by the feature.
class RadiationMissionData {
  RadiationMissionData({
    required List<CrewProfile> crewProfiles,
    required List<DailyRadiationRecord> dosimetry,
    required List<SpaceWeatherReading> spaceWeather,
  })  : crewProfiles = List.unmodifiable(crewProfiles),
        dosimetry = List.unmodifiable(dosimetry),
        spaceWeather = List.unmodifiable(spaceWeather);

  final List<CrewProfile> crewProfiles;
  final List<DailyRadiationRecord> dosimetry;
  final List<SpaceWeatherReading> spaceWeather;
}

/// Loads the demo datasets from Flutter's offline asset bundle.
class RadiationSampleRepository {
  RadiationSampleRepository({AssetBundle? assetBundle})
      : _assetBundle = assetBundle ?? rootBundle;

  static const _crewProfilesAsset =
      'DB/samples/radiation/crew_profiles.json';
  static const _dosimetryAsset =
      'DB/samples/radiation/dosimetry_daily.csv';
  static const _spaceWeatherAsset =
      'DB/samples/radiation/space_weather.csv';

  final AssetBundle _assetBundle;

  Future<RadiationMissionData> load() async {
    final contents = await Future.wait<String>([
      _assetBundle.loadString(_crewProfilesAsset),
      _assetBundle.loadString(_dosimetryAsset),
      _assetBundle.loadString(_spaceWeatherAsset),
    ]);

    final profiles = _parseCrewProfiles(contents[0]);
    final dosimetry = RadiationCsvParser.parseDosimetry(contents[1]);
    final spaceWeather = RadiationCsvParser.parseSpaceWeather(contents[2]);

    final crewIds = profiles.map((profile) => profile.id).toSet();
    final unknownCrewIds = dosimetry
        .map((record) => record.astronautId)
        .where((id) => !crewIds.contains(id))
        .toSet();
    if (unknownCrewIds.isNotEmpty) {
      throw FormatException(
        'Dosimetry contains astronaut IDs without profiles: ${unknownCrewIds.join(', ')}.',
      );
    }

    return RadiationMissionData(
      crewProfiles: profiles,
      dosimetry: dosimetry,
      spaceWeather: spaceWeather,
    );
  }
}

List<CrewProfile> _parseCrewProfiles(String jsonText) {
  final decoded = jsonDecode(jsonText);
  if (decoded is! List) {
    throw const FormatException('Crew profile JSON must contain a list.');
  }

  final profiles = <CrewProfile>[];
  final seenIds = <String>{};
  for (final item in decoded) {
    if (item is! Map<String, dynamic>) {
      throw const FormatException('Each crew profile must be a JSON object.');
    }

    final id = _requiredString(item, 'id');
    if (!seenIds.add(id)) {
      throw FormatException('Duplicate crew profile ID: $id.');
    }

    final age = item['ageYears'];
    if (age is! int || age < 1) {
      throw FormatException('Crew profile $id must have a positive integer ageYears.');
    }
    final priorDose = item['priorCareerEffectiveDoseMsv'];
    if (priorDose is! num || !priorDose.isFinite || priorDose < 0) {
      throw FormatException(
        'Crew profile $id must have a finite, non-negative priorCareerEffectiveDoseMsv.',
      );
    }

    profiles.add(CrewProfile(
      id: id,
      name: _requiredString(item, 'name'),
      ageYears: age,
      sex: _requiredString(item, 'sex'),
      priorCareerEffectiveDoseMsv: priorDose.toDouble(),
    ));
  }
  if (profiles.isEmpty) {
    throw const FormatException('Crew profile JSON must not be empty.');
  }
  return profiles;
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('Crew profile field $key must be a non-empty string.');
  }
  return value.trim();
}
