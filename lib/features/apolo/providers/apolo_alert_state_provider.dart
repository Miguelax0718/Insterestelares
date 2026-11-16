import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../agent/domain/agent_contracts.dart';
import '../../agent/providers/agent_providers.dart';
import '../../crew/models/astronaut_profile.dart';
import '../../crew/presentation/providers/crew_provider.dart';
import '../domain/apolo_models.dart';
import '../data/apolo_repository.dart';
import 'apolo_contract_providers.dart';
import 'apolo_providers.dart';

/// Shared status for every crew surface, including astronauts not selected.
@immutable
class CrewEffectiveStatus {
  CrewEffectiveStatus({
    required this.astronautId,
    required this.severity,
    required this.title,
    required List<String> alerts,
  }) : alerts = List.unmodifiable(alerts);

  final String astronautId;
  final ApoloSeverity severity;
  final String title;
  final List<String> alerts;
}

final crewEffectiveStatusesProvider =
    Provider<Map<String, CrewEffectiveStatus>>((ref) {
  final crew = ref.watch(crewMembersProvider);
  final states = ref.watch(apoloStateNotifierProvider);
  final selectedId = ref.watch(selectedAstronautIdProvider);
  final session = ref.watch(agentOrchestratorProvider);
  final active = ref.watch(apoloActiveStateProvider);
  final global = ref.watch(apoloGlobalAlertStateProvider);
  return Map.unmodifiable({
    for (final astronaut in crew)
      astronaut.id: (() {
        final profileSeverity = switch (astronaut.riskLevel) {
          CrewRiskLevel.nominal => ApoloSeverity.ok,
          CrewRiskLevel.warning => ApoloSeverity.warn,
          CrewRiskLevel.critical => ApoloSeverity.crit,
        };
        final state = astronaut.id == selectedId
            ? active
            : states[ApoloRepository.resolveAstronautId(astronaut.id)];
        final components = _componentAlerts(
          astronaut.id == session.astronautId
              ? session.activeComponents
              : const <AgentViewModel>[],
        );
        final severity = ApoloSeverity.worst([
          profileSeverity,
          state?.overallSeverity ?? ApoloSeverity.ok,
          if (state?.solarStormActive == true) ApoloSeverity.warn,
          components.severity,
          if (astronaut.id == selectedId) global.severity,
        ]);
        final alerts = <String>{
          ...astronaut.activeAlerts,
          if (state != null)
            for (final mod in state.rankedModules)
              if (mod.severity != ApoloSeverity.ok)
                '${mod.title}: ${mod.keyMetric}',
          if (state?.solarStormActive == true) 'Solar storm active',
          ...components.reasons,
          if (astronaut.id == selectedId) ...global.reasons,
        }.toList();
        final title = profileSeverity == severity &&
                astronaut.riskLevel != CrewRiskLevel.nominal
            ? astronaut.riskTitle
            : alerts.isNotEmpty
                ? '${severity == ApoloSeverity.crit ? 'CRITICAL' : 'Caution'}: ${alerts.first}'
                : 'Nominal Status';
        return CrewEffectiveStatus(
          astronautId: astronaut.id,
          severity: severity,
          title: title,
          alerts: alerts,
        );
      })(),
  });
});

final effectiveCriticalCrewCountProvider = Provider<int>((ref) => ref
    .watch(crewEffectiveStatusesProvider).values
    .where((status) => status.severity == ApoloSeverity.crit).length);
final effectiveWarningCrewCountProvider = Provider<int>((ref) => ref
    .watch(crewEffectiveStatusesProvider).values
    .where((status) => status.severity == ApoloSeverity.warn).length);
final effectiveNominalCrewCountProvider = Provider<int>((ref) => ref
    .watch(crewEffectiveStatusesProvider).values
    .where((status) => status.severity == ApoloSeverity.ok).length);

@immutable
class ApoloGlobalAlertState {
  const ApoloGlobalAlertState({
    required this.severity,
    required this.isRedAlert,
    required this.evaBlocked,
    required this.reasons,
    this.primaryCause,
  });

  final ApoloSeverity severity;
  final bool isRedAlert;
  final bool evaBlocked;
  final List<String> reasons;
  final String? primaryCause;

  String get summaryLine =>
      reasons.isEmpty ? 'All monitored systems nominal.' : reasons.join(' · ');
}

