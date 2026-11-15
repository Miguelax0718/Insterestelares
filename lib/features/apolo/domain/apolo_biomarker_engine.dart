import 'dart:math' as math;

import 'apolo_models.dart';

class ApoloRenalRisk {
  const ApoloRenalRisk({
    required this.outOfRangeCount,
    required this.label,
    required this.score,
    required this.outOfRange,
    required this.inRange,
  });

  final int outOfRangeCount;
  final String label; // 'Low' | 'Moderate' | 'High'
  final double score;
  final List<String> outOfRange;
  final List<String> inRange;
}

class ApoloModuleMeta {
  const ApoloModuleMeta({
    required this.id,
    required this.title,
    required this.shortLabel,
    required this.measures,
    required this.whyItMatters,
    required this.biomarkerIds,
    required this.primaryBiomarkerId,
    required this.relatedModules,
  });

  final ApoloModuleId id;
  final String title;
  final String shortLabel;
  final String measures;
  final String whyItMatters;
  final List<String> biomarkerIds;
  final String primaryBiomarkerId;
  final List<ApoloModuleId> relatedModules;
}

abstract final class ApoloBiomarkerEngine {
  static const List<String> defaultSampleTimes = ['07:30', '15:30'];

  static const Map<String, ApoloBiomarkerDef> catalog = {
    'vol': ApoloBiomarkerDef(
      id: 'vol',
      name: '24h volume',
      unit: 'L',
      decimals: 2,
      min: 0,
      max: 3.5,
      lo: 1.6,
      hi: 2.5,
    ),
    'dens': ApoloBiomarkerDef(
      id: 'dens',
      name: 'Specific gravity',
      unit: '',
      decimals: 3,
      min: 1,
      max: 1.035,
      lo: 1.005,
      hi: 1.025,
    ),
    'osm': ApoloBiomarkerDef(
      id: 'osm',
      name: 'Osmolality',
      unit: 'mOsm/kg',
      decimals: 0,
      min: 50,
      max: 1200,
      lo: 300,
      hi: 800,
    ),
    'color': ApoloBiomarkerDef(
      id: 'color',
      name: 'Color (1-8)',
      unit: 'shade',
      decimals: 0,
      min: 1,
      max: 8,
      lo: 1,
      hi: 4,
    ),
    'ca': ApoloBiomarkerDef(
      id: 'ca',
      name: 'Urinary calcium',
      unit: 'mg/day',
      decimals: 0,
      min: 0,
      max: 400,
      lo: 100,
      hi: 250,
    ),
    'ox': ApoloBiomarkerDef(
      id: 'ox',
      name: 'Oxalate',
      unit: 'mg/day',
      decimals: 0,
      min: 0,
      max: 60,
      lo: 10,
      hi: 40,
    ),
    'cit': ApoloBiomarkerDef(
      id: 'cit',
      name: 'Citrate',
      unit: 'mg/day',
      decimals: 0,
      min: 0,
      max: 1200,
      lo: 450,
      hi: 1000,
    ),
    'ua': ApoloBiomarkerDef(
      id: 'ua',
      name: 'Uric acid',
      unit: 'mg/day',
      decimals: 0,
      min: 0,
      max: 1000,
      lo: 250,
      hi: 750,
    ),
    'ph': ApoloBiomarkerDef(
      id: 'ph',
      name: 'pH',
      unit: '',
      decimals: 1,
      min: 4.5,
      max: 8,
      lo: 5.8,
      hi: 6.8,
    ),
    'ntx': ApoloBiomarkerDef(
      id: 'ntx',
      name: 'NTx',
      unit: 'nmol BCE/mmol',
      decimals: 0,
      min: 0,
      max: 100,
      lo: 20,
      hi: 60,
    ),
    'ctx': ApoloBiomarkerDef(
      id: 'ctx',
      name: 'CTx',
      unit: 'µg/g',
      decimals: 0,
      min: 0,
      max: 800,
      lo: 150,
      hi: 500,
    ),
    'ohdg': ApoloBiomarkerDef(
      id: 'ohdg',
      name: '8-OHdG',
      unit: 'ng/mg creat.',
      decimals: 1,
      min: 0,
      max: 14,
      lo: 2,
      hi: 8,
    ),
    'iso': ApoloBiomarkerDef(
      id: 'iso',
      name: 'Isoprostanes',
      unit: 'ng/mg creat.',
      decimals: 2,
      min: 0,
      max: 2.2,
      lo: 0.3,
      hi: 1.2,
    ),
    'leu': ApoloBiomarkerDef(
      id: 'leu',
      name: 'Leukocytes',
      unit: '/HPF',
      decimals: 0,
      min: 0,
      max: 15,
      lo: 0,
      hi: 5,
    ),
    'nit': ApoloBiomarkerDef(id: 'nit', name: 'Nitrites', isBoolean: true),
    'bld': ApoloBiomarkerDef(id: 'bld', name: 'Blood', isBoolean: true),
    'cort': ApoloBiomarkerDef(
      id: 'cort',
      name: 'Free cortisol',
      unit: 'µg/day',
      decimals: 0,
      min: 0,
      max: 120,
      lo: 20,
      hi: 70,
    ),
    'mel': ApoloBiomarkerDef(
      id: 'mel',
      name: '6-sulfatoxymelatonin',
      unit: 'µg/day',
      decimals: 0,
      min: 0,
      max: 50,
      lo: 10,
      hi: 35,
    ),
    'na': ApoloBiomarkerDef(
      id: 'na',
      name: 'Sodium',
      unit: 'mmol/day',
      decimals: 0,
      min: 0,
      max: 300,
      lo: 100,
      hi: 200,
    ),
    'k': ApoloBiomarkerDef(
      id: 'k',
      name: 'Potassium',
      unit: 'mmol/day',
      decimals: 0,
      min: 0,
      max: 140,
      lo: 50,
      hi: 100,
    ),
    'nak': ApoloBiomarkerDef(
      id: 'nak',
      name: 'Na/K ratio',
      unit: '',
      decimals: 1,
      min: 0,
      max: 5,
      lo: 1,
      hi: 3,
      isDerived: true,
    ),
    'acr': ApoloBiomarkerDef(
      id: 'acr',
      name: 'Albumin/creatinine',
      unit: 'mg/g',
      decimals: 0,
      min: 0,
      max: 60,
      lo: 0,
      hi: 30,
    ),
    'glu': ApoloBiomarkerDef(id: 'glu', name: 'Glucose', isBoolean: true),
    'ket': ApoloBiomarkerDef(id: 'ket', name: 'Ketones', isBoolean: true),
    'prot': ApoloBiomarkerDef(
      id: 'prot',
      name: 'Protein',
      unit: 'mg/day',
      decimals: 0,
      min: 0,
      max: 250,
      lo: 0,
      hi: 150,
    ),
    'urea': ApoloBiomarkerDef(
      id: 'urea',
      name: 'Urea',
      unit: 'g/day',
      decimals: 0,
      min: 0,
      max: 40,
      lo: 12,
      hi: 30,
    ),
    'crea': ApoloBiomarkerDef(
      id: 'crea',
      name: 'Creatinine',
      unit: 'g/day',
      decimals: 1,
      min: 0,
      max: 3,
      lo: 1,
      hi: 2,
    ),
  };

