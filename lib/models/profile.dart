class Profile {
  final String id;
  final String role;
  final String fullName;
  final String phone;
  final String? address;

  /// Mirrored from technician_kyc.status by a trigger (migration 015).
  /// The documents themselves stay owner-only -- this boolean is the
  /// only part customers ever see.
  final bool isVerified;

  /// Cancellations made after a technician was already assigned. Shown
  /// as a plain count, deliberately not used to block anything.
  final int lateCancellations;

  /// Earned for on-time arrival/job completion (technician) or prompt
  /// payment/leaving a review (customer) -- migration 019. Spent on
  /// visibility boosts, never redeemable for money.
  final int rewardPoints;

  const Profile({
    required this.id,
    required this.role,
    required this.fullName,
    required this.phone,
    this.address,
    this.isVerified = false,
    this.lateCancellations = 0,
    this.rewardPoints = 0,
  });

  factory Profile.fromMap(Map<String, dynamic> map) => Profile(
        id: map['id'] as String,
        role: map['role'] as String,
        fullName: map['full_name'] as String,
        phone: map['phone'] as String,
        address: map['address'] as String?,
        isVerified: map['is_verified'] as bool? ?? false,
        lateCancellations: map['late_cancellations'] as int? ?? 0,
        rewardPoints: map['reward_points'] as int? ?? 0,
      );

  bool get isCustomer => role == 'customer';
  bool get isTechnician => role == 'technician';
}
