import '../../core/supabase_client.dart';
import '../../models/points_transaction.dart';

class PointsRepository {
  /// profiles.reward_points is platform-controlled (migration 019's
  /// guard_platform_profile_columns), so this is always a fresh read,
  /// never something computed by summing transactions client-side.
  Future<int> fetchBalance() async {
    final uid = supabase.auth.currentUser!.id;
    final data =
        await supabase.from('profiles').select('reward_points').eq('id', uid).single();
    return data['reward_points'] as int;
  }

  Future<List<PointsTransaction>> fetchHistory() async {
    final uid = supabase.auth.currentUser!.id;
    final data = await supabase
        .from('points_transactions')
        .select()
        .eq('profile_id', uid)
        .order('created_at', ascending: false);
    return (data as List)
        .map((e) => PointsTransaction.fromMap(e as Map<String, dynamic>))
        .toList();
  }
}
