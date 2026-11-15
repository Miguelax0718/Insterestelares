import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:astramed/core/theme/space_theme.dart';
import 'package:astramed/features/01_general_health/domain/telemetry_view_contracts.dart';
import 'package:astramed/features/01_general_health/presentation/providers/telemetry_panel_provider.dart';
import 'package:astramed/features/05_clinical_triage/domain/apollo_triage_engine.dart';
import 'package:astramed/features/05_clinical_triage/domain/hybrid_llm_triage_service.dart';
import 'package:astramed/features/05_clinical_triage/models/triage_decision.dart';
import 'package:astramed/features/crew/models/astronaut_profile.dart';
import 'package:astramed/features/crew/presentation/providers/crew_provider.dart';

/// Configuración del motor híbrido (Local Web/Ollama -> Cloud -> ADA Offline)
final hybridAiConfigProvider = StateProvider<HybridAiConfig>((ref) {
  return const HybridAiConfig();
});

/// Indica si APOLO está procesando una consulta con el motor híbrido
final apolloIsTypingProvider = StateProvider<bool>((ref) => false);

/// Proveedor del historial de chat de APOLO
final apolloChatProvider =
    StateNotifierProvider<ApolloChatNotifier, List<ApolloChatMessage>>((ref) {
  return ApolloChatNotifier();
});

class ApolloChatNotifier extends StateNotifier<List<ApolloChatMessage>> {
  final HybridLlmTriageService _hybridService;

  ApolloChatNotifier({HybridLlmTriageService? hybridService})
      : _hybridService = hybridService ?? HybridLlmTriageService(),
        super(_initialMessages());

  static List<ApolloChatMessage> _initialMessages() {
    return [
      ApolloChatMessage(
        id: 'INIT-01',
        sender: 'apollo',
        text:
            'Saludos. Soy APOLO, tu Asistente Médico Autónomo y Sistema de Triaje Clínico.\n\nEstoy enlazado a tu telemetría biológica y a las condiciones del entorno activo. ¿Presentas algún síntoma, sospecha de intoxicación, traumatismo o consulta de salud?',
        timestamp: DateTime.now(),
        triageLevel: TriagePriority.green,
        recommendedHardware: 'Bio-Monitor CSA / Draeger Double Sensor',
        actionChecklist: const [
          'Puedes escribir tu molestia o usar los accesos directos de protocolos frecuentes abajo.',
          'En caso de dolor agudo o hemorragia, prioriza el protocolo de emergencia.',
        ],
        followUpOptions: const [
          'Cefalea y visión borrosa (SANS)',
          'Traumatismo por golpe o caída',
          'Dolor lumbar agudo (Cálculo Renal)',
          'Sensación de asfixia o bolsa de CO₂',
        ],
      ),
    ];
  }

  Future<void> sendMessage({
    required String query,
    required AstronautProfile astronaut,
    required SpaceOperationalEnvironment environment,
    required HybridAiConfig config,
    required void Function(ClinicalMissionLogEntry) onLogEntry,
  }) async {
    final now = DateTime.now();
    final userMsg = ApolloChatMessage(
      id: 'USER-${now.millisecondsSinceEpoch}',
      sender: 'astronaut',
      text: query,
      timestamp: now,
    );

    state = [...state, userMsg];

    final apolloReply = await _hybridService.evaluateQuery(
      query: query,
      astronaut: astronaut,
      environment: environment,
      config: config,
    );

    state = [...state, apolloReply];

    // Si tiene severidad moderada o crítica, se archiva de inmediato en la bitácora
    if (apolloReply.triageLevel == TriagePriority.yellow ||
        apolloReply.triageLevel == TriagePriority.red) {
      onLogEntry(
        ClinicalMissionLogEntry(
          id: 'APOLLO-LOG-${now.millisecondsSinceEpoch}',
          astronautId: astronaut.id,
          timestamp: now,
          missionDay: astronaut.vitals.missionDay,
          environment: environment,
          category: 'Triaje APOLO: ${apolloReply.triageLevel?.name.toUpperCase()}',
          title: 'Evaluación APOLO: "$query"',
          summary: apolloReply.text.split('\n\n').first,
          answers: {
            'Consulta del tripulante': query,
            'Severidad': apolloReply.triageLevel?.name ?? 'normal',
            if (apolloReply.recommendedHardware != null)
              'Hardware sugerido': apolloReply.recommendedHardware!,
          },
          badgeEarned: apolloReply.triageLevel == TriagePriority.red
              ? 'Intervención Oportuna'
              : 'Vigilancia Nominal',
          xpAwarded: 45,
        ),
      );
    }
  }

