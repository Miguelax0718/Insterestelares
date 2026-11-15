import 'package:astramed/features/crew/models/astronaut_profile.dart';
import 'package:astramed/features/crew/presentation/providers/crew_provider.dart';
import 'package:astramed/features/telemetry/presentation/providers/telemetry_provider.dart';

import '../domain/agent_contracts.dart';

int _memoryIdSequence = 0;

String _nextMemoryId(DateTime now) {
  _memoryIdSequence += 1;
  return 'mem_${now.microsecondsSinceEpoch}_$_memoryIdSequence';
}

AgentSkill coreSkill() {
  return AgentSkill(
    id: 'core',
    alwaysOn: true,
    instructions: 'Use core tools to inspect live crew, vitals, and telemetry data, recall or save persistent astronaut memory, and show or hide UI components. Keep responses natural, concise, and direct.',
    tools: [
      _GetCrewOverviewTool(),
      _GetVitalsTool(),
      _GetTelemetrySeriesTool(),
      _RecallMemoryTool(),
      _SaveMemoryTool(),
      _ShowComponentTool(),
      _HideComponentTool(),
    ],
    componentIds: const [
      ComponentIds.crewStatus,
      ComponentIds.vitalsCard,
      ComponentIds.telemetryChart,
    ],
  );
}

class _GetCrewOverviewTool extends AgentTool {
  @override
  String get name => 'get_crew_overview';

  @override
  String get description =>
      'Read live overview of all crew members including vitals, sleep hours, risk level, and alert counts.';

  @override
  Map<String, dynamic> get parameters => const {
    'type': 'object',
    'properties': <String, dynamic>{},
  };

  @override
  Future<ToolResult> call(Map<String, dynamic> args, ToolContext ctx) async {
    final crew = ctx.read<List<AstronautProfile>>(crewMembersProvider);
    final summaries = crew
        .map(
          (a) => <String, dynamic>{
            'id': a.id,
            'name': a.name,
            'role': a.role,
            'risk_level': a.riskLevel.name,
            'heart_rate': a.vitals.heartRate,
            'spo2': a.vitals.spO2,
            'sleep_hours': a.sleep.sleepHours,
            'alert_count': a.activeAlerts.length,
          },
        )
        .toList(growable: false);

    final event = ShowComponentEvent(ComponentIds.crewStatus, {
      'title': 'Crew Status',
      'crew': summaries,
      'count': summaries.length,
    });
    ctx.ui.emit(event);

    return ToolResult.ok(
      {'crew': summaries, 'count': summaries.length},
      uiEvents: [event],
    );
  }
}

class _GetVitalsTool extends AgentTool {
  @override
  String get name => 'get_vitals';

  @override
  String get description =>
      'Read live vital signs and active clinical alerts for an astronaut (defaults to active astronaut).';

  @override
  Map<String, dynamic> get parameters => const {
    'type': 'object',
    'properties': {
      'astronaut_id': {
        'type': 'string',
        'description': 'Optional astronaut ID. Defaults to active astronaut.',
      },
    },
  };

  @override
  Future<ToolResult> call(Map<String, dynamic> args, ToolContext ctx) async {
    final requestedId = (args['astronaut_id'] as String?)?.trim();
    final targetId = (requestedId != null && requestedId.isNotEmpty)
        ? requestedId
        : ctx.astronautId;

    final crew = ctx.read<List<AstronautProfile>>(crewMembersProvider);
    AstronautProfile? match;
    for (final member in crew) {
      if (member.id == targetId) {
        match = member;
        break;
      }
    }
    if (match == null) {
      return ToolResult.fail('Astronaut not found: $targetId');
    }

    final v = match.vitals;
    final vitalsMap = <String, dynamic>{
      'timestamp': v.timestamp.toUtc().toIso8601String(),
      'heart_rate': v.heartRate,
      'systolic_bp': v.systolicBP,
      'diastolic_bp': v.diastolicBP,
      'spo2': v.spO2,
      'body_temp': v.bodyTemp,
      'blood_glucose': v.bloodGlucose,
      'respiratory_rate': v.respiratoryRate,
      'capillary_refill_seconds': v.capillaryRefillSeconds,
      'source': v.source,
      'signal_quality': v.signalQuality,
    };

    final payload = <String, dynamic>{
      'astronaut_id': match.id,
      'name': match.name,
      'risk_level': match.riskLevel.name,
      'risk_title': match.riskTitle,
      'vitals': vitalsMap,
      'active_alerts': match.activeAlerts,
    };

    final event = ShowComponentEvent(ComponentIds.vitalsCard, {
      'title': '${match.name} Vitals',
      ...payload,
    });
    ctx.ui.emit(event);

    return ToolResult.ok(payload, uiEvents: [event]);
  }
}