/// Computes unified clinical + APOLO urine + active-component severity for
/// the selected astronaut so sky background, dog expression, red-alert banner,
/// and agent greeting always agree.
final apoloGlobalAlertStateProvider = Provider<ApoloGlobalAlertState>((ref) {
  final apoloState = ref.watch(apoloActiveStateProvider);
  final session = ref.watch(agentOrchestratorProvider);

  AstronautProfile? profile;
  try {
    profile = ref.watch(selectedAstronautProvider);
  } catch (_) {
    profile = null;
  }

  final reasons = <String>[];
  var worst = apoloState.overallSeverity;

  if (profile != null && profile.id == apoloState.astronautId) {
    final profileSev = switch (profile.riskLevel) {
      CrewRiskLevel.critical => ApoloSeverity.crit,
      CrewRiskLevel.warning => ApoloSeverity.warn,
      CrewRiskLevel.nominal => ApoloSeverity.ok,
    };
    worst = ApoloSeverity.worst([worst, profileSev]);
    if (profile.riskLevel == CrewRiskLevel.critical) {
      reasons.add(profile.riskTitle);
    }
    for (final alert in profile.activeAlerts) {
      if (profile.riskLevel == CrewRiskLevel.critical ||
          alert.toLowerCase().contains('critical') ||
          alert.toLowerCase().contains('hipoxia') ||
          alert.toLowerCase().contains('hypoxia') ||
          alert.toLowerCase().contains('no-go')) {
        if (!reasons.contains(alert)) {
          reasons.add(alert);
        }
      }
    }
  }

  for (final mod in apoloState.rankedModules) {
    if (mod.severity == ApoloSeverity.crit) {
      final line = '${mod.title} critical (${mod.keyMetric})';
      if (!reasons.contains(line)) {
        reasons.add(line);
      }
    }
  }

  final components = _componentAlerts(
    session.astronautId == apoloState.astronautId
        ? session.activeComponents
        : const <AgentViewModel>[],
  );
  worst = ApoloSeverity.worst([worst, components.severity]);
  reasons.addAll(components.reasons.where((reason) => !reasons.contains(reason)));
  if (apoloState.solarStormActive) {
    worst = ApoloSeverity.worst([worst, ApoloSeverity.warn]);
    reasons.add('Solar storm active');
  }

  if (worst == ApoloSeverity.warn && reasons.isEmpty) {
    for (final mod in apoloState.rankedModules) {
      if (mod.severity == ApoloSeverity.warn) {
        reasons.add('${mod.title} (${mod.keyMetric})');
      }
    }
  }

  final isRedAlert = worst == ApoloSeverity.crit || components.evaBlocked;
  return ApoloGlobalAlertState(
    severity: isRedAlert ? ApoloSeverity.crit : worst,
    isRedAlert: isRedAlert,
    evaBlocked: components.evaBlocked,
    reasons: List<String>.unmodifiable(reasons),
    primaryCause: reasons.isNotEmpty ? reasons.first : null,
  );
});

/// Keep active assessment safety rules identical for the crew and home views.
ApoloGlobalAlertState _componentAlerts(Iterable<AgentViewModel> components) {
  var worst = ApoloSeverity.ok;
  var evaBlocked = false;
  final reasons = <String>[];
  for (final vm in components) {
    final props = vm.toProps();
    if (vm.componentId == ComponentIds.alertBanner) {
      final sev = props['severity']?.toString().toLowerCase();
      if (sev == 'critical' || sev == 'crit') {
        worst = ApoloSeverity.crit;
        final msg = props['message']?.toString() ?? vm.title;
        if (!reasons.contains(msg)) reasons.add(msg);
      } else if (sev == 'warning' || sev == 'warn' || sev == 'caution') {
        worst = ApoloSeverity.worst([worst, ApoloSeverity.warn]);
        final msg = props['message']?.toString() ?? vm.title;
        if (!reasons.contains(msg)) reasons.add(msg);
      }
    }
    if (vm.componentId == ComponentIds.evaReadiness &&
        props['authorized'] == false) {
      evaBlocked = true;
      worst = ApoloSeverity.worst([worst, ApoloSeverity.warn]);
      reasons.add('NO-GO EVA: Authorization withheld');
    }
    if (vm.componentId == ComponentIds.graybielQuestionnaire &&
        props['eva_blocked'] == true) {
      evaBlocked = true;
      worst = ApoloSeverity.crit;
      const msg = 'NO-GO EVA: Space motion sickness threshold reached';
      if (!reasons.contains(msg)) reasons.add(msg);
    }
    if (vm.componentId == ComponentIds.exerciseMonitor &&
        props['unsafe_vitals'] == true) {
      worst = ApoloSeverity.crit;
      const msg = 'Unsafe exercise vitals detected';
      if (!reasons.contains(msg)) reasons.add(msg);
    }
    if (vm.componentId == ComponentIds.lbnpRamp &&
        props['emergency_release'] == true) {
      worst = ApoloSeverity.crit;
      const msg = 'LBNP emergency decompression triggered';
      if (!reasons.contains(msg)) reasons.add(msg);
    }
    if ((vm.componentId == ComponentIds.sansGrid ||
            vm.componentId == ComponentIds.sansFocus) &&
        props['eva_blocked'] == true) {
      evaBlocked = true;
      worst = ApoloSeverity.crit;
      const msg = 'SANS critical ocular shift detected';
      if (!reasons.contains(msg)) reasons.add(msg);
    }
  }

  final isRedAlert = worst == ApoloSeverity.crit || evaBlocked;
  return ApoloGlobalAlertState(
    severity: isRedAlert ? ApoloSeverity.crit : worst,
    isRedAlert: isRedAlert,
    evaBlocked: evaBlocked,
    reasons: List<String>.unmodifiable(reasons),
    primaryCause: reasons.isNotEmpty ? reasons.first : null,
  );
}