  void resetChat() {
    state = _initialMessages();
  }
}

class TriageView extends ConsumerStatefulWidget {
  const TriageView({super.key});

  @override
  ConsumerState<TriageView> createState() => _TriageViewState();
}

class _TriageViewState extends ConsumerState<TriageView> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _handleSend(String query) async {
    final text = query.trim();
    if (text.isEmpty || ref.read(apolloIsTypingProvider)) return;

    final astronaut = ref.read(selectedAstronautProvider);
    final environment = ref.read(selectedEnvironmentProvider);
    final aiConfig = ref.read(hybridAiConfigProvider);

    _inputController.clear();
    ref.read(apolloIsTypingProvider.notifier).state = true;
    _scrollToBottom();

    try {
      await ref.read(apolloChatProvider.notifier).sendMessage(
            query: text,
            astronaut: astronaut,
            environment: environment,
            config: aiConfig,
            onLogEntry: (entry) {
              ref.read(clinicalMissionLogsProvider.notifier).addEntry(entry);
            },
          );
    } finally {
      if (mounted) {
        ref.read(apolloIsTypingProvider.notifier).state = false;
        _scrollToBottom();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final astronaut = ref.watch(selectedAstronautProvider);
    final environment = ref.watch(selectedEnvironmentProvider);
    final chatMessages = ref.watch(apolloChatProvider);
    final isCritical = astronaut.riskLevel == CrewRiskLevel.critical;

    return Column(
      children: [
        // ── CABECERA Y CONTEXTO DEL ENTORNO DE APOLO ──
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: SpaceTheme.surface,
            border: const Border(
              bottom: BorderSide(color: Colors.white12),
            ),
          ),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: SpaceTheme.cyan.withValues(alpha: 0.2),
                radius: 18,
                child: const Icon(Icons.smart_toy, color: SpaceTheme.cyan, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'APOLO • Asistente Médico de Triaje',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Color(environment.accentHex).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Color(environment.accentHex)),
                          ),
                          child: Text(
                            environment.shortLabel,
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: Color(environment.accentHex),
                            ),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      'Paciente: ${astronaut.name} [${astronaut.callsign}] • FC: ${astronaut.vitals.heartRate.toInt()} lpm • SpO₂: ${astronaut.vitals.spO2.toInt()}%',
                      style: const TextStyle(fontSize: 11, color: Colors.white60),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Configurar IA Híbrida (Local Web / Cloud / ADA Offline)',
                icon: const Icon(Icons.memory, color: SpaceTheme.cyan, size: 20),
                onPressed: () => _showHybridAiConfigDialog(context),
              ),
              IconButton(
                tooltip: 'Reiniciar conversación',
                icon: const Icon(Icons.refresh, color: Colors.white54, size: 20),
                onPressed: () => ref.read(apolloChatProvider.notifier).resetChat(),
              ),
            ],
          ),
        ),

        // ── BANNER DE ALERTA CRÍTICA SI PROCEDE ──
        if (isCritical)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            color: SpaceTheme.dangerRed.withValues(alpha: 0.18),
            child: Row(
              children: [
                const Icon(Icons.warning, color: SpaceTheme.dangerRed, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Alerta en Telemetría: ${astronaut.riskDescription}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: SpaceTheme.dangerRed,
                    ),
                  ),
                ),
              ],
            ),
          ),

        // ── LISTA DE MENSAJES CONVERSACIONALES ──
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(14),
            itemCount: chatMessages.length,
            itemBuilder: (context, index) {
              final msg = chatMessages[index];
              return _buildMessageBubble(msg);
            },
          ),
        ),

        if (ref.watch(apolloIsTypingProvider))
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: SpaceTheme.cyan,
                  ),
                ),
                SizedBox(width: 8),
                Text(
                  'APOLO evaluando con Guardrail ADA + IA Híbrida...',
                  style: TextStyle(fontSize: 11, color: SpaceTheme.cyan),
                ),
              ],
            ),
          ),

        // ── BOTONES DE ACCESO RÁPIDO (PRESETS JUSTIFICADOS) ──
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          color: SpaceTheme.surface,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildQuickActionChip(
                  icon: Icons.remove_red_eye,
                  label: 'Cefalea / Visión borrosa (SANS)',
                  query: 'Tengo dolor de cabeza y noto visión borrosa al leer',
                ),
                const SizedBox(width: 6),
                _buildQuickActionChip(
                  icon: Icons.air,
                  label: 'Bolsa de CO₂ / Asfixia',
                  query: 'Siento falta de aire y sospecho bolsa de CO2 focal',
                ),
                const SizedBox(width: 6),
                _buildQuickActionChip(
                  icon: Icons.local_hospital,
                  label: 'Dolor Lumbar / Cálculo Renal',
                  query: 'Tengo un dolor lumbar agudo intermitente hacia la ingle',
                ),
                const SizedBox(width: 6),
                _buildQuickActionChip(
                  icon: Icons.healing,
                  label: 'Golpe / Trauma',
                  query: 'Sufrí un golpe biomecánico fuerte contra el mamparo',
                ),
              ],
            ),
          ),
        ),

        // ── BARRA DE ENTRADA DE TEXTO Y BOTÓN DE VOZ FUTURO ──
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: SpaceTheme.card,
            border: const Border(
              top: BorderSide(color: Colors.white12),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Entrada por Voz (Enlace futuro con APOLO Voice)',
                  icon: const Icon(Icons.mic, color: SpaceTheme.cyan),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Módulo de Voz APOLO preparado. Selecciona un preset o escribe para triaje asistido.',
                        ),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                ),
                Expanded(
                  child: TextField(
                    controller: _inputController,
                    style: const TextStyle(fontSize: 13, color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Describe síntomas o responde a APOLO...',
                      hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      filled: true,
                      fillColor: SpaceTheme.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onSubmitted: _handleSend,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send, color: SpaceTheme.cyan),
                  onPressed: () => _handleSend(_inputController.text),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActionChip({
    required IconData icon,
    required String label,
    required String query,
  }) {
    return ActionChip(
      avatar: Icon(icon, size: 14, color: SpaceTheme.cyan),
      label: Text(label, style: const TextStyle(fontSize: 11, color: Colors.white)),
      backgroundColor: SpaceTheme.card,
      side: const BorderSide(color: Colors.white12),
      visualDensity: VisualDensity.compact,
      onPressed: () => _handleSend(query),
    );
  }

  Widget _buildMessageBubble(ApolloChatMessage msg) {
    final isApollo = msg.isApollo;
    final timeStr = DateFormat('HH:mm').format(msg.timestamp);

    Color priorityColor = Colors.transparent;
    if (msg.triageLevel == TriagePriority.red) {
      priorityColor = SpaceTheme.dangerRed;
    } else if (msg.triageLevel == TriagePriority.yellow) {
      priorityColor = SpaceTheme.warningYellow;
    } else if (msg.triageLevel == TriagePriority.green) {
      priorityColor = SpaceTheme.green;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment:
            isApollo ? MainAxisAlignment.start : MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isApollo) ...[
            CircleAvatar(
              radius: 14,
              backgroundColor: SpaceTheme.cyan.withValues(alpha: 0.15),
              child: const Icon(Icons.auto_awesome, color: SpaceTheme.cyan, size: 14),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 580),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isApollo ? SpaceTheme.surface : SpaceTheme.cyan.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isApollo
                      ? (msg.triageLevel == TriagePriority.red
                          ? SpaceTheme.dangerRed
                          : Colors.white12)
                      : SpaceTheme.cyan.withValues(alpha: 0.5),
                  width: msg.triageLevel == TriagePriority.red ? 1.5 : 1.0,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        isApollo ? 'APOLO' : 'Tripulante',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isApollo ? SpaceTheme.cyan : Colors.white,
                        ),
                      ),
                      if (msg.triageLevel != null && isApollo) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: priorityColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: priorityColor),
                          ),
                          child: Text(
                            msg.triageLevel!.name.toUpperCase(),
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: priorityColor,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(width: 8),
                      Text(timeStr, style: const TextStyle(fontSize: 10, color: Colors.white38)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    msg.text,
                    style: const TextStyle(fontSize: 12, color: Colors.white, height: 1.35),
                  ),
                  if (isApollo) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: SpaceTheme.cyan.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        msg.inferenceSource,
                        style: const TextStyle(fontSize: 9, color: SpaceTheme.cyan),
                      ),
                    ),
                  ],
                  if (msg.recommendedHardware != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: SpaceTheme.card,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.biotech, color: SpaceTheme.cyan, size: 16),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Hardware: ${msg.recommendedHardware!}',
                              style: const TextStyle(fontSize: 11, color: Colors.white70),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (msg.actionChecklist != null && msg.actionChecklist!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    const Text(
                      'Pautas de Acción Inmediata:',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: SpaceTheme.cyan,
                      ),
                    ),
                    const SizedBox(height: 4),
                    ...msg.actionChecklist!.map(
                      (action) => Padding(
                        padding: const EdgeInsets.only(bottom: 3),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('• ', style: TextStyle(color: SpaceTheme.cyan)),
                            Expanded(
                              child: Text(
                                action,
                                style: const TextStyle(fontSize: 11, color: Colors.white70),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  if (msg.followUpOptions != null && msg.followUpOptions!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: msg.followUpOptions!.map((opt) {
                        return InkWell(
                          onTap: () => _handleSend(opt),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: SpaceTheme.card,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: SpaceTheme.cyan.withValues(alpha: 0.4)),
                            ),
                            child: Text(
                              '➜ $opt',
                              style: const TextStyle(fontSize: 10, color: SpaceTheme.cyan),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showHybridAiConfigDialog(BuildContext context) {
    final current = ref.read(hybridAiConfigProvider);
    bool preferLocal = current.preferLocalModel;
    final localEndpointCtrl = TextEditingController(text: current.localEndpoint);
    final localModelCtrl = TextEditingController(text: current.localModelName);
    final cloudEndpointCtrl = TextEditingController(text: current.cloudEndpoint);
    final cloudKeyCtrl = TextEditingController(text: current.cloudApiKey);

    showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              backgroundColor: SpaceTheme.surface,
              title: const Row(
                children: [
                  Icon(Icons.memory, color: SpaceTheme.cyan),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Motor Híbrido IA + ADA',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Prioridad: 1) Modelo Local Web/Edge -> 2) Fallback Nube -> 3) Motor ADA Determinista 100% Offline.',
                      style: TextStyle(fontSize: 11, color: Colors.white70),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'Priorizar Modelo Local',
                        style: TextStyle(fontSize: 13),
                      ),
                      value: preferLocal,
                      onChanged: (val) => setDialogState(() => preferLocal = val),
                    ),
                    TextField(
                      controller: localEndpointCtrl,
                      style: const TextStyle(fontSize: 12),
                      decoration: const InputDecoration(
                        labelText: 'Endpoint Local (Ollama / WebLLM)',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: localModelCtrl,
                      style: const TextStyle(fontSize: 12),
                      decoration: const InputDecoration(
                        labelText: 'Modelo Local',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: cloudEndpointCtrl,
                      style: const TextStyle(fontSize: 12),
                      decoration: const InputDecoration(
                        labelText: 'Endpoint Cloud (Fallback)',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: cloudKeyCtrl,
                      obscureText: true,
                      style: const TextStyle(fontSize: 12),
                      decoration: const InputDecoration(
                        labelText: 'API Key Cloud (opcional)',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancelar'),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: SpaceTheme.cyan,
                    foregroundColor: Colors.black,
                  ),
                  onPressed: () {
                    ref.read(hybridAiConfigProvider.notifier).state = current.copyWith(
                      preferLocalModel: preferLocal,
                      localEndpoint: localEndpointCtrl.text.trim(),
                      localModelName: localModelCtrl.text.trim(),
                      cloudEndpoint: cloudEndpointCtrl.text.trim(),
                      cloudApiKey: cloudKeyCtrl.text.trim(),
                    );
                    Navigator.of(ctx).pop();
                  },
                  child: const Text('Guardar'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
