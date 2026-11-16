import 'dart:convert';

import 'package:astramed/features/crew/models/astronaut_profile.dart';

import '../domain/agent_contracts.dart';
import '../domain/guided_assessment_catalog.dart';
import '../../apolo/domain/apolo_models.dart';

class AgentContextBuilder {
  const AgentContextBuilder();

  static const int maxBytes = 16 * 1024;

  /// Shared safety projection for prompts and live read tools.
  static Map<String, dynamic> coherence({
    AstronautProfile? astronaut,
    ApoloAstronautState? apoloState,
    Map<String, dynamic> activeFlags = const {},
  }) {
    final eva = activeFlags['eva_blocked'];
    final blocked = eva is Map && eva['blocked'] == true;
    final critical = astronaut?.riskLevel.name == 'critical' ||
        apoloState?.overallSeverity == ApoloSeverity.crit ||
        (blocked && eva['severity'] == 'crit');
    final warning = astronaut?.riskLevel.name == 'warning' ||
        apoloState?.overallSeverity == ApoloSeverity.warn || blocked;
    return {
      'effective_risk_level': critical ? 'critical' : warning ? 'warning' : 'nominal',
      'critical_causes': <String>{
        if (astronaut?.riskLevel.name == 'critical') ...[
          ...astronaut!.activeAlerts,
          astronaut.riskTitle,
        ],
        if (apoloState != null)
          for (final m in apoloState.rankedModules)
            if (m.severity == ApoloSeverity.crit) '${m.title}: ${m.keyMetric}',
        if (blocked) 'EVA blocked: ${eva['reason'] ?? eva['reasons'] ?? 'NO-GO EVA'}',
      }.where((s) => s.isNotEmpty).toList(),
    };
  }

  static Map<String, dynamic> apoloSummary(ApoloAstronautState state) => {
    'overall_severity': state.overallSeverity.wire,
    'water_ml': state.waterMlToday,
    'water_goal_ml': state.waterGoalMl,
    'exercise_min': state.exerciseMinToday,
    'exercise_goal_min': state.exerciseGoalMin,
    'sample_due': state.sampleSchedule.isDue,
    'sample_status': state.sampleSchedule.shortLabel,
    'urgent_modules': [
      for (final m in state.rankedModules)
        if (m.severity != ApoloSeverity.ok)
          {'id': m.id.name, 'title': m.title, 'sev': m.severity.wire, 'metric': m.keyMetric},
    ],
    'pending_recs': [
      for (final m in state.rankedModules)
        for (final r in m.recommendations)
          if (!r.done) r.text,
    ].take(4).toList(),
  };

  Future<Map<String, dynamic>> build({
    required AstronautProfile astronaut,
    required MemoryStore memory,
    required AgentFlagsStore flags,
    List<String> activeComponentIds = const [],
    int? missionDay,
    ApoloAstronautState? apoloState,
    List<GuidedAssessmentDescriptor> availableTests = const [],
    Map<String, dynamic>? extraFlags,
  }) async {
    final recentMemory = await memory.recentForPrompt(astronaut.id);
    final activeFlags = <String, dynamic>{
      ...await flags.allForAstronaut(astronaut.id), ...?extraFlags,
    };

    final live = <String, dynamic>{
      'id': astronaut.id,
      'name': astronaut.name,
      'role': astronaut.role,
      'mission_day': ?missionDay,
      'risk_level': astronaut.riskLevel.name,
      ...coherence(astronaut: astronaut, apoloState: apoloState, activeFlags: activeFlags),
      if (apoloState != null) 'apolo': apoloSummary(apoloState),
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
      if (availableTests.isNotEmpty)
        'available_tests': availableTests.map((t) => t.toCompactJson()).toList(),
    };

    return _fitToBudget(context);
  }

  Future<Map<String, dynamic>> buildMinimal({
    required String astronautId,
    required MemoryStore memory,
    required AgentFlagsStore flags,
    List<String> activeComponentIds = const [],
    int? missionDay,
    ApoloAstronautState? apoloState,
    List<GuidedAssessmentDescriptor> availableTests = const [],
    Map<String, dynamic>? extraFlags,
  }) async {
    final recentMemory = await memory.recentForPrompt(astronautId);
    final activeFlags = <String, dynamic>{
      ...await flags.allForAstronaut(astronautId), ...?extraFlags,
    };

    final context = <String, dynamic>{
      'live': <String, dynamic>{
        'id': astronautId, 'mission_day': ?missionDay,
        ...coherence(apoloState: apoloState, activeFlags: activeFlags),
        if (apoloState != null) 'apolo': apoloSummary(apoloState),
      },
      if (availableTests.isNotEmpty)
        'available_tests': availableTests.map((t) => t.toCompactJson()).toList(),
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
    live.remove('passive_dimensions');
    if (_encodedByteLength(context) <= maxBytes) {
      return context;
    }
    context.remove('available_tests');
    if (_encodedByteLength(context) <= maxBytes) {
      return context;
    }
    final apolo = live['apolo'];
    if (apolo is Map) apolo.remove('pending_recs');
    final components = context['active_components'] as List<dynamic>;
    while (components.isNotEmpty && _encodedByteLength(context) > maxBytes) {
      components.removeLast();
    }
    if (_encodedByteLength(context) <= maxBytes) {
      return context;
    }

    final alerts = live['active_alerts'];
    if (alerts is List) {
      while (alerts.isNotEmpty && _encodedByteLength(context) > maxBytes) {
        alerts.removeLast();
      }
      if (_encodedByteLength(context) <= maxBytes) {
        return context;
      }
    }

    return <String, dynamic>{
      'live': <String, dynamic>{
        'id': live['id'],
        if (live['name'] != null) 'name': live['name'],
        if (live['risk_level'] != null) 'risk_level': live['risk_level'],
        if (live['effective_risk_level'] != null)
          'effective_risk_level': live['effective_risk_level'],
        if (live['critical_causes'] != null)
          'critical_causes': live['critical_causes'],
      },
    };
  }

  int _encodedByteLength(Map<String, dynamic> value) {
    return utf8.encode(jsonEncode(value)).length;
  }
}
