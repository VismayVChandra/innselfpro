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
import '../../profile/profile_repository.dart';
import '../../shell/refresh_signal.dart';
import '../jobs_repository.dart';
import '../widgets/job_cards.dart';
import 'job_detail_screen.dart';

/// Feed tab: every open job a technician could bid on, filtered by
/// category and area. Live -- one realtime subscription carries both
/// the general feed and any job invited directly to this technician;
/// jobs_select's RLS means any invited-job row reaching this stream is
/// necessarily invited to this technician (nobody else's invite could
/// ever arrive here), so no separate query is needed to tell them apart.
class TechnicianHomeScreen extends StatefulWidget {
  const TechnicianHomeScreen({
    super.key,
    required this.profile,
    required this.onOpenTab,
  });

  final Profile profile;
  final ValueChanged<int> onOpenTab;

  @override
  State<TechnicianHomeScreen> createState() => _TechnicianHomeScreenState();
}

class _TechnicianHomeScreenState extends State<TechnicianHomeScreen> {
  final _jobsRepository = JobsRepository();
  final _profileRepository = ProfileRepository();
  final _areaController = TextEditingController();
  late final Stream<List<Job>> _openJobsStream = _jobsRepository.streamOpenJobs();

  List<Category> _categories = [];
  Set<int> _mySkillCategoryIds = {};

  /// null = "My skills" (the default); 0 = "All"; anything else = that
  /// one category. 0 is a safe sentinel since Postgres serial ids start
  /// at 1.
  int? _selectedCategoryId;

