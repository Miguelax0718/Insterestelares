import 'package:astramed/features/05_clinical_triage/data/medical_procedures_data.dart';
import 'package:astramed/features/01_general_health/agent/general_health_skills.dart';
import 'package:astramed/features/05_clinical_triage/models/triage_decision.dart';
import 'package:astramed/features/agent/domain/agent_contracts.dart';
import 'package:astramed/features/agent/domain/guided_assessment_catalog.dart';
import 'package:astramed/features/apolo/domain/apolo_models.dart';
import 'package:astramed/features/apolo/providers/apolo_contract_providers.dart';
import 'package:astramed/features/crew/models/astronaut_profile.dart';
import 'package:astramed/features/crew/presentation/providers/crew_provider.dart';

/// Skill siempre activo que conecta el asistente APOLO con:
/// 1) Tarjetas clínicas y orbes APOLO sin navegación al dashboard antiguo,
/// 2) Búsqueda offline del catálogo maestro de 10 procedimientos médicos (incl. Radiación, SAS/SMS, SANS, RCP),
/// 3) Guías paso a paso para medición manual de signos vitales sin sensores.
AgentSkill clinicalNavigationAndProceduresSkill() {
  return const AgentSkill(
    id: 'clinical_navigation_and_procedures',
    alwaysOn: true,
    instructions:
        'You are the central interactive astronaut health assistant in AstraMed / APOLO. '
         'Open APOLO cockpit cards, never the legacy dashboard. When the user asks to open the clinical terminal or a capability '
        '(General Health, Radiation, Microgravity/SMS/SANS, Mental Health/Sleep, Triage/Procedures), '
        'or asks to open manual measurement mode, ALWAYS call `open_clinical_terminal` instead of `show_component(crew_status)`. '
        'When the user asks how to manually measure vital signs (pulse, respiratory rate, capillary refill, temperature, blood pressure) '
        'call `get_manual_vitals_guide(open_manual_tool: false)` and clearly explain the anatomical measurement steps. '
        'Do not reopen the manual vitals form for how-to questions; only open it when explicitly requested. '
        'When the user asks for emergency or clinical procedures, radiation sickness (ARS), SAS/SMS space motion sickness, SANS neuro-ocular syndrome, '
        'hypoxia, hypercapnia, CPR, or first-aid kit items, call `search_medical_procedures`.',
    tools: [
      _OpenClinicalTerminalTool(),
      _SearchMedicalProceduresTool(),
      _GetManualVitalsGuideTool(),
    ],
    componentIds: [ComponentIds.statusReport, ComponentIds.telemetryChart,
      ComponentIds.vitalsCard, ComponentIds.spaceWeatherAlert,
      ComponentIds.pvtTest, MicrogravityCockpitIds.zeroGHorizon,
      ApoloCockpitIds.manualVitals, ApoloCockpitIds.medicalProcedures,
      ApoloCockpitIds.missionSimulator],
    triggers: [
      'grafica vitales',
      'gráfica vitales',
      'vitals trend',
      'procedimientos',
      'procedures',
      'simulador',
      'simulator',
      'abre la terminal',
      'abrir terminal',
      'abrir la terminal',
      'terminal clinica',
      'terminal médica',
      'terminal medica',
      'open terminal',
      'open clinical terminal',
      'abre el dashboard',
      'abrir dashboard',
      'open dashboard',
      'abre los modulos',
      'abre los módulos',
      'abrir modulos',
      'abrir módulos',
      'open modules',
      'abre salud general',
      'abre radiacion',
      'abre radiación',
      'abre microgravedad',
      'abre salud mental',
      'abre sueno',
      'abre sueño',
      'abre triage',
      'abre procedimientos',
      'toma manual',
      'medicion manual',
      'medición manual',
      'medir manualmente',
      'medir pulso',
      'tomar pulso',
      'como tomar',
      'cómo tomar',
      'como medir',
      'cómo medir',
      'signos vitales manualmente',
      'sin sensores',
      'llenado capilar',
      'manual vitals',
      'take pulse',
      'measure pulse',
      'record manual vitals',
      'protocolo sas',
      'protocolo sms',
      'protocolo sans',
      'protocolo radiacion',
      'protocolo radiación',
      'protocolo rcp',
      'procedimiento medico',
      'procedimiento médico',
      'primeros auxilios',
      'botiquin',
      'botiquín',
      'protocol',
      'first aid',
      'medical kit',
      'cpr',
      'how to measure',
      'how do i measure',
      'measure vital signs manually',
      'without sensors',
    ],
    offlineFlow: ClinicalNavigationOfflineFlow(),
  );
}

