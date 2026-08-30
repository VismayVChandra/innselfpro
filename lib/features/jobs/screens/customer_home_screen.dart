import 'package:flutter/material.dart';

import '../../../core/format.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/widgets/layout.dart';
import '../../../core/widgets/states.dart';
import '../../../core/widgets/surfaces.dart';
import '../../../models/category.dart';
import '../../../models/job.dart';
import '../../../models/profile.dart';
import '../../bids/bids_repository.dart';
import '../../notifications/notification_bell.dart';
import '../../shell/refresh_signal.dart';
import '../job_status.dart';
import '../jobs_repository.dart';
import '../widgets/category_grid.dart';
import 'job_detail_screen.dart';
import 'post_job_screen.dart';

/// Everything the home tab renders, fetched together so the screen has
/// one loading state rather than four.
class _HomeData {
  const _HomeData({
    required this.jobs,
    required this.categories,
    required this.bidCounts,
  });

  final List<Job> jobs;
  final List<Category> categories;
  final Map<String, int> bidCounts;
}

class CustomerHomeScreen extends StatefulWidget {
  const CustomerHomeScreen({
    super.key,
    required this.profile,
    required this.onOpenTab,
  });

  final Profile profile;

  /// Switches the shell's bottom tab, for the "View history" links.
  final ValueChanged<int> onOpenTab;

