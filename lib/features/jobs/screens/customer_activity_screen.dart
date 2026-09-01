import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/layout.dart';
import '../../../core/widgets/states.dart';
import '../../../core/widgets/surfaces.dart';
import '../../../models/category.dart';
import '../../../models/job.dart';
import '../../../models/profile.dart';
import '../../notifications/notification_bell.dart';
import '../../shell/refresh_signal.dart';
import '../jobs_repository.dart';
import '../widgets/job_cards.dart';
import 'job_detail_screen.dart';
import 'post_job_screen.dart';

/// Every request this customer has ever posted, newest first.
class CustomerActivityScreen extends StatefulWidget {
  const CustomerActivityScreen({super.key, required this.profile});

  final Profile profile;

  @override
  State<CustomerActivityScreen> createState() => _CustomerActivityScreenState();
}

class _CustomerActivityScreenState extends State<CustomerActivityScreen>
    with RefreshAware {
  final _jobsRepository = JobsRepository();
  late Future<List<Job>> _future;

  @override
  void initState() {
    super.initState();
    _future = _jobsRepository.fetchMyJobs();
  }

  @override
  void onRefreshSignal() =>
      setState(() => _future = _jobsRepository.fetchMyJobs());

  Future<void> _refresh() async {
    setState(() => _future = _jobsRepository.fetchMyJobs());
    await _future;
  }

  Future<void> _openPostJob() async {
    final posted = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const PostJobScreen()),
    );
    if (posted == true && mounted) RefreshScope.of(context).bump();
  }

  /// Prefills a fresh request from an expired one -- the customer still
  /// submits a genuinely new job (with the same nudge to widen the area
  /// or adjust price that a first-time post gets via PriceGuidanceHint),
  /// not an update to the expired one.
  Future<void> _repost(Job job) async {
    final posted = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PostJobScreen(
          initialCategory: Category(id: job.categoryId, name: job.categoryName),
          initialDescription: job.description,
          initialLocation: job.location,
        ),
      ),
    );
    if (posted == true && mounted) RefreshScope.of(context).bump();
  }

  Future<void> _openJob(Job job) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => JobDetailScreen(
          initialJob: job,
          viewerProfile: widget.profile,
        ),
      ),
    );
    if (mounted) RefreshScope.of(context).bump();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: _refresh,
        color: AppColors.primary,
        backgroundColor: AppColors.card,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(top: 20, bottom: 32),
          child: FutureBuilder<List<Job>>(
            future: _future,
            builder: (context, snapshot) {
              final jobs = snapshot.data ?? const <Job>[];
              final expiredJobs = jobs.where((j) => j.status == 'expired').toList();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ScreenHeader(
                    eyebrow: 'YOUR INNSELF',
                    title: 'Activity',
                    action: NotificationBell(),
                  ),
                  _SummaryCard(count: jobs.length),
                  if (snapshot.hasError)
                    ErrorView(
                      message: 'Could not load your requests: ${snapshot.error}',
                      onRetry: _refresh,
                    )
                  else if (snapshot.connectionState != ConnectionState.done)
                    LoadingView()
                  else ...[
                    if (expiredJobs.isNotEmpty) ...[
                      SectionHeading(title: 'Expired -- no bids', topPadding: 30),
                      for (final job in expiredJobs)
                        _ExpiredJobCard(job: job, onRepost: () => _repost(job)),
                    ],
                    SectionHeading(title: 'All requests', topPadding: 30),
                    if (jobs.isEmpty)
                      EmptyView(
                        icon: Icons.inbox_outlined,
                        title: 'No requests yet',
                        message:
                            'Your posted jobs and their progress will show up here.',
                      )
                    else
                      for (final job in jobs)
                        JobListCard(job: job, onTap: () => _openJob(job)),
                    const SizedBox(height: 4),
                    OutlineButton(
                      label: 'Start a new request',
                      icon: Icons.add,
                      onPressed: _openPostJob,
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ExpiredJobCard extends StatelessWidget {
  const _ExpiredJobCard({required this.job, required this.onRepost});

  final Job job;
  final VoidCallback onRepost;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: kGutter, vertical: 5),
      child: AppCard(
        margin: EdgeInsets.zero,
        radius: 19,
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            SoftIcon(
              Icons.hourglass_disabled_outlined,
              background: AppColors.muted,
              foreground: AppColors.mutedForeground,
              size: 40,
              iconSize: 19,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(job.categoryName, style: AppText.cardTitle),
                  const SizedBox(height: 3),
                  Text(
                    'No one bid before this expired.',
                    style: AppText.bodyMuted.copyWith(fontSize: 10.5),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: onRepost,
              child: const Text('Repost'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: AppColors.accent,
      borderColor: AppColors.accent,
      radius: 21,
      padding: const EdgeInsets.all(19),
      child: Row(
        children: [
          Text(
            '$count',
            style: TextStyle(
              fontSize: 35,
              fontWeight: FontWeight.w700,
              color: AppColors.accentForeground,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  count == 1 ? 'request with InnSelf' : 'requests with InnSelf',
                  style: AppText.cardTitleLarge.copyWith(
                    color: AppColors.accentForeground,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Your home, looked after.',
                  style: AppText.bodyMuted.copyWith(
                    color: AppColors.accentForeground,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