AstronautProfile? _resolveActiveAstronaut(ToolContext ctx, [String? explicitId]) {
  List<AstronautProfile> crew;
  try {
    crew = ctx.read<List<AstronautProfile>>(crewMembersProvider);
  } catch (_) {
    return null;
  }
  if (crew.isEmpty) return null;

  String targetId = explicitId?.trim() ?? '';
  if (targetId.isEmpty) {
    try {
      targetId = ctx.read<String>(selectedAstronautIdProvider);
    } catch (_) {
      targetId = ctx.astronautId;
    }
  }
  if (targetId.isEmpty) targetId = ctx.astronautId;

  return crew.firstWhere(
    (a) => a.id == targetId,
    orElse: () => crew.first,
  );
}

AgentComponentEvent _buildStatusReportEvent(
  ToolContext ctx, {
  required String title,
  required String summary,
  String? riskLevel,
  List<String> alerts = const [],
  Map<String, String> subsystems = const {},
}) {
  final astronaut = _resolveActiveAstronaut(ctx);
  final astronautId = astronaut?.id ??
      (ctx.astronautId.isNotEmpty ? ctx.astronautId : 'AST-01');
  final astronautName = astronaut?.name ?? astronautId;
  final callsign = astronaut?.callsign ?? 'ARES';

  return AgentComponentEvent.show(ComponentIds.statusReport, {
    'title': title,
    'astronaut_id': astronautId,
    'astronaut_name': astronautName,
    'callsign': callsign,
    'risk_level': riskLevel ?? astronaut?.riskLevel.name ?? 'nominal',
    'risk_title': title,
    'summary': summary,
    'active_alerts': alerts,
    'active_flags': const <String, String>{},
    'subsystems': subsystems,
    'generated_at': ctx.now.toUtc().toIso8601String(),
  });
}

({int tabIndex, String tabLabel, ApoloModuleId? apoloOrb, bool showAllOrbs})
_resolveTarget(String rawModule) {
  final norm = _normalizeText(rawModule);
  if (norm.contains('orbe') ||
      norm.contains('circulo') ||
      norm == 'orbs' ||
      norm.contains('show_all_orbs')) {
    return (
      tabIndex: 0,
      tabLabel: 'APOLO Orbs',
      apoloOrb: null,
      showAllOrbs: true,
    );
  }

  final directOrb = switch (norm) {
    'hidratacion' || 'hydration' || 'agua' => ApoloModuleId.hidratacion,
    'renal' || 'rinon' || 'kidneys' => ApoloModuleId.renal,
    'osea' || 'hueso' || 'bones' => ApoloModuleId.osea,
    'inmunidad' || 'immunity' => ApoloModuleId.inmunidad,
    'metabolismo' || 'metabolism' => ApoloModuleId.metabolismo,
    _ => null,
  };
  if (directOrb != null) {
    return (
      tabIndex: 0,
      tabLabel: 'APOLO Orb: ${directOrb.title}',
      apoloOrb: directOrb,
      showAllOrbs: false,
    );
  }

  if (norm.contains('radiacion') ||
      norm.contains('radiation') ||
      norm.contains('dosimetr')) {
    return (
      tabIndex: 1,
      tabLabel: 'Space Radiation',
      apoloOrb: null,
      showAllOrbs: false,
    );
  }
  if (norm.contains('microgravedad') ||
      norm.contains('microgravity') ||
      norm.contains('sms') ||
      norm.contains('sans') ||
      norm.contains('sas') ||
      norm.contains('vestibular') ||
      norm.contains('lbnp') ||
      norm.contains('0g')) {
    return (
      tabIndex: 2,
      tabLabel: 'Microgravity (SMS / SANS)',
      apoloOrb: null,
      showAllOrbs: false,
    );
  }
  if (norm.contains('mental') ||
      norm.contains('sueno') ||
      norm.contains('sleep') ||
      norm.contains('descanso') ||
      norm.contains('circadian')) {
    return (
      tabIndex: 3,
      tabLabel: 'Sleep and Mental Health',
      apoloOrb: null,
      showAllOrbs: false,
    );
  }
  if (norm.contains('triage') ||
      norm.contains('procedim') ||
      norm.contains('procedure') ||
      norm.contains('emergenc') ||
      norm.contains('botiquin') ||
      norm.contains('auxilios')) {
    return (
      tabIndex: 4,
      tabLabel: 'Clinical Triage and Procedures',
      apoloOrb: null,
      showAllOrbs: false,
    );
  }
  return (
    tabIndex: 0,
    tabLabel: 'General Health',
    apoloOrb: null,
    showAllOrbs: false,
  );
}

