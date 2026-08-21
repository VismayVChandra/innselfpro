class TechnicianDetails {
  final String profileId;
  final String? serviceArea;

  const TechnicianDetails({
    required this.profileId,
    this.serviceArea,
  });

  factory TechnicianDetails.fromMap(Map<String, dynamic> map) =>
      TechnicianDetails(
        profileId: map['profile_id'] as String,
        serviceArea: map['service_area'] as String?,
      );
}
