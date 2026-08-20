import 'package:flutter/material.dart';

import '../../../models/app_notification.dart';
import '../notifications_repository.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _repository = NotificationsRepository();
  late Future<List<AppNotification>> _future;

  @override
  void initState() {
    super.initState();
    _future = _repository.fetchMyNotifications();
  }

  Future<void> _onTap(AppNotification notification) async {
    if (notification.isRead) return;
    await _repository.markAsRead(notification.id);
    if (!mounted) return;
    setState(() {
      _future = _repository.fetchMyNotifications();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: FutureBuilder<List<AppNotification>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Could not load notifications: ${snapshot.error}'));
          }
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snapshot.data!;
          if (items.isEmpty) {
            return const Center(child: Text('No notifications yet.'));
          }
          return ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, index) {
              final notification = items[index];
              return ListTile(
                tileColor: notification.isRead
                    ? null
                    : Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.4),
                leading: Icon(
                  notification.isRead ? Icons.notifications_none : Icons.notifications,
                ),
                title: Text(notification.message),
                subtitle: Text(notification.createdAt.toLocal().toString()),
                onTap: () => _onTap(notification),
              );
            },
          );
        },
      ),
    );
  }
}
