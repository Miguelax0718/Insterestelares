# AstraMed Agent Frontend Component Handoff Guide

This document explains how AstraMed's headless clinical agent UI injection system works and how to replace any placeholder component widget with custom production visuals without touching agent, skill, or controller code.

---

## 1. Architecture: Headless Component Injection

The clinical agent never builds Flutter widgets directly inside skills or tools. Instead:

```text
Agent Tool / Proactive Monitor
  └─ emits AgentComponentEvent.show(id, props) or .hide(id)
       └─ ComponentRegistry (lib/features/agent/application/component_registry.dart)
            └─ validates props & constructs a typed AgentViewModel
                 └─ AgentSessionState.activeComponents
                      └─ AgentCanvasView (lib/features/agent/presentation/agent_canvas_view.dart)
                           └─ AgentComponentWidgetRegistry (lib/features/agent/presentation/component_widget_registry.dart)
                                └─ renders the widget registered for `viewModel.componentId`
```

Key files:
- `lib/features/agent/domain/agent_contracts.dart` — `ComponentIds`, `AgentViewModel`, `AgentComponentEvent`, `AgentUiSink`
- `lib/features/agent/application/component_registry.dart` — `ComponentSpec` & `ComponentRegistry` (`fromProps` validation)
- `lib/features/agent/presentation/component_widget_registry.dart` — `AgentComponentWidgetBuilder` & `AgentComponentWidgetRegistry`
- `lib/features/agent/presentation/agent_canvas_view.dart` — Main Agent Canvas, Dynamic Component Injection Zone, and Crew Sidebar
- `lib/features/agent/providers/agent_providers.dart` — Riverpod providers including `componentWidgetOverridesProvider` and `componentWidgetRegistryProvider`

**Visual silence invariant:** When `AgentSessionState.activeComponents` is empty, the Dynamic Component Injection Zone renders nothing (`SizedBox.shrink()`).

---

## 2. How to Replace Any Placeholder Widget in One Step

Every widget builder has the signature:

```dart
typedef AgentComponentWidgetBuilder = Widget Function(
  BuildContext context,
  AgentViewModel viewModel,
  void Function(Map<String, dynamic> result) onSubmit,
  VoidCallback onDismiss,
);
```

### Option A: Override via Riverpod (`componentWidgetOverridesProvider`) — Recommended

Pass your custom builders in `ProviderScope.overrides` (for example in `main.dart`):

```dart
ProviderScope(
  overrides: [
    componentWidgetOverridesProvider.overrideWithValue({
      ComponentIds.vitalsCard: (context, viewModel, onSubmit, onDismiss) {
        final vm = viewModel as VitalsCardViewModel;
        return MyDesignerVitalsCard(
          heartRate: vm.heartRate,
          spO2: vm.spO2,
          onClose: onDismiss,
        );
      },
      ComponentIds.confirmAction: (context, viewModel, onSubmit, onDismiss) {
        final props = viewModel.toProps();
        return MyConfirmationModal(
          description: props['description'] as String,
          onConfirm: () => onSubmit({'decision': 'confirmed'}),
          onReject: () => onSubmit({'decision': 'rejected'}),
        );
      },
    }),
  ],
  child: const AstraMedApp(),
)
```

### Option B: Mutate or Copy an `AgentComponentWidgetRegistry` Instance

```dart
final registry = AgentComponentWidgetRegistry()
  ..register(ComponentIds.vitalsCard, myVitalsBuilder);

// Or immutably:
final customRegistry = registry.copyWithOverrides({
  ComponentIds.vitalsCard: myVitalsBuilder,
});
```

### Widget Contract Rules

1. **Read data** from the typed `AgentViewModel` (or `viewModel.toProps()` if using `GenericComponentViewModel`).
2. **Send user interaction results** back via `onSubmit(result)` using the payload shapes listed below.
3. **Allow dismissal** via `onDismiss()`.
4. **Never call clinical engines or mutate Hive/crew state directly** from a component widget.

---

## 3. Complete Component Catalog (All 22 `ComponentIds`)

