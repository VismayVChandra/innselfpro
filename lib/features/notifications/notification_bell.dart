import 'package:flutter/material.dart';

import '../../core/widgets/buttons.dart';
import 'notifications_repository.dart';
import 'screens/notifications_screen.dart';

/// Round bell button with the coral unread marker, sitting at the end of
/// each home screen's header. Refreshes its count on build and again
/// after returning from the notifications list (no realtime
/// subscription -- polling on navigation is enough for this).
class NotificationBell extends StatefulWidget {
  const NotificationBell({super.key});

  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell> {
  late Future<int> _unreadCountFuture;

  @override
  void initState() {
    super.initState();
    _unreadCountFuture = NotificationsRepository().fetchUnreadCount();
  }

  Future<void> _open() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const NotificationsScreen()),
    );
    if (!mounted) return;
    setState(() {
      _unreadCountFuture = NotificationsRepository().fetchUnreadCount();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<int>(
      future: _unreadCountFuture,
      builder: (context, snapshot) {
        final count = snapshot.data ?? 0;
        return CircleIconButton(
          icon: Icons.notifications_none_rounded,
          onPressed: _open,
          tooltip: 'Notifications',
          showDot: count > 0,
        );
      },
    );
  }
}
