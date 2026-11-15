import '../../agent/domain/agent_contracts.dart';
import '../../pharmacy/data/asset_pharmacy_inventory_repository.dart';
import '../../pharmacy/domain/astropharmacy_engine.dart';
import '../../pharmacy/domain/pharmacy_inventory_repository.dart';
import 'donki_space_weather_service.dart';

class SpaceWeatherAlertViewModel extends AgentViewModel {
  const SpaceWeatherAlertViewModel({
    super.title = 'Space Weather & Solar Radiation',
    required this.alertLevel,
    required this.stormActive,
    required this.maxEventClass,
    required this.peakFluxPfu,
    required this.durationHours,
    required this.source,
    required this.isOfflineFallback,
    required this.fetchedAt,
    required this.summary,
    required this.flaresCount,
    required this.sepEventsCount,
  }) : super(componentId: ComponentIds.spaceWeatherAlert);

  factory SpaceWeatherAlertViewModel.fromSnapshot(
    SpaceWeatherSnapshot snapshot,
  ) {
    return SpaceWeatherAlertViewModel(
      alertLevel: snapshot.alertLevel,
      stormActive: snapshot.stormActive,
      maxEventClass: snapshot.maxEventClass,
      peakFluxPfu: snapshot.peakFluxPfu,
      durationHours: snapshot.durationHours,
      source: snapshot.source,
      isOfflineFallback: snapshot.isOfflineFallback,
      fetchedAt: snapshot.fetchedAt,
      summary: snapshot.summary,
      flaresCount: snapshot.flares.length,
      sepEventsCount: snapshot.sepEvents.length,
    );
  }

  factory SpaceWeatherAlertViewModel.fromProps(Map<String, dynamic> props) {
    final alertLevel = props['alert_level'];
    final stormActive = props['storm_active'];
    final maxEventClass = props['max_event_class'];
    final peakFluxPfu = props['peak_flux_pfu'];
    final durationHours = props['duration_hours'];
    final source = props['source'];
    final isOfflineFallback = props['is_offline_fallback'];
    final fetchedAt = props['fetched_at'];
    final summary = props['summary'];

    if (alertLevel is! String ||
        stormActive is! bool ||
        maxEventClass is! String ||
        peakFluxPfu is! num ||
        durationHours is! num ||
        source is! String ||
        isOfflineFallback is! bool ||
        fetchedAt is! String ||
        summary is! String) {
      throw const FormatException('Invalid space_weather_alert props');
    }

    return SpaceWeatherAlertViewModel(
      title: props['title'] as String? ?? 'Space Weather & Solar Radiation',
      alertLevel: alertLevel,
      stormActive: stormActive,
      maxEventClass: maxEventClass,
      peakFluxPfu: peakFluxPfu.toDouble(),
      durationHours: durationHours.toDouble(),
      source: source,
      isOfflineFallback: isOfflineFallback,
      fetchedAt: DateTime.parse(fetchedAt),
      summary: summary,
      flaresCount: (props['flares_count'] as num?)?.toInt() ?? 0,
      sepEventsCount: (props['sep_events_count'] as num?)?.toInt() ?? 0,
    );
  }

  final String alertLevel;
  final bool stormActive;
  final String maxEventClass;
  final double peakFluxPfu;
  final double durationHours;
  final String source;
  final bool isOfflineFallback;
  final DateTime fetchedAt;
  final String summary;
  final int flaresCount;
  final int sepEventsCount;

  @override
  Map<String, dynamic> toProps() => {
    'title': title,
    'alert_level': alertLevel,
    'storm_active': stormActive,
    'max_event_class': maxEventClass,
    'peak_flux_pfu': peakFluxPfu,
    'duration_hours': durationHours,
    'source': source,
    'is_offline_fallback': isOfflineFallback,
    'fetched_at': fetchedAt.toUtc().toIso8601String(),
    'summary': summary,
    'flares_count': flaresCount,
    'sep_events_count': sepEventsCount,
  };
}

class PharmacyBatchItemViewModel {
  const PharmacyBatchItemViewModel({
    required this.batchId,
    required this.medication,
    required this.route,
    required this.storageLocation,
    required this.unitsRemaining,
    required this.degradationPct,
    required this.deltaPct,
    required this.flagged,
    required this.compromised,
  });

