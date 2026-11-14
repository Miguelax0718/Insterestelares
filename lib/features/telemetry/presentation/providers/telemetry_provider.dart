import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:astramed/features/crew/models/astronaut_profile.dart';
import 'package:astramed/features/crew/presentation/providers/crew_provider.dart';
import 'package:astramed/features/telemetry/data/space_machines_catalog.dart';
import 'package:astramed/features/telemetry/models/telemetry_machine.dart';

/// Estado inmutable del motor de telemetría y sensores médicos
class TelemetryState {
  final List<TelemetryMachine> machines;
  final bool isLiveStreaming;
  final bool isScanning;
  final DateTime? lastSyncAt;
  final List<TelemetryPacket> recentLogs;
  final int tickCount;

  const TelemetryState({
    required this.machines,
    this.isLiveStreaming = false,
    this.isScanning = false,
    this.lastSyncAt,
    this.recentLogs = const [],
    this.tickCount = 0,
  });

  TelemetryState copyWith({
    List<TelemetryMachine>? machines,
    bool? isLiveStreaming,
    bool? isScanning,
    DateTime? lastSyncAt,
    List<TelemetryPacket>? recentLogs,
    int? tickCount,
  }) {
    return TelemetryState(
      machines: machines ?? this.machines,
      isLiveStreaming: isLiveStreaming ?? this.isLiveStreaming,
      isScanning: isScanning ?? this.isScanning,
      lastSyncAt: lastSyncAt ?? this.lastSyncAt,
      recentLogs: recentLogs ?? this.recentLogs,
      tickCount: tickCount ?? this.tickCount,
    );
  }
}

/// Notifier que gestiona las conexiones con los equipos médicos espaciales
/// y la inyección de telemetría en tiempo real hacia los tripulantes
class TelemetryNotifier extends StateNotifier<TelemetryState> {
  final Ref _ref;
  Timer? _liveTimer;

  TelemetryNotifier(this._ref)
      : super(
          TelemetryState(
            machines: SpaceMachinesCatalog.getInitialMachines(
              _ref.read(crewMembersProvider),
            ),
          ),
        );

  /// Conecta o desconecta una máquina médica para un astronauta específico
  void toggleMachineForAstronaut(String astronautId, String machineId) {
    final updatedMachines = <TelemetryMachine>[];

    for (final machine in state.machines) {
      if (machine.id == machineId) {
        final isCurrentlyConnected = machine.isConnectedFor(astronautId);
        final newStatus = isCurrentlyConnected
            ? MachineConnectionStatus.disconnected
            : MachineConnectionStatus.streaming;

        final newStatusMap = Map<String, MachineConnectionStatus>.from(machine.statusByAstronaut);
        newStatusMap[astronautId] = newStatus;

        final newPacketMap = Map<String, TelemetryPacket>.from(machine.lastPacketByAstronaut);

        if (!isCurrentlyConnected) {
          // Si se conecta, enlazar en CrewNotifier y generar un paquete inicial
          _ref.read(crewMembersProvider.notifier).linkMachine(astronautId, machineId);

          final crew = _ref.read(crewMembersProvider);
          final astronaut = crew.firstWhere(
            (a) => a.id == astronautId,
            orElse: () => crew.first,
          );

          final packet = SpaceMachinesCatalog.generateTelemetryPacket(
            machine,
            astronaut,
            tick: state.tickCount,
          );

          newPacketMap[astronautId] = packet;
          _ref.read(crewMembersProvider.notifier).applyTelemetryPacket(astronautId, packet);

          final updatedLogs = [packet, ...state.recentLogs];
          if (updatedLogs.length > 50) {
            updatedLogs.removeLast();
          }

          state = state.copyWith(
            recentLogs: updatedLogs,
            lastSyncAt: packet.timestamp,
            tickCount: state.tickCount + 1,
          );
        } else {
          // Si se desconecta, desvincular en CrewNotifier
          _ref.read(crewMembersProvider.notifier).unlinkMachine(astronautId, machineId);
        }

        updatedMachines.add(
          machine.copyWith(
            statusByAstronaut: newStatusMap,
            lastPacketByAstronaut: newPacketMap,
          ),
        );
      } else {
        updatedMachines.add(machine);
      }
    }

    state = state.copyWith(machines: updatedMachines);
  }

  /// Realiza una captura inmediata de telemetría de una máquina para el astronauta indicado
  TelemetryPacket? pullSingleMachine(String astronautId, String machineId) {
    final machineIndex = state.machines.indexWhere((m) => m.id == machineId);
    if (machineIndex == -1) return null;

    final machine = state.machines[machineIndex];
    final crew = _ref.read(crewMembersProvider);
    final astronaut = crew.firstWhere(
      (a) => a.id == astronautId,
      orElse: () => crew.first,
    );

    final packet = SpaceMachinesCatalog.generateTelemetryPacket(
      machine,
      astronaut,
      tick: state.tickCount,
    );

    // Actualiza el último paquete para este astronauta
    final newPacketMap = Map<String, TelemetryPacket>.from(machine.lastPacketByAstronaut);
    newPacketMap[astronautId] = packet;

    final updatedMachine = machine.copyWith(
      lastPacketByAstronaut: newPacketMap,
    );

    final updatedMachines = List<TelemetryMachine>.from(state.machines);
    updatedMachines[machineIndex] = updatedMachine;

    // Actualiza bitácora de telemetría reciente
    final updatedLogs = [packet, ...state.recentLogs];
    if (updatedLogs.length > 50) {
      updatedLogs.removeLast();
    }

    state = state.copyWith(
      machines: updatedMachines,
      recentLogs: updatedLogs,
      lastSyncAt: packet.timestamp,
      tickCount: state.tickCount + 1,
    );

    // Propaga el paquete al estado del tripulante en CrewNotifier
    _ref.read(crewMembersProvider.notifier).applyTelemetryPacket(astronautId, packet);

    return packet;
  }

