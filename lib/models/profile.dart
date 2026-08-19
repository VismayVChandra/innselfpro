class Profile {
  final String id;
  final String role;
  final String fullName;
  final String phone;
  final String? address;

  const Profile({
    required this.id,
    required this.role,
    required this.fullName,
    required this.phone,
    this.address,
  });

  factory Profile.fromMap(Map<String, dynamic> map) => Profile(
        id: map['id'] as String,
        role: map['role'] as String,
        fullName: map['full_name'] as String,
        phone: map['phone'] as String,
        address: map['address'] as String?,
      );

  bool get isCustomer => role == 'customer';
  bool get isTechnician => role == 'technician';
}
