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

  // Mareo Espacial (SMS) & Función Sensoriomotora (NASA NTRS 20150018603 / Graybiel 1968)
  static const int graybielModerateMalaiseThreshold = 5;
  static const int graybielSevereMalaiseThreshold = 8;
  static const int graybielFrankSicknessThreshold = 16;
  static const double facialGreennessWarningDeltaRatio = 0.035;
  static const double facialGreennessCriticalDeltaRatio = 0.070;
  static const double targetHeadOscillationHz = 1.0;
  static const double minAcceptableGazeStabilityScore = 0.80;
  static const int zeroGHorizonDurationSeconds = 45;
  static const double minZeroGHorizonPassScore = 70.0;

  // Síndrome Neuro-Ocular Asociado a Vuelos Espaciales (SANS - Mader 2011 / TechPort 97109 / Lawley 2017)
  static const double defaultCrewIpdMm = 63.0;
  static const double defaultNearPointBaselineCm = 25.0;
  static const double sansHyperopicShiftPair1Diopters = 0.50;
  static const double sansHyperopicShiftPair2Diopters = 1.00;
  static const double sansHyperopicShiftPair3Diopters = 1.50;
  static const double blindSpotTemporalDeg = 15.0;
  static const double lbnpTargetPressureMmHg = -20.0;
  static const int lbnpMinDecompressionSeconds = 15;
}