  static const Map<ApoloModuleId, ApoloModuleMeta> moduleMeta = {
    ApoloModuleId.hidratacion: ApoloModuleMeta(
      id: ApoloModuleId.hidratacion,
      title: 'Hydration',
      shortLabel: 'Water',
      measures: 'How much water your body has based on urine concentration',
      whyItMatters: 'In microgravity thirst sensation decreases and recycled water is limited. Drinking too little concentrates urine and raises the risk of kidney stones.',
      biomarkerIds: ['vol', 'dens', 'osm', 'color'],
      primaryBiomarkerId: 'vol',
      relatedModules: [ApoloModuleId.renal, ApoloModuleId.cardio],
    ),
    ApoloModuleId.renal: ApoloModuleMeta(
      id: ApoloModuleId.renal,
      title: 'Renal risk',
      shortLabel: 'Kidneys',
      measures: 'Likelihood of kidney stone formation from urinary minerals',
      whyItMatters: 'Bone loss in microgravity releases calcium into urine. Combined with low fluid intake, calcium concentrates and forms crystals. A kidney stone mid-mission is a serious emergency.',
      biomarkerIds: ['ca', 'ox', 'cit', 'ua', 'ph', 'vol'],
      primaryBiomarkerId: 'ca',
      relatedModules: [ApoloModuleId.hidratacion, ApoloModuleId.osea],
    ),
    ApoloModuleId.osea: ApoloModuleMeta(
      id: ApoloModuleId.osea,
      title: 'Bone health',
      shortLabel: 'Bones',
      measures: 'Rate at which your bones are losing mineral',
      whyItMatters: 'Without gravity loading, bones lose 1 to 1.5% of their mass per month. Daily resistive exercise is the primary countermeasure.',
      biomarkerIds: ['ntx', 'ctx'],
      primaryBiomarkerId: 'ntx',
      relatedModules: [ApoloModuleId.renal, ApoloModuleId.metabolismo],
    ),
    ApoloModuleId.radiacion: ApoloModuleMeta(
      id: ApoloModuleId.radiacion,
      title: 'Radiation',
      shortLabel: 'Radiation',
      measures: 'Cumulative dose and your body\'s oxidative damage response',
      whyItMatters: 'Outside Earth\'s protection, cosmic rays and solar storms damage DNA. Urine biomarkers show how much oxidative damage your body is repairing.',
      biomarkerIds: ['ohdg', 'iso'],
      primaryBiomarkerId: 'ohdg',
      relatedModules: [ApoloModuleId.inmunidad],
    ),
    ApoloModuleId.inmunidad: ApoloModuleMeta(
      id: ApoloModuleId.inmunidad,
      title: 'Immunity',
      shortLabel: 'Immunity',
      measures: 'Signs of infection and status of your immune defenses',
      whyItMatters: 'Isolation, stress, and radiation weaken the immune system, and latent viruses can reactivate. Catching an infection early prevents complications.',
      biomarkerIds: ['leu', 'nit', 'bld'],
      primaryBiomarkerId: 'leu',
      relatedModules: [ApoloModuleId.estres, ApoloModuleId.radiacion],
    ),
    ApoloModuleId.cardio: ApoloModuleMeta(
      id: ApoloModuleId.cardio,
      title: 'Cardiovascular',
      shortLabel: 'Heart',
      measures: 'Salt and fluid balance affecting your heart',
      whyItMatters: 'In microgravity fluids shift toward the head and the heart works differently. Excess sodium retains fluid and strains the cardiovascular system.',
      biomarkerIds: ['na', 'k', 'nak', 'acr'],
      primaryBiomarkerId: 'na',
      relatedModules: [ApoloModuleId.hidratacion],
    ),
    ApoloModuleId.estres: ApoloModuleMeta(
      id: ApoloModuleId.estres,
      title: 'Stress & sleep',
      shortLabel: 'Sleep',
      measures: 'Stress and sleep hormones plus your own log',
      whyItMatters: 'Months of isolation, altered light cycles, and heavy workloads disrupt sleep and mood. Protecting them safeguards performance and health.',
      biomarkerIds: ['cort', 'mel'],
      primaryBiomarkerId: 'cort',
      relatedModules: [ApoloModuleId.inmunidad],
    ),
    ApoloModuleId.metabolismo: ApoloModuleMeta(
      id: ApoloModuleId.metabolismo,
      title: 'Metabolism',
      shortLabel: 'Energy',
      measures: 'Energy and nutrients your body is currently using',
      whyItMatters: 'Eating less than needed is common on long missions. When energy is lacking, the body breaks down muscle and fat and ketones appear in urine.',
      biomarkerIds: ['glu', 'ket', 'prot', 'urea', 'crea'],
      primaryBiomarkerId: 'prot',
      relatedModules: [ApoloModuleId.osea, ApoloModuleId.cardio],
    ),
  };

