import '../../03_microgravity/agent/exercise_guidance_engine.dart';
import '../../03_microgravity/agent/graybiel_engine.dart';
import '../../03_microgravity/agent/microgravity_skills.dart';
import '../../03_microgravity/agent/procedures_engine.dart';
import '../../03_microgravity/agent/sans_engine.dart';
import '../../apolo/domain/apolo_models.dart';
import '../../apolo/providers/apolo_contract_providers.dart';
import '../../crew/models/astronaut_profile.dart';
import '../../crew/presentation/providers/crew_provider.dart';
import '../domain/agent_contracts.dart';
import '../domain/guided_assessment_catalog.dart';

class ComponentSubmissionResult {
  const ComponentSubmissionResult({
    required this.summary,
    required this.data,
    this.uiEvents = const [],
    this.proactiveEvent,
  });

  final String summary;
  final Map<String, dynamic> data;
  final List<AgentComponentEvent> uiEvents;
  final ProactiveEvent? proactiveEvent;
}

/// Offline clinical evaluation shared by interactive cards and the agent session.
/// Does not clear an existing EVA hold: clearance requires a separate assessment.
class ComponentSubmissionCoordinator {
  ComponentSubmissionCoordinator(this.state);

  final MicrogravitySkillState state;
  int _sequence = 0;

