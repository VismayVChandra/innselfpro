import 'package:flutter/material.dart';

import '../../../models/review.dart';
import '../reviews_repository.dart';

class TechnicianRatingsScreen extends StatefulWidget {
  const TechnicianRatingsScreen({super.key});

  @override
  State<TechnicianRatingsScreen> createState() => _TechnicianRatingsScreenState();
}

class _TechnicianRatingsScreenState extends State<TechnicianRatingsScreen> {
  late final Future<List<Review>> _reviewsFuture;

  @override
  void initState() {
    super.initState();
    _reviewsFuture = ReviewsRepository().fetchReviewsForTechnician();
  }

  Widget _buildStarRow(int rating) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        5,
        (i) => Icon(
          i < rating ? Icons.star : Icons.star_border,
          color: Colors.amber,
          size: 18,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Ratings')),
      body: FutureBuilder<List<Review>>(
        future: _reviewsFuture,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Could not load ratings: ${snapshot.error}'));
          }
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final reviews = snapshot.data!;
          if (reviews.isEmpty) {
            return const Center(child: Text("You haven't received any ratings yet."));
          }
          final average = reviews.map((r) => r.rating).reduce((a, b) => a + b) / reviews.length;
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text(
                      average.toStringAsFixed(1),
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    _buildStarRow(average.round()),
                    Text('${reviews.length} rating${reviews.length == 1 ? '' : 's'}'),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: reviews.length,
                  itemBuilder: (context, index) {
                    final review = reviews[index];
                    return Card(
                      child: ListTile(
                        title: _buildStarRow(review.rating),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (review.jobCategoryName != null)
                              Text(review.jobCategoryName!),
                            if (review.comment != null && review.comment!.isNotEmpty)
                              Text(review.comment!),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
