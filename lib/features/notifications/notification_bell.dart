import 'package:flutter/material.dart';

import 'notifications_repository.dart';
import 'screens/notifications_screen.dart';

/// Bell icon with an unread-count badge, used in both home screens'
/// AppBars. Refreshes its count each time it's built and after returning
/// from the notifications list (no realtime subscription -- simple polling
/// on navigation is enough for this).
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
        return IconButton(
          onPressed: _open,
          tooltip: 'Notifications',
          icon: Badge(
            label: Text('$count'),
            isLabelVisible: count > 0,
            child: const Icon(Icons.notifications_outlined),
          ),
        );
      },
    );
  }
}
