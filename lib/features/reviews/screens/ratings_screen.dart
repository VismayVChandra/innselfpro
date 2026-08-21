import 'package:flutter/material.dart';

import '../../../core/format.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/widgets/layout.dart';
import '../../../core/widgets/states.dart';
import '../../../core/widgets/surfaces.dart';
import '../../../models/review.dart';

/// A viewer's own rating and the reviews behind it -- shared by both
/// directions of the two-way review system. Only the copy and the fetch
/// differ: a technician's ratings come from customers, a customer's
/// come from technicians.
class RatingsScreen extends StatefulWidget {
  const RatingsScreen({
    super.key,
    required this.title,
    required this.raterLabel,
    required this.emptyMessage,
    required this.fetchReviews,
  });

  final String title;

  /// Who the ratings are from, e.g. "customers" or "technicians".
  final String raterLabel;

  final String emptyMessage;
  final Future<List<Review>> Function() fetchReviews;

  @override
  State<RatingsScreen> createState() => _RatingsScreenState();
}

class _RatingsScreenState extends State<RatingsScreen> {
  late Future<List<Review>> _reviewsFuture;

  @override
  void initState() {
    super.initState();
    _reviewsFuture = widget.fetchReviews();
  }

  Future<void> _refresh() async {
    setState(() => _reviewsFuture = widget.fetchReviews());
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
                    TopBar(eyebrow: 'REPUTATION', title: widget.title),
                    if (snapshot.hasError)
                      ErrorView(
                        message: 'Could not load ratings: ${snapshot.error}',
                        onRetry: _refresh,
                      )
                    else if (snapshot.connectionState != ConnectionState.done)
                      const LoadingView()
                    else if (reviews.isEmpty)
                      EmptyView(
                        icon: Icons.star_border_rounded,
                        title: 'No ratings yet',
                        message: widget.emptyMessage,
                      )
                    else ...[
                      _AverageCard(reviews: reviews, raterLabel: widget.raterLabel),
                      SectionHeading(title: 'What ${widget.raterLabel} said'),
                      for (final review in reviews) _ReviewCard(review: review),
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
  const _AverageCard({required this.reviews, required this.raterLabel});

  final List<Review> reviews;
  final String raterLabel;

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
                  '${reviews.length} rating${reviews.length == 1 ? '' : 's'} from $raterLabel',
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
