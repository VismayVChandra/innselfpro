import 'package:flutter/material.dart';

import '../../../models/job.dart';
import '../../../models/profile.dart';
import '../../auth/auth_repository.dart';
import '../jobs_repository.dart';
import 'job_detail_screen.dart';
import 'post_job_screen.dart';

class CustomerHomeScreen extends StatefulWidget {
  const CustomerHomeScreen({super.key, required this.profile});

  final Profile profile;

  @override
  State<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen> {
  final _jobsRepository = JobsRepository();
  late Future<List<Job>> _jobsFuture;

  @override
  void initState() {
    super.initState();
    _jobsFuture = _jobsRepository.fetchMyJobs();
  }

  Future<void> _refresh() async {
    setState(() {
      _jobsFuture = _jobsRepository.fetchMyJobs();
    });
    await _jobsFuture;
  }

  Future<void> _openPostJob() async {
    final posted = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const PostJobScreen()),
    );
    if (posted == true) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Requests'),
        actions: [
          IconButton(
            onPressed: () => AuthRepository().signOut(),
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openPostJob,
        icon: const Icon(Icons.add),
        label: const Text('Post a job'),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<Job>>(
          future: _jobsFuture,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(child: Text('Could not load jobs: ${snapshot.error}'));
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final jobs = snapshot.data!;
            if (jobs.isEmpty) {
              return LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                    child: const Center(
                      child: Text("You haven't posted any jobs yet."),
                    ),
                  ),
                ),
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              itemCount: jobs.length,
              itemBuilder: (context, index) {
                final job = jobs[index];
                return Card(
                  child: ListTile(
                    title: Text(job.categoryName),
                    subtitle: Text(
                      job.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Chip(
                      label: Text(job.status.replaceAll('_', ' ')),
                    ),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => JobDetailScreen(job: job)),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
