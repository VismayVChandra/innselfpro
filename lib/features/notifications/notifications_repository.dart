import '../../core/supabase_client.dart';
import '../../models/app_notification.dart';

class NotificationsRepository {
  /// Live-updating list, newest first -- used by the bell and the
  /// notifications screen, both of which want to reflect a new bid or
  /// status change the moment it lands rather than on next navigation.
  /// Realtime still enforces notifications_select_own per subscriber,
  /// so this can't surface anything RLS wouldn't already allow.
  Stream<List<AppNotification>> streamMyNotifications() {
    final uid = supabase.auth.currentUser!.id;
    return supabase
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('user_id', uid)
        .order('created_at', ascending: false)
        .map(
          (rows) => rows.map((e) => AppNotification.fromMap(e)).toList(),
        );
  }

  Future<List<AppNotification>> fetchMyNotifications() async {
    final uid = supabase.auth.currentUser!.id;
    final data = await supabase
        .from('notifications')
        .select()
        .eq('user_id', uid)
        .order('created_at', ascending: false);
    return (data as List)
        .map((e) => AppNotification.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  Future<int> fetchUnreadCount() async {
    final uid = supabase.auth.currentUser!.id;
    final data = await supabase
        .from('notifications')
        .select('id')
        .eq('user_id', uid)
        .eq('is_read', false);
    return (data as List).length;
  }

  Future<void> markAsRead(String id) async {
    await supabase.from('notifications').update({'is_read': true}).eq('id', id);
  }

  /// Whether there's an unread notification of [type] for [jobId] --
  /// used for the chat unread dot on a job's contact card, a one-shot
  /// check rather than pulling the whole notifications list.
  Future<bool> hasUnread({required String jobId, required String type}) async {
    final uid = supabase.auth.currentUser!.id;
    final data = await supabase
        .from('notifications')
        .select('id')
        .eq('user_id', uid)
        .eq('job_id', jobId)
        .eq('type', type)
        .eq('is_read', false)
        .limit(1);
    return (data as List).isNotEmpty;
  }

  /// Marks every unread notification of [type] for [jobId] as read --
  /// called on opening a job's chat, since viewing the thread is itself
  /// "reading" whatever prompted the unread dot.
  Future<void> markJobNotificationsRead({required String jobId, required String type}) async {
    final uid = supabase.auth.currentUser!.id;
    await supabase
        .from('notifications')
        .update({'is_read': true})
        .eq('user_id', uid)
        .eq('job_id', jobId)
        .eq('type', type)
        .eq('is_read', false);
  }
}