  static double? valueOf(
    List<ApoloUrineSample> samples,
    String key, {
    int? sampleIndex,
  }) {
    if (samples.isEmpty) return null;
    final idx = sampleIndex ?? (samples.length - 1);
    if (idx < 0 || idx >= samples.length) return null;
    final values = samples[idx].values;
    if (key == 'nak') {
      final na = values['na'];
      final k = values['k'];
      if (na == null || k == null || k == 0) return null;
      return double.parse((na / k).toStringAsFixed(1));
    }
    return values[key];
  }

  static ({double lo, double hi}) rangeOf(
    String key, {
    Map<String, ({double lo, double hi})> personalRanges = const {},
  }) {
    final override = personalRanges[key];
    if (override != null) return override;
    final def = catalog[key];
    if (def == null) return (lo: 0, hi: 1);
    return (lo: def.lo, hi: def.hi);
  }

  static ApoloSeverity severityOf(
    List<ApoloUrineSample> samples,
    String key, {
    int? sampleIndex,
    Map<String, ({double lo, double hi})> personalRanges = const {},
  }) {
    final def = catalog[key];
    if (def == null) return ApoloSeverity.ok;
    final v = valueOf(samples, key, sampleIndex: sampleIndex);
    if (v == null) return ApoloSeverity.ok;
    if (def.isBoolean) {
      return v > 0 ? ApoloSeverity.warn : ApoloSeverity.ok;
    }
    final (:lo, :hi) = rangeOf(key, personalRanges: personalRanges);
    if (v > hi * 1.35 || (lo > 0 && v < lo * 0.65)) {
      return ApoloSeverity.crit;
    }
    if (v < lo || v > hi) {
      return ApoloSeverity.warn;
    }
    return ApoloSeverity.ok;
  }

