import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/widgets/layout.dart';
import '../../../models/profile.dart';
import '../../auth/auth_repository.dart';
import '../../notifications/notifications_repository.dart';
import '../../notifications/screens/notifications_screen.dart';
import '../widgets/profile_widgets.dart';

/// Account tab for a customer: who they are, where jobs get sent, and
/// the way out.
class CustomerProfileScreen extends StatefulWidget {
  const CustomerProfileScreen({super.key, required this.profile});

  final Profile profile;

  @override
  State<CustomerProfileScreen> createState() => _CustomerProfileScreenState();
}

class _CustomerProfileScreenState extends State<CustomerProfileScreen> {
  late Future<int> _unreadFuture;

  @override
  void initState() {
    super.initState();
    _unreadFuture = NotificationsRepository().fetchUnreadCount();
  }

  Future<void> _openNotifications() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const NotificationsScreen()),
    );
    if (!mounted) return;
    setState(() {
      _unreadFuture = NotificationsRepository().fetchUnreadCount();
    });
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.profile;
    return SafeArea(
      bottom: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(top: 20, bottom: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const ScreenHeader(eyebrow: 'ACCOUNT', title: 'Profile'),
            ProfileHeaderCard(
              name: profile.fullName,
              subtitle: profile.phone,
              roleLabel: 'Customer',
            ),
            const SectionHeading(title: 'Your details'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: kGutter),
              child: Column(
                children: [
                  FutureBuilder<int>(
                    future: _unreadFuture,
                    builder: (context, snapshot) {
                      final count = snapshot.data ?? 0;
                      return SettingsRow(
                        icon: Icons.notifications_none_rounded,
                        label: 'Notifications',
                        value: count == 0
                            ? 'You are all caught up'
                            : '$count unread update${count == 1 ? '' : 's'}',
                        onTap: _openNotifications,
                      );
                    },
                  ),
                  SettingsRow(
                    icon: Icons.location_on_outlined,
                    label: 'Service address',
                    value: profile.address?.isNotEmpty == true
                        ? profile.address!
                        : 'Not set',
                  ),
                  SettingsRow(
                    icon: Icons.call_outlined,
                    label: 'Phone number',
                    value: profile.phone,
                  ),
                  SettingsRow(
                    icon: Icons.logout_rounded,
                    label: 'Sign out',
                    value: 'End this session on this device',
                    iconBackground: const Color(0x1AD94B48),
                    iconColor: AppColors.destructive,
                    labelColor: AppColors.destructive,
                    onTap: () => AuthRepository().signOut(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'InnSelf  ·  Built for better homes',
              textAlign: TextAlign.center,
              style: AppText.bodyMuted.copyWith(fontSize: 10.5),
            ),
          ],
        ),
      ),
    );
  }
}
