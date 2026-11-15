import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;

import '../../01_general_health/agent/general_health_skills.dart';
import '../../01_general_health/agent/scientific_telemetry_agent_skill.dart';
import '../../01_general_health/domain/telemetry_view_contracts.dart';
import '../../02_radiation/agent/donki_space_weather_service.dart';
import '../../02_radiation/agent/radiation_agent_skills.dart';
import '../../02_radiation/agent/radiation_health_skills.dart';
import '../../03_microgravity/agent/exercise_guidance_engine.dart';
import '../../03_microgravity/agent/graybiel_engine.dart';
import '../../03_microgravity/agent/microgravity_skills.dart';
import '../../03_microgravity/agent/procedures_engine.dart';
import '../../03_microgravity/agent/sans_engine.dart';
import '../../04_mental_health/agent/mental_health_skills.dart';
import '../../05_clinical_triage/agent/proactive_monitor.dart';
import '../../05_clinical_triage/agent/triage_agent_skills.dart';
import '../../05_clinical_triage/domain/hybrid_llm_triage_service.dart';
import '../../apolo/providers/apolo_providers.dart';
import '../../crew/presentation/providers/crew_provider.dart';
import '../../pharmacy/data/asset_pharmacy_inventory_repository.dart';
import '../../pharmacy/domain/deterministic_medication_safety.dart';
import '../../pharmacy/domain/pharmacy_inventory_repository.dart';
import '../application/agent_conversation_controller.dart';
import '../application/component_registry.dart';
import '../application/core_tools.dart';
import '../application/hands_free_controller.dart';
import '../application/skill_registry.dart';
import '../data/agent_api_client.dart';
import '../data/local_speech_to_text_service.dart';
import '../data/local_text_to_speech_service.dart';
import '../data/persistence/agent_hive_boxes.dart';
import '../data/persistence/confirmation_gate_impl.dart';
import '../data/persistence/hive_audit_log.dart';
import '../data/persistence/hive_flags_store.dart';
import '../data/persistence/hive_memory_store.dart';
import '../data/remote_speech_to_text_service.dart';
import '../data/remote_text_to_speech_service.dart';
import '../data/resilient_agent_services.dart';
import '../domain/agent_config.dart';
import '../domain/agent_contracts.dart';
import '../domain/agent_models.dart';
import '../domain/agent_ports.dart';
import '../presentation/component_widget_registry.dart';

class MissionContextMetadata {
  const MissionContextMetadata({
    this.missionName = 'Artemis Deep Space Transit',
    this.missionDay = 14,
    this.gravityLabel = '0.00 g · Microgravity',
    this.earthLatencyLabel = '12.4 min OWLT',
  });

  final String missionName;
  final int missionDay;
  final String gravityLabel;
  final String earthLatencyLabel;
}

final missionContextProvider = Provider<MissionContextMetadata>(
  (ref) => const MissionContextMetadata(),
);

final agentConfigProvider = Provider<AgentConfig>(
  (ref) => const AgentConfig.fromEnvironment(),
);

final httpClientProvider = Provider<http.Client>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
});

final agentApiClientProvider = Provider<AgentApiClient>((ref) {
  final config = ref.watch(agentConfigProvider);
  final client = ref.watch(httpClientProvider);
  return AgentApiClient(config: config, client: client);
});

final audioCapturePortProvider = Provider<AudioCapturePort>(
  (ref) => RecordAudioCapture(),
);

final remoteSpeechToTextProvider = Provider<SpeechToTextService>((ref) {
  final service = RemoteSpeechToTextService(
    client: ref.watch(agentApiClientProvider),
    capture: ref.watch(audioCapturePortProvider),
  );
  ref.onDispose(service.dispose);
  return service;
});

final localSpeechToTextProvider = Provider<SpeechToTextService>((ref) {
  final service = LocalSpeechToTextService();
  ref.onDispose(service.dispose);
  return service;
});

final speechToTextServiceProvider = Provider<SpeechToTextService>((ref) {
  final config = ref.watch(agentConfigProvider);
  return ResilientSpeechToTextService(
    remote: ref.watch(remoteSpeechToTextProvider),
    local: ref.watch(localSpeechToTextProvider),
    isRemoteConfigured: config.isConfigured,
  );
});

