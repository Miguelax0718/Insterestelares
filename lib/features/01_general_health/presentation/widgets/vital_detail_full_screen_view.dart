import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:astramed/core/theme/space_theme.dart';
import 'package:astramed/features/01_general_health/domain/scientific_criteria_engine.dart';
import 'package:astramed/features/01_general_health/domain/telemetry_view_contracts.dart';

enum _TemporalRangeFilter {
  last24h('Últimas 24h'),
  last7d('Últimos 7 días'),
  mission18d('Misión (18 días)');

  final String label;
  const _TemporalRangeFilter(this.label);
}

/// Vista de pantalla completa para el detalle clínico, gamificado y contextual
/// de un indicador vital específico (Frecuencia Cardíaca, Frecuencia Respiratoria, SpO2).
class VitalDetailFullScreenView extends StatefulWidget {
  final String title;
  final IconData icon;
  final Color color;
  final EvaluationResult evaluation;
  final String contextAverageLabel;
  final String metadataTag;
  final List<TelemetrySamplePoint> samples;
  final String unit;
  final String howToMeasure;
  final String contextMeaning;
  final String whenToPayAttention;
  final ActivityContext activeContext;
  final String? customValueDisplay;
  final String? astronautId;
  final int missionDay;
  final SpaceOperationalEnvironment activeEnvironment;
  final void Function(ClinicalMissionLogEntry entry)? onMissionLogCreated;

  const VitalDetailFullScreenView({
    super.key,
    required this.title,
    required this.icon,
    required this.color,
    required this.evaluation,
    required this.contextAverageLabel,
    required this.metadataTag,
    required this.samples,
    required this.unit,
    required this.howToMeasure,
    required this.contextMeaning,
    required this.whenToPayAttention,
    required this.activeContext,
    this.customValueDisplay,
    this.astronautId,
    this.missionDay = 18,
    this.activeEnvironment = SpaceOperationalEnvironment.spaceStation,
    this.onMissionLogCreated,
  });

  static Future<void> navigate(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
    required EvaluationResult evaluation,
    required String contextAverageLabel,
    required String metadataTag,
    required List<TelemetrySamplePoint> samples,
    required String unit,
    required String howToMeasure,
    required String contextMeaning,
    required String whenToPayAttention,
    required ActivityContext activeContext,
    String? customValueDisplay,
    String? astronautId,
    int missionDay = 18,
    SpaceOperationalEnvironment activeEnvironment =
        SpaceOperationalEnvironment.spaceStation,
    void Function(ClinicalMissionLogEntry entry)? onMissionLogCreated,
  }) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => VitalDetailFullScreenView(
          title: title,
          icon: icon,
          color: color,
          evaluation: evaluation,
          contextAverageLabel: contextAverageLabel,
          metadataTag: metadataTag,
          samples: samples,
          unit: unit,
          howToMeasure: howToMeasure,
          contextMeaning: contextMeaning,
          whenToPayAttention: whenToPayAttention,
          activeContext: activeContext,
          customValueDisplay: customValueDisplay,
          astronautId: astronautId,
          missionDay: missionDay,
          activeEnvironment: activeEnvironment,
          onMissionLogCreated: onMissionLogCreated,
        ),
      ),
    );
  }

  @override
  State<VitalDetailFullScreenView> createState() =>
      _VitalDetailFullScreenViewState();
}

class _VitalDetailFullScreenViewState extends State<VitalDetailFullScreenView> {
  bool _missionCompleted = false;
  _TemporalRangeFilter _selectedRange = _TemporalRangeFilter.mission18d;
  int? _selectedSampleIndex;
  Map<String, String>? _savedVerificationAnswers;

