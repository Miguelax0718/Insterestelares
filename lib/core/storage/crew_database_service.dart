import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'package:astramed/features/crew/data/mock_crew_data.dart';
import 'package:astramed/features/crew/models/astronaut_profile.dart';

/// Servicio de almacenamiento y persistencia para la tripulación de AstraMed
/// Diseñado bajo modelo 100% Offline-First y compatible con Flutter Web, Desktop y Mobile
class CrewDatabaseService {
  // Caché en memoria para acceso ultrarrápido y seguro en cualquier plataforma
  final Map<String, AstronautProfile> _memoryCache = {};

  /// Carga la lista de perfiles leyendo `DB/Users/crew_index.json`
  /// y los archivos individuales de cada tripulante.
  /// Si ocurre cualquier error de lectura o los assets aún no están empaquetados,
  /// retorna con seguridad la lista predeterminada de `MockCrewData.getInitialCrew()`.
  Future<List<AstronautProfile>> loadCrewFromDbUsers() async {
    try {
      final indexRaw = await rootBundle.loadString('DB/Users/crew_index.json');
      final indexDecoded = jsonDecode(indexRaw);

      if (indexDecoded is List && indexDecoded.isNotEmpty) {
        final loadedList = <AstronautProfile>[];

        for (final item in indexDecoded) {
          final fileName = item.toString();
          final path = fileName.startsWith('DB/Users/')
              ? fileName
              : 'DB/Users/$fileName';

          final profileRaw = await rootBundle.loadString(path);
          final profileMap = jsonDecode(profileRaw) as Map<String, dynamic>;
          loadedList.add(AstronautProfile.fromJson(profileMap));
        }

        if (loadedList.isNotEmpty) {
          _memoryCache.clear();
          for (final p in loadedList) {
            _memoryCache[p.id] = p;
          }
          return loadedList;
        }
      }
    } catch (e, stackTrace) {
      debugPrint('Aviso: Fallback a MockCrewData al cargar DB/Users: $e\n$stackTrace');
    }

    // Fallback offline seguro
    final fallbackCrew = MockCrewData.getInitialCrew();
    _memoryCache.clear();
    for (final profile in fallbackCrew) {
      _memoryCache[profile.id] = profile;
    }
    return fallbackCrew;
  }

  /// Retorna un perfil desde la caché en memoria si existe
  AstronautProfile? getCachedProfile(String astronautId) {
    return _memoryCache[astronautId];
  }

  /// Retorna todos los perfiles cacheados actualmente
  List<AstronautProfile> getAllCached() {
    return _memoryCache.values.toList();
  }

  /// Serializa el perfil del astronauta a JSON con formato legible de 2 espacios
  /// Listo para guardarse en la carpeta `DB/Users/`
  String exportAstronautJson(AstronautProfile profile) {
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(profile.toJson());
  }

  /// Guarda o actualiza un perfil en la caché en memoria local
  Future<void> saveAstronautProfile(AstronautProfile profile) async {
    _memoryCache[profile.id] = profile;
  }
}
