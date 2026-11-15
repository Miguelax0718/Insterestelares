import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../crew/presentation/providers/crew_provider.dart';
import '../agent/apolo_urine_skill.dart';
import '../data/apolo_repository.dart';
import '../domain/apolo_models.dart';
import 'apolo_contract_providers.dart';

final apoloRepositoryProvider = Provider<ApoloRepository>((ref) {
  return ApoloRepository();
});

final apoloStateNotifierProvider =
    StateNotifierProvider<ApoloStateNotifier, Map<String, ApoloAstronautState>>(
      (ref) {
        final repo = ref.watch(apoloRepositoryProvider);
        final initialId = ref.read(selectedAstronautIdProvider);
        final notifier = ApoloStateNotifier(
          repository: repo,
          initialAstronautId: initialId,
        );
        ref.listen<String>(selectedAstronautIdProvider, (_, nextId) {
          notifier.setActiveAstronautId(nextId);
        });
        return notifier;
      },
    );

final apoloUrineSkillProvider = Provider<ApoloUrineSkill>((ref) {
  return ApoloUrineSkill();
});

final List<Override> apoloProviderOverrides = [
  apoloActiveStateProvider.overrideWith((ref) {
    final selectedId = ref.watch(selectedAstronautIdProvider);
    final states = ref.watch(apoloStateNotifierProvider);
    final resolvedId = ApoloRepository.resolveAstronautId(selectedId);
    return states[resolvedId] ??
        ref.read(apoloStateNotifierProvider.notifier).stateFor(selectedId);
  }),
  apoloActionsProvider.overrideWith(
    (ref) => ref.watch(apoloStateNotifierProvider.notifier),
  ),
];