  Future<ComponentSubmissionResult> submit(
    String componentId,
    Map<String, dynamic> result,
    ToolContext ctx,
  ) async {
    var data = Map<String, dynamic>.from(result);
    var flag = '${componentId}_latest';
    var critical = false;
    var title = 'Clinical assessment alert';
    late String summary;
    final events = <AgentComponentEvent>[];

    double number(String key, [double fallback = 0]) {
      final value = result[key];
      if (value == null) return fallback;
      if (value is! num || !value.isFinite) {
        throw FormatException('$key must be a finite number.');
      }
      return value.toDouble();
    }

    switch (componentId) {
      case ComponentIds.graybielQuestionnaire:
        final raw = result['responses'];
        if (raw is! Map) {
          throw const FormatException('responses must be a map.');
        }
        final responses = <GraybielSymptom, GraybielLevel>{};
        for (final entry in raw.entries) {
          final symptom = GraybielSymptom.tryParse(entry.key.toString());
          final level = GraybielLevel.tryParse(entry.value.toString());
          if (symptom == null || level == null) {
            throw const FormatException('Invalid Graybiel symptom or level.');
          }
          responses[symptom] = level;
        }
        final facialPallor = result['facial_pallor'];
        if (facialPallor != null) {
          final level = facialPallor == true
              ? GraybielLevel.minimal
              : GraybielLevel.tryParse(facialPallor.toString());
          if (level != null) responses[GraybielSymptom.pallor] = level;
        }
        final emesis = result['emesis'] == true;
        final evaluation = GraybielEngine.evaluate(responses, emesis: emesis);
        final session = state.graybielFor(ctx.astronautId)..reset();
        for (final entry in responses.entries) {
          session.recordAnswer(entry.key, entry.value);
        }
        session
          ..emesis = emesis
          ..completed = true
          ..lastEvaluation = evaluation;
        data = {...data, ...evaluation.toJson()};
        flag = 'graybiel_latest';
        critical = evaluation.totalScore >= 5 || emesis;
        title = 'NO-GO EVA: Motion Sickness';
        summary = 'Graybiel score ${evaluation.totalScore}'
            '${critical ? ' (NO-GO EVA)' : ''}. ${evaluation.recommendedAction}';
      case MicrogravityCockpitIds.zeroGHorizon:
        final alignment = number('alignment_pct');
        data = {...data, 'rms_error': number('rms_error', number('rms_error_deg')), 'alignment_pct': alignment};
        summary = 'Horizon alignment ${alignment.toStringAsFixed(0)}%. '
            '${alignment < 55 ? 'Repeat habituation with vestibular caution; stop if symptoms increase.' : 'Maintain controlled head-trunk alignment.'}';
      case MicrogravityCockpitIds.dvaGaze:
        final total = number('total');
        final accuracy = result['accuracy_pct'] != null
            ? number('accuracy_pct')
            : (total > 0 ? number('correct_count') * 100 / total : 0.0);
        data = {
          ...data,
          'accuracy_pct': accuracy,
          'gaze_stability_pct': number('gaze_stability_pct'),
          'frequency_hz': 1,
        };
        summary = '1 Hz DVA accuracy ${data['accuracy_pct']}%; gaze stability '
            '${data['gaze_stability_pct']}%. Rest before repeating if dizzy.';
      case ComponentIds.sansGrid:
      case ComponentIds.sansContrast:
      case ComponentIds.sansFocus:
        final previous = state.sansEvaluations[ctx.astronautId];
        final cells = result['distorted_cells'];
        final distorted = cells is List ? cells.length : number('distorted_cells').toInt();
        final evaluation = SansEngine.evaluate(
          nearFocusCm: number('near_focus_cm', previous?.nearFocusCm ?? 25),
          gridMetamorphopsia: result['grid_metamorphopsia'] as bool? ??
              (distorted > 0 || result['wavy_lines'] == true || (previous?.gridMetamorphopsia ?? false)),
          gridScotoma: result['grid_scotoma'] as bool? ??
              (number('scotoma_misses') > 0 || (previous?.gridScotoma ?? false)),
          contrastLogCs: number('contrast_log_cs', previous?.contrastLogCs ?? 1.8),
          contrastLoss: result['contrast_loss'] as bool?,
        );
        state.sansEvaluations[ctx.astronautId] = evaluation;
        data = {...data, ...evaluation.toJson()};
        flag = 'sans_latest';
        critical = evaluation.grade == SansGrade.grade2 || number('delta_diopters') >= 1.5;
        title = 'NO-GO EVA: SANS ocular findings';
        summary = '${evaluation.summary}${critical ? ' NO-GO EVA; request flight surgeon review.' : ''}';
      case ComponentIds.lbnpRamp:
        final current = state.lbnpStates[ctx.astronautId] ?? LbnpEngine.start();
        final emergency =
            result['emergency_release'] == true ||
            result['action'] == 'emergency_release';
        final abort = result['action'] == 'abort' || emergency;
        final transition = abort
            ? LbnpEngine.abort(
                current,
                emergencySyncope: emergency,
                systolicBP: (result['systolic_bp'] as num?)?.toDouble(),
                hrDropBpm: (result['hr_drop_bpm'] as num?)?.toDouble(),
              )
            : LbnpEngine.advance(
                current,
                sealChecked: result['seal_checked'] == true,
                systolicBP: (result['systolic_bp'] as num?)?.toDouble(),
                hrDropBpm: (result['hr_drop_bpm'] as num?)?.toDouble(),
                requestedPhase: result['action'] == 'complete' ? LbnpPhase.completed : null,
              );
        if (!transition.ok) throw FormatException(transition.error ?? 'Invalid LBNP transition.');
        state.lbnpStates[ctx.astronautId] = transition.state;
        data = transition.state.toJson();
        flag = 'lbnp_latest';
        critical = transition.state.emergencyRelease;
        title = 'LBNP emergency release';
        summary = transition.state.instruction;
      case ComponentIds.exerciseMonitor:
        ExerciseGuidanceResult? evaluation;
        List<AstronautProfile> crew = const [];
        try {
          crew = ctx.read<List<AstronautProfile>>(crewMembersProvider);
        } catch (_) {
          // Isolated/offline contexts may not expose crew providers.
        }
        for (final profile in crew) {
          if (profile.id == ctx.astronautId) {
            evaluation = ExerciseGuidanceEngine.evaluate(profile: profile);
            break;
          }
        }
        critical = result['unsafe_vitals'] == true ||
            (evaluation?.unsafeVitals ?? false) ||
            (result['spo2'] != null && number('spo2') < ExerciseGuidanceEngine.minSafeSpO2) ||
            number('heart_rate') > ExerciseGuidanceEngine.maxSafeHeartRate ||
            number('systolic_bp') > ExerciseGuidanceEngine.maxSafeSystolicBP;
        final minutes = number('duration_minutes').toInt();
        if (minutes < 0) throw const FormatException('duration_minutes must not be negative.');
        var logged = false;
        if (!critical && minutes > 0) {
          ApoloStateActions? actions;
          try {
            actions = ctx.read<ApoloStateActions>(apoloActionsProvider);
          } catch (_) {
            // Workout still receives a local clinical record without APOLO.
          }
          logged = actions?.addExercise(minutes, astronautId: ctx.astronautId) ?? false;
        }
        data = {...?evaluation?.toJson(), ...data, 'unsafe_vitals': critical, 'workout_logged': logged};
        flag = 'exercise_latest';
        title = 'Unsafe exercise vitals';
        summary = critical
            ? 'Stop exercise immediately. Unsafe vitals; unload restraints and monitor recovery. NO-GO EVA.'
            : '$minutes workout minutes recorded. Begin a low-load cooldown and hydrate.';
      case ComponentIds.pvtTest:
        final reaction = number('reaction_ms', number('mean_reaction_ms'));
        final lapses = number('lapses').toInt();
        final severity = reaction >= 700
            ? 'critical'
            : (reaction >= 450 || lapses >= 3 ? 'warning' : 'nominal');
        data = {
          ...data,
          'reaction_ms': reaction,
          'lapses': lapses,
          'severity': severity,
        };
        flag = 'pvt_latest';
        summary =
            'Reaction ${reaction.toStringAsFixed(0)} ms, $lapses lapses: $severity fatigue. '
            '${severity == 'nominal' ? 'Continue routine monitoring.' : 'Rest and repeat before safety-critical tasks.'}';
      case ComponentIds.mptTest:
        if (result['accuracy_pct'] != null || result['hits'] != null) {
          final total = number('total');
          final hits = number('hits');
          final accuracy = result['accuracy_pct'] != null
              ? number('accuracy_pct')
              : (total > 0 ? hits * 100 / total : 0.0);
          final severity = accuracy < 50
              ? 'critical'
              : (accuracy < 75 ? 'warning' : 'nominal');
          data = {...data, 'accuracy_pct': accuracy, 'severity': severity};
          flag = 'pvt_latest';
          summary =
              'Motor pointer precision ${accuracy.toStringAsFixed(0)}% ($severity). '
              '${severity == 'nominal' ? 'Continue routine monitoring.' : 'Pause fine motor tasks and re-check coordination.'}';
        } else {
          final reaction = number('reaction_ms', number('mean_reaction_ms'));
          final lapses = number('lapses').toInt();
          final severity = reaction >= 700
              ? 'critical'
              : (reaction >= 450 || lapses >= 3 ? 'warning' : 'nominal');
          data = {
            ...data,
            'reaction_ms': reaction,
            'lapses': lapses,
            'severity': severity,
          };
          flag = 'pvt_latest';
          summary =
              'Motor reaction ${reaction.toStringAsFixed(0)} ms, $lapses lapses: $severity.';
        }
      case ComponentIds.diaryRecorder:
        flag = 'diary_latest';
        summary = 'Sleep, mood, and stress diary recorded. Maintain a regular sleep window and review trends.';
      case ComponentIds.ultrasoundGuide:
        summary = 'Ultrasound scan steps recorded. Save findings for flight surgeon review.';
      case ApoloCockpitIds.manualVitals:
        final hr = number('heart_rate', 70);
        final rr = number('respiratory_rate', 16);
        final cap = number('capillary_refill_seconds', 1.5);
        final temp = number('body_temp', 36.6);
        critical = hr > 115 || hr < 45 || rr >= 26 || cap > 2.5 || temp > 38.0;
        flag = 'manual_vitals_latest';
        title = 'Critical manual vital signs recorded';
        summary =
            'Manual vitals saved: HR ${hr.toStringAsFixed(0)} bpm, '
            'RR ${rr.toStringAsFixed(0)} rpm, refill ${cap.toStringAsFixed(1)}s, '
            'temp ${temp.toStringAsFixed(1)} C.'
            '${critical ? ' Critical threshold exceeded; review triage immediately.' : ''}';
      case ApoloCockpitIds.medicalProcedures:
        final procTitle =
            result['title']?.toString() ??
            result['procedure_id']?.toString() ??
            'medical procedure';
        flag = 'medical_procedures_latest';
        summary = 'Reviewed offline procedure: $procTitle.';
      case ApoloCockpitIds.missionSimulator:
        flag = 'mission_simulator_latest';
        summary = 'Mission simulator state updated.';
      default:
        throw FormatException('Unsupported interactive component: $componentId');
    }

    data = {...data, 'astronaut_id': ctx.astronautId, 'completed': true};
    await ctx.flags.setFlag(ctx.astronautId, flag, data);
    if (critical) {
      await ctx.flags.setFlag(ctx.astronautId, 'eva_blocked', {
        'blocked': true, 'reason': summary, 'source': componentId,
      });
      events.add(ShowComponentEvent(ComponentIds.alertBanner, {
        'severity': 'critical', 'title': title, 'message': summary,
      }));
    }
    events.add(ShowComponentEvent(componentId, {...data, if (critical) 'eva_blocked': true}));
    final id = 'submission-${ctx.now.microsecondsSinceEpoch}-${++_sequence}';
    await ctx.memory.save(MemoryEntry(
      id: id, astronautId: ctx.astronautId, kind: MemoryKind.clinicalEvent,
      summary: summary, createdAt: ctx.now, tags: [componentId], data: data,
    ));
    return ComponentSubmissionResult(
      summary: summary, data: Map.unmodifiable(data), uiEvents: List.unmodifiable(events),
      proactiveEvent: critical ? ProactiveEvent(
        id: id, astronautId: ctx.astronautId, severity: ProactiveSeverity.critical,
        kind: '${componentId}_critical', spokenMessage: summary,
        createdAt: ctx.now, data: data, uiEvents: events,
      ) : null,
    );
  }
}