  @override
  Widget build(BuildContext context) {
    final validSamples =
        widget.samples.where((s) => s.isValid && s.value != null).toList();
    final criterion = widget.evaluation.appliedCriterion;

    // Calcular valores/medias por contexto específico
    final restAvg = _calculateAverage(widget.samples, ActivityContext.rest);
    final sleepAvg = _calculateAverage(widget.samples, ActivityContext.sleep);
    final activityAvg =
        _calculateAverage(widget.samples, ActivityContext.physicalActivity);

    return Scaffold(
      backgroundColor: SpaceTheme.background,
      appBar: AppBar(
        backgroundColor: SpaceTheme.surface,
        elevation: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: widget.color.withValues(alpha: 0.2),
              child: Icon(widget.icon, color: widget.color, size: 18),
            ),
            const SizedBox(width: 10),
            Text(
              widget.title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // ── TARJETA HERO: VALOR ACTUAL Y ESTADO ──
          _buildHeroCard(restAvg, sleepAvg, activityAvg),
          const SizedBox(height: 16),

          // ── COMPARATIVA VISUAL DE CONTEXTOS (REPOSO, SUEÑO, ACTIVIDAD) ──
          _buildContextsBreakdownCard(restAvg, sleepAvg, activityAvg),
          const SizedBox(height: 16),

          // ── MISIÓN DE GAMIFICACIÓN / APRENDIZAJE ──
          _buildGamificationMissionCard(),
          const SizedBox(height: 16),

          // ── GRÁFICAS Y TENDENCIA TEMPORAL ──
          _buildChartsCard(validSamples),
          const SizedBox(height: 16),

          // ── GUÍA CLARA PARA EL ASTRONAUTA (INSTRUCCIONES SIMPLES) ──
          _buildEducationalInstructionsCard(),
          const SizedBox(height: 16),

          // ── METADATOS Y CRITERIO CIENTÍFICO ──
          if (criterion != null) ...[
            _buildScientificReferenceCard(criterion),
            const SizedBox(height: 20),
          ],
        ],
      ),
    );
  }

  double? _calculateAverage(
      List<TelemetrySamplePoint> samples, ActivityContext ctx) {
    final values = samples
        .where((s) => s.context == ctx && s.isValid && s.value != null)
        .map((s) => s.value!)
        .toList();
    if (values.isEmpty) return null;
    return values.reduce((a, b) => a + b) / values.length;
  }

  int get _unitDecimals {
    if (widget.unit == 'rpm' || widget.unit == 's' || widget.unit == '°C') {
      return 1;
    }
    if (widget.unit == '%' && widget.title.contains('Hidratación')) {
      return 1;
    }
    return 0;
  }

  Widget _buildHeroCard(double? restAvg, double? sleepAvg, double? activityAvg) {
    final hasData = widget.evaluation.hasData;
    final valStr = hasData
        ? (widget.customValueDisplay ??
            '${widget.evaluation.value!.toStringAsFixed(_unitDecimals)} ${widget.unit}')
        : 'Sin datos';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: SpaceTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: widget.color.withValues(alpha: 0.4), width: 1.5),
        gradient: LinearGradient(
          colors: [
            widget.color.withValues(alpha: 0.12),
            SpaceTheme.surface,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: SpaceTheme.card,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white12),
                ),
                child: Text(
                  'Contexto actual: ${widget.activeContext.label}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white70,
                  ),
                ),
              ),
              Text(
                widget.evaluation.severity.label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: widget.color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            valStr,
            style: TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.bold,
              color: hasData ? Colors.white : Colors.white54,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            widget.evaluation.summary,
            style: const TextStyle(fontSize: 13, color: Colors.white70),
          ),
          const SizedBox(height: 6),
          Text(
            widget.metadataTag,
            style: const TextStyle(fontSize: 11, color: Colors.white38),
          ),
        ],
      ),
    );
  }

  Widget _buildContextsBreakdownCard(
      double? restAvg, double? sleepAvg, double? activityAvg) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: SpaceTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.compare_arrows, color: SpaceTheme.cyan, size: 18),
              SizedBox(width: 8),
              Text(
                'Valores Medios por Contexto Fisiológico',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildContextBox(
                  'Reposo',
                  restAvg,
                  Icons.chair,
                  Colors.blueAccent,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildContextBox(
                  'Sueño',
                  sleepAvg,
                  Icons.bedtime,
                  Colors.indigoAccent,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildContextBox(
                  'Actividad',
                  activityAvg,
                  Icons.fitness_center,
                  Colors.orangeAccent,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildContextBox(
      String label, double? val, IconData icon, Color boxColor) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: SpaceTheme.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: boxColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 18, color: boxColor),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: Colors.white60),
          ),
          const SizedBox(height: 6),
          Text(
            val != null
                ? '${val.toStringAsFixed(_unitDecimals)} ${widget.unit}'
                : 'Sin datos',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: val != null ? Colors.white : Colors.white38,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGamificationMissionCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: SpaceTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _missionCompleted ? SpaceTheme.green : SpaceTheme.cyan.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    _missionCompleted
                        ? Icons.military_tech
                        : Icons.stars_rounded,
                    color: _missionCompleted ? SpaceTheme.green : SpaceTheme.cyan,
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Misión: Autoconocimiento Vital',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: (_missionCompleted ? SpaceTheme.green : SpaceTheme.cyan)
                      .withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _missionCompleted ? '+50 XP Cumplido' : 'En progreso',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: _missionCompleted ? SpaceTheme.green : SpaceTheme.cyan,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Comprender tus indicadores reduce riesgos de misión y optimiza las contramedidas de salud espacial.',
            style: TextStyle(fontSize: 12, color: Colors.white70),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: _missionCompleted ? 1.0 : 0.6,
                    minHeight: 6,
                    backgroundColor: Colors.white12,
                    color: _missionCompleted ? SpaceTheme.green : SpaceTheme.cyan,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                _missionCompleted ? '100%' : '60%',
                style: const TextStyle(fontSize: 11, color: Colors.white60),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (_savedVerificationAnswers != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: SpaceTheme.green.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: SpaceTheme.green.withValues(alpha: 0.35)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: _savedVerificationAnswers!.entries
                    .map(
                      (e) => Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Text(
                          '• ${e.key}: ${e.value}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.white70,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
            const SizedBox(height: 6),
          ],
          if (!_missionCompleted)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                style: TextButton.styleFrom(
                  foregroundColor: SpaceTheme.cyan,
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: _showMissionVerificationDialog,
                icon: const Icon(Icons.quiz_outlined, size: 16),
                label: const Text('Completar Revisión de Misión'),
              ),
            ),
        ],
      ),
    );
  }

  ({String capsuleTitle, String capsuleBody, String question, List<String> options})
      _buildEducationalCheckinForVital() {
    if (widget.unit == 'lpm') {
      return (
        capsuleTitle: 'Cápsula de Salud: Pulso y Fluid Shift en 0 g',
        capsuleBody:
            'En microgravedad la sangre y líquidos corporales se redistribuyen hacia el tórax y la cabeza. Tu corazón no necesita bombear contra la gravedad, pero el aumento de volumen central hace que la frecuencia cardíaca en reposo suba normalmente entre +3 y +4 lpm.',
        question: '¿Cómo evalúas tu pulso y ritmo cardíaco en este momento?',
        options: const [
          'Ritmo regular y cómodo, acorde a mi actividad actual',
          'Noto palpitaciones leves o aceleración al moverme por los módulos',
          'Palpitaciones persistentes en reposo absoluto o sensación de arritmia',
        ],
      );
    }
    if (widget.unit == 'mg/dL') {
      return (
        capsuleTitle: 'Cápsula de Salud: Metabolismo y Energía en Vuelo',
        capsuleBody:
            'El aislamiento y la microgravedad pueden inducir resistencia periférica a la insulina, mientras que el ejercicio con ARED/CEVIS agota rápidamente el glucógeno muscular. Mantener glucemias estables evita fatiga súbita en tareas críticas.',
        question: '¿Cuál es tu estado nutricional y energético en este turno?',
        options: const [
          'Energía óptima tras ingesta de ración programada e hidratación',
          'Ligera sensación de mareo o bajón de energía previo a comida',
          'Temblor, sudor frío o fatiga extrema (posible hipoglucemia)',
        ],
      );
    }
    if (widget.unit == '°C') {
      return (
        capsuleTitle: 'Cápsula de Salud: Termorregulación en el Espacio',
        capsuleBody:
            'Al no existir corrientes de convección térmica de aire natural, tu cuerpo acumula calor más rápido durante tareas físicas. El sensor cutáneo estima tu temperatura central sin métodos invasivos.',
        question: '¿Cómo percibes tu confort térmico corporal en este turno?',
        options: const [
          'Confort térmico adecuado, sin sensación febril ni sofoco',
          'Sensación de calor residual tras ejercicio en fase de enfriamiento',
          'Escalofríos o sensación febril marcada en reposo',
        ],
      );
    }
    return (
      capsuleTitle: 'Cápsula de Salud: Monitoreo Contextual de ${widget.title}',
      capsuleBody:
          'Las lecturas fisiológicas varían según si estás descansando, durmiendo o en plena actividad física. Interpretar cada signo vital dentro de su contexto evita falsas alarmas y optimiza el descanso.',
      question: '¿Qué condición describe mejor tu estado actual en relación a este indicador?',
      options: const [
        'Registro consistente con mi estado de reposo / actividad actual',
        'Leve desviación temporal explicable por esfuerzo o adaptación de cabina',
        'Lectura inusual acompañada de molestia física que requiere revisión médica',
      ],
    );
  }

  Future<void> _showMissionVerificationDialog() async {
    final checkin = _buildEducationalCheckinForVital();
    int? selectedCheckinIdx = 0;
    String selectedActionTaken = 'Pauta de hidratación y descanso al día';
    final noteController = TextEditingController();

    final verified = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              backgroundColor: SpaceTheme.surface,
              title: Row(
                children: [
                  Icon(Icons.school, color: widget.color, size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Autochequeo Educativo: ${widget.title}',
                      style: const TextStyle(fontSize: 15, color: Colors.white),
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Cápsula explicativa
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: SpaceTheme.card,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: SpaceTheme.cyan.withValues(alpha: 0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.lightbulb, color: SpaceTheme.cyan, size: 16),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  checkin.capsuleTitle,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: SpaceTheme.cyan,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            checkin.capsuleBody,
                            style: const TextStyle(fontSize: 11, color: Colors.white70, height: 1.3),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    Text(
                      '1. ${checkin.question}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...List.generate(checkin.options.length, (i) {
                      final isChosen = selectedCheckinIdx == i;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () => setDialogState(() {
                            selectedCheckinIdx = i;
                          }),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: isChosen
                                  ? widget.color.withValues(alpha: 0.16)
                                  : SpaceTheme.card,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isChosen
                                    ? widget.color
                                    : Colors.white12,
                              ),
                            ),
                            child: Text(
                              checkin.options[i],
                              style: TextStyle(
                                fontSize: 11,
                                color: isChosen ? Colors.white : Colors.white70,
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 12),
                    const Text(
                      '2. Acción preventiva o contramedida en curso:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 6),
                    ...[
                      'Pauta de hidratación y descanso al día',
                      'Revisión de sensores y ajuste de vestimenta biométrica',
                      'Descanso programado y notificación al equipo médico',
                    ].map((opt) {
                      final isChosen = selectedActionTaken == opt;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 5),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () =>
                              setDialogState(() => selectedActionTaken = opt),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              color: isChosen
                                  ? SpaceTheme.cyan.withValues(alpha: 0.16)
                                  : SpaceTheme.card,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isChosen ? SpaceTheme.cyan : Colors.white12,
                              ),
                            ),
                            child: Text(
                              opt,
                              style: TextStyle(
                                fontSize: 11,
                                color: isChosen ? Colors.white : Colors.white70,
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 8),
                    TextField(
                      controller: noteController,
                      style: const TextStyle(fontSize: 12, color: Colors.white),
                      decoration: const InputDecoration(
                        isDense: true,
                        labelText: 'Comentario opcional para el registro',
                        labelStyle:
                            TextStyle(fontSize: 11, color: Colors.white54),
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogCtx).pop(false),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: SpaceTheme.cyan,
                    foregroundColor: Colors.black,
                  ),
                  icon: const Icon(Icons.check_circle, size: 16),
                  label: const Text('Guardar Autochequeo (+50 XP)'),
                  onPressed: () {
                    Navigator.of(dialogCtx).pop(true);
                  },
                ),
              ],
            );
          },
        );
      },
    );

    if (verified != true || !mounted) {
      noteController.dispose();
      return;
    }

    final valStr = widget.customValueDisplay ??
        (widget.evaluation.hasData
            ? '${widget.evaluation.value!.toStringAsFixed(_unitDecimals)} ${widget.unit}'
            : 'Sin lectura');
    final extraNote = noteController.text.trim();
    noteController.dispose();

    final answers = <String, String>{
      'Autochequeo': checkin.options[selectedCheckinIdx ?? 0],
      'Acción preventiva': selectedActionTaken,
      if (extraNote.isNotEmpty) 'Observación': extraNote,
    };

    widget.onMissionLogCreated?.call(
      ClinicalMissionLogEntry(
        id: 'REV-${DateTime.now().millisecondsSinceEpoch}',
        astronautId: widget.astronautId ?? 'AST-01',
        timestamp: DateTime.now(),
        missionDay: widget.missionDay,
        environment: widget.activeEnvironment,
        category: 'Autochequeo Vital (${widget.title})',
        title: '${widget.title}: $valStr (${widget.activeContext.label})',
        summary:
            '${checkin.options[selectedCheckinIdx ?? 0]}${extraNote.isNotEmpty ? " • $extraNote" : ""}',
        answers: answers,
        badgeEarned: 'Especialista ${widget.title}',
        xpAwarded: 50,
      ),
    );

    setState(() {
      _missionCompleted = true;
      _savedVerificationAnswers = answers;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Autochequeo registrado (+50 XP) y archivado en la bitácora clínica.',
        ),
        duration: Duration(seconds: 3),
      ),
    );
  }

  List<TelemetrySamplePoint> _filterSamplesByRange(
      List<TelemetrySamplePoint> allValid) {
    if (allValid.isEmpty) return const [];
    final sorted = List<TelemetrySamplePoint>.from(allValid)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    final latest = sorted.last.timestamp;
    List<TelemetrySamplePoint> filtered;
    switch (_selectedRange) {
      case _TemporalRangeFilter.last24h:
        final cutoff = latest.subtract(const Duration(hours: 25));
        filtered =
            sorted.where((s) => !s.timestamp.isBefore(cutoff)).toList();
      case _TemporalRangeFilter.last7d:
        final cutoff = latest.subtract(const Duration(days: 7, hours: 1));
        filtered =
            sorted.where((s) => !s.timestamp.isBefore(cutoff)).toList();
      case _TemporalRangeFilter.mission18d:
        filtered = sorted;
    }

    if (filtered.length < 2 && sorted.length >= 2) {
      return sorted.sublist(sorted.length - 2);
    }
    return filtered;
  }

  ({double minY, double maxY, double interval}) _resolveChartBounds(
      List<TelemetrySamplePoint> samples) {
    final values = samples.map((s) => s.value!).toList();
    final minVal = values.reduce((a, b) => a < b ? a : b);
    final maxVal = values.reduce((a, b) => a > b ? a : b);

    double minY;
    double maxY;
    double interval;

    if (widget.unit == 'mg/dL') {
      minY = minVal < 65 ? 50.0 : 60.0;
      maxY = maxVal > 155 ? ((maxVal / 20).ceil() * 20.0) : 160.0;
      interval = 20.0;
    } else if (widget.unit == 'lpm') {
      minY = minVal < 42 ? 35.0 : 40.0;
      maxY = maxVal > 165 ? ((maxVal / 20).ceil() * 20.0) : 170.0;
      interval = 25.0;
    } else if (widget.unit == 'rpm') {
      minY = minVal < 9 ? 6.0 : 8.0;
      maxY = maxVal > 34 ? ((maxVal / 4).ceil() * 4.0) : 36.0;
      interval = 4.0;
    } else if (widget.unit == '%' && !widget.title.contains('Hidratación')) {
      minY = minVal < 86 ? 80.0 : 85.0;
      maxY = 100.0;
      interval = 3.0;
    } else if (widget.title.contains('Hidratación')) {
      minY = minVal < 48 ? 35.0 : 45.0;
      maxY = maxVal > 94 ? 100.0 : 95.0;
      interval = 10.0;
    } else if (widget.unit == 'mmHg') {
      minY = minVal < 65 ? 50.0 : 60.0;
      maxY = maxVal > 165 ? ((maxVal / 20).ceil() * 20.0) : 170.0;
      interval = 20.0;
    } else if (widget.unit == 's') {
      minY = 0.5;
      maxY = maxVal > 3.8 ? 5.0 : 4.0;
      interval = 0.5;
    } else if (widget.unit == '°C') {
      minY = 35.0;
      maxY = maxVal > 39.2 ? 40.5 : 39.5;
      interval = 0.5;
    } else {
      // ms (HRV)
      minY = 10.0;
      maxY = maxVal > 105 ? ((maxVal / 20).ceil() * 20.0) : 110.0;
      interval = 20.0;
    }

    return (minY: minY, maxY: maxY, interval: interval);
  }

  Widget _buildChartsCard(List<TelemetrySamplePoint> validSamples) {
    final displaySamples = _filterSamplesByRange(validSamples);
    final selectedIdx = displaySamples.isEmpty
        ? null
        : (_selectedSampleIndex ?? (displaySamples.length - 1))
            .clamp(0, displaySamples.length - 1);
    final selectedSample =
        selectedIdx != null ? displaySamples[selectedIdx] : null;
    final bounds = displaySamples.isNotEmpty
        ? _resolveChartBounds(displaySamples)
        : (minY: 0.0, maxY: 100.0, interval: 25.0);
    final int xStep =
        displaySamples.length <= 6 ? 1 : (displaySamples.length / 5).ceil();
    final DateTime? latestTs =
        displaySamples.isNotEmpty ? displaySamples.last.timestamp : null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: SpaceTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.history, color: widget.color, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Historial Clínico y Evolución (${widget.unit})',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              Text(
                '${displaySamples.length} reg.',
                style: const TextStyle(fontSize: 11, color: Colors.white54),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _TemporalRangeFilter.values.map((filter) {
              final active = _selectedRange == filter;
              return ChoiceChip(
                label: Text(
                  filter.label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: active ? FontWeight.bold : FontWeight.normal,
                    color: active ? Colors.black : Colors.white70,
                  ),
                ),
                selected: active,
                selectedColor: widget.color,
                backgroundColor: SpaceTheme.card,
                side: BorderSide(
                  color: active ? widget.color : Colors.white12,
                ),
                visualDensity: VisualDensity.compact,
                onSelected: (_) {
                  setState(() {
                    _selectedRange = filter;
                    _selectedSampleIndex = null;
                  });
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 6),
          const Text(
            'Toca un punto de la gráfica o usa los controles para inspeccionar registros pasados por entorno y evento.',
            style: TextStyle(fontSize: 11, color: Colors.white54),
          ),
          const SizedBox(height: 14),
          if (displaySamples.isNotEmpty) ...[
            SizedBox(
              height: 185,
              child: LineChart(
                LineChartData(
                  minY: bounds.minY,
                  maxY: bounds.maxY,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: bounds.interval,
                  ),
                  borderData: FlBorderData(show: false),
                  lineTouchData: LineTouchData(
                    handleBuiltInTouches: true,
                    touchCallback: (event, response) {
                      final spots = response?.lineBarSpots;
                      if (spots != null && spots.isNotEmpty) {
                        final idx = spots.first.x.round();
                        if (idx >= 0 &&
                            idx < displaySamples.length &&
                            idx != _selectedSampleIndex) {
                          setState(() => _selectedSampleIndex = idx);
                        }
                      }
                    },
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipItems: (touchedSpots) {
                        return touchedSpots.map((spot) {
                          final idx = spot.x.round().clamp(
                              0, displaySamples.length - 1);
                          final pt = displaySamples[idx];
                          final dayTag = pt.missionDay != null
                              ? 'D${pt.missionDay}'
                              : DateFormat('dd/MM').format(pt.timestamp);
                          return LineTooltipItem(
                            '$dayTag • ${spot.y.toStringAsFixed(_unitDecimals)} ${widget.unit}\n${pt.context.label}',
                            const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          );
                        }).toList();
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        interval: bounds.interval,
                        getTitlesWidget: (val, meta) {
                          if (val > bounds.maxY + 0.01 ||
                              val < bounds.minY - 0.01) {
                            return const SizedBox.shrink();
                          }
                          final formatted = bounds.interval < 1.0
                              ? val.toStringAsFixed(1)
                              : val.toInt().toString();
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: Text(
                              formatted,
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                fontSize: 10,
                                color: Colors.white54,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 24,
                        interval: 1.0,
                        getTitlesWidget: (val, meta) {
                          final idx = val.round();
                          if ((val - idx).abs() > 0.01 ||
                              idx < 0 ||
                              idx >= displaySamples.length) {
                            return const SizedBox.shrink();
                          }
                          final isLast = idx == displaySamples.length - 1;
                          final tooCloseToLast =
                              !isLast && (displaySamples.length - 1 - idx) < (xStep / 2);
                          if ((!isLast && idx % xStep != 0) || tooCloseToLast) {
                            return const SizedBox.shrink();
                          }
                          final pt = displaySamples[idx];
                          final String label;
                          if (_selectedRange == _TemporalRangeFilter.last24h &&
                              latestTs != null) {
                            final diffH =
                                latestTs.difference(pt.timestamp).inHours;
                            label = isLast
                                ? 'Ahora'
                                : (diffH == 0
                                    ? DateFormat('HH:mm').format(pt.timestamp)
                                    : '-${diffH}h');
                          } else {
                            label = pt.missionDay != null
                                ? 'D${pt.missionDay}'
                                : DateFormat('dd/MM').format(pt.timestamp);
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              label,
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: idx == selectedIdx
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: idx == selectedIdx
                                    ? widget.color
                                    : Colors.white54,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: List.generate(
                        displaySamples.length,
                        (i) => FlSpot(i.toDouble(), displaySamples[i].value!),
                      ),
                      isCurved: true,
                      preventCurveOverShooting: true,
                      color: widget.color,
                      barWidth: 2.6,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, barData, index) {
                          final isSelected = index == selectedIdx;
                          return FlDotCirclePainter(
                            radius: isSelected ? 5.0 : 2.8,
                            color: isSelected ? Colors.white : widget.color,
                            strokeWidth: isSelected ? 2.5 : 1.0,
                            strokeColor: widget.color,
                          );
                        },
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        color: widget.color.withValues(alpha: 0.14),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (selectedSample != null && selectedIdx != null) ...[
              const SizedBox(height: 12),
              _buildPastSampleInspector(
                displaySamples: displaySamples,
                selectedIdx: selectedIdx,
                sample: selectedSample,
              ),
            ],
          ] else
            Container(
              height: 100,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: SpaceTheme.card,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'Sin muestras suficientes para graficar. Puedes capturar datos desde la cabina o registrar manualmente.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.white54),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPastSampleInspector({
    required List<TelemetrySamplePoint> displaySamples,
    required int selectedIdx,
    required TelemetrySamplePoint sample,
  }) {
    final tsLabel = DateFormat('dd/MM HH:mm').format(sample.timestamp);
    final dayLabel =
        sample.missionDay != null ? 'Día ${sample.missionDay}' : 'Histórico';
    final envLabel = sample.environment?.label ?? widget.activeEnvironment.label;
    final qualStr = sample.signalQualityPercent != null
        ? ' • Señal ${sample.signalQualityPercent!.toStringAsFixed(0)}%'
        : '';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: SpaceTheme.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: widget.color.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                tooltip: 'Registro anterior',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: const Icon(Icons.chevron_left, color: Colors.white70),
                onPressed: selectedIdx > 0
                    ? () => setState(() => _selectedSampleIndex = selectedIdx - 1)
                    : null,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$dayLabel • $tsLabel',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: SpaceTheme.cyan,
                      ),
                    ),
                    Text(
                      '${sample.value!.toStringAsFixed(_unitDecimals)} ${widget.unit}  •  ${sample.context.label}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: widget.color,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              IconButton(
                tooltip: 'Registro siguiente',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: const Icon(Icons.chevron_right, color: Colors.white70),
                onPressed: selectedIdx < displaySamples.length - 1
                    ? () => setState(() => _selectedSampleIndex = selectedIdx + 1)
                    : null,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Entorno: $envLabel',
            style: const TextStyle(fontSize: 11, color: Colors.white70),
          ),
          Text(
            'Sensor: ${sample.source}$qualStr',
            style: const TextStyle(fontSize: 11, color: Colors.white54),
          ),
          if (sample.clinicalEventNote != null &&
              sample.clinicalEventNote!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: SpaceTheme.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white12),
              ),
              child: Text(
                sample.clinicalEventNote!,
                style: const TextStyle(fontSize: 11, color: Colors.white70),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEducationalInstructionsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: SpaceTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.menu_book_rounded, color: SpaceTheme.cyan, size: 18),
              SizedBox(width: 8),
              Text(
                'Guía de Instrucciones Simples para el Astronauta',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildStepRow(
            '1. ¿Cómo se mide?',
            widget.howToMeasure,
            Icons.straighten,
            Colors.tealAccent,
          ),
          const SizedBox(height: 10),
          _buildStepRow(
            '2. ¿Qué significa según tu actividad?',
            widget.contextMeaning,
            Icons.psychology_alt,
            Colors.orangeAccent,
          ),
          const SizedBox(height: 10),
          _buildStepRow(
            '3. ¿Cuándo prestar atención o reportar?',
            widget.whenToPayAttention,
            Icons.health_and_safety,
            Colors.redAccent,
          ),
        ],
      ),
    );
  }

  Widget _buildStepRow(
      String heading, String content, IconData icon, Color iconColor) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: SpaceTheme.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: iconColor.withValues(alpha: 0.15),
            child: Icon(icon, size: 16, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  heading,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  content,
                  style: const TextStyle(fontSize: 12, color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScientificReferenceCard(ScientificCriterion criterion) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: SpaceTheme.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Base Científica y Trazabilidad',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Fuente: ${criterion.source} (v${criterion.version})',
            style: const TextStyle(fontSize: 10, color: Colors.white54),
          ),
          Text(
            'Limitaciones: ${criterion.limitations}',
            style: const TextStyle(fontSize: 10, color: Colors.white38),
          ),
        ],
      ),
    );
  }
}
