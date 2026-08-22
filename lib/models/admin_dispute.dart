/// A dispute plus the job context an admin needs to act on it, as
/// returned by admin_list_disputes (migration 015). Distinct from
/// [Dispute], which is the plain row either participant sees on their
/// own job.
class AdminDispute {
  final String id;
  final String jobId;
  final String jobStatus;
  final String categoryName;
  final String flaggedBy;
  final String flaggedByName;
  final String reason;
  final String status;
  final DateTime createdAt;

  const AdminDispute({
    required this.id,
    required this.jobId,
    required this.jobStatus,
    required this.categoryName,
    required this.flaggedBy,
    required this.flaggedByName,
    required this.reason,
    required this.status,
    required this.createdAt,
  });

  factory AdminDispute.fromMap(Map<String, dynamic> map) => AdminDispute(
        id: map['id'] as String,
        jobId: map['job_id'] as String,
        jobStatus: map['job_status'] as String? ?? '',
        categoryName: map['category_name'] as String? ?? '',
        flaggedBy: map['flagged_by'] as String,
        flaggedByName: map['flagged_by_name'] as String? ?? '',
        reason: map['reason'] as String,
        status: map['status'] as String,
        createdAt: DateTime.parse(map['created_at'] as String),
      );

  bool get isOpen => status == 'open';
}
