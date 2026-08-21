import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/format.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/layout.dart';
import '../../../core/widgets/photo_picker.dart';
import '../../../core/widgets/states.dart';
import '../../../core/widgets/surfaces.dart';
import '../../../models/bid.dart';
import '../../../models/dispute.dart';
import '../../../models/job.dart';
import '../../../models/payment.dart';
import '../../../models/profile.dart';
import '../../../models/review.dart';
import '../../bids/bids_repository.dart';
import '../../disputes/disputes_repository.dart';
import '../../payments/payment_service.dart';
import '../../payments/payments_repository.dart';
import '../../profile/profile_repository.dart';
import '../../reviews/reviews_repository.dart';
import '../job_status.dart';
import '../jobs_repository.dart';

class JobDetailScreen extends StatefulWidget {
  const JobDetailScreen({
    super.key,
    required this.initialJob,
    required this.viewerProfile,
  });

  final Job initialJob;
  final Profile viewerProfile;

  @override
  State<JobDetailScreen> createState() => _JobDetailScreenState();
}

class _JobDetailScreenState extends State<JobDetailScreen> {
  final _jobsRepository = JobsRepository();
  final _bidsRepository = BidsRepository();
  final _paymentsRepository = PaymentsRepository();
  final _paymentService = PaymentService();
  final _reviewsRepository = ReviewsRepository();
  final _disputesRepository = DisputesRepository();
  final _profileRepository = ProfileRepository();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  final _reviewCommentController = TextEditingController();
  final _customerReviewCommentController = TextEditingController();

  late Job _job;
  Future<List<Bid>>? _bidsFuture;
  Future<Bid?>? _myBidFuture;
  Future<Payment?>? _paymentFuture;
  Future<Review?>? _reviewFuture;
  Future<Review?>? _customerReviewFuture;
  Future<Dispute?>? _disputeFuture;

  /// The other party's contact card once a bid is accepted -- the
  /// technician for a customer, the customer for the winning technician
  /// -- plus that party's own rating, so it's a reminder of who you're
  /// working with rather than just a phone number. Set in initState for
  /// the customer (their own job, always safe); set lazily inside the
  /// technician branch only after confirming their bid is the accepted
  /// one, so a technician whose bid lost never sees the customer's
  /// number.
  Future<({Profile profile, double? rating, int reviewCount})?>? _contactFuture;

  bool _isSubmittingBid = false;
  String? _acceptingBidId;
  bool _isUpdatingStatus = false;
  bool _isStartingPayment = false;
  bool _isConfirmingPayment = false;
  bool _isMarkingCashPaid = false;
  int _selectedRating = 0;
  bool _isSubmittingReview = false;
  int _selectedCustomerRating = 0;
  bool _isSubmittingCustomerReview = false;
  bool _isFlagging = false;
  bool _isCancelling = false;
  bool _isWithdrawingBid = false;
  File? _completionPhoto;

  bool get _isOwningCustomer =>
      widget.viewerProfile.isCustomer && widget.viewerProfile.id == _job.customerId;
  bool get _isTechnician => widget.viewerProfile.isTechnician;

  @override
  void initState() {
    super.initState();
    _job = widget.initialJob;
    if (_isOwningCustomer) {
      _bidsFuture = _bidsRepository.fetchBidsForJob(_job.id);
      if (_job.status == 'completed') {
        _paymentFuture = _paymentsRepository.fetchPaymentForJob(_job.id);
        _reviewFuture =
            _reviewsRepository.fetchReviewForJob(_job.id, reviewerRole: 'customer');
      }
      if (_job.status != 'open') {
        _disputeFuture = _disputesRepository.fetchDisputeForJob(_job.id);
      }
      if (_job.acceptedBidId != null) {
        _contactFuture = _loadTechnicianContact();
      }
    } else if (_isTechnician) {
      _myBidFuture = _bidsRepository.fetchMyBidForJob(_job.id);
      if (_job.status != 'open') {
        _disputeFuture = _disputesRepository.fetchDisputeForJob(_job.id);
      }
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    _reviewCommentController.dispose();
    _customerReviewCommentController.dispose();
    _paymentService.dispose();
    super.dispose();
  }

  Future<void> _refreshJob() async {
    final updated = await _jobsRepository.fetchJobById(_job.id);
    if (!mounted) return;
    setState(() => _job = updated);
  }

  Future<({Profile profile, double? rating, int reviewCount})?> _loadTechnicianContact() async {
    final technicianId =
        await _bidsRepository.fetchTechnicianIdForBid(_job.acceptedBidId!);
    final profile = await _profileRepository.fetchProfileById(technicianId);
    if (profile == null) return null;
    final ratings = await _bidsRepository.fetchTechnicianRatings([technicianId]);
    final rating = ratings[technicianId];
    return (profile: profile, rating: rating?.average, reviewCount: rating?.count ?? 0);
  }

  Future<({Profile profile, double? rating, int reviewCount})?> _loadCustomerContact() async {
    final profile = await _profileRepository.fetchProfileById(_job.customerId);
    if (profile == null) return null;
    final rating = await _reviewsRepository.fetchCustomerRating(_job.customerId);
    return (
      profile: profile,
      rating: rating?.average,
      reviewCount: rating?.count ?? 0,
    );
  }

  Future<void> _pickCompletionPhoto() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (picked != null) {
      setState(() => _completionPhoto = File(picked.path));
    }
  }

