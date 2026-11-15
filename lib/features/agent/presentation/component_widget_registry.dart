import 'package:flutter/material.dart';

import 'package:astramed/core/theme/space_theme.dart';

import '../application/hands_free_controller.dart';
import '../domain/agent_contracts.dart';
import 'hands_free_widgets.dart';

/// Builder signature for any visual widget bound to an agent component id.
///
/// Frontend designers can replace any default placeholder by registering a
/// custom builder for a [ComponentIds] id without modifying agent, skill, or
/// controller logic.
typedef AgentComponentWidgetBuilder = Widget Function(
  BuildContext context,
  AgentViewModel viewModel,
  void Function(Map<String, dynamic> result) onSubmit,
  VoidCallback onDismiss,
);

/// Maps every [ComponentIds] identifier to a replaceable UI widget builder.
class AgentComponentWidgetRegistry {
  AgentComponentWidgetRegistry({
    Map<String, AgentComponentWidgetBuilder>? overrides,
  }) {
    _registerDefaults();
    if (overrides != null) {
      overrides.forEach(register);
    }
  }

  final Map<String, AgentComponentWidgetBuilder> _builders = {};

  Iterable<String> get registeredIds => _builders.keys;

  bool has(String componentId) => _builders.containsKey(componentId);

  AgentComponentWidgetBuilder? builderFor(String componentId) =>
      _builders[componentId];

  void register(String componentId, AgentComponentWidgetBuilder builder) {
    if (componentId.trim().isEmpty) {
      throw const FormatException('Component id must not be empty.');
    }
    _builders[componentId] = builder;
  }

  AgentComponentWidgetRegistry copyWithOverrides(
    Map<String, AgentComponentWidgetBuilder> overrides,
  ) {
    return AgentComponentWidgetRegistry(
      overrides: {..._builders, ...overrides},
    );
  }

  Widget build(
    BuildContext context,
    AgentViewModel viewModel, {
    required void Function(Map<String, dynamic> result) onSubmit,
    required VoidCallback onDismiss,
  }) {
    final builder = _builders[viewModel.componentId];
    if (builder != null) {
      return builder(context, viewModel, onSubmit, onDismiss);
    }
    return _PlaceholderComponentCard(
      viewModel: viewModel,
      accentColor: SpaceTheme.cyan,
      icon: Icons.widgets_outlined,
      onDismiss: onDismiss,
    );
  }

  void _registerDefaults() {
    register(ComponentIds.vitalsCard, _buildVitalsCard);
    register(ComponentIds.telemetryChart, _buildTelemetryChart);
    register(ComponentIds.crewStatus, _buildCrewStatus);
    register(ComponentIds.statusReport, _buildStatusReport);
    register(ComponentIds.evaReadiness, _buildEvaReadiness);
    register(ComponentIds.alertBanner, _buildAlertBanner);
    register(ComponentIds.spaceWeatherAlert, _buildSpaceWeatherAlert);
    register(ComponentIds.pharmacyBatches, _buildPharmacyBatches);
    register(ComponentIds.ramanRequest, _buildRamanRequest);
    register(ComponentIds.medicationCheck, _buildMedicationCheck);
    register(ComponentIds.graybielQuestionnaire, _buildGraybielQuestionnaire);
    register(ComponentIds.pvtTest, _buildPvtTest);
    register(ComponentIds.mptTest, _buildMptTest);
    register(ComponentIds.sansGrid, _buildSansGrid);
    register(ComponentIds.sansContrast, _buildSansContrast);
    register(ComponentIds.sansFocus, _buildSansFocus);
    register(ComponentIds.exerciseMonitor, _buildExerciseMonitor);
    register(ComponentIds.lbnpRamp, _buildLbnpRamp);
    register(ComponentIds.ultrasoundGuide, _buildUltrasoundGuide);
    register(ComponentIds.diaryRecorder, _buildDiaryRecorder);
    register(ComponentIds.recommendations, _buildRecommendations);
    register(ComponentIds.confirmAction, _buildConfirmAction);
    register(HandsFreeWidgetIds.toggle, _buildHandsFreeToggle);
    register(HandsFreeWidgetIds.listeningIndicator, _buildListeningIndicator);
  }