class _GetTelemetrySeriesTool extends AgentTool {
  @override
  String get name => 'get_telemetry_series';

  @override
  String get description =>
      'Read connected telemetry machines, recent telemetry packet logs, and latest metric snapshot.';

  @override
  Map<String, dynamic> get parameters => const {
    'type': 'object',
    'properties': {
      'astronaut_id': {
        'type': 'string',
        'description': 'Optional astronaut ID. Defaults to active astronaut.',
      },
      'limit': {
        'type': 'integer',
        'description': 'Maximum number of recent log packets (1-25).',
      },
    },
  };

  @override
  Future<ToolResult> call(Map<String, dynamic> args, ToolContext ctx) async {
    final requestedId = (args['astronaut_id'] as String?)?.trim();
    final targetId = (requestedId != null && requestedId.isNotEmpty)
        ? requestedId
        : ctx.astronautId;
    final limit = (args['limit'] as num?)?.toInt().clamp(1, 25) ?? 10;

    final telemetry = ctx.read<TelemetryState>(telemetryProvider);
    final connectedMachines = telemetry.machines
        .where((m) => m.isConnectedFor(targetId))
        .map(
          (m) => <String, dynamic>{
            'id': m.id,
            'name': m.name,
            'code': m.code,
            'category': m.category.name,
            'battery_percent': m.batteryPercent,
            'signal_percent': m.signalPercent,
            if (m.lastPacketFor(targetId) != null)
              'last_metrics': m.lastPacketFor(targetId)!.metrics,
          },
        )
        .toList(growable: false);

    final recentLogs = telemetry.recentLogs
        .where((packet) => packet.astronautId == targetId)
        .take(limit)
        .map(
          (packet) => <String, dynamic>{
            'timestamp': packet.timestamp.toUtc().toIso8601String(),
            'machine_id': packet.machineId,
            'device': packet.device,
            'signal_quality': packet.signalQuality,
            'metrics': packet.metrics,
          },
        )
        .toList(growable: false);

    final snapshot = <String, dynamic>{};
    for (final machine in telemetry.machines) {
      if (!machine.isConnectedFor(targetId)) {
        continue;
      }
      final packet = machine.lastPacketFor(targetId);
      if (packet != null) {
        snapshot.addAll(packet.metrics);
      }
    }
    for (final log in recentLogs.reversed) {
      final metrics = log['metrics'];
      if (metrics is Map<String, dynamic>) {
        snapshot.addAll(metrics);
      }
    }

    final payload = <String, dynamic>{
      'astronaut_id': targetId,
      'is_live_streaming': telemetry.isLiveStreaming,
      if (telemetry.lastSyncAt != null)
        'last_sync_at': telemetry.lastSyncAt!.toUtc().toIso8601String(),
      'machines': connectedMachines,
      'recent_logs': recentLogs,
      'metrics': snapshot,
    };

    final event = ShowComponentEvent(ComponentIds.telemetryChart, {
      'title': 'Telemetry ($targetId)',
      ...payload,
    });
    ctx.ui.emit(event);

    return ToolResult.ok(payload, uiEvents: [event]);
  }
}

class _RecallMemoryTool extends AgentTool {
  @override
  String get name => 'recall_memory';

  @override
  String get description =>
      'Search persistent clinical and session memory for the active astronaut.';

  @override
  Map<String, dynamic> get parameters => const {
    'type': 'object',
    'properties': {
      'query': {
        'type': 'string',
        'description': 'Optional search query to filter memories.',
      },
      'limit': {
        'type': 'integer',
        'description': 'Maximum entries to return (1-20).',
      },
    },
  };

