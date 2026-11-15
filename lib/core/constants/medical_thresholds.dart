/// Constantes y umbrales médicos basados en estándares de la NASA
class MedicalThresholds {
  // Signos vitales basales
  static const double minHeartRate = 60.0;
  static const double maxHeartRate = 100.0;
  static const double microgravityMeanHrDeltaBpm = 3.44;
  static const double minSystolicBP = 90.0;
  static const double maxSystolicBP = 130.0;
  static const double minSpO2 = 95.0;
  static const double minRespiratoryRate = 12.0;
  static const double maxRespiratoryRate = 20.0;
  static const double coreHeatFluxTempWarningLowC = 35.5;
  static const double coreHeatFluxTempWarningHighC = 37.8;
  static const double minHydrationBioimpedanceIndex = 70.0;

  // Radiación espacial (mSv)
  static const double radiationWarningRateHourly = 1.0; // mSv/h
  static const double radiationAcuteDangerThreshold = 250.0; // mSv en evento solar agudo
  static const double radiationCareerLimitMax = 600.0; // mSv estándar carrera NASA

  // Sueño, actigrafía y descanso nocturno (NSF / AASM / NASA)
  static const double minRecommendedSleepHours = 7.0;
  static const double optimalSleepHours = 8.0;
  static const double maxRecommendedSleepHours = 9.0;
  static const double minSleepEfficiencyPercent = 85.0;
  static const double minNocturnalHrvRmssdMs = 30.0;

  // Dimensión Neurológica y Sensorial (medición pasiva continua)
  static const double minPupilNpi = 3.0;
  static const double maxNormalPlrLatencyMs = 280.0;
  static const double tofHyperopicShiftAlertCm = 35.0;
  static const double passivePvtReactionAlertMs = 355.0;
  static const double passivePvtLapseThresholdMs = 500.0;

  // Dimensión Musculoesquelética
  static const double biomechanicalImpactAlertG = 2.5;
  static const double minMuscleVolumeRetentionPercent = 80.0;
  static const double minMuscleStrengthRetentionPercent = 80.0;
}
