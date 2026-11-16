import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:astramed/features/agent/domain/guided_assessment_catalog.dart';
import 'package:astramed/features/agent/providers/agent_providers.dart';
import 'package:astramed/features/apolo/presentation/apolo_theme.dart';
import 'package:astramed/features/crew/presentation/providers/crew_provider.dart';
import 'cockpit_widgets/apolo_cockpit_overrides.dart';

class MicrogravityView extends ConsumerWidget {
  const MicrogravityView({super.key});

  void _launch(BuildContext context, WidgetRef ref, String id) {
    final descriptor = GuidedAssessmentCatalog.byId(id)!;
    final controller = ref.read(agentOrchestratorProvider.notifier);
    final astronautId = ref.read(selectedAstronautProvider).id;
    controller.switchAstronaut(astronautId);
    final vm = ref.read(componentRegistryProvider).resolve(descriptor.componentId,
      {...descriptor.defaultProps, 'astronaut_id': astronautId});
    final builder = buildApoloCockpitComponentOverrides()[descriptor.componentId]!;
    showModalBottomSheet<void>(
      context: context, isScrollControlled: true, isDismissible: false,
      enableDrag: false, backgroundColor: ApoloPalette.standard.bg,
      builder: (sheetContext) => SafeArea(child: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: builder(sheetContext, vm, (result) async {
          final session = await controller.submitInteractiveResult(descriptor.componentId, result);
          if (!sheetContext.mounted) return;
          if (session.lastError != null) {
            ScaffoldMessenger.of(sheetContext).showSnackBar(
              SnackBar(content: Text('Could not record assessment: ${session.lastError}')));
            return;
          }
          if (result['completed'] == true || result['emergency_release'] == true) {
            Navigator.pop(sheetContext);
          }
        }, () => Navigator.pop(sheetContext)),
      )),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final astronaut = ref.watch(selectedAstronautProvider);
    final exercise = astronaut.exercise;

    final progress = (exercise.durationMinutes / 150.0).clamp(0.0, 1.0);

    const p = ApoloPalette.standard;
    return Theme(data: buildApoloTheme(), child: ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        const Text('Microgravity Health', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        Text('${astronaut.name} • ${astronaut.callsign}', style: TextStyle(color: p.text2)),
        const SizedBox(height: 16),

        Card(
          color: p.bg2,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Exercise Countermeasures • NASA HRP',
                  style: TextStyle(fontWeight: FontWeight.bold)),
                if (exercise.targetReached) const Text('✓ Target reached'),
                const SizedBox(height: 12),
                Text('Primary device: ${exercise.deviceName}', style: TextStyle(color: p.text2)),
                const SizedBox(height: 6),
                LinearProgressIndicator(
                  value: progress,
                  backgroundColor: p.surface,
                  color: exercise.targetReached ? p.ok : p.warn,
                  minHeight: 10,
                  borderRadius: BorderRadius.circular(5),
                ),
                const SizedBox(height: 8),
                Text('${exercise.durationMinutes} / 150 min target • ${exercise.caloriesBurned.toInt()} kcal'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        for (final suite in {
          'SMS Suite': ['zero_g_horizon', 'dva_gaze', 'graybiel'],
          'SANS Suite': ['starfield_distortion', 'near_point_diopter', 'lbnp'],
        }.entries) ...[
          Padding(padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(suite.key, style: TextStyle(color: p.lav2, fontSize: 18))),
          for (final id in suite.value) Card(color: p.surface, child: ListTile(
            leading: Icon(Icons.explore_outlined, color: p.lav),
            title: Text(GuidedAssessmentCatalog.byId(id)!.title),
            subtitle: Text(GuidedAssessmentCatalog.byId(id)!.summary),
            trailing: const Icon(Icons.arrow_forward),
            onTap: () => _launch(context, ref, id),
          )),
        ],
      ],
    ));
  }
}
