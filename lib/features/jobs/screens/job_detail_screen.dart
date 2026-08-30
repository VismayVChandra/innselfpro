import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/format.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/layout.dart';
import '../../../core/widgets/photo_picker.dart';
import '../../../core/widgets/states.dart';
import '../../../core/widgets/surfaces.dart';
import '../../../models/bid.dart';
import '../../../models/category.dart';
import '../../../models/dispute.dart';
import '../../../models/job.dart';
import '../../../models/payment.dart';
import '../../../models/profile.dart';
import '../../../models/review.dart';
import '../../bids/bids_repository.dart';
import '../../disputes/disputes_repository.dart';
import '../../messages/screens/chat_screen.dart';
import '../../notifications/notifications_repository.dart';
import '../../payments/payment_service.dart';
import '../../payments/payments_repository.dart';
import '../../profile/profile_repository.dart';
import '../../profile/widgets/profile_widgets.dart';
import '../../safety/safety_repository.dart';
import '../widgets/price_guidance_hint.dart';
import 'post_job_screen.dart';
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
  final _notificationsRepository = NotificationsRepository();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  final _reviewCommentController = TextEditingController();
  final _customerReviewCommentController = TextEditingController();
  final _completionCodeController = TextEditingController();

  late Job _job;
  Stream<List<Bid>>? _bidsStream;
  Future<Bid?>? _myBidFuture;
  Future<Payment?>? _paymentFuture;
  Future<Review?>? _reviewFuture;
  Future<Review?>? _customerReviewFuture;

  /// The customer's rating from other technicians, shown to a
  /// technician before they've even bid -- separate from _contactFuture
  /// (name/phone), which stays hidden until a bid is accepted.
  Future<({double average, int count})?>? _customerRatingFuture;

  /// Typical accepted-bid price for this job's category, shown to a
  /// technician while they're quoting.
  Future<({double average, double min, double max, int count})?>? _priceGuidanceFuture;
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

  /// Whether the other party has sent a chat message this viewer hasn't
  /// opened the thread for yet -- drives the unread dot on the message
  /// action in _ContactCard.
  Future<bool>? _chatUnreadFuture;

  /// Memoized per technician id so a rebuild of the "Book again" section
  /// doesn't re-issue the availability RPC on every setState elsewhere
  /// in this screen.
  final Map<String, Future<bool>> _availabilityCache = {};

  Future<bool> _availabilityFor(String technicianId) => _availabilityCache
      .putIfAbsent(technicianId, () => _profileRepository.fetchTechnicianAvailability(technicianId));

  bool _isSubmittingBid = false;
  String? _acceptingBidId;
  bool _isUpdatingStatus = false;
  bool _isStartingEnRoute = false;
  DateTime? _selectedEta;
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
  bool _isBoosting = false;
  bool _isBoostingJob = false;
  bool _isRescheduling = false;
  File? _completionPhoto;

  /// Why an assigned job was called off, shown to whichever party
  /// didn't do the cancelling (wave 7.2). Only loaded once the job is
  /// actually cancelled.
  Future<({String reason, String cancelledBy})?>? _cancellationFuture;

  bool get _isOwningCustomer =>
      widget.viewerProfile.isCustomer && widget.viewerProfile.id == _job.customerId;
  bool get _isTechnician => widget.viewerProfile.isTechnician;

  @override
  void initState() {
    super.initState();
    _job = widget.initialJob;
    if (_isOwningCustomer) {
      _bidsStream = _bidsRepository.streamBidsForJob(_job.id);
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
        _chatUnreadFuture =
            _notificationsRepository.hasUnread(jobId: _job.id, type: 'new_message');
      }
    } else if (_isTechnician) {
      _myBidFuture = _bidsRepository.fetchMyBidForJob(_job.id);
      if (_job.status != 'open') {
        _disputeFuture = _disputesRepository.fetchDisputeForJob(_job.id);
      }
      // Shown before a bid is even placed, so a technician can judge
      // whether this customer is worth bidding on -- reviews are
      // already authenticated-readable (reviews_select_all), so this
      // needs no new RLS.
      _customerRatingFuture = _reviewsRepository.fetchCustomerRating(_job.customerId);
      if (_job.status == 'open') {
        _priceGuidanceFuture = _jobsRepository.fetchPriceGuidance(_job.categoryId);
      }
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    _reviewCommentController.dispose();
    _customerReviewCommentController.dispose();
    _completionCodeController.dispose();
    _paymentService.dispose();
    super.dispose();
  }

  Future<void> _refreshJob() async {
    final updated = await _jobsRepository.fetchJobById(_job.id);
    if (!mounted) return;
    setState(() {
      _job = updated;
      if (updated.status == 'cancelled') {
        _cancellationFuture = _jobsRepository.fetchCancellation(updated.id);
      }
    });
  }

  /// Spends 50 reward points to pin this open job to the top of nearby
  /// technicians' feeds (migration 019). Same trust-the-server pattern
  /// as _boostBid -- balance and status are checked in boost_job itself.
  Future<void> _boostJob() async {
    setState(() => _isBoostingJob = true);
    try {
      await _jobsRepository.boostJob(_job.id);
      await _refreshJob();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Job boosted -- more technicians will see it first')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not boost job: $e')),
      );
    } finally {
      if (mounted) setState(() => _isBoostingJob = false);
    }
  }

  /// "Can't make it" -- available to either party while a job is
  /// assigned but not yet started. Requires a reason, which the other
  /// party sees, so an ordinary change of plan doesn't have to become a
  /// dispute.
  Future<void> _cancelAssignedJob() async {
    const reasons = [
      "Something came up, I can't make it",
      'Schedule clash',
      'Not needed any more',
      'Could not agree on the details',
    ];
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text("Can't make it?"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'The other person is told right away, along with your reason.',
              style: AppText.bodyMuted,
            ),
            const SizedBox(height: 12),
            for (final r in reasons)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: OutlinedButton(
                  onPressed: () => Navigator.of(dialogContext).pop(r),
                  child: Text(r, textAlign: TextAlign.center),
                ),
              ),
            const SizedBox(height: 4),
            TextField(
              controller: controller,
              decoration: const InputDecoration(hintText: 'Or type your own reason'),
              onSubmitted: (v) => Navigator.of(dialogContext).pop(v.trim()),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Never mind'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.destructive),
            onPressed: () => Navigator.of(dialogContext).pop(controller.text.trim()),
            child: const Text('Cancel job'),
          ),
        ],
      ),
    );
    if (reason == null || reason.isEmpty) return;
    setState(() => _isCancelling = true);
    try {
      await _jobsRepository.cancelJobWithReason(jobId: _job.id, reason: reason);
      await _refreshJob();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not cancel: $e')),
      );
    } finally {
      if (mounted) setState(() => _isCancelling = false);
    }
  }

  Future<void> _rescheduleJob() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _job.scheduledFor ?? now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 60)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_job.scheduledFor ?? now),
    );
    if (time == null) return;
    setState(() => _isRescheduling = true);
    try {
      await _jobsRepository.rescheduleJob(
        jobId: _job.id,
        scheduledFor:
            DateTime(date.year, date.month, date.day, time.hour, time.minute),
      );
      await _refreshJob();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not reschedule: $e')),
      );
    } finally {
      if (mounted) setState(() => _isRescheduling = false);
    }
  }

  /// The two "ordinary life happened" actions, shown to both sides
  /// while a job is assigned but hasn't started.
  Widget _buildPlanChangeActions() {
    if (_job.status != 'bid_accepted' && _job.status != 'en_route') {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 10),
        OutlineButton(
          label: 'Reschedule',
          icon: Icons.event_repeat_outlined,
          isLoading: _isRescheduling,
          onPressed: _rescheduleJob,
        ),
        const SizedBox(height: 10),
        OutlineButton(
          label: "Can't make it",
          icon: Icons.event_busy_outlined,
          color: AppColors.destructive,
          isLoading: _isCancelling,
          onPressed: _cancelAssignedJob,
        ),
      ],
    );
  }

  /// Replaces the generic "you cancelled this" copy once a reason was
  /// recorded, so the party who didn't cancel learns why.
  Widget _buildCancellationNotice() {
    if (_job.status != 'cancelled') return const SizedBox.shrink();
    _cancellationFuture ??= _jobsRepository.fetchCancellation(_job.id);
    return FutureBuilder<({String reason, String cancelledBy})?>(
      future: _cancellationFuture,
      builder: (context, snapshot) {
        final cancellation = snapshot.data;
        if (cancellation == null) return const SizedBox.shrink();
        final byMe = cancellation.cancelledBy == widget.viewerProfile.id;
        return Padding(
          padding: const EdgeInsets.only(top: 13),
          child: _NoticeCard(
            icon: Icons.event_busy_outlined,
            background: AppColors.muted,
            foreground: AppColors.mutedForeground,
            title: byMe ? 'You cancelled this job' : 'This job was cancelled',
            message: '"${cancellation.reason}"',
          ),
        );
      },
    );
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

  /// Spends 50 reward points to pin this pending bid to the top of the
  /// customer's list (migration 019). The RPC itself checks the balance
  /// and bid status server-side -- errors (not enough points, bid no
  /// longer pending) surface via the same snackbar path as any other
  /// repository call here, nothing pre-validated client-side.
  Future<void> _boostBid(String bidId) async {
    setState(() => _isBoosting = true);
    try {
      await _bidsRepository.boostBid(bidId);
      if (!mounted) return;
      setState(() {
        _myBidFuture = _bidsRepository.fetchMyBidForJob(_job.id);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bid boosted -- it now shows first to the customer')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not boost bid: $e')),
      );
    } finally {
      if (mounted) setState(() => _isBoosting = false);
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

  Future<void> _pickEta() async {
    final now = TimeOfDay.now();
    final picked = await showTimePicker(context: context, initialTime: now);
    if (picked == null) return;
    final today = DateTime.now();
    var eta = DateTime(today.year, today.month, today.day, picked.hour, picked.minute);
    if (eta.isBefore(today)) eta = eta.add(const Duration(days: 1));
    setState(() => _selectedEta = eta);
  }

  Future<void> _startEnRoute() async {
    setState(() => _isStartingEnRoute = true);
    try {
      await _jobsRepository.startEnRoute(_job.id, etaAt: _selectedEta);
      await _refreshJob();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update status: $e')),
      );
    } finally {
      if (mounted) setState(() => _isStartingEnRoute = false);
    }
  }

  Future<void> _openChat() async {
    await _notificationsRepository.markJobNotificationsRead(
      jobId: _job.id,
      type: 'new_message',
    );
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatScreen(jobId: _job.id, viewerId: widget.viewerProfile.id),
      ),
    );
    if (!mounted) return;
    setState(() {
      _chatUnreadFuture = Future.value(false);
    });
  }

  Future<void> _completeJob() async {
    final code = _completionCodeController.text.trim();
    if (code.length != 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter the 4-digit code the customer gave you')),
      );
      return;
    }
    setState(() => _isUpdatingStatus = true);
    try {
      await _jobsRepository.completeJob(
        _job.id,
        completionCode: code,
        completionPhoto: _completionPhoto,
      );
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
      // No manual bids refetch needed -- _bidsStream already reflects
      // the accept/reject updates live once they commit.
      setState(() {
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
              if (_job.photoUrls.isNotEmpty) ...[
                const SizedBox(height: 13),
                _JobPhotos(urls: _job.photoUrls),
              ],
              if (_job.completionPhotoUrl != null) ...[
                const SectionHeading(title: 'Completion photo', topPadding: 20),
                _JobPhoto(url: _job.completionPhotoUrl!),
              ],
              if (_isTechnician && _job.status == 'open')
                FutureBuilder<({double average, int count})?>(
                  future: _customerRatingFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const SizedBox.shrink();
                    }
                    return _CustomerRatingPreview(rating: snapshot.data);
                  },
                ),
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
                                'You quoted ${formatRupees(myBid.amount)}  ·  ${humanizeStatus(myBid.status)}'
                                '${myBid.isBoosted ? '  ·  Boosted' : ''}',
                                style: AppText.bodyMuted,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 13),
                  if (!myBid.isBoosted) ...[
                    OutlineButton(
                      label: 'Boost bid (50 pts)',
                      icon: Icons.trending_up_rounded,
                      isLoading: _isBoosting,
                      onPressed: () => _boostBid(myBid.id),
                    ),
                    const SizedBox(height: 10),
                  ],
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
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_priceGuidanceFuture != null) ...[
                const SizedBox(height: 13),
                PriceGuidanceHint(future: _priceGuidanceFuture!),
              ],
              _SectionCard(
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
        _chatUnreadFuture ??=
            _notificationsRepository.hasUnread(jobId: _job.id, type: 'new_message');
        if (_job.status == 'completed') {
          _customerReviewFuture ??=
              _reviewsRepository.fetchReviewForJob(_job.id, reviewerRole: 'technician');
        }

        Widget? action;
        Widget? photoPicker;
        Widget? codeField;
        Widget? etaPicker;
        Widget? enRouteNotice;
        if (_job.status == 'bid_accepted') {
          etaPicker = Padding(
            padding: const EdgeInsets.only(top: 13),
            child: OutlineButton(
              label: _selectedEta == null
                  ? 'Give an arrival time (optional)'
                  : 'Arriving around ${formatDateTime(_selectedEta!).split('  ·  ').last}',
              icon: Icons.schedule_outlined,
              onPressed: _pickEta,
            ),
          );
          action = PrimaryButton(
            label: "I'm on my way",
            icon: Icons.directions_car_filled_outlined,
            isLoading: _isStartingEnRoute,
            onPressed: _startEnRoute,
          );
        } else if (_job.status == 'en_route') {
          enRouteNotice = Padding(
            padding: const EdgeInsets.only(top: 13),
            child: _NoticeCard(
              icon: Icons.directions_car_filled_outlined,
              background: AppColors.warnSurface,
              foreground: AppColors.warn,
              title: "You're on the way",
              message: _job.etaAt == null
                  ? 'Let the customer know when you arrive.'
                  : 'You told the customer around ${formatDateTime(_job.etaAt!).split('  ·  ').last}.',
            ),
          );
          action = PrimaryButton(
            label: 'Start this job',
            isLoading: _isUpdatingStatus,
            onPressed: _startJob,
          );
        } else if (_job.status == 'in_progress') {
          codeField = _SectionCard(
            title: 'Completion code',
            subtitle: 'Ask the customer for the 4-digit code shown on their screen.',
            children: [
              TextField(
                controller: _completionCodeController,
                keyboardType: TextInputType.number,
                maxLength: 4,
                textAlign: TextAlign.center,
                style: AppText.body.copyWith(fontSize: 20, letterSpacing: 8),
                decoration: const InputDecoration(counterText: ''),
              ),
            ],
          );
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
                return FutureBuilder<bool>(
                  future: _chatUnreadFuture,
                  builder: (context, unreadSnapshot) => _ContactCard(
                    label: 'Your customer',
                    profile: contact.profile,
                    jobId: _job.id,
                    rating: contact.rating,
                    reviewCount: contact.reviewCount,
                    onMessage: _openChat,
                    hasUnreadMessage: unreadSnapshot.data ?? false,
                  ),
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
            ?enRouteNotice,
            ?codeField,
            if (photoPicker != null) ...[const SizedBox(height: 16), photoPicker],
            ?etaPicker,
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
            _buildPlanChangeActions(),
            _buildCancellationNotice(),
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
      } else if (_job.status == 'en_route') {
        notice = _NoticeCard(
          icon: Icons.directions_car_filled_outlined,
          background: AppColors.warnSurface,
          foreground: AppColors.warn,
          title: 'Your technician is on the way',
          message: _job.etaAt == null
              ? "They're heading to you now."
              : 'Arriving around ${formatDateTime(_job.etaAt!).split('  ·  ').last}.',
        );
      } else if (_job.status == 'in_progress') {
        notice = _NoticeCard(
          icon: Icons.handyman_outlined,
          background: const Color(0x1FF0644F),
          foreground: AppColors.primary,
          title: 'Work in progress',
          message: 'Your technician is on the job right now.',
        );
      } else if (_job.status == 'cancelled' && _job.acceptedBidId == null) {
        // Cancelled before anyone was assigned. Once a technician is
        // involved, _buildCancellationNotice takes over -- it carries
        // the recorded reason and says which side called it off.
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
                return FutureBuilder<bool>(
                  future: _chatUnreadFuture,
                  builder: (context, unreadSnapshot) => _ContactCard(
                    label: 'Your technician',
                    profile: contact.profile,
                    jobId: _job.id,
                    rating: contact.rating,
                    reviewCount: contact.reviewCount,
                    onMessage: _openChat,
                    hasUnreadMessage: unreadSnapshot.data ?? false,
                  ),
                );
              },
            ),
          if (_job.completionCode != null &&
              (_job.status == 'bid_accepted' ||
                  _job.status == 'en_route' ||
                  _job.status == 'in_progress'))
            _CompletionCodeCard(code: _job.completionCode!),
          if (notice != null) Padding(padding: const EdgeInsets.only(top: 13), child: notice),
          _buildCancellationNotice(),
          _buildPlanChangeActions(),
          if (_job.status == 'completed') ...[
            _buildPaymentSection(),
            _buildReviewSection(),
            FutureBuilder<({Profile profile, double? rating, int reviewCount})?>(
              future: _contactFuture,
              builder: (context, contactSnapshot) {
                final contact = contactSnapshot.data;
                if (contact == null) return const SizedBox.shrink();
                return FutureBuilder<bool>(
                  future: _availabilityFor(contact.profile.id),
                  builder: (context, availabilitySnapshot) {
                    // Defaults to available while the check is in
                    // flight rather than flashing a disabled button.
                    final isAvailable = availabilitySnapshot.data ?? true;
                    return Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: OutlineButton(
                        label: isAvailable
                            ? 'Book ${contact.profile.fullName} again'
                            : '${contact.profile.fullName} is unavailable right now',
                        icon: Icons.replay_rounded,
                        onPressed: !isAvailable
                            ? null
                            : () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => PostJobScreen(
                                      initialCategory: Category(
                                          id: _job.categoryId, name: _job.categoryName),
                                      invitedTechnicianId: contact.profile.id,
                                      invitedTechnicianName: contact.profile.fullName,
                                    ),
                                  ),
                                ),
                      ),
                    );
                  },
                );
              },
            ),
          ],
          if (_job.status != 'cancelled') _buildDisputeSection(),
        ],
      );
    }

    return StreamBuilder<List<Bid>>(
      stream: _bidsStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return ErrorView(message: 'Could not load bids: ${snapshot.error}');
        }
        if (!snapshot.hasData) {
          return const LoadingView(height: 160);
        }
        final bids = snapshot.data!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!_job.isBoosted)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: OutlineButton(
                  label: 'Boost this job (50 pts)',
                  icon: Icons.trending_up_rounded,
                  isLoading: _isBoostingJob,
                  onPressed: _boostJob,
                ),
              ),
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

