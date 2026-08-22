import '../../core/supabase_client.dart';
import '../../models/bid.dart';
import '../profile/profile_repository.dart';

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

  /// Live bids on a job, always resolved with technician name and
  /// rating, updating in place as bids arrive or get accepted/withdrawn.
  /// Streaming carries no profiles(full_name) embed, so each emission
  /// resolves names and ratings itself; asyncMap keeps that resolution
  /// inside the stream rather than pushing it onto every call site.
  Stream<List<Bid>> streamBidsForJob(String jobId) {
    return supabase
        .from('bids')
        .stream(primaryKey: ['id'])
        .eq('job_id', jobId)
        .order('amount', ascending: true)
        .asyncMap((rows) async {
      final technicianIds = rows.map((r) => r['technician_id'] as String).toSet().toList();
      final names = await _fetchProfileNames(technicianIds);
      final ratings = await fetchTechnicianRatings(technicianIds);
      final verified = await ProfileRepository().fetchVerifiedProfileIds(technicianIds);
      return rows.map((row) {
        final technicianId = row['technician_id'] as String;
        final rating = ratings[technicianId];
        return Bid(
          id: row['id'] as String,
          jobId: row['job_id'] as String,
          technicianId: technicianId,
          technicianName: names[technicianId] ?? '',
          amount: (row['amount'] as num).toDouble(),
          note: row['note'] as String?,
          status: row['status'] as String,
          createdAt: DateTime.parse(row['created_at'] as String),
          technicianRating: rating?.average,
          technicianReviewCount: rating?.count ?? 0,
          technicianIsVerified: verified.contains(technicianId),
        );
      }).toList();
    });
  }

  Future<Map<String, String>> _fetchProfileNames(List<String> ids) async {
    if (ids.isEmpty) return {};
    final rows =
        await supabase.from('profiles').select('id, full_name').inFilter('id', ids);
    return {
      for (final row in rows as List)
        (row as Map<String, dynamic>)['id'] as String: row['full_name'] as String,
    };
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
