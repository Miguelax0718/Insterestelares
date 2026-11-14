import '../models/biomarkers/biomarker_baseline.dart';
import '../models/contracts/bio_summary.dart';

/// Qué tan importante es un síntoma posible.
enum SymptomLevel { info, watch, alert }

/// Un síntoma que el astronauta podría notar, con la razón y la fuente.
class PossibleSymptom {
  final String title;
  final String detail;
  final String source;
  final SymptomLevel level;

  const PossibleSymptom({
    required this.title,
    required this.detail,
    required this.source,
    required this.level,
  });
}

/// Traduce la dosis y los biomarcadores a una lista de SÍNTOMAS POSIBLES para
/// vigilar. Es orientativa: no diagnostica, sirve para que el astronauta y el
/// médico sepan qué observar.
///
/// Fuentes:
/// - CDC, "Acute Radiation Syndrome: Information for Clinicians" (2024):
///   síntomas leves desde 0,3 Gy; síndrome completo desde 0,7 Gy; fase
///   inicial con náuseas, vómito y pérdida de apetito de 1 hora a 2 días
///   después; la destrucción de la médula ósea lleva a infecciones.
///   https://www.cdc.gov/radiation-emergencies/hcp/clinical-guidance/ars.html
/// - Inspiration4 (NASA OSDR): variación normal de linfocitos entre análisis
///   ~25 % y bajada de ~18 % al día siguiente de regresar, sin relación con
///   la radiación.
class SymptomAdvisor {
  const SymptomAdvisor();

  static const String cdcSource =
      'CDC, Acute Radiation Syndrome: Information for Clinicians (2024)';
  static const String i4Source = 'Inspiration4, NASA OSDR (OSD-569)';

  /// Cambio que supera la variación normal entre análisis (Inspiration4).
  static const double beyondNormal = 0.25;

  List<PossibleSymptom> evaluate({
    required BioSummary summary,
    required double speDoseGy,
    int? daysSinceSpe,
    bool returnedToEarth = false,
  }) {
    final out = <PossibleSymptom>[];

    // 1. Dosis aguda de la tormenta solar (fase inicial, hasta ~2 días).
    final earlyPhase =
        daysSinceSpe != null && daysSinceSpe >= 0 && daysSinceSpe <= 2;
    if (earlyPhase && speDoseGy >= 0.7) {
      out.add(const PossibleSymptom(
        title: 'Náuseas, vómito y pérdida de apetito',
        detail: 'La dosis de la tormenta supera 0,7 Gy. Estos síntomas suelen '
            'aparecer entre 1 hora y 2 días después. Avisar al médico de '
            'inmediato.',
        source: cdcSource,
        level: SymptomLevel.alert,
      ));
    } else if (earlyPhase && speDoseGy >= 0.3) {
      out.add(const PossibleSymptom(
        title: 'Náuseas leves o pérdida de apetito',
        detail: 'Con más de 0,3 Gy pueden aparecer síntomas leves en los días '
            'siguientes a la tormenta.',
        source: cdcSource,
        level: SymptomLevel.watch,
      ));
    }

    // 2. Defensas (linfocitos y neutrófilos).
    final lymph = summary.changeOf(Biomarker.bloodLymphocytes);
    final neut = summary.changeOf(Biomarker.bloodNeutrophils);
    final worstDrop = [
      if (lymph != null) -lymph,
      if (neut != null) -neut,
    ].fold<double>(0, (a, b) => b > a ? b : a);
    if (worstDrop >= beyondNormal) {
      final strong = worstDrop >= 0.5;
      out.add(PossibleSymptom(
        title: 'Más riesgo de infecciones',
        detail: 'Las defensas en sangre bajaron '
            '${(worstDrop * 100).toStringAsFixed(0)} %. Vigilar fiebre, dolor '
            'de garganta, tos o heridas que tardan en sanar.'
            '${returnedToEarth ? ' Al regresar a la Tierra parte de esta bajada es normal (~18 % en Inspiration4).' : ''}',
        source: strong ? '$cdcSource; $i4Source' : i4Source,
        level: strong ? SymptomLevel.alert : SymptomLevel.watch,
      ));
    }

    // 3. Inflamación (PCR).
    final crp = summary.changeOf(Biomarker.bloodCrp);
    if (crp != null && crp >= 0.5) {
      out.add(PossibleSymptom(
        title: 'Fiebre o malestar general',
        detail: 'La PCR (marcador de inflamación) subió '
            '${(crp * 100).toStringAsFixed(0)} %. Puede acompañarse de fiebre, '
            'cansancio o dolor muscular.',
        source: 'PCR: marcador general de inflamación',
        level: SymptomLevel.watch,
      ));
    }

    // 4. Estrés oxidativo en orina.
    final oxidative = [
      summary.changeOf(Biomarker.urineOhdg),
      summary.changeOf(Biomarker.urineIsoprostane),
      summary.changeOf(Biomarker.urineMda),
    ].whereType<double>().fold<double>(0, (a, b) => b > a ? b : a);
    if (oxidative >= beyondNormal) {
      out.add(PossibleSymptom(
        title: 'Estrés oxidativo alto (no da síntomas por sí solo)',
        detail: speDoseGy >= 0.3
            ? 'El estrés oxidativo subió después de una dosis alta. No suele '
                'causar síntomas por sí solo; repetir la muestra en 2–3 días.'
            : 'El estrés oxidativo subió sin una dosis alta. Lo más probable '
                'es ejercicio intenso, mal sueño o la dieta: no la radiación.',
        source: 'Matriz dosis × biomarcadores del módulo',
        level: SymptomLevel.info,
      ));
    }

    if (out.isEmpty) {
      out.add(const PossibleSymptom(
        title: 'No se esperan síntomas por radiación',
        detail: 'Los biomarcadores están dentro de la variación normal. Los '
            'riesgos de largo plazo (cáncer, cataratas, corazón) no dan '
            'síntomas inmediatos: por eso se vigila la dosis acumulada.',
        source: '$cdcSource; $i4Source',
        level: SymptomLevel.info,
      ));
    }
    return out;
  }
}
