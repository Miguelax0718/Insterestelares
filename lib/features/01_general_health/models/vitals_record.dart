class VitalsRecord {
  final DateTime timestamp;
  final double heartRate; // bpm
  final double systolicBP; // mmHg
  final double diastolicBP; // mmHg
  final double spO2; // %
  final double bodyTemp; // °C
  final double bloodGlucose; // mg/dL
  final double respiratoryRate; // rpm (frecuencia respiratoria)
  final double capillaryRefillSeconds; // segundos de llenado capilar

  const VitalsRecord({
    required this.timestamp,
    required this.heartRate,
    required this.systolicBP,
    required this.diastolicBP,
    required this.spO2,
    required this.bodyTemp,
    required this.bloodGlucose,
    this.respiratoryRate = 16.0,
    this.capillaryRefillSeconds = 1.5,
  });
}