  factory PharmacyBatchItemViewModel.fromJson(Map<String, dynamic> json) {
    final batchId = json['batch_id'];
    final medication = json['medication'];
    final route = json['route'];
    final storageLocation = json['storage_location'];
    final unitsRemaining = json['units_remaining'];
    final degradationPct = json['degradation_pct'];
    final deltaPct = json['delta_pct'];
    final flagged = json['flagged'];
    final compromised = json['compromised'];
    if (batchId is! String ||
        medication is! String ||
        route is! String ||
        storageLocation is! String ||
        unitsRemaining is! num ||
        degradationPct is! num ||
        deltaPct is! num ||
        flagged is! bool ||
        compromised is! bool) {
      throw const FormatException('Invalid pharmacy batch item props');
    }
    return PharmacyBatchItemViewModel(
      batchId: batchId,
      medication: medication,
      route: route,
      storageLocation: storageLocation,
      unitsRemaining: unitsRemaining.toInt(),
      degradationPct: degradationPct.toDouble(),
      deltaPct: deltaPct.toDouble(),
      flagged: flagged,
      compromised: compromised,
    );
  }

  final String batchId;
  final String medication;
  final String route;
  final String storageLocation;
  final int unitsRemaining;
  final double degradationPct;
  final double deltaPct;
  final bool flagged;
  final bool compromised;

  Map<String, dynamic> toJson() => {
    'batch_id': batchId,
    'medication': medication,
    'route': route,
    'storage_location': storageLocation,
    'units_remaining': unitsRemaining,
    'degradation_pct': degradationPct,
    'delta_pct': deltaPct,
    'flagged': flagged,
    'compromised': compromised,
  };
}

class PharmacyBatchesViewModel extends AgentViewModel {
  const PharmacyBatchesViewModel({
    super.title = 'Astropharmacy Radiation Assessment',
    required this.eventClass,
    required this.doseEquivalentMsv,
    required this.ramanVerificationRequired,
    required this.leukocyteCheckTimes,
    required this.batches,
    required this.summary,
  }) : super(componentId: ComponentIds.pharmacyBatches);

  factory PharmacyBatchesViewModel.fromAssessment(
    AstropharmacyAssessment assessment,
  ) {
    return PharmacyBatchesViewModel(
      eventClass: assessment.eventClass,
      doseEquivalentMsv: double.parse(
        assessment.doseEquivalentMsv.toStringAsFixed(2),
      ),
      ramanVerificationRequired: assessment.ramanVerificationRequired,
      leukocyteCheckTimes: assessment.leukocyteCheckTimes,
      batches: assessment.batchAssessments
          .map(
            (a) => PharmacyBatchItemViewModel.fromJson(a.toJson()),
          )
          .toList(growable: false),
      summary: assessment.summary,
    );
  }

  factory PharmacyBatchesViewModel.fromProps(Map<String, dynamic> props) {
    final eventClass = props['event_class'];
    final doseEquivalentMsv = props['dose_equivalent_msv'];
    final ramanRequired = props['raman_verification_required'];
    final rawTimes = props['leukocyte_check_times'];
    final rawBatches = props['batches'];
    final summary = props['summary'];

    if (eventClass is! String ||
        doseEquivalentMsv is! num ||
        ramanRequired is! bool ||
        rawTimes is! List<dynamic> ||
        rawBatches is! List<dynamic> ||
        summary is! String) {
      throw const FormatException('Invalid pharmacy_batches props');
    }

    return PharmacyBatchesViewModel(
      title: props['title'] as String? ?? 'Astropharmacy Radiation Assessment',
      eventClass: eventClass,
      doseEquivalentMsv: doseEquivalentMsv.toDouble(),
      ramanVerificationRequired: ramanRequired,
      leukocyteCheckTimes: rawTimes
          .map((e) => DateTime.parse(e.toString()).toUtc())
          .toList(growable: false),
      batches: rawBatches
          .whereType<Map<String, dynamic>>()
          .map(PharmacyBatchItemViewModel.fromJson)
          .toList(growable: false),
      summary: summary,
    );
  }

  final String eventClass;
  final double doseEquivalentMsv;
  final bool ramanVerificationRequired;
  final List<DateTime> leukocyteCheckTimes;
  final List<PharmacyBatchItemViewModel> batches;
  final String summary;

  @override
  Map<String, dynamic> toProps() => {
    'title': title,
    'event_class': eventClass,
    'dose_equivalent_msv': doseEquivalentMsv,
    'raman_verification_required': ramanVerificationRequired,
    'leukocyte_check_times': leukocyteCheckTimes
        .map((t) => t.toUtc().toIso8601String())
        .toList(growable: false),
    'batches': batches.map((b) => b.toJson()).toList(growable: false),
    'summary': summary,
  };
}

