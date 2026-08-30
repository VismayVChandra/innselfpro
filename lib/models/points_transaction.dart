/// One line of the reward-points ledger (migration 019) -- positive
/// delta for earning, negative for a spend (a boost).
class PointsTransaction {
  final String id;
  final int delta;
  final String reason;
  final String? jobId;
  final DateTime createdAt;

  const PointsTransaction({
    required this.id,
    required this.delta,
    required this.reason,
    this.jobId,
    required this.createdAt,
  });

  factory PointsTransaction.fromMap(Map<String, dynamic> map) => PointsTransaction(
        id: map['id'] as String,
        delta: map['delta'] as int,
        reason: map['reason'] as String,
        jobId: map['job_id'] as String?,
        createdAt: DateTime.parse(map['created_at'] as String),
      );

  bool get isEarn => delta > 0;
}