  static List<double> seriesOf(
    List<ApoloUrineSample> samples,
    String key,
    int count,
  ) {
    if (samples.isEmpty || count <= 0) return const [];
    final start = math.max(0, samples.length - count);
    final out = <double>[];
    for (var i = start; i < samples.length; i++) {
      final v = valueOf(samples, key, sampleIndex: i);
      if (v != null) out.add(v);
    }
    return out;
  }

  static String formatValue(String key, double? value) {
    if (value == null) return '—';
    final def = catalog[key];
    if (def == null) return value.toString();
    if (def.isBoolean) {
      return value > 0 ? 'Positive' : 'Negative';
    }
    return value.toStringAsFixed(def.decimals);
  }

  static ApoloBiomarkerReading buildReading(
    List<ApoloUrineSample> samples,
    String key, {
    int? sampleIndex,
    Map<String, ({double lo, double hi})> personalRanges = const {},
  }) {
    final def = catalog[key]!;
    final idx = samples.isEmpty ? -1 : (sampleIndex ?? samples.length - 1);
    final v = valueOf(samples, key, sampleIndex: idx) ?? 0.0;
    final prev = idx > 0
        ? valueOf(samples, key, sampleIndex: idx - 1)
        : valueOf(samples, key, sampleIndex: idx);
    final (:lo, :hi) = rangeOf(key, personalRanges: personalRanges);
    final sev = severityOf(
      samples,
      key,
      sampleIndex: idx,
      personalRanges: personalRanges,
    );
    return ApoloBiomarkerReading(
      def: def,
      value: v,
      personalLo: lo,
      personalHi: hi,
      severity: sev,
      formattedValue: samples.isEmpty ? '—' : formatValue(key, v),
      previousValue: prev,
    );
  }

  static ApoloRenalRisk renalRisk(
    List<ApoloUrineSample> samples, {
    int? sampleIndex,
    Map<String, ({double lo, double hi})> personalRanges = const {},
  }) {
    const keys = ['ca', 'ox', 'cit', 'ph', 'vol'];
    final severities = [
      for (final k in keys)
        severityOf(
          samples,
          k,
          sampleIndex: sampleIndex,
          personalRanges: personalRanges,
        ),
    ];
    final out = <String>[];
    final inr = <String>[];
    for (var i = 0; i < keys.length; i++) {
      if (severities[i] != ApoloSeverity.ok) {
        out.add(keys[i]);
      } else {
        inr.add(keys[i]);
      }
    }
    if (severityOf(
          samples,
          'ua',
          sampleIndex: sampleIndex,
          personalRanges: personalRanges,
        ) ==
        ApoloSeverity.ok) {
      inr.add('ua');
    }
    final n = out.length;
    final hasCrit = severities.contains(ApoloSeverity.crit);
    final label = (hasCrit || n >= 5) ? 'High' : (n >= 2 ? 'Moderate' : 'Low');
    final score = math.min(1.0, (n / 5.0) * 0.8 + (hasCrit ? 0.2 : 0.0));
    return ApoloRenalRisk(
      outOfRangeCount: n,
      label: label,
      score: score,
      outOfRange: out,
      inRange: inr,
    );
  }

