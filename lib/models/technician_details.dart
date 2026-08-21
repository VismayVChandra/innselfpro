class TechnicianDetails {
  final String profileId;
  final String? serviceArea;
  final bool isAvailable;
  final double? baseLat;
  final double? baseLng;
  final int serviceRadiusKm;

  const TechnicianDetails({
    required this.profileId,
    this.serviceArea,
    this.isAvailable = true,
    this.baseLat,
    this.baseLng,
    this.serviceRadiusKm = 10,
  });

  bool get hasLocation => baseLat != null && baseLng != null;

  factory TechnicianDetails.fromMap(Map<String, dynamic> map) =>
      TechnicianDetails(
        profileId: map['profile_id'] as String,
        serviceArea: map['service_area'] as String?,
        isAvailable: map['is_available'] as bool? ?? true,
        baseLat: (map['base_lat'] as num?)?.toDouble(),
        baseLng: (map['base_lng'] as num?)?.toDouble(),
        serviceRadiusKm: map['service_radius_km'] as int? ?? 10,
      );
}
