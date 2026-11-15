import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/space_theme.dart';
import '../models/radiation_symptom.dart';
import '../providers/biomarker_providers.dart';
import '../providers/symptom_providers.dart';
import 'biomarker_panel.dart';

Color symptomLevelColor(SymptomLevel level) => switch (level) {
      SymptomLevel.info => SpaceTheme.green,
      SymptomLevel.watch => SpaceTheme.warningYellow,
      SymptomLevel.urgent => SpaceTheme.dangerRed,
    };

/// Lista de posibles síntomas por radiación. El astronauta marca los que
/// siente y la tarjeta le dice qué hacer. Toca un síntoma para ver cuándo
/// aparece y por qué.
class RadiationSymptomsCard extends ConsumerWidget {
  const RadiationSymptomsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final astronaut = ref.watch(biomarkerAstronautProvider);
    final reported = ref.watch(reportedSymptomsProvider(astronaut));
    final bioLevel = BioLevel.of(ref.watch(selectedBioSummaryProvider).score);

    void toggle(RadiationSymptom s, bool on) {
      final notifier = ref.read(reportedSymptomsProvider(astronaut).notifier);
      notifier.state = on ? {...notifier.state, s} : ({...notifier.state}..remove(s));
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Posibles síntomas por radiación',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 4),
            const Text(
              'Marca los que sientas hoy. Toca un síntoma para saber cuándo '
              'aparece, por qué y qué hacer.',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 12),
            _SymptomVerdict(reported: reported, bioLevel: bioLevel),
            const SizedBox(height: 8),
            for (final s in RadiationSymptom.values)
              _SymptomTile(
                symptom: s,
                checked: reported.contains(s),
                onChanged: (v) => toggle(s, v),
              ),
            const SizedBox(height: 8),
            const Text(
              'Guía educativa basada en CDC/REMM y NASA HRP. No reemplaza al '
              'cirujano de vuelo; los niveles son ilustrativos.',
              style: TextStyle(color: Colors.white38, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

/// Recuadro con la conclusión: qué hacer según el peor síntoma marcado.
class _SymptomVerdict extends StatelessWidget {
  const _SymptomVerdict({required this.reported, required this.bioLevel});

  final Set<RadiationSymptom> reported;
  final BioLevel bioLevel;

  @override
  Widget build(BuildContext context) {
    final worst = RadiationSymptom.worstOf(reported);
    final (color, icon, text) = switch (worst) {
      null => (
          SpaceTheme.green,
          Icons.check_circle_outline,
          'Sin síntomas marcados.',
        ),
      SymptomLevel.info => (
          SpaceTheme.green,
          Icons.check_circle_outline,
          'Nada preocupante. Anótalo y sigue con tu rutina.',
        ),
      SymptomLevel.watch => (
          SpaceTheme.warningYellow,
          Icons.visibility_outlined,
          'Repórtalo en el próximo chequeo médico.',
        ),
      SymptomLevel.urgent => (
          SpaceTheme.dangerRed,
          Icons.warning_amber_rounded,
          'Avisa al cirujano de vuelo ahora.',
        ),
    };
    final bioWarning = bioLevel == BioLevel.alert &&
        worst != null &&
        worst != SymptomLevel.info;

    return Container(
      key: const Key('symptomVerdict'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color, width: 1.5),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  text,
                  key: const Key('symptomVerdictText'),
                  style: TextStyle(color: color, fontWeight: FontWeight.bold),
                ),
                if (reported.isNotEmpty)
                  Text(
                    '${reported.length} síntoma${reported.length == 1 ? '' : 's'} '
                    'marcado${reported.length == 1 ? '' : 's'}',
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                if (bioWarning)
                  const Text(
                    'Tus biomarcadores también están en Alerta: menciónalo.',
                    style: TextStyle(color: SpaceTheme.dangerRed, fontSize: 12),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SymptomTile extends StatelessWidget {
  const _SymptomTile({
    required this.symptom,
    required this.checked,
    required this.onChanged,
  });

  final RadiationSymptom symptom;
  final bool checked;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final color = symptomLevelColor(symptom.level);
    return ExpansionTile(
      key: Key('symptom_${symptom.name}'),
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.fromLTRB(48, 0, 8, 12),
      expandedCrossAxisAlignment: CrossAxisAlignment.start,
      leading: Checkbox(
        key: Key('symptomCheck_${symptom.name}'),
        value: checked,
        activeColor: color,
        onChanged: (v) => onChanged(v ?? false),
      ),
      title: Text(symptom.label),
      subtitle: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(symptom.level.label,
              style: TextStyle(color: color, fontSize: 12)),
        ],
      ),
      children: [
        _InfoLine(label: 'Cuándo aparece', text: symptom.when),
        _InfoLine(label: 'Por qué', text: symptom.why),
        _InfoLine(label: 'Qué hacer', text: symptom.action, color: color),
      ],
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.label, required this.text, this.color});

  final String label;
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: '$label: ',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: color ?? Colors.white,
                ),
              ),
              TextSpan(text: text, style: const TextStyle(color: Colors.white70)),
            ],
          ),
          style: const TextStyle(fontSize: 13),
        ),
      );
}
