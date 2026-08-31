import '../../core/supabase_client.dart';
import '../../models/support_message.dart';

class SupportRepository {
  /// One ongoing thread per user -- support_messages_select (migration
  /// 021) already restricts a plain user to their own thread, and lets
  /// any admin read any thread, so [threadUserId] just says which one.
  Stream<List<SupportMessage>> streamThread(String threadUserId) {
    return supabase
        .from('support_messages')
        .stream(primaryKey: ['id'])
        .eq('user_id', threadUserId)
        .order('created_at', ascending: true)
        .map((rows) => rows.map((e) => SupportMessage.fromMap(e)).toList());
  }

  Future<void> sendMessage({required String threadUserId, required String body}) async {
    final uid = supabase.auth.currentUser!.id;
    await supabase.from('support_messages').insert({
      'user_id': threadUserId,
      'sender_id': uid,
      'body': body,
    });
  }

  Future<List<SupportThreadSummary>> fetchThreads() async {
    final rows = await supabase.rpc('admin_list_support_threads');
    return ((rows ?? []) as List)
        .map((e) => SupportThreadSummary.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  /// Called when an admin opens a thread -- support_messages_update_admin
  /// (migration 021) is what allows this.
  Future<void> markThreadRead(String threadUserId) async {
    await supabase
        .from('support_messages')
        .update({'read_by_admin': true})
        .eq('user_id', threadUserId)
        .eq('sender_id', threadUserId);
  }
}
