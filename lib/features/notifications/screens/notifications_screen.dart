import 'package:flutter/material.dart';

import '../../../core/format.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/widgets/layout.dart';
import '../../../core/widgets/states.dart';
import '../../../core/widgets/surfaces.dart';
import '../../../models/app_notification.dart';
import '../../jobs/jobs_repository.dart';
import '../../jobs/screens/job_detail_screen.dart';
import '../../profile/profile_repository.dart';
import '../../support/screens/support_chat_screen.dart';
import '../notifications_repository.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _repository = NotificationsRepository();
  final _jobsRepository = JobsRepository();
  final _profileRepository = ProfileRepository();
  late final Stream<List<AppNotification>> _notificationsStream =
      _repository.streamMyNotifications();
  String? _openingJobId;

  Future<void> _onTap(AppNotification notification) async {
    if (!notification.isRead) {
      // No manual refetch needed -- the realtime stream re-emits once
      // this update commits.
      await _repository.markAsRead(notification.id);
    }
    if (notification.type == 'support_message') {
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const SupportChatScreen()),
      );
      return;
    }
    if (notification.jobId == null) return;
    setState(() => _openingJobId = notification.id);
    try {
      final job = await _jobsRepository.fetchJobById(notification.jobId!);
      final viewer = await _profileRepository.fetchMyProfile();
      if (!mounted || viewer == null) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => JobDetailScreen(initialJob: job, viewerProfile: viewer),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open this job: $e')),
      );
    } finally {
      if (mounted) setState(() => _openingJobId = null);
    }
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
      case 'direct_request':
        return (
          icon: Icons.person_pin_circle_outlined,
          color: AppColors.accentForeground,
          background: AppColors.accent,
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
      case 'new_job':
        return (
          icon: Icons.campaign_outlined,
          color: AppColors.success,
          background: AppColors.successSurface,
        );
      case 'new_message':
        return (
          icon: Icons.forum_outlined,
          color: AppColors.accentForeground,
          background: AppColors.secondary,
        );
      case 'technician_en_route':
        return (
          icon: Icons.directions_car_filled_outlined,
          color: AppColors.warn,
          background: AppColors.warnSurface,
        );
      case 'job_expired':
        return (
          icon: Icons.hourglass_disabled_outlined,
          color: AppColors.mutedForeground,
          background: AppColors.muted,
        );
      case 'job_cancelled':
        return (
          icon: Icons.event_busy_outlined,
          color: AppColors.destructive,
          background: Color(0x1AD94B48),
        );
      case 'job_rescheduled':
        return (
          icon: Icons.event_repeat_outlined,
          color: AppColors.warn,
          background: AppColors.warnSurface,
        );
      case 'support_message':
        return (
          icon: Icons.support_agent_outlined,
          color: AppColors.accentForeground,
          background: AppColors.accent,
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(top: 10, bottom: 32),
          child: StreamBuilder<List<AppNotification>>(
            stream: _notificationsStream,
            builder: (context, snapshot) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TopBar(
                    eyebrow: 'YOUR INNSELF',
                    title: 'Notifications',
                  ),
                  if (snapshot.hasError)
                    ErrorView(
                      message:
                          'Could not load notifications: ${snapshot.error}',
                    )
                  else if (!snapshot.hasData)
                    LoadingView()
                  else if (snapshot.data!.isEmpty)
                    EmptyView(
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
                        isOpening: _openingJobId == notification.id,
                        onTap: () => _onTap(notification),
                      ),
                ],
              );
            },
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
    required this.isOpening,
    required this.onTap,
  });

  final AppNotification notification;
  final ({IconData icon, Color color, Color background}) style;
  final bool isOpening;
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
            if (isOpening) ...[
              const SizedBox(width: 8),
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ] else if (unread) ...[
              const SizedBox(width: 8),
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(top: 6),
                decoration: BoxDecoration(
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
