import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:astramed/core/theme/space_theme.dart';
import 'package:astramed/features/05_clinical_triage/data/medical_procedures_data.dart';
import 'package:astramed/features/05_clinical_triage/models/triage_decision.dart';
import 'package:astramed/features/agent/presentation/agent_canvas_view.dart';
import 'package:astramed/features/agent/providers/agent_providers.dart';
import 'package:astramed/features/crew/models/astronaut_profile.dart';
import 'package:astramed/features/crew/presentation/providers/crew_provider.dart';

class TriageView extends ConsumerStatefulWidget {
  const TriageView({super.key});

  @override
  ConsumerState<TriageView> createState() => _TriageViewState();
}

class _TriageViewState extends ConsumerState<TriageView> {
  String? _selectedSituationId;
  List<MedicalProcedure> _procedures = MedicalProceduresData.getProcedures();
  List<ClinicalScenario> _scenarios = MedicalProceduresData.getScenarios();

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      await _loadDbCatalog();
      if (!mounted) return;
      _consumePendingProcedure();
    });
  }

  Future<void> _loadDbCatalog() async {
    final procs = await MedicalProceduresData.loadProceduresFromDb();
    final scens = await MedicalProceduresData.loadScenariosFromDb();
    if (!mounted) return;
    setState(() {
      _procedures = procs;
      _scenarios = scens;
    });
  }

  void _consumePendingProcedure() {
    final pendingId = ref.read(pendingProcedureSelectionProvider);
    if (pendingId != null && pendingId.isNotEmpty) {
      _openProcedureById(pendingId);
    }
  }

  void _openProcedureById(String procedureId) {
    final proc = MedicalProceduresData.findById(procedureId, _procedures);
    ref.read(pendingProcedureSelectionProvider.notifier).state = null;
    if (proc != null && mounted) {
      _showProcedureDetailSheet(context, proc);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<String?>(pendingProcedureSelectionProvider, (_, nextId) {
      if (nextId == null || nextId.isEmpty) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _openProcedureById(nextId);
      });
    });

    final astronaut = ref.watch(selectedAstronautProvider);
    final suggestions = MedicalProceduresData.suggestProceduresForAstronaut(
      astronaut,
      simulatedSituationId: _selectedSituationId,
      catalog: _procedures,
      scenarios: _scenarios,
    );
    final primarySuggestion = suggestions.first;
    final secondarySuggestions = suggestions.skip(1).toList();
    final isCritical = astronaut.riskLevel == CrewRiskLevel.critical ||
        primarySuggestion.procedure.priority == TriagePriority.red;

    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        _buildHeader(astronaut),
        const SizedBox(height: 14),
        if (isCritical) ...[
          _buildCriticalAlertBanner(context, astronaut, primarySuggestion),
          const SizedBox(height: 14),
        ],
        _buildRecommendedProcedureCard(
          context,
          primarySuggestion,
          secondarySuggestions,
        ),
        const SizedBox(height: 16),
        _buildGuidedSelfDiagnosisCard(context, astronaut),
        const SizedBox(height: 16),
        _buildSituationSelectorCard(),
        const SizedBox(height: 18),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'Protocolos Médicos en DB (${_procedures.length})',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            const Text(
              '100% Offline',
              style: TextStyle(
                fontSize: 11,
                color: SpaceTheme.cyan,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ..._procedures.map((proc) => _buildProtocolTile(context, proc)),
      ],
    );
  }

  Widget _buildHeader(AstronautProfile astronaut) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Triage Clínico y Procedimientos',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Text(
                'Paciente activo: ${astronaut.name} [${astronaut.callsign}]',
                style: const TextStyle(fontSize: 12, color: SpaceTheme.cyan),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCriticalAlertBanner(
    BuildContext context,
    AstronautProfile astronaut,
    ProcedureSuggestion primarySuggestion,
  ) {
    final proc = primarySuggestion.procedure;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: SpaceTheme.dangerRed.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: SpaceTheme.dangerRed, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.emergency, color: SpaceTheme.dangerRed, size: 22),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'INTERVENCIÓN PRIORITARIA REQUERIDA',
                  style: TextStyle(
                    color: SpaceTheme.dangerRed,
                    fontWeight: FontWeight.bold,
                    fontSize: 13.5,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _selectedSituationId != null
                ? primarySuggestion.reason
                : astronaut.riskDescription,
            style: const TextStyle(color: Colors.white, fontSize: 12.5),
          ),
          const SizedBox(height: 10),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: SpaceTheme.dangerRed,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 38),
            ),
            icon: const Icon(Icons.medical_services, size: 18),
            label: Text(
              'Abrir: ${proc.title}',
              overflow: TextOverflow.ellipsis,
            ),
            onPressed: () => _showProcedureDetailSheet(context, proc),
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendedProcedureCard(
    BuildContext context,
    ProcedureSuggestion primary,
    List<ProcedureSuggestion> secondary,
  ) {
    final proc = primary.procedure;
    final priorityColor = _getPriorityColor(proc.priority);

    return Card(
      color: SpaceTheme.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: priorityColor.withValues(alpha: 0.7),
          width: 1.4,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _getCategoryIcon(proc.category),
                  color: priorityColor,
                  size: 22,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Procedimiento Sugerido',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: SpaceTheme.cyan,
                    ),
                  ),
                ),
                _buildPriorityBadge(proc.priority),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              proc.title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              primary.reason,
              style: const TextStyle(fontSize: 12.5, color: Colors.white70),
            ),
            if (proc.steps.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: SpaceTheme.background,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Acción inmediata (Paso 1):',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: SpaceTheme.cyan,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      proc.steps.first.action,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: SpaceTheme.cyan,
                  foregroundColor: Colors.black,
                ),
                icon: const Icon(Icons.assignment_turned_in, size: 18),
                label: const Text(
                  'Ver Procedimiento Paso a Paso',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                onPressed: () => _showProcedureDetailSheet(context, proc),
              ),
            ),
            if (secondary.isNotEmpty) ...[
              const SizedBox(height: 10),
              const Text(
                'Otras sugerencias por telemetría:',
                style: TextStyle(fontSize: 11, color: Colors.white54),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: secondary.map((s) {
                  return ActionChip(
                    backgroundColor: SpaceTheme.background,
                    side: BorderSide(
                      color: _getPriorityColor(s.procedure.priority)
                          .withValues(alpha: 0.5),
                    ),
                    label: Text(
                      s.procedure.title,
                      style: const TextStyle(fontSize: 11, color: Colors.white),
                    ),
                    onPressed: () =>
                        _showProcedureDetailSheet(context, s.procedure),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildGuidedSelfDiagnosisCard(
    BuildContext context,
    AstronautProfile astronaut,
  ) {
    return Card(
      color: SpaceTheme.card,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.health_and_safety, color: Colors.greenAccent),
                SizedBox(width: 8),
                Text(
                  'Autodiagnóstico Guiado por Síntomas',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Evalúa a ${astronaut.name} respondiendo preguntas clínicas escalonadas para recibir clasificación determinista (Verde, Amarillo, Rojo).',
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const AgentCanvasView(),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: SpaceTheme.cyan,
                foregroundColor: Colors.black,
              ),
              icon: const Icon(Icons.play_arrow),
              label: const Text('Comenzar Evaluación Clínica'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSituationSelectorCard() {
    return Card(
      color: SpaceTheme.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Colors.white12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.help_outline, color: SpaceTheme.cyan, size: 19),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '¿Qué situación ocurre?',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Selecciona una situación para ver el procedimiento adecuado o evalúa con la telemetría actual.',
              style: TextStyle(fontSize: 12, color: Colors.white70),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  selected: _selectedSituationId == null,
                  selectedColor: SpaceTheme.cyan.withValues(alpha: 0.22),
                  backgroundColor: SpaceTheme.background,
                  side: BorderSide(
                    color: _selectedSituationId == null
                        ? SpaceTheme.cyan
                        : Colors.white12,
                  ),
                  label: Text(
                    'Evaluar según Telemetría Actual',
                    style: TextStyle(
                      fontSize: 12,
                      color: _selectedSituationId == null
                          ? SpaceTheme.cyan
                          : Colors.white70,
                      fontWeight: _selectedSituationId == null
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                  onSelected: (_) {
                    setState(() {
                      _selectedSituationId = null;
                    });
                  },
                ),
                ..._scenarios.map((scenario) {
                  final isSelected = _selectedSituationId == scenario.id;
                  final color = _getPriorityColor(scenario.priority);
                  return ChoiceChip(
                    selected: isSelected,
                    selectedColor: color.withValues(alpha: 0.22),
                    backgroundColor: SpaceTheme.background,
                    side: BorderSide(
                      color: isSelected ? color : Colors.white12,
                    ),
                    label: Text(
                      scenario.label,
                      style: TextStyle(
                        fontSize: 12,
                        color: isSelected ? color : Colors.white,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    onSelected: (_) {
                      setState(() {
                        _selectedSituationId = scenario.id;
                      });
                    },
                  );
                }),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProtocolTile(BuildContext context, MedicalProcedure proc) {
    final color = _getPriorityColor(proc.priority);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: SpaceTheme.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Colors.white12),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.16),
          child: Icon(_getCategoryIcon(proc.category), color: color, size: 20),
        ),
        title: Text(
          proc.title,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          proc.summary,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 11.5, color: Colors.white60),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildPriorityBadge(proc.priority),
            const SizedBox(width: 6),
            const Icon(
              Icons.arrow_forward_ios,
              size: 14,
              color: Colors.white38,
            ),
          ],
        ),
        onTap: () => _showProcedureDetailSheet(context, proc),
      ),
    );
  }

  Widget _buildPriorityBadge(TriagePriority priority) {
    final color = _getPriorityColor(priority);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.55)),
      ),
      child: Text(
        _getPriorityLabel(priority),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  void _showProcedureDetailSheet(
    BuildContext context,
    MedicalProcedure proc,
  ) {
    final color = _getPriorityColor(proc.priority);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.9,
            maxWidth: 780,
          ),
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            color: SpaceTheme.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: 0.65), width: 1.5),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 10, 12),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: color.withValues(alpha: 0.18),
                      child: Icon(_getCategoryIcon(proc.category), color: color),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            proc.title,
                            style: const TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              _buildPriorityBadge(proc.priority),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  proc.code,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.white54,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Cerrar procedimiento',
                      icon: const Icon(Icons.close, color: Colors.white70),
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ],
                ),
              ),
              const Divider(color: Colors.white12, height: 1),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text(
                      proc.summary,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.white70,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 14),
                    _buildSectionTitle(
                      'Cuándo aplicar este procedimiento',
                      Icons.fact_check,
                      SpaceTheme.cyan,
                    ),
                    const SizedBox(height: 6),
                    ...proc.whenToActivate.map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '• ',
                              style: TextStyle(color: SpaceTheme.cyan),
                            ),
                            Expanded(
                              child: Text(
                                item,
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  color: Colors.white70,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _buildSectionTitle(
                      'Pasos a seguir',
                      Icons.format_list_numbered,
                      SpaceTheme.green,
                    ),
                    const SizedBox(height: 8),
                    ...proc.steps.map(
                      (s) => Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: SpaceTheme.card,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 12,
                                  backgroundColor:
                                      SpaceTheme.cyan.withValues(alpha: 0.2),
                                  child: Text(
                                    '${s.step}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: SpaceTheme.cyan,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    s.title,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13.5,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              s.action,
                              style: const TextStyle(
                                fontSize: 12.5,
                                color: Colors.white70,
                                height: 1.35,
                              ),
                            ),
                            if (s.clinicalTip.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(
                                'Nota clínica: ${s.clinicalTip}',
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  color: Colors.amberAccent,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildSectionTitle(
                      'Botiquín e insumos requeridos',
                      Icons.medical_services,
                      Colors.amberAccent,
                    ),
                    const SizedBox(height: 8),
                    ...proc.requiredSupplies.map(
                      (sup) => Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        color: SpaceTheme.card,
                        child: ListTile(
                          dense: true,
                          leading: const Icon(
                            Icons.inventory_2_outlined,
                            color: SpaceTheme.cyan,
                            size: 20,
                          ),
                          title: Text(
                            sup.name,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Text(
                            '${sup.usage}\nUbicación: ${sup.location}',
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: Colors.white70,
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (proc.warnings.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      _buildSectionTitle(
                        'Advertencias de seguridad',
                        Icons.warning_amber_rounded,
                        SpaceTheme.dangerRed,
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: SpaceTheme.dangerRed.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: SpaceTheme.dangerRed.withValues(alpha: 0.45),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: proc.warnings
                              .map(
                                (w) => Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: Text(
                                    '• $w',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionTitle(String title, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, size: 17, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
      ],
    );
  }

  Color _getPriorityColor(TriagePriority priority) {
    switch (priority) {
      case TriagePriority.red:
        return SpaceTheme.dangerRed;
      case TriagePriority.yellow:
        return SpaceTheme.warningYellow;
      case TriagePriority.green:
        return SpaceTheme.green;
    }
  }

  String _getPriorityLabel(TriagePriority priority) {
    switch (priority) {
      case TriagePriority.red:
        return 'ROJO';
      case TriagePriority.yellow:
        return 'AMARILLO';
      case TriagePriority.green:
        return 'VERDE';
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'cardiovascular':
        return Icons.favorite;
      case 'respiratory':
        return Icons.air;
      case 'radiation':
        return Icons.warning_amber;
      case 'hemodynamics':
        return Icons.monitor_heart;
      case 'environmental':
        return Icons.co2;
      case 'trauma':
        return Icons.local_hospital;
      case 'neuro_ocular':
        return Icons.remove_red_eye;
      case 'renal_metabolic':
        return Icons.water_drop;
      case 'vestibular':
        return Icons.explore;
      case 'behavioral_circadian':
      default:
        return Icons.bedtime;
    }
  }
}
