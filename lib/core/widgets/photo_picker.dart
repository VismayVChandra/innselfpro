import 'dart:io';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import 'layout.dart';
import 'surfaces.dart';

/// Optional photo attachment: an invitation card while empty, a preview
/// with edit/clear actions once picked. Shared by the post-job form and
/// the technician's completion-photo flow.
class JobPhotoPicker extends StatelessWidget {
  const JobPhotoPicker({
    super.key,
    required this.photo,
    required this.onPick,
    required this.onClear,
    this.icon = Icons.photo_camera_outlined,
    this.title = 'Add a photo',
    this.subtitle = 'Optional, but it helps.',
    this.previewHeight = 170,
  });

  final File? photo;
  final VoidCallback onPick;
  final VoidCallback onClear;
  final IconData icon;
  final String title;
  final String subtitle;
  final double previewHeight;

  @override
  Widget build(BuildContext context) {
    if (photo == null) {
      return AppCard(
        onTap: onPick,
        radius: 17,
        padding: const EdgeInsets.all(13),
        child: Row(
          children: [
            SoftIcon(icon, size: 39, iconSize: 19),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppText.cardTitle),
                  const SizedBox(height: 4),
                  Text(subtitle, style: AppText.bodyMuted.copyWith(fontSize: 10.5)),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              size: 18,
              color: AppColors.mutedForeground,
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: kGutter),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(17),
            child: Image.file(
              photo!,
              height: previewHeight,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
          Positioned(
            top: 10,
            right: 10,
            child: Row(
              children: [
                _PhotoAction(icon: Icons.edit_outlined, onTap: onPick),
                const SizedBox(width: 8),
                _PhotoAction(icon: Icons.close_rounded, onTap: onClear),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PhotoAction extends StatelessWidget {
  const _PhotoAction({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.card,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: 34,
          height: 34,
          child: Icon(icon, size: 17, color: AppColors.foreground),
        ),
      ),
    );
  }
}
