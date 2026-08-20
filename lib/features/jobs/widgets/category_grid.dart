import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/layout.dart';
import '../../../models/category.dart';

/// Three-across grid of service categories. Doubles as the home screen's
/// "Book a service" launcher and the request form's category picker --
/// the same tiles, with the picker showing a selected state.
class CategoryGrid extends StatelessWidget {
  const CategoryGrid({
    super.key,
    required this.categories,
    required this.onTap,
    this.selectedId,
    this.limit,
  });

  final List<Category> categories;
  final ValueChanged<Category> onTap;
  final int? selectedId;

  /// Show only the first N categories (the home screen shows six).
  final int? limit;

  @override
  Widget build(BuildContext context) {
    final shown =
        limit == null ? categories : categories.take(limit!).toList();
    const spacing = 10.0;
    final tileWidth =
        (MediaQuery.sizeOf(context).width - (kGutter * 2) - (spacing * 2)) / 3;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: kGutter),
      child: Wrap(
        spacing: spacing,
        runSpacing: spacing,
        children: [
          for (final category in shown)
            SizedBox(
              width: tileWidth,
              child: _CategoryTile(
                category: category,
                selected: category.id == selectedId,
                onTap: () => onTap(category),
              ),
            ),
        ],
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.category,
    required this.selected,
    required this.onTap,
  });

  final Category category;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final style = CategoryStyle.of(category.name);
    final borderRadius = BorderRadius.circular(17);

    return Material(
      color: selected ? AppColors.accent : AppColors.card,
      borderRadius: borderRadius,
      child: InkWell(
        onTap: onTap,
        borderRadius: borderRadius,
        child: Container(
          height: 102,
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(
            borderRadius: borderRadius,
            border: Border.all(
              color: selected ? AppColors.accentForeground : AppColors.border,
            ),
          ),
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.card.withValues(alpha: 0.65)
                          : style.color.withValues(alpha: 0.11),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(style.icon, size: 22, color: style.color),
                  ),
                  Text(
                    category.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.5,
                      height: 1.25,
                      fontWeight: FontWeight.w600,
                      color: selected
                          ? AppColors.accentForeground
                          : AppColors.foreground,
                    ),
                  ),
                ],
              ),
              if (selected)
                const Positioned(
                  top: 0,
                  right: 0,
                  child: Icon(
                    Icons.check_circle,
                    size: 17,
                    color: AppColors.accentForeground,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
