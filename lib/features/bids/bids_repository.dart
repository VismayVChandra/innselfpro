import '../../core/supabase_client.dart';
import '../../models/bid.dart';

const _bidSelect = '*, profiles(full_name)';

class BidsRepository {
  Future<void> submitBid({
    required String jobId,
    required double amount,
    String? note,
  }) async {
    final uid = supabase.auth.currentUser!.id;
    await supabase.from('bids').insert({
      'job_id': jobId,
      'technician_id': uid,
      'amount': amount,
      'note': note,
    });
  }

  Future<Bid?> fetchMyBidForJob(String jobId) async {
    final uid = supabase.auth.currentUser!.id;
    final data = await supabase
        .from('bids')
        .select(_bidSelect)
        .eq('job_id', jobId)
        .eq('technician_id', uid)
        .maybeSingle();
    if (data == null) return null;
    return Bid.fromMap(data);
  }

  Future<List<Bid>> fetchBidsForJob(String jobId) async {
    final data = await supabase
        .from('bids')
        .select(_bidSelect)
        .eq('job_id', jobId)
        .order('amount', ascending: true);
    return (data as List)
        .map((e) => Bid.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  /// Accepts one bid on a job: marks the job bid_accepted, the chosen bid
  /// accepted, and every other pending bid on that job rejected.
  Future<void> acceptBid({required String jobId, required String bidId}) async {
    await supabase.from('jobs').update({
      'accepted_bid_id': bidId,
      'status': 'bid_accepted',
    }).eq('id', jobId);

    await supabase.from('bids').update({'status': 'accepted'}).eq('id', bidId);

    await supabase
        .from('bids')
        .update({'status': 'rejected'})
        .eq('job_id', jobId)
        .neq('id', bidId);
  }
}