  static int boneResorptionPct(
    List<ApoloUrineSample> samples, {
    int? sampleIndex,
  }) {
    if (samples.isEmpty) return 0;
    final baselineCount = math.min(10, samples.length);
    var sum = 0.0;
    var count = 0;
    for (var i = 0; i < baselineCount; i++) {
      final v = valueOf(samples, 'ntx', sampleIndex: i);
      if (v != null) {
        sum += v;
        count++;
      }
    }
    if (count == 0) return 0;
    final baseline = sum / count;
    final current = valueOf(samples, 'ntx', sampleIndex: sampleIndex);
    if (baseline == 0 || current == null) return 0;
    return ((current / baseline - 1.0) * 100.0).round();
  }

  static bool hasInfectionSigns(
    List<ApoloUrineSample> samples, {
    int? sampleIndex,
    Map<String, ({double lo, double hi})> personalRanges = const {},
  }) {
    final nit = valueOf(samples, 'nit', sampleIndex: sampleIndex) ?? 0.0;
    final bld = valueOf(samples, 'bld', sampleIndex: sampleIndex) ?? 0.0;
    final leuSev = severityOf(
      samples,
      'leu',
      sampleIndex: sampleIndex,
      personalRanges: personalRanges,
    );
    return nit > 0 || bld > 0 || leuSev != ApoloSeverity.ok;
  }

  static ({String word, double phase}) sleepQuality(
    double sleepHours,
    List<ApoloUrineSample> samples, {
    int? sampleIndex,
    Map<String, ({double lo, double hi})> personalRanges = const {},
  }) {
    final melSev = severityOf(
      samples,
      'mel',
      sampleIndex: sampleIndex,
      personalRanges: personalRanges,
    );
    if (sleepHours >= 7.0 && melSev == ApoloSeverity.ok) {
      return (word: 'good', phase: 1.0);
    }
    if (sleepHours >= 6.0) {
      return (word: 'fair', phase: 0.62);
    }
    return (word: 'poor', phase: 0.3);
  }

  static String stressLevel(
    List<ApoloUrineSample> samples, {
    int? sampleIndex,
    Map<String, ({double lo, double hi})> personalRanges = const {},
  }) {
    return severityOf(
              samples,
              'cort',
              sampleIndex: sampleIndex,
              personalRanges: personalRanges,
            ) ==
            ApoloSeverity.ok
        ? 'low'
        : 'high';
  }

  static ApoloSeverity moduleSeverity(
    ApoloModuleId id, {
    required List<ApoloUrineSample> samples,
    required int waterMlToday,
    required int waterGoalMl,
    required bool solarStormActive,
    int? sampleIndex,
    Map<String, ({double lo, double hi})> personalRanges = const {},
  }) {
    final meta = moduleMeta[id]!;
    final isLatest = sampleIndex == null || sampleIndex == samples.length - 1;
    var sev = ApoloSeverity.worst([
      for (final k in meta.biomarkerIds)
        severityOf(
          samples,
          k,
          sampleIndex: sampleIndex,
          personalRanges: personalRanges,
        ),
    ]);
    if (isLatest) {
      if (id == ApoloModuleId.hidratacion && waterMlToday >= waterGoalMl) {
        sev = ApoloSeverity.ok;
      }
      if (id == ApoloModuleId.radiacion && solarStormActive) {
        sev = ApoloSeverity.crit;
      }
    }
    return sev;
  }

