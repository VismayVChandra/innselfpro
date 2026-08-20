import '../../core/supabase_client.dart';
import '../../models/app_notification.dart';

class NotificationsRepository {
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
}
