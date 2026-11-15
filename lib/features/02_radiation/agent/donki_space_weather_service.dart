import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

class SolarFlareEvent {
  const SolarFlareEvent({
    required this.flrId,
    required this.beginTime,
    this.peakTime,
    this.endTime,
    required this.classType,
    this.sourceLocation = '',
    this.activeRegionNum,
  });

  factory SolarFlareEvent.fromJson(Map<String, dynamic> json) {
    final begin = _parseDonkiTime(json['beginTime'] as String?) ?? DateTime.now().toUtc();
    return SolarFlareEvent(
      flrId: json['flrID'] as String? ?? json['flrId'] as String? ?? 'FLR-UNKNOWN',
      beginTime: begin,
      peakTime: _parseDonkiTime(json['peakTime'] as String?),
      endTime: _parseDonkiTime(json['endTime'] as String?),
      classType: (json['classType'] as String? ?? 'C1.0').trim().toUpperCase(),
      sourceLocation: json['sourceLocation'] as String? ?? '',
      activeRegionNum: (json['activeRegionNum'] as num?)?.toInt(),
    );
  }

  final String flrId;
  final DateTime beginTime;
  final DateTime? peakTime;
  final DateTime? endTime;
  final String classType;
  final String sourceLocation;
  final int? activeRegionNum;

  Map<String, dynamic> toJson() => {
    'flrID': flrId,
    'beginTime': beginTime.toUtc().toIso8601String(),
    if (peakTime != null) 'peakTime': peakTime!.toUtc().toIso8601String(),
    if (endTime != null) 'endTime': endTime!.toUtc().toIso8601String(),
    'classType': classType,
    'sourceLocation': sourceLocation,
    if (activeRegionNum != null) 'activeRegionNum': activeRegionNum,
  };
}

class SepEvent {
  const SepEvent({
    required this.sepId,
    required this.eventTime,
    required this.peakFluxPfu,
    required this.durationHours,
    this.instruments = const [],
  });

  factory SepEvent.fromJson(
    Map<String, dynamic> json, {
    String? fallbackFlareClass,
  }) {
    final eventTime =
        _parseDonkiTime(json['eventTime'] as String?) ?? DateTime.now().toUtc();
    final rawInstruments = json['instruments'] as List<dynamic>? ?? const [];
    final instruments = rawInstruments
        .map((e) => e is Map<String, dynamic>
            ? (e['displayName'] as String? ?? e.toString())
            : e.toString())
        .toList(growable: false);

    final explicitFlux =
        (json['peakFluxPfu'] as num?)?.toDouble() ??
        (json['fluxPfu'] as num?)?.toDouble();
    final flux = explicitFlux ?? _estimateFluxFromFlareClass(fallbackFlareClass);
    final duration = (json['durationHours'] as num?)?.toDouble() ?? 12.0;

    return SepEvent(
      sepId: json['sepID'] as String? ?? json['sepId'] as String? ?? 'SEP-UNKNOWN',
      eventTime: eventTime,
      peakFluxPfu: flux,
      durationHours: duration,
      instruments: instruments,
    );
  }

  final String sepId;
  final DateTime eventTime;
  final double peakFluxPfu;
  final double durationHours;
  final List<String> instruments;

  Map<String, dynamic> toJson() => {
    'sepID': sepId,
    'eventTime': eventTime.toUtc().toIso8601String(),
    'peakFluxPfu': peakFluxPfu,
    'durationHours': durationHours,
    'instruments': instruments,
  };
}

class SpaceWeatherSnapshot {
  const SpaceWeatherSnapshot({
    required this.fetchedAt,
    required this.source,
    required this.isOfflineFallback,
    required this.flares,
    required this.sepEvents,
    required this.stormActive,
    required this.alertLevel,
    required this.maxEventClass,
    required this.peakFluxPfu,
    required this.durationHours,
    required this.summary,
  });

