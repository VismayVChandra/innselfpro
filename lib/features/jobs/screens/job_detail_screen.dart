import 'package:flutter/material.dart';

import '../../../models/bid.dart';
import '../../../models/job.dart';
import '../../../models/profile.dart';
import '../../bids/bids_repository.dart';
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
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();

  late Job _job;
  Future<List<Bid>>? _bidsFuture;
  Future<Bid?>? _myBidFuture;
  bool _isSubmittingBid = false;
  String? _acceptingBidId;
  bool _isUpdatingStatus = false;

  bool get _isOwningCustomer =>
      widget.viewerProfile.isCustomer && widget.viewerProfile.id == _job.customerId;
  bool get _isTechnician => widget.viewerProfile.isTechnician;

  @override
  void initState() {
    super.initState();
    _job = widget.initialJob;
    if (_isOwningCustomer) {
      _bidsFuture = _bidsRepository.fetchBidsForJob(_job.id);
    } else if (_isTechnician) {
      _myBidFuture = _bidsRepository.fetchMyBidForJob(_job.id);
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
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

        if (_job.status == 'bid_accepted') {
          return FilledButton(
            onPressed: _isUpdatingStatus ? null : _startJob,
            child: _isUpdatingStatus
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Start job'),
          );
        }
        if (_job.status == 'in_progress') {
          return FilledButton(
            onPressed: _isUpdatingStatus ? null : _completeJob,
            child: _isUpdatingStatus
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Mark completed'),
          );
        }
        if (_job.status == 'completed') {
          return const Text('You completed this job.');
        }
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildCustomerSection() {
    if (_job.status != 'open') {
      if (_job.status == 'bid_accepted') {
        return const Text('A technician has been assigned and will begin work soon.');
      }
      if (_job.status == 'in_progress') {
        return const Text('Your technician is currently working on this job.');
      }
      if (_job.status == 'completed') {
        return const Text('This job is complete.');
      }
      return const SizedBox.shrink();
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
}
