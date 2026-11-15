import 'dart:async';

import 'package:astramed/core/constants/medical_thresholds.dart';
import 'package:astramed/features/01_general_health/agent/artifact_filter_engine.dart';
import 'package:astramed/features/01_general_health/agent/cross_correlation_engine.dart';
import 'package:astramed/features/02_radiation/agent/donki_space_weather_service.dart';
import 'package:astramed/features/02_radiation/models/radiation_dose.dart';
import 'package:astramed/features/agent/application/agent_conversation_controller.dart';
import 'package:astramed/features/agent/domain/agent_contracts.dart';
import 'package:astramed/features/crew/models/astronaut_profile.dart';

/// In-memory [AgentNotifier] retaining delivered [ProactiveEvent]s and
/// exposing a broadcast stream for UI alert banners.
class InAppAgentNotifier implements AgentNotifier {
  InAppAgentNotifier({this.maxHistory = 100});

  final int maxHistory;
  final List<ProactiveEvent> _events = [];
  final StreamController<ProactiveEvent> _controller =
      StreamController<ProactiveEvent>.broadcast();

  List<ProactiveEvent> get notifications => List<ProactiveEvent>.unmodifiable(_events);

  Stream<ProactiveEvent> get stream => _controller.stream;

  ProactiveEvent? get latest => _events.isEmpty ? null : _events.last;

  @override
  Future<void> notify(ProactiveEvent event) async {
    _events.add(event);
    if (maxHistory > 0 && _events.length > maxHistory) {
      _events.removeRange(0, _events.length - maxHistory);
    }
    if (!_controller.isClosed) {
      _controller.add(event);
    }
  }

  void dismiss(String eventId) {
    _events.removeWhere((e) => e.id == eventId);
  }

  void clear() {
    _events.clear();
  }

  Future<void> dispose() async {
    if (!_controller.isClosed) {
      await _controller.close();
    }
  }
}

class _EmittedRecord {
  const _EmittedRecord({required this.timestamp, required this.severity});

  final DateTime timestamp;
  final ProactiveSeverity severity;
}

/// On-device clinical monitor watching live vitals (through [ArtifactFilterEngine]),
/// space weather / radiation, and scheduled countermeasures, with per-(astronautId, kind)
/// cooldown deduplication and warning->critical escalation bypass (S4, S9).
class ProactiveMonitor {
  ProactiveMonitor({
    this.notifier,
    this.orchestrator,
    this.artifactFilter = const ArtifactFilterEngine(),
    this.correlationEngine = const CrossCorrelationEngine(),
    this.cooldown = const Duration(minutes: 5),
    this.language = 'en',
    DateTime Function()? clock,
    this.crewReader,
    this.spaceWeatherReader,
    this.flagsReader,
    this.memoryReader,
  }) : _clock = clock ?? (() => DateTime.now().toUtc());

  static const Duration defaultCooldown = Duration(minutes: 5);
  static const Duration diaryOverdueThreshold = Duration(hours: 24);
  static const double criticalRadiationDoseRateThreshold = 160.0;
  static const double warningRadiationDoseRateThreshold = 100.0;

  final AgentNotifier? notifier;
  final AgentConversationOrchestrator? orchestrator;
  final ArtifactFilterEngine artifactFilter;
  final CrossCorrelationEngine correlationEngine;
  final Duration cooldown;
  final String language;
  final DateTime Function() _clock;
  final FutureOr<List<AstronautProfile>> Function()? crewReader;
  final FutureOr<SpaceWeatherSnapshot?> Function()? spaceWeatherReader;
  final FutureOr<Map<String, Map<String, dynamic>>> Function(String astronautId)?
      flagsReader;
  final FutureOr<List<MemoryEntry>> Function(String astronautId)? memoryReader;

  final Map<String, _EmittedRecord> _lastEmitted = {};
  final StreamController<ProactiveEvent> _eventController =
      StreamController<ProactiveEvent>.broadcast();
  Timer? _timer;
  int _sequence = 0;

  Stream<ProactiveEvent> get events => _eventController.stream;

  void resetCooldowns() => _lastEmitted.clear();

