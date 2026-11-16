import 'package:flutter/material.dart';
import '../../agent/graybiel_engine.dart';
import 'cockpit_card.dart';

class GraybielCard extends StatefulWidget {
  const GraybielCard({super.key, required this.onSubmit, required this.onDismiss,
    this.initialResponses = const {}, this.initialEmesis = false});
  final CockpitSubmit onSubmit;
  final VoidCallback onDismiss;
  final Map<GraybielSymptom, GraybielLevel> initialResponses;
  final bool initialEmesis;
  @override
  State<GraybielCard> createState() => _GraybielCardState();
}

class _GraybielCardState extends State<GraybielCard> {
  final _session = GraybielSession();
  GraybielLevel _epigastric = GraybielLevel.none;
  GraybielLevel _nausea = GraybielLevel.none;
  @override
  void initState() {
    super.initState();
    for (final entry in widget.initialResponses.entries) {
      _session.recordAnswer(entry.key, entry.value);
    }
    _session.emesis = widget.initialEmesis;
    _nausea = widget.initialResponses[GraybielSymptom.nausea] ?? GraybielLevel.none;
  }
  void _updateNauseaSyndrome() => _session.recordAnswer(GraybielSymptom.nausea,
    _nausea.index >= _epigastric.index ? _nausea : _epigastric);
  @override
  Widget build(BuildContext context) {
    final evaluation = GraybielEngine.evaluate(_session.responses, emesis: _session.emesis);
    return CockpitCard(title: 'Graybiel Assessment', onDismiss: widget.onDismiss,
      critical: evaluation.evaBlockedRecommended,
      status: evaluation.evaBlockedRecommended ? 'NO-GO EVA' : 'Symptom assessment',
      children: [
        Text('Score ${evaluation.totalScore} • ${evaluation.category.wireName}'),
        if (evaluation.evaBlockedRecommended) Container(
          padding: const EdgeInsets.all(8), color: ApoloPalette.standard.crit,
          child: const Row(children: [Icon(Icons.block), SizedBox(width: 8), Text('NO-GO EVA')])),
        for (final symptom in GraybielSymptom.values) Row(children: [
          Expanded(child: Text(switch (symptom) {
            GraybielSymptom.nausea => 'Nausea',
            GraybielSymptom.coldSweating => 'Cold Sweat',
            GraybielSymptom.pallor => 'Pallor/Greenness',
            _ => symptom.label,
          })),
          DropdownButton<GraybielLevel>(value: symptom == GraybielSymptom.nausea ?
            _nausea : _session.responses[symptom] ?? GraybielLevel.none,
            items: [for (final level in GraybielLevel.values)
              DropdownMenuItem(value: level, child: Text(level.wireName))],
            onChanged: (v) => setState(() {
              if (symptom == GraybielSymptom.nausea) {
                _nausea = v!;
                _updateNauseaSyndrome();
              } else {
                _session.recordAnswer(symptom, v!);
              }
            })),
        ]),
        Row(children: [
          const Expanded(child: Text('Epigastric')),
          DropdownButton<GraybielLevel>(value: _epigastric,
            items: [for (final level in GraybielLevel.values)
              DropdownMenuItem(value: level, child: Text(level.wireName))],
            onChanged: (v) => setState(() {
              _epigastric = v!;
              // Epigastric awareness belongs to the existing nausea syndrome;
              // do not double-count it as a new independent Graybiel symptom.
              _updateNauseaSyndrome();
            })),
        ]),
        const Text('Nausea syndrome uses the higher nausea/epigastric rating without double-counting.'),
        SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Emesis'),
          value: _session.emesis, onChanged: (v) => setState(() => _session.emesis = v)),
        FilledButton(onPressed: () => widget.onSubmit({
          'completed': true, 'responses': evaluation.toJson()['responses'],
          'emesis': _session.emesis,
          'epigastric': _epigastric.wireName,
          'facial_pallor': (_session.responses[GraybielSymptom.pallor] ?? GraybielLevel.none).wireName,
        }), child: const Text('Submit Assessment')),
      ]);
  }
}
