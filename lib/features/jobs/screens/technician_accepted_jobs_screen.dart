import 'package:flutter/material.dart';

import '../../../models/job.dart';
import '../../../models/profile.dart';
import '../jobs_repository.dart';
import 'job_detail_screen.dart';

class TechnicianAcceptedJobsScreen extends StatefulWidget {
  const TechnicianAcceptedJobsScreen({super.key, required this.profile});

  final Profile profile;

  @override
  State<TechnicianAcceptedJobsScreen> createState() =>
      _TechnicianAcceptedJobsScreenState();
}

class _TechnicianAcceptedJobsScreenState
    extends State<TechnicianAcceptedJobsScreen> {
  final _jobsRepository = JobsRepository();
  late Future<List<Job>> _jobsFuture;

  @override
  void initState() {
    super.initState();
    _jobsFuture = _jobsRepository.fetchMyAcceptedJobs();
  }

  void _refresh() {
    setState(() {
      _jobsFuture = _jobsRepository.fetchMyAcceptedJobs();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Jobs')),
      body: FutureBuilder<List<Job>>(
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
            return const Center(child: Text("You haven't won any bids yet."));
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
                    job.location,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Chip(label: Text(job.status.replaceAll('_', ' '))),
                  onTap: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => JobDetailScreen(
                          initialJob: job,
                          viewerProfile: widget.profile,
                        ),
                      ),
                    );
                    _refresh();
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