  static Widget _buildHandsFreeToggle(
    BuildContext context,
    AgentViewModel vm,
    void Function(Map<String, dynamic>) onSubmit,
    VoidCallback onDismiss,
  ) {
    final toggleVm = vm is HandsFreeToggleViewModel
        ? vm
        : HandsFreeToggleViewModel(
            enabled: vm.toProps()['enabled'] == true,
            status: HandsFreeStatus.values.firstWhere(
              (s) => s.name == vm.toProps()['status'],
              orElse: () => HandsFreeStatus.off,
            ),
            permissionDenied: vm.toProps()['permission_denied'] == true,
            supported: vm.toProps()['supported'] != false,
            errorMessage: vm.toProps()['error_message']?.toString(),
          );
    return HandsFreeTogglePlaceholder(
      viewModel: toggleVm,
      onToggle: (nextEnabled) => onSubmit({'enabled': nextEnabled}),
    );
  }

  static Widget _buildListeningIndicator(
    BuildContext context,
    AgentViewModel vm,
    void Function(Map<String, dynamic>) onSubmit,
    VoidCallback onDismiss,
  ) {
    final indVm = vm is ListeningIndicatorViewModel
        ? vm
        : ListeningIndicatorViewModel(
            status: HandsFreeStatus.values.firstWhere(
              (s) => s.name == vm.toProps()['status'],
              orElse: () => HandsFreeStatus.off,
            ),
            handsFreeEnabled: vm.toProps()['hands_free_enabled'] == true,
            manualListening: vm.toProps()['manual_listening'] == true,
            usingLocalFallback: vm.toProps()['using_local_fallback'] == true,
            errorMessage: vm.toProps()['error_message']?.toString(),
          );
    return ListeningIndicatorPlaceholder(viewModel: indVm);
  }

  static Widget _buildVitalsCard(
    BuildContext context,
    AgentViewModel vm,
    void Function(Map<String, dynamic>) onSubmit,
    VoidCallback onDismiss,
  ) {
    final props = vm.toProps();
    final vitalsMap = props['vitals'] is Map
        ? Map<String, dynamic>.from(props['vitals'] as Map)
        : props;
    final hr = _numStr(vitalsMap['heart_rate']);
    final sbp = _numStr(vitalsMap['systolic_bp']);
    final dbp = _numStr(vitalsMap['diastolic_bp']);
    final spo2 = _numStr(vitalsMap['spo2']);
    final temp = _numStr(vitalsMap['body_temp'], decimals: 1);

    return _PlaceholderComponentCard(
      viewModel: vm,
      accentColor: SpaceTheme.cyan,
      icon: Icons.monitor_heart_outlined,
      onDismiss: onDismiss,
      body: Wrap(
        spacing: 10,
        runSpacing: 8,
        children: [
          _MetricChip(label: 'HR', value: '$hr bpm'),
          _MetricChip(label: 'BP', value: '$sbp/$dbp mmHg'),
          _MetricChip(label: 'SpO2', value: '$spo2%'),
          if (temp != '--') _MetricChip(label: 'Temp', value: '$temp C'),
        ],
      ),
    );
  }