/// Opens turn-by-turn directions to the job in Google Maps (or whichever
/// maps app the user has set as default) -- prefers the job's real
/// lat/lng (migration 014) for an exact pin, falling back to the typed
/// address text for older jobs posted before that column existed.
Future<void> _openInMaps(BuildContext context, Job job) async {
  final destination = job.hasLocation
      ? '${job.lat},${job.lng}'
      : Uri.encodeComponent(job.location);
  final uri = Uri.parse(
    'https://www.google.com/maps/dir/?api=1&destination=$destination',
  );
  bool launched;
  try {
    launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    launched = false;
  }
  if (!launched && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Could not open Maps')),
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
          _FactRow(
            icon: Icons.location_on_outlined,
            text: job.location,
            onTap: () => _openInMaps(context, job),
            trailing: Icons.directions_outlined,
          ),
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
          if (job.invitedTechnicianId != null) ...[
            const SizedBox(height: 11),
            const _FactRow(
              icon: Icons.person_pin_circle_outlined,
              text: 'Direct request -- only visible to one technician',
            ),
          ],
        ],
      ),
    );
  }
}

class _FactRow extends StatelessWidget {
  const _FactRow({required this.icon, required this.text, this.onTap, this.trailing});

  final IconData icon;
  final String text;

  /// Non-null makes the whole row tappable -- used for the address row
  /// to open turn-by-turn directions; every other fact is inert.
  final VoidCallback? onTap;
  final IconData? trailing;

