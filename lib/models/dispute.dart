class Dispute {
  final String id;
  final String jobId;
  final String flaggedBy;
  final String reason;
  final String status;
  final DateTime createdAt;

  const Dispute({
    required this.id,
    required this.jobId,
    required this.flaggedBy,
    required this.reason,
    required this.status,
    required this.createdAt,
  });

  factory Dispute.fromMap(Map<String, dynamic> map) => Dispute(
        id: map['id'] as String,
        jobId: map['job_id'] as String,
        flaggedBy: map['flagged_by'] as String,
        reason: map['reason'] as String,
        status: map['status'] as String,
        createdAt: DateTime.parse(map['created_at'] as String),
      );
}