  Future<void> _cancelJob() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancel this request?'),
        content: const Text(
          'Technicians who already bid will no longer be able to help with this job. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Keep request'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.destructive),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Cancel request'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _isCancelling = true);
    try {
      await _jobsRepository.cancelJob(_job.id);
      await _refreshJob();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not cancel job: $e')),
      );
    } finally {
      if (mounted) setState(() => _isCancelling = false);
    }
  }

  Future<void> _withdrawBid(String bidId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Withdraw your bid?'),
        content: const Text(
          'You can submit a new bid later if the job is still open.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Keep bid'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.destructive),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Withdraw'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _isWithdrawingBid = true);
    try {
      await _bidsRepository.withdrawBid(bidId);
      if (!mounted) return;
      setState(() {
        _myBidFuture = _bidsRepository.fetchMyBidForJob(_job.id);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not withdraw bid: $e')),
      );
    } finally {
      if (mounted) setState(() => _isWithdrawingBid = false);
    }
  }

  Future<void> _submitBid() async {
    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid amount')),
      );
      return;
    }
    setState(() => _isSubmittingBid = true);
    try {
      await _bidsRepository.submitBid(
        jobId: _job.id,
        amount: amount,
        note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _myBidFuture = _bidsRepository.fetchMyBidForJob(_job.id);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not submit bid: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSubmittingBid = false);
    }
  }

  Future<void> _startPayment() async {
    setState(() => _isStartingPayment = true);
    try {
      final order = await _paymentsRepository.createOrder(_job.id);
      _paymentService.open(
        keyId: order['keyId'] as String,
        orderId: order['orderId'] as String,
        amountInPaise: order['amount'] as int,
        description: _job.categoryName,
        onSuccess: () async {
          if (!mounted) return;
          setState(() {
            _isStartingPayment = false;
            _isConfirmingPayment = true;
          });
          // Give the Razorpay webhook a moment to land before re-checking.
          await Future.delayed(const Duration(seconds: 2));
          if (!mounted) return;
          setState(() {
            _isConfirmingPayment = false;
            _paymentFuture = _paymentsRepository.fetchPaymentForJob(_job.id);
          });
        },
        onError: (message) {
          if (!mounted) return;
          setState(() => _isStartingPayment = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Payment failed: $message')),
          );
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isStartingPayment = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not start payment: $e')),
      );
    }
  }

  Future<void> _markPaidInCash() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirm cash payment'),
        content: const Text(
          "Only confirm this once you've actually handed over the cash -- "
          'it closes out the job immediately and cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Not yet'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text("I've paid in cash"),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _isMarkingCashPaid = true);
    try {
      await _paymentsRepository.markPaidInCash(_job.id);
      if (!mounted) return;
      setState(() {
        _paymentFuture = _paymentsRepository.fetchPaymentForJob(_job.id);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not record cash payment: $e')),
      );
    } finally {
      if (mounted) setState(() => _isMarkingCashPaid = false);
    }
  }

  Future<void> _startJob() async {
    setState(() => _isUpdatingStatus = true);
    try {
      await _jobsRepository.startJob(_job.id);
      await _refreshJob();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not start job: $e')),
      );
    } finally {
      if (mounted) setState(() => _isUpdatingStatus = false);
    }
  }

  Future<void> _completeJob() async {
    setState(() => _isUpdatingStatus = true);
    try {
      await _jobsRepository.completeJob(_job.id, completionPhoto: _completionPhoto);
      await _refreshJob();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not mark job completed: $e')),
      );
    } finally {
      if (mounted) setState(() => _isUpdatingStatus = false);
    }
  }

  Future<void> _submitReview() async {
    setState(() => _isSubmittingReview = true);
    try {
      final technicianId =
          await _bidsRepository.fetchTechnicianIdForBid(_job.acceptedBidId!);
      await _reviewsRepository.submitReview(
        jobId: _job.id,
        technicianId: technicianId,
        rating: _selectedRating,
        comment: _reviewCommentController.text.trim().isEmpty
            ? null
            : _reviewCommentController.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _reviewFuture =
            _reviewsRepository.fetchReviewForJob(_job.id, reviewerRole: 'customer');
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not submit review: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSubmittingReview = false);
    }
  }

  Future<void> _submitCustomerReview() async {
    setState(() => _isSubmittingCustomerReview = true);
    try {
      await _reviewsRepository.submitTechnicianReview(
        jobId: _job.id,
        customerId: _job.customerId,
        rating: _selectedCustomerRating,
        comment: _customerReviewCommentController.text.trim().isEmpty
            ? null
            : _customerReviewCommentController.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _customerReviewFuture =
            _reviewsRepository.fetchReviewForJob(_job.id, reviewerRole: 'technician');
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not submit review: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSubmittingCustomerReview = false);
    }
  }

  Future<void> _showFlagDialog() async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Flag an issue'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'What went wrong?'),
          maxLines: 3,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text.trim()),
            child: const Text('Submit'),
          ),
        ],
      ),
    );
    if (reason == null || reason.isEmpty) return;
    setState(() => _isFlagging = true);
    try {
      await _disputesRepository.flagJob(jobId: _job.id, reason: reason);
      if (!mounted) return;
      setState(() {
        _disputeFuture = _disputesRepository.fetchDisputeForJob(_job.id);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not flag job: $e')),
      );
    } finally {
      if (mounted) setState(() => _isFlagging = false);
    }
  }

  Future<void> _confirmAndAcceptBid(Bid bid) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Choose this technician?'),
        content: Text(
          '${bid.technicianName.isEmpty ? 'This technician' : bid.technicianName} '
          'will be assigned at ${formatRupees(bid.amount)}. Every other bid on '
          'this job will be rejected, and this cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Not yet'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _acceptBid(bid);
  }

  Future<void> _acceptBid(Bid bid) async {
    setState(() => _acceptingBidId = bid.id);
    try {
      await _bidsRepository.acceptBid(jobId: _job.id, bidId: bid.id);
      await _refreshJob();
      if (!mounted) return;
      setState(() {
        _bidsFuture = _bidsRepository.fetchBidsForJob(_job.id);
        _disputeFuture = _disputesRepository.fetchDisputeForJob(_job.id);
        _contactFuture = _loadTechnicianContact();
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not accept bid: $e')),
      );
    } finally {
      if (mounted) setState(() => _acceptingBidId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(top: 10, bottom: 36),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TopBar(
                eyebrow: 'JOB ${_job.id.substring(0, 8)}',
                title: _job.categoryName,
              ),
              _StatusPanel(job: _job, forTechnician: _isTechnician),
              if (JobStatusInfo.showsTimeline(_job.status)) ...[
                const SizedBox(height: 13),
                _TimelineCard(step: JobStatusInfo.of(_job.status).step),
              ],
              const SizedBox(height: 13),
              _JobFactsCard(job: _job),
              if (_job.photoUrl != null) ...[
                const SizedBox(height: 13),
                _JobPhoto(url: _job.photoUrl!),
              ],
              if (_job.completionPhotoUrl != null) ...[
                const SectionHeading(title: 'Completion photo', topPadding: 20),
                _JobPhoto(url: _job.completionPhotoUrl!),
              ],
              if (_isTechnician) _buildTechnicianSection(),
              if (_isOwningCustomer) _buildCustomerSection(),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- technician

  Widget _buildTechnicianSection() {
    return FutureBuilder<Bid?>(
      future: _myBidFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const LoadingView(height: 160);
        }
        final myBid = snapshot.data;

        if (_job.status == 'open') {
          if (myBid != null) {
            return Padding(
              padding: const EdgeInsets.only(top: 13),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppCard(
                    radius: 21,
                    padding: const EdgeInsets.all(17),
                    child: Row(
                      children: [
                        const SoftIcon(
                          Icons.check_circle_outline,
                          background: AppColors.successSurface,
                          foreground: AppColors.success,
                          size: 42,
                          iconSize: 21,
                        ),
                        const SizedBox(width: 13),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Your bid is in', style: AppText.cardTitleLarge),
                              const SizedBox(height: 4),
                              Text(
                                'You quoted ${formatRupees(myBid.amount)}  ·  ${humanizeStatus(myBid.status)}',
                                style: AppText.bodyMuted,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 13),
                  OutlineButton(
                    label: 'Withdraw bid',
                    icon: Icons.undo_rounded,
                    color: AppColors.destructive,
                    isLoading: _isWithdrawingBid,
                    onPressed: () => _withdrawBid(myBid.id),
                  ),
                ],
              ),
            );
          }
          return _SectionCard(
            title: 'Submit a bid',
            subtitle: 'Quote a fair price and tell the customer why you.',
            children: [
              TextField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: AppText.body.copyWith(fontSize: 13),
                decoration: const InputDecoration(
                  labelText: 'Your price',
                  prefixText: '₹ ',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _noteController,
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
                style: AppText.body.copyWith(fontSize: 13),
                decoration: const InputDecoration(
                  labelText: 'Note (optional)',
                  hintText: 'What is included, when you can come...',
                ),
              ),
              const SizedBox(height: 16),
              PrimaryButton(
                label: 'Submit bid',
                margin: EdgeInsets.zero,
                isLoading: _isSubmittingBid,
                onPressed: _submitBid,
              ),
            ],
          );
        }

        // Job is no longer open. Only the technician whose bid was
        // accepted has anything to do here.
        if (myBid == null || myBid.status != 'accepted') {
          final cancelled = _job.status == 'cancelled';
          return Padding(
            padding: const EdgeInsets.only(top: 13),
            child: EmptyStateCard(
              icon: cancelled ? Icons.block_outlined : Icons.lock_outline_rounded,
              title: cancelled ? 'Request cancelled' : 'This job is closed',
              message: cancelled
                  ? 'The customer cancelled this request before choosing a technician.'
                  : myBid == null
                      ? 'It was assigned before you placed a bid.'
                      : 'The customer chose a different technician this time.',
            ),
          );
        }

        // From here on myBid.status == 'accepted' is confirmed, so it's
        // safe to load the customer's contact details for this job --
        // memoized so it isn't re-fetched on every rebuild.
        _contactFuture ??= _loadCustomerContact();
        if (_job.status == 'completed') {
          _customerReviewFuture ??=
              _reviewsRepository.fetchReviewForJob(_job.id, reviewerRole: 'technician');
        }

        Widget? action;
        Widget? photoPicker;
        if (_job.status == 'bid_accepted') {
          action = PrimaryButton(
            label: 'Start this job',
            isLoading: _isUpdatingStatus,
            onPressed: _startJob,
          );
        } else if (_job.status == 'in_progress') {
          photoPicker = JobPhotoPicker(
            photo: _completionPhoto,
            onPick: _pickCompletionPhoto,
            onClear: () => setState(() => _completionPhoto = null),
            title: 'Add proof of work',
            subtitle: 'Optional, but reassures the customer the job is done.',
          );
          action = PrimaryButton(
            label: 'Mark as completed',
            isLoading: _isUpdatingStatus,
            onPressed: _completeJob,
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FutureBuilder<({Profile profile, double? rating, int reviewCount})?>(
              future: _contactFuture,
              builder: (context, contactSnapshot) {
                final contact = contactSnapshot.data;
                if (contact == null) return const SizedBox.shrink();
                return _ContactCard(
                  label: 'Your customer',
                  profile: contact.profile,
                  rating: contact.rating,
                  reviewCount: contact.reviewCount,
                );
              },
            ),
            Padding(
              padding: const EdgeInsets.only(top: 13),
              child: AppCard(
                radius: 21,
                padding: const EdgeInsets.all(17),
                child: Row(
                  children: [
                    const SoftIcon(
                      Icons.workspace_premium_outlined,
                      size: 42,
                      iconSize: 21,
                    ),
                    const SizedBox(width: 13),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('You won this job', style: AppText.cardTitleLarge),
                          const SizedBox(height: 4),
                          Text(
                            'Agreed price ${formatRupees(myBid.amount)}',
                            style: AppText.bodyMuted,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (photoPicker != null) ...[const SizedBox(height: 16), photoPicker],
            if (action != null) ...[const SizedBox(height: 20), action],
            if (_job.status == 'completed') ...[
              const SizedBox(height: 13),
              _NoticeCard(
                icon: Icons.check_circle_outline,
                background: AppColors.successSurface,
                foreground: AppColors.success,
                title: 'Work completed',
                message:
                    'Once the customer pays, it will show up in your wallet.',
              ),
              _buildCustomerReviewSection(),
            ],
            _buildDisputeSection(),
          ],
        );
      },
    );
  }

  // ------------------------------------------------------------------ customer

  Widget _buildCustomerSection() {
    if (_job.status != 'open') {
      Widget? notice;
      if (_job.status == 'bid_accepted') {
        notice = _NoticeCard(
          icon: Icons.engineering_outlined,
          title: 'Your technician is assigned',
          message: 'They will start the work shortly.',
        );
      } else if (_job.status == 'in_progress') {
        notice = _NoticeCard(
          icon: Icons.handyman_outlined,
          background: const Color(0x1FF0644F),
          foreground: AppColors.primary,
          title: 'Work in progress',
          message: 'Your technician is on the job right now.',
        );
      } else if (_job.status == 'cancelled') {
        notice = _NoticeCard(
          icon: Icons.block_outlined,
          background: AppColors.muted,
          foreground: AppColors.mutedForeground,
          title: 'Request cancelled',
          message: 'You cancelled this request before choosing a technician.',
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_job.acceptedBidId != null)
            FutureBuilder<({Profile profile, double? rating, int reviewCount})?>(
              future: _contactFuture,
              builder: (context, contactSnapshot) {
                final contact = contactSnapshot.data;
                if (contact == null) return const SizedBox.shrink();
                return _ContactCard(
                  label: 'Your technician',
                  profile: contact.profile,
                  rating: contact.rating,
                  reviewCount: contact.reviewCount,
                );
              },
            ),
          if (notice != null) Padding(padding: const EdgeInsets.only(top: 13), child: notice),
          if (_job.status == 'completed') ...[
            _buildPaymentSection(),
            _buildReviewSection(),
          ],
          if (_job.status != 'cancelled') _buildDisputeSection(),
        ],
      );
    }

    return FutureBuilder<List<Bid>>(
      future: _bidsFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return ErrorView(message: 'Could not load bids: ${snapshot.error}');
        }
        if (snapshot.connectionState != ConnectionState.done) {
          return const LoadingView(height: 160);
        }
        final bids = snapshot.data!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (bids.isEmpty) ...[
              const SectionHeading(title: 'Bids received', topPadding: 28),
              const EmptyView(
                icon: Icons.hourglass_empty_rounded,
                title: 'No bids yet',
                message:
                    'Local technicians are seeing your request. We will notify you the moment one bids.',
              ),
            ] else ...[
              SectionHeading(
                title:
                    '${bids.length} technician${bids.length == 1 ? '' : 's'} interested',
                actionLabel: 'Lowest first',
                topPadding: 28,
              ),
              for (var i = 0; i < bids.length; i++)
                _BidCard(
                  bid: bids[i],
                  isLowest: i == 0 && bids.length > 1,
                  isAccepting: _acceptingBidId == bids[i].id,
                  acceptDisabled: _acceptingBidId != null,
                  onAccept: () => _confirmAndAcceptBid(bids[i]),
                ),
              const FootNote('Your address is shared once you choose a pro.'),
            ],
            const SizedBox(height: 20),
            OutlineButton(
              label: 'Cancel this request',
              icon: Icons.close_rounded,
              color: AppColors.destructive,
              isLoading: _isCancelling,
              onPressed: _cancelJob,
            ),
          ],
        );
      },
    );
  }

  Widget _buildPaymentSection() {
    if (_isConfirmingPayment) {
      return Padding(
        padding: const EdgeInsets.only(top: 13),
        child: AppCard(
          radius: 21,
          padding: const EdgeInsets.all(17),
          child: Row(
            children: [
              const SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 14),
              Text('Confirming your payment...', style: AppText.cardTitle),
            ],
          ),
        ),
      );
    }
    return FutureBuilder<Payment?>(
      future: _paymentFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return ErrorView(
            message: 'Could not load payment status: ${snapshot.error}',
          );
        }
        if (snapshot.connectionState != ConnectionState.done) {
          return const LoadingView(height: 140);
        }
        final payment = snapshot.data;
        if (payment?.status == 'paid') {
          return Padding(
            padding: const EdgeInsets.only(top: 13),
            child: _NoticeCard(
              icon: Icons.verified_outlined,
              background: AppColors.successSurface,
              foreground: AppColors.success,
              title: 'Paid ${formatRupees(payment!.amount)}${payment.isCash ? ' (cash)' : ''}',
              message: payment.paidAt == null
                  ? 'This job is settled.'
                  : 'Settled on ${formatDateTime(payment.paidAt!)}.',
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SectionHeading(title: 'Payment', topPadding: 28),
            AppCard(
              radius: 21,
              padding: const EdgeInsets.all(17),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'The work is done. Pay to close it out.',
                    style: AppText.cardTitleLarge,
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'You only pay after the job is marked complete.',
                    style: AppText.bodyMuted,
                  ),
                  const SizedBox(height: 16),
                  PrimaryButton(
                    label: 'Pay online',
                    margin: EdgeInsets.zero,
                    isLoading: _isStartingPayment,
                    onPressed: _isMarkingCashPaid ? null : _startPayment,
                  ),
                  const SizedBox(height: 10),
                  OutlineButton(
                    label: "I've paid in cash",
                    icon: Icons.payments_outlined,
                    margin: EdgeInsets.zero,
                    isLoading: _isMarkingCashPaid,
                    onPressed: _isStartingPayment ? null : _markPaidInCash,
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildReviewSection() {
    return FutureBuilder<Review?>(
      future: _reviewFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return ErrorView(message: 'Could not load review: ${snapshot.error}');
        }
        if (snapshot.connectionState != ConnectionState.done) {
          return const LoadingView(height: 140);
        }
        final review = snapshot.data;
        if (review != null) {
          return _SectionCard(
            title: 'Your review',
            children: [
              StarRow(rating: review.rating, size: 20),
              if (review.comment != null && review.comment!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  '"${review.comment!}"',
                  style: AppText.body.copyWith(fontStyle: FontStyle.italic),
                ),
              ],
            ],
          );
        }
        return _SectionCard(
          title: 'Rate your technician',
          subtitle: 'Your rating helps other neighbours choose well.',
          children: [
            Center(
              child: StarRow(
                rating: _selectedRating,
                onChanged: (r) => setState(() => _selectedRating = r),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _reviewCommentController,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              style: AppText.body.copyWith(fontSize: 13),
              decoration: const InputDecoration(
                hintText: 'Anything you want to add? (optional)',
              ),
            ),
            const SizedBox(height: 16),
            PrimaryButton(
              label: 'Submit review',
              margin: EdgeInsets.zero,
              isLoading: _isSubmittingReview,
              onPressed: _selectedRating == 0 ? null : _submitReview,
            ),
          ],
        );
      },
    );
  }

  /// The technician's side of two-way reviews: rating the customer back
  /// once the job is done. Mirrors _buildReviewSection exactly, just in
  /// the other direction.
  Widget _buildCustomerReviewSection() {
    return FutureBuilder<Review?>(
      future: _customerReviewFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return ErrorView(message: 'Could not load review: ${snapshot.error}');
        }
        if (snapshot.connectionState != ConnectionState.done) {
          return const LoadingView(height: 140);
        }
        final review = snapshot.data;
        if (review != null) {
          return _SectionCard(
            title: 'Your rating of the customer',
            children: [
              StarRow(rating: review.rating, size: 20),
              if (review.comment != null && review.comment!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  '"${review.comment!}"',
                  style: AppText.body.copyWith(fontStyle: FontStyle.italic),
                ),
              ],
            ],
          );
        }
        return _SectionCard(
          title: 'Rate this customer',
          subtitle: 'Helps other technicians know who they\'re working with.',
          children: [
            Center(
              child: StarRow(
                rating: _selectedCustomerRating,
                onChanged: (r) => setState(() => _selectedCustomerRating = r),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _customerReviewCommentController,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              style: AppText.body.copyWith(fontSize: 13),
              decoration: const InputDecoration(
                hintText: 'Anything you want to add? (optional)',
              ),
            ),
            const SizedBox(height: 16),
            PrimaryButton(
              label: 'Submit rating',
              margin: EdgeInsets.zero,
              isLoading: _isSubmittingCustomerReview,
              onPressed: _selectedCustomerRating == 0 ? null : _submitCustomerReview,
            ),
          ],
        );
      },
    );
  }

  Widget _buildDisputeSection() {
    return FutureBuilder<Dispute?>(
      future: _disputeFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return ErrorView(
            message: 'Could not load dispute status: ${snapshot.error}',
          );
        }
        if (snapshot.connectionState != ConnectionState.done) {
          return const SizedBox.shrink();
        }
        final dispute = snapshot.data;
        if (dispute != null) {
          return Padding(
            padding: const EdgeInsets.only(top: 13),
            child: _NoticeCard(
              icon: Icons.flag_outlined,
              background: const Color(0x1AD94B48),
              foreground: AppColors.destructive,
              title: 'Issue flagged  ·  ${humanizeStatus(dispute.status)}',
              message: dispute.reason,
            ),
          );
        }
        return Padding(
          padding: const EdgeInsets.only(top: 20),
          child: OutlineButton(
            label: 'Flag an issue with this job',
            icon: Icons.flag_outlined,
            color: AppColors.destructive,
            isLoading: _isFlagging,
            onPressed: _showFlagDialog,
          ),
        );
      },
    );
  }
}

