import 'package:flutter/material.dart';

import '../../../core/format.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/layout.dart';
import '../../../core/widgets/states.dart';
import '../../../core/widgets/surfaces.dart';
import '../../../models/admin_dispute.dart';
import '../../../models/kyc_submission.dart';
import '../admin_repository.dart';

/// The hidden operations surface (wave 7.3): approve or reject KYC
/// submissions and close disputes, so neither needs the Supabase console
/// any more. Only reachable when is_admin() returns true -- and every
/// call it makes re-checks that server-side regardless.
class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  final _repository = AdminRepository();
  late Future<List<KycSubmission>> _kycFuture;
  late Future<List<AdminDispute>> _disputesFuture;
  bool _showingKyc = true;
  String? _busyId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _kycFuture = _repository.fetchKycSubmissions(status: 'pending');
    _disputesFuture = _repository.fetchDisputes(status: 'open');
  }

  Future<void> _refresh() async {
    setState(_load);
    await Future.wait([_kycFuture, _disputesFuture]);
  }

  Future<void> _runAction(String id, Future<void> Function() action) async {
    setState(() => _busyId = id);
    try {
      await action();
      if (!mounted) return;
      setState(_load);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not complete that: $e')),
      );
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _approve(KycSubmission submission) => _runAction(
        submission.profileId,
        () => _repository.setKycStatus(
          profileId: submission.profileId,
          status: 'verified',
        ),
      );

  Future<void> _reject(KycSubmission submission) async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reject this submission?'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Why? The technician sees this so they can resubmit.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.destructive),
            onPressed: () => Navigator.of(dialogContext).pop(controller.text.trim()),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    if (reason == null || reason.isEmpty) return;
    await _runAction(
      submission.profileId,
      () => _repository.setKycStatus(
        profileId: submission.profileId,
        status: 'rejected',
        reason: reason,
      ),
    );
  }

  Future<void> _closeDispute(AdminDispute dispute) => _runAction(
        dispute.id,
        () => _repository.closeDispute(dispute.id),
      );

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
            padding: const EdgeInsets.only(top: 10, bottom: 36),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const TopBar(eyebrow: 'OPERATIONS', title: 'Admin'),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: kGutter),
                  child: Row(
                    children: [
                      ChoicePill(
                        label: 'Pending KYC',
                        selected: _showingKyc,
                        onTap: () => setState(() => _showingKyc = true),
                      ),
                      const SizedBox(width: 8),
                      ChoicePill(
                        label: 'Open disputes',
                        selected: !_showingKyc,
                        onTap: () => setState(() => _showingKyc = false),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                if (_showingKyc) _buildKycList() else _buildDisputeList(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildKycList() {
    return FutureBuilder<List<KycSubmission>>(
      future: _kycFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return ErrorView(
            message: 'Could not load submissions: ${snapshot.error}',
            onRetry: _refresh,
          );
        }
        if (snapshot.connectionState != ConnectionState.done) {
          return const LoadingView();
        }
        final submissions = snapshot.data!;
        if (submissions.isEmpty) {
          return const EmptyView(
            icon: Icons.verified_outlined,
            title: 'Nothing waiting',
            message: 'Every KYC submission has been reviewed.',
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionHeading(
              title: 'Awaiting review',
              actionLabel: '${submissions.length}',
              topPadding: 18,
            ),
            for (final submission in submissions)
              _KycCard(
                submission: submission,
                isBusy: _busyId == submission.profileId,
                onApprove: () => _approve(submission),
                onReject: () => _reject(submission),
              ),
          ],
        );
      },
    );
  }

  Widget _buildDisputeList() {
    return FutureBuilder<List<AdminDispute>>(
      future: _disputesFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return ErrorView(
            message: 'Could not load disputes: ${snapshot.error}',
            onRetry: _refresh,
          );
        }
        if (snapshot.connectionState != ConnectionState.done) {
          return const LoadingView();
        }
        final disputes = snapshot.data!;
        if (disputes.isEmpty) {
          return const EmptyView(
            icon: Icons.flag_outlined,
            title: 'No open disputes',
            message: 'Nothing needs your attention right now.',
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionHeading(
              title: 'Open disputes',
              actionLabel: '${disputes.length}',
              topPadding: 18,
            ),
            for (final dispute in disputes)
              _DisputeCard(
                dispute: dispute,
                isBusy: _busyId == dispute.id,
                onClose: () => _closeDispute(dispute),
              ),
          ],
        );
      },
    );
  }
}

class _KycCard extends StatelessWidget {
  const _KycCard({
    required this.submission,
    required this.isBusy,
    required this.onApprove,
    required this.onReject,
  });

  final KycSubmission submission;
  final bool isBusy;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: AppCard(
        radius: 19,
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const SoftIcon(Icons.badge_outlined, size: 42, iconSize: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(submission.fullName, style: AppText.cardTitleLarge),
                      const SizedBox(height: 3),
                      Text(
                        '${submission.phone}  ·  ${submission.idNumber}',
                        style: AppText.bodyMuted.copyWith(fontSize: 10.5),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Submitted ${formatDateTime(submission.submittedAt)}',
              style: AppText.bodyMuted.copyWith(fontSize: 10),
            ),
            const SizedBox(height: 6),
            // The bucket is private, so the path is shown rather than the
            // image -- opening it needs a signed URL, which is a console
            // step for now.
            Text(
              'Document: ${submission.idDocumentUrl}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppText.bodyMuted.copyWith(fontSize: 10),
            ),
            const SizedBox(height: 14),
            if (isBusy)
              const Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else
              Row(
                children: [
                  Expanded(
                    child: OutlineButton(
                      label: 'Reject',
                      color: AppColors.destructive,
                      margin: EdgeInsets.zero,
                      onPressed: onReject,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlineButton(
                      label: 'Approve',
                      icon: Icons.verified_rounded,
                      color: AppColors.success,
                      margin: EdgeInsets.zero,
                      onPressed: onApprove,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _DisputeCard extends StatelessWidget {
  const _DisputeCard({
    required this.dispute,
    required this.isBusy,
    required this.onClose,
  });

  final AdminDispute dispute;
  final bool isBusy;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: AppCard(
        radius: 19,
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const SoftIcon(
                  Icons.flag_outlined,
                  background: Color(0x1AD94B48),
                  foreground: AppColors.destructive,
                  size: 42,
                  iconSize: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${dispute.categoryName} job',
                        style: AppText.cardTitleLarge,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Flagged by ${dispute.flaggedByName}  ·  ${humanizeStatus(dispute.jobStatus)}',
                        style: AppText.bodyMuted.copyWith(fontSize: 10.5),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '"${dispute.reason}"',
              style: AppText.body.copyWith(fontSize: 12.5, fontStyle: FontStyle.italic),
            ),
            const SizedBox(height: 8),
            Text(
              'Job ${dispute.jobId.substring(0, 8)}  ·  ${formatDateTime(dispute.createdAt)}',
              style: AppText.bodyMuted.copyWith(fontSize: 10),
            ),
            const SizedBox(height: 14),
            OutlineButton(
              label: 'Mark resolved',
              icon: Icons.check_rounded,
              margin: EdgeInsets.zero,
              isLoading: isBusy,
              onPressed: onClose,
            ),
          ],
        ),
      ),
    );
  }
}
