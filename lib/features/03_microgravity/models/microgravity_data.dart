class ExerciseSession {
  final DateTime date;
  final String deviceName; // ARED (Resistencia), T2 (Cinta), CEVIS (Bicicleta)
  final int durationMinutes;
  final double caloriesBurned;
  final bool targetReached;

  const ExerciseSession({
    required this.date,
    required this.deviceName,
    required this.durationMinutes,
    required this.caloriesBurned,
    required this.targetReached,
  });
}
