import 'dart:io';

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/widgets/layout.dart';

/// A row of picked photo thumbnails plus an "add" tile, capped at
/// [maxPhotos]. Distinct from the single-photo JobPhotoPicker (used for
/// the technician's one completion photo) -- this needs individually
/// removable thumbnails in a grid, not one big preview.
class JobPhotosPicker extends StatelessWidget {
  const JobPhotosPicker({
    super.key,
    required this.photos,
    required this.onAdd,
    required this.onRemove,
    this.maxPhotos = 5,
  });

  final List<File> photos;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;
  final int maxPhotos;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: kGutter),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          for (var i = 0; i < photos.length; i++)
            _Thumb(file: photos[i], onRemove: () => onRemove(i)),
          if (photos.length < maxPhotos) _AddTile(onTap: onAdd),
        ],
      ),
    );
  }
}

const _tileSize = 84.0;

class _Thumb extends StatelessWidget {
  const _Thumb({required this.file, required this.onRemove});

  final File file;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _tileSize,
      height: _tileSize,
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(15),
            child: Image.file(
              file,
              width: _tileSize,
              height: _tileSize,
              fit: BoxFit.cover,
            ),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: Material(
              color: Colors.black.withValues(alpha: 0.55),
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onRemove,
                child: const SizedBox(
                  width: 22,
                  height: 22,
                  child: Icon(Icons.close_rounded, size: 14, color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AddTile extends StatelessWidget {
  const _AddTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Container(
          width: _tileSize,
          height: _tileSize,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add_a_photo_outlined, size: 20, color: AppColors.mutedForeground),
              const SizedBox(height: 4),
              Text('Add', style: AppText.bodyMuted.copyWith(fontSize: 10)),
            ],
          ),
        ),
      ),
    );
  }
}
