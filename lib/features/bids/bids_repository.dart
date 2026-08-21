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

  /// Bids on a job, each carrying the bidding technician's rating so the
  /// customer can weigh price against reputation without a second screen.
  Future<List<Bid>> fetchBidsForJob(String jobId) async {
    final data = await supabase
        .from('bids')
        .select(_bidSelect)
        .eq('job_id', jobId)
        .order('amount', ascending: true);
    final bids = (data as List)
        .map((e) => Bid.fromMap(e as Map<String, dynamic>))
        .toList();
    final ratings = await fetchTechnicianRatings(
      bids.map((b) => b.technicianId).toSet().toList(),
    );
    return bids.map((bid) {
      final rating = ratings[bid.technicianId];
      return bid.withRating(
        rating: rating?.average,
        reviewCount: rating?.count ?? 0,
      );
    }).toList();
  }

  /// Average rating and review count per technician, in one round trip.
  /// Filtered to reviewer_role = 'customer' -- a technician's own
  /// reviews of their customers also carry their technician_id, and
  /// would otherwise pollute their own rating.
  Future<Map<String, ({double average, int count})>> fetchTechnicianRatings(
    List<String> technicianIds,
  ) async {
    if (technicianIds.isEmpty) return {};
    final rows = await supabase
        .from('reviews')
        .select('technician_id, rating')
        .inFilter('technician_id', technicianIds)
        .eq('reviewer_role', 'customer');
    final byTechnician = <String, List<int>>{};
    for (final row in rows as List) {
      final map = row as Map<String, dynamic>;
      final technicianId = map['technician_id'] as String;
      byTechnician.putIfAbsent(technicianId, () => []).add(map['rating'] as int);
    }
    return byTechnician.map(
      (technicianId, ratings) => MapEntry(technicianId, (
        average: ratings.reduce((a, b) => a + b) / ratings.length,
        count: ratings.length,
      )),
    );
  }

  /// How many bids each of these jobs has attracted, in one round trip.
  /// The customer home screen needs counts across several open jobs at
  /// once, and a per-job query would be a request each.
  Future<Map<String, int>> fetchBidCounts(List<String> jobIds) async {
    if (jobIds.isEmpty) return {};
    final rows =
        await supabase.from('bids').select('job_id').inFilter('job_id', jobIds);
    final counts = <String, int>{};
    for (final row in rows as List) {
      final jobId = (row as Map<String, dynamic>)['job_id'] as String;
      counts[jobId] = (counts[jobId] ?? 0) + 1;
    }
    return counts;
  }

  Future<String> fetchTechnicianIdForBid(String bidId) async {
    final data =
        await supabase.from('bids').select('technician_id').eq('id', bidId).single();
    return data['technician_id'] as String;
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

  /// Deletes a still-pending bid. Only valid while the job is still open --
  /// enforced both here client-side (button only shown then) and by the
  /// bids_delete_own_pending RLS policy from migration 005.
  Future<void> withdrawBid(String bidId) async {
    await supabase.from('bids').delete().eq('id', bidId);
  }
}