/// Dark "live update" panel at the top of the job.
class _StatusPanel extends StatelessWidget {
  const _StatusPanel({required this.job, required this.forTechnician});

  final Job job;
  final bool forTechnician;

  @override
  Widget build(BuildContext context) {
    final status = JobStatusInfo.of(job.status);
    final isFinished = job.status == 'completed';
    final isCancelled = job.status == 'cancelled';
    final label =
        forTechnician ? status.technicianLabel : status.customerLabel;

    return DarkPanel(
      padding: const EdgeInsets.all(20),
      showGlow: !isCancelled,
      solidColor: isCancelled
          ? AppColors.foreground.withValues(alpha: 0.55)
          : isFinished
              ? AppColors.panelOnline
              : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isFinished || isCancelled
                            ? AppColors.onPanelKicker
                            : AppColors.peach,
                      ),
                    ),
                    const SizedBox(width: 7),
                    Text(
                      isCancelled
                          ? 'CANCELLED'
                          : isFinished
                              ? 'COMPLETED'
                              : 'LIVE UPDATE',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 8.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                formatShortDate(job.createdAt),
                style: const TextStyle(
                  color: AppColors.onPanelFaint,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 23,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            isCancelled
                ? 'This request is no longer active.'
                : isFinished
                    ? 'Thanks for using InnSelf.'
                    : 'We will keep this updated as things move along.',
            style: const TextStyle(
              color: AppColors.onPanelMuted,
              fontSize: 11.5,
              height: 1.5,
            ),
          ),
          if (!isCancelled) ...[
            const SizedBox(height: 18),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: status.progress / 100,
                minHeight: 5,
                backgroundColor: Colors.white.withValues(alpha: 0.16),
                valueColor: const AlwaysStoppedAnimation(AppColors.peach),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Four-milestone tracker, drawn once a job leaves the open state.
class _TimelineCard extends StatelessWidget {
  const _TimelineCard({required this.step});

  final int step;

  @override
  Widget build(BuildContext context) {
    final steps = JobStatusInfo.timeline;
    return AppCard(
      radius: 21,
      padding: const EdgeInsets.fromLTRB(17, 17, 17, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Job progress', style: AppText.cardTitleLarge),
          const SizedBox(height: 16),
          for (var i = 0; i < steps.length; i++)
            _TimelineRow(
              label: steps[i].label,
              icon: steps[i].icon,
              done: i <= step,
              current: i == step,
              isLast: i == steps.length - 1,
              railFilled: i < step,
            ),
        ],
      ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.label,
    required this.icon,
    required this.done,
    required this.current,
    required this.isLast,
    required this.railFilled,
  });

  final String label;
  final IconData icon;
  final bool done;
  final bool current;
  final bool isLast;
  final bool railFilled;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: done ? AppColors.accent : AppColors.background,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: done ? AppColors.accent : AppColors.border,
                  ),
                ),
                child: Icon(
                  icon,
                  size: 15,
                  color: done
                      ? AppColors.accentForeground
                      : AppColors.mutedForeground,
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: railFilled ? AppColors.accent : AppColors.border,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(top: 6, bottom: isLast ? 11 : 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: AppText.cardTitle.copyWith(
                      color: done
                          ? AppColors.foreground
                          : AppColors.mutedForeground,
                    ),
                  ),
                  if (current) ...[
                    const SizedBox(height: 3),
                    const Text(
                      'Current status',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (done)
            const Padding(
              padding: EdgeInsets.only(top: 7),
              child: Icon(
                Icons.check_circle,
                size: 17,
                color: AppColors.primary,
              ),
            ),
        ],
      ),
    );
  }
}

