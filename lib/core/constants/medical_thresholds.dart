/// Constantes científicas de referencia versionadas y trazables.
///
/// Nota: La evaluación fisiológica contextual debe realizarse mediante
/// [ScientificCriteriaEngine] y no mediante umbrales rígidos aislados.
class MedicalThresholds {
  // Referencia terrestre general en reposo (AHA) - no aplicar en sueño o ejercicio.
  static const double minHeartRate = 60.0;
  static const double maxHeartRate = 100.0;

  // Incremento promedio observado en microgravedad (Mendes Zambetta et al., 2024).
  // No uniforme entre individuos; usar solo como contexto descriptivo.
  static const double microgravityMeanHrDeltaBpm = 3.44;

  // Presión arterial (referencia existente para compatibilidad temporal)
  static const double minSystolicBP = 90.0;
  static const double maxSystolicBP = 130.0;

  // Referencia terrestre general de SpO2 (FDA). No es límite universal espacial.
  static const double minSpO2 = 95.0;

  // Frecuencia respiratoria orientativa en reposo (Cleveland Clinic / Berry et al., 2012)
  static const double minRespiratoryRate = 12.0;
  static const double maxRespiratoryRate = 20.0;

  // Radiación espacial (mSv)
  static const double radiationWarningRateHourly = 1.0; // mSv/h
  static const double radiationAcuteDangerThreshold = 250.0; // mSv en evento solar agudo
  static const double radiationCareerLimitMax = 600.0; // mSv estándar carrera NASA

  // Sueño y descanso diario (Hirshkowitz et al., 2015; Watson et al., 2015)
  static const double minRecommendedSleepHours = 7.0;
  static const double maxRecommendedSleepHours = 9.0;
  static const double optimalSleepHours = 8.0;

  // Fuerza muscular (NASA-STD-3001 Vol. 1, Requisito V1 4024)
  static const double minMuscleStrengthRetentionPercent = 80.0;
}
