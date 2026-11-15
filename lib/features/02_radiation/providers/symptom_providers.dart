import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/radiation_symptom.dart';

/// Síntomas que cada astronauta marcó hoy (clave: id del astronauta).
final reportedSymptomsProvider =
    StateProvider.family<Set<RadiationSymptom>, String>((ref, astronautId) => {});