  factory SpaceWeatherSnapshot.offlineFallback({DateTime? now}) {
    final ts = (now ?? DateTime.now()).toUtc();
    final eventStart = ts.subtract(const Duration(hours: 6));
    return SpaceWeatherSnapshot(
      fetchedAt: ts,
      source: 'offline_fallback',
      isOfflineFallback: true,
      flares: [
        SolarFlareEvent(
          flrId: 'OFFLINE-FLR-X2.1',
          beginTime: eventStart,
          peakTime: eventStart.add(const Duration(minutes: 25)),
          endTime: eventStart.add(const Duration(hours: 1)),
          classType: 'X2.1',
          sourceLocation: 'S16W34',
          activeRegionNum: 13842,
        ),
      ],
      sepEvents: [
        SepEvent(
          sepId: 'OFFLINE-SEP-S3',
          eventTime: eventStart.add(const Duration(minutes: 40)),
          peakFluxPfu: 1200.0,
          durationHours: 18.0,
          instruments: const ['Bundled NASA/NOAA SPE Baseline'],
        ),
      ],
      stormActive: true,
      alertLevel: 'warning',
      maxEventClass: 'X2.1',
      peakFluxPfu: 1200.0,
      durationHours: 18.0,
      summary:
          'Offline bundled space-weather snapshot: active X2.1 solar flare and S3 SEP event (1200 pfu, 18h).',
    );
  }

  final DateTime fetchedAt;
  final String source; // 'donki_live' | 'cache' | 'offline_fallback'
  final bool isOfflineFallback;
  final List<SolarFlareEvent> flares;
  final List<SepEvent> sepEvents;
  final bool stormActive;
  final String alertLevel; // 'nominal' | 'watch' | 'warning' | 'critical'
  final String maxEventClass;
  final double peakFluxPfu;
  final double durationHours;
  final String summary;

  SpaceWeatherSnapshot asCachedFallback({required DateTime now}) {
    return SpaceWeatherSnapshot(
      fetchedAt: now.toUtc(),
      source: 'cache',
      isOfflineFallback: true,
      flares: flares,
      sepEvents: sepEvents,
      stormActive: stormActive,
      alertLevel: alertLevel,
      maxEventClass: maxEventClass,
      peakFluxPfu: peakFluxPfu,
      durationHours: durationHours,
      summary: '$summary (cached offline fallback)',
    );
  }

  Map<String, dynamic> toJson() => {
    'fetched_at': fetchedAt.toUtc().toIso8601String(),
    'source': source,
    'is_offline_fallback': isOfflineFallback,
    'storm_active': stormActive,
    'alert_level': alertLevel,
    'max_event_class': maxEventClass,
    'peak_flux_pfu': peakFluxPfu,
    'duration_hours': durationHours,
    'flares_count': flares.length,
    'sep_events_count': sepEvents.length,
    'summary': summary,
  };
}

class DonkiSpaceWeatherService {
  DonkiSpaceWeatherService({
    http.Client? client,
    String? apiKey,
    this.timeout = const Duration(seconds: 10),
    this.lookbackDays = 7,
  }) : _client = client ?? http.Client(),
       _apiKey = (apiKey != null && apiKey.trim().isNotEmpty)
           ? apiKey.trim()
           : const String.fromEnvironment(
               'NASA_API_KEY',
               defaultValue: 'DEMO_KEY',
             );

  static const String flrEndpoint = 'https://api.nasa.gov/DONKI/FLR';
  static const String sepEndpoint = 'https://api.nasa.gov/DONKI/SEP';

  final http.Client _client;
  final String _apiKey;
  final Duration timeout;
  final int lookbackDays;

  SpaceWeatherSnapshot? _cachedSnapshot;

  SpaceWeatherSnapshot? get cachedSnapshot => _cachedSnapshot;

  Future<SpaceWeatherSnapshot> fetchLatest({DateTime? now}) async {
    final current = (now ?? DateTime.now()).toUtc();
    final start = current.subtract(Duration(days: lookbackDays));
    final startDate = _formatDate(start);
    final endDate = _formatDate(current);

    try {
      final flrUri = Uri.parse(flrEndpoint).replace(
        queryParameters: {
          'startDate': startDate,
          'endDate': endDate,
          'api_key': _apiKey,
        },
      );
      final sepUri = Uri.parse(sepEndpoint).replace(
        queryParameters: {
          'startDate': startDate,
          'endDate': endDate,
          'api_key': _apiKey,
        },
      );

      final responses = await Future.wait([
        _client.get(flrUri, headers: const {'Accept': 'application/json'}).timeout(timeout),
        _client.get(sepUri, headers: const {'Accept': 'application/json'}).timeout(timeout),
      ]);

      final flrResp = responses[0];
      final sepResp = responses[1];
      if (flrResp.statusCode != 200 || sepResp.statusCode != 200) {
        return _fallback(current);
      }

      final flares = _decodeList(flrResp.body)
          .map(SolarFlareEvent.fromJson)
          .toList(growable: false);
      final maxFlare = _strongestFlareClass(flares);
      final sepEvents = _decodeList(sepResp.body)
          .map((item) => SepEvent.fromJson(item, fallbackFlareClass: maxFlare))
          .toList(growable: false);

      final snapshot = _buildSnapshot(
        now: current,
        flares: flares,
        sepEvents: sepEvents,
      );
      _cachedSnapshot = snapshot;
      return snapshot;
    } catch (_) {
      return _fallback(current);
    }
  }

