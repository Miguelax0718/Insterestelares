import 'package:flutter/material.dart';
import '../../../apolo/presentation/apolo_theme.dart';

export '../../../apolo/presentation/apolo_theme.dart';

typedef CockpitSubmit = void Function(Map<String, dynamic>);

/// Shared compact, scroll-host-friendly surface with accessible status and dismissal.
class CockpitCard extends StatelessWidget {
  const CockpitCard({super.key, required this.title, required this.onDismiss,
    required this.children, this.critical = false, this.status = 'Self-check'});
  final String title;
  final VoidCallback onDismiss;
  final List<Widget> children;
  final bool critical;
  final String status;
  @override
  Widget build(BuildContext context) {
    const p = ApoloPalette.standard;
    return Theme(
      data: buildApoloTheme(),
      child: Card(
        color: p.bg2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: critical ? p.crit : p.border)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min,
            children: [
              Row(children: [
                Icon(critical ? Icons.error_outline : Icons.explore_outlined,
                  color: critical ? p.crit : p.lav),
                const SizedBox(width: 8),
                Expanded(child: Text(title, style: TextStyle(color: p.text,
                  fontSize: 18, fontWeight: FontWeight.w600))),
                IconButton(tooltip: 'Dismiss', onPressed: onDismiss, icon: const Icon(Icons.close)),
              ]),
              Text(critical ? 'Critical • $status' : 'Ready • $status',
                style: TextStyle(color: critical ? p.crit : p.ok)),
              const SizedBox(height: 12),
              ...children,
            ]),
        ),
      ),
    );
  }
}
