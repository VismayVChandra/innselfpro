import 'package:flutter/material.dart';

import '../../../core/format.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/widgets/layout.dart';
import '../../../core/widgets/states.dart';
import '../../../core/widgets/surfaces.dart';
import '../../../models/review.dart';
import '../reviews_repository.dart';

class TechnicianRatingsScreen extends StatefulWidget {
  const TechnicianRatingsScreen({super.key});

  @override
  State<TechnicianRatingsScreen> createState() =>
      _TechnicianRatingsScreenState();
}

class _TechnicianRatingsScreenState extends State<TechnicianRatingsScreen> {
  late Future<List<Review>> _reviewsFuture;

  @override
  void initState() {
    super.initState();
    _reviewsFuture = ReviewsRepository().fetchReviewsForTechnician();
  }

  Future<void> _refresh() async {
    setState(
      () => _reviewsFuture = ReviewsRepository().fetchReviewsForTechnician(),
    );
    await _reviewsFuture;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          color: AppColors.primary,
          backgroundColor: AppColors.card,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(top: 10, bottom: 32),
            child: FutureBuilder<List<Review>>(
              future: _reviewsFuture,
              builder: (context, snapshot) {
                final reviews = snapshot.data ?? const <Review>[];
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const TopBar(eyebrow: 'REPUTATION', title: 'My ratings'),
                    if (snapshot.hasError)
                      ErrorView(
                        message: 'Could not load ratings: ${snapshot.error}',
                        onRetry: _refresh,
                      )
                    else if (snapshot.connectionState != ConnectionState.done)
                      const LoadingView()
                    else if (reviews.isEmpty)
                      const EmptyView(
                        icon: Icons.star_border_rounded,
                        title: 'No ratings yet',
                        message:
                            'Customers can rate you once they have paid for a completed job.',
                      )
                    else ...[
                      _AverageCard(reviews: reviews),
                      const SectionHeading(title: 'What customers said'),
                      for (final review in reviews)
                        _ReviewCard(review: review),
                    ],
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _AverageCard extends StatelessWidget {
  const _AverageCard({required this.reviews});

  final List<Review> reviews;

  @override
  Widget build(BuildContext context) {
    final average =
        reviews.map((r) => r.rating).reduce((a, b) => a + b) / reviews.length;
    return AppCard(
      color: AppColors.accent,
      borderColor: AppColors.accent,
      radius: 22,
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Text(
            average.toStringAsFixed(1),
            style: const TextStyle(
              fontSize: 40,
              fontWeight: FontWeight.w700,
              letterSpacing: -1.5,
              color: AppColors.accentForeground,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                StarRow(rating: average.round(), size: 19),
                const SizedBox(height: 7),
                Text(
                  '${reviews.length} rating${reviews.length == 1 ? '' : 's'} from customers',
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

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.review});

  final Review review;

  @override
  Widget build(BuildContext context) {
    final category = review.jobCategoryName;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        radius: 19,
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                StarRow(rating: review.rating, size: 16),
                const Spacer(),
                Text(
                  formatShortDate(review.createdAt),
                  style: AppText.bodyMuted.copyWith(fontSize: 10),
                ),
              ],
            ),
            if (category != null) ...[
              const SizedBox(height: 9),
              Row(
                children: [
                  Icon(
                    CategoryStyle.of(category).icon,
                    size: 14,
                    color: AppColors.mutedForeground,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    category,
                    style: AppText.meta.copyWith(fontSize: 11),
                  ),
                ],
              ),
            ],
            if (review.comment != null && review.comment!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                '"${review.comment!}"',
                style: AppText.body.copyWith(
                  fontSize: 12.5,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
