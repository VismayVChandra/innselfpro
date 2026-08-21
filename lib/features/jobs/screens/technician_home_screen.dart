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
/// category and area.
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

class _TechnicianHomeScreenState extends State<TechnicianHomeScreen>
    with RefreshAware {
  final _jobsRepository = JobsRepository();
  final _profileRepository = ProfileRepository();
  final _areaController = TextEditingController();

  List<Category> _categories = [];
  Set<int> _mySkillCategoryIds = {};

  /// null = "My skills" (the default); 0 = "All"; anything else = that
  /// one category. 0 is a safe sentinel since Postgres serial ids start
  /// at 1.
  int? _selectedCategoryId;

  Future<List<Job>>? _feedFuture;
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

  @override
  void onRefreshSignal() {
    if (!_initializing) _applyFilters();
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
      _applyFilters();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _initError = e;
        _initializing = false;
      });
    }
  }

  void _applyFilters() {
    setState(() {
      List<int>? categoryIds;
      if (_selectedCategoryId == null) {
        categoryIds = _mySkillCategoryIds.isEmpty ? null : _mySkillCategoryIds.toList();
      } else if (_selectedCategoryId != 0) {
        categoryIds = [_selectedCategoryId!];
      }
      _feedFuture = _jobsRepository.fetchOpenJobsFeed(
        categoryIds: categoryIds,
        area: _areaController.text,
      );
    });
  }

  Future<void> _refresh() async {
    _applyFilters();
    await _feedFuture;
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
              else ...[
                _AreaPanel(
                  area: _areaController.text,
                  feedFuture: _feedFuture,
                ),
                const SizedBox(height: 20),
                _CategoryFilter(
                  categories: _categories,
                  selectedId: _selectedCategoryId,
                  onSelected: (id) {
                    _selectedCategoryId = id;
                    _applyFilters();
                  },
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: kGutter),
                  child: TextField(
                    controller: _areaController,
                    textInputAction: TextInputAction.search,
                    style: AppText.body.copyWith(fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Filter by area, e.g. Koramangala',
                      prefixIcon: const Icon(
                        Icons.search,
                        size: 20,
                        color: AppColors.mutedForeground,
                      ),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.arrow_forward, size: 18),
                        color: AppColors.primary,
                        onPressed: _applyFilters,
                        tooltip: 'Apply',
                      ),
                    ),
                    onSubmitted: (_) => _applyFilters(),
                  ),
                ),
                FutureBuilder<List<Job>>(
                  future: _feedFuture,
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return ErrorView(
                        message: 'Could not load the feed: ${snapshot.error}',
                        onRetry: _applyFilters,
                      );
                    }
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const LoadingView();
                    }
                    final jobs = snapshot.data!;
                    if (jobs.isEmpty) {
                      return Column(
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
                      );
                    }
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SectionHeading(
                          title: 'Nearby opportunities',
                          actionLabel:
                              '${jobs.length} open',
                          topPadding: 26,
                        ),
                        for (final job in jobs)
                          JobFeedCard(job: job, onTap: () => _openJob(job)),
                      ],
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Dark panel summarising where this technician is looking for work.
class _AreaPanel extends StatelessWidget {
  const _AreaPanel({required this.area, required this.feedFuture});

  final String area;
  final Future<List<Job>>? feedFuture;

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
          FutureBuilder<List<Job>>(
            future: feedFuture,
            builder: (context, snapshot) {
              final count = snapshot.data?.length;
              return Text(
                count == null
                    ? 'Looking for open requests...'
                    : count == 0
                        ? 'Nothing open right now. Pull down to refresh.'
                        : '$count open request${count == 1 ? '' : 's'} waiting for a bid.',
                style: const TextStyle(
                  color: AppColors.onPanelMuted,
                  fontSize: 11.5,
                  height: 1.5,
                  fontWeight: FontWeight.w400,
                ),
              );
            },
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