/// Category, location and posting time in one card.
class _JobFactsCard extends StatelessWidget {
  const _JobFactsCard({required this.job});

  final Job job;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      radius: 21,
      padding: const EdgeInsets.all(17),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(job.description, style: AppText.body.copyWith(fontSize: 13)),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 15),
            child: Divider(),
          ),
          _FactRow(
            icon: CategoryStyle.of(job.categoryName).icon,
            text: job.categoryName,
          ),
          const SizedBox(height: 11),
          _FactRow(icon: Icons.location_on_outlined, text: job.location),
          const SizedBox(height: 11),
          _FactRow(
            icon: Icons.event_outlined,
            text: job.scheduledFor == null
                ? 'As soon as possible'
                : 'Wants ${formatDateTime(job.scheduledFor!)}',
          ),
          const SizedBox(height: 11),
          _FactRow(
            icon: Icons.schedule_outlined,
            text: 'Posted ${formatDateTime(job.createdAt)}',
          ),
        ],
      ),
    );
  }
}

class _FactRow extends StatelessWidget {
  const _FactRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 17, color: AppColors.mutedForeground),
        const SizedBox(width: 11),
        Expanded(
          child: Text(text, style: AppText.body.copyWith(fontSize: 12.5)),
        ),
      ],
    );
  }
}

