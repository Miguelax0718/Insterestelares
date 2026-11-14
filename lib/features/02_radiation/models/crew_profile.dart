/// Crew profile fields used by the radiation feature.
class CrewProfile {
  const CrewProfile({
    required this.id,
    required this.name,
    required this.ageYears,
    required this.sex,
    required this.priorCareerEffectiveDoseMsv,
  });

  final String id;
  final String name;
  final int ageYears;
  final String sex;
  final double priorCareerEffectiveDoseMsv;
}