| `ComponentIds` constant (wire id) | Module | `AgentViewModel` Class | Input Props (`toProps()`) | `onSubmit` Payload Shape |
|---|---|---|---|---|
| `ComponentIds.vitalsCard` (`vitals_card`) | 01 / Core | `VitalsCardViewModel` | `title`, `astronaut_id`, `astronaut_name`, `heart_rate`, `systolic_bp`, `diastolic_bp`, `spo2`, `body_temp`, `blood_glucose`, `respiratory_rate`, `capillary_refill_seconds`, `activity_state`, `signal_quality`, `source`, `timestamp` *(adapter also accepts nested `vitals` map from `get_vitals`)* | Display-only (`{}` if unused) |
| `ComponentIds.telemetryChart` (`telemetry_chart`) | 01 / Core | `TelemetryChartViewModel` | `title`, `metric`, `unit`, `astronaut_id`, `series` (`[{label, value, metadata?}]`), `summary` *(adapter also accepts `machines` / `recent_logs` / `metrics` from `get_telemetry_series`)* | Display-only |
| `ComponentIds.crewStatus` (`crew_status`) | Core | `GenericComponentViewModel` | `title`, `crew` (`[{id, name, role, risk_level, heart_rate, spo2, sleep_hours, alert_count}]`), `count` | Display-only |
| `ComponentIds.statusReport` (`status_report`) | 01 | `StatusReportViewModel` | `title`, `astronaut_id`, `astronaut_name`, `callsign`, `risk_level`, `risk_title`, `summary`, `active_alerts` (`List<String>`), `active_flags` (`Map`), `subsystems` (`Map`), `generated_at` | Display-only |
| `ComponentIds.evaReadiness` (`eva_readiness`) | 05 | `GenericComponentViewModel` *(pluggable via `extraComponentSpecsProvider`)* | `title`, `astronaut_id`, `status` / `ready`, `blockers`, `warnings`, `summary` | Display-only |
| `ComponentIds.alertBanner` (`alert_banner`) | 01 / Core / 05 | `AlertBannerViewModel` | `title`, `severity` (`info`\|`warning`\|`critical`), `classification`, `message`, `suppressed` (`bool`), `recommended_action?`, `astronaut_id?`, `details` (`List<String>`) | Display-only |
| `ComponentIds.spaceWeatherAlert` (`space_weather_alert`) | 02 | `SpaceWeatherAlertViewModel` | `title`, `alert_level`, `storm_active` (`bool`), `max_event_class`, `peak_flux_pfu`, `duration_hours`, `source`, `is_offline_fallback`, `fetched_at`, `summary`, `flares_count`, `sep_events_count` | Display-only |
| `ComponentIds.pharmacyBatches` (`pharmacy_batches`) | 02 | `PharmacyBatchesViewModel` | `title`, `event_class`, `dose_equivalent_msv`, `raman_verification_required`, `leukocyte_check_times`, `batches` (`[{batch_id, medication, route, storage_location, units_remaining, degradation_pct, delta_pct, flagged, compromised}]`), `summary` | Display-only |
| `ComponentIds.ramanRequest` (`raman_request`) | 02 | `RamanRequestViewModel` | `title`, `batch_ids` (`List<String>`), `reason`, `priority` (`routine`\|`urgent`\|`critical`), `requested_at`, `status` | Display-only |
| `ComponentIds.medicationCheck` (`medication_check`) | 02 / 04 | `MedicationCheckViewModel` | `title`, `astronaut_id`, `medication`, `dose_mg`, `route`, `allowed` (`bool`), `reasons` (`List<String>`), `batch_id?`, `remaining_units?`, `suggested_alternative_route?` | Display-only |
| `ComponentIds.graybielQuestionnaire` (`graybiel_questionnaire`) | 03 | `GraybielQuestionnaireViewModel` | `component_id`, `title`, `astronaut_id`, `current_symptom?`, `current_prompt?`, `answered_count`, `total_symptoms`, `responses` (`Map<String, String>`), `emesis` (`bool`), `completed` (`bool`), `evaluation?` | `{'symptom': String, 'level': 'none'\|'minimal'\|'minor'\|'moderate'\|'severe', 'emesis'?: bool}` or `{'completed': true, 'responses': Map<String, String>}` |
| `ComponentIds.pvtTest` (`pvt_test`) | 04 | `PvtTestViewModel` | `component_id`, `title`, `astronaut_id`, `trial_count`, `min_stimulus_delay_ms`, `max_stimulus_delay_ms`, `false_start_threshold_ms`, `lapse_threshold_ms`, `last_lrm50_ms?`, `last_lapses?`, `last_fatigue_level?` | `{'reaction_times_ms': List<num>, 'completed': bool}` |
| `ComponentIds.mptTest` (`mpt_test`) | 04 | `MptTestViewModel` | `component_id`, `title`, `astronaut_id`, `target_count`, `tolerance_mm`, `last_hit_accuracy_percent?`, `last_path_deviation_mm?`, `last_motor_status?` | `{'targets_hit': int, 'total_targets': int, 'path_deviations_mm': List<num>, 'completed': bool}` |
| `ComponentIds.sansGrid` (`sans_grid`) | 03 | `SansGridViewModel` | `component_id`, `title`, `astronaut_id`, `instruction`, `metamorphopsia_reported` (`bool`), `scotoma_reported` (`bool`), `affected_quadrant?` | `{'metamorphopsia_reported': bool, 'scotoma_reported': bool, 'affected_quadrant'?: String}` |
| `ComponentIds.sansContrast` (`sans_contrast`) | 03 | `SansContrastViewModel` | `component_id`, `title`, `astronaut_id`, `instruction`, `contrast_log_cs?`, `contrast_loss` (`bool`) | `{'contrast_log_cs': double, 'contrast_loss': bool}` |
| `ComponentIds.sansFocus` (`sans_focus`) | 03 | `SansFocusViewModel` | `component_id`, `title`, `astronaut_id`, `instruction`, `near_focus_cm?`, `estimated_diopters?` | `{'near_focus_cm': double}` |
| `ComponentIds.exerciseMonitor` (`exercise_monitor`) | 03 | `ExerciseMonitorViewModel` | `component_id`, `title`, `astronaut_id`, `device_name`, `modality`, `duration_minutes`, `calories_burned`, `target_reached`, `heart_rate`, `systolic_bp`, `spo2`, `status`, `unsafe_vitals`, `alerts`, `guidance` | Display-only |
| `ComponentIds.lbnpRamp` (`lbnp_ramp`) | 03 | `LbnpRampViewModel` | `component_id`, `title`, `astronaut_id`, `phase`, `pressure_mmhg`, `phase_duration_minutes`, `instruction`, `abort_pending`, `emergency_release`, `supine_fluid_load_alert`, `alerts`, `last_systolic_bp?`, `last_hr_drop_bpm?` | `{'action': 'advance'\|'abort'\|'emergency_abort', 'seal_checked'?: bool, 'systolic_bp'?: double, 'hr_drop_bpm'?: double, 'emergency_syncope'?: bool}` |
| `ComponentIds.ultrasoundGuide` (`ultrasound_guide`) | 03 | `UltrasoundGuideViewModel` | `component_id`, `title`, `astronaut_id`, `step`, `acoustic_window_ok`, `hydronephrosis_present`, `stone_shadow_present`, `residual_bladder_volume_ml?`, `urinary_retention_risk`, `findings`, `instruction` | `{'action'?: 'next_step', 'step'?: String, 'acoustic_window_ok'?: bool, 'hydronephrosis_present'?: bool, 'stone_shadow_present'?: bool, 'bladder_width_cm'?: double, 'bladder_height_cm'?: double, 'bladder_length_cm'?: double, 'completed'?: bool}` |
| `ComponentIds.diaryRecorder` (`diary_recorder`) | 04 | `DiaryRecorderViewModel` | `component_id`, `title`, `astronaut_id`, `prompts` (`List<String>`), `max_duration_seconds`, `sleep_hours_last_night?`, `morning_mood?` | `{'transcript': String, 'completed': bool, 'words_per_minute'?: double, 'pause_ratio'?: double, 'mean_pause_ms'?: double, 'pitch_monotony'?: double}` |
| `ComponentIds.recommendations` (`recommendations`) | 04 | `RecommendationsViewModel` | `component_id`, `title`, `astronaut_id`, `risk_level`, `central_fatigue_detected`, `detected_markers`, `sleep_hours`, `recommendations` (`[{category, title, action, rationale, priority}]`), `summary` | Display-only |
| `ComponentIds.confirmAction` (`confirm_action`) | Core | `GenericComponentViewModel` | `title?`, `id` (or `action_id`), `description`, `astronaut_id?`, `action_type?`, `payload?` | `{'decision': 'confirmed'\|'rejected', 'action_id'?: String, 'reason'?: String}` |

---

## 4. Plugging Module 05 (`05_clinical_triage`) into Providers

To register Module 05 skills (`readiness`) and typed specs (`eva_readiness`) without tight coupling:

```dart
ProviderScope(
  overrides: [
    extraAgentSkillsProvider.overrideWithValue(clinicalTriageSkills()),
    extraComponentSpecsProvider.overrideWithValue({
      ComponentIds.evaReadiness: ComponentSpec<EvaReadinessViewModel>(
        id: ComponentIds.evaReadiness,
        fromProps: EvaReadinessViewModel.fromProps,
      ),
    }),
  ],
  child: const AstraMedApp(),
)
```
