class Bid {
  final String id;
  final String jobId;
  final String technicianId;
  final String technicianName;
  final double amount;
  final String? note;
  final String status;
  final DateTime createdAt;

  const Bid({
    required this.id,
    required this.jobId,
    required this.technicianId,
    required this.technicianName,
    required this.amount,
    this.note,
    required this.status,
    required this.createdAt,
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
}
