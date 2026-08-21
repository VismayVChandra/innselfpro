import 'package:flutter/material.dart';

import '../../../core/format.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/widgets/layout.dart';

/// "Typical price in this category" hint, shown to a customer describing
/// a job and to a technician quoting one -- same data, same widget,
/// different audience. Renders nothing while loading or when there
/// isn't enough historical data to be a useful signal (JobsRepository.
/// fetchPriceGuidance already returns null below a sample-size floor).
class PriceGuidanceHint extends StatelessWidget {
  const PriceGuidanceHint({super.key, required this.future});

  final Future<({double average, double min, double max, int count})?> future;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<({double average, double min, double max, int count})?>(
      future: future,
      builder: (context, snapshot) {
        final guidance = snapshot.data;
        if (guidance == null) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.fromLTRB(kGutter, 0, kGutter, 12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: AppColors.secondary,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.insights_outlined,
                  size: 17,
                  color: AppColors.accentForeground,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Typical price: ${formatRupees(guidance.min)}–'
                    '${formatRupees(guidance.max)} '
                    '(from ${guidance.count} past jobs)',
                    style: AppText.meta.copyWith(color: AppColors.secondaryForeground),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
