import '../../core/supabase_client.dart';
import '../../models/profile.dart';

class SafetyRepository {
  Future<void> blockUser(String userId) async {
    final uid = supabase.auth.currentUser!.id;
    await supabase
        .from('user_blocks')
        .upsert({'blocker_id': uid, 'blocked_id': userId});
  }

  Future<void> unblockUser(String userId) async {
    final uid = supabase.auth.currentUser!.id;
    await supabase
        .from('user_blocks')
        .delete()
        .eq('blocker_id', uid)
        .eq('blocked_id', userId);
  }

  /// The caller's own blocked list, with each blocked profile resolved.
  /// Two queries rather than an embed -- user_blocks has two foreign
  /// keys into profiles (blocker_id and blocked_id), so a PostgREST
  /// embed needs the exact auto-generated constraint name to
  /// disambiguate; a plain inFilter avoids depending on that.
  Future<List<Profile>> fetchBlockedUsers() async {
    final uid = supabase.auth.currentUser!.id;
    final blockRows = await supabase
        .from('user_blocks')
        .select('blocked_id')
        .eq('blocker_id', uid)
        .order('created_at', ascending: false);
    final blockedIds =
        (blockRows as List).map((e) => (e as Map<String, dynamic>)['blocked_id'] as String).toList();
    if (blockedIds.isEmpty) return [];
    final profileRows =
        await supabase.from('profiles').select().inFilter('id', blockedIds);
    final byId = {
      for (final row in profileRows as List)
        (row as Map<String, dynamic>)['id'] as String: Profile.fromMap(row),
    };
    // Preserve the newest-first order from the block list itself.
    return [for (final id in blockedIds) if (byId[id] != null) byId[id]!];
  }

  Future<void> reportUser({
    required String reportedId,
    required String reason,
    String? jobId,
  }) async {
    final uid = supabase.auth.currentUser!.id;
    await supabase.from('user_reports').insert({
      'reporter_id': uid,
      'reported_id': reportedId,
      'job_id': ?jobId,
      'reason': reason,
    });
  }
}