  /// Lee todas las máquinas conectadas del tripulante seleccionado y actualiza sus datos en bloque
  /// Retorna el número de máquinas que transmitieron
  int pullAllConnectedMachines(String astronautId) {
    final crew = _ref.read(crewMembersProvider);
    final astronaut = crew.firstWhere(
      (a) => a.id == astronautId,
      orElse: () => crew.first,
    );

    final connected = state.machines
        .where((m) => m.isConnectedFor(astronautId))
        .toList();

    if (connected.isEmpty) return 0;

    final newPackets = <TelemetryPacket>[];
    final updatedMachines = <TelemetryMachine>[];

    for (final machine in state.machines) {
      if (machine.isConnectedFor(astronautId)) {
        final packet = SpaceMachinesCatalog.generateTelemetryPacket(
          machine,
          astronaut,
          tick: state.tickCount,
        );
        newPackets.add(packet);

        final newPacketMap = Map<String, TelemetryPacket>.from(machine.lastPacketByAstronaut);
        newPacketMap[astronautId] = packet;

        updatedMachines.add(
          machine.copyWith(lastPacketByAstronaut: newPacketMap),
        );

        // Notificar a CrewNotifier
        _ref.read(crewMembersProvider.notifier).applyTelemetryPacket(astronautId, packet);
      } else {
        updatedMachines.add(machine);
      }
    }

    final updatedLogs = [...newPackets, ...state.recentLogs];
    if (updatedLogs.length > 50) {
      updatedLogs.removeRange(50, updatedLogs.length);
    }

    state = state.copyWith(
      machines: updatedMachines,
      recentLogs: updatedLogs,
      lastSyncAt: DateTime.now(),
      tickCount: state.tickCount + 1,
    );

    return connected.length;
  }

  /// Simula un escaneo rápido del bus de comunicaciones de la cabina (600 ms)
  Future<void> scanCabinBus(String astronautId) async {
    state = state.copyWith(isScanning: true);
    await Future.delayed(const Duration(milliseconds: 600));
    state = state.copyWith(isScanning: false);
  }

  /// Activa o desactiva la transmisión en vivo periódica cada 3 segundos
  void toggleLiveStreaming(String activeAstronautId) {
    if (state.isLiveStreaming) {
      _liveTimer?.cancel();
      _liveTimer = null;
      state = state.copyWith(isLiveStreaming: false);
    } else {
      state = state.copyWith(isLiveStreaming: true);
      _liveTimer?.cancel();
      _liveTimer = Timer.periodic(const Duration(seconds: 3), (_) {
        final currentSelectedId = _ref.read(selectedAstronautIdProvider);
        pullAllConnectedMachines(currentSelectedId);
      });
    }
  }

  /// Sincroniza el estado de las máquinas con la lista de tripulantes actual
  void syncWithCrewData(List<AstronautProfile> crew) {
    final updatedMachines = <TelemetryMachine>[];

    for (final machine in state.machines) {
      final statusMap = Map<String, MachineConnectionStatus>.from(machine.statusByAstronaut);

      for (final astronaut in crew) {
        final isLinked = astronaut.linkedMachineIds.contains(machine.id);
        if (isLinked && statusMap[astronaut.id] == null) {
          statusMap[astronaut.id] = MachineConnectionStatus.streaming;
        } else if (!isLinked) {
          statusMap[astronaut.id] = MachineConnectionStatus.disconnected;
        }
      }

      updatedMachines.add(machine.copyWith(statusByAstronaut: statusMap));
    }

    state = state.copyWith(machines: updatedMachines);
  }

  /// Restablece las máquinas a su estado inicial
  void resetToInitial() {
    _liveTimer?.cancel();
    _liveTimer = null;

    final initialCrew = _ref.read(crewMembersProvider);
    state = TelemetryState(
      machines: SpaceMachinesCatalog.getInitialMachines(initialCrew),
      isLiveStreaming: false,
      isScanning: false,
      recentLogs: const [],
      tickCount: 0,
    );
  }

  @override
  void dispose() {
    _liveTimer?.cancel();
    _liveTimer = null;
    super.dispose();
  }
}

/// Provider global del motor de telemetría
final telemetryProvider =
    StateNotifierProvider<TelemetryNotifier, TelemetryState>((ref) {
  return TelemetryNotifier(ref);
});

/// Provider que entrega las máquinas conectadas para el astronauta actualmente seleccionado
final connectedMachinesForSelectedProvider =
    Provider<List<TelemetryMachine>>((ref) {
  final telemetryState = ref.watch(telemetryProvider);
  final selectedId = ref.watch(selectedAstronautIdProvider);

  return telemetryState.machines
      .where((machine) => machine.isConnectedFor(selectedId))
      .toList();
});

/// Provider de conveniencia para consultar la lista completa de máquinas
final allMachinesProvider = Provider<List<TelemetryMachine>>((ref) {
  return ref.watch(telemetryProvider).machines;
});

/// Provider de conveniencia para consultar el estado del streaming en vivo
final isTelemetryStreamingProvider = Provider<bool>((ref) {
  return ref.watch(telemetryProvider).isLiveStreaming;
});
