/// Constantes y umbrales médicos basados en estándares de la NASA
class MedicalThresholds {
  // Signos vitales basales
  static const double minHeartRate = 50.0;
  static const double maxHeartRate = 100.0;
  static const double minSystolicBP = 90.0;
  static const double maxSystolicBP = 130.0;
  static const double minSpO2 = 94.0;

  // Radiación espacial (mSv)
  static const double radiationWarningRateHourly = 1.0; // mSv/h
  static const double radiationAcuteDangerThreshold = 250.0; // mSv en evento solar agudo
  static const double radiationCareerLimitMax = 600.0; // mSv estándar carrera NASA

  // Sueño y descanso diario
  static const double minRecommendedSleepHours = 6.5;
  static const double optimalSleepHours = 8.0;
}
