import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/layout.dart';
import '../../../core/widgets/states.dart';
import '../../../core/widgets/surfaces.dart';
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
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const ScreenHeader(
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
                    const LoadingView()
                  else ...[
                    const SectionHeading(title: 'All requests', topPadding: 30),
                    if (jobs.isEmpty)
                      const EmptyView(
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
            style: const TextStyle(
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
