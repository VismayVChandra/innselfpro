import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Presentation layer over the raw `jobs.status` values. The database
/// stores four states; the UI wants a friendly label per audience, a
/// progress fraction for the tracker bars, and a colour.
class JobStatusInfo {
  const JobStatusInfo({
    required this.customerLabel,
    required this.technicianLabel,
    required this.progress,
    required this.color,
    required this.step,
  });

  /// How the customer sees this state.
  final String customerLabel;

  /// How the assigned technician sees it.
  final String technicianLabel;

  /// 0-100, for the progress bars on the home and job screens.
  final int progress;

  final Color color;

  /// Index into the five-step timeline on the job screen.
  final int step;

  static const _open = JobStatusInfo(
    customerLabel: 'Collecting bids',
    technicianLabel: 'Open for bids',
    progress: 15,
    color: AppColors.accentForeground,
    step: 0,
  );

  static const _bidAccepted = JobStatusInfo(
    customerLabel: 'Technician assigned',
    technicianLabel: 'You won this job',
    progress: 45,
    color: AppColors.warn,
    step: 1,
  );

  static const _inProgress = JobStatusInfo(
    customerLabel: 'Work in progress',
    technicianLabel: 'Work in progress',
    progress: 75,
    color: AppColors.primary,
    step: 2,
  );

  static const _completed = JobStatusInfo(
    customerLabel: 'Completed',
    technicianLabel: 'Completed',
    progress: 100,
    color: AppColors.success,
    step: 3,
  );

  static const _cancelled = JobStatusInfo(
    customerLabel: 'Cancelled',
    technicianLabel: 'Cancelled',
    progress: 0,
    color: AppColors.mutedForeground,
    step: 0,
  );

  static const _unknown = JobStatusInfo(
    customerLabel: 'Unknown',
    technicianLabel: 'Unknown',
    progress: 0,
    color: AppColors.mutedForeground,
    step: 0,
  );

  static JobStatusInfo of(String status) => switch (status) {
        'open' => _open,
        'bid_accepted' => _bidAccepted,
        'in_progress' => _inProgress,
        'completed' => _completed,
        'cancelled' => _cancelled,
        _ => _unknown,
      };

  /// The five milestones drawn on the job tracker, in order.
  static const timeline = <({String label, IconData icon})>[
    (label: 'Request posted', icon: Icons.send_outlined),
    (label: 'Technician assigned', icon: Icons.person_outline),
    (label: 'Work in progress', icon: Icons.handyman_outlined),
    (label: 'Job completed', icon: Icons.check_circle_outline),
  ];

  /// Is this job still moving?
  static bool isActive(String status) =>
      status == 'bid_accepted' || status == 'in_progress';

  /// Does the four-step tracker make sense for this status? Not for
  /// 'open' (nothing assigned yet) or 'cancelled' (nothing to track).
  static bool showsTimeline(String status) =>
      status == 'bid_accepted' || status == 'in_progress' || status == 'completed';
}
