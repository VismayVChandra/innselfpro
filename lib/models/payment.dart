class Payment {
  final String id;
  final String jobId;
  final double amount;
  final String status;
  final String? razorpayPaymentId;

  /// Null on rows created before this column existed -- those were all
  /// made through the Razorpay Edge Function, so null is treated the
  /// same as 'razorpay'.
  final String? paymentMethod;

  final DateTime? paidAt;
  final String? jobCategoryName;

  const Payment({
    required this.id,
    required this.jobId,
    required this.amount,
    required this.status,
    this.razorpayPaymentId,
    this.paymentMethod,
    this.paidAt,
    this.jobCategoryName,
  });

  factory Payment.fromMap(Map<String, dynamic> map) => Payment(
        id: map['id'] as String,
        jobId: map['job_id'] as String,
        amount: (map['amount'] as num).toDouble(),
        status: map['status'] as String,
        razorpayPaymentId: map['razorpay_payment_id'] as String?,
        paymentMethod: map['payment_method'] as String?,
        paidAt: map['paid_at'] == null ? null : DateTime.parse(map['paid_at'] as String),
        jobCategoryName: (map['jobs']
            as Map<String, dynamic>?)?['categories']?['name'] as String?,
      );

  bool get isCash => paymentMethod == 'cash';
}
