import '../../agent/domain/agent_contracts.dart';
import '../../crew/presentation/providers/crew_provider.dart';
import '../../crew/models/astronaut_profile.dart';
import '../presentation/providers/mission_simulator_provider.dart';

class MissionSimulatorSkill extends AgentSkill {
  MissionSimulatorSkill() : super(
    id: 'mission_simulator',
    alwaysOn: true,
    instructions: 'Open the mission_simulator cockpit card for synthetic mission scenarios. '
      'Use control_mission_simulation to start, pause, advance 1–365 days, reset_nominal, '
      'or set_mission_type (orbital/lunar/transit/surface). '
      'Use trigger_simulation_event for sleep_loss, solar_particle_event, exercise_failure, '
      'or workload, optionally targeting an astronaut_id. Never represent simulation as real telemetry.',
    tools: const [MissionSimulatorStatusTool(), ControlMissionSimulationTool(), TriggerSimulationEventTool()],
    componentIds: const ['mission_simulator'],
    triggers: const ['simulador', 'simulación', 'simulacion', 'simulation', 'simulator',
      'solar particle', 'partículas solares', 'sleep loss', 'déficit de sueño',
      'exercise failure', 'falla de ejercicio', 'workload', 'sobrecarga'],
    offlineFlow: MissionSimulatorOfflineFlow(),
  );
}

Map<String, dynamic> _status(ToolContext ctx) {
  final s = ctx.read<MissionSimulatorState>(missionSimulatorProvider);
  return {
    'mission_day': s.missionDay,
    'mission_type': s.missionType.name,
    'is_running': s.isRunning,
    'nominal': ctx.read<int>(nominalCrewCountProvider),
    'warning': ctx.read<int>(warningCrewCountProvider),
    'critical': ctx.read<int>(criticalCrewCountProvider),
    'log': s.log.take(8).toList(),
  };
}

ToolResult _show(ToolContext ctx) {
  final data = _status(ctx);
  final event = ShowComponentEvent('mission_simulator', data);
  ctx.ui.emit(event);
  return ToolResult.ok(data, uiEvents: [event]);
}

class MissionSimulatorStatusTool extends AgentTool {
  const MissionSimulatorStatusTool();
  @override
  String get name => 'get_mission_simulator_status';
  @override
  String get description => 'Show synthetic mission day, controls, crew risks, and recent log.';
  @override
  Map<String, dynamic> get parameters => const {'type': 'object', 'properties': {}, 'additionalProperties': false};
  @override
  ToolEffect get effect => ToolEffect.ui;
  @override
  Future<ToolResult> call(Map<String, dynamic> args, ToolContext ctx) async {
    if (args.isNotEmpty) return const ToolResult.fail('No arguments expected.');
    return _show(ctx);
  }
}

class ControlMissionSimulationTool extends AgentTool {
  const ControlMissionSimulationTool();
  @override
  String get name => 'control_mission_simulation';
  @override
  String get description => 'Start/pause simulation, advance 1–365 days, reset nominal, or set mission type.';
  @override
  Map<String, dynamic> get parameters => const {
    'type': 'object', 'additionalProperties': false, 'required': ['action'],
    'properties': {
      'action': {'type': 'string', 'enum': ['start', 'pause', 'advance_day', 'reset_nominal', 'set_mission_type']},
      'days': {'type': 'integer', 'minimum': 1, 'maximum': 365},
      'mission_type': {'type': 'string', 'enum': ['orbital', 'lunar', 'transit', 'surface']},
    },
  };
  @override
  ToolEffect get effect => ToolEffect.ui;
  @override
  Future<ToolResult> call(Map<String, dynamic> args, ToolContext ctx) async {
    const actions = ['start', 'pause', 'advance_day', 'reset_nominal', 'set_mission_type'];
    final action = args['action'];
    if (!actions.contains(action) || args.keys.any((k) => !['action', 'days', 'mission_type'].contains(k))) {
      return const ToolResult.fail('Invalid simulation action or argument.');
    }
    if (args.containsKey('days') && (action != 'advance_day' || args['days'] is! int || (args['days'] as int) < 1 || (args['days'] as int) > 365)) {
      return const ToolResult.fail('days must be an integer from 1 to 365 for advance_day.');
    }
    if (args.containsKey('mission_type') && action != 'set_mission_type') {
      return const ToolResult.fail('mission_type requires set_mission_type.');
    }
    final types = MissionType.values.where((t) => t.name == args['mission_type']);
    if (action == 'set_mission_type' && types.isEmpty) {
      return const ToolResult.fail('mission_type must be orbital, lunar, transit, or surface.');
    }
    final n = ctx.read<MissionSimulatorNotifier>(missionSimulatorProvider.notifier);
    switch (action) {
      case 'start': n.setRunning(true);
      case 'pause': n.setRunning(false);
      case 'advance_day': n.advanceDays(args['days'] as int? ?? 1);
      case 'reset_nominal': n.resetNominal();
      case 'set_mission_type': n.setMissionType(types.single);
    }
    return _show(ctx);
  }
}

