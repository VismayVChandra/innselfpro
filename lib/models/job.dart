class Job {
  final String id;
  final String customerId;
  final int categoryId;
  final String categoryName;
  final String description;
  final List<String> photoUrls;
  final String location;
  final String status;
  final String? acceptedBidId;

  /// The customer's requested visit time. Null means "as soon as
  /// possible" rather than an unset value.
  final DateTime? scheduledFor;

  /// Set by the technician when marking the job complete -- proof of
  /// work, distinct from photoUrls (the customer's original job photos).
  final String? completionPhotoUrl;

  /// Set when the customer booked this specific technician directly
  /// (a "rebook") rather than posting an open request. Null means any
  /// technician can see and bid on it, as normal.
  final String? invitedTechnicianId;

  final DateTime createdAt;

  const Job({
    required this.id,
    required this.customerId,
    required this.categoryId,
    required this.categoryName,
    required this.description,
    this.photoUrls = const [],
    required this.location,
    required this.status,
    this.acceptedBidId,
    this.scheduledFor,
    this.completionPhotoUrl,
    this.invitedTechnicianId,
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
        photoUrls: (map['photo_urls'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            const [],
        location: map['location'] as String,
        status: map['status'] as String,
        acceptedBidId: map['accepted_bid_id'] as String?,
        scheduledFor: map['scheduled_for'] == null
            ? null
            : DateTime.parse(map['scheduled_for'] as String),
        completionPhotoUrl: map['completion_photo_url'] as String?,
        invitedTechnicianId: map['invited_technician_id'] as String?,
        createdAt: DateTime.parse(map['created_at'] as String),
      );
}
