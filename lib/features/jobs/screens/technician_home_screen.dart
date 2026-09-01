import 'package:flutter/material.dart';

import '../../../core/geo.dart';
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
  late final Stream<List<Job>> _openJobsStream = _jobsRepository.streamOpenJobs();

  List<Category> _categories = [];
  Set<int> _mySkillCategoryIds = {};
  bool _isAvailable = true;
  bool _isTogglingAvailability = false;

  /// The technician's own base location, once loaded -- null means
  /// "hasn't set one yet" (set from Edit profile), in which case the
  /// feed can't compute distance and just shows every open job
  /// unsorted, same as before this feature existed.
  double? _baseLat;
  double? _baseLng;
  double _radiusKm = 10;

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

  Future<void> _init() async {
    try {
      final categories = await _jobsRepository.fetchCategories();
      final details = await _profileRepository.fetchMyTechnicianDetails();
      final skillIds = await _profileRepository.fetchMySkillCategoryIds();
      if (!mounted) return;
      setState(() {
        _categories = categories;
        _mySkillCategoryIds = skillIds;
        _isAvailable = details?.isAvailable ?? true;
        _baseLat = details?.baseLat;
        _baseLng = details?.baseLng;
        _radiusKm = (details?.serviceRadiusKm ?? 10).toDouble();
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

  /// A technician's skill (and the category filter chips) only ever
  /// hold top-level ids -- picking a specific subcategory isn't offered
  /// client-side. A job can still be posted under a subcategory though
  /// (migration 020), so matching by exact id alone would silently hide
  /// e.g. a "Fridge Repair" job from a technician skilled in "Appliance
  /// Repair". This widens a set of top-level ids to also include every
  /// subcategory under them.
  Set<int> _withSubcategories(Iterable<int> topLevelIds) {
    final ids = topLevelIds.toSet();
    for (final category in _categories) {
      if (category.parentCategoryId != null && ids.contains(category.parentCategoryId)) {
        ids.add(category.id);
      }
    }
    return ids;
  }

  bool get _hasBaseLocation => _baseLat != null && _baseLng != null;

  /// Null when either side's coordinates are missing -- distance simply
  /// can't be known, rather than guessed.
  double? _distanceFor(Job job) {
    if (!_hasBaseLocation || !job.hasLocation) return null;
    return haversineKm(_baseLat!, _baseLng!, job.lat!, job.lng!);
  }

  /// Resolves each streamed row's category name (streaming carries no
  /// join), applies the category filter, and -- once the technician has
  /// set a base location -- filters to the chosen radius and sorts
  /// nearest first. Jobs without coordinates of their own (posted
  /// before this feature) are kept but sort to the end, never silently
  /// dropped. Pure client-side computation over the live snapshot, so a
  /// filter change never needs to hit the network.
  List<Job> _applyFilters(List<Job> generalJobs) {
    final namesById = _categoryNamesById;
    var jobs = generalJobs
        .map((j) => j.copyWithCategoryName(namesById[j.categoryId] ?? ''))
        .toList();

    Set<int>? categoryIds;
    if (_selectedCategoryId == null) {
      categoryIds = _mySkillCategoryIds.isEmpty ? null : _withSubcategories(_mySkillCategoryIds);
    } else if (_selectedCategoryId != 0) {
      categoryIds = _withSubcategories([_selectedCategoryId!]);
    }
    if (categoryIds != null) {
      jobs = jobs.where((j) => categoryIds!.contains(j.categoryId)).toList();
    }

    if (_hasBaseLocation) {
      jobs = jobs.where((j) {
        final distance = _distanceFor(j);
        return distance == null || distance <= _radiusKm;
      }).toList();
      jobs.sort((a, b) {
        final da = _distanceFor(a);
        final db = _distanceFor(b);
        if (da == null && db == null) return 0;
        if (da == null) return 1;
        if (db == null) return -1;
        return da.compareTo(db);
      });
    }
    return jobs;
  }

  Future<void> _toggleAvailability(bool value) async {
    setState(() {
      _isAvailable = value;
      _isTogglingAvailability = true;
    });
    try {
      await _profileRepository.setAvailability(value);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isAvailable = !value);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update availability: $e')),
      );
    } finally {
      if (mounted) setState(() => _isTogglingAvailability = false);
    }
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
              ScreenHeader(
                eyebrow: 'TECHNICIAN MODE',
                title: 'Job feed',
                action: NotificationBell(),
              ),
              if (_initializing)
                LoadingView(height: 300)
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
                      return LoadingView(height: 300);
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
                        _AvailabilityRow(
                          isAvailable: _isAvailable,
                          isUpdating: _isTogglingAvailability,
                          onChanged: _toggleAvailability,
                        ),
                        const SizedBox(height: 12),
                        _AreaPanel(
                          hasLocation: _hasBaseLocation,
                          radiusKm: _radiusKm,
                          jobCount: jobs.length,
                          isAvailable: _isAvailable,
                        ),
                        const SizedBox(height: 20),
                        _CategoryFilter(
                          categories: _categories.where((c) => c.isTopLevel).toList(),
                          selectedId: _selectedCategoryId,
                          onSelected: (id) => setState(() => _selectedCategoryId = id),
                        ),
                        if (_hasBaseLocation) ...[
                          const SizedBox(height: 8),
                          _RadiusControl(
                            radiusKm: _radiusKm,
                            onChanged: (value) => setState(() => _radiusKm = value),
                          ),
                        ],
                        if (jobs.isEmpty)
                          Column(
                            children: [
                              EmptyView(
                                icon: Icons.search_off_rounded,
                                title: 'No open jobs match your filters',
                                message: _hasBaseLocation
                                    ? 'Try widening your radius or picking a different category.'
                                    : 'Try picking a different category, or set your service radius from Edit profile.',
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
                            JobFeedCard(
                              job: job,
                              onTap: () => _openJob(job),
                              distanceLabel: _distanceFor(job) == null
                                  ? null
                                  : formatDistance(_distanceFor(job)!),
                            ),
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

/// Compact card toggle above the area panel -- flipping this off stops
/// wave 4.3's new-job pushes and drops this technician from rebook /
/// direct-request selection (migration 012).
class _AvailabilityRow extends StatelessWidget {
  const _AvailabilityRow({
    required this.isAvailable,
    required this.isUpdating,
    required this.onChanged,
  });

  final bool isAvailable;
  final bool isUpdating;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: kGutter),
      child: AppCard(
        radius: 19,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            SoftIcon(
              isAvailable ? Icons.visibility_outlined : Icons.visibility_off_outlined,
              background: isAvailable ? AppColors.successSurface : AppColors.muted,
              foreground: isAvailable ? AppColors.success : AppColors.mutedForeground,
              size: 38,
              iconSize: 18,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isAvailable ? 'Available for new jobs' : 'Not taking new jobs',
                    style: AppText.cardTitle.copyWith(fontSize: 12.5),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    isAvailable
                        ? "You'll get new-job alerts and can be rebooked."
                        : 'Hidden from alerts and rebook until you switch back on.',
                    style: AppText.bodyMuted.copyWith(fontSize: 10),
                  ),
                ],
              ),
            ),
            if (isUpdating)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Switch(
                value: isAvailable,
                onChanged: onChanged,
                activeTrackColor: AppColors.primary,
              ),
          ],
        ),
      ),
    );
  }
}