class _JobPhoto extends StatelessWidget {
  const _JobPhoto({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: kGutter),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(21),
        child: Image.network(
          url,
          height: 200,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
          loadingBuilder: (context, child, progress) => progress == null
              ? child
              : Container(
                  height: 200,
                  color: AppColors.muted,
                  alignment: Alignment.center,
                  child: const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
        ),
      ),
    );
  }
}

/// A titled white card holding form fields or read-only content.
class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.children,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeading(title: title, topPadding: 28),
        AppCard(
          radius: 21,
          padding: const EdgeInsets.all(17),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (subtitle != null) ...[
                Text(subtitle!, style: AppText.bodyMuted),
                const SizedBox(height: 14),
              ],
              ...children,
            ],
          ),
        ),
      ],
    );
  }
}

/// Coloured status card: an icon tile, a headline and a line of detail.
class _NoticeCard extends StatelessWidget {
  const _NoticeCard({
    required this.icon,
    required this.title,
    required this.message,
    this.background = AppColors.secondary,
    this.foreground = AppColors.accentForeground,
  });

  final IconData icon;
  final String title;
  final String message;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      radius: 21,
      padding: const EdgeInsets.all(17),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SoftIcon(
            icon,
            background: background,
            foreground: foreground,
            size: 42,
            iconSize: 21,
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppText.cardTitleLarge),
                const SizedBox(height: 4),
                Text(message, style: AppText.bodyMuted),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The other party's name, phone and a copy action, shown once a bid is
/// accepted. Both roles reuse this -- only the label and the profile
/// fetched differ.
class _ContactCard extends StatelessWidget {
  const _ContactCard({
    required this.label,
    required this.profile,
    this.rating,
    this.reviewCount = 0,
  });

