import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/widgets/layout.dart';
import '../../../models/profile.dart';
import '../../admin/admin_repository.dart';
import '../../admin/screens/admin_screen.dart';
import '../../auth/auth_repository.dart';
import '../../jobs/screens/saved_addresses_screen.dart';
import '../../safety/screens/blocked_users_screen.dart';
import '../../notifications/notifications_repository.dart';
import '../../notifications/screens/notifications_screen.dart';
import '../../reviews/reviews_repository.dart';
import '../../reviews/screens/ratings_screen.dart';
import '../widgets/profile_widgets.dart';
import 'edit_profile_screen.dart';

/// Account tab for a customer: who they are, where jobs get sent, and
/// the way out.
class CustomerProfileScreen extends StatefulWidget {
  const CustomerProfileScreen({
    super.key,
    required this.profile,
    required this.onProfileUpdated,
  });

  final Profile profile;
  final ValueChanged<Profile> onProfileUpdated;

  @override
  State<CustomerProfileScreen> createState() => _CustomerProfileScreenState();
}

class _CustomerProfileScreenState extends State<CustomerProfileScreen> {
  late Future<int> _unreadFuture;
  late Future<({double average, int count})?> _ratingFuture;
  late Future<bool> _isAdminFuture;
  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();
    _unreadFuture = NotificationsRepository().fetchUnreadCount();
    _ratingFuture =
        ReviewsRepository().fetchCustomerRating(widget.profile.id);
    _isAdminFuture = AdminRepository().amIAdmin();
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

  void _openRatings() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RatingsScreen(
          title: 'My rating',
          raterLabel: 'technicians',
          emptyMessage:
              'Technicians can rate you once they have completed a job for you.',
          fetchReviews: ReviewsRepository().fetchReviewsForCustomer,
        ),
      ),
    );
  }

  Future<void> _openEditProfile() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EditProfileScreen(
          profile: widget.profile,
          onSaved: widget.onProfileUpdated,
        ),
      ),
    );
  }

  Future<void> _deleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete your account?'),
        content: const Text(
          'This removes your personal details from InnSelf and signs you '
          'out everywhere. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Keep my account'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.destructive),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete account'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _isDeleting = true);
    try {
      await AuthRepository().deleteAccount();
      await AuthRepository().signOut();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not delete account: $e')),
      );
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
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
                  SettingsRow(
                    icon: Icons.edit_outlined,
                    label: 'Edit profile',
                    value: 'Update your name, phone and address',
                    onTap: _openEditProfile,
                  ),
                  FutureBuilder<({double average, int count})?>(
                    future: _ratingFuture,
                    builder: (context, snapshot) {
                      final rating = snapshot.data;
                      return SettingsRow(
                        icon: Icons.star_outline_rounded,
                        label: 'My rating',
                        value: rating == null
                            ? 'No ratings yet'
                            : '${rating.average.toStringAsFixed(1)} average from ${rating.count} review${rating.count == 1 ? '' : 's'}',
                        onTap: _openRatings,
                      );
                    },
                  ),
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
                    label: 'Saved addresses',
                    value: 'Manage the addresses you post jobs from',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const SavedAddressesScreen()),
                    ),
                  ),
                  SettingsRow(
                    icon: Icons.call_outlined,
                    label: 'Phone number',
                    value: profile.phone,
                  ),
                  SettingsRow(
                    icon: Icons.block_outlined,
                    label: 'Blocked users',
                    value: 'People you have blocked from messaging you',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const BlockedUsersScreen()),
                    ),
                  ),
                  FutureBuilder<bool>(
                    future: _isAdminFuture,
                    builder: (context, snapshot) {
                      if (snapshot.data != true) return const SizedBox.shrink();
                      return SettingsRow(
                        icon: Icons.shield_outlined,
                        label: 'Admin',
                        value: 'Review KYC submissions and disputes',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const AdminScreen()),
                        ),
                      );
                    },
                  ),
                  if (profile.lateCancellations > 0)
                    SettingsRow(
                      icon: Icons.event_busy_outlined,
                      label: 'Late cancellations',
                      value:
                          '${profile.lateCancellations} job${profile.lateCancellations == 1 ? '' : 's'} cancelled after a technician was assigned',
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
                  SettingsRow(
                    icon: Icons.delete_outline_rounded,
                    label: 'Delete account',
                    value: _isDeleting
                        ? 'Deleting...'
                        : 'Permanently remove your personal data',
                    iconBackground: const Color(0x1AD94B48),
                    iconColor: AppColors.destructive,
                    labelColor: AppColors.destructive,
                    onTap: _isDeleting ? null : _deleteAccount,
                    trailing: _isDeleting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : null,
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