  @override
  Future<ToolResult> call(Map<String, dynamic> args, ToolContext ctx) async {
    final query = args['query'] as String?;
    final limit = (args['limit'] as num?)?.toInt().clamp(1, 20) ?? 10;
    final entries = await ctx.memory.recall(
      ctx.astronautId,
      query: query,
      limit: limit,
    );
    return ToolResult.ok({
      'entries': entries.map((e) => e.toJson()).toList(growable: false),
      'count': entries.length,
    });
  }
}

class _SaveMemoryTool extends AgentTool {
  @override
  String get name => 'save_memory';

  @override
  String get description =>
      'Persist a concise clinical fact, event, or summary for the active astronaut.';

  @override
  Map<String, dynamic> get parameters => const {
    'type': 'object',
    'properties': {
      'summary': {
        'type': 'string',
        'description': 'Concise summary to store in persistent memory.',
      },
      'kind': {
        'type': 'string',
        'enum': ['fact', 'session_summary', 'clinical_event'],
      },
      'tags': {
        'type': 'array',
        'items': {'type': 'string'},
      },
      'data': {'type': 'object'},
    },
    'required': ['summary'],
  };

  @override
  Future<ToolResult> call(Map<String, dynamic> args, ToolContext ctx) async {
    final rawSummary = args['summary'];
    if (rawSummary is! String || rawSummary.trim().isEmpty) {
      return const ToolResult.fail('summary is required');
    }
    final kindRaw = args['kind'] as String? ?? 'fact';
    final tags = (args['tags'] as List<dynamic>? ?? const [])
        .map((e) => e.toString())
        .toList(growable: false);
    final rawData = args['data'];
    final data = rawData is Map
        ? Map<String, dynamic>.from(rawData)
        : const <String, dynamic>{};

    final entry = MemoryEntry(
      id: _nextMemoryId(ctx.now),
      astronautId: ctx.astronautId,
      kind: MemoryKind.fromWire(kindRaw),
      summary: rawSummary.trim(),
      createdAt: ctx.now,
      tags: tags,
      data: data,
    );
    final saved = await ctx.memory.save(entry);
    return ToolResult.ok({'saved': true, 'entry': saved.toJson()});
  }
}

class _ShowComponentTool extends AgentTool {
  @override
  ToolEffect get effect => ToolEffect.ui;

  @override
  String get name => 'show_component';

  @override
  String get description => 'Display a registered visual component in the UI.';

  @override
  Map<String, dynamic> get parameters => const {
    'type': 'object',
    'properties': {
      'id': {
        'type': 'string',
        'description': 'Registered component identifier.',
      },
      'props': {
        'type': 'object',
        'description': 'Component properties payload.',
      },
    },
    'required': ['id'],
  };

  @override
  Future<ToolResult> call(Map<String, dynamic> args, ToolContext ctx) async {
    final id = args['id'];
    if (id is! String || !ComponentIds.all.contains(id)) {
      return ToolResult.fail('Unknown component id: $id');
    }
    final rawProps = args['props'];
    final props = rawProps is Map
        ? Map<String, dynamic>.from(rawProps)
        : const <String, dynamic>{};
    final event = ShowComponentEvent(id, props);
    ctx.ui.emit(event);
    return ToolResult.ok({'shown': id}, uiEvents: [event]);
  }
}

class _HideComponentTool extends AgentTool {
  @override
  ToolEffect get effect => ToolEffect.ui;

  @override
  String get name => 'hide_component';

  @override
  String get description => 'Hide an active visual component from the UI.';

  @override
  Map<String, dynamic> get parameters => const {
    'type': 'object',
    'properties': {
      'id': {'type': 'string', 'description': 'Component identifier to hide.'},
    },
    'required': ['id'],
  };

  @override
  Future<ToolResult> call(Map<String, dynamic> args, ToolContext ctx) async {
    final id = args['id'];
    if (id is! String || id.trim().isEmpty) {
      return const ToolResult.fail('Component id is required');
    }
    final trimmed = id.trim();
    final event = HideComponentEvent(trimmed);
    ctx.ui.emit(event);
    return ToolResult.ok({'hidden': trimmed}, uiEvents: [event]);
  }
}