  static Map<ApoloModuleId, ApoloModuleSnapshot> buildModules({
    required List<ApoloUrineSample> samples,
    required int waterMlToday,
    required int waterGoalMl,
    required double doseMsv,
    required double doseLimitMsv,
    required double sleepHours,
    required bool solarStormActive,
    required List<ApoloRecommendation> recommendations,
    Map<String, ({double lo, double hi})> personalRanges = const {},
  }) {
    final renal = renalRisk(samples, personalRanges: personalRanges);
    final resorp = boneResorptionPct(samples);
    final infected = hasInfectionSigns(samples, personalRanges: personalRanges);
    final sleepQ = sleepQuality(
      sleepHours,
      samples,
      personalRanges: personalRanges,
    );
    final stress = stressLevel(samples, personalRanges: personalRanges);
    final nakText = samples.isEmpty
        ? '—'
        : formatValue('nak', valueOf(samples, 'nak'));
    final ketPositive = (valueOf(samples, 'ket') ?? 0) > 0;

    final result = <ApoloModuleId, ApoloModuleSnapshot>{};

    for (final id in ApoloModuleId.values) {
      final meta = moduleMeta[id]!;
      final sev = moduleSeverity(
        id,
        samples: samples,
        waterMlToday: waterMlToday,
        waterGoalMl: waterGoalMl,
        solarStormActive: solarStormActive,
        personalRanges: personalRanges,
      );

      final (keyMetric, subMetric) = switch (id) {
        ApoloModuleId.hidratacion => (
          '${(waterMlToday / 1000).toStringAsFixed(1)} L',
          'of ${(waterGoalMl / 1000).toStringAsFixed(1)} L today',
        ),
        ApoloModuleId.renal => (
          renal.label,
          renal.outOfRangeCount > 0
              ? '${renal.outOfRangeCount} factor${renal.outOfRangeCount > 1 ? 's' : ''} out of range'
              : 'all in range',
        ),
        ApoloModuleId.osea => (
          '${resorp >= 0 ? '+' : ''}$resorp %',
          'resorption vs. baseline',
        ),
        ApoloModuleId.radiacion => (
          '${_compactNum(doseMsv)} mSv',
          'of ${_compactNum(doseLimitMsv)} mSv limit',
        ),
        ApoloModuleId.inmunidad => (
          infected ? 'Watch' : 'Stable',
          infected
              ? 'possible urinary tract infection'
              : 'no signs of infection',
        ),
        ApoloModuleId.cardio => ('Na/K $nakText', 'electrolyte balance'),
        ApoloModuleId.estres => (
          formatHoursMinutes(sleepHours, shortMinutes: true),
          'sleep ${sleepQ.word} · stress $stress',
        ),
        ApoloModuleId.metabolismo => (
          ketPositive ? 'Ketones' : 'No ketones',
          ketPositive ? 'insufficient energy' : 'sufficient energy',
        ),
      };

      final readings = [
        for (final bmId in meta.biomarkerIds)
          buildReading(samples, bmId, personalRanges: personalRanges),
      ];
      final primaryDef = catalog[meta.primaryBiomarkerId]!;
      final trend = seriesOf(samples, meta.primaryBiomarkerId, 14);
      final modRecs = recommendations
          .where((r) => r.moduleId == id)
          .toList(growable: false);

      result[id] = ApoloModuleSnapshot(
        id: id,
        title: meta.title,
        shortLabel: meta.shortLabel,
        measures: meta.measures,
        whyItMatters: meta.whyItMatters,
        severity: sev,
        keyMetric: keyMetric,
        subMetric: subMetric,
        primaryBiomarkerId: meta.primaryBiomarkerId,
        primaryBiomarkerName: primaryDef.name,
        biomarkers: List<ApoloBiomarkerReading>.unmodifiable(readings),
        trendValues: List<double>.unmodifiable(trend),
        recommendations: List<ApoloRecommendation>.unmodifiable(modRecs),
        relatedModules: meta.relatedModules,
      );
    }

    return Map<ApoloModuleId, ApoloModuleSnapshot>.unmodifiable(result);
  }

