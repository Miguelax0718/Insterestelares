enum RadiationSeverity { normal, warning, critical }

class RadiationDose {
  final DateTime timestamp;
  final double doseRateMicroSvPerHour; // uSv/h
  final double cumulativeDoseMilliSv;  // mSv
  final RadiationSeverity severity;

  const RadiationDose({
    required this.timestamp,
    required this.doseRateMicroSvPerHour,
    required this.cumulativeDoseMilliSv,
    required this.severity,
  });
}