class RamanRequestViewModel extends AgentViewModel {
  const RamanRequestViewModel({
    super.title = 'Raman Spectrometry Verification',
    required this.batchIds,
    required this.reason,
    required this.priority,
    required this.requestedAt,
    required this.status,
  }) : super(componentId: ComponentIds.ramanRequest);

  factory RamanRequestViewModel.fromProps(Map<String, dynamic> props) {
    final rawIds = props['batch_ids'];
    final reason = props['reason'];
    final priority = props['priority'];
    final requestedAt = props['requested_at'];
    final status = props['status'];

    if (rawIds is! List<dynamic> ||
        reason is! String ||
        priority is! String ||
        requestedAt is! String ||
        status is! String) {
      throw const FormatException('Invalid raman_request props');
    }

    return RamanRequestViewModel(
      title: props['title'] as String? ?? 'Raman Spectrometry Verification',
      batchIds: rawIds.map((e) => e.toString()).toList(growable: false),
      reason: reason,
      priority: priority,
      requestedAt: DateTime.parse(requestedAt).toUtc(),
      status: status,
    );
  }

  final List<String> batchIds;
  final String reason;
  final String priority;
  final DateTime requestedAt;
  final String status;

  @override
  Map<String, dynamic> toProps() => {
    'title': title,
    'batch_ids': batchIds,
    'reason': reason,
    'priority': priority,
    'requested_at': requestedAt.toUtc().toIso8601String(),
    'status': status,
  };
}

class MedicationCheckViewModel extends AgentViewModel {
  const MedicationCheckViewModel({
    super.title = 'Medication Safety Check',
    required this.astronautId,
    required this.medication,
    required this.doseMg,
    required this.route,
    required this.allowed,
    required this.reasons,
    this.batchId,
    this.remainingUnits,
    this.suggestedAlternativeRoute,
  }) : super(componentId: ComponentIds.medicationCheck);

  factory MedicationCheckViewModel.fromCheck({
    required MedicationRequest request,
    required MedicationCheck check,
  }) {
    return MedicationCheckViewModel(
      astronautId: request.astronautId,
      medication: request.medication,
      doseMg: request.doseMg,
      route: request.route,
      allowed: check.allowed,
      reasons: check.reasons,
      batchId: check.batchId,
      remainingUnits: check.remainingUnits,
      suggestedAlternativeRoute: check.suggestedAlternativeRoute,
    );
  }

  factory MedicationCheckViewModel.fromProps(Map<String, dynamic> props) {
    final astronautId = props['astronaut_id'];
    final medication = props['medication'];
    final doseMg = props['dose_mg'];
    final route = props['route'];
    final allowed = props['allowed'];
    final reasons = props['reasons'];

    if (astronautId is! String ||
        medication is! String ||
        doseMg is! num ||
        route is! String ||
        allowed is! bool ||
        reasons is! List<dynamic>) {
      throw const FormatException('Invalid medication_check props');
    }

    return MedicationCheckViewModel(
      title: props['title'] as String? ?? 'Medication Safety Check',
      astronautId: astronautId,
      medication: medication,
      doseMg: doseMg.toDouble(),
      route: route,
      allowed: allowed,
      reasons: reasons.map((e) => e.toString()).toList(growable: false),
      batchId: props['batch_id'] as String?,
      remainingUnits: (props['remaining_units'] as num?)?.toInt(),
      suggestedAlternativeRoute: props['suggested_alternative_route'] as String?,
    );
  }

  final String astronautId;
  final String medication;
  final double doseMg;
  final String route;
  final bool allowed;
  final List<String> reasons;
  final String? batchId;
  final int? remainingUnits;
  final String? suggestedAlternativeRoute;

  @override
  Map<String, dynamic> toProps() => {
    'title': title,
    'astronaut_id': astronautId,
    'medication': medication,
    'dose_mg': doseMg,
    'route': route,
    'allowed': allowed,
    'reasons': reasons,
    if (batchId != null) 'batch_id': batchId,
    if (remainingUnits != null) 'remaining_units': remainingUnits,
    if (suggestedAlternativeRoute != null)
      'suggested_alternative_route': suggestedAlternativeRoute,
  };
}

int _actionSequence = 0;

String _nextActionId(String actionType, DateTime now) {
  _actionSequence++;
  return '${actionType}_${now.microsecondsSinceEpoch}_$_actionSequence';
}

class GetSpaceWeatherTool extends AgentTool {
  GetSpaceWeatherTool(this._service);

  final DonkiSpaceWeatherService _service;