  @override
  Widget build(BuildContext context) {
    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 17, color: AppColors.mutedForeground),
        const SizedBox(width: 11),
        Expanded(
          child: Text(
            text,
            style: AppText.body.copyWith(
              fontSize: 12.5,
              color: onTap != null ? AppColors.primary : null,
              decoration: onTap != null ? TextDecoration.underline : null,
              decorationColor: onTap != null ? AppColors.primary : null,
            ),
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 8),
          Icon(trailing, size: 16, color: AppColors.primary),
        ],
      ],
    );
    if (onTap == null) return row;
    return InkWell(onTap: onTap, borderRadius: BorderRadius.circular(8), child: row);
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

/// The customer's original job photos -- a single big preview for the
/// common one-photo case, a horizontally scrolling row when there are
/// several.
class _JobPhotos extends StatelessWidget {
  const _JobPhotos({required this.urls});

  final List<String> urls;

  @override
  Widget build(BuildContext context) {
    if (urls.length == 1) return _JobPhoto(url: urls.first);
    return SizedBox(
      height: 140,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: kGutter),
        itemCount: urls.length,
        separatorBuilder: (context, index) => const SizedBox(width: 10),
        itemBuilder: (context, index) => ClipRRect(
          borderRadius: BorderRadius.circular(17),
          child: Image.network(
            urls[index],
            width: 140,
            height: 140,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
            loadingBuilder: (context, child, progress) => progress == null
                ? child
                : Container(
                    width: 140,
                    height: 140,
                    color: AppColors.muted,
                    alignment: Alignment.center,
                    child: const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
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

/// The 4-digit code the customer reads out to their technician to close
/// out the job -- deliberately loud (large, high-contrast digits) since
/// missing it is the only way a job gets stuck at "in progress".
class _CompletionCodeCard extends StatelessWidget {
  const _CompletionCodeCard({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 13),
      child: DarkPanel(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'GIVE THIS CODE TO YOUR TECHNICIAN WHEN THE WORK IS DONE',
              style: TextStyle(
                color: AppColors.onPanelFaint,
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              code,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 34,
                fontWeight: FontWeight.w800,
                letterSpacing: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The other party's name, phone and a copy action, shown once a bid is
/// accepted. Both roles reuse this -- only the label and the profile
/// fetched differ.
/// A customer's rating from other technicians, shown on an open job so
/// a technician can judge whether it's worth bidding on -- before any
/// bid exists, well before the full contact card (name/phone) would
/// ever be shown.
class _CustomerRatingPreview extends StatelessWidget {
  const _CustomerRatingPreview({required this.rating});

  final ({double average, int count})? rating;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 13),
      child: AppCard(
        radius: 19,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            const SoftIcon(Icons.person_outline_rounded, size: 40, iconSize: 19),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('ABOUT THIS CUSTOMER', style: AppText.microLabel),
                  const SizedBox(height: 4),
                  if (rating == null)
                    Text('New on InnSelf -- no ratings yet', style: AppText.bodyMuted)
                  else
                    Row(
                      children: [
                        const Icon(Icons.star_rounded, size: 14, color: AppColors.star),
                        const SizedBox(width: 4),
                        Text(
                          '${rating!.average.toStringAsFixed(1)} from ${rating!.count} '
                          'technician${rating!.count == 1 ? '' : 's'}',
                          style: AppText.cardTitle,
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContactCard extends StatelessWidget {
  const _ContactCard({
    required this.label,
    required this.profile,
    required this.jobId,
    this.rating,
    this.reviewCount = 0,
    this.onMessage,
    this.hasUnreadMessage = false,
  });

  final String label;
  final Profile profile;
  final String jobId;
  final double? rating;
  final int reviewCount;

  /// Null hides the message action entirely -- used before a bid is
  /// accepted, when there's no chat to open yet.
  final VoidCallback? onMessage;
  final bool hasUnreadMessage;

  Future<void> _launchOrWarn(BuildContext context, Uri uri, String failureMessage) async {
    bool launched;
    try {
      launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      launched = false;
    }
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(failureMessage)));
    }
  }

  Future<void> _showSafetyMenu(BuildContext context) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.flag_outlined, color: AppColors.destructive),
              title: const Text('Report'),
              onTap: () => Navigator.of(sheetContext).pop('report'),
            ),
            ListTile(
              leading: const Icon(Icons.block_outlined, color: AppColors.destructive),
              title: Text('Block ${profile.fullName}'),
              onTap: () => Navigator.of(sheetContext).pop('block'),
            ),
          ],
        ),
      ),
    );
    if (action == null || !context.mounted) return;
    if (action == 'report') {
      await _reportFlow(context);
    } else {
      await _blockFlow(context);
    }
  }

  Future<void> _reportFlow(BuildContext context) async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Report ${profile.fullName}?'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
          decoration: const InputDecoration(hintText: 'What happened?'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.destructive),
            onPressed: () => Navigator.of(dialogContext).pop(controller.text.trim()),
            child: const Text('Report'),
          ),
        ],
      ),
    );
    if (reason == null || reason.isEmpty || !context.mounted) return;
    try {
      await SafetyRepository().reportUser(reportedId: profile.id, reason: reason, jobId: jobId);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Report submitted')));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Could not submit report: $e')));
    }
  }

  Future<void> _blockFlow(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Block ${profile.fullName}?'),
        content: const Text(
          'They will no longer be able to message you. You can unblock them later from your profile.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.destructive),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Block'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await SafetyRepository().blockUser(profile.id);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('${profile.fullName} blocked')));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Could not block: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final normalisedPhone = normalisePhone(profile.phone);

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
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          profile.fullName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.cardTitleLarge,
                        ),
                      ),
                      if (profile.isVerified) ...[
                        const SizedBox(width: 5),
                        const VerifiedBadge(size: 15),
                      ],
                    ],
                  ),
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
            if (normalisedPhone != null) ...[
              _ContactAction(
                icon: Icons.call_rounded,
                onTap: () => _launchOrWarn(
                  context,
                  Uri(scheme: 'tel', path: normalisedPhone),
                  'Could not open the dialer',
                ),
              ),
              const SizedBox(width: 8),
              _ContactAction(
                icon: Icons.chat_rounded,
                onTap: () => _launchOrWarn(
                  context,
                  Uri.parse('https://wa.me/${normalisedPhone.substring(1)}'),
                  'Could not open WhatsApp',
                ),
              ),
              const SizedBox(width: 8),
            ],
            if (onMessage != null) ...[
              _ContactAction(
                icon: Icons.forum_outlined,
                onTap: onMessage!,
                showDot: hasUnreadMessage,
              ),
              const SizedBox(width: 8),
            ],
            _ContactAction(
              icon: Icons.copy_rounded,
              onTap: () {
                Clipboard.setData(ClipboardData(text: profile.phone));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Phone number copied')),
                );
              },
            ),
            const SizedBox(width: 8),
            _ContactAction(
              icon: Icons.more_vert_rounded,
              onTap: () => _showSafetyMenu(context),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContactAction extends StatelessWidget {
  const _ContactAction({required this.icon, required this.onTap, this.showDot = false});

  final IconData icon;
  final VoidCallback onTap;
  final bool showDot;

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
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(icon, size: 18, color: AppColors.accentForeground),
              if (showDot)
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primary,
                      border: Border.all(color: AppColors.secondary),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Small marker on a boosted bid/job (migration 019's points-spend
/// visibility perk) -- reuses the brand accent since it's a promotional
/// signal, not a status like VerifiedBadge.
class _BoostedChip extends StatelessWidget {
  const _BoostedChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.trending_up_rounded, size: 10, color: AppColors.primary),
          const SizedBox(width: 2),
          Text(
            'BOOSTED',
            style: TextStyle(
              fontSize: 8.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
              color: AppColors.primary,
            ),
          ),
        ],
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
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    bid.technicianName.isEmpty
                                        ? 'Technician'
                                        : bid.technicianName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppText.cardTitleLarge,
                                  ),
                                ),
                                if (bid.technicianIsVerified) ...[
                                  const SizedBox(width: 5),
                                  const VerifiedBadge(size: 14),
                                ],
                                if (bid.isBoosted) ...[
                                  const SizedBox(width: 5),
                                  const _BoostedChip(),
                                ],
                              ],
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
