/// A report against another user, with both names resolved for the
/// admin queue (admin_list_reports, migration 016).
class UserReport {
  final String id;
  final String reporterId;
  final String reporterName;
  final String reportedId;
  final String reportedName;
  final String? jobId;
  final String reason;
  final String status;
  final DateTime createdAt;

  const UserReport({
    required this.id,
    required this.reporterId,
    required this.reporterName,
    required this.reportedId,
    required this.reportedName,
    this.jobId,
    required this.reason,
    required this.status,
    required this.createdAt,
  });

  factory UserReport.fromMap(Map<String, dynamic> map) => UserReport(
        id: map['id'] as String,
        reporterId: map['reporter_id'] as String,
        reporterName: map['reporter_name'] as String? ?? '',
        reportedId: map['reported_id'] as String,
        reportedName: map['reported_name'] as String? ?? '',
        jobId: map['job_id'] as String?,
        reason: map['reason'] as String,
        status: map['status'] as String,
        createdAt: DateTime.parse(map['created_at'] as String),
      );
}
