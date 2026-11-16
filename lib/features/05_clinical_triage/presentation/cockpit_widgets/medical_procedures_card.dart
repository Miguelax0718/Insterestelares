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
    const p = ApoloPalette.standard;
    final color = switch (procedure.priority) {
      TriagePriority.red => p.crit,
      TriagePriority.yellow => p.warn,
      TriagePriority.green => p.ok,
    };
    final priorityLabel = switch (procedure.priority) {
      TriagePriority.red => 'CRITICAL · RED',
      TriagePriority.yellow => 'URGENT · YELLOW',
      TriagePriority.green => 'ROUTINE · GREEN',
    };
    return CockpitCard(title: 'Medical Procedures', onDismiss: widget.onDismiss,
      critical: procedure.priority == TriagePriority.red, children: [
        Wrap(spacing: 8, runSpacing: 8, children: [
          _pill('${astronaut.callsign} • ${astronaut.id}', p.mint),
          _pill('Offline Protocol Guide', p.lav2),
        ]),
        _heading("What's happening?"),
        const Text('Choose a situation or use live telemetry to find a protocol.'),
        const SizedBox(height: 8),
        Wrap(spacing: 6, runSpacing: 6, children: [
          ChoiceChip(label: const Text('Live Telemetry'), selected: _scenarioId == null,
            shape: const StadiumBorder(),
            onSelected: (_) => setState(() { _scenarioId = null; _procedureId = null; })),
          for (final item in _scenarios)
            ChoiceChip(label: Text(item.label), selected: _scenarioId == item.id,
              shape: const StadiumBorder(),
              onSelected: (_) => setState(() {
                _scenarioId = item.id; _procedureId = item.recommendedProcedureId;
              })),
        ]),
        if (scenario != null)
          _panel(accent: color, children: [
            _label('First 60 Seconds', icon: Icons.timer_outlined, color: color),
            Text(scenario.symptomSummary),
            ...scenario.first60Seconds.map((s) => _bullet(s)),
            _label('Verify before continuing'),
            ...scenario.verificationQuestions.map((s) => _bullet(s)),
            _label('Emergency supplies'),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final supply in scenario.emergencySupplies) _pill(supply, color),
            ]),
          ]),
        _heading('Selected procedure'),
        _panel(accent: color, children: [
          Wrap(spacing: 8, runSpacing: 8, children: [
            _pill(priorityLabel, color),
            _pill(procedure.code, p.text2),
          ]),
          Text(procedure.title, style: const TextStyle(
            fontSize: 19, height: 1.3, fontWeight: FontWeight.w700)),
          Text(procedure.summary, style: const TextStyle(height: 1.5)),
          if (_procedureId == null && suggestions.isNotEmpty)
            _panel(children: [
              _label('Matched to live telemetry', icon: Icons.monitor_heart_outlined),
              Text(suggestions.first.reason),
            ]),
        ]),
        const SizedBox(height: 8),
        const Text('Switch offline protocol'),
        const SizedBox(height: 6),
        DecoratedBox(
          decoration: BoxDecoration(color: p.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: p.border)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: procedure.id, isExpanded: true,
                items: [for (final item in _catalog) DropdownMenuItem(
                  value: item.id,
                  child: Text(item.title, overflow: TextOverflow.ellipsis))],
                onChanged: (id) => setState(() => _procedureId = id)),
            ),
          ),
        ),
        _heading('When to activate'),
        _panel(children: [
          ...procedure.whenToActivate.map((s) => _bullet(s, icon: Icons.bolt)),
        ]),
        _heading('Step-by-step instructions'),
        for (final step in procedure.steps)
          _panel(key: ValueKey('procedure-step-${step.step}'), children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              CircleAvatar(radius: 16, backgroundColor: p.lav2,
                foregroundColor: p.bg, child: Text('${step.step}')),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(step.title, style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  _pill('~${step.durationSeconds}s', p.mint),
                ])),
            ]),
            Text(step.action, style: const TextStyle(height: 1.5)),
            _panel(accent: p.lav2, children: [
              _label('Clinical Tip', icon: Icons.lightbulb_outline, color: p.lav2),
              Text(step.clinicalTip, style: const TextStyle(height: 1.4)),
            ]),
          ]),
        _heading('Clinical warnings'),
        _panel(key: const ValueKey('clinical-warnings'),
          accent: procedure.priority == TriagePriority.red ? p.crit : p.warn,
          children: [
            _label('Safety first', icon: Icons.warning_amber_rounded,
              color: procedure.priority == TriagePriority.red ? p.crit : p.warn),
            ...procedure.warnings.map((s) => _bullet(s)),
          ]),
        _heading('Required first-aid kit supplies'),
        for (final supply in procedure.requiredSupplies)
          _panel(key: ValueKey('procedure-supply-${supply.itemId}'), children: [
            _label(supply.name, icon: Icons.medical_services_outlined),
            _pill(supply.location, p.mint),
            Text(supply.usage, style: const TextStyle(height: 1.5)),
          ]),
        const SizedBox(height: 16),
        Text(procedure.criterionReference,
          style: TextStyle(color: p.text2, fontSize: 12, height: 1.4)),
        const SizedBox(height: 8),
        Text('Follow mission medical protocols and contact the flight surgeon when available.',
          style: TextStyle(color: p.text2, fontSize: 12, height: 1.4)),
      ]);
  }

  Widget _heading(String text) => Padding(
    padding: const EdgeInsets.only(top: 20, bottom: 10),
    child: Text(text, style: const TextStyle(
      fontSize: 16, fontWeight: FontWeight.w700)),
  );

  Widget _label(String text, {IconData? icon, Color? color}) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (icon != null) ...[
        Icon(icon, size: 20, color: color ?? ApoloPalette.standard.mint),
        const SizedBox(width: 8),
      ],
      Expanded(child: Text(text, style: TextStyle(
        fontWeight: FontWeight.w700, color: color))),
    ],
  );

  Widget _pill(String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      border: Border.all(color: color.withValues(alpha: 0.45)),
      borderRadius: BorderRadius.circular(20)),
    child: Text(text, style: TextStyle(
      color: color, fontSize: 12, fontWeight: FontWeight.w600)),
  );

  Widget _bullet(String text, {IconData icon = Icons.circle}) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(padding: const EdgeInsets.only(top: 5),
        child: Icon(icon, size: icon == Icons.circle ? 6 : 16,
          color: ApoloPalette.standard.text2)),
      const SizedBox(width: 8),
      Expanded(child: Text(text, style: const TextStyle(height: 1.5))),
    ],
  );

  Widget _panel({Key? key, Color? accent, required List<Widget> children}) {
    const p = ApoloPalette.standard;
    return Container(
      key: key,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: accent?.withValues(alpha: 0.09) ?? p.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent?.withValues(alpha: 0.5) ?? p.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            children[i],
          ],
        ]),
    );
  }
}