final remoteTextToSpeechProvider = Provider<TextToSpeechService>((ref) {
  final service = RemoteTextToSpeechService(
    client: ref.watch(agentApiClientProvider),
    playback: _CompletionAwareAudioPlayback(),
  );
  ref.onDispose(service.dispose);
  return service;
});

final localTextToSpeechProvider = Provider<TextToSpeechService>((ref) {
  final service = LocalTextToSpeechService();
  ref.onDispose(service.dispose);
  return service;
});

final textToSpeechServiceProvider = Provider<TextToSpeechService>((ref) {
  final config = ref.watch(agentConfigProvider);
  return ResilientTextToSpeechService(
    remote: ref.watch(remoteTextToSpeechProvider),
    local: ref.watch(localTextToSpeechProvider),
    isRemoteConfigured: config.isConfigured,
  );
});

final trackedTextToSpeechProvider =
    Provider<SpeakingTrackedTextToSpeechService>((ref) {
      final inner = ref.watch(textToSpeechServiceProvider);
      final tracked = SpeakingTrackedTextToSpeechService(inner: inner);
      ref.onDispose(() {
        unawaited(tracked.dispose());
      });
      return tracked;
    });

final agentVoiceRepliesEnabledProvider = StateProvider<bool>((ref) => true);

final handsFreeControllerProvider =
    StateNotifierProvider<HandsFreeController, HandsFreeState>((ref) {
      final config = ref.watch(agentConfigProvider);
      final sttService = ref.watch(speechToTextServiceProvider);
      final trackedTts = ref.watch(trackedTextToSpeechProvider);

      AudioCapturePort? capture;
      Future<String> Function(Uint8List wavBytes, {String language})?
      transcribeRemoteWav;
      ContinuousSpeechToTextService? localContinuousStt;

      if (sttService is ResilientSpeechToTextService) {
        capture = ref.watch(audioCapturePortProvider);
        final remote = ref.watch(remoteSpeechToTextProvider);
        if (remote is RemoteSpeechToTextService) {
          transcribeRemoteWav = remote.transcribeWav;
        }
        final local = ref.watch(localSpeechToTextProvider);
        if (local is ContinuousSpeechToTextService) {
          localContinuousStt = local as ContinuousSpeechToTextService;
        }
      } else {
        if (sttService is AudioCapturePort) {
          capture = sttService as AudioCapturePort;
        }
        if (sttService is ContinuousSpeechToTextService) {
          localContinuousStt = sttService as ContinuousSpeechToTextService;
        }
      }

      return HandsFreeController(
        capture: capture,
        transcribeRemoteWav: transcribeRemoteWav,
        localContinuousStt: localContinuousStt,
        isRemoteConfigured: config.isConfigured,
        speakingSignal: trackedTts,
        onTranscript: (transcript) async {
          final speakReply = ref.read(agentVoiceRepliesEnabledProvider);
          await ref
              .read(agentOrchestratorProvider.notifier)
              .sendUserMessage(transcript, speakReply: speakReply);
        },
      );
    });

final agentChatServiceProvider = Provider<AgentChatService>((ref) {
  final config = ref.watch(agentConfigProvider);
  return ResilientAgentChatService(
    remote: ref.watch(agentApiClientProvider),
    isRemoteConfigured: config.isConfigured,
  );
});

final agentHealthProvider = FutureProvider<HealthStatus>((ref) {
  return ref.watch(agentApiClientProvider).health();
});

final agentHiveBoxesProvider = Provider<AgentHiveBoxes?>((ref) {
  if (Hive.isBoxOpen(AgentHiveBoxes.memoryBoxName) &&
      Hive.isBoxOpen(AgentHiveBoxes.auditBoxName) &&
      Hive.isBoxOpen(AgentHiveBoxes.flagsBoxName)) {
    return AgentHiveBoxes(
      memoryBox: Hive.box<dynamic>(AgentHiveBoxes.memoryBoxName),
      auditBox: Hive.box<dynamic>(AgentHiveBoxes.auditBoxName),
      flagsBox: Hive.box<dynamic>(AgentHiveBoxes.flagsBoxName),
    );
  }
  return null;
});

