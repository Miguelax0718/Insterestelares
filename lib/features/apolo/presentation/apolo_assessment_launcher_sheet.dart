import 'package:flutter/material.dart';

import '../../agent/domain/guided_assessment_catalog.dart';
import 'apolo_theme.dart';

/// Space Cockpit sheet listing all implemented guided clinical tests,
/// microgravity SMS/SANS suites, and exercise countermeasures.
class ApoloAssessmentLauncherSheet extends StatelessWidget {
  const ApoloAssessmentLauncherSheet({super.key, required this.onLaunch});

  final void Function(GuidedAssessmentDescriptor descriptor) onLaunch;

  static Future<void> show(
    BuildContext context, {
    required void Function(GuidedAssessmentDescriptor descriptor) onLaunch,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ApoloAssessmentLauncherSheet(onLaunch: onLaunch),
    );
  }

  @override
  Widget build(BuildContext context) {
    const categories = {
      'microgravity': 'Microgravity / SMS',
      'ocular': 'Ocular / SANS',
      'cognitive': 'Cognitive & Diary',
      'readiness': 'Readiness',
    };
    const p = ApoloPalette.standard;
    return Theme(data: buildApoloTheme(), child: SafeArea(
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .85),
        decoration: BoxDecoration(color: p.bg, borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: p.border)),
        child: SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min,
          children: [
            Row(children: [
              const Expanded(child: Text('Guided Tests & Countermeasures', style: TextStyle(fontSize: 20))),
              IconButton(tooltip: 'Dismiss', onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
            ]),
            for (final category in categories.entries) ...[
              Padding(padding: const EdgeInsets.only(top: 16, bottom: 8),
                child: Text(category.value, style: TextStyle(color: p.lav2, fontWeight: FontWeight.bold))),
              for (final descriptor in GuidedAssessmentCatalog.all.where((d) => d.category == category.key))
                Card(color: p.surface, child: Padding(padding: const EdgeInsets.all(12),
                  child: Row(children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(descriptor.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                      Text(descriptor.summary, style: TextStyle(color: p.text2)),
                      Chip(avatar: const Icon(Icons.schedule, size: 14),
                        label: Text('${descriptor.estimatedMinutes} min')),
                    ])),
                    const SizedBox(width: 8),
                    FilledButton(onPressed: () {
                      Navigator.pop(context);
                      onLaunch(descriptor);
                    }, child: const Text('Start')),
                  ]))),
            ],
          ],
        )),
      ),
    ));
  }
}
