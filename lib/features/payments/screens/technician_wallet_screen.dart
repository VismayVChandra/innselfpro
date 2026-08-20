import 'package:flutter/material.dart';

import '../../../core/format.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/widgets/layout.dart';
import '../../../core/widgets/states.dart';
import '../../../core/widgets/surfaces.dart';
import '../../../models/payment.dart';
import '../payments_repository.dart';

class TechnicianWalletScreen extends StatefulWidget {
  const TechnicianWalletScreen({super.key});

  @override
  State<TechnicianWalletScreen> createState() => _TechnicianWalletScreenState();
}

class _TechnicianWalletScreenState extends State<TechnicianWalletScreen> {
  late Future<List<Payment>> _earningsFuture;

  @override
  void initState() {
    super.initState();
    _earningsFuture = PaymentsRepository().fetchMyEarnings();
  }

  Future<void> _refresh() async {
    setState(() => _earningsFuture = PaymentsRepository().fetchMyEarnings());
    await _earningsFuture;
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
            child: FutureBuilder<List<Payment>>(
              future: _earningsFuture,
              builder: (context, snapshot) {
                final payments = snapshot.data ?? const <Payment>[];
                final total =
                    payments.fold<double>(0, (sum, p) => sum + p.amount);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const TopBar(eyebrow: 'EARNINGS', title: 'Wallet'),
                    if (snapshot.hasError)
                      ErrorView(
                        message: 'Could not load earnings: ${snapshot.error}',
                        onRetry: _refresh,
                      )
                    else if (snapshot.connectionState != ConnectionState.done)
                      const LoadingView()
                    else ...[
                      _BalancePanel(
                        total: total,
                        jobCount: payments.length,
                      ),
                      const SectionHeading(title: 'Paid jobs'),
                      if (payments.isEmpty)
                        const EmptyView(
                          icon: Icons.receipt_long_outlined,
                          title: 'No paid jobs yet',
                          message:
                              'Once a customer pays for a job you completed, it lands here.',
                        )
                      else
                        for (final payment in payments)
                          _PaymentRow(payment: payment),
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
  const _BalancePanel({required this.total, required this.jobCount});

  final double total;
  final int jobCount;

  @override
  Widget build(BuildContext context) {
    return DarkPanel(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'TOTAL EARNED',
            style: TextStyle(
              color: AppColors.onPanelKicker,
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            formatRupees(total),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.w700,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            jobCount == 0
                ? 'No payments have landed yet.'
                : 'Across $jobCount paid job${jobCount == 1 ? '' : 's'}.',
            style: const TextStyle(
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

class _PaymentRow extends StatelessWidget {
  const _PaymentRow({required this.payment});

  final Payment payment;

  @override
  Widget build(BuildContext context) {
    final category = payment.jobCategoryName ?? 'Job';
    final style = CategoryStyle.of(category);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        radius: 19,
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            SoftIcon.tinted(style.icon, color: style.color, size: 42, iconSize: 21),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(child: Text(category, style: AppText.cardTitle)),
                      if (payment.isCash) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.muted,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'CASH',
                            style: TextStyle(
                              fontSize: 8.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                              color: AppColors.mutedForeground,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    payment.paidAt == null
                        ? 'Paid'
                        : 'Paid ${formatShortDate(payment.paidAt!)}',
                    style: AppText.bodyMuted.copyWith(fontSize: 10.5),
                  ),
                ],
              ),
            ),
            Text(
              formatRupees(payment.amount),
              style: AppText.cardTitleLarge.copyWith(
                fontSize: 15,
                color: AppColors.success,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