  bool _initializing = true;
  Object? _initError;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _areaController.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    try {
      final categories = await _jobsRepository.fetchCategories();
      final details = await _profileRepository.fetchMyTechnicianDetails();
      final skillIds = await _profileRepository.fetchMySkillCategoryIds();
      if (!mounted) return;
      setState(() {
        _categories = categories;
        _mySkillCategoryIds = skillIds;
        _areaController.text = details?.serviceArea ?? '';
        _initializing = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _initError = e;
        _initializing = false;
      });
    }
  }

  Map<int, String> get _categoryNamesById => {
        for (final category in _categories) category.id: category.name,
      };

  /// Resolves each streamed row's category name (streaming carries no
  /// join), then applies whatever category/area filter is currently
  /// selected -- pure client-side computation over the live snapshot,
  /// so a filter change never needs to hit the network.
  List<Job> _applyFilters(List<Job> generalJobs) {
    final namesById = _categoryNamesById;
    var jobs = generalJobs
        .map((j) => j.copyWithCategoryName(namesById[j.categoryId] ?? ''))
        .toList();

    List<int>? categoryIds;
    if (_selectedCategoryId == null) {
      categoryIds = _mySkillCategoryIds.isEmpty ? null : _mySkillCategoryIds.toList();
    } else if (_selectedCategoryId != 0) {
      categoryIds = [_selectedCategoryId!];
    }
    if (categoryIds != null) {
      jobs = jobs.where((j) => categoryIds!.contains(j.categoryId)).toList();
    }

    final area = _areaController.text.trim().toLowerCase();
    if (area.isNotEmpty) {
      jobs = jobs.where((j) => j.location.toLowerCase().contains(area)).toList();
    }
    return jobs;
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
    // Other screens (e.g. "My Jobs") still fetch one-shot and need this
    // nudge to refresh after something changes here.
    if (mounted) RefreshScope.of(context).bump();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: _init,
        color: AppColors.primary,
        backgroundColor: AppColors.card,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(top: 16, bottom: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const ScreenHeader(
                eyebrow: 'TECHNICIAN MODE',
                title: 'Job feed',
                action: NotificationBell(),
              ),
              if (_initializing)
                const LoadingView(height: 300)
              else if (_initError != null)
                ErrorView(
                  message: 'Could not load the feed: $_initError',
                  onRetry: () {
                    setState(() {
                      _initializing = true;
                      _initError = null;
                    });
                    _init();
                  },
                )
              else
                StreamBuilder<List<Job>>(
                  stream: _openJobsStream,
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return ErrorView(
                        message: 'Could not load the feed: ${snapshot.error}',
                      );
                    }
                    if (!snapshot.hasData) {
                      return const LoadingView(height: 300);
                    }
                    final namesById = _categoryNamesById;
                    final all = snapshot.data!;
                    final invited = all
                        .where((j) => j.invitedTechnicianId != null)
                        .map((j) => j.copyWithCategoryName(namesById[j.categoryId] ?? ''))
                        .toList();
                    final general = all.where((j) => j.invitedTechnicianId == null).toList();
                    final jobs = _applyFilters(general);

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (invited.isNotEmpty) ...[
                          SectionHeading(
                            title: 'Direct requests',
                            actionLabel: '${invited.length}',
                            topPadding: 0,
                          ),
                          for (final job in invited)
                            JobFeedCard(job: job, onTap: () => _openJob(job)),
                          const SizedBox(height: 6),
                        ],
                        _AreaPanel(area: _areaController.text, jobCount: jobs.length),
                        const SizedBox(height: 20),
                        _CategoryFilter(
                          categories: _categories,
                          selectedId: _selectedCategoryId,
                          onSelected: (id) => setState(() => _selectedCategoryId = id),
                        ),
                        const SizedBox(height: 12),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: kGutter),
                          child: TextField(
                            controller: _areaController,
                            textInputAction: TextInputAction.search,
                            style: AppText.body.copyWith(fontSize: 13),
                            decoration: const InputDecoration(
                              hintText: 'Filter by area, e.g. Koramangala',
                              prefixIcon: Icon(
                                Icons.search,
                                size: 20,
                                color: AppColors.mutedForeground,
                              ),
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        if (jobs.isEmpty)
                          Column(
                            children: [
                              const EmptyView(
                                icon: Icons.search_off_rounded,
                                title: 'No open jobs match your filters',
                                message:
                                    'Try clearing the area or picking a different category.',
                              ),
                              OutlineButton(
                                label: 'See the jobs you have won',
                                icon: Icons.work_outline_rounded,
                                onPressed: () => widget.onOpenTab(1),
                              ),
                            ],
                          )
                        else ...[
                          SectionHeading(
                            title: 'Nearby opportunities',
                            actionLabel: '${jobs.length} open',
                            topPadding: 26,
                          ),
                          for (final job in jobs)
                            JobFeedCard(job: job, onTap: () => _openJob(job)),
                        ],
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

/// Dark panel summarising where this technician is looking for work.
class _AreaPanel extends StatelessWidget {
  const _AreaPanel({required this.area, required this.jobCount});

  final String area;
  final int jobCount;

  @override
  Widget build(BuildContext context) {
    final hasArea = area.trim().isNotEmpty;
    return DarkPanel(
      minHeight: 150,
      padding: const EdgeInsets.all(20),
      solidColor: hasArea ? AppColors.panelOnline : AppColors.panelStart,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            hasArea ? 'YOU ARE VISIBLE IN' : 'NO SERVICE AREA SET',
            style: const TextStyle(
              color: AppColors.onPanelKicker,
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            hasArea ? area : 'Showing every open job',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 21,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            jobCount == 0
                ? 'Nothing open right now. New requests will appear live.'
                : '$jobCount open request${jobCount == 1 ? '' : 's'} waiting for a bid.',
            style: const TextStyle(
              color: AppColors.onPanelMuted,
              fontSize: 11.5,
              height: 1.5,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}

/// Horizontally scrolling category filter: "My skills" (the default),
/// then "All", then every individual category.
class _CategoryFilter extends StatelessWidget {
  const _CategoryFilter({
    required this.categories,
    required this.selectedId,
    required this.onSelected,
  });

  final List<Category> categories;
  final int? selectedId;
  final ValueChanged<int?> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: kGutter),
        children: [
          ChoicePill(
            label: 'My skills',
            selected: selectedId == null,
            onTap: () => onSelected(null),
          ),
          const SizedBox(width: 8),
          ChoicePill(
            label: 'All',
            selected: selectedId == 0,
            onTap: () => onSelected(0),
          ),
          for (final category in categories) ...[
            const SizedBox(width: 8),
            ChoicePill(
              label: category.name,
              selected: category.id == selectedId,
              onTap: () => onSelected(category.id),
            ),
          ],
        ],
      ),
    );
  }
}