  SpaceWeatherSnapshot _fallback(DateTime now) {
    final cached = _cachedSnapshot;
    if (cached != null) {
      return cached.asCachedFallback(now: now);
    }
    return SpaceWeatherSnapshot.offlineFallback(now: now);
  }

  SpaceWeatherSnapshot _buildSnapshot({
    required DateTime now,
    required List<SolarFlareEvent> flares,
    required List<SepEvent> sepEvents,
  }) {
    final maxFlareClass = _strongestFlareClass(flares);
    var maxFlux = 0.0;
    var maxDuration = 0.0;
    for (final sep in sepEvents) {
      if (sep.peakFluxPfu > maxFlux) {
        maxFlux = sep.peakFluxPfu;
      }
      if (sep.durationHours > maxDuration) {
        maxDuration = sep.durationHours;
      }
    }

    final stormActive =
        sepEvents.isNotEmpty ||
        maxFlareClass.startsWith('X') ||
        maxFlareClass.startsWith('M');
    final String alertLevel;
    if (maxFlux >= 10000 || maxFlareClass.startsWith('X5')) {
      alertLevel = 'critical';
    } else if (maxFlux >= 100 || maxFlareClass.startsWith('X')) {
      alertLevel = 'warning';
    } else if (stormActive) {
      alertLevel = 'watch';
    } else {
      alertLevel = 'nominal';
    }

    final summary = stormActive
        ? 'DONKI live telemetry: max flare $maxFlareClass, SEP peak ${maxFlux.toStringAsFixed(0)} pfu over ${maxDuration.toStringAsFixed(0)}h ($alertLevel).'
        : 'DONKI live telemetry: nominal solar weather (${flares.length} minor flares, 0 active SEP events).';

    return SpaceWeatherSnapshot(
      fetchedAt: now,
      source: 'donki_live',
      isOfflineFallback: false,
      flares: flares,
      sepEvents: sepEvents,
      stormActive: stormActive,
      alertLevel: alertLevel,
      maxEventClass: maxFlareClass,
      peakFluxPfu: maxFlux,
      durationHours: maxDuration,
      summary: summary,
    );
  }

  static List<Map<String, dynamic>> _decodeList(String body) {
    final trimmed = body.trim();
    if (trimmed.isEmpty) return const [];
    final decoded = jsonDecode(trimmed);
    if (decoded is! List<dynamic>) {
      throw const FormatException('Expected JSON array from DONKI endpoint');
    }
    return decoded.whereType<Map<String, dynamic>>().toList(growable: false);
  }

  static String _formatDate(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  static String _strongestFlareClass(List<SolarFlareEvent> flares) {
    if (flares.isEmpty) return 'NONE';
    var best = flares.first.classType;
    var bestScore = _flareScore(best);
    for (final flare in flares.skip(1)) {
      final score = _flareScore(flare.classType);
      if (score > bestScore) {
        best = flare.classType;
        bestScore = score;
      }
    }
    return best;
  }

  static double _flareScore(String classType) {
    if (classType.isEmpty) return 0;
    final letter = classType[0];
    final magnitude = double.tryParse(classType.substring(1)) ?? 1.0;
    final scale = switch (letter) {
      'X' => 1000.0,
      'M' => 100.0,
      'C' => 10.0,
      'B' => 1.0,
      _ => 0.1,
    };
    return scale * magnitude;
  }
}

DateTime? _parseDonkiTime(String? raw) {
  if (raw == null || raw.trim().isEmpty) return null;
  return DateTime.tryParse(raw.trim())?.toUtc();
}

double _estimateFluxFromFlareClass(String? flareClass) {
  final upper = flareClass?.trim().toUpperCase() ?? '';
  if (upper.startsWith('X')) return 1500.0;
  if (upper.startsWith('M')) return 150.0;
  return 50.0;
}
