import 'package:flutter/material.dart';

import '../../../models/job.dart';

class JobDetailScreen extends StatelessWidget {
  const JobDetailScreen({super.key, required this.job});

  final Job job;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(job.categoryName)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Chip(label: Text(job.status.replaceAll('_', ' ').toUpperCase())),
            const SizedBox(height: 16),
            if (job.photoUrl != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  job.photoUrl!,
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                ),
              ),
              const SizedBox(height: 16),
            ],
            Text('Description', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(job.description),
            const SizedBox(height: 16),
            Text('Location', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(job.location),
            const SizedBox(height: 16),
            Text('Posted', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(job.createdAt.toLocal().toString()),
          ],
        ),
      ),
    );
  }
}
