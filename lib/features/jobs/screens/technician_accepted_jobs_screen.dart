import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/widgets/layout.dart';
import '../../../core/widgets/states.dart';
import '../../../core/widgets/surfaces.dart';
import '../../../models/job.dart';
import '../../../models/profile.dart';
import '../../notifications/notification_bell.dart';
import '../../shell/refresh_signal.dart';
import '../job_status.dart';
import '../jobs_repository.dart';
import '../widgets/job_cards.dart';
import 'job_detail_screen.dart';

/// Jobs this technician won the bid on. They drop out of the open feed
/// once accepted, so this tab is the only way back to them.
class TechnicianAcceptedJobsScreen extends StatefulWidget {
  const TechnicianAcceptedJobsScreen({super.key, required this.profile});

  final Profile profile;

  @override
  State<TechnicianAcceptedJobsScreen> createState() =>
      _TechnicianAcceptedJobsScreenState();
}

class _TechnicianAcceptedJobsScreenState
    extends State<TechnicianAcceptedJobsScreen> with RefreshAware {
  final _jobsRepository = JobsRepository();
  late Future<List<Job>> _future;

  @override
  void initState() {
    super.initState();
    _future = _jobsRepository.fetchMyAcceptedJobs();
  }

  @override
  void onRefreshSignal() =>
      setState(() => _future = _jobsRepository.fetchMyAcceptedJobs());

  Future<void> _refresh() async {
    setState(() => _future = _jobsRepository.fetchMyAcceptedJobs());
    await _future;
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
              final live =
                  jobs.where((j) => JobStatusInfo.isActive(j.status)).length;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ScreenHeader(
                    eyebrow: 'YOUR WORK',
                    title: 'My jobs',
                    action: NotificationBell(),
                  ),
                  if (snapshot.hasError)
                    ErrorView(
                      message: 'Could not load your jobs: ${snapshot.error}',
                      onRetry: _refresh,
                    )
                  else if (snapshot.connectionState != ConnectionState.done)
                    LoadingView()
                  else ...[
                    _WonSummary(total: jobs.length, live: live),
                    SectionHeading(title: 'All accepted jobs'),
                    if (jobs.isEmpty)
                      EmptyView(
                        icon: Icons.work_outline_rounded,
                        title: 'No jobs won yet',
                        message:
                            'Bid on an open request from the Feed tab. Once a customer accepts, it lands here.',
                      )
                    else
                      for (final job in jobs)
                        JobListCard(
                          job: job,
                          forTechnician: true,
                          onTap: () => _openJob(job),
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

class _WonSummary extends StatelessWidget {
  const _WonSummary({required this.total, required this.live});

  final int total;
  final int live;

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
            '$total',
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
                  total == 1 ? 'job won so far' : 'jobs won so far',
                  style: AppText.cardTitleLarge.copyWith(
                    color: AppColors.accentForeground,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  live == 0
                      ? 'Nothing needs your attention right now.'
                      : '$live still need${live == 1 ? 's' : ''} your attention.',
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
