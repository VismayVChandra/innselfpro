class Review {
  final String id;
  final String jobId;
  final String customerId;
  final String technicianId;
  final int rating;
  final String? comment;
  final DateTime createdAt;
  final String? jobCategoryName;

  const Review({
    required this.id,
    required this.jobId,
    required this.customerId,
    required this.technicianId,
    required this.rating,
    this.comment,
    required this.createdAt,
    this.jobCategoryName,
  });

  factory Review.fromMap(Map<String, dynamic> map) => Review(
        id: map['id'] as String,
        jobId: map['job_id'] as String,
        customerId: map['customer_id'] as String,
        technicianId: map['technician_id'] as String,
        rating: map['rating'] as int,
        comment: map['comment'] as String?,
        createdAt: DateTime.parse(map['created_at'] as String),
        jobCategoryName: (map['jobs']
            as Map<String, dynamic>?)?['categories']?['name'] as String?,
      );
}