  @override
  String get name => 'get_space_weather';

  @override
  String get description =>
      'Fetch latest solar flare and SEP space weather events from NASA DONKI (or offline cache/fallback).';

  @override
  ToolEffect get effect => ToolEffect.ui;

  @override
  Map<String, dynamic> get parameters => const {
    'type': 'object',
    'properties': <String, dynamic>{},
  };

  @override
  Future<ToolResult> call(Map<String, dynamic> args, ToolContext ctx) async {
    final snapshot = await _service.fetchLatest(now: ctx.now);
    final vm = SpaceWeatherAlertViewModel.fromSnapshot(snapshot);
    return ToolResult.ok(
      snapshot.toJson(),
      uiEvents: [AgentComponentEvent.show(ComponentIds.spaceWeatherAlert, vm.toProps())],
    );
  }
}

class AssessPharmacyRadiationTool extends AgentTool {
  AssessPharmacyRadiationTool({
    required this.repository,
    required this.spaceWeatherService,
    required this.engine,
  });

  final PharmacyInventoryRepository repository;
  final DonkiSpaceWeatherService spaceWeatherService;
  final AstropharmacyEngine engine;

  @override
  String get name => 'assess_pharmacy_radiation';

  @override
  String get description =>
      'Compute per-batch chemical degradation across pharmacy storage locations for a solar particle event.';

  @override
  ToolEffect get effect => ToolEffect.ui;

  @override
  Map<String, dynamic> get parameters => const {
    'type': 'object',
    'properties': {
      'sep_flux_pfu': {'type': 'number', 'description': 'Peak proton flux in pfu'},
      'duration_hours': {'type': 'number', 'description': 'Event duration in hours'},
      'event_class': {'type': 'string', 'description': 'Solar flare class (e.g. X2.2)'},
    },
  };

  @override
  Future<ToolResult> call(Map<String, dynamic> args, ToolContext ctx) async {
    double? flux = (args['sep_flux_pfu'] as num?)?.toDouble();
    double? duration = (args['duration_hours'] as num?)?.toDouble();
    String? eventClass = args['event_class'] as String?;

    if (flux == null || duration == null || eventClass == null) {
      final snapshot =
          spaceWeatherService.cachedSnapshot ??
          await spaceWeatherService.fetchLatest(now: ctx.now);
      flux ??= snapshot.peakFluxPfu;
      duration ??= snapshot.durationHours;
      eventClass ??= snapshot.maxEventClass;
    }

    final batches = await repository.getBatches();
    final assessment = engine.assessStorm(
      batches: batches,
      sepFluxPfu: flux,
      durationHours: duration,
      eventClass: eventClass,
      peakTime: ctx.now,
    );
    final vm = PharmacyBatchesViewModel.fromAssessment(assessment);

    return ToolResult.ok(
      {
        'event_class': assessment.eventClass,
        'dose_equivalent_msv': assessment.doseEquivalentMsv,
        'compromised_batch_ids':
            assessment.compromisedBatches.map((b) => b.batchId).toList(),
        'raman_verification_required': assessment.ramanVerificationRequired,
        'leukocyte_check_times': assessment.leukocyteCheckTimes
            .map((t) => t.toUtc().toIso8601String())
            .toList(),
        'summary': assessment.summary,
      },
      uiEvents: [AgentComponentEvent.show(ComponentIds.pharmacyBatches, vm.toProps())],
    );
  }
}

class FlagBatchesTool extends AgentTool {
  FlagBatchesTool(this._repository);

  final PharmacyInventoryRepository _repository;

  @override
  String get name => 'flag_batches';

  @override
  String get description =>
      'Flag compromised medication batches to block dispensing. Requires crew confirmation.';

  @override
  ToolEffect get effect => ToolEffect.consequential;

  @override
  Map<String, dynamic> get parameters => const {
    'type': 'object',
    'required': ['batch_ids', 'reason'],
    'properties': {
      'batch_ids': {
        'type': 'array',
        'items': {'type': 'string'},
      },
      'reason': {'type': 'string'},
    },
  };