  final String label;
  final Profile profile;
  final double? rating;
  final int reviewCount;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 13),
      child: AppCard(
        radius: 21,
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.secondary,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                initialsOf(profile.fullName),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.accentForeground,
                ),
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label.toUpperCase(), style: AppText.microLabel),
                  const SizedBox(height: 4),
                  Text(profile.fullName, style: AppText.cardTitleLarge),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Text(profile.phone, style: AppText.bodyMuted),
                      if (reviewCount > 0) ...[
                        Text('  ·  ', style: AppText.bodyMuted),
                        const Icon(Icons.star_rounded, size: 12, color: AppColors.star),
                        const SizedBox(width: 2),
                        Text(
                          rating!.toStringAsFixed(1),
                          style: AppText.bodyMuted.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            _ContactAction(
              icon: Icons.copy_rounded,
              onTap: () {
                Clipboard.setData(ClipboardData(text: profile.phone));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Phone number copied')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ContactAction extends StatelessWidget {
  const _ContactAction({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.secondary,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(icon, size: 18, color: AppColors.accentForeground),
        ),
      ),
    );
  }
}

/// One technician's offer on an open job.
class _BidCard extends StatelessWidget {
  const _BidCard({
    required this.bid,
    required this.isLowest,
    required this.isAccepting,
    required this.acceptDisabled,
    required this.onAccept,
  });

  final Bid bid;
  final bool isLowest;
  final bool isAccepting;
  final bool acceptDisabled;
  final VoidCallback onAccept;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: AppCard(
        radius: 21,
        padding: EdgeInsets.zero,
        borderColor: isLowest ? AppColors.primary : AppColors.border,
        borderWidth: isLowest ? 1.6 : 1,
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        width: 45,
                        height: 45,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isLowest
                              ? const Color(0xFFD9EEE6)
                              : const Color(0xFFECE6DE),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          initialsOf(bid.technicianName),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: isLowest
                                ? AppColors.success
                                : const Color(0xFF88644F),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              bid.technicianName.isEmpty
                                  ? 'Technician'
                                  : bid.technicianName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.cardTitleLarge,
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                if (bid.technicianReviewCount > 0) ...[
                                  const Icon(
                                    Icons.star_rounded,
                                    size: 13,
                                    color: AppColors.star,
                                  ),
                                  const SizedBox(width: 2),
                                  Text(
                                    '${bid.technicianRating!.toStringAsFixed(1)} '
                                    '(${bid.technicianReviewCount})',
                                    style: AppText.bodyMuted.copyWith(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.foreground,
                                    ),
                                  ),
                                  Text(
                                    '  ·  ',
                                    style: AppText.bodyMuted.copyWith(fontSize: 10.5),
                                  ),
                                ] else ...[
                                  Text(
                                    'New on InnSelf  ·  ',
                                    style: AppText.bodyMuted.copyWith(fontSize: 10.5),
                                  ),
                                ],
                                Text(
                                  'bid ${formatRelative(bid.createdAt)}',
                                  style: AppText.bodyMuted.copyWith(fontSize: 10.5),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Padding(
                    padding: EdgeInsets.only(top: 15, bottom: 13),
                    child: Divider(),
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('QUOTE', style: AppText.microLabel),
                          const SizedBox(height: 4),
                          Text(formatRupees(bid.amount), style: AppText.amount),
                        ],
                      ),
                      const Spacer(),
                      SizedBox(
                        height: 42,
                        child: FilledButton(
                          onPressed: acceptDisabled ? null : onAccept,
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: AppColors.primaryForeground,
                            padding:
                                const EdgeInsets.symmetric(horizontal: 20),
                            textStyle: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: isAccepting
                              ? const SizedBox(
                                  height: 16,
                                  width: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('Choose'),
                        ),
                      ),
                    ],
                  ),
                  if (bid.note != null && bid.note!.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Text(
                      '"${bid.note!}"',
                      style: AppText.bodyMuted.copyWith(
                        fontStyle: FontStyle.italic,
                        height: 1.5,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (isLowest)
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.only(
                      topRight: Radius.circular(20),
                      bottomLeft: Radius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'LOWEST BID',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.7,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
