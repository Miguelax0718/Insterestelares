import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:astramed/features/01_general_health/models/vitals_record.dart';
import 'package:astramed/features/crew/data/mock_crew_data.dart';
import 'package:astramed/features/crew/models/astronaut_profile.dart';

/// Notifier que administra el estado de los 5 astronautas de la tripulación
class CrewNotifier extends StateNotifier<List<AstronautProfile>> {
  CrewNotifier() : super(MockCrewData.getInitialCrew());

  /// Actualiza los signos vitales de un astronauta en particular
  void updateVitals(String astronautId, VitalsRecord newVitals) {
    state = [
      for (final profile in state)
        if (profile.id == astronautId)
          profile.copyWith(vitals: newVitals)
        else
          profile,
    ];
  }

  /// Actualiza el estado de riesgo y alertas de un astronauta
  void updateRiskStatus({
    required String astronautId,
    required CrewRiskLevel riskLevel,
    required String riskTitle,
    required String riskDescription,
    required List<String> activeAlerts,
  }) {
    state = [
      for (final profile in state)
        if (profile.id == astronautId)
          profile.copyWith(
            riskLevel: riskLevel,
            riskTitle: riskTitle,
            riskDescription: riskDescription,
            activeAlerts: activeAlerts,
          )
        else
          profile,
    ];
  }

  /// Restablece la tripulación a su estado inicial simulado
  void resetToInitial() {
    state = MockCrewData.getInitialCrew();
  }
}

/// Provider de la lista de perfiles de la tripulación
final crewMembersProvider =
    StateNotifierProvider<CrewNotifier, List<AstronautProfile>>((ref) {
  return CrewNotifier();
});

/// Provider que almacena el ID del astronauta actualmente activo/seleccionado
final selectedAstronautIdProvider = StateProvider<String>((ref) {
  return 'AST-01'; // Por defecto inicia con el Comandante Alex Vance
});

/// Provider derivado que expone el objeto completo del astronauta seleccionado
final selectedAstronautProvider = Provider<AstronautProfile>((ref) {
  final crew = ref.watch(crewMembersProvider);
  final selectedId = ref.watch(selectedAstronautIdProvider);

  return crew.firstWhere(
    (profile) => profile.id == selectedId,
    orElse: () => crew.first,
  );
});

/// Contador de astronautas en estado CRÍTICO
final criticalCrewCountProvider = Provider<int>((ref) {
  final crew = ref.watch(crewMembersProvider);
  return crew.where((a) => a.riskLevel == CrewRiskLevel.critical).length;
});

/// Contador de astronautas en estado de PRECAUCIÓN
final warningCrewCountProvider = Provider<int>((ref) {
  final crew = ref.watch(crewMembersProvider);
  return crew.where((a) => a.riskLevel == CrewRiskLevel.warning).length;
});

/// Contador de astronautas en estado NOMINAL
final nominalCrewCountProvider = Provider<int>((ref) {
  final crew = ref.watch(crewMembersProvider);
  return crew.where((a) => a.riskLevel == CrewRiskLevel.nominal).length;
});