  @override
  Future<ToolResult> call(Map<String, dynamic> args, ToolContext ctx) async {
    final batchIds = (args['batch_ids'] as List<dynamic>? ?? const [])
        .map((e) => e.toString().trim())
        .where((e) => e.isNotEmpty)
        .toList(growable: false);
    final reason = (args['reason'] as String? ?? 'Radiation degradation check')
        .trim();

    if (batchIds.isEmpty) {
      return const ToolResult.fail('batch_ids must be a non-empty list');
    }

    final actionId = _nextActionId('flag_batches', ctx.now);
    final action = ConsequentialAction(
      id: actionId,
      astronautId: ctx.astronautId,
      actionType: 'flag_batches',
      description: 'Flag medication batches ${batchIds.join(', ')}: $reason',
      payload: {'batch_ids': batchIds, 'reason': reason},
    );

    final decision = await ctx.confirm.request(
      action,
      onConfirmed: () async {
        final flaggedIds = <String>[];
        for (final id in batchIds) {
          final existing = await _repository.getBatchById(id);
          if (existing != null) {
            await _repository.flagBatch(id, reason: reason);
            flaggedIds.add(id);
          }
        }
        final existingFlag = await ctx.flags.getFlag(
          ctx.astronautId,
          'flagged_batches',
        );
        final priorIds = (existingFlag?['batch_ids'] as List<dynamic>? ?? const [])
            .map((e) => e.toString())
            .toSet();
        final mergedIds = {...priorIds, ...flaggedIds}.toList(growable: false);
        await ctx.flags.setFlag(ctx.astronautId, 'flagged_batches', {
          'batch_ids': mergedIds,
          'reason': reason,
          'updated_at': ctx.now.toUtc().toIso8601String(),
        });
        await ctx.audit.append(
          AuditEntry(
            id: '${actionId}_audit',
            astronautId: ctx.astronautId,
            actionType: 'flag_batches',
            description: action.description,
            payload: {'batch_ids': flaggedIds, 'reason': reason},
            decision: ConfirmationDecision.confirmed,
            timestamp: ctx.now,
            reason: reason,
          ),
        );
        return {'flagged_batch_ids': flaggedIds};
      },
    );

    if (decision != ConfirmationDecision.confirmed) {
      return ToolResult.ok({
        'confirmed': false,
        'decision': decision.wireName,
        'action_id': actionId,
        'batch_ids': batchIds,
      });
    }

    return ToolResult.ok({
      'confirmed': true,
      'decision': decision.wireName,
      'action_id': actionId,
      'flagged_batch_ids': batchIds,
      'reason': reason,
    });
  }
}

class RequestRamanCheckTool extends AgentTool {
  const RequestRamanCheckTool();

  @override
  String get name => 'request_raman_check';

  @override
  String get description =>
      'Request Raman spectrometry potency verification for radiation-exposed batches. Requires crew confirmation.';

  @override
  ToolEffect get effect => ToolEffect.consequential;

  @override
  Map<String, dynamic> get parameters => const {
    'type': 'object',
    'required': ['batch_ids', 'reason'],
    'properties': {
      'batch_ids': {
        'type': 'array',
        'items': {'type': 'string'},
      },
      'reason': {'type': 'string'},
      'priority': {
        'type': 'string',
        'enum': ['routine', 'urgent', 'critical'],
      },
    },
  };

  @override
  Future<ToolResult> call(Map<String, dynamic> args, ToolContext ctx) async {
    final batchIds = (args['batch_ids'] as List<dynamic>? ?? const [])
        .map((e) => e.toString().trim())
        .where((e) => e.isNotEmpty)
        .toList(growable: false);
    final reason = (args['reason'] as String? ?? 'Post-SPE potency verification')
        .trim();
    final priority = (args['priority'] as String? ?? 'urgent').trim();

    if (batchIds.isEmpty) {
      return const ToolResult.fail('batch_ids must be a non-empty list');
    }

    final actionId = _nextActionId('request_raman_check', ctx.now);
    final action = ConsequentialAction(
      id: actionId,
      astronautId: ctx.astronautId,
      actionType: 'request_raman_check',
      description:
          'Request Raman spectrometry check for ${batchIds.join(', ')} ($priority)',
      payload: {'batch_ids': batchIds, 'reason': reason, 'priority': priority},
    );

    final vm = RamanRequestViewModel(
      batchIds: batchIds,
      reason: reason,
      priority: priority,
      requestedAt: ctx.now,
      status: 'requested',
    );

    final decision = await ctx.confirm.request(
      action,
      onConfirmed: () async {
        await ctx.flags.setFlag(ctx.astronautId, 'raman_check_requested', {
          'batch_ids': batchIds,
          'reason': reason,
          'priority': priority,
          'requested_at': ctx.now.toUtc().toIso8601String(),
        });
        await ctx.audit.append(
          AuditEntry(
            id: '${actionId}_audit',
            astronautId: ctx.astronautId,
            actionType: 'request_raman_check',
            description: action.description,
            payload: action.payload,
            decision: ConfirmationDecision.confirmed,
            timestamp: ctx.now,
            reason: reason,
          ),
        );
        return vm.toProps();
      },
    );

    if (decision != ConfirmationDecision.confirmed) {
      return ToolResult.ok({
        'confirmed': false,
        'decision': decision.wireName,
        'action_id': actionId,
        'batch_ids': batchIds,
      });
    }

    return ToolResult.ok(
      {
        'confirmed': true,
        'decision': decision.wireName,
        'action_id': actionId,
        ...vm.toProps(),
      },
      uiEvents: [AgentComponentEvent.show(ComponentIds.ramanRequest, vm.toProps())],
    );
  }
}

