class Bid {
  final String id;
  final String jobId;
  final String technicianId;
  final String technicianName;
  final double amount;
  final String? note;
  final String status;
  final DateTime createdAt;

  /// Attached after the initial fetch, from a separate reviews query --
  /// null until BidsRepository fills it in, distinct from "no reviews yet"
  /// (technicianReviewCount == 0).
  final double? technicianRating;
  final int technicianReviewCount;

  /// Whether this technician's KYC has been approved (migration 015),
  /// resolved alongside the rating.
  final bool technicianIsVerified;

  const Bid({
    required this.id,
    required this.jobId,
    required this.technicianId,
    required this.technicianName,
    required this.amount,
    this.note,
    required this.status,
    required this.createdAt,
    this.technicianRating,
    this.technicianReviewCount = 0,
    this.technicianIsVerified = false,
  });

  factory Bid.fromMap(Map<String, dynamic> map) => Bid(
        id: map['id'] as String,
        jobId: map['job_id'] as String,
        technicianId: map['technician_id'] as String,
        technicianName:
            (map['profiles'] as Map<String, dynamic>?)?['full_name'] as String? ??
                '',
        amount: (map['amount'] as num).toDouble(),
        note: map['note'] as String?,
        status: map['status'] as String,
        createdAt: DateTime.parse(map['created_at'] as String),
      );

  Bid withRating({
    required double? rating,
    required int reviewCount,
    bool isVerified = false,
  }) =>
      Bid(
        id: id,
        jobId: jobId,
        technicianId: technicianId,
        technicianName: technicianName,
        amount: amount,
        note: note,
        status: status,
        createdAt: createdAt,
        technicianRating: rating,
        technicianReviewCount: reviewCount,
        technicianIsVerified: isVerified,
      );
}