const _events = {
  'sleep_loss': SimulationEvent.sleepLoss,
  'solar_particle_event': SimulationEvent.solarParticleEvent,
  'exercise_failure': SimulationEvent.exerciseFailure,
  'workload': SimulationEvent.workload,
};

class TriggerSimulationEventTool extends AgentTool {
  const TriggerSimulationEventTool();
  @override
  String get name => 'trigger_simulation_event';
  @override
  String get description => 'Apply a synthetic event to the selected or specified astronaut.';
  @override
  Map<String, dynamic> get parameters => const {
    'type': 'object', 'required': ['event'], 'additionalProperties': false,
    'properties': {
      'event': {'type': 'string', 'enum': ['sleep_loss', 'solar_particle_event', 'exercise_failure', 'workload']},
      'astronaut_id': {'type': 'string'},
    },
  };
  @override
  ToolEffect get effect => ToolEffect.ui;
  @override
  Future<ToolResult> call(Map<String, dynamic> args, ToolContext ctx) async {
    if (args['event'] is! String || !_events.containsKey(args['event']) ||
        args.keys.any((k) => !['event', 'astronaut_id'].contains(k))) {
      return const ToolResult.fail('Invalid simulation event or argument.');
    }
    final rawId = args['astronaut_id'];
    if (args.containsKey('astronaut_id') && (rawId is! String || rawId.trim().isEmpty)) {
      return const ToolResult.fail('astronaut_id must identify an existing crew member.');
    }
    final id = rawId as String? ?? ctx.read<String>(selectedAstronautIdProvider);
    // Validate before either clinical store is mutated.
    final crewIds = ctx.read<List<AstronautProfile>>(crewMembersProvider).map((p) => p.id);
    if (!crewIds.contains(id)) return const ToolResult.fail('Unknown astronaut_id.');
    ctx.read<MissionSimulatorNotifier>(missionSimulatorProvider.notifier)
      .triggerEvent(_events[args['event']]!, astronautId: id);
    return _show(ctx);
  }
}

class MissionSimulatorOfflineFlow implements QueryAwareDeterministicFlow {
  @override
  String get skillId => 'mission_simulator';
  @override
  Future<DeterministicStep> start(ToolContext ctx) => startWithQuery('', ctx);
  @override
  Future<DeterministicStep> advance(String userInput, ToolContext ctx) => startWithQuery(userInput, ctx);
  @override
  Future<DeterministicStep> startWithQuery(String query, ToolContext ctx) async {
    final q = query.toLowerCase();
    ToolResult result;
    String? event;
    if (q.contains('solar')) event = 'solar_particle_event';
    if (q.contains('sleep loss') || q.contains('déficit de sueño') || q.contains('deficit de sueño')) event = 'sleep_loss';
    if (q.contains('exercise failure') || q.contains('falla de ejercicio')) event = 'exercise_failure';
    if (q.contains('workload') || q.contains('sobrecarga')) event = 'workload';
    if (event != null) {
      result = await const TriggerSimulationEventTool().call({'event': event}, ctx);
    } else {
      final type = MissionType.values.where((t) => q.contains(t.name));
      String? action;
      if (q.contains('reset') || q.contains('reinici') || q.contains('restablec')) {
        action = 'reset_nominal';
      } else if (q.contains('pause') || q.contains('paus')) {
        action = 'pause';
      } else if (q.contains('advance') || q.contains('avanza')) {
        action = 'advance_day';
      } else if (q.contains('start') || q.contains('inicia')) {
        action = 'start';
      } else if (type.isNotEmpty) {
        action = 'set_mission_type';
      }
      final digits = RegExp(r'\b\d+\b').firstMatch(q)?.group(0);
      result = action == null ? await const MissionSimulatorStatusTool().call({}, ctx) :
        await const ControlMissionSimulationTool().call({
          'action': action,
          if (action == 'advance_day') 'days': digits == null ? 1 : int.tryParse(digits),
          if (action == 'set_mission_type') 'mission_type': type.first.name,
        }, ctx);
    }
    return DeterministicStep(
      prompt: result.ok ? 'Mission simulator · Day ${result.data['mission_day']}. Synthetic scenarios only.' : result.error!,
      uiEvents: result.uiEvents,
      isTerminal: true,
      verdict: result.data,
    );
  }
}