class ScheduleLeukocyteCountTool extends AgentTool {
  const ScheduleLeukocyteCountTool();

  @override
  String get name => 'schedule_leukocyte_count';

  @override
  String get description =>
      'Schedule post-storm leukocyte / CBC blood checks (+24h and +72h after SPE peak). Requires crew confirmation.';

  @override
  ToolEffect get effect => ToolEffect.consequential;

  @override
  Map<String, dynamic> get parameters => const {
    'type': 'object',
    'properties': {
      'hours_after_peak': {
        'type': 'array',
        'items': {'type': 'integer'},
      },
      'peak_time': {'type': 'string'},
    },
  };

  @override
  Future<ToolResult> call(Map<String, dynamic> args, ToolContext ctx) async {
    final rawHours =
        args['hours_after_peak'] as List<dynamic>? ??
        AstropharmacyEngine.postStormLeukocyteHours;
    final hours = rawHours
        .map((e) => (e as num).toInt())
        .where((h) => h > 0)
        .toList(growable: false);
    final effectiveHours = hours.isEmpty
        ? AstropharmacyEngine.postStormLeukocyteHours
        : hours;

    final peak = args['peak_time'] is String
        ? (DateTime.tryParse(args['peak_time'] as String)?.toUtc() ?? ctx.now)
        : ctx.now;
    final scheduledTimes = effectiveHours
        .map((h) => peak.add(Duration(hours: h)).toUtc().toIso8601String())
        .toList(growable: false);

    final actionId = _nextActionId('schedule_leukocyte_count', ctx.now);
    final action = ConsequentialAction(
      id: actionId,
      astronautId: ctx.astronautId,
      actionType: 'schedule_leukocyte_count',
      description:
          'Schedule post-storm leukocyte counts at +${effectiveHours.join('h, +')}h',
      payload: {
        'hours_after_peak': effectiveHours,
        'scheduled_times': scheduledTimes,
      },
    );

    final decision = await ctx.confirm.request(
      action,
      onConfirmed: () async {
        await ctx.flags.setFlag(ctx.astronautId, 'leukocyte_check_scheduled', {
          'hours_after_peak': effectiveHours,
          'scheduled_times': scheduledTimes,
          'scheduled_at': ctx.now.toUtc().toIso8601String(),
        });
        await ctx.audit.append(
          AuditEntry(
            id: '${actionId}_audit',
            astronautId: ctx.astronautId,
            actionType: 'schedule_leukocyte_count',
            description: action.description,
            payload: action.payload,
            decision: ConfirmationDecision.confirmed,
            timestamp: ctx.now,
          ),
        );
        return {'scheduled_times': scheduledTimes};
      },
    );

    if (decision != ConfirmationDecision.confirmed) {
      return ToolResult.ok({
        'confirmed': false,
        'decision': decision.wireName,
        'action_id': actionId,
      });
    }

    return ToolResult.ok({
      'confirmed': true,
      'decision': decision.wireName,
      'action_id': actionId,
      'hours_after_peak': effectiveHours,
      'scheduled_times': scheduledTimes,
    });
  }
}

class CheckMedicationTool extends AgentTool {
  const CheckMedicationTool();

  @override
  String get name => 'check_medication';

  @override
  String get description =>
      'Validate medication dose, route, stock, batch radiation status, and crew allergies deterministically.';

  @override
  ToolEffect get effect => ToolEffect.ui;

  @override
  Map<String, dynamic> get parameters => const {
    'type': 'object',
    'required': ['medication', 'dose_mg', 'route'],
    'properties': {
      'astronaut_id': {'type': 'string'},
      'medication': {'type': 'string'},
      'dose_mg': {'type': 'number'},
      'route': {
        'type': 'string',
        'enum': ['oral', 'intranasal', 'intramuscular'],
      },
      'indication': {'type': 'string'},
    },
  };

