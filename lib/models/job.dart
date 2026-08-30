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

  /// The 4-digit code the customer reads out to the technician to close
  /// out the job (migration 010) -- generated server-side the moment a
  /// bid is accepted, so it's already set by the time this is shown.
  final String? completionCode;

  /// When the technician expects to arrive, set from the "I'm on my
  /// way" time picker (migration 012). Null means no ETA was given.
  final DateTime? etaAt;

  /// Machine-readable location (migration 014) -- location stays the
  /// human-readable address; these back real distance sorting/matching.
  /// Null when the job predates this feature or geolocation wasn't
  /// available/granted when it was posted.
  final String? pincode;
  final double? lat;
  final double? lng;

  /// Null means this job never expires (posted before migration 014,
  /// or an already-assigned job -- only 'open' jobs are ever expired).
  final DateTime? expiresAt;

  /// Set when the customer spends points to boost this job's visibility
  /// (migration 019) -- boosted jobs sort first in the technician feed.
  final DateTime? boostedAt;

  final DateTime createdAt;

  bool get isBoosted => boostedAt != null;

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
    this.completionCode,
    this.etaAt,
    this.pincode,
    this.lat,
    this.lng,
    this.expiresAt,
    this.boostedAt,
    required this.createdAt,
  });

  bool get hasLocation => lat != null && lng != null;

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
        completionCode: map['completion_code'] as String?,
        etaAt: map['eta_at'] == null
            ? null
            : DateTime.parse(map['eta_at'] as String),
        pincode: map['pincode'] as String?,
        lat: (map['lat'] as num?)?.toDouble(),
        lng: (map['lng'] as num?)?.toDouble(),
        expiresAt: map['expires_at'] == null
            ? null
            : DateTime.parse(map['expires_at'] as String),
        boostedAt: map['boosted_at'] == null
            ? null
            : DateTime.parse(map['boosted_at'] as String),
        createdAt: DateTime.parse(map['created_at'] as String),
      );

  /// Realtime rows (via .stream()) can't carry the categories(name)
  /// embed the way a one-shot select can -- this fills the name back in
  /// from a category list the caller already has loaded.
  Job copyWithCategoryName(String name) => Job(
        id: id,
        customerId: customerId,
        categoryId: categoryId,
        categoryName: name,
        description: description,
        photoUrls: photoUrls,
        location: location,
        status: status,
        acceptedBidId: acceptedBidId,
        scheduledFor: scheduledFor,
        completionPhotoUrl: completionPhotoUrl,
        invitedTechnicianId: invitedTechnicianId,
        completionCode: completionCode,
        etaAt: etaAt,
        pincode: pincode,
        lat: lat,
        lng: lng,
        expiresAt: expiresAt,
        boostedAt: boostedAt,
        createdAt: createdAt,
      );
}
