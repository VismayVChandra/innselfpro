import '../../core/supabase_client.dart';
import '../../models/message.dart';

class MessagesRepository {
  /// Live-updating thread for one job, oldest first -- messages_select
  /// (migration 012) already restricts this to the two participants,
  /// and only once a bid is accepted.
  Stream<List<Message>> streamMessagesForJob(String jobId) {
    return supabase
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('job_id', jobId)
        .order('created_at', ascending: true)
        .map((rows) => rows.map((e) => Message.fromMap(e)).toList());
  }

  Future<void> sendMessage({required String jobId, required String body}) async {
    final uid = supabase.auth.currentUser!.id;
    await supabase.from('messages').insert({
      'job_id': jobId,
      'sender_id': uid,
      'body': body,
    });
  }
}