final agentMemoryStoreProvider = Provider<MemoryStore>((ref) {
  final boxes = ref.watch(agentHiveBoxesProvider);
  if (boxes != null) {
    return HiveMemoryStore(boxes.memoryBox);
  }
  return _InMemoryMemoryStore();
});

final agentAuditLogProvider = Provider<AuditLog>((ref) {
  final boxes = ref.watch(agentHiveBoxesProvider);
  if (boxes != null) {
    return HiveAuditLog(boxes.auditBox);
  }
  return _InMemoryAuditLog();
});

final agentFlagsStoreProvider = Provider<AgentFlagsStore>((ref) {
  final boxes = ref.watch(agentHiveBoxesProvider);
  if (boxes != null) {
    return HiveFlagsStore(boxes.flagsBox);
  }
  return _InMemoryAgentFlagsStore();
});

final pharmacyInventoryRepositoryProvider =
    Provider<PharmacyInventoryRepository>((ref) {
      return AssetPharmacyInventoryRepository();
    });

final donkiSpaceWeatherServiceProvider = Provider<DonkiSpaceWeatherService>(
  (ref) => DonkiSpaceWeatherService(client: ref.watch(httpClientProvider)),
);

final medicationSafetyProvider = Provider<MedicationSafety>((ref) {
  return DeterministicMedicationSafety(
    repository: ref.watch(pharmacyInventoryRepositoryProvider),
    flags: ref.watch(agentFlagsStoreProvider),
  );
});

final operationalEnvironmentProvider = StateProvider<SpaceOperationalEnvironment>(
  (ref) => SpaceOperationalEnvironment.spaceStation,
);

final hybridAiConfigProvider = StateProvider<HybridAiConfig>(
  (ref) => const HybridAiConfig(),
);

final hybridLlmTriageServiceProvider = Provider<HybridLlmTriageService>(
  (ref) => HybridLlmTriageService(httpClient: ref.watch(httpClientProvider)),
);

final extraAgentSkillsProvider = Provider<List<AgentSkill>>(
  (ref) => scientificTelemetryAgentSkills(),
);

final extraComponentSpecsProvider =
    Provider<Map<String, ComponentSpec<AgentViewModel>>>((ref) => const {});

final componentWidgetOverridesProvider =
    Provider<Map<String, AgentComponentWidgetBuilder>>((ref) => const {});

final skillRegistryProvider = Provider<SkillRegistry>((ref) {
  final weather = ref.watch(donkiSpaceWeatherServiceProvider);
  final pharmacyRepo = ref.watch(pharmacyInventoryRepositoryProvider);
  final extraSkills = ref.watch(extraAgentSkillsProvider);
  final apoloSkill = ref.watch(apoloUrineSkillProvider);

  return SkillRegistry([
    coreSkill(),
    ...generalHealthSkills(),
    ...radiationAndPharmacySkills(
      spaceWeatherService: weather,
      pharmacyRepository: pharmacyRepo,
    ),
    radiationHealthSkill(),
    ...microgravitySkills(),
    ...mentalHealthSkills(),
    ...triageAgentSkills(),
    apoloSkill,
    ...extraSkills,
  ]);
});

