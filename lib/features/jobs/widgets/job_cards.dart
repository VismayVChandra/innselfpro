import 'package:flutter/material.dart';

import '../../../core/format.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/widgets/surfaces.dart';
import '../../../models/job.dart';
import '../job_status.dart';

/// Row card for a job in a list the viewer already owns a stake in: the
/// customer's activity feed and the technician's won-jobs list.
class JobListCard extends StatelessWidget {
  const JobListCard({
    super.key,
    required this.job,
    required this.onTap,
    this.forTechnician = false,
  });

  final Job job;
  final VoidCallback onTap;
  final bool forTechnician;

  @override
  Widget build(BuildContext context) {
    final category = CategoryStyle.of(job.categoryName);
    final status = JobStatusInfo.of(job.status);
    final label =
        forTechnician ? status.technicianLabel : status.customerLabel;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        onTap: onTap,
        radius: 19,
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            SoftIcon.tinted(category.icon, color: category.color, size: 42, iconSize: 21),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          job.categoryName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.cardTitle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        formatShortDate(job.createdAt),
                        style: AppText.bodyMuted.copyWith(fontSize: 9.5),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    job.description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.bodyMuted.copyWith(fontSize: 10.5),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: status.color,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            const Icon(
              Icons.chevron_right,
              size: 19,
              color: AppColors.mutedForeground,
            ),
          ],
        ),
      ),
    );
  }
}

/// Row card for an open job in the technician's feed -- leads with the
/// category, then the ask, then where it is.
class JobFeedCard extends StatelessWidget {
  const JobFeedCard({super.key, required this.job, required this.onTap, this.distanceLabel});

  final Job job;
  final VoidCallback onTap;

  /// "3.2 km away" -- null when either side's coordinates aren't known,
  /// in which case the card just omits the line rather than guessing.
  final String? distanceLabel;

  @override
  Widget build(BuildContext context) {
    final category = CategoryStyle.of(job.categoryName);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        onTap: onTap,
        radius: 19,
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SoftIcon.tinted(category.icon, color: category.color, size: 42, iconSize: 21),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    job.categoryName.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    job.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.cardTitle.copyWith(height: 1.35),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        size: 12,
                        color: AppColors.mutedForeground,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          job.location,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.bodyMuted.copyWith(fontSize: 10.5),
                        ),
                      ),
                    ],
                  ),
                  if (job.scheduledFor != null) ...[
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        const Icon(
                          Icons.event_outlined,
                          size: 12,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            'Wants ${formatShortDate(job.scheduledFor!)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.bodyMuted.copyWith(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (distanceLabel != null) ...[
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        const Icon(
                          Icons.near_me_outlined,
                          size: 12,
                          color: AppColors.success,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          distanceLabel!,
                          style: AppText.bodyMuted.copyWith(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.success,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 6),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  formatShortDate(job.createdAt),
                  style: AppText.bodyMuted.copyWith(fontSize: 9.5),
                ),
                const SizedBox(height: 12),
                const Icon(
                  Icons.north_east,
                  size: 16,
                  color: AppColors.mutedForeground,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
