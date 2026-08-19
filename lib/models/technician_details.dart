class TechnicianDetails {
  final String profileId;
  final String? skills;
  final String? serviceArea;

  const TechnicianDetails({
    required this.profileId,
    this.skills,
    this.serviceArea,
  });

  factory TechnicianDetails.fromMap(Map<String, dynamic> map) =>
      TechnicianDetails(
        profileId: map['profile_id'] as String,
        skills: map['skills'] as String?,
        serviceArea: map['service_area'] as String?,
      );
}