final componentRegistryProvider = Provider<ComponentRegistry>((ref) {
  final extraSpecs = ref.watch(extraComponentSpecsProvider);
  final registry = ComponentRegistry();

  // Module 01: General Health
  registry.register(
    ComponentSpec<StatusReportViewModel>(
      id: ComponentIds.statusReport,
      fromProps: StatusReportViewModel.fromProps,
    ),
  );
  registry.register(
    ComponentSpec<AlertBannerViewModel>(
      id: ComponentIds.alertBanner,
      fromProps: _adaptAlertBannerProps,
    ),
  );
  registry.register(
    ComponentSpec<VitalsCardViewModel>(
      id: ComponentIds.vitalsCard,
      fromProps: _adaptVitalsCardProps,
    ),
  );
  registry.register(
    ComponentSpec<TelemetryChartViewModel>(
      id: ComponentIds.telemetryChart,
      fromProps: _adaptTelemetryChartProps,
    ),
  );

  // Module 02: Radiation & Pharmacy
  registry.register(
    ComponentSpec<SpaceWeatherAlertViewModel>(
      id: ComponentIds.spaceWeatherAlert,
      fromProps: SpaceWeatherAlertViewModel.fromProps,
    ),
  );
  registry.register(
    ComponentSpec<PharmacyBatchesViewModel>(
      id: ComponentIds.pharmacyBatches,
      fromProps: PharmacyBatchesViewModel.fromProps,
    ),
  );
  registry.register(
    ComponentSpec<RamanRequestViewModel>(
      id: ComponentIds.ramanRequest,
      fromProps: RamanRequestViewModel.fromProps,
    ),
  );
  registry.register(
    ComponentSpec<MedicationCheckViewModel>(
      id: ComponentIds.medicationCheck,
      fromProps: _adaptMedicationCheckProps,
    ),
  );

  // Module 03: Microgravity
  registry.register(
    ComponentSpec<GraybielQuestionnaireViewModel>(
      id: ComponentIds.graybielQuestionnaire,
      fromProps: GraybielQuestionnaireViewModel.fromProps,
    ),
  );
  registry.register(
    ComponentSpec<SansGridViewModel>(
      id: ComponentIds.sansGrid,
      fromProps: SansGridViewModel.fromProps,
    ),
  );
  registry.register(
    ComponentSpec<SansContrastViewModel>(
      id: ComponentIds.sansContrast,
      fromProps: SansContrastViewModel.fromProps,
    ),
  );
  registry.register(
    ComponentSpec<SansFocusViewModel>(
      id: ComponentIds.sansFocus,
      fromProps: SansFocusViewModel.fromProps,
    ),
  );
  registry.register(
    ComponentSpec<ExerciseMonitorViewModel>(
      id: ComponentIds.exerciseMonitor,
      fromProps: ExerciseMonitorViewModel.fromProps,
    ),
  );
  registry.register(
    ComponentSpec<LbnpRampViewModel>(
      id: ComponentIds.lbnpRamp,
      fromProps: LbnpRampViewModel.fromProps,
    ),
  );
  registry.register(
    ComponentSpec<UltrasoundGuideViewModel>(
      id: ComponentIds.ultrasoundGuide,
      fromProps: UltrasoundGuideViewModel.fromProps,
    ),
  );

  // Module 04: Mental Health
  registry.register(
    ComponentSpec<PvtTestViewModel>(
      id: ComponentIds.pvtTest,
      fromProps: PvtTestViewModel.fromProps,
    ),
  );
  registry.register(
    ComponentSpec<MptTestViewModel>(
      id: ComponentIds.mptTest,
      fromProps: MptTestViewModel.fromProps,
    ),
  );
  registry.register(
    ComponentSpec<DiaryRecorderViewModel>(
      id: ComponentIds.diaryRecorder,
      fromProps: DiaryRecorderViewModel.fromProps,
    ),
  );
  registry.register(
    ComponentSpec<RecommendationsViewModel>(
      id: ComponentIds.recommendations,
      fromProps: RecommendationsViewModel.fromProps,
    ),
  );

  // Module 05: Clinical Triage & Operational Readiness
  registry.register(
    ComponentSpec<EvaReadinessViewModel>(
      id: ComponentIds.evaReadiness,
      fromProps: EvaReadinessViewModel.fromProps,
    ),
  );

  for (final spec in extraSpecs.values) {
    registry.register(spec);
  }

  return registry;
});

final componentWidgetRegistryProvider = Provider<AgentComponentWidgetRegistry>((
  ref,
) {
  final overrides = ref.watch(componentWidgetOverridesProvider);
  return AgentComponentWidgetRegistry(overrides: overrides);
});

final _delegatingUiSinkProvider = Provider<_DelegatingUiSink>((ref) {
  return _DelegatingUiSink();
});

final agentConfirmationGateProvider = Provider<ConfirmationGate>((ref) {
  final auditLog = ref.watch(agentAuditLogProvider);
  final uiSink = ref.watch(_delegatingUiSinkProvider);
  return ConfirmationGateImpl(auditLog: auditLog, uiSink: uiSink);
});

final proactiveAlertStoreProvider = Provider<ProactiveAlertStore>(
  (ref) => ProactiveAlertStore(),
);

