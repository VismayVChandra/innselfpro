import 'package:flutter/material.dart';

import '../../../core/format.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/widgets/layout.dart';
import '../../../core/widgets/states.dart';
import '../../../core/widgets/surfaces.dart';
import '../../../models/kyc_submission.dart';
import '../../../models/payment.dart';
import '../../../models/profile.dart';
import '../../../models/review.dart';
import '../../../models/technician_details.dart';
import '../../admin/admin_repository.dart';
import '../../admin/screens/admin_screen.dart';
import '../../auth/auth_repository.dart';
import '../../safety/screens/blocked_users_screen.dart';
import '../../jobs/jobs_repository.dart';
import '../../notifications/notifications_repository.dart';
import '../../notifications/screens/notifications_screen.dart';
import '../../payments/payments_repository.dart';
import '../../payments/screens/technician_wallet_screen.dart';
import '../../reviews/reviews_repository.dart';
import '../../reviews/screens/ratings_screen.dart';
import '../profile_repository.dart';
import '../widgets/profile_widgets.dart';
import 'edit_profile_screen.dart';

/// What the technician's account tab needs, in one fetch.
class _TechnicianSummary {
  const _TechnicianSummary({
    required this.payments,
    required this.reviews,
    required this.details,
    required this.skillNames,
    required this.unreadCount,
    required this.kyc,
    required this.isAdmin,
  });

  final List<Payment> payments;
  final List<Review> reviews;
  final TechnicianDetails? details;
  final List<String> skillNames;
  final int unreadCount;
  final KycSubmission? kyc;
  final bool isAdmin;

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
  bool _isTogglingAvailability = false;

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
    final skillIds = await ProfileRepository().fetchMySkillCategoryIds();
    final categories = await JobsRepository().fetchCategories();
    final skillNames = categories
        .where((c) => skillIds.contains(c.id))
        .map((c) => c.name)
        .toList();
    final kyc = await ProfileRepository().fetchMyKyc();
    final isAdmin = await AdminRepository().amIAdmin();
    return _TechnicianSummary(
      payments: payments,
      reviews: reviews,
      details: details,
      skillNames: skillNames,
      unreadCount: unread,
      kyc: kyc,
      isAdmin: isAdmin,
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

  bool? _availabilityOverride;

  Future<void> _toggleAvailability(bool current) async {
    final next = !current;
    setState(() {
      _availabilityOverride = next;
      _isTogglingAvailability = true;
    });
    try {
      await ProfileRepository().setAvailability(next);
    } catch (e) {
      if (!mounted) return;
      setState(() => _availabilityOverride = current);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update availability: $e')),
      );
    } finally {
      if (mounted) setState(() => _isTogglingAvailability = false);
    }
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
                  final isAvailable =
                      _availabilityOverride ?? summary.details?.isAvailable ?? true;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _KycStatusCard(kyc: summary.kyc),
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
                              onTap: () => _push(RatingsScreen(
                                title: 'My ratings',
                                raterLabel: 'customers',
                                emptyMessage:
                                    'Customers can rate you once they have paid for a completed job.',
                                fetchReviews:
                                    ReviewsRepository().fetchReviewsForTechnician,
                              )),
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
                              value: summary.skillNames.isEmpty
                                  ? 'Not set'
                                  : summary.skillNames.join(', '),
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
                              icon: Icons.block_outlined,
                              label: 'Blocked users',
                              value: 'People you have blocked from messaging you',
                              onTap: () => _push(const BlockedUsersScreen()),
                            ),
                            SettingsRow(
                              icon: isAvailable
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              label: 'Available for new jobs',
                              value: isAvailable
                                  ? "You'll get new-job alerts and can be rebooked"
                                  : 'Hidden from alerts and rebook',
                              trailing: _isTogglingAvailability
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : Switch(
                                      value: isAvailable,
                                      onChanged: (_) => _toggleAvailability(isAvailable),
                                      activeTrackColor: AppColors.primary,
                                    ),
                            ),
                            if (summary.isAdmin)
                              SettingsRow(
                                icon: Icons.shield_outlined,
                                label: 'Admin',
                                value: 'Review KYC submissions and disputes',
                                onTap: () => _push(const AdminScreen()),
                              ),
                            if (widget.profile.lateCancellations > 0)
                              SettingsRow(
                                icon: Icons.event_busy_outlined,
                                label: 'Late cancellations',
                                value:
                                    '${widget.profile.lateCancellations} job${widget.profile.lateCancellations == 1 ? '' : 's'} cancelled after being assigned',
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

/// The technician's own view of KYC (wave 7.1): pending, verified, or
/// rejected with the reason, so someone who was turned down knows to
/// resubmit rather than wondering why no badge ever appeared.
class _KycStatusCard extends StatelessWidget {
  const _KycStatusCard({required this.kyc});

  final KycSubmission? kyc;

  @override
  Widget build(BuildContext context) {
    final status = kyc?.status ?? 'missing';
    final ({IconData icon, Color color, Color background, String title, String message}) style =
        switch (status) {
      'verified' => (
          icon: Icons.verified_rounded,
          color: AppColors.success,
          background: AppColors.successSurface,
          title: 'You are verified',
          message: 'Customers see a verified badge on your bids.',
        ),
      'rejected' => (
          icon: Icons.error_outline_rounded,
          color: AppColors.destructive,
          background: const Color(0x1AD94B48),
          title: 'ID check was rejected',
          message: kyc?.rejectionReason?.isNotEmpty == true
              ? '${kyc!.rejectionReason!}  Re-upload your ID from Edit profile.'
              : 'Re-upload a clearer photo of your ID from Edit profile.',
        ),
      'pending' => (
          icon: Icons.hourglass_top_rounded,
          color: AppColors.warn,
          background: AppColors.warnSurface,
          title: 'ID check in progress',
          message: 'We are reviewing your document. This usually takes a day.',
        ),
      _ => (
          icon: Icons.badge_outlined,
          color: AppColors.mutedForeground,
          background: AppColors.muted,
          title: 'No ID on file',
          message: 'Upload your ID to earn a verified badge on your bids.',
        ),
    };

    return Padding(
      padding: const EdgeInsets.only(top: 13),
      child: AppCard(
        radius: 19,
        padding: const EdgeInsets.all(15),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SoftIcon(
              style.icon,
              background: style.background,
              foreground: style.color,
              size: 40,
              iconSize: 19,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(style.title, style: AppText.cardTitle),
                  const SizedBox(height: 4),
                  Text(style.message, style: AppText.bodyMuted.copyWith(fontSize: 10.5)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
