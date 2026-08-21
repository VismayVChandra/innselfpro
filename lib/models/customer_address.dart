class CustomerAddress {
  final String id;
  final String label;
  final String address;
  final String? pincode;
  final double? lat;
  final double? lng;
  final bool isDefault;

  const CustomerAddress({
    required this.id,
    required this.label,
    required this.address,
    this.pincode,
    this.lat,
    this.lng,
    this.isDefault = false,
  });

  factory CustomerAddress.fromMap(Map<String, dynamic> map) => CustomerAddress(
        id: map['id'] as String,
        label: map['label'] as String,
        address: map['address'] as String,
        pincode: map['pincode'] as String?,
        lat: (map['lat'] as num?)?.toDouble(),
        lng: (map['lng'] as num?)?.toDouble(),
        isDefault: map['is_default'] as bool? ?? false,
      );
}
