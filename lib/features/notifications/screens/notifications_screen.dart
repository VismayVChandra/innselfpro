import 'package:flutter/material.dart';

import '../../../core/format.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/widgets/layout.dart';
import '../../../core/widgets/states.dart';
import '../../../core/widgets/surfaces.dart';
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

  Future<void> _refresh() async {
    setState(() => _future = _repository.fetchMyNotifications());
    await _future;
  }

  Future<void> _onTap(AppNotification notification) async {
    if (notification.isRead) return;
    await _repository.markAsRead(notification.id);
    if (!mounted) return;
    setState(() {
      _future = _repository.fetchMyNotifications();
    });
  }

  /// Icon + tint per notification type, so the list scans quickly.
  ({IconData icon, Color color, Color background}) _styleFor(String type) {
    switch (type) {
      case 'new_bid':
        return (
          icon: Icons.sell_outlined,
          color: AppColors.accentForeground,
          background: AppColors.secondary,
        );
      case 'bid_accepted':
        return (
          icon: Icons.handshake_outlined,
          color: AppColors.warn,
          background: AppColors.warnSurface,
        );
      case 'job_completed':
        return (
          icon: Icons.check_circle_outline,
          color: AppColors.success,
          background: AppColors.successSurface,
        );
      case 'payment_received':
        return (
          icon: Icons.account_balance_wallet_outlined,
          color: AppColors.primary,
          background: Color(0x1FF0644F),
        );
      default:
        return (
          icon: Icons.notifications_none_rounded,
          color: AppColors.mutedForeground,
          background: AppColors.muted,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          color: AppColors.primary,
          backgroundColor: AppColors.card,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(top: 10, bottom: 32),
            child: FutureBuilder<List<AppNotification>>(
              future: _future,
              builder: (context, snapshot) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const TopBar(
                      eyebrow: 'YOUR INNSELF',
                      title: 'Notifications',
                    ),
                    if (snapshot.hasError)
                      ErrorView(
                        message:
                            'Could not load notifications: ${snapshot.error}',
                        onRetry: _refresh,
                      )
                    else if (snapshot.connectionState != ConnectionState.done)
                      const LoadingView()
                    else if (snapshot.data!.isEmpty)
                      const EmptyView(
                        icon: Icons.notifications_none_rounded,
                        title: 'Nothing yet',
                        message:
                            'Bids, status changes and payments will show up here.',
                      )
                    else
                      for (final notification in snapshot.data!)
                        _NotificationRow(
                          notification: notification,
                          style: _styleFor(notification.type),
                          onTap: () => _onTap(notification),
                        ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _NotificationRow extends StatelessWidget {
  const _NotificationRow({
    required this.notification,
    required this.style,
    required this.onTap,
  });

  final AppNotification notification;
  final ({IconData icon, Color color, Color background}) style;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final unread = !notification.isRead;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        onTap: onTap,
        radius: 19,
        padding: const EdgeInsets.all(14),
        color: unread ? AppColors.card : AppColors.background,
        borderColor: unread ? AppColors.accent : AppColors.border,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SoftIcon(
              style.icon,
              background: style.background,
              foreground: style.color,
              size: 42,
              iconSize: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notification.message,
                    style: AppText.body.copyWith(
                      fontSize: 12.5,
                      fontWeight: unread ? FontWeight.w600 : FontWeight.w400,
                      color: unread
                          ? AppColors.foreground
                          : AppColors.mutedForeground,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    formatRelative(notification.createdAt),
                    style: AppText.bodyMuted.copyWith(fontSize: 10),
                  ),
                ],
              ),
            ),
            if (unread) ...[
              const SizedBox(width: 8),
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(top: 6),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