  void start({Duration interval = const Duration(seconds: 30)}) {
    _timer?.cancel();
    _timer = Timer.periodic(interval, (_) {
      unawaited(tick());
    });
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> dispose() async {
    stop();
    if (!_eventController.isClosed) {
      await _eventController.close();
    }
  }

  Future<List<ProactiveEvent>> tick({DateTime? now}) async {
    final readCrew = crewReader;
    if (readCrew == null) {
      return const [];
    }
    final crew = await readCrew();
    final readWeather = spaceWeatherReader;
    final spaceWeather = readWeather != null ? await readWeather() : null;
    final flagsByAstronaut = <String, Map<String, Map<String, dynamic>>>{};
    final memoriesByAstronaut = <String, List<MemoryEntry>>{};
    final readFlags = flagsReader;
    final readMemory = memoryReader;

    for (final member in crew) {
      if (readFlags != null) {
        flagsByAstronaut[member.id] = await readFlags(member.id);
      }
      if (readMemory != null) {
        memoriesByAstronaut[member.id] = await readMemory(member.id);
      }
    }

    return evaluate(
      crew: crew,
      spaceWeather: spaceWeather,
      flagsByAstronaut: flagsByAstronaut,
      memoriesByAstronaut: memoriesByAstronaut,
      now: now,
    );
  }

  Future<List<ProactiveEvent>> evaluate({
    required List<AstronautProfile> crew,
    SpaceWeatherSnapshot? spaceWeather,
    SepEvent? sepEvent,
    Map<String, Map<String, Map<String, dynamic>>> flagsByAstronaut = const {},
    Map<String, List<MemoryEntry>> memoriesByAstronaut = const {},
    Map<String, double> accelerationRmsGByAstronaut = const {},
    Map<String, double> motionArtifactIndexByAstronaut = const {},
    Map<String, RenalStoneRiskAssessment> renalRiskByAstronaut = const {},
    Map<String, bool> lbnpTargetMissedByAstronaut = const {},
    DateTime? now,
  }) async {
    final ts = (now ?? _clock()).toUtc();
    final emitted = <ProactiveEvent>[];

    for (final profile in crew) {
      final astronautEvents = await evaluateAstronaut(
        profile: profile,
        spaceWeather: spaceWeather,
        sepEvent: sepEvent,
        activeFlags: flagsByAstronaut[profile.id] ?? const {},
        recentMemories: memoriesByAstronaut[profile.id] ?? const [],
        accelerationRmsG: accelerationRmsGByAstronaut[profile.id] ?? 0.0,
        motionArtifactIndex: motionArtifactIndexByAstronaut[profile.id],
        renalStoneRisk: renalRiskByAstronaut[profile.id],
        lbnpTargetMissed: lbnpTargetMissedByAstronaut[profile.id] ?? false,
        now: ts,
      );
      emitted.addAll(astronautEvents);
    }

    return emitted;
  }

  Future<List<ProactiveEvent>> evaluateAstronaut({
    required AstronautProfile profile,
    SpaceWeatherSnapshot? spaceWeather,
    SepEvent? sepEvent,
    Map<String, Map<String, dynamic>> activeFlags = const {},
    List<MemoryEntry> recentMemories = const [],
    double accelerationRmsG = 0.0,
    double? motionArtifactIndex,
    RenalStoneRiskAssessment? renalStoneRisk,
    bool lbnpTargetMissed = false,
    DateTime? now,
  }) async {
    final ts = (now ?? _clock()).toUtc();
    final candidates = <ProactiveEvent>[];

    _collectVitalAlerts(
      candidates: candidates,
      profile: profile,
      accelerationRmsG: accelerationRmsG,
      motionArtifactIndex: motionArtifactIndex,
      now: ts,
    );
    _collectRadiationAndWeatherAlerts(
      candidates: candidates,
      profile: profile,
      spaceWeather: spaceWeather,
      sepEvent: sepEvent,
      now: ts,
    );
    _collectScheduledAndCascadeAlerts(
      candidates: candidates,
      profile: profile,
      activeFlags: activeFlags,
      recentMemories: recentMemories,
      renalStoneRisk: renalStoneRisk,
      lbnpTargetMissed: lbnpTargetMissed,
      now: ts,
    );

    final delivered = <ProactiveEvent>[];
    for (final candidate in candidates) {
      if (!_shouldEmit(candidate, ts)) {
        continue;
      }
      _lastEmitted['${candidate.astronautId}::${candidate.kind}'] =
          _EmittedRecord(timestamp: ts, severity: candidate.severity);
      delivered.add(candidate);
      if (!_eventController.isClosed) {
        _eventController.add(candidate);
      }
      await notifier?.notify(candidate);
      await orchestrator?.handleProactiveEvent(candidate);
    }

    return delivered;
  }

  bool _shouldEmit(ProactiveEvent candidate, DateTime now) {
    final key = '${candidate.astronautId}::${candidate.kind}';
    final previous = _lastEmitted[key];
    if (previous == null) {
      return true;
    }
    final elapsed = now.difference(previous.timestamp);
    if (elapsed >= cooldown) {
      return true;
    }
    return candidate.severity.index > previous.severity.index;
  }

  void _collectVitalAlerts({
    required List<ProactiveEvent> candidates,
    required AstronautProfile profile,
    required double accelerationRmsG,
    required double? motionArtifactIndex,
    required DateTime now,
  }) {
    final v = profile.vitals;
    final isExercisingVitals =
        v.activityState.trim().toLowerCase() == 'exercise' ||
        accelerationRmsG >= ArtifactFilterEngine.highMotionRmsThresholdG;

    final filterResult = artifactFilter.classify(
      vitals: v,
      accelerationRmsG: accelerationRmsG,
      motionArtifactIndex: motionArtifactIndex,
      exercise: isExercisingVitals ? profile.exercise : null,
    );

    if (filterResult.classification == ArtifactClassification.trueClinicalAlert &&
        !filterResult.suppressAlarm) {
      final isCritical =
          v.spO2 < 90.0 ||
          v.heartRate > 115.0 ||
          v.heartRate > ArtifactFilterEngine.maxExercisePhysiologicalHr ||
          v.systolicBP < 85.0 ||
          v.respiratoryRate >= ArtifactFilterEngine.severeTachypneaThresholdRpm ||
          v.capillaryRefillSeconds >
              ArtifactFilterEngine.prolongedCapillaryRefillSeconds;

      final severity =
          isCritical ? ProactiveSeverity.critical : ProactiveSeverity.warning;

      final String kind;
      if (v.spO2 < MedicalThresholds.minSpO2) {
        kind = 'hypoxia_alert';
      } else if (v.heartRate > MedicalThresholds.maxHeartRate) {
        kind = 'tachycardia_alert';
      } else if (v.systolicBP < MedicalThresholds.minSystolicBP) {
        kind = 'hypotension_alert';
      } else {
        kind = 'vitals_alert';
      }

      final message = _isSpanish
          ? '${profile.name}: alerta clínica de signos vitales (SpO2 ${v.spO2.toStringAsFixed(0)}%, FC ${v.heartRate.toStringAsFixed(0)} bpm). ${filterResult.recommendedAction}'
          : '${profile.name}: vital sign alert (SpO2 ${v.spO2.toStringAsFixed(0)}%, HR ${v.heartRate.toStringAsFixed(0)} bpm). ${filterResult.recommendedAction}';

      candidates.add(
        _buildEvent(
          astronautId: profile.id,
          severity: severity,
          kind: kind,
          skillId: 'status_report',
          title: isCritical
              ? 'Critical Vital Alert (${profile.callsign})'
              : 'Vital Warning (${profile.callsign})',
          message: message,
          classification: filterResult.classification.wireName,
          recommendedAction: filterResult.recommendedAction,
          details: filterResult.reasons,
          data: filterResult.toJson(),
          now: now,
        ),
      );
    }

    // Additional vital thresholds not flagged by ArtifactFilterEngine.
    if (v.heartRate < MedicalThresholds.minHeartRate) {
      final isCritical = v.heartRate < 45.0;
      candidates.add(
        _buildEvent(
          astronautId: profile.id,
          severity:
              isCritical ? ProactiveSeverity.critical : ProactiveSeverity.warning,
          kind: 'bradycardia_alert',
          skillId: 'status_report',
          title: 'Bradycardia Alert (${profile.callsign})',
          message: _isSpanish
              ? '${profile.name}: frecuencia cardíaca baja (${v.heartRate.toStringAsFixed(0)} bpm). Evaluar ritmo y síntomas.'
              : '${profile.name}: low heart rate (${v.heartRate.toStringAsFixed(0)} bpm). Evaluate ECG and symptoms.',
          classification: 'bradycardia',
          recommendedAction: 'Check 3-lead ECG and orthostatic tolerance.',
          now: now,
        ),
      );
    }

    if (v.systolicBP > 150.0) {
      final isCritical = v.systolicBP > 160.0;
      candidates.add(
        _buildEvent(
          astronautId: profile.id,
          severity:
              isCritical ? ProactiveSeverity.critical : ProactiveSeverity.warning,
          kind: 'hypertension_alert',
          skillId: 'status_report',
          title: 'Blood Pressure Alert (${profile.callsign})',
          message: _isSpanish
              ? '${profile.name}: presión sistólica elevada (${v.systolicBP.toStringAsFixed(0)}/${v.diastolicBP.toStringAsFixed(0)} mmHg).'
              : '${profile.name}: elevated blood pressure (${v.systolicBP.toStringAsFixed(0)}/${v.diastolicBP.toStringAsFixed(0)} mmHg).',
          classification: 'hypertension',
          recommendedAction: 'Rest for 5 minutes and repeat cuff measurement.',
          now: now,
        ),
      );
    }

    if (v.bodyTemp > 37.8) {
      final isCritical = v.bodyTemp > 38.0;
      candidates.add(
        _buildEvent(
          astronautId: profile.id,
          severity:
              isCritical ? ProactiveSeverity.critical : ProactiveSeverity.warning,
          kind: 'fever_alert',
          skillId: 'status_report',
          title: 'Temperature Alert (${profile.callsign})',
          message: _isSpanish
              ? '${profile.name}: fiebre detectada (${v.bodyTemp.toStringAsFixed(1)} °C).'
              : '${profile.name}: elevated temperature (${v.bodyTemp.toStringAsFixed(1)} C).',
          classification: 'hyperthermia',
          recommendedAction: 'Evaluate infection markers and hydration.',
          now: now,
        ),
      );
    }
  }

  void _collectRadiationAndWeatherAlerts({
    required List<ProactiveEvent> candidates,
    required AstronautProfile profile,
    required SpaceWeatherSnapshot? spaceWeather,
    required SepEvent? sepEvent,
    required DateTime now,
  }) {
    final rad = profile.radiation;
    if (rad.severity == RadiationSeverity.critical ||
        rad.doseRateMicroSvPerHour > criticalRadiationDoseRateThreshold) {
      candidates.add(
        _buildEvent(
          astronautId: profile.id,
          severity: ProactiveSeverity.critical,
          kind: 'radiation_dose_rate',
          skillId: 'space_weather',
          title: 'Critical Radiation Dose Rate (${profile.callsign})',
          message: _isSpanish
              ? '${profile.name}: tasa de radiación crítica (${rad.doseRateMicroSvPerHour.toStringAsFixed(1)} uSv/h). Refugio inmediato y revisar farmacia.'
              : '${profile.name}: critical radiation dose rate (${rad.doseRateMicroSvPerHour.toStringAsFixed(1)} uSv/h). Shelter immediately and check pharmacy batches.',
          classification: 'radiation_critical',
          recommendedAction:
              'Move to shielded storm shelter and assess astropharmacy batches.',
          data: {
            'dose_rate_usv_h': rad.doseRateMicroSvPerHour,
            'cumulative_msv': rad.cumulativeDoseMilliSv,
          },
          now: now,
        ),
      );
    } else if (rad.severity == RadiationSeverity.warning ||
        rad.doseRateMicroSvPerHour > warningRadiationDoseRateThreshold) {
      candidates.add(
        _buildEvent(
          astronautId: profile.id,
          severity: ProactiveSeverity.warning,
          kind: 'radiation_dose_rate',
          skillId: 'space_weather',
          title: 'Elevated Radiation Dose Rate (${profile.callsign})',
          message: _isSpanish
              ? '${profile.name}: radiación elevada (${rad.doseRateMicroSvPerHour.toStringAsFixed(1)} uSv/h). Monitorear dosimetría.'
              : '${profile.name}: elevated radiation (${rad.doseRateMicroSvPerHour.toStringAsFixed(1)} uSv/h). Monitor dosimetry.',
          classification: 'radiation_warning',
          recommendedAction: 'Review shielding posture and DONKI solar telemetry.',
          data: {
            'dose_rate_usv_h': rad.doseRateMicroSvPerHour,
            'cumulative_msv': rad.cumulativeDoseMilliSv,
          },
          now: now,
        ),
      );
    }

    if (sepEvent != null) {
      final severity = sepEvent.peakFluxPfu >= 10000
          ? ProactiveSeverity.critical
          : (sepEvent.peakFluxPfu >= 100
              ? ProactiveSeverity.warning
              : ProactiveSeverity.info);
      candidates.add(
        _buildEvent(
          astronautId: profile.id,
          severity: severity,
          kind: 'space_weather_sep',
          skillId: 'space_weather',
          title: 'Solar Particle Event (${sepEvent.sepId})',
          message: _isSpanish
              ? 'Evento de partículas solares ${sepEvent.sepId} (${sepEvent.peakFluxPfu.toStringAsFixed(0)} pfu). Verificar lotes expuestos y leucocitos.'
              : 'Solar particle event ${sepEvent.sepId} (${sepEvent.peakFluxPfu.toStringAsFixed(0)} pfu). Check unshielded pharmacy batches and schedule leukocyte counts.',
          classification: 'space_weather_sep',
          recommendedAction:
              'Run assess_pharmacy_radiation and confirm storm countermeasures.',
          data: sepEvent.toJson(),
          now: now,
        ),
      );
    } else if (spaceWeather != null &&
        !spaceWeather.isOfflineFallback &&
        (spaceWeather.stormActive ||
            spaceWeather.sepEvents.isNotEmpty ||
            spaceWeather.alertLevel == 'critical' ||
            spaceWeather.alertLevel == 'warning')) {
      final severity = switch (spaceWeather.alertLevel) {
        'critical' => ProactiveSeverity.critical,
        'warning' => ProactiveSeverity.warning,
        _ => ProactiveSeverity.info,
      };
      candidates.add(
        _buildEvent(
          astronautId: profile.id,
          severity: severity,
          kind: 'space_weather_sep',
          skillId: 'space_weather',
          title: 'Space Weather Alert (${spaceWeather.maxEventClass})',
          message: _isSpanish
              ? 'Alerta solar ${spaceWeather.maxEventClass} (${spaceWeather.peakFluxPfu.toStringAsFixed(0)} pfu). Revisar protección y farmacia.'
              : 'Solar storm ${spaceWeather.maxEventClass} (${spaceWeather.peakFluxPfu.toStringAsFixed(0)} pfu). Review shielding and pharmacy batches.',
          classification: 'space_weather_alert',
          recommendedAction:
              'Assess pharmacy degradation and post-storm leukocyte schedule.',
          data: spaceWeather.toJson(),
          now: now,
        ),
      );
    }
  }

  void _collectScheduledAndCascadeAlerts({
    required List<ProactiveEvent> candidates,
    required AstronautProfile profile,
    required Map<String, Map<String, dynamic>> activeFlags,
    required List<MemoryEntry> recentMemories,
    required RenalStoneRiskAssessment? renalStoneRisk,
    required bool lbnpTargetMissed,
    required DateTime now,
  }) {
    // 1. Scheduled post-storm leukocyte check due.
    final leukFlag = activeFlags['leukocyte_check_scheduled'];
    if (leukFlag != null && leukFlag['completed'] != true) {
      final completedTimes = (leukFlag['completed_times'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toSet();
      final scheduledRaw = leukFlag['scheduled_times'] as List<dynamic>? ?? const [];
      String? dueTimeStr;
      for (final item in scheduledRaw) {
        final raw = item.toString();
        if (completedTimes.contains(raw)) continue;
        final parsed = DateTime.tryParse(raw)?.toUtc();
        if (parsed != null && !now.isBefore(parsed)) {
          dueTimeStr = raw;
          break;
        }
      }
      if (dueTimeStr == null && leukFlag['due_at'] != null) {
        final dueAt = DateTime.tryParse(leukFlag['due_at'].toString())?.toUtc();
        if (dueAt != null && !now.isBefore(dueAt)) {
          dueTimeStr = leukFlag['due_at'].toString();
        }
      }
      if (dueTimeStr != null) {
        candidates.add(
          _buildEvent(
            astronautId: profile.id,
            severity: ProactiveSeverity.warning,
            kind: 'leukocyte_check_due',
            skillId: 'space_weather',
            title: 'Leukocyte Check Due (${profile.callsign})',
            message: _isSpanish
                ? '${profile.name}: control programado de leucocitos post-tormenta vencido ($dueTimeStr).'
                : '${profile.name}: scheduled post-storm leukocyte count is due ($dueTimeStr).',
            classification: 'scheduled_countermeasure',
            recommendedAction:
                'Perform CBC / leukocyte assay and record result.',
            data: {'due_at': dueTimeStr},
            now: now,
          ),
        );
      }
    }

    // 2. Daily voice diary overdue.
    if (_isDailyDiaryOverdue(activeFlags, recentMemories, now)) {
      candidates.add(
        _buildEvent(
          astronautId: profile.id,
          severity: ProactiveSeverity.warning,
          kind: 'daily_diary_overdue',
          skillId: 'diary',
          title: 'Daily Voice Diary Overdue (${profile.callsign})',
          message: _isSpanish
              ? '${profile.name}: tu bitácora diaria de voz está pendiente (>24h).'
              : '${profile.name}: your daily voice diary check-in is overdue (>24h).',
          classification: 'scheduled_countermeasure',
          recommendedAction: 'Record a brief daily voice diary entry.',
          now: now,
        ),
      );
    }

    // 3. Exercise target missed.
    if (!profile.exercise.targetReached) {
      candidates.add(
        _buildEvent(
          astronautId: profile.id,
          severity: ProactiveSeverity.warning,
          kind: 'exercise_target_missed',
          skillId: 'exercise',
          title: 'Exercise Target Missed (${profile.callsign})',
          message: _isSpanish
              ? '${profile.name}: meta de ejercicio resistivo (${profile.exercise.deviceName}) incompleta.'
              : '${profile.name}: musculoskeletal exercise target (${profile.exercise.deviceName}) missed.',
          classification: 'countermeasure_missed',
          recommendedAction:
              'Complete scheduled resistive/cardio countermeasure session.',
          data: {
            'device': profile.exercise.deviceName,
            'duration_minutes': profile.exercise.durationMinutes,
          },
          now: now,
        ),
      );
    }

    // 4. LBNP target missed.
    final lbnpScheduled = activeFlags['lbnp_scheduled'];
    final lbnpDue = lbnpScheduled != null &&
        lbnpScheduled['completed'] != true &&
        (() {
          final dueAt = DateTime.tryParse(
            lbnpScheduled['due_at']?.toString() ?? '',
          )?.toUtc();
          return dueAt != null && !now.isBefore(dueAt);
        })();
    final isLbnpMissed = lbnpTargetMissed ||
        activeFlags['lbnp_missed']?['missed'] == true ||
        lbnpDue;
    if (isLbnpMissed) {
      candidates.add(
        _buildEvent(
          astronautId: profile.id,
          severity: ProactiveSeverity.warning,
          kind: 'lbnp_target_missed',
          skillId: 'procedures',
          title: 'LBNP Countermeasure Pending (${profile.callsign})',
          message: _isSpanish
              ? '${profile.name}: sesión programada de LBNP pendiente o incompleta.'
              : '${profile.name}: scheduled LBNP countermeasure session is overdue.',
          classification: 'countermeasure_missed',
          recommendedAction:
              'Run -20 mmHg LBNP ramp with baseline cuff vitals.',
          now: now,
        ),
      );
    }

    // 5. Renal stone cascade high risk.
    final effectiveRenal = renalStoneRisk ?? _assessRenalFromFlags(profile, activeFlags);
    final explicitHighFlag =
        activeFlags['renal_stone_risk']?['risk_level']?.toString().toLowerCase() ==
            'high';
    if (explicitHighFlag ||
        (effectiveRenal != null &&
            effectiveRenal.riskLevel == CorrelationRiskLevel.high)) {
      candidates.add(
        _buildEvent(
          astronautId: profile.id,
          severity: ProactiveSeverity.warning,
          kind: 'renal_stone_high_risk',
          skillId: 'correlation',
          title: 'High Renal Stone Cascade Risk (${profile.callsign})',
          message: _isSpanish
              ? '${profile.name}: riesgo alto de litiasis renal. Aumentar hidratación y realizar ultrasonido renal.'
              : '${profile.name}: high renal stone cascade risk. Increase hydration and run renal ultrasound.',
          classification: 'renal_stone_risk',
          recommendedAction:
              effectiveRenal?.summary ??
              'Increase hydration to 3000 mL/day and run renal ultrasound.',
          details: effectiveRenal?.contributingFactors ?? const [],
          data: effectiveRenal?.toJson() ?? const {},
          now: now,
        ),
      );
    }
  }

  bool _isDailyDiaryOverdue(
    Map<String, Map<String, dynamic>> activeFlags,
    List<MemoryEntry> recentMemories,
    DateTime now,
  ) {
    final flag = activeFlags['daily_diary_due'] ??
        activeFlags['voice_diary_due'] ??
        activeFlags['daily_diary'];
    if (flag != null) {
      if (flag['completed_today'] == true) {
        return false;
      }
      if (flag['overdue'] == true) {
        return true;
      }
      final dueAt = DateTime.tryParse(flag['due_at']?.toString() ?? '')?.toUtc();
      if (dueAt != null && !now.isBefore(dueAt)) {
        return true;
      }
      final lastCompleted = DateTime.tryParse(
        flag['last_completed_at']?.toString() ?? '',
      )?.toUtc();
      if (lastCompleted != null &&
          now.difference(lastCompleted) >= diaryOverdueThreshold) {
        return true;
      }
    }

    DateTime? latestDiaryAt;
    for (final entry in recentMemories) {
      if (entry.tags.contains('voice_diary')) {
        final created = entry.createdAt.toUtc();
        if (latestDiaryAt == null || created.isAfter(latestDiaryAt)) {
          latestDiaryAt = created;
        }
      }
    }
    if (latestDiaryAt != null &&
        now.difference(latestDiaryAt) >= diaryOverdueThreshold) {
      return true;
    }

    return false;
  }

  RenalStoneRiskAssessment? _assessRenalFromFlags(
    AstronautProfile profile,
    Map<String, Map<String, dynamic>> activeFlags,
  ) {
    final sms = activeFlags['space_motion_sickness'];
    final hydration = activeFlags['hydration'];
    final bone = activeFlags['bone_resorption'];
    if (sms == null && hydration == null && bone == null) {
      return null;
    }

    return correlationEngine.assessRenalStoneRisk(
      profile: profile,
      emesisEpisodes: (sms?['emesis_episodes'] as num?)?.toInt() ?? 0,
      hydrationMlPerDay: (hydration?['ml_per_day'] as num?)?.toDouble(),
      lowUrineOutput: hydration?['low_urine_output'] == true,
      urinaryCalciumMgPerDay:
          (bone?['urinary_calcium_mg_per_day'] as num?)?.toDouble(),
      boneResorptionElevated: bone?['elevated'] == true,
      boneLossPercent: (bone?['bone_loss_percent'] as num?)?.toDouble(),
    );
  }

  ProactiveEvent _buildEvent({
    required String astronautId,
    required ProactiveSeverity severity,
    required String kind,
    required String skillId,
    required String title,
    required String message,
    required String classification,
    required String recommendedAction,
    List<String> details = const [],
    Map<String, dynamic> data = const {},
    required DateTime now,
  }) {
    _sequence++;
    final id = 'proactive-$astronautId-$kind-${now.millisecondsSinceEpoch}-$_sequence';
    final bannerProps = <String, dynamic>{
      'title': title,
      'severity': severity.name,
      'classification': classification,
      'message': message,
      'suppressed': false,
      'recommended_action': recommendedAction,
      'astronaut_id': astronautId,
      'kind': kind,
      'details': details,
    };

    return ProactiveEvent(
      id: id,
      astronautId: astronautId,
      severity: severity,
      kind: kind,
      spokenMessage: message,
      createdAt: now,
      skillId: skillId,
      data: data,
      uiEvents: [
        ShowComponentEvent(ComponentIds.alertBanner, bannerProps),
      ],
    );
  }

  bool get _isSpanish => language.trim().toLowerCase().startsWith('es');
}
