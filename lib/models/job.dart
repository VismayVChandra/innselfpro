class Job {
  final String id;
  final String customerId;
  final int categoryId;
  final String categoryName;
  final String description;
  final String? photoUrl;
  final String location;
  final String status;
  final String? acceptedBidId;
  final DateTime createdAt;

  const Job({
    required this.id,
    required this.customerId,
    required this.categoryId,
    required this.categoryName,
    required this.description,
    this.photoUrl,
    required this.location,
    required this.status,
    this.acceptedBidId,
    required this.createdAt,
  });

  factory Job.fromMap(Map<String, dynamic> map) => Job(
        id: map['id'] as String,
        customerId: map['customer_id'] as String,
        categoryId: map['category_id'] as int,
        categoryName:
            (map['categories'] as Map<String, dynamic>?)?['name'] as String? ??
                '',
        description: map['description'] as String,
        photoUrl: map['photo_url'] as String?,
        location: map['location'] as String,
        status: map['status'] as String,
        acceptedBidId: map['accepted_bid_id'] as String?,
        createdAt: DateTime.parse(map['created_at'] as String),
      );
}
