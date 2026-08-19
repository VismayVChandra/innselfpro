class Payment {
  final String id;
  final String jobId;
  final double amount;
  final String status;
  final String? razorpayPaymentId;
  final DateTime? paidAt;

  const Payment({
    required this.id,
    required this.jobId,
    required this.amount,
    required this.status,
    this.razorpayPaymentId,
    this.paidAt,
  });

  factory Payment.fromMap(Map<String, dynamic> map) => Payment(
        id: map['id'] as String,
        jobId: map['job_id'] as String,
        amount: (map['amount'] as num).toDouble(),
        status: map['status'] as String,
        razorpayPaymentId: map['razorpay_payment_id'] as String?,
        paidAt: map['paid_at'] == null ? null : DateTime.parse(map['paid_at'] as String),
      );
}
