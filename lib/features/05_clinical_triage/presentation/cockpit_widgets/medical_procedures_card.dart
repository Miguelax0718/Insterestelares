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
  int _stepIndex = 0;
  bool _showSituation = false;
  bool _showAllSteps = false;
  bool _showWarnings = false;
  bool _showSupplies = false;
  bool _showActivate = false;
  bool _showReference = false;

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
      _stepIndex = 0;
      _applyInitial();
    }
  }

  @override
  Widget build(BuildContext context) {
    final crew = ref.watch(crewMembersProvider);
    final selected = ref.watch(selectedAstronautProvider);
    final matches = crew.where((a) => a.id == widget.astronautId);
    final astronaut = widget.astronautId == null ? selected : matches.firstOrNull;
    if (astronaut == null) return const Text('Crew member unavailable');

    final suggestions = MedicalProceduresData.suggestProceduresForAstronaut(
      astronaut,
      catalog: _catalog,
      scenarios: _scenarios,
      simulatedSituationId: _scenarioId,
    );
    final procedure = MedicalProceduresData.findById(_procedureId ?? '', _catalog) ??
        (suggestions.isEmpty ? _catalog.first : suggestions.first.procedure);
    final scenario = _scenarios.where((s) => s.id == _scenarioId).firstOrNull;
    const p = ApoloPalette.standard;
    final color = switch (procedure.priority) {
      TriagePriority.red => p.crit,
      TriagePriority.yellow => p.warn,
      TriagePriority.green => p.ok,
    };
    final priorityLabel = switch (procedure.priority) {
      TriagePriority.red => 'CRITICAL',
      TriagePriority.yellow => 'URGENT',
      TriagePriority.green => 'ROUTINE',
    };
    final warningColor = procedure.priority == TriagePriority.red ? p.crit : p.warn;
    final totalSteps = procedure.steps.length;
    final safeStepIndex = totalSteps == 0 ? 0 : _stepIndex.clamp(0, totalSteps - 1);

    return CockpitCard(
      title: 'Medical Procedures',
      onDismiss: widget.onDismiss,
      critical: procedure.priority == TriagePriority.red,
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _pill('${astronaut.callsign} • Offline Guide', p.mint),
            _pill(priorityLabel, color),
            _pill(procedure.code, p.text2),
          ],
        ),
        const SizedBox(height: 8),
        DecoratedBox(
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: p.border),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: procedure.id,
                isExpanded: true,
                items: [
                  for (final item in _catalog)
                    DropdownMenuItem(
                      value: item.id,
                      child: Text(item.title, overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: (id) => setState(() {
                  _procedureId = id;
                  _stepIndex = 0;
                }),
              ),
            ),
          ),
        ),
        _panel(
          accent: color,
          children: [
            Text(
              procedure.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 16.5,
                height: 1.25,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              procedure.summary,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: p.text2, fontSize: 13.5, height: 1.35),
            ),
            if (_procedureId == null && suggestions.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: p.mint.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: p.mint.withValues(alpha: 0.35)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _label(
                      'Matched to live telemetry',
                      icon: Icons.monitor_heart_outlined,
                      color: p.mint,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      suggestions.first.reason,
                      style: TextStyle(color: p.text2, fontSize: 12, height: 1.3),
                    ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        _drawerToggle(
          key: const ValueKey('procedures_situation_toggle'),
          label: 'Situation triage: ${scenario?.label ?? 'Live Telemetry'}',
          icon: Icons.tune_rounded,
          expanded: _showSituation,
          accent: p.lav2,
          onTap: () => setState(() => _showSituation = !_showSituation),
        ),
        if (_showSituation) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              ChoiceChip(
                label: const Text('Live Telemetry'),
                selected: _scenarioId == null,
                visualDensity: VisualDensity.compact,
                shape: const StadiumBorder(),
                onSelected: (_) => setState(() {
                  _scenarioId = null;
                  _procedureId = null;
                  _stepIndex = 0;
                }),
              ),
              for (final item in _scenarios)
                ChoiceChip(
                  label: Text(item.label),
                  selected: _scenarioId == item.id,
                  visualDensity: VisualDensity.compact,
                  shape: const StadiumBorder(),
                  onSelected: (_) => setState(() {
                    _scenarioId = item.id;
                    _procedureId = item.recommendedProcedureId;
                    _stepIndex = 0;
                    _showSituation = true;
                  }),
                ),
            ],
          ),
          if (scenario != null)
            _panel(
              accent: color,
              children: [
                _label('First 60 Seconds', icon: Icons.timer_outlined, color: color),
                Text(scenario.symptomSummary),
                ...scenario.first60Seconds.map((s) => _bullet(s)),
                _label('Verify before continuing'),
                ...scenario.verificationQuestions.map((s) => _bullet(s)),
                _label('Emergency supplies'),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final supply in scenario.emergencySupplies) _pill(supply, color),
                  ],
                ),
              ],
            ),
        ],
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: Text(
                totalSteps == 0
                    ? 'No steps available'
                    : 'Step ${safeStepIndex + 1} of $totalSteps',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ),
            TextButton.icon(
              key: const ValueKey('procedure_all_steps_toggle'),
              onPressed: () => setState(() => _showAllSteps = !_showAllSteps),
              icon: Icon(
                _showAllSteps ? Icons.view_carousel_outlined : Icons.format_list_numbered,
                size: 16,
              ),
              label: Text(_showAllSteps ? 'Single step' : 'View all steps'),
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                foregroundColor: p.lav2,
              ),
            ),
          ],
        ),
        if (totalSteps > 0 && !_showAllSteps) ...[
          _stepCard(procedure.steps[safeStepIndex], p),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  key: const ValueKey('procedure_prev_step'),
                  onPressed: safeStepIndex > 0
                      ? () => setState(() => _stepIndex = safeStepIndex - 1)
                      : null,
                  icon: const Icon(Icons.arrow_back, size: 16),
                  label: const Text('Previous'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  key: const ValueKey('procedure_next_step'),
                  onPressed: safeStepIndex < totalSteps - 1
                      ? () => setState(() => _stepIndex = safeStepIndex + 1)
                      : null,
                  icon: const Icon(Icons.arrow_forward, size: 16),
                  label: const Text('Next Step'),
                ),
              ),
            ],
          ),
        ] else if (totalSteps > 0) ...[
          for (final step in procedure.steps) _stepCard(step, p),
        ],
        const SizedBox(height: 14),
        _drawerToggle(
          key: const ValueKey('procedures_warnings_toggle'),
          label: 'Warnings (${procedure.warnings.length})',
          icon: Icons.warning_amber_rounded,
          expanded: _showWarnings,
          accent: warningColor,
          tinted: true,
          onTap: () => setState(() => _showWarnings = !_showWarnings),
        ),
        if (_showWarnings)
          _panel(
            key: const ValueKey('clinical-warnings'),
            accent: warningColor,
            children: [
              _label('Safety first', icon: Icons.warning_amber_rounded, color: warningColor),
              ...procedure.warnings.map((s) => _bullet(s)),
            ],
          ),
        const SizedBox(height: 8),
        _drawerToggle(
          key: const ValueKey('procedures_supplies_toggle'),
          label: 'First-Aid Supplies (${procedure.requiredSupplies.length})',
          icon: Icons.medical_services_outlined,
          expanded: _showSupplies,
          accent: p.mint,
          onTap: () => setState(() => _showSupplies = !_showSupplies),
        ),
        if (_showSupplies)
          for (final supply in procedure.requiredSupplies)
            _panel(
              key: ValueKey('procedure-supply-${supply.itemId}'),
              children: [
                _label(supply.name, icon: Icons.medical_services_outlined),
                _pill(supply.location, p.mint),
                Text(supply.usage, style: const TextStyle(height: 1.45)),
              ],
            ),
        const SizedBox(height: 8),
        _drawerToggle(
          key: const ValueKey('procedures_activate_toggle'),
          label: 'When to Activate (${procedure.whenToActivate.length})',
          icon: Icons.bolt,
          expanded: _showActivate,
          accent: p.lav2,
          onTap: () => setState(() => _showActivate = !_showActivate),
        ),
        if (_showActivate)
          _panel(
            children: [
              ...procedure.whenToActivate.map((s) => _bullet(s, icon: Icons.bolt)),
            ],
          ),
        const SizedBox(height: 8),
        _drawerToggle(
          key: const ValueKey('procedures_reference_toggle'),
          label: 'Clinical Reference',
          icon: Icons.menu_book_outlined,
          expanded: _showReference,
          accent: p.text2,
          onTap: () => setState(() => _showReference = !_showReference),
        ),
        if (_showReference)
          _panel(
            children: [
              Text(
                procedure.criterionReference,
                style: TextStyle(color: p.text2, fontSize: 12.5, height: 1.4),
              ),
              Text(
                'Follow mission medical protocols and contact the flight surgeon when available.',
                style: TextStyle(color: p.text2, fontSize: 12, height: 1.4),
              ),
            ],
          ),
      ],
    );
  }

  Widget _stepCard(ProcedureStep step, ApoloPalette p) => _panel(
        key: ValueKey('procedure-step-${step.step}'),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 15,
                backgroundColor: p.lav2,
                foregroundColor: p.bg,
                child: Text(
                  '${step.step}',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      step.title,
                      style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 6),
                    _pill('~${step.durationSeconds}s', p.mint),
                  ],
                ),
              ),
            ],
          ),
          Text(step.action, style: const TextStyle(height: 1.45)),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: p.lav2.withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: p.lav2.withValues(alpha: 0.4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _label('Clinical Tip', icon: Icons.lightbulb_outline, color: p.lav2),
                const SizedBox(height: 4),
                Text(step.clinicalTip, style: const TextStyle(fontSize: 13, height: 1.4)),
              ],
            ),
          ),
        ],
      );

  Widget _drawerToggle({
    required Key key,
    required String label,
    required IconData icon,
    required bool expanded,
    required Color accent,
    required VoidCallback onTap,
    bool tinted = false,
  }) {
    const p = ApoloPalette.standard;
    return InkWell(
      key: key,
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: tinted ? accent.withValues(alpha: 0.12) : p.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: tinted || expanded ? accent.withValues(alpha: 0.5) : p.border,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: accent),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: tinted ? accent : p.text,
                ),
              ),
            ),
            Icon(
              expanded ? Icons.expand_less : Icons.expand_more,
              size: 20,
              color: tinted ? accent : p.text2,
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text, {IconData? icon, Color? color}) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: color ?? ApoloPalette.standard.mint),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontWeight: FontWeight.w700, color: color),
            ),
          ),
        ],
      );

  Widget _pill(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          border: Border.all(color: color.withValues(alpha: 0.45)),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          text,
          style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
        ),
      );

  Widget _bullet(String text, {IconData icon = Icons.circle}) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Icon(
              icon,
              size: icon == Icons.circle ? 6 : 16,
              color: ApoloPalette.standard.text2,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(height: 1.45))),
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
        border: Border.all(color: accent?.withValues(alpha: 0.5) ?? p.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            children[i],
          ],
        ],
      ),
    );
  }
}
