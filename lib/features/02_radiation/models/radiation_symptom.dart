/// Qué tan pronto hay que actuar ante un síntoma.
enum SymptomLevel {
  /// Esperable en vuelo; solo se anota.
  info('Informativo'),

  /// Reportarlo en el próximo chequeo médico.
  watch('Vigilar'),

  /// Avisar al cirujano de vuelo de inmediato.
  urgent('Urgente');

  const SymptomLevel(this.label);

  final String label;
}

/// Posibles síntomas relacionados con la radiación espacial que el astronauta
/// puede marcar. Cada uno explica, en lenguaje sencillo, cuándo suele
/// aparecer, por qué ocurre y qué hacer.
///
/// Fuentes generales: CDC "Acute Radiation Syndrome: A Fact Sheet for
/// Clinicians"; HHS REMM (Radiation Emergency Medical Management); NASA Human
/// Research Program, peligro "Space Radiation". El nivel de cada síntoma es
/// ILUSTRATIVO para el prototipo, no un criterio clínico.
enum RadiationSymptom {
  lightFlashes(
    'Destellos de luz con los ojos cerrados',
    SymptomLevel.info,
    when: 'En cualquier momento del vuelo.',
    why: 'Son rayos cósmicos que atraviesan la retina. Son comunes en '
        'astronautas y no indican una dosis peligrosa.',
    action: 'Anótalo. No necesita tratamiento.',
  ),
  fatigue(
    'Cansancio o debilidad',
    SymptomLevel.watch,
    when: 'Horas o días después de una dosis alta, o por falta de sueño.',
    why: 'Puede venir del sueño o del esfuerzo. Tras una dosis alta también '
        'aparece porque se dañan células de la sangre.',
    action: 'Descansa y revisa tus horas de sueño. Si dura más de 2 días, '
        'repórtalo.',
  ),
  nausea(
    'Náuseas o pérdida de apetito',
    SymptomLevel.watch,
    when: 'Pocas horas después de una dosis alta. También en los primeros '
        'días de vuelo por mareo espacial.',
    why: 'Es de las primeras señales del cuerpo ante una dosis alta.',
    action: 'Anota a qué hora empezó y repórtalo en el próximo chequeo.',
  ),
  vomiting(
    'Vómito',
    SymptomLevel.urgent,
    when: 'Pocas horas después de una tormenta solar.',
    why: 'Cuanto antes empieza el vómito tras la exposición, mayor suele ser '
        'la dosis recibida.',
    action: 'Anota la hora exacta y avisa al cirujano de vuelo ahora.',
  ),
  diarrhea(
    'Diarrea',
    SymptomLevel.urgent,
    when: 'Horas o días después de una dosis muy alta.',
    why: 'Indica que la radiación pudo dañar el revestimiento del intestino.',
    action: 'Hidrátate y avisa al cirujano de vuelo ahora.',
  ),
  headache(
    'Dolor de cabeza',
    SymptomLevel.watch,
    when: 'En cualquier momento.',
    why: 'Suele deberse al CO₂ de la cabina o a la subida de fluidos hacia la '
        'cabeza en microgravedad. Con dosis muy altas también aparece.',
    action: 'Revisa el CO₂ de la cabina y bebe agua. Si no mejora, repórtalo.',
  ),
  skinRedness(
    'Piel roja, con picor o ardor',
    SymptomLevel.watch,
    when: 'Horas o días después de una dosis alta en la piel.',
    why: 'La radiación irrita la piel de forma parecida a una quemadura de sol.',
    action: 'No rasques la zona. Toma una foto y repórtalo.',
  ),
  fever(
    'Fiebre',
    SymptomLevel.urgent,
    when: 'Días o semanas después de una dosis alta.',
    why: 'Con defensas bajas (linfocitos y neutrófilos) aumenta el riesgo de '
        'infección.',
    action: 'Mide tu temperatura y avisa al cirujano de vuelo ahora.',
  ),
  bleeding(
    'Moretones o sangrado fácil (encías, nariz)',
    SymptomLevel.urgent,
    when: '2 a 4 semanas después de una dosis alta.',
    why: 'Puede indicar que bajaron las plaquetas, que ayudan a coagular.',
    action: 'Evita golpes y avisa al cirujano de vuelo ahora.',
  ),
  mouthSores(
    'Llagas en la boca o infecciones frecuentes',
    SymptomLevel.watch,
    when: 'Días o semanas después de una dosis alta.',
    why: 'Son señales de defensas bajas.',
    action: 'Mantén la higiene bucal y repórtalo en el próximo chequeo.',
  ),
  blurredVision(
    'Visión borrosa o nublada',
    SymptomLevel.watch,
    when: 'Meses o años (cataratas), o durante el vuelo.',
    why: 'La radiación aumenta el riesgo de cataratas a largo plazo. En vuelo '
        'también puede deberse a cambios en el ojo por microgravedad (SANS).',
    action: 'Haz el control de visión de la rutina y repórtalo.',
  );

  const RadiationSymptom(
    this.label,
    this.level, {
    required this.when,
    required this.why,
    required this.action,
  });

  /// Nombre del síntoma para mostrar.
  final String label;

  /// Qué tan pronto hay que actuar.
  final SymptomLevel level;

  /// Cuándo suele aparecer.
  final String when;

  /// Por qué ocurre, en lenguaje sencillo.
  final String why;

  /// Qué debe hacer el astronauta.
  final String action;

  /// Nivel más alto entre los síntomas marcados, o null si no hay ninguno.
  static SymptomLevel? worstOf(Iterable<RadiationSymptom> symptoms) {
    SymptomLevel? worst;
    for (final s in symptoms) {
      if (worst == null || s.level.index > worst.index) worst = s.level;
    }
    return worst;
  }
}