/// Dark panel summarising where this technician is looking for work --
/// available and visible within a radius, available everywhere (no
/// location set yet), or offline.
class _AreaPanel extends StatelessWidget {
  const _AreaPanel({
    required this.hasLocation,
    required this.radiusKm,
    required this.jobCount,
    required this.isAvailable,
  });

  final bool hasLocation;
  final double radiusKm;
  final int jobCount;
  final bool isAvailable;

  @override
  Widget build(BuildContext context) {
    return DarkPanel(
      minHeight: 150,
      padding: const EdgeInsets.all(20),
      solidColor: !isAvailable
          ? AppColors.foreground.withValues(alpha: 0.55)
          : hasLocation
              ? AppColors.panelOnline
              : AppColors.panelStart,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            !isAvailable
                ? 'OFFLINE'
                : hasLocation
                    ? 'YOU ARE VISIBLE WITHIN'
                    : 'NO SERVICE RADIUS SET',
            style: TextStyle(
              color: AppColors.onPanelKicker,
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            !isAvailable
                ? 'Not visible to customers'
                : hasLocation
                    ? '${radiusKm.round()} km of you'
                    : 'Showing every open job',
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
            !isAvailable
                ? 'Switch availability back on to start getting new-job alerts again.'
                : jobCount == 0
                    ? 'Nothing open right now. New requests will appear live.'
                    : '$jobCount open request${jobCount == 1 ? '' : 's'} waiting for a bid.',
            style: TextStyle(
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

/// Radius slider shown once the technician has a base location set --
/// filters and re-sorts the feed live as it's dragged.
class _RadiusControl extends StatelessWidget {
  const _RadiusControl({required this.radiusKm, required this.onChanged});

  final double radiusKm;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: kGutter),
      child: Row(
        children: [
          Icon(Icons.radar_outlined, size: 16, color: AppColors.mutedForeground),
          const SizedBox(width: 8),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: AppColors.primary,
                thumbColor: AppColors.primary,
                inactiveTrackColor: AppColors.border,
              ),
              child: Slider(
                value: radiusKm.clamp(5, 50),
                min: 5,
                max: 50,
                divisions: 9,
                label: '${radiusKm.round()} km',
                onChanged: onChanged,
              ),
            ),
          ),
          SizedBox(
            width: 46,
            child: Text(
              '${radiusKm.round()} km',
              textAlign: TextAlign.right,
              style: AppText.bodyMuted.copyWith(fontWeight: FontWeight.w600),
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