String _normalizeText(String raw) {
  return raw
      .toLowerCase()
      .replaceAll('á', 'a')
      .replaceAll('é', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ú', 'u')
      .replaceAll('ü', 'u')
      .replaceAll('ñ', 'n')
      .trim();
}

class _OpenClinicalTerminalTool extends AgentTool {
  const _OpenClinicalTerminalTool();

  @override
  String get name => 'open_clinical_terminal';

  @override
  String get description =>
      'Opens interactive APOLO cockpit cards: vitals trends, manual_vitals, '
      'medical procedures, radiation, microgravity, mental_health or simulator. '
      'Also opens APOLO module orbs. No legacy dashboard navigation.';

  @override
  ToolEffect get effect => ToolEffect.ui;

  @override
  Map<String, dynamic> get parameters => const {
        'type': 'object',
        'properties': {
          'module': {
            'type': 'string',
            'description':
                'Target card: "general_health", "vitals", "manual_vitals", "radiation", '
                    '"microgravity", "mental_health", "triage", "procedures", "simulator", or an APOLO orb ID.',
          },
          'open_manual_vitals': {
            'type': 'boolean',
            'description':
                'When true, opens the interactive APOLO Tap-to-Count card.',
          },
          'procedure_id': {
            'type': 'string',
            'description':
                'Optional MedicalProcedure ID to open in the APOLO procedures card.',
          },
        },
      };

  @override
  Future<ToolResult> call(Map<String, dynamic> args, ToolContext ctx) async {
    final rawModule = args['module']?.toString() ?? 'terminal';
    final openManual = args['open_manual_vitals'] == true ||
        _normalizeText(rawModule).contains('manual');
    final procedureId = args['procedure_id']?.toString().trim();
    final hasProcedure = procedureId != null && procedureId.isNotEmpty;

    final target = _resolveTarget(hasProcedure ? 'triage' : rawModule);

    if (target.showAllOrbs || target.apoloOrb != null) {
      try {
        final actions = ctx.read<ApoloStateActions>(apoloActionsProvider);
        if (target.showAllOrbs) {
          actions.showAllOrbs();
        } else if (target.apoloOrb != null) {
          actions.openDetail(target.apoloOrb);
        }
      } catch (_) {
        // Standalone test containers may omit apoloActionsProvider overrides;
        // report the requested orb without navigating to the legacy dashboard.
      }
      final uiEvent = _buildStatusReportEvent(
        ctx,
        title: target.tabLabel,
        summary: 'APOLO view updated: ${target.tabLabel}.',
      );
      return ToolResult.ok({
        'opened': target.tabLabel,
        'mode': 'apolo_orb',
        'apolo_orb': target.apoloOrb?.name,
        'show_all_orbs': target.showAllOrbs,
      }, uiEvents: [uiEvent]);
    }

    final simulator = _normalizeText(rawModule).contains('simula');
    final id = openManual ? ApoloCockpitIds.manualVitals
        : simulator ? ApoloCockpitIds.missionSimulator
        : switch (target.tabIndex) {
          1 => ComponentIds.statusReport,
          2 => MicrogravityCockpitIds.zeroGHorizon,
          3 => ComponentIds.pvtTest,
          4 => ApoloCockpitIds.medicalProcedures,
          _ => ComponentIds.telemetryChart,
        };
    final title = openManual ? 'Manual Vitals (Tap-to-Count)'
        : simulator ? 'Mission Simulator'
        : switch (target.tabIndex) {
          0 => 'Vitals Trend',
          1 => 'Radiation Status',
          2 => 'Zero-G Horizon (Sensorimotor)',
          3 => 'PVT Reaction Time Test',
          _ => 'Medical Procedures',
        };
    return ToolResult.ok({
      'opened': title,
      'component_id': id,
      'open_manual_vitals': openManual,
      if (hasProcedure) 'procedure_id': procedureId,
    }, uiEvents: [
      if (id != ComponentIds.statusReport) AgentComponentEvent.show(id, {
        'title': title,
        if (hasProcedure) 'procedure_id': procedureId,
        if (id == ComponentIds.telemetryChart) ...{
          'metric': 'heartRate', 'unit': 'bpm', 'series': <dynamic>[],
          'astronaut_id': _resolveActiveAstronaut(ctx)?.id ?? ctx.astronautId,
        },
      }),
      if (id == ComponentIds.telemetryChart && _resolveActiveAstronaut(ctx) != null)
        AgentComponentEvent.show(ComponentIds.vitalsCard,
          VitalsCardViewModel.fromAstronaut(_resolveActiveAstronaut(ctx)!).toProps()),
      _buildStatusReportEvent(
        ctx,
        title: title,
        summary: id == ComponentIds.statusReport
          ? 'Local dosimetry: ${_resolveActiveAstronaut(ctx)?.radiation.doseRateMicroSvPerHour} µSv/h; '
            'cumulative dose ${_resolveActiveAstronaut(ctx)?.radiation.cumulativeDoseMilliSv} mSv. '
            'This is not a live solar forecast.'
          : 'APOLO card opened: $title.',
      ),
    ]);
  }
}

class _SearchMedicalProceduresTool extends AgentTool {
  const _SearchMedicalProceduresTool();

  @override
  String get name => 'search_medical_procedures';

  @override
  String get description =>
      'Searches the 100% offline AstraMed NASA medical procedures catalog (10 protocols: '
      'cardiac arrest CPR, hypoxia/decompression, acute radiation ARS, hemodynamic syncope, CO2 hypercapnia, '
      'trauma/hemorrhage, SANS neuro-ocular, renal dehydration, SAS/SMS vestibular sickness, circadian fatigue) '
      'with step-by-step actions, warnings, and first-aid kit supplies.';

  @override
  ToolEffect get effect => ToolEffect.read;

  @override
  Map<String, dynamic> get parameters => const {
        'type': 'object',
        'properties': {
          'query': {
            'type': 'string',
            'description':
                'Condition, hazard, or symptom keywords (e.g. "radiation", "sas", "sms", "sans", "hypoxia", "cpr").',
          },
          'procedure_id': {
            'type': 'string',
            'description': 'Exact MedicalProcedure ID if known.',
          },
          'astronaut_id': {
            'type': 'string',
            'description': 'Optional astronaut ID to evaluate current vitals against protocols.',
          },
        },
      };

  @override
  Future<ToolResult> call(Map<String, dynamic> args, ToolContext ctx) async {
    final catalog = MedicalProceduresData.getProcedures();
    final scenarios = MedicalProceduresData.getScenarios();
    final procId = args['procedure_id']?.toString().trim();
    final query = _normalizeText(args['query']?.toString() ?? '');
    final astronaut = _resolveActiveAstronaut(
      ctx,
      args['astronaut_id']?.toString(),
    );

    final matches = _matchProcedures(
      query: query,
      procedureId: procId,
      catalog: catalog,
      scenarios: scenarios,
      astronaut: astronaut,
    );

    final primary = matches.first;
    final statusEvent = _buildStatusReportEvent(
      ctx,
      title: 'Protocol: ${primary.title}',
      riskLevel: _priorityToRiskLevel(primary.priority),
      summary:
          '${primary.summary} Key steps: ${primary.steps.take(3).map((s) => '${s.step}. ${s.title}').join(' | ')}',
      alerts: primary.warnings.take(2).toList(),
      subsystems: {
        'Category': primary.category,
        'Code': primary.code,
        'Medical kit': primary.requiredSupplies.map((s) => s.name).join(', '),
      },
    );

    return ToolResult.ok({
      'matched_count': matches.length,
      'primary_procedure': primary.toJson(),
      'alternatives': matches
          .skip(1)
          .take(3)
          .map((p) => {'id': p.id, 'title': p.title, 'priority': p.priority.name})
          .toList(),
    }, uiEvents: [
      AgentComponentEvent.show(ApoloCockpitIds.medicalProcedures, {
        'title': primary.title, 'procedure_id': primary.id, 'query': query,
      }),
      statusEvent,
    ]);
  }
}

class _GetManualVitalsGuideTool extends AgentTool {
  const _GetManualVitalsGuideTool();

  @override
  String get name => 'get_manual_vitals_guide';

  @override
  String get description =>
      'Provides step-by-step anatomical instructions for taking vital signs manually without electronic sensors '
      '(pulse via carotid/radial artery 15s x4, respiratory rate 30s x2, capillary refill 5s nail press <2.0s, '
       'body temperature, and blood pressure). Optionally opens the interactive APOLO Tap-to-Count card.';

  @override
  ToolEffect get effect => ToolEffect.ui;

  @override
  Map<String, dynamic> get parameters => const {
        'type': 'object',
        'properties': {
          'metric': {
            'type': 'string',
            'description':
                'Specific vital sign ("pulse", "respiration", "capillary", "temperature", "blood_pressure", or "all").',
          },
          'open_manual_tool': {
            'type': 'boolean',
            'description':
                 'If true, opens the interactive APOLO Tap-to-Count card.',
          },
        },
      };

  @override
  Future<ToolResult> call(Map<String, dynamic> args, ToolContext ctx) async {
    final metric = _normalizeText(args['metric']?.toString() ?? 'all');
    final openTool = args['open_manual_tool'] == true;

    final guides = _manualGuidesForMetric(metric);
    final summary = guides.map((g) => '${g['name']}: ${g['steps']}').join('\n');

    return ToolResult.ok({
      'metric': metric,
      'opened_manual_dialog': openTool,
      'guides': guides,
    }, uiEvents: [
      if (openTool) AgentComponentEvent.show(ApoloCockpitIds.manualVitals, {
        'title': 'Manual Vitals (Tap-to-Count)', 'metric': metric,
      }),
      _buildStatusReportEvent(
        ctx,
        title: 'Manual Vital Signs Measurement Guide',
        riskLevel: 'nominal',
        summary: summary,
        subsystems: {
          'Mode': '100% Offline / No electronic sensors',
          'Pulse formula': 'Beats in 15s × 4 = bpm (Normal 60–100)',
          'Respiration formula': 'Chest rises in 30s × 2 = breaths/min (Normal 12–20)',
          'Capillary refill': 'Press nail for 5s; refill < 2.0s is normal',
        },
      ),
    ]);
  }
}

class ClinicalNavigationOfflineFlow implements QueryAwareDeterministicFlow {
  const ClinicalNavigationOfflineFlow();

  @override
  String get skillId => 'clinical_navigation_and_procedures';

  @override
  Future<DeterministicStep> startWithQuery(String query, ToolContext ctx) =>
      advance(query, ctx);

  @override
  Future<DeterministicStep> start(ToolContext ctx) async {
    return const DeterministicStep(
      prompt:
           'I can open APOLO clinical cards, guide manual vital sign measurements, or look up emergency protocols (Radiation, SAS/SMS, SANS, CPR). What do you need?',
      options: [
        'Open Clinical Terminal',
        'How to measure vital signs manually',
        'Look up medical protocols (SAS/SMS, SANS, Radiation)',
      ],
    );
  }

  @override
  Future<DeterministicStep> advance(String userInput, ToolContext ctx) async {
    final norm = _normalizeText(userInput);

    // 1. Guías de medición manual de signos vitales
    if (norm.contains('manual') ||
        norm.contains('como tomar') ||
        norm.contains('como medir') ||
        norm.contains('medir pulso') ||
        norm.contains('tomar pulso') ||
        norm.contains('llenado capilar') ||
        norm.contains('sin sensor') ||
        norm.contains('take pulse') ||
        norm.contains('how to measure') ||
        norm.contains('how do i measure') ||
        norm.contains('measure vital signs manually') ||
        norm.contains('without sensors') ||
        norm.contains('measure pulse')) {
      final explicitOpen = norm.contains('open') || norm.contains('abre') ||
          norm.contains('abrir');
      final asksHow = norm.contains('how to') || norm.contains('how do i') ||
          norm.contains('explain') || norm.contains('como tomar') ||
          norm.contains('como medir');
      final wantsDialogOpen =
          explicitOpen || (!asksHow && (norm.contains('inicia') ||
              norm.contains('start') || norm.contains('record')));
      final res = await const _GetManualVitalsGuideTool().call({
        'metric': norm,
        'open_manual_tool': wantsDialogOpen,
      }, ctx);
      final guides = (res.data['guides'] as List<dynamic>? ?? const []);
      final lines = guides
          .map((g) => '• ${g['name']}: ${g['steps']}')
          .join('\n');
      return DeterministicStep(
        prompt:
            'Manual vital signs guide (100% offline):\n$lines'
             '${wantsDialogOpen ? '\n\nThe interactive APOLO Tap-to-Count card is open.' : ''}',
        isTerminal: true,
        uiEvents: res.uiEvents,
        verdict: res.data,
      );
    }

    // 2. Consultas de procedimientos / conocimientos médicos (SAS/SMS, SANS, Radiación, RCP)
    final isOpenIntent =
        norm.contains('abre') ||
        norm.contains('abrir') ||
        norm.contains('open') ||
        norm.contains('ir a') ||
        norm.contains('muestra');
    final isProtocolIntent =
        norm.contains('protocolo') ||
        norm.contains('procedimiento') ||
        norm.contains('primeros auxilios') ||
        norm.contains('botiquin') ||
        norm.contains('como tratar') ||
        norm.contains('que hacer') ||
        norm.contains('sas') ||
        norm.contains('sms') ||
        norm.contains('sans') ||
        norm.contains('rcp') ||
        norm.contains('protocol') ||
        norm.contains('first aid') ||
        norm.contains('medical kit') ||
        norm.contains('how to treat') ||
        norm.contains('what to do') ||
        norm.contains('cpr');

    if (isProtocolIntent && !isOpenIntent) {
      final res = await const _SearchMedicalProceduresTool().call({
        'query': norm,
      }, ctx);
      final procMap =
          res.data['primary_procedure'] as Map<String, dynamic>? ?? const {};
      final title = procMap['title']?.toString() ?? 'Medical protocol';
      final steps = (procMap['steps'] as List<dynamic>? ?? const [])
          .take(3)
          .map((s) {
            final m = s as Map;
            return '${m['step']}. ${m['title']}: ${m['action']}';
          })
          .join('\n');
      return DeterministicStep(
        prompt: '$title:\n$steps',
        isTerminal: true,
        uiEvents: res.uiEvents,
        verdict: res.data,
      );
    }

    // 3. Navegación a terminal clínica / módulos / orbes
    final openManual = norm.contains('manual');
    final res = await const _OpenClinicalTerminalTool().call({
      'module': norm,
      'open_manual_vitals': openManual,
    }, ctx);
    final label = res.data['tab_label']?.toString() ??
        res.data['opened']?.toString() ??
        'Clinical Terminal';
    return DeterministicStep(
      prompt: 'Opened $label on your screen.',
      isTerminal: true,
      uiEvents: res.uiEvents,
      verdict: res.data,
    );
  }
}

List<MedicalProcedure> _matchProcedures({
  required String query,
  required String? procedureId,
  required List<MedicalProcedure> catalog,
  required List<ClinicalScenario> scenarios,
  AstronautProfile? astronaut,
}) {
  if (procedureId != null && procedureId.isNotEmpty) {
    final exact = MedicalProceduresData.findById(procedureId, catalog);
    if (exact != null) {
      return [
        exact,
        ...catalog.where((p) => p.id != exact.id),
      ];
    }
  }

  final keywordMapping = <String, List<String>>{
    'PROC-RADIATION-ARS': ['radiac', 'radiation', 'ars', 'spe', 'tormenta solar', 'solar storm', 'dosis'],
    'PROC-VESTIBULAR-SAS': ['sas', 'sms', 'mareo', 'vertigo', 'vestibular', 'nausea'],
    'PROC-SANS-CEPHALEA': ['sans', 'ocular', 'ojo', 'cefalea', 'vista', 'papiledema', 'hiperop'],
    'PROC-CARDIAC-ARREST': ['rcp', 'cpr', 'paro', 'cardiac', 'desfibril', 'aed'],
    'PROC-HYPOXIA-DECOMP': ['hipox', 'hypox', 'spo2', 'descomp', 'oxigen', 'eva'],
    'PROC-HYPERCAPNIA-CO2': ['co2', 'hipercapn', 'hypercapn', 'eclss'],
    'PROC-TRAUMA-HEMORRHAGE': ['trauma', 'hemorrag', 'sangr', 'quemadur', 'herida'],
    'PROC-RENAL-DEHYDRATION': ['renal', 'deshidrat', 'agua', 'orina', 'colico'],
    'PROC-HEMODYNAMIC-SYNCOPE': ['sincope', 'presion', 'hipertens', 'hipotens', 'arritm'],
    'PROC-CIRCADIAN-FATIGUE': ['sueno', 'fatiga', 'insomnio', 'circadian', 'descanso'],
  };

  if (query.isNotEmpty) {
    final scored = <({MedicalProcedure proc, int score})>[];
    for (final proc in catalog) {
      var score = 0;
      final haystack = _normalizeText(
        '${proc.id} ${proc.code} ${proc.category} ${proc.title} ${proc.summary}',
      );
      for (final kw in keywordMapping[proc.id] ?? const <String>[]) {
        if (query.contains(kw)) score += 10;
      }
      for (final token in query.split(RegExp(r'\s+'))) {
        if (token.length >= 3 && haystack.contains(token)) {
          score += 3;
        }
      }
      if (score > 0) scored.add((proc: proc, score: score));
    }
    if (scored.isNotEmpty) {
      scored.sort((a, b) => b.score.compareTo(a.score));
      return scored.map((e) => e.proc).toList();
    }
  }

  if (astronaut != null) {
    final suggested = MedicalProceduresData.suggestProceduresForAstronaut(
      astronaut,
      catalog: catalog,
      scenarios: scenarios,
    );
    if (suggested.isNotEmpty) {
      return suggested.map((s) => s.procedure).toList();
    }
  }

  return catalog;
}

List<Map<String, String>> _manualGuidesForMetric(String metric) {
  final allGuides = <Map<String, String>>[
    {
      'key': 'pulse',
      'name': 'Pulse / Heart Rate (bpm)',
      'steps':
          'Place your index and middle fingers (not your thumb) over the radial artery at the wrist or carotid artery in the neck. Count beats for 15 seconds and multiply ×4. NASA normal range: 60–100 bpm.',
    },
    {
      'key': 'respiration',
      'name': 'Respiratory Rate (breaths/min)',
      'steps':
          'Count chest rises for 30 seconds at rest and multiply ×2. Normal: 12–20 breaths/min.',
    },
    {
      'key': 'capillary',
      'name': 'Capillary Refill and Perfusion (s)',
      'steps':
          'Press the nail bed for 5 seconds until it blanches, release, and time the return to pink. Normal: < 2.0 seconds.',
    },
    {
      'key': 'temperature',
      'name': 'Body Temperature (°C)',
      'steps':
          'Use a tympanic or sublingual thermometer and confirm the patient is resting. Normal: 36.0–37.2 °C (alert <35.5 or >37.8 °C).',
    },
    {
      'key': 'blood_pressure',
      'name': 'Blood Pressure (mmHg)',
      'steps':
          'Secure the body with legs uncrossed and the cuff at heart level after 5 min of rest. NASA normal range: 90–130 / 60–85 mmHg.',
    },
  ];

  if (metric.contains('puls') || metric.contains('card') || metric == 'hr') {
    return [allGuides[0]];
  }
  if (metric.contains('respir') || metric == 'rr') {
    return [allGuides[1]];
  }
  if (metric.contains('capil') || metric.contains('perfus')) {
    return [allGuides[2]];
  }
  if (metric.contains('temp') || metric.contains('fiebr')) {
    return [allGuides[3]];
  }
  if (metric.contains('pres') || metric.contains('bp') || metric.contains('tens')) {
    return [allGuides[4]];
  }
  return allGuides;
}

String _priorityToRiskLevel(TriagePriority priority) => switch (priority) {
  TriagePriority.red => 'critical',
  TriagePriority.yellow => 'warning',
  TriagePriority.green => 'nominal',
};
