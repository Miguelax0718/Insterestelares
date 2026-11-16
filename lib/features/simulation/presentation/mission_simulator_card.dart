import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../apolo/presentation/apolo_theme.dart';
import '../../crew/presentation/providers/crew_provider.dart';
import 'providers/mission_simulator_provider.dart';

/// Embeddable in both the agent sheet and the sidebar modal sheet.
class MissionSimulatorCard extends ConsumerWidget {
  const MissionSimulatorCard({super.key, this.onDismiss});

  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(missionSimulatorProvider);
    final actions = ref.read(missionSimulatorProvider.notifier);
    final crew = ref.watch(crewMembersProvider);
    final selected = ref.watch(selectedAstronautIdProvider);
    const p = ApoloPalette.standard;
    return Theme(
      data: buildApoloTheme(),
      child: Material(
        color: p.surface,
        borderRadius: BorderRadius.circular(20),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Mission Simulator · Day ${state.missionDay}',
                      style: TextStyle(
                        color: p.text,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (onDismiss != null)
                    IconButton(
                      tooltip: 'Close',
                      onPressed: onDismiss,
                      icon: Icon(Icons.close, color: p.text2),
                    ),
                ],
              ),
              const Text('Synthetic scenarios · not a medical forecast'),
              const SizedBox(height: 12),
              Wrap(spacing: 6, children: [
                for (final type in MissionType.values)
                  ChoiceChip(label: Text(type.name),
                    selected: state.missionType == type,
                    onSelected: (_) => actions.setMissionType(type)),
              ]),
              Wrap(spacing: 8, children: [
                FilledButton(onPressed: () => actions.advanceDays(), child: const Text('+1d')),
                FilledButton(onPressed: () => actions.advanceDays(5), child: const Text('+5d')),
                FilledButton(onPressed: actions.toggleRunning, child: Text(state.isRunning ? 'Pause' : 'Play')),
                OutlinedButton(onPressed: actions.resetNominal, child: const Text('Reset Nominal')),
              ]),
              DropdownButton<String>(
                isExpanded: true,
                value: crew.any((a) => a.id == selected) ? selected : crew.first.id,
                items: [for (final a in crew) DropdownMenuItem(value: a.id, child: Text(a.name, overflow: TextOverflow.ellipsis))],
                onChanged: (id) {
                  if (id != null) ref.read(selectedAstronautIdProvider.notifier).state = id;
                },
              ),
              SwitchListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: const Text('Whole crew'),
                subtitle: const Text('Solar particle events always reach everyone'),
                value: state.wholeCrew,
                onChanged: actions.setWholeCrew,
              ),
              Wrap(spacing: 6, children: [
                for (final event in SimulationEvent.values)
                  OutlinedButton(onPressed: () => actions.triggerEvent(event), child: Text(switch (event) {
                    SimulationEvent.sleepLoss => 'Sleep loss',
                    SimulationEvent.solarParticleEvent => 'Solar particle event',
                    SimulationEvent.exerciseFailure => 'Exercise failure',
                    SimulationEvent.workload => 'Workload',
                  })),
              ]),
              Wrap(spacing: 6, children: [
                Chip(label: Text('Nominal ${ref.watch(nominalCrewCountProvider)}'), avatar: Icon(Icons.check_circle, color: p.ok)),
                Chip(label: Text('Warning ${ref.watch(warningCrewCountProvider)}'), avatar: Icon(Icons.warning, color: p.warn)),
                Chip(label: Text('Critical ${ref.watch(criticalCrewCountProvider)}'), avatar: Icon(Icons.error, color: p.crit)),
              ]),
              if (state.episodes.any((e) => !e.isExposure)) ...[
                const Text('Active conditions'),
                Wrap(spacing: 6, runSpacing: 4, children: [
                  for (final e in state.episodes.where((e) => !e.isExposure))
                    Chip(
                      label: Text('${e.astronautId} · ${e.kind.label} · '
                          '${e.severityLabelOn(state.missionDay)}'),
                    ),
                ]),
              ],
              const Text('Simulation log'),
              for (final entry in state.log.take(12)) Text(entry),
            ],
          ),
        ),
      ),
    );
  }
}
