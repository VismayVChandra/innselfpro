import 'package:flutter/material.dart';

import '../../../core/format.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/widgets/layout.dart';
import '../../../core/widgets/states.dart';
import '../../../core/widgets/surfaces.dart';
import '../../../models/points_transaction.dart';
import '../points_repository.dart';

class PointsScreen extends StatefulWidget {
  const PointsScreen({super.key});

  @override
  State<PointsScreen> createState() => _PointsScreenState();
}

class _PointsScreenState extends State<PointsScreen> {
  final _repository = PointsRepository();
  late Future<(int, List<PointsTransaction>)> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<(int, List<PointsTransaction>)> _load() async {
    final balance = await _repository.fetchBalance();
    final history = await _repository.fetchHistory();
    return (balance, history);
  }

  Future<void> _refresh() async {
    setState(() => _future = _load());
    await _future;
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
            child: FutureBuilder<(int, List<PointsTransaction>)>(
              future: _future,
              builder: (context, snapshot) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const TopBar(eyebrow: 'REWARDS', title: 'Points'),
                    if (snapshot.hasError)
                      ErrorView(
                        message: 'Could not load points: ${snapshot.error}',
                        onRetry: _refresh,
                      )
                    else if (snapshot.connectionState != ConnectionState.done)
                      const LoadingView()
                    else ...[
                      _BalancePanel(balance: snapshot.data!.$1),
                      const SectionHeading(title: 'History'),
                      if (snapshot.data!.$2.isEmpty)
                        const EmptyView(
                          icon: Icons.stars_outlined,
                          title: 'No points yet',
                          message:
                              'Arrive on time, finish jobs, pay promptly, and leave reviews to start earning.',
                        )
                      else
                        for (final tx in snapshot.data!.$2) _TransactionRow(tx: tx),
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

class _BalancePanel extends StatelessWidget {
  const _BalancePanel({required this.balance});

  final int balance;

  @override
  Widget build(BuildContext context) {
    return DarkPanel(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'YOUR BALANCE',
            style: TextStyle(
              color: AppColors.onPanelKicker,
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '$balance pts',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.w700,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Spend points to boost a bid or job to the top of the list.',
            style: TextStyle(
              color: AppColors.onPanelMuted,
              fontSize: 11.5,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

String _labelFor(String reason) {
  switch (reason) {
    case 'on_time_arrival':
      return 'On-time arrival';
    case 'job_completed':
      return 'Job completed';
    case 'prompt_payment':
      return 'Paid promptly';
    case 'review_left':
      return 'Left a review';
    case 'boost_bid':
      return 'Boosted a bid';
    case 'boost_job':
      return 'Boosted a job';
    default:
      return reason;
  }
}

IconData _iconFor(String reason) {
  switch (reason) {
    case 'on_time_arrival':
      return Icons.directions_car_filled_outlined;
    case 'job_completed':
      return Icons.check_circle_outline;
    case 'prompt_payment':
      return Icons.payments_outlined;
    case 'review_left':
      return Icons.star_outline_rounded;
    case 'boost_bid':
    case 'boost_job':
      return Icons.trending_up_rounded;
    default:
      return Icons.stars_outlined;
  }
}

class _TransactionRow extends StatelessWidget {
  const _TransactionRow({required this.tx});

  final PointsTransaction tx;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        radius: 19,
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            SoftIcon.tinted(
              _iconFor(tx.reason),
              color: tx.isEarn ? AppColors.success : AppColors.mutedForeground,
              size: 42,
              iconSize: 21,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_labelFor(tx.reason), style: AppText.cardTitle),
                  const SizedBox(height: 4),
                  Text(formatShortDate(tx.createdAt), style: AppText.bodyMuted.copyWith(fontSize: 10.5)),
                ],
              ),
            ),
            Text(
              '${tx.isEarn ? '+' : ''}${tx.delta}',
              style: AppText.cardTitleLarge.copyWith(
                fontSize: 15,
                color: tx.isEarn ? AppColors.success : AppColors.destructive,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