  @override
  Future<ToolResult> call(Map<String, dynamic> args, ToolContext ctx) async {
    final medication = (args['medication'] as String? ?? '').trim();
    final doseMg = (args['dose_mg'] as num?)?.toDouble() ?? 0.0;
    final route = (args['route'] as String? ?? 'oral').trim();
    final astronautId =
        (args['astronaut_id'] as String?)?.trim().isNotEmpty == true
        ? (args['astronaut_id'] as String).trim()
        : ctx.astronautId;
    final indication = args['indication'] as String?;

    final request = MedicationRequest(
      astronautId: astronautId,
      medication: medication,
      doseMg: doseMg,
      route: route,
      indication: indication,
    );
    final check = await ctx.medication.validate(request);
    final vm = MedicationCheckViewModel.fromCheck(
      request: request,
      check: check,
    );

    return ToolResult.ok(
      check.toJson(),
      uiEvents: [AgentComponentEvent.show(ComponentIds.medicationCheck, vm.toProps())],
    );
  }
}

class SpaceWeatherOfflineFlow implements DeterministicFlow {
  SpaceWeatherOfflineFlow({
    required this.spaceWeatherService,
    required this.repository,
    required this.engine,
  });

  final DonkiSpaceWeatherService spaceWeatherService;
  final PharmacyInventoryRepository repository;
  final AstropharmacyEngine engine;

  AstropharmacyAssessment? _lastAssessment;

  @override
  String get skillId => 'space_weather';

  @override
  Future<DeterministicStep> start(ToolContext ctx) async {
    final snapshot = await spaceWeatherService.fetchLatest(now: ctx.now);
    final weatherVm = SpaceWeatherAlertViewModel.fromSnapshot(snapshot);
    final batches = await repository.getBatches();
    final assessment = engine.assessStorm(
      batches: batches,
      sepFluxPfu: snapshot.peakFluxPfu,
      durationHours: snapshot.durationHours,
      eventClass: snapshot.maxEventClass,
      peakTime: ctx.now,
    );
    _lastAssessment = assessment;
    final batchesVm = PharmacyBatchesViewModel.fromAssessment(assessment);

    final uiEvents = [
      AgentComponentEvent.show(ComponentIds.spaceWeatherAlert, weatherVm.toProps()),
      AgentComponentEvent.show(ComponentIds.pharmacyBatches, batchesVm.toProps()),
    ];

    if (assessment.compromisedBatches.isEmpty) {
      return DeterministicStep(
        prompt:
            'Offline space-weather check (${snapshot.maxEventClass}): all pharmacy batches remain within safe shielding limits.',
        uiEvents: uiEvents,
        isTerminal: true,
        verdict: {
          'storm_active': snapshot.stormActive,
          'compromised_batches': const <String>[],
          'raman_verification_required': assessment.ramanVerificationRequired,
        },
      );
    }

    final ids = assessment.compromisedBatches.map((b) => b.batchId).join(', ');
    return DeterministicStep(
      prompt:
          'Offline solar storm check (${snapshot.maxEventClass}, ${snapshot.peakFluxPfu.toStringAsFixed(0)} pfu): '
          '${assessment.compromisedBatches.length} batch(es) ($ids) projected >=15% degradation. '
          'Flag compromised batches, request Raman verification, and schedule post-storm leukocyte counts?',
      options: const ['Confirm all actions', 'Flag batches only', 'Skip'],
      uiEvents: uiEvents,
    );
  }