  static ApoloSeverity overallSeverity(
    Map<ApoloModuleId, ApoloModuleSnapshot> modules,
  ) {
    return ApoloSeverity.worst(modules.values.map((m) => m.severity));
  }

  static ApoloSampleScheduleState sampleSchedule(
    DateTime now, {
    required List<ApoloUrineSample> samples,
    DateTime? lastSubmittedAt,
    List<String> sampleTimes = defaultSampleTimes,
  }) {
    final times =
        (sampleTimes.isNotEmpty ? sampleTimes : defaultSampleTimes).map((raw) {
          final parts = raw.split(':');
          final h = int.tryParse(parts.first) ?? 7;
          final m = parts.length > 1 ? (int.tryParse(parts[1]) ?? 30) : 0;
          return (hour: h, minute: m);
        }).toList()..sort(
          (a, b) => (a.hour * 60 + a.minute).compareTo(b.hour * 60 + b.minute),
        );

    DateTime atOffset(int dayOffset, int h, int m) {
      return now.isUtc
          ? DateTime.utc(now.year, now.month, now.day + dayOffset, h, m)
          : DateTime(now.year, now.month, now.day + dayOffset, h, m);
    }

    final slots = <DateTime>[
      for (final off in const [-1, 0, 1])
        for (final t in times) atOffset(off, t.hour, t.minute),
    ];

    final previousSlot = slots.lastWhere(
      (d) => !d.isAfter(now),
      orElse: () => slots.first,
    );
    final nextSlot = slots.firstWhere(
      (d) => d.isAfter(now),
      orElse: () => slots.last,
    );

    final last =
        lastSubmittedAt ?? (samples.isNotEmpty ? samples.last.takenAt : null);
    final isFirst = samples.isEmpty;
    final isDue = isFirst || last == null || last.isBefore(previousSlot);

    final spanMs = nextSlot.difference(previousSlot).inMilliseconds;
    final elapsedMs = now.difference(previousSlot).inMilliseconds;
    final progress = isDue
        ? 1.0
        : (spanMs <= 0 ? 1.0 : (elapsedMs / spanMs).clamp(0.0, 1.0));

    final remaining = nextSlot.difference(now);
    final remMinutes = math.max(1, (remaining.inSeconds / 60).round());
    final remH = remMinutes ~/ 60;
    final remM = remMinutes % 60;
    final shortLabel = isDue
        ? 'Now'
        : (remH > 0 ? '${remH}h ${remM}m' : '${remMinutes}m');

    final sameDay =
        nextSlot.year == now.year &&
        nextSlot.month == now.month &&
        nextSlot.day == now.day;
    final dayWord = sameDay ? 'today' : 'tomorrow';

    final title = isDue
        ? (isFirst ? 'Log your first sample' : 'Sample due now')
        : 'Next sample in ${formatDuration(remaining)}';
    final subtitle = isDue
        ? (isFirst
              ? 'Creates your personal baseline'
              : 'Due since ${_hhmm(previousSlot)} · ${formatDuration(now.difference(previousSlot))} ago')
        : 'Scheduled $dayWord at ${_hhmm(nextSlot)}';

    return ApoloSampleScheduleState(
      isDue: isDue,
      isFirstSample: isFirst,
      previousSlot: previousSlot,
      nextSlot: nextSlot,
      progress: progress,
      shortLabel: shortLabel,
      title: title,
      subtitle: subtitle,
    );
  }

  static String formatHoursMinutes(double hours, {bool shortMinutes = false}) {
    final wholeH = hours.floor();
    final mins = ((hours - wholeH) * 60).round();
    final padded = mins.toString().padLeft(2, '0');
    return shortMinutes ? '$wholeH h $padded m' : '$wholeH h $padded min';
  }

  static String formatDuration(Duration duration) {
    final totalMin = math.max(0, (duration.inSeconds / 60).round());
    if (totalMin < 1) return 'less than 1 min';
    final h = totalMin ~/ 60;
    final r = totalMin % 60;
    if (h > 0) {
      return r > 0 ? '$h h $r min' : '$h h';
    }
    return '$r min';
  }

  static String _hhmm(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  static String _compactNum(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    return value.toStringAsFixed(1);
  }
}
