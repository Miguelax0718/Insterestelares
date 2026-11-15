import 'dart:convert';

import 'package:astramed/features/crew/models/astronaut_profile.dart';

import '../domain/agent_contracts.dart';

class AgentContextBuilder {
  const AgentContextBuilder();

  static const int maxBytes = 16 * 1024;

  Future<Map<String, dynamic>> build({
    required AstronautProfile astronaut,
    required MemoryStore memory,
    required AgentFlagsStore flags,
    List<String> activeComponentIds = const [],
    int? missionDay,
  }) async {
    final recentMemory = await memory.recentForPrompt(astronaut.id);
    final activeFlags = await flags.allForAstronaut(astronaut.id);

    final live = <String, dynamic>{
      'id': astronaut.id,
      'name': astronaut.name,
      'role': astronaut.role,
      'mission_day': ?missionDay,
      'risk_level': astronaut.riskLevel.name,
      'vitals': <String, dynamic>{
        'heart_rate': astronaut.vitals.heartRate,
        'systolic_bp': astronaut.vitals.systolicBP,
        'diastolic_bp': astronaut.vitals.diastolicBP,
        'spo2': astronaut.vitals.spO2,
        'body_temp': astronaut.vitals.bodyTemp,
        'blood_glucose': astronaut.vitals.bloodGlucose,
        'respiratory_rate': astronaut.vitals.respiratoryRate,
        'capillary_refill_seconds': astronaut.vitals.capillaryRefillSeconds,
        'hrv_rmssd_ms': astronaut.vitals.hrvRmssdMs,
        'hrv_sdnn_ms': astronaut.vitals.hrvSdnnMs,
        'core_temp_heat_flux_c': astronaut.vitals.coreTempHeatFluxC,
        'hydration_bis_calibrated_pct':
            astronaut.vitals.calibratedHydrationIndex,
        'local_co2_mmhg': astronaut.vitals.localCo2MmHg,
        'local_o2_pct': astronaut.vitals.localO2Percent,
      },
      'passive_dimensions': <String, dynamic>{
        'cardiorespiratory_metabolic': <String, dynamic>{
          'hrv_rmssd_ms': astronaut.vitals.hrvRmssdMs,
          'hrv_sdnn_ms': astronaut.vitals.hrvSdnnMs,
          'core_temp_heat_flux_c': astronaut.vitals.coreTempHeatFluxC,
          'hydration_bis_calibrated_pct':
              astronaut.vitals.calibratedHydrationIndex,
        },
        'neurological_sensory': <String, dynamic>{
          'pupil_diameter_mm': astronaut.vitals.pupilDiameterMm,
          'pupillometry_npi': astronaut.vitals.pupillometryNpi,
          'plr_latency_ms': astronaut.vitals.plrLatencyMs,
          'passive_near_focus_cm': astronaut.vitals.passiveNearFocusCm,
          'hyperopic_shift_diopters':
              astronaut.vitals.estimatedHyperopicShiftDiopters,
          'passive_pvt_reaction_ms': astronaut.vitals.passivePvtReactionMs,
          'passive_pvt_lapses': astronaut.vitals.passivePvtLapsesCount,
          'pointer_accuracy_pct': astronaut.vitals.touchPointerAccuracyPercent,
        },
        'musculoskeletal': <String, dynamic>{
          'accelerometry_rms_g': astronaut.vitals.accelerometryRmsG,
          'peak_impact_g': astronaut.vitals.peakImpactG,
          'muscle_volume_retention_pct':
              astronaut.vitals.muscleVolumeRetentionPercent,
          'pennation_angle_deg': astronaut.vitals.pennationAngleDeg,
        },
        'circadian_psychoemotional': <String, dynamic>{
          'sleep_hours': astronaut.sleep.sleepHours,
          'sleep_efficiency_pct': astronaut.vitals.sleepEfficiencyPercent,
          'sleep_fragmentation_index':
              astronaut.vitals.sleepFragmentationIndex,
          'sleep_regularity_index': astronaut.vitals.sleepRegularityIndex,
          'nocturnal_hrv_rmssd_ms': astronaut.vitals.nocturnalHrvRmssdMs,
          'nocturnal_spo2_mean_pct': astronaut.vitals.nocturnalSpO2MeanPercent,
          'nocturnal_desaturations':
              astronaut.vitals.nocturnalDesaturationEvents,
        },
      },
      'active_alerts': List<String>.from(astronaut.activeAlerts),
    };

    final memoryItems = recentMemory
        .map(
          (entry) => <String, dynamic>{
            'kind': entry.kind.wireName,
            'summary': entry.summary,
            'created_at': entry.createdAt.toUtc().toIso8601String(),
          },
        )
        .toList();

    final components = List<String>.from(activeComponentIds);
    final flagsCopy = Map<String, dynamic>.from(activeFlags);

    final context = <String, dynamic>{
      'live': live,
      'memory': memoryItems,
      'active_components': components,
      'flags': flagsCopy,
    };

    return _fitToBudget(context);
  }

