import 'package:flutter/material.dart';

import '../../core/widgets/buttons.dart';
import '../../models/app_notification.dart';
import 'notifications_repository.dart';
import 'screens/notifications_screen.dart';

/// Round bell button with the coral unread marker, sitting at the end of
/// each home screen's header. Live -- subscribed to the same realtime
/// notifications stream the notifications screen uses, so the dot
/// appears the moment a new one lands rather than on next navigation.
class NotificationBell extends StatefulWidget {
  const NotificationBell({super.key});

  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell> {
  late final Stream<List<AppNotification>> _notificationsStream =
      NotificationsRepository().streamMyNotifications();

  void _open() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const NotificationsScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<AppNotification>>(
      stream: _notificationsStream,
      builder: (context, snapshot) {
        final count = snapshot.data?.where((n) => !n.isRead).length ?? 0;
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
