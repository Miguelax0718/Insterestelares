import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:astramed/features/03_microgravity/presentation/cockpit_widgets/cockpit_card.dart';
import 'package:astramed/features/05_clinical_triage/data/medical_procedures_data.dart';
import 'package:astramed/features/05_clinical_triage/models/triage_decision.dart';
import 'package:astramed/features/crew/presentation/providers/crew_provider.dart';

class MedicalProceduresCockpitCard extends ConsumerStatefulWidget {
  const MedicalProceduresCockpitCard({super.key, this.astronautId,
    this.initialProcedureId, this.initialQuery, required this.onDismiss,
    this.onSubmit});
  final String? astronautId, initialProcedureId, initialQuery;
  final VoidCallback onDismiss;
  final ValueChanged<Map<String, dynamic>>? onSubmit;
  @override
  ConsumerState<MedicalProceduresCockpitCard> createState() => _ProceduresState();
}

class _ProceduresState extends ConsumerState<MedicalProceduresCockpitCard> {
  final _catalog = MedicalProceduresData.getProcedures();
  final _scenarios = MedicalProceduresData.getScenarios();
  String? _procedureId, _scenarioId;
  @override
  void initState() {
    super.initState();
    _applyInitial();
  }
  void _applyInitial() {
    _procedureId = MedicalProceduresData.findById(widget.initialProcedureId ?? '', _catalog)?.id;
    final query = widget.initialQuery?.trim().toLowerCase() ?? '';
    if (_procedureId == null && query.isNotEmpty) {
      for (final procedure in _catalog) {
        if ('${procedure.id} ${procedure.title} ${procedure.summary}'.toLowerCase().contains(query)) {
          _procedureId = procedure.id;
          break;
        }
      }
    }
  }
  @override
  void didUpdateWidget(covariant MedicalProceduresCockpitCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialProcedureId != widget.initialProcedureId ||
        oldWidget.initialQuery != widget.initialQuery ||
        oldWidget.astronautId != widget.astronautId) {
      _scenarioId = null;
      _applyInitial();
    }
  }
  @override
  Widget build(BuildContext context) {
    final crew = ref.watch(crewMembersProvider);
    final selected = ref.watch(selectedAstronautProvider);
    final matches = crew.where((a) => a.id == widget.astronautId);
    final astronaut = widget.astronautId == null ? selected
      : matches.firstOrNull;
    if (astronaut == null) return const Text('Crew member unavailable');
    final suggestions = MedicalProceduresData.suggestProceduresForAstronaut(
      astronaut, catalog: _catalog, scenarios: _scenarios,
      simulatedSituationId: _scenarioId);
    final procedure = MedicalProceduresData.findById(_procedureId ?? '', _catalog)
      ?? (suggestions.isEmpty ? _catalog.first : suggestions.first.procedure);
    final scenario = _scenarios.where((s) => s.id == _scenarioId).firstOrNull;
    final color = switch (procedure.priority) {
      TriagePriority.red => Colors.redAccent,
      TriagePriority.yellow => Colors.amber,
      TriagePriority.green => Colors.green,
    };
    return CockpitCard(title: 'Medical Procedures', onDismiss: widget.onDismiss,
      critical: procedure.priority == TriagePriority.red, children: [
        Text('${astronaut.callsign} • ${astronaut.id} • Offline catalog'),
        Wrap(spacing: 6, runSpacing: 6, children: [
          ChoiceChip(label: const Text('Live Telemetry'), selected: _scenarioId == null,
            onSelected: (_) => setState(() { _scenarioId = null; _procedureId = null; })),
          for (final item in _scenarios)
            ChoiceChip(label: Text(item.label), selected: _scenarioId == item.id,
              onSelected: (_) => setState(() {
                _scenarioId = item.id; _procedureId = item.recommendedProcedureId;
              })),
        ]),
        if (scenario != null) ...[
          Text('Selected situation • ${scenario.priority.name.toUpperCase()}'),
          Text(scenario.symptomSummary),
          ...scenario.first60Seconds.map((s) => Text(s)),
          ...scenario.verificationQuestions.map((s) => Text(s)),
          Text('Emergency supplies: ${scenario.emergencySupplies.join(', ')}'),
        ],
        DropdownButton<String>(value: procedure.id, isExpanded: true,
          items: [for (final p in _catalog) DropdownMenuItem(value: p.id,
            child: Text(p.title, overflow: TextOverflow.ellipsis))],
          onChanged: (id) => setState(() => _procedureId = id)),
        Text(procedure.priority.name.toUpperCase(), style: TextStyle(color: color,
          fontWeight: FontWeight.bold)),
        Text(procedure.title, style: Theme.of(context).textTheme.titleMedium),
        Text(procedure.summary),
        if (_procedureId == null && suggestions.isNotEmpty) Text(suggestions.first.reason),
        const Text('When to activate'),
        ...procedure.whenToActivate.map((s) => Text(s)),
        const Text('Step-by-step instructions'),
        for (final step in procedure.steps) ...[
          Text('${step.step}. ${step.title} (${step.durationSeconds}s)'),
          Text(step.action),
          Text(step.clinicalTip),
        ],
        const Text('Clinical warnings'),
        ...procedure.warnings.map((s) => Text(s)),
        const Text('Required first-aid kit supplies'),
        for (final supply in procedure.requiredSupplies) ...[
          Text('${supply.name} • ${supply.location}'),
          Text(supply.usage),
        ],
        Text(procedure.criterionReference),
        const Text('Follow mission medical protocols and contact the flight surgeon when available.'),
      ]);
  }
}
