import 'package:flutter/material.dart';

import '../../../models/category.dart';
import '../../../models/job.dart';
import '../../../models/profile.dart';
import '../../auth/auth_repository.dart';
import '../../profile/profile_repository.dart';
import '../jobs_repository.dart';
import 'job_detail_screen.dart';

class TechnicianHomeScreen extends StatefulWidget {
  const TechnicianHomeScreen({super.key, required this.profile});

  final Profile profile;

  @override
  State<TechnicianHomeScreen> createState() => _TechnicianHomeScreenState();
}

class _TechnicianHomeScreenState extends State<TechnicianHomeScreen> {
  final _jobsRepository = JobsRepository();
  final _profileRepository = ProfileRepository();
  final _areaController = TextEditingController();

  List<Category> _categories = [];
  int? _selectedCategoryId;
  Future<List<Job>>? _feedFuture;
  bool _initializing = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final categories = await _jobsRepository.fetchCategories();
    final details = await _profileRepository.fetchMyTechnicianDetails();
    if (!mounted) return;
    setState(() {
      _categories = categories;
      _areaController.text = details?.serviceArea ?? '';
      _initializing = false;
      _feedFuture = _jobsRepository.fetchOpenJobsFeed(
        area: _areaController.text,
      );
    });
  }

  @override
  void dispose() {
    _areaController.dispose();
    super.dispose();
  }

  void _applyFilters() {
    setState(() {
      _feedFuture = _jobsRepository.fetchOpenJobsFeed(
        categoryId: _selectedCategoryId,
        area: _areaController.text,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Job Feed'),
        actions: [
          IconButton(
            onPressed: () => AuthRepository().signOut(),
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
          ),
        ],
      ),
      body: _initializing
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Column(
                    children: [
                      DropdownButtonFormField<int?>(
                        initialValue: _selectedCategoryId,
                        decoration: const InputDecoration(labelText: 'Category'),
                        items: [
                          const DropdownMenuItem(value: null, child: Text('All categories')),
                          ..._categories.map(
                            (c) => DropdownMenuItem(value: c.id, child: Text(c.name)),
                          ),
                        ],
                        onChanged: (v) {
                          _selectedCategoryId = v;
                          _applyFilters();
                        },
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _areaController,
                        decoration: InputDecoration(
                          labelText: 'Area',
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.search),
                            onPressed: _applyFilters,
                          ),
                        ),
                        onSubmitted: (_) => _applyFilters(),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: FutureBuilder<List<Job>>(
                    future: _feedFuture,
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return Center(child: Text('Could not load feed: ${snapshot.error}'));
                      }
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final jobs = snapshot.data!;
                      if (jobs.isEmpty) {
                        return const Center(child: Text('No open jobs match your filters.'));
                      }
                      return ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: jobs.length,
                        itemBuilder: (context, index) {
                          final job = jobs[index];
                          return Card(
                            child: ListTile(
                              title: Text(job.categoryName),
                              subtitle: Text(
                                '${job.location}\n${job.description}',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              isThreeLine: true,
                              onTap: () async {
                                await Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => JobDetailScreen(
                                      initialJob: job,
                                      viewerProfile: widget.profile,
                                    ),
                                  ),
                                );
                                _applyFilters();
                              },
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}