  @override
  State<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen>
    with RefreshAware {
  final _jobsRepository = JobsRepository();
  final _bidsRepository = BidsRepository();
  late Future<_HomeData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void onRefreshSignal() => setState(() => _future = _load());

  Future<_HomeData> _load() async {
    final jobs = await _jobsRepository.fetchMyJobs();
    final categories = await _jobsRepository.fetchCategories();
    final openJobIds =
        jobs.where((j) => j.status == 'open').map((j) => j.id).toList();
    final bidCounts = await _bidsRepository.fetchBidCounts(openJobIds);
    return _HomeData(
      jobs: jobs,
      categories: categories,
      bidCounts: bidCounts,
    );
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
    await _future;
  }

  Future<void> _pickCategoryAndPost(Category tapped, List<Category> allCategories) async {
    final resolved = await resolveCategoryTap(context, tapped, allCategories);
    if (resolved != null && mounted) await _openPostJob(category: resolved);
  }

  Future<void> _openPostJob({Category? category}) async {
    final posted = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PostJobScreen(initialCategory: category),
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
    final firstName = widget.profile.fullName.split(' ').first;

    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: _refresh,
        color: AppColors.primary,
        backgroundColor: AppColors.card,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(top: 16, bottom: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ScreenHeader(
                eyebrow: formatHeaderDate(DateTime.now()),
                title: 'Hi, $firstName',
                action: const NotificationBell(),
              ),
              _Hero(onRequest: _openPostJob),
              FutureBuilder<_HomeData>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return ErrorView(
                      message: 'Could not load your home: ${snapshot.error}',
                      onRetry: _refresh,
                    );
                  }
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const LoadingView(height: 260);
                  }
                  return _HomeBody(
                    data: snapshot.data!,
                    onOpenTab: widget.onOpenTab,
                    onPickCategory: (c) => _pickCategoryAndPost(c, snapshot.data!.categories),
                    onOpenPostJob: _openPostJob,
                    onOpenJob: _openJob,
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

class _Hero extends StatelessWidget {
  const _Hero({required this.onRequest});

  final VoidCallback onRequest;

  @override
  Widget build(BuildContext context) {
    return DarkPanel(
      minHeight: 218,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'HOME, HANDLED.',
            style: TextStyle(
              color: AppColors.onPanelKicker,
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.6,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'What can we\nhelp with today?',
            style: TextStyle(
              color: Colors.white,
              fontSize: 27,
              height: 1.16,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.7,
            ),
          ),
          const SizedBox(height: 11),
          const SizedBox(
            width: 230,
            child: Text(
              'Get trusted local pros competing for your job.',
              style: TextStyle(
                color: AppColors.onPanelMuted,
                fontSize: 12.5,
                height: 1.45,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
          const SizedBox(height: 22),
          Material(
            color: AppColors.peach,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              onTap: onRequest,
              borderRadius: BorderRadius.circular(16),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Request a pro',
                      style: TextStyle(
                        color: AppColors.panelStart,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(width: 10),
                    Icon(Icons.north_east, size: 17, color: AppColors.panelStart),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeBody extends StatelessWidget {
  const _HomeBody({
    required this.data,
    required this.onOpenTab,
    required this.onPickCategory,
    required this.onOpenPostJob,
    required this.onOpenJob,
  });

  final _HomeData data;
  final ValueChanged<int> onOpenTab;
  final ValueChanged<Category> onPickCategory;
  final VoidCallback onOpenPostJob;
  final ValueChanged<Job> onOpenJob;

  @override
  Widget build(BuildContext context) {
    final activeJob =
        data.jobs.where((j) => JobStatusInfo.isActive(j.status)).firstOrNull;
    final openJob = data.jobs.where((j) => j.status == 'open').firstOrNull;
    final activeCount = data.jobs
        .where((j) => j.status != 'completed' && j.status != 'cancelled')
        .length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeading(
          title: 'Book a service',
          actionLabel: 'See all',
          onAction: onOpenPostJob,
        ),
        CategoryGrid(
          categories: data.categories.where((c) => c.isTopLevel).toList(),
          limit: 6,
          onTap: onPickCategory,
        ),
        const SizedBox(height: 25),
        if (activeJob != null)
          _ActiveJobCard(job: activeJob, onTap: () => onOpenJob(activeJob))
        else
          EmptyStateCard(
            icon: Icons.home_outlined,
            title: 'Your home is ready for care',
            message: 'Start a request and let local pros come to you.',
            onTap: onOpenPostJob,
          ),
        if (openJob != null) ...[
          const SizedBox(height: 13),
          _BidsBanner(
            bidCount: data.bidCounts[openJob.id] ?? 0,
            onTap: () => onOpenJob(openJob),
          ),
        ],
        SectionHeading(
          title: 'Your activity',
          actionLabel: 'View history',
          onAction: () => onOpenTab(1),
        ),
        AppCard(
          radius: 20,
          padding: const EdgeInsets.all(15),
          onTap: () => onOpenTab(1),
          child: Row(
            children: [
              const SoftIcon(
                Icons.verified_user_outlined,
                background: AppColors.successSurface,
                foreground: AppColors.success,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      activeCount == 0
                          ? 'No open requests'
                          : '$activeCount request${activeCount == 1 ? '' : 's'} in progress',
                      style: AppText.cardTitle,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Everything you need, all in one place.',
                      style: AppText.bodyMuted,
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
                size: 19,
                color: AppColors.mutedForeground,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ActiveJobCard extends StatelessWidget {
  const _ActiveJobCard({required this.job, required this.onTap});

  final Job job;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final status = JobStatusInfo.of(job.status);
    return AppCard(
      onTap: onTap,
      radius: 22,
      padding: const EdgeInsets.all(17),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 7),
                  const Text(
                    'ACTIVE JOB',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
              const Icon(
                Icons.north_east,
                size: 17,
                color: AppColors.mutedForeground,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            job.categoryName,
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w700,
              color: AppColors.foreground,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            job.description,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.bodyMuted.copyWith(fontSize: 12),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Divider(),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('STATUS', style: AppText.microLabel),
                  const SizedBox(height: 3),
                  Text(
                    status.customerLabel,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.foreground,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: status.progress / 100,
                      minHeight: 5,
                      backgroundColor: AppColors.muted,
                      valueColor: const AlwaysStoppedAnimation(AppColors.primary),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '${status.progress}%',
                style: AppText.meta.copyWith(fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BidsBanner extends StatelessWidget {
  const _BidsBanner({required this.bidCount, required this.onTap});

  final int bidCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasBids = bidCount > 0;
    return AppCard(
      onTap: onTap,
      color: AppColors.accent,
      borderColor: AppColors.accent,
      radius: 18,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          const SoftIcon(
            Icons.sell_outlined,
            background: Color(0xFFD7EEE5),
            size: 38,
            iconSize: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasBids
                      ? '$bidCount pro${bidCount == 1 ? '' : 's'} sent you a bid'
                      : 'Your request is live',
                  style: AppText.cardTitle.copyWith(
                    color: AppColors.accentForeground,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  hasBids
                      ? 'Compare prices and choose your match'
                      : 'We will let you know the moment a pro bids',
                  style: AppText.bodyMuted.copyWith(
                    color: AppColors.accentForeground,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.arrow_forward,
            size: 18,
            color: AppColors.accentForeground,
          ),
        ],
      ),
    );
  }
}
