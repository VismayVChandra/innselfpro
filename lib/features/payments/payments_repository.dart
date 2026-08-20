import '../../core/supabase_client.dart';
import '../../models/payment.dart';

class PaymentsRepository {
  /// Calls the create-razorpay-order Edge Function, which validates the job
  /// server-side and returns the order details needed to open checkout.
  Future<Map<String, dynamic>> createOrder(String jobId) async {
    final res = await supabase.functions.invoke(
      'create-razorpay-order',
      body: {'jobId': jobId},
    );
    if (res.status != 200) {
      final error = (res.data is Map) ? res.data['error'] : null;
      throw Exception(error ?? 'Failed to start payment (status ${res.status})');
    }
    return res.data as Map<String, dynamic>;
  }

  /// Records a cash payment directly -- no Edge Function involved, since
  /// there's no external gateway to verify a cash handoff against. The
  /// technician and amount are re-read from the job's actual accepted
  /// bid rather than trusted from the caller, and the
  /// payments_insert_cash_by_customer RLS policy (migration 006)
  /// re-derives and checks both server-side too.
  Future<void> markPaidInCash(String jobId) async {
    final uid = supabase.auth.currentUser!.id;
    final job = await supabase
        .from('jobs')
        .select('accepted_bid_id')
        .eq('id', jobId)
        .single();
    final acceptedBidId = job['accepted_bid_id'] as String;
    final bid = await supabase
        .from('bids')
        .select('amount, technician_id')
        .eq('id', acceptedBidId)
        .single();
    await supabase.from('payments').insert({
      'job_id': jobId,
      'customer_id': uid,
      'technician_id': bid['technician_id'],
      'amount': bid['amount'],
      'payment_method': 'cash',
      'status': 'paid',
      'paid_at': DateTime.now().toIso8601String(),
    });
  }

  Future<Payment?> fetchPaymentForJob(String jobId) async {
    final data =
        await supabase.from('payments').select().eq('job_id', jobId).maybeSingle();
    if (data == null) return null;
    return Payment.fromMap(data);
  }

  Future<List<Payment>> fetchMyEarnings() async {
    final uid = supabase.auth.currentUser!.id;
    final data = await supabase
        .from('payments')
        .select('*, jobs(categories(name))')
        .eq('technician_id', uid)
        .eq('status', 'paid')
        .order('paid_at', ascending: false);
    return (data as List)
        .map((e) => Payment.fromMap(e as Map<String, dynamic>))
        .toList();
  }
}