final agentOrchestratorProvider =
    StateNotifierProvider<AgentConversationController, AgentSessionState>((
      ref,
    ) {
      final chat = ref.watch(agentChatServiceProvider);
      final tts = ref.watch(trackedTextToSpeechProvider);
      final skillRegistry = ref.watch(skillRegistryProvider);
      final componentRegistry = ref.watch(componentRegistryProvider);
      final memory = ref.watch(agentMemoryStoreProvider);
      final audit = ref.watch(agentAuditLogProvider);
      final flags = ref.watch(agentFlagsStoreProvider);
      final medication = ref.watch(medicationSafetyProvider);
      final baseGate = ref.watch(agentConfirmationGateProvider);
      final delegatingSink = ref.watch(_delegatingUiSinkProvider);
      final initialAstronautId = ref.read(selectedAstronautIdProvider);
      final alertStore = ref.watch(proactiveAlertStoreProvider);

      late final AgentConversationController controller;
      final syncedGate = _ControllerSyncConfirmationGate(
        inner: baseGate,
        onPendingChanged: (pending) =>
            controller.orchestrator.syncPendingAction(pending),
      );

      controller = AgentConversationController(
        chat: chat,
        tts: tts,
        skillRegistry: skillRegistry,
        componentRegistry: componentRegistry,
        initialAstronautId: initialAstronautId,
        alertStore: alertStore,
        contextFactory: (astronautId, ui) {
          delegatingSink.delegate = ui;
          return ToolContext(
            astronautId: astronautId,
            read: <T>(provider) => ref.read(provider as ProviderListenable<T>),
            ui: ui,
            confirm: syncedGate,
            audit: audit,
            memory: memory,
            flags: flags,
            medication: medication,
          );
        },
      );
      ref.onDispose(() {
        unawaited(controller.closeSession());
      });
      return controller;
    });

final agentNotifierProvider = Provider<InAppAgentNotifier>((ref) {
  final notifier = InAppAgentNotifier();
  ref.onDispose(notifier.dispose);
  return notifier;
});

final proactiveMonitorProvider = Provider<ProactiveMonitor>((ref) {
  final notifier = ref.watch(agentNotifierProvider);
  final controller = ref.watch(agentOrchestratorProvider.notifier);
  final flags = ref.watch(agentFlagsStoreProvider);
  final memory = ref.watch(agentMemoryStoreProvider);
  final weather = ref.watch(donkiSpaceWeatherServiceProvider);
  final alertStore = ref.watch(proactiveAlertStoreProvider);

  final monitor = ProactiveMonitor(
    notifier: notifier,
    alertStore: alertStore,
    orchestrator: controller.orchestrator,
    crewReader: () => ref.read(crewMembersProvider),
    spaceWeatherReader: weather.fetchLatest,
    flagsReader: flags.allForAstronaut,
    memoryReader: (astronautId) => memory.recall(astronautId, limit: 20),
  );
  ref.listen<List<dynamic>>(crewMembersProvider, (previous, next) {
    if (previous != null) {
      unawaited(monitor.tick());
    }
  });
  ref.onDispose(monitor.dispose);
  return monitor;
});

VitalsCardViewModel _adaptVitalsCardProps(Map<String, dynamic> props) {
  if (props['heart_rate'] is num &&
      props['systolic_bp'] is num &&
      props['diastolic_bp'] is num &&
      props['spo2'] is num) {
    return VitalsCardViewModel.fromProps(props);
  }
  final nested = props['vitals'];
  if (nested is Map) {
    final flattened = <String, dynamic>{
      ...Map<String, dynamic>.from(nested),
      ...props,
      if (props['astronaut_name'] == null && props['name'] != null)
        'astronaut_name': props['name'],
    };
    return VitalsCardViewModel.fromProps(flattened);
  }
  return VitalsCardViewModel.fromProps(props);
}

TelemetryChartViewModel _adaptTelemetryChartProps(Map<String, dynamic> props) {
  if (props['metric'] is String &&
      props['unit'] is String &&
      props['series'] is List) {
    return TelemetryChartViewModel.fromProps(props);
  }
  final metrics = props['metrics'];
  final logs = props['recent_logs'] ?? props['logs'];
  final machines = props['machines'];
  if (metrics is Map || logs is List || machines is List) {
    final series = <TelemetryDataPoint>[];
    if (metrics is Map) {
      for (final entry in metrics.entries) {
        if (entry.value is num) {
          series.add(
            TelemetryDataPoint(
              label: entry.key.toString(),
              value: (entry.value as num).toDouble(),
            ),
          );
        }
      }
    }
    return TelemetryChartViewModel(
      title: props['title'] as String? ?? 'Telemetry',
      metric: props['metric'] as String? ?? 'live_telemetry',
      unit: props['unit'] as String? ?? '',
      astronautId: props['astronaut_id'] as String? ?? 'CREW',
      series: series,
      summary: {
        if (machines is List) 'machines_count': machines.length,
        if (logs is List) 'logs_count': logs.length,
      },
    );
  }
  return TelemetryChartViewModel.fromProps(props);
}

