import '../../../agent/presentation/component_widget_registry.dart';
import '../../../agent/domain/agent_contracts.dart';
import '../../../agent/domain/guided_assessment_catalog.dart';
import '../../agent/graybiel_engine.dart';
import '../../agent/procedures_engine.dart';
import 'zero_g_horizon_card.dart';
import 'dva_gaze_card.dart';
import 'graybiel_card.dart';
import 'sans_cockpit_cards.dart';
import 'clinical_cockpit_cards.dart';

/// Shared interactive surfaces used by both the agent canvas and legacy tab.
Map<String, AgentComponentWidgetBuilder> buildApoloCockpitComponentOverrides() {
  return {
    MicrogravityCockpitIds.zeroGHorizon: (_, vm, submit, dismiss) =>
      ZeroGHorizonCard(onSubmit: submit, onDismiss: dismiss),
    MicrogravityCockpitIds.dvaGaze: (_, vm, submit, dismiss) =>
      DvaGazeCard(onSubmit: submit, onDismiss: dismiss),
    ComponentIds.graybielQuestionnaire: (_, vm, submit, dismiss) {
      final model = GraybielQuestionnaireViewModel.fromProps(vm.toProps());
      return GraybielCard(onSubmit: submit, onDismiss: dismiss,
        initialResponses: model.responses, initialEmesis: model.emesis);
    },
    ComponentIds.sansGrid: (_, vm, submit, dismiss) =>
      StarfieldDistortionCard(onSubmit: submit, onDismiss: dismiss),
    ComponentIds.sansFocus: (_, vm, submit, dismiss) =>
      NearPointDiopterCard(onSubmit: submit, onDismiss: dismiss,
        baselineCm: (vm.toProps()['baseline_near_point_cm'] as num?)?.toDouble() ?? 25),
    ComponentIds.sansContrast: (_, vm, submit, dismiss) =>
      SansContrastCard(onSubmit: submit, onDismiss: dismiss),
    ComponentIds.lbnpRamp: (_, vm, submit, dismiss) =>
      LbnpRampCard(onSubmit: submit, onDismiss: dismiss,
        initialState: LbnpRampViewModel.fromProps(vm.toProps()).state),
    ComponentIds.exerciseMonitor: (_, vm, submit, dismiss) =>
      ExerciseMonitorCard(onSubmit: submit, onDismiss: dismiss, props: vm.toProps()),
    ComponentIds.pvtTest: (_, vm, submit, dismiss) =>
      PvtTestCard(onSubmit: submit, onDismiss: dismiss),
    ComponentIds.mptTest: (_, vm, submit, dismiss) =>
      MptTestCard(onSubmit: submit, onDismiss: dismiss),
    ComponentIds.diaryRecorder: (_, vm, submit, dismiss) =>
      DiaryRecorderCard(onSubmit: submit, onDismiss: dismiss),
    ComponentIds.ultrasoundGuide: (_, vm, submit, dismiss) =>
      UltrasoundGuideCard(onSubmit: submit, onDismiss: dismiss),
  };
}