  @override
  Future<DeterministicStep> advance(String userInput, ToolContext ctx) async {
    final assessment = _lastAssessment;
    if (assessment == null) {
      return start(ctx);
    }

    final normalized = userInput.trim().toLowerCase();
    final compromisedIds =
        assessment.compromisedBatches.map((b) => b.batchId).toList(growable: false);

    if (normalized.contains('skip') ||
        normalized == 'no' ||
        normalized.contains('cancel')) {
      return const DeterministicStep(
        prompt: 'No pharmacy or scheduling changes applied.',
        isTerminal: true,
        verdict: {
          'confirmed': false,
          'flagged_batches': <String>[],
          'raman_requested': false,
          'leukocyte_scheduled': false,
        },
      );
    }

    final flagTool = FlagBatchesTool(repository);
    final flagRes = await flagTool.call({
      'batch_ids': compromisedIds,
      'reason': 'Offline SPE degradation >= 15% (${assessment.eventClass})',
    }, ctx);
    final flagConfirmed = flagRes.data['confirmed'] == true;

    if (normalized.contains('flag') && !normalized.contains('all')) {
      return DeterministicStep(
        prompt: flagConfirmed
            ? 'Flagged compromised batches: ${compromisedIds.join(', ')}.'
            : 'Batch flagging was not confirmed.',
        isTerminal: true,
        verdict: {
          'confirmed': flagConfirmed,
          'flagged_batches': flagConfirmed ? compromisedIds : const <String>[],
          'raman_requested': false,
          'leukocyte_scheduled': false,
        },
      );
    }

    final ramanTool = const RequestRamanCheckTool();
    final ramanRes = await ramanTool.call({
      'batch_ids': compromisedIds,
      'reason': 'Offline SPE potency check (${assessment.eventClass})',
      'priority': 'urgent',
    }, ctx);
    final ramanConfirmed = ramanRes.data['confirmed'] == true;

    final leukTool = const ScheduleLeukocyteCountTool();
    final leukRes = await leukTool.call({
      'hours_after_peak': AstropharmacyEngine.postStormLeukocyteHours,
      'peak_time': ctx.now.toUtc().toIso8601String(),
    }, ctx);
    final leukConfirmed = leukRes.data['confirmed'] == true;

    return DeterministicStep(
      prompt: (flagConfirmed && ramanConfirmed && leukConfirmed)
          ? 'Confirmed: flagged ${compromisedIds.join(', ')}, requested Raman check, and scheduled +24h/+72h leukocyte counts.'
          : 'Completed offline review (flag: $flagConfirmed, raman: $ramanConfirmed, leukocyte: $leukConfirmed).',
      uiEvents: ramanRes.uiEvents,
      isTerminal: true,
      verdict: {
        'confirmed': flagConfirmed || ramanConfirmed || leukConfirmed,
        'flagged_batches': flagConfirmed ? compromisedIds : const <String>[],
        'raman_requested': ramanConfirmed,
        'leukocyte_scheduled': leukConfirmed,
      },
    );
  }
}

List<AgentSkill> radiationAndPharmacySkills({
  DonkiSpaceWeatherService? spaceWeatherService,
  PharmacyInventoryRepository? pharmacyRepository,
  AstropharmacyEngine astropharmacyEngine = const AstropharmacyEngine(),
}) {
  final weather = spaceWeatherService ?? DonkiSpaceWeatherService();
  final repo = pharmacyRepository ?? AssetPharmacyInventoryRepository();

  final spaceWeatherSkill = AgentSkill(
    id: 'space_weather',
    instructions:
        'Check solar flare and SEP telemetry via get_space_weather, evaluate batch degradation with assess_pharmacy_radiation, and always request crew confirmation before flagging batches, ordering Raman verification, or scheduling post-storm leukocyte counts. Keep responses concise and natural.',
    tools: [
      GetSpaceWeatherTool(weather),
      AssessPharmacyRadiationTool(
        repository: repo,
        spaceWeatherService: weather,
        engine: astropharmacyEngine,
      ),
      FlagBatchesTool(repo),
      const RequestRamanCheckTool(),
      const ScheduleLeukocyteCountTool(),
    ],
    componentIds: const [
      ComponentIds.spaceWeatherAlert,
      ComponentIds.pharmacyBatches,
      ComponentIds.ramanRequest,
    ],
    triggers: const [
      'radiation',
      'solar',
      'storm',
      'flare',
      'sep',
      'donki',
      'raman',
      'leukocyte',
      'shield',
      'batch',
      'radiación',
      'tormenta',
      'lote',
      'leucocitos',
    ],
    offlineFlow: SpaceWeatherOfflineFlow(
      spaceWeatherService: weather,
      repository: repo,
      engine: astropharmacyEngine,
    ),
  );

  const medicationSkill = AgentSkill(
    id: 'medication',
    instructions:
        'Always validate every medication, dose, and route through check_medication before recommending it. Never bypass allergy, dose-limit, stock, or radiation-flag blocks, and offer the suggested alternative route when oral administration is blocked.',
    tools: [CheckMedicationTool()],
    componentIds: [ComponentIds.medicationCheck],
    triggers: [
      'medication',
      'drug',
      'dose',
      'allergy',
      'paracetamol',
      'promethazine',
      'modafinil',
      'zolpidem',
      'ibuprofen',
      'ondansetron',
      'potassium_citrate',
      'pharmacy',
      'medicamento',
      'medicina',
      'dosis',
      'alergia',
    ],
  );

  return [spaceWeatherSkill, medicationSkill];
}