AlertBannerViewModel _adaptAlertBannerProps(Map<String, dynamic> props) {
  if (props['severity'] is String &&
      props['classification'] is String &&
      props['message'] is String &&
      props['suppressed'] is bool) {
    return AlertBannerViewModel.fromProps(props);
  }
  final rawMsg = props['message'] ?? props['title'] ?? props['text'];
  if (rawMsg is! String || rawMsg.trim().isEmpty) {
    throw const FormatException('Invalid alert_banner props.');
  }
  return AlertBannerViewModel.fromProps({
    ...props,
    'message': rawMsg.trim(),
    'severity': (props['severity'] as String?) ?? 'info',
    'classification': (props['classification'] as String?) ?? 'clinical_alert',
    'suppressed': (props['suppressed'] as bool?) ?? false,
  });
}

MedicationCheckViewModel _adaptMedicationCheckProps(
  Map<String, dynamic> props,
) {
  if (props['astronaut_id'] is String && props['allowed'] is bool) {
    return MedicationCheckViewModel.fromProps(props);
  }
  if (props['authorized'] is bool && props['medication'] is String) {
    final nestedCheck = props['medication_check'];
    final nestedMap = nestedCheck is Map
        ? Map<String, dynamic>.from(nestedCheck)
        : const <String, dynamic>{};
    return MedicationCheckViewModel.fromProps({
      ...nestedMap,
      ...props,
      'astronaut_id': props['astronaut_id'] as String? ?? 'CREW',
      'allowed': props['authorized'] as bool,
      'reasons': props['reasons'] ?? const <String>[],
    });
  }
  return MedicationCheckViewModel.fromProps(props);
}

class _DelegatingUiSink implements AgentUiSink {
  AgentUiSink? delegate;

  @override
  void emit(AgentComponentEvent event) {
    delegate?.emit(event);
  }

  @override
  void submit(String componentId, Map<String, dynamic> result) {
    delegate?.submit(componentId, result);
  }
}

class _ControllerSyncConfirmationGate implements ConfirmationGate {
  _ControllerSyncConfirmationGate({
    required this.inner,
    required this.onPendingChanged,
  });

  final ConfirmationGate inner;
  final void Function(ConsequentialAction? pending) onPendingChanged;

  @override
  ConsequentialAction? get pending => inner.pending;

  @override
  Future<ConfirmationDecision> request(
    ConsequentialAction action, {
    required Future<Map<String, dynamic>> Function() onConfirmed,
  }) {
    final future = inner.request(action, onConfirmed: onConfirmed);
    onPendingChanged(inner.pending);
    return future;
  }

  @override
  Future<Map<String, dynamic>?> resolve(
    String actionId,
    ConfirmationDecision decision, {
    String? reason,
  }) async {
    final result = await inner.resolve(actionId, decision, reason: reason);
    onPendingChanged(inner.pending);
    return result;
  }
}

class _InMemoryMemoryStore implements MemoryStore {
  final List<MemoryEntry> _entries = [];

  @override
  Future<MemoryEntry> save(MemoryEntry entry) async {
    _entries.removeWhere(
      (e) => e.astronautId == entry.astronautId && e.id == entry.id,
    );
    _entries.add(entry);
    return entry;
  }

  @override
  Future<List<MemoryEntry>> recall(
    String astronautId, {
    String? query,
    Set<MemoryKind>? kinds,
    int limit = 10,
  }) async {
    final q = query?.trim().toLowerCase() ?? '';
    final filtered =
        _entries
            .where((e) => e.astronautId == astronautId)
            .where((e) => kinds == null || kinds.contains(e.kind))
            .where(
              (e) =>
                  q.isEmpty ||
                  e.summary.toLowerCase().contains(q) ||
                  e.tags.any((t) => t.toLowerCase().contains(q)),
            )
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return filtered.take(limit).toList(growable: false);
  }

