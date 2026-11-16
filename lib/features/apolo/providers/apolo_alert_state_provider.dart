import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../agent/domain/agent_contracts.dart';
import '../../agent/providers/agent_providers.dart';
import '../../crew/models/astronaut_profile.dart';
import '../../crew/presentation/providers/crew_provider.dart';
import '../domain/apolo_models.dart';
import 'apolo_contract_providers.dart';

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

  var evaBlocked = false;
  for (final vm in session.activeComponents) {
    final props = vm.toProps();
    if (vm.componentId == ComponentIds.alertBanner) {
      final sev = props['severity']?.toString().toLowerCase();
      if (sev == 'critical' || sev == 'crit') {
        worst = ApoloSeverity.crit;
        final msg = props['message']?.toString() ?? vm.title;
        if (!reasons.contains(msg)) reasons.add(msg);
      }
    }
    if (vm.componentId == ComponentIds.evaReadiness &&
        props['authorized'] == false) {
      evaBlocked = true;
      worst = ApoloSeverity.worst([worst, ApoloSeverity.warn]);
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

  if (worst == ApoloSeverity.warn && reasons.isEmpty) {
    for (final mod in apoloState.rankedModules) {
      if (mod.severity == ApoloSeverity.warn) {
        reasons.add('${mod.title} (${mod.keyMetric})');
      }
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
});
