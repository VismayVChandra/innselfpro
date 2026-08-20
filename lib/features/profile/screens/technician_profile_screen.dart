import 'package:flutter/material.dart';

import '../../../core/format.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/widgets/layout.dart';
import '../../../core/widgets/states.dart';
import '../../../core/widgets/surfaces.dart';
import '../../../models/payment.dart';
import '../../../models/profile.dart';
import '../../../models/review.dart';
import '../../../models/technician_details.dart';
import '../../auth/auth_repository.dart';
import '../../notifications/notifications_repository.dart';
import '../../notifications/screens/notifications_screen.dart';
import '../../payments/payments_repository.dart';
import '../../payments/screens/technician_wallet_screen.dart';
import '../../reviews/reviews_repository.dart';
import '../../reviews/screens/technician_ratings_screen.dart';
import '../profile_repository.dart';
import '../widgets/profile_widgets.dart';
import 'edit_profile_screen.dart';

/// What the technician's account tab needs, in one fetch.
class _TechnicianSummary {
  const _TechnicianSummary({
    required this.payments,
    required this.reviews,
    required this.details,
    required this.unreadCount,
  });

  final List<Payment> payments;
  final List<Review> reviews;
  final TechnicianDetails? details;
  final int unreadCount;

  double get totalEarnings =>
      payments.fold<double>(0, (sum, p) => sum + p.amount);

  double? get averageRating => reviews.isEmpty
      ? null
      : reviews.map((r) => r.rating).reduce((a, b) => a + b) / reviews.length;
}

class TechnicianProfileScreen extends StatefulWidget {
  const TechnicianProfileScreen({
    super.key,
    required this.profile,
    required this.onProfileUpdated,
  });

  final Profile profile;
  final ValueChanged<Profile> onProfileUpdated;

  @override
  State<TechnicianProfileScreen> createState() =>
      _TechnicianProfileScreenState();
}

class _TechnicianProfileScreenState extends State<TechnicianProfileScreen> {
  late Future<_TechnicianSummary> _future;
  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_TechnicianSummary> _load() async {
    final payments = await PaymentsRepository().fetchMyEarnings();
    final reviews = await ReviewsRepository().fetchReviewsForTechnician();
    final details = await ProfileRepository().fetchMyTechnicianDetails();
    final unread = await NotificationsRepository().fetchUnreadCount();
    return _TechnicianSummary(
      payments: payments,
      reviews: reviews,
      details: details,
      unreadCount: unread,
    );
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
    await _future;
  }

  Future<void> _push(Widget screen) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
    if (mounted) _refresh();
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
    if (mounted) _refresh();
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
      child: RefreshIndicator(
        onRefresh: _refresh,
        color: AppColors.primary,
        backgroundColor: AppColors.card,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(top: 20, bottom: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const ScreenHeader(eyebrow: 'ACCOUNT', title: 'Profile'),
              ProfileHeaderCard(
                name: profile.fullName,
                subtitle: profile.phone,
                roleLabel: 'Technician',
              ),
              FutureBuilder<_TechnicianSummary>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return ErrorView(
                      message: 'Could not load your account: ${snapshot.error}',
                      onRetry: _refresh,
                    );
                  }
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const LoadingView(height: 240);
                  }
                  final summary = snapshot.data!;
                  final rating = summary.averageRating;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 14),
                      Padding(
                        padding:
                            const EdgeInsets.symmetric(horizontal: kGutter),
                        child: Row(
                          children: [
                            StatTile(
                              value: formatRupees(summary.totalEarnings),
                              label: 'Total earned',
                            ),
                            const SizedBox(width: 8),
                            StatTile(
                              value: rating == null
                                  ? '--'
                                  : rating.toStringAsFixed(1),
                              label: 'Your rating',
                            ),
                            const SizedBox(width: 8),
                            StatTile(
                              value: '${summary.payments.length}',
                              label: 'Jobs paid',
                            ),
                          ],
                        ),
                      ),
                      const SectionHeading(title: 'Your work'),
                      Padding(
                        padding:
                            const EdgeInsets.symmetric(horizontal: kGutter),
                        child: Column(
                          children: [
                            SettingsRow(
                              icon: Icons.edit_outlined,
                              label: 'Edit profile',
                              value:
                                  'Update your details, skills and service area',
                              onTap: _openEditProfile,
                            ),
                            SettingsRow(
                              icon: Icons.account_balance_wallet_outlined,
                              label: 'Wallet',
                              value:
                                  '${formatRupees(summary.totalEarnings)} earned across ${summary.payments.length} paid job${summary.payments.length == 1 ? '' : 's'}',
                              onTap: () =>
                                  _push(const TechnicianWalletScreen()),
                            ),
                            SettingsRow(
                              icon: Icons.star_outline_rounded,
                              label: 'My ratings',
                              value: summary.reviews.isEmpty
                                  ? 'No ratings yet'
                                  : '${rating!.toStringAsFixed(1)} average from ${summary.reviews.length} review${summary.reviews.length == 1 ? '' : 's'}',
                              onTap: () =>
                                  _push(const TechnicianRatingsScreen()),
                            ),
                            SettingsRow(
                              icon: Icons.notifications_none_rounded,
                              label: 'Notifications',
                              value: summary.unreadCount == 0
                                  ? 'You are all caught up'
                                  : '${summary.unreadCount} unread update${summary.unreadCount == 1 ? '' : 's'}',
                              onTap: () => _push(const NotificationsScreen()),
                            ),
                            SettingsRow(
                              icon: Icons.handyman_outlined,
                              label: 'Skills',
                              value: summary.details?.skills?.isNotEmpty == true
                                  ? summary.details!.skills!
                                  : 'Not set',
                            ),
                            SettingsRow(
                              icon: Icons.map_outlined,
                              label: 'Service area',
                              value: summary
                                          .details?.serviceArea?.isNotEmpty ==
                                      true
                                  ? summary.details!.serviceArea!
                                  : 'Not set',
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
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
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
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
