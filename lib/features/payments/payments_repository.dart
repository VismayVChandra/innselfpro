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
