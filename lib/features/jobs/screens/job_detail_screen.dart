import 'package:flutter/material.dart';

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
import '../../reviews/reviews_repository.dart';
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
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  final _reviewCommentController = TextEditingController();

  late Job _job;
  Future<List<Bid>>? _bidsFuture;
  Future<Bid?>? _myBidFuture;
  Future<Payment?>? _paymentFuture;
  Future<Review?>? _reviewFuture;
  Future<Dispute?>? _disputeFuture;
  bool _isSubmittingBid = false;
  String? _acceptingBidId;
  bool _isUpdatingStatus = false;
  bool _isStartingPayment = false;
  bool _isConfirmingPayment = false;
  int _selectedRating = 0;
  bool _isSubmittingReview = false;
  bool _isFlagging = false;

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
        _reviewFuture = _reviewsRepository.fetchReviewForJob(_job.id);
      }
      if (_job.status != 'open') {
        _disputeFuture = _disputesRepository.fetchDisputeForJob(_job.id);
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
    _paymentService.dispose();
    super.dispose();
  }

  Future<void> _refreshJob() async {
    final updated = await _jobsRepository.fetchJobById(_job.id);
    if (!mounted) return;
    setState(() => _job = updated);
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
      await _jobsRepository.completeJob(_job.id);
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
        _reviewFuture = _reviewsRepository.fetchReviewForJob(_job.id);
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

  Future<void> _showFlagDialog() async {
    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Flag an issue'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'What went wrong?'),
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

  Future<void> _acceptBid(Bid bid) async {
    setState(() => _acceptingBidId = bid.id);
    try {
      await _bidsRepository.acceptBid(jobId: _job.id, bidId: bid.id);
      await _refreshJob();
      if (!mounted) return;
      setState(() {
        _bidsFuture = _bidsRepository.fetchBidsForJob(_job.id);
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
      appBar: AppBar(title: Text(_job.categoryName)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Chip(label: Text(_job.status.replaceAll('_', ' ').toUpperCase())),
            const SizedBox(height: 16),
            if (_job.photoUrl != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  _job.photoUrl!,
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                ),
              ),
              const SizedBox(height: 16),
            ],
            Text('Description', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(_job.description),
            const SizedBox(height: 16),
            Text('Location', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(_job.location),
            const SizedBox(height: 16),
            Text('Posted', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(_job.createdAt.toLocal().toString()),
            const SizedBox(height: 24),
            if (_isTechnician) _buildTechnicianSection(),
            if (_isOwningCustomer) _buildCustomerSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildTechnicianSection() {
    return FutureBuilder<Bid?>(
      future: _myBidFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final myBid = snapshot.data;

        if (_job.status == 'open') {
          if (myBid != null) {
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text('You bid ₹${myBid.amount.toStringAsFixed(0)} - ${myBid.status}'),
              ),
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Submit a bid', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              TextField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Your price (₹)'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _noteController,
                decoration: const InputDecoration(labelText: 'Note (optional)'),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _isSubmittingBid ? null : _submitBid,
                child: _isSubmittingBid
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Submit bid'),
              ),
            ],
          );
        }

        // Job is no longer open. Only the technician whose bid was
        // accepted has anything to do here.
        if (myBid == null || myBid.status != 'accepted') {
          return const SizedBox.shrink();
        }

        Widget statusWidget;
        if (_job.status == 'bid_accepted') {
          statusWidget = FilledButton(
            onPressed: _isUpdatingStatus ? null : _startJob,
            child: _isUpdatingStatus
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Start job'),
          );
        } else if (_job.status == 'in_progress') {
          statusWidget = FilledButton(
            onPressed: _isUpdatingStatus ? null : _completeJob,
            child: _isUpdatingStatus
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Mark completed'),
          );
        } else if (_job.status == 'completed') {
          statusWidget = const Text('You completed this job.');
        } else {
          statusWidget = const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            statusWidget,
            const SizedBox(height: 24),
            _buildDisputeSection(),
          ],
        );
      },
    );
  }

  Widget _buildCustomerSection() {
    if (_job.status != 'open') {
      Widget statusWidget;
      if (_job.status == 'bid_accepted') {
        statusWidget = const Text('A technician has been assigned and will begin work soon.');
      } else if (_job.status == 'in_progress') {
        statusWidget = const Text('Your technician is currently working on this job.');
      } else if (_job.status == 'completed') {
        statusWidget = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildPaymentSection(),
            const SizedBox(height: 24),
            _buildReviewSection(),
          ],
        );
      } else {
        statusWidget = const SizedBox.shrink();
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          statusWidget,
          const SizedBox(height: 24),
          _buildDisputeSection(),
        ],
      );
    }
    return FutureBuilder<List<Bid>>(
      future: _bidsFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Text('Could not load bids: ${snapshot.error}');
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final bids = snapshot.data!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Bids received', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (bids.isEmpty) const Text('No bids yet.'),
            ...bids.map(
              (bid) => Card(
                child: ListTile(
                  title: Text('${bid.technicianName} - ₹${bid.amount.toStringAsFixed(0)}'),
                  subtitle: bid.note != null && bid.note!.isNotEmpty ? Text(bid.note!) : null,
                  trailing: FilledButton(
                    onPressed: _acceptingBidId != null ? null : () => _acceptBid(bid),
                    child: _acceptingBidId == bid.id
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Accept'),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPaymentSection() {
    if (_isConfirmingPayment) {
      return const Row(
        children: [
          SizedBox(
            height: 16,
            width: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 12),
          Text('Confirming payment...'),
        ],
      );
    }
    return FutureBuilder<Payment?>(
      future: _paymentFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Text('Could not load payment status: ${snapshot.error}');
        }
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final payment = snapshot.data;
        if (payment?.status == 'paid') {
          return Text('Paid ₹${payment!.amount.toStringAsFixed(0)}.');
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('This job is complete. Pay to close it out.'),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _isStartingPayment ? null : _startPayment,
              child: _isStartingPayment
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Pay now'),
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
          return Text('Could not load review: ${snapshot.error}');
        }
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final review = snapshot.data;
        if (review != null) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Your review', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              _buildStarRow(rating: review.rating),
              if (review.comment != null && review.comment!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(review.comment!),
              ],
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Rate this technician', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            _buildStarRow(
              rating: _selectedRating,
              interactive: true,
              onChanged: (r) => setState(() => _selectedRating = r),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _reviewCommentController,
              decoration: const InputDecoration(labelText: 'Comment (optional)'),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: (_isSubmittingReview || _selectedRating == 0) ? null : _submitReview,
              child: _isSubmittingReview
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Submit review'),
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
          return Text('Could not load dispute status: ${snapshot.error}');
        }
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final dispute = snapshot.data;
        if (dispute != null) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Dispute flagged (${dispute.status})',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(dispute.reason),
                ],
              ),
            ),
          );
        }
        return Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: _isFlagging ? null : _showFlagDialog,
            icon: const Icon(Icons.flag_outlined),
            label: const Text('Flag an issue'),
          ),
        );
      },
    );
  }

  Widget _buildStarRow({
    required int rating,
    bool interactive = false,
    ValueChanged<int>? onChanged,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final icon = Icon(
          i < rating ? Icons.star : Icons.star_border,
          color: Colors.amber,
        );
        if (!interactive) return icon;
        return IconButton(
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          onPressed: () => onChanged?.call(i + 1),
          icon: icon,
        );
      }),
    );
  }
}
