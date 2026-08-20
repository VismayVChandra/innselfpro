class AppNotification {
  final String id;
  final String type;
  final String? jobId;
  final String message;
  final bool isRead;
  final DateTime createdAt;

  const AppNotification({
    required this.id,
    required this.type,
    this.jobId,
    required this.message,
    required this.isRead,
    required this.createdAt,
  });

  factory AppNotification.fromMap(Map<String, dynamic> map) => AppNotification(
        id: map['id'] as String,
        type: map['type'] as String,
        jobId: map['job_id'] as String?,
        message: map['message'] as String,
        isRead: map['is_read'] as bool,
        createdAt: DateTime.parse(map['created_at'] as String),
      );
}