  @override
  Future<List<MemoryEntry>> recentForPrompt(
    String astronautId, {
    int limit = 8,
  }) async {
    final items = _entries.where((e) => e.astronautId == astronautId).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return items.take(limit).toList(growable: false);
  }
}

class _InMemoryAuditLog implements AuditLog {
  final List<AuditEntry> _entries = [];
  final Set<String> _ids = {};

  @override
  Future<void> append(AuditEntry entry) async {
    if (_ids.contains(entry.id)) {
      throw StateError('Duplicate AuditEntry id: ${entry.id}');
    }
    _ids.add(entry.id);
    _entries.add(entry);
  }

  @override
  Future<List<AuditEntry>> list({String? astronautId, int limit = 50}) async {
    final items =
        _entries
            .where((e) => astronautId == null || e.astronautId == astronautId)
            .toList()
          ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return items.take(limit).toList(growable: false);
  }
}

class _InMemoryAgentFlagsStore implements AgentFlagsStore {
  final Map<String, Map<String, Map<String, dynamic>>> _flags = {};

  @override
  Future<void> setFlag(
    String astronautId,
    String key,
    Map<String, dynamic> value,
  ) async {
    _flags.putIfAbsent(astronautId, () => {})[key] = Map<String, dynamic>.from(
      value,
    );
  }

  @override
  Future<Map<String, dynamic>?> getFlag(String astronautId, String key) async {
    final value = _flags[astronautId]?[key];
    return value == null ? null : Map<String, dynamic>.from(value);
  }

  @override
  Future<Map<String, Map<String, dynamic>>> allForAstronaut(
    String astronautId,
  ) async {
    final map = _flags[astronautId];
    if (map == null) return const {};
    return {
      for (final entry in map.entries)
        entry.key: Map<String, dynamic>.from(entry.value),
    };
  }
}

class _CompletionAwareAudioPlayback implements AudioPlaybackPort {
  _CompletionAwareAudioPlayback();

  AudioPlayer? _player;
  Completer<void>? _activeCompleter;

  AudioPlayer get _instance => _player ??= AudioPlayer();

  Duration _estimateTimeout(Uint8List wavBytes) {
    if (wavBytes.lengthInBytes > 44) {
      final header = ByteData.sublistView(wavBytes, 0, 44);
      final byteRate = header.getUint32(28, Endian.little);
      if (byteRate > 0) {
        final seconds = ((wavBytes.lengthInBytes - 44) / byteRate).ceil() + 5;
        return Duration(seconds: math.max(10, math.min(seconds, 120)));
      }
    }
    return const Duration(seconds: 45);
  }

  void _completeActive() {
    final c = _activeCompleter;
    if (c != null && !c.isCompleted) {
      c.complete();
    }
    _activeCompleter = null;
  }

  @override
  Future<void> playWav(Uint8List wavBytes) async {
    final player = _instance;
    _completeActive();
    final completer = Completer<void>();
    _activeCompleter = completer;

    late final StreamSubscription<void> completeSub;
    late final StreamSubscription<PlayerState> stateSub;

    completeSub = player.onPlayerComplete.listen((_) {
      if (!completer.isCompleted) completer.complete();
    });
    stateSub = player.onPlayerStateChanged.listen((state) {
      if ((state == PlayerState.completed ||
              state == PlayerState.stopped ||
              state == PlayerState.disposed) &&
          !completer.isCompleted) {
        completer.complete();
      }
    });

    try {
      await player.play(BytesSource(wavBytes, mimeType: 'audio/wav'));
      await completer.future.timeout(
        _estimateTimeout(wavBytes),
        onTimeout: () {},
      );
    } finally {
      await completeSub.cancel();
      await stateSub.cancel();
      if (identical(_activeCompleter, completer)) {
        _activeCompleter = null;
      }
    }
  }

  @override
  Future<void> stop() async {
    _completeActive();
    final player = _player;
    if (player != null) {
      await player.stop();
    }
  }

  @override
  Future<void> dispose() async {
    _completeActive();
    final player = _player;
    _player = null;
    if (player != null) {
      await player.dispose();
    }
  }
}