  static Widget _buildTelemetryChart(
    BuildContext context,
    AgentViewModel vm,
    void Function(Map<String, dynamic>) onSubmit,
    VoidCallback onDismiss,
  ) {
    final props = vm.toProps();
    final series = props['series'] as List<dynamic>? ?? const [];
    final metric = props['metric']?.toString() ?? 'telemetry';
    final unit = props['unit']?.toString() ?? '';

    return _PlaceholderComponentCard(
      viewModel: vm,
      accentColor: SpaceTheme.cyan,
      icon: Icons.show_chart,
      onDismiss: onDismiss,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Metric: $metric${unit.isNotEmpty ? ' ($unit)' : ''} · ${series.length} sample(s)',
            style: const TextStyle(fontSize: 12, color: Colors.white70),
          ),
          if (series.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: series
                  .take(6)
                  .map((item) {
                    final map = item is Map
                        ? Map<String, dynamic>.from(item)
                        : const <String, dynamic>{};
                    return _MetricChip(
                      label: map['label']?.toString() ?? '-',
                      value: '${map['value'] ?? '--'} $unit'.trim(),
                    );
                  })
                  .toList(growable: false),
            ),
          ],
        ],
      ),
    );
  }

  static Widget _buildCrewStatus(
    BuildContext context,
    AgentViewModel vm,
    void Function(Map<String, dynamic>) onSubmit,
    VoidCallback onDismiss,
  ) {
    final props = vm.toProps();
    final crew = props['crew'] as List<dynamic>? ?? const [];
    return _PlaceholderComponentCard(
      viewModel: vm,
      accentColor: SpaceTheme.cyan,
      icon: Icons.groups_outlined,
      onDismiss: onDismiss,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final entry in crew.take(5))
            if (entry is Map)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(
                  '${entry['name'] ?? entry['id']} (${entry['risk_level'] ?? 'nominal'}) · HR ${_numStr(entry['heart_rate'])} · SpO2 ${_numStr(entry['spo2'])}%',
                  style: const TextStyle(fontSize: 12, color: Colors.white70),
                ),
              ),
        ],
      ),
    );
  }

  static Widget _buildStatusReport(
    BuildContext context,
    AgentViewModel vm,
    void Function(Map<String, dynamic>) onSubmit,
    VoidCallback onDismiss,
  ) {
    final props = vm.toProps();
    final risk = props['risk_level']?.toString() ?? 'nominal';
    final summary = props['summary']?.toString() ?? '';
    final alerts = props['active_alerts'] as List<dynamic>? ?? const [];
    return _PlaceholderComponentCard(
      viewModel: vm,
      accentColor: _riskColor(risk),
      icon: Icons.assignment_outlined,
      onDismiss: onDismiss,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (summary.isNotEmpty)
            Text(summary, style: const TextStyle(fontSize: 13)),
          if (alerts.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Alerts: ${alerts.join(' · ')}',
              style: const TextStyle(
                fontSize: 12,
                color: SpaceTheme.warningYellow,
              ),
            ),
          ],
        ],
      ),
    );
  }

  static Widget _buildEvaReadiness(
    BuildContext context,
    AgentViewModel vm,
    void Function(Map<String, dynamic>) onSubmit,
    VoidCallback onDismiss,
  ) {
    final props = vm.toProps();
    final status =
        props['status']?.toString() ??
        props['readiness']?.toString() ??
        (props['ready'] == false ? 'blocked' : 'evaluated');
    final isBlocked =
        status.toLowerCase().contains('block') || props['ready'] == false;
    return _PlaceholderComponentCard(
      viewModel: vm,
      accentColor: isBlocked ? SpaceTheme.dangerRed : SpaceTheme.green,
      icon: Icons.rocket_launch_outlined,
      onDismiss: onDismiss,
      body: _KeyPropsSummary(props: props),
    );
  }

  static Widget _buildAlertBanner(
    BuildContext context,
    AgentViewModel vm,
    void Function(Map<String, dynamic>) onSubmit,
    VoidCallback onDismiss,
  ) {
    final props = vm.toProps();
    final severity = props['severity']?.toString() ?? 'info';
    final message = props['message']?.toString() ?? vm.title;
    final action = props['recommended_action']?.toString();
    final suppressed = props['suppressed'] == true;
    return _PlaceholderComponentCard(
      viewModel: vm,
      accentColor: _riskColor(severity),
      icon: Icons.warning_amber_rounded,
      onDismiss: onDismiss,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(message, style: const TextStyle(fontSize: 13)),
          if (suppressed)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text(
                'Suppressed artifact alarm',
                style: TextStyle(fontSize: 11, color: Colors.white54),
              ),
            ),
          if (action != null && action.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Action: $action',
                style: const TextStyle(fontSize: 12, color: SpaceTheme.cyan),
              ),
            ),
        ],
      ),
    );
  }

  static Widget _buildSpaceWeatherAlert(
    BuildContext context,
    AgentViewModel vm,
    void Function(Map<String, dynamic>) onSubmit,
    VoidCallback onDismiss,
  ) {
    final props = vm.toProps();
    final level = props['alert_level']?.toString() ?? 'nominal';
    final storm = props['storm_active'] == true;
    return _PlaceholderComponentCard(
      viewModel: vm,
      accentColor: storm ? SpaceTheme.dangerRed : SpaceTheme.warningYellow,
      icon: Icons.wb_sunny_outlined,
      onDismiss: onDismiss,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _MetricChip(label: 'Level', value: level.toUpperCase()),
              _MetricChip(
                label: 'Class',
                value: props['max_event_class']?.toString() ?? '--',
              ),
              _MetricChip(
                label: 'Flux',
                value: '${_numStr(props['peak_flux_pfu'])} pfu',
              ),
            ],
          ),
          if (props['summary'] != null) ...[
            const SizedBox(height: 6),
            Text(
              props['summary'].toString(),
              style: const TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ],
        ],
      ),
    );
  }

  static Widget _buildPharmacyBatches(
    BuildContext context,
    AgentViewModel vm,
    void Function(Map<String, dynamic>) onSubmit,
    VoidCallback onDismiss,
  ) {
    final props = vm.toProps();
    final batches = props['batches'] as List<dynamic>? ?? const [];
    return _PlaceholderComponentCard(
      viewModel: vm,
      accentColor: SpaceTheme.warningYellow,
      icon: Icons.medication_liquid_outlined,
      onDismiss: onDismiss,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (props['summary'] != null)
            Text(
              props['summary'].toString(),
              style: const TextStyle(fontSize: 12),
            ),
          const SizedBox(height: 6),
          Text(
            'Evaluated batches: ${batches.length}',
            style: const TextStyle(fontSize: 12, color: Colors.white70),
          ),
        ],
      ),
    );
  }

  static Widget _buildRamanRequest(
    BuildContext context,
    AgentViewModel vm,
    void Function(Map<String, dynamic>) onSubmit,
    VoidCallback onDismiss,
  ) {
    final props = vm.toProps();
    final batchIds = (props['batch_ids'] as List<dynamic>? ?? const []).join(
      ', ',
    );
    return _PlaceholderComponentCard(
      viewModel: vm,
      accentColor: SpaceTheme.neonPurple,
      icon: Icons.science_outlined,
      onDismiss: onDismiss,
      body: Text(
        'Batches: $batchIds\nPriority: ${props['priority'] ?? 'urgent'} · Status: ${props['status'] ?? 'requested'}',
        style: const TextStyle(fontSize: 12, color: Colors.white70),
      ),
    );
  }

  static Widget _buildMedicationCheck(
    BuildContext context,
    AgentViewModel vm,
    void Function(Map<String, dynamic>) onSubmit,
    VoidCallback onDismiss,
  ) {
    final props = vm.toProps();
    final allowed = props['allowed'] == true;
    final reasons = (props['reasons'] as List<dynamic>? ?? const []).join('; ');
    return _PlaceholderComponentCard(
      viewModel: vm,
      accentColor: allowed ? SpaceTheme.green : SpaceTheme.dangerRed,
      icon: Icons.verified_user_outlined,
      onDismiss: onDismiss,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${props['medication'] ?? ''} ${props['dose_mg'] ?? ''} mg (${props['route'] ?? ''}) — ${allowed ? 'ALLOWED' : 'BLOCKED'}',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: allowed ? SpaceTheme.green : SpaceTheme.dangerRed,
            ),
          ),
          if (reasons.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              reasons,
              style: const TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ],
          if (props['suggested_alternative_route'] != null) ...[
            const SizedBox(height: 4),
            Text(
              'Suggested route: ${props['suggested_alternative_route']}',
              style: const TextStyle(fontSize: 12, color: SpaceTheme.cyan),
            ),
          ],
        ],
      ),
    );
  }

  static Widget _buildGraybielQuestionnaire(
    BuildContext context,
    AgentViewModel vm,
    void Function(Map<String, dynamic>) onSubmit,
    VoidCallback onDismiss,
  ) {
    final props = vm.toProps();
    final currentSymptom = props['current_symptom']?.toString() ?? 'nausea';
    final prompt =
        props['current_prompt']?.toString() ??
        'Select severity level for $currentSymptom.';
    final answered = props['answered_count'] ?? 0;
    final total = props['total_symptoms'] ?? 7;
    final completed = props['completed'] == true;
    const levels = ['none', 'minimal', 'minor', 'moderate', 'severe'];

    return _PlaceholderComponentCard(
      viewModel: vm,
      accentColor: SpaceTheme.cyan,
      icon: Icons.quiz_outlined,
      onDismiss: onDismiss,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            completed
                ? 'Assessment completed ($answered/$total)'
                : 'Progress: $answered/$total · $prompt',
            style: const TextStyle(fontSize: 12, color: Colors.white70),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final level in levels)
                OutlinedButton(
                  onPressed: () =>
                      onSubmit({'symptom': currentSymptom, 'level': level}),
                  child: Text(level),
                ),
              FilledButton(
                onPressed: () => onSubmit({
                  'completed': true,
                  'responses': props['responses'] ?? const <String, dynamic>{},
                }),
                child: const Text('Complete'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static Widget _buildPvtTest(
    BuildContext context,
    AgentViewModel vm,
    void Function(Map<String, dynamic>) onSubmit,
    VoidCallback onDismiss,
  ) {
    final props = vm.toProps();
    final trials = props['trial_count'] ?? 10;
    return _PlaceholderComponentCard(
      viewModel: vm,
      accentColor: SpaceTheme.cyan,
      icon: Icons.timer_outlined,
      onDismiss: onDismiss,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'PVT Trials: $trials · LRM-50: ${props['last_lrm50_ms'] ?? '--'} ms',
            style: const TextStyle(fontSize: 12, color: Colors.white70),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton(
                onPressed: () => onSubmit({
                  'reaction_times_ms': [235, 242, 248, 250, 239],
                  'completed': true,
                }),
                child: const Text('Submit Nominal Sample'),
              ),
              FilledButton(
                onPressed: () => onSubmit({'completed': true}),
                child: const Text('Complete PVT'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static Widget _buildMptTest(
    BuildContext context,
    AgentViewModel vm,
    void Function(Map<String, dynamic>) onSubmit,
    VoidCallback onDismiss,
  ) {
    final props = vm.toProps();
    final targets = (props['target_count'] as num?)?.toInt() ?? 20;
    return _PlaceholderComponentCard(
      viewModel: vm,
      accentColor: SpaceTheme.cyan,
      icon: Icons.track_changes_outlined,
      onDismiss: onDismiss,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Targets: $targets · Tolerance: ${props['tolerance_mm'] ?? 3.0} mm',
            style: const TextStyle(fontSize: 12, color: Colors.white70),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton(
                onPressed: () => onSubmit({
                  'targets_hit': targets,
                  'total_targets': targets,
                  'path_deviations_mm': const [1.2, 1.5, 1.8],
                  'completed': true,
                }),
                child: const Text('Submit Nominal Run'),
              ),
              FilledButton(
                onPressed: () => onSubmit({'completed': true}),
                child: const Text('Complete MPT'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static Widget _buildSansGrid(
    BuildContext context,
    AgentViewModel vm,
    void Function(Map<String, dynamic>) onSubmit,
    VoidCallback onDismiss,
  ) {
    final props = vm.toProps();
    return _PlaceholderComponentCard(
      viewModel: vm,
      accentColor: SpaceTheme.cyan,
      icon: Icons.grid_on_outlined,
      onDismiss: onDismiss,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            props['instruction']?.toString() ?? 'Amsler Grid screening',
            style: const TextStyle(fontSize: 12, color: Colors.white70),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton(
                onPressed: () => onSubmit({
                  'metamorphopsia_reported': false,
                  'scotoma_reported': false,
                }),
                child: const Text('Grid Clear'),
              ),
              OutlinedButton(
                onPressed: () => onSubmit({
                  'metamorphopsia_reported': true,
                  'scotoma_reported': false,
                }),
                child: const Text('Wavy Lines'),
              ),
              OutlinedButton(
                onPressed: () => onSubmit({
                  'metamorphopsia_reported': false,
                  'scotoma_reported': true,
                }),
                child: const Text('Blind Spot'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static Widget _buildSansContrast(
    BuildContext context,
    AgentViewModel vm,
    void Function(Map<String, dynamic>) onSubmit,
    VoidCallback onDismiss,
  ) {
    final props = vm.toProps();
    return _PlaceholderComponentCard(
      viewModel: vm,
      accentColor: SpaceTheme.cyan,
      icon: Icons.contrast_outlined,
      onDismiss: onDismiss,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            props['instruction']?.toString() ??
                'Contrast sensitivity screening',
            style: const TextStyle(fontSize: 12, color: Colors.white70),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton(
                onPressed: () =>
                    onSubmit({'contrast_log_cs': 1.80, 'contrast_loss': false}),
                child: const Text('1.80 logCS (Nominal)'),
              ),
              OutlinedButton(
                onPressed: () =>
                    onSubmit({'contrast_log_cs': 1.60, 'contrast_loss': false}),
                child: const Text('1.60 logCS'),
              ),
              OutlinedButton(
                onPressed: () =>
                    onSubmit({'contrast_log_cs': 1.35, 'contrast_loss': true}),
                child: const Text('1.35 logCS (Loss)'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static Widget _buildSansFocus(
    BuildContext context,
    AgentViewModel vm,
    void Function(Map<String, dynamic>) onSubmit,
    VoidCallback onDismiss,
  ) {
    final props = vm.toProps();
    return _PlaceholderComponentCard(
      viewModel: vm,
      accentColor: SpaceTheme.cyan,
      icon: Icons.center_focus_strong_outlined,
      onDismiss: onDismiss,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            props['instruction']?.toString() ?? 'Near focus distance test',
            style: const TextStyle(fontSize: 12, color: Colors.white70),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton(
                onPressed: () => onSubmit({'near_focus_cm': 25.0}),
                child: const Text('25 cm'),
              ),
              OutlinedButton(
                onPressed: () => onSubmit({'near_focus_cm': 40.0}),
                child: const Text('40 cm'),
              ),
              OutlinedButton(
                onPressed: () => onSubmit({'near_focus_cm': 50.0}),
                child: const Text('50 cm'),
              ),
              OutlinedButton(
                onPressed: () => onSubmit({'near_focus_cm': 60.0}),
                child: const Text('60 cm'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static Widget _buildExerciseMonitor(
    BuildContext context,
    AgentViewModel vm,
    void Function(Map<String, dynamic>) onSubmit,
    VoidCallback onDismiss,
  ) {
    final props = vm.toProps();
    final unsafe = props['unsafe_vitals'] == true;
    return _PlaceholderComponentCard(
      viewModel: vm,
      accentColor: unsafe ? SpaceTheme.dangerRed : SpaceTheme.green,
      icon: Icons.fitness_center_outlined,
      onDismiss: onDismiss,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _MetricChip(
                label: 'Device',
                value: props['device_name']?.toString() ?? '--',
              ),
              _MetricChip(
                label: 'HR',
                value: '${_numStr(props['heart_rate'])} bpm',
              ),
              _MetricChip(label: 'SpO2', value: '${_numStr(props['spo2'])}%'),
            ],
          ),
          if (props['guidance'] != null) ...[
            const SizedBox(height: 6),
            Text(
              props['guidance'].toString(),
              style: const TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ],
        ],
      ),
    );
  }

  static Widget _buildLbnpRamp(
    BuildContext context,
    AgentViewModel vm,
    void Function(Map<String, dynamic>) onSubmit,
    VoidCallback onDismiss,
  ) {
    final props = vm.toProps();
    final phase = props['phase']?.toString() ?? 'prep_sealCheck';
    final pressure = props['pressure_mmhg'] ?? 0;
    final emergency = props['emergency_release'] == true;
    return _PlaceholderComponentCard(
      viewModel: vm,
      accentColor: emergency ? SpaceTheme.dangerRed : SpaceTheme.cyan,
      icon: Icons.compress_outlined,
      onDismiss: onDismiss,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Phase: $phase · Pressure: $pressure mmHg',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          if (props['instruction'] != null &&
              props['instruction'].toString().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              props['instruction'].toString(),
              style: const TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton(
                onPressed: () => onSubmit({'action': 'advance'}),
                child: const Text('Advance Phase'),
              ),
              OutlinedButton(
                onPressed: () => onSubmit({'action': 'abort'}),
                child: const Text('Controlled Abort'),
              ),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: SpaceTheme.dangerRed,
                ),
                onPressed: () => onSubmit({
                  'action': 'emergency_abort',
                  'emergency_syncope': true,
                }),
                child: const Text('Emergency Release'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static Widget _buildUltrasoundGuide(
    BuildContext context,
    AgentViewModel vm,
    void Function(Map<String, dynamic>) onSubmit,
    VoidCallback onDismiss,
  ) {
    final props = vm.toProps();
    return _PlaceholderComponentCard(
      viewModel: vm,
      accentColor: SpaceTheme.cyan,
      icon: Icons.medical_information_outlined,
      onDismiss: onDismiss,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Step: ${props['step'] ?? 'prep_gel_and_probe'}',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          if (props['instruction'] != null &&
              props['instruction'].toString().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              props['instruction'].toString(),
              style: const TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton(
                onPressed: () => onSubmit({
                  'action': 'next_step',
                  'acoustic_window_ok': true,
                }),
                child: const Text('Next Step'),
              ),
              OutlinedButton(
                onPressed: () =>
                    onSubmit({'step': 'completed', 'completed': true}),
                child: const Text('Complete Scan'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static Widget _buildDiaryRecorder(
    BuildContext context,
    AgentViewModel vm,
    void Function(Map<String, dynamic>) onSubmit,
    VoidCallback onDismiss,
  ) {
    final props = vm.toProps();
    final prompts = (props['prompts'] as List<dynamic>? ?? const [])
        .map((e) => e.toString())
        .toList(growable: false);
    return _PlaceholderComponentCard(
      viewModel: vm,
      accentColor: SpaceTheme.cyan,
      icon: Icons.mic_none_outlined,
      onDismiss: onDismiss,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final prompt in prompts.take(3))
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '• $prompt',
                style: const TextStyle(fontSize: 12, color: Colors.white70),
              ),
            ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton(
                onPressed: () => onSubmit({
                  'transcript': 'Rested and nominal today.',
                  'completed': true,
                }),
                child: const Text('Log Nominal Check-In'),
              ),
              OutlinedButton(
                onPressed: () => onSubmit({
                  'transcript': 'Fatigued and low energy after poor sleep.',
                  'completed': true,
                }),
                child: const Text('Log Fatigue Check-In'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static Widget _buildRecommendations(
    BuildContext context,
    AgentViewModel vm,
    void Function(Map<String, dynamic>) onSubmit,
    VoidCallback onDismiss,
  ) {
    final props = vm.toProps();
    final recs = props['recommendations'] as List<dynamic>? ?? const [];
    return _PlaceholderComponentCard(
      viewModel: vm,
      accentColor: SpaceTheme.green,
      icon: Icons.tips_and_updates_outlined,
      onDismiss: onDismiss,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (props['summary'] != null)
            Text(
              props['summary'].toString(),
              style: const TextStyle(fontSize: 12),
            ),
          const SizedBox(height: 6),
          for (final item in recs.take(4))
            if (item is Map)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '• ${item['title']}: ${item['action']}',
                  style: const TextStyle(fontSize: 12, color: Colors.white70),
                ),
              ),
        ],
      ),
    );
  }

  static Widget _buildConfirmAction(
    BuildContext context,
    AgentViewModel vm,
    void Function(Map<String, dynamic>) onSubmit,
    VoidCallback onDismiss,
  ) {
    final props = vm.toProps();
    final actionId = (props['id'] ?? props['action_id'])?.toString() ?? '';
    final description = props['description']?.toString() ?? vm.title;
    final actionType = props['action_type']?.toString();

    return _PlaceholderComponentCard(
      viewModel: vm,
      accentColor: SpaceTheme.warningYellow,
      icon: Icons.shield_outlined,
      onDismiss: onDismiss,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (actionType != null && actionType.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                'Action type: $actionType',
                style: const TextStyle(fontSize: 11, color: Colors.white60),
              ),
            ),
          Text(description, style: const TextStyle(fontSize: 13)),
          const SizedBox(height: 12),
          Row(
            children: [
              FilledButton.icon(
                key: const ValueKey('confirm_action_confirm_button'),
                style: FilledButton.styleFrom(
                  backgroundColor: SpaceTheme.green,
                  foregroundColor: Colors.black,
                ),
                onPressed: () => onSubmit({
                  'decision': ConfirmationDecision.confirmed.wireName,
                  if (actionId.isNotEmpty) 'action_id': actionId,
                }),
                icon: const Icon(Icons.check, size: 18),
                label: const Text('Confirm'),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                key: const ValueKey('confirm_action_reject_button'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: SpaceTheme.dangerRed,
                  side: const BorderSide(color: SpaceTheme.dangerRed),
                ),
                onPressed: () => onSubmit({
                  'decision': ConfirmationDecision.rejected.wireName,
                  if (actionId.isNotEmpty) 'action_id': actionId,
                }),
                icon: const Icon(Icons.close, size: 18),
                label: const Text('Reject'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static Color _riskColor(String raw) {
    final lower = raw.toLowerCase();
    if (lower.contains('critical') ||
        lower.contains('high') ||
        lower.contains('danger')) {
      return SpaceTheme.dangerRed;
    }
    if (lower.contains('warn') ||
        lower.contains('caution') ||
        lower.contains('elevated')) {
      return SpaceTheme.warningYellow;
    }
    return SpaceTheme.green;
  }

  static String _numStr(Object? raw, {int decimals = 0}) {
    if (raw is! num) return '--';
    return raw.toDouble().toStringAsFixed(decimals);
  }
}

class _PlaceholderComponentCard extends StatelessWidget {
  const _PlaceholderComponentCard({
    required this.viewModel,
    required this.accentColor,
    required this.icon,
    required this.onDismiss,
    this.body,
  });

  final AgentViewModel viewModel;
  final Color accentColor;
  final IconData icon;
  final VoidCallback onDismiss;
  final Widget? body;

  @override
  Widget build(BuildContext context) {
    return Card(
      key: ValueKey('agent_component_${viewModel.componentId}'),
      margin: const EdgeInsets.only(bottom: 12),
      color: SpaceTheme.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: accentColor.withValues(alpha: 0.45)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: accentColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    viewModel.title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    viewModel.componentId,
                    style: TextStyle(
                      fontSize: 10,
                      color: accentColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  key: ValueKey(
                    'agent_component_dismiss_${viewModel.componentId}',
                  ),
                  tooltip: 'Dismiss component',
                  visualDensity: VisualDensity.compact,
                  onPressed: onDismiss,
                  icon: const Icon(
                    Icons.close,
                    size: 18,
                    color: Colors.white60,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            body ?? _KeyPropsSummary(props: viewModel.toProps()),
          ],
        ),
      ),
    );
  }
}

class _KeyPropsSummary extends StatelessWidget {
  const _KeyPropsSummary({required this.props});

  final Map<String, dynamic> props;

  @override
  Widget build(BuildContext context) {
    final entries = props.entries
        .where((e) => e.key != 'component_id' && e.key != 'title')
        .take(6)
        .toList(growable: false);
    if (entries.isEmpty) {
      return const Text(
        'No additional properties.',
        style: TextStyle(fontSize: 12, color: Colors.white54),
      );
    }
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: [
        for (final entry in entries)
          _MetricChip(label: entry.key, value: entry.value.toString()),
      ],
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: SpaceTheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white12),
      ),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(fontSize: 12, color: Colors.white),
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(color: Colors.white60),
            ),
            TextSpan(
              text: value,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