  Future<Map<String, dynamic>> buildMinimal({
    required String astronautId,
    required MemoryStore memory,
    required AgentFlagsStore flags,
    List<String> activeComponentIds = const [],
    int? missionDay,
  }) async {
    final recentMemory = await memory.recentForPrompt(astronautId);
    final activeFlags = await flags.allForAstronaut(astronautId);

    final context = <String, dynamic>{
      'live': <String, dynamic>{'id': astronautId, 'mission_day': ?missionDay},
      'memory': recentMemory
          .map(
            (entry) => <String, dynamic>{
              'kind': entry.kind.wireName,
              'summary': entry.summary,
              'created_at': entry.createdAt.toUtc().toIso8601String(),
            },
          )
          .toList(),
      'active_components': List<String>.from(activeComponentIds),
      'flags': Map<String, dynamic>.from(activeFlags),
    };

    return _fitToBudget(context);
  }

  Map<String, dynamic> _fitToBudget(Map<String, dynamic> context) {
    if (_encodedByteLength(context) <= maxBytes) {
      return context;
    }

    final memoryList = context['memory'] as List<dynamic>;
    while (memoryList.isNotEmpty && _encodedByteLength(context) > maxBytes) {
      memoryList.removeLast();
    }
    if (_encodedByteLength(context) <= maxBytes) {
      return context;
    }

    final flagsMap = context['flags'] as Map<String, dynamic>;
    final flagKeys = flagsMap.keys.toList();
    for (final key in flagKeys.reversed) {
      if (_encodedByteLength(context) <= maxBytes) {
        break;
      }
      flagsMap.remove(key);
    }
    if (_encodedByteLength(context) <= maxBytes) {
      return context;
    }

    final live = context['live'] as Map<String, dynamic>;
    final alerts = live['active_alerts'];
    if (alerts is List) {
      while (alerts.isNotEmpty && _encodedByteLength(context) > maxBytes) {
        alerts.removeLast();
      }
    }
    final components = context['active_components'] as List<dynamic>;
    while (components.isNotEmpty && _encodedByteLength(context) > maxBytes) {
      components.removeLast();
    }
    if (_encodedByteLength(context) <= maxBytes) {
      return context;
    }

    if (live.containsKey('passive_dimensions')) {
      live.remove('passive_dimensions');
      if (_encodedByteLength(context) <= maxBytes) {
        return context;
      }
    }

    return <String, dynamic>{
      'live': <String, dynamic>{
        'id': live['id'],
        if (live['name'] != null) 'name': live['name'],
        if (live['risk_level'] != null) 'risk_level': live['risk_level'],
      },
    };
  }

  int _encodedByteLength(Map<String, dynamic> value) {
    return utf8.encode(jsonEncode(value)).length;
  }
}
