import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import 'layout.dart';

/// White card with the system border and radius. The workhorse surface.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin = const EdgeInsets.symmetric(horizontal: kGutter),
    this.onTap,
    this.radius = 20,
    this.borderColor,
    this.borderWidth = 1,
    this.color = AppColors.card,
  });

  final Widget child;
  final EdgeInsets padding;
  final EdgeInsets margin;
  final VoidCallback? onTap;
  final double radius;
  final Color? borderColor;
  final double borderWidth;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(radius);
    return Padding(
      padding: margin,
      child: Material(
        color: color,
        borderRadius: borderRadius,
        child: InkWell(
          onTap: onTap,
          borderRadius: borderRadius,
          splashColor: AppColors.muted.withValues(alpha: 0.5),
          highlightColor: AppColors.muted.withValues(alpha: 0.3),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              borderRadius: borderRadius,
              border: Border.all(
                color: borderColor ?? AppColors.border,
                width: borderWidth,
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Rounded-square tinted icon tile that leads most rows and cards.
class SoftIcon extends StatelessWidget {
  const SoftIcon(
    this.icon, {
    super.key,
    this.background = AppColors.secondary,
    this.foreground = AppColors.accentForeground,
    this.size = 40,
    this.iconSize = 20,
  });

  /// Tints the tile from a category/accent colour at the same low opacity
  /// the prototype used for its service grid.
  factory SoftIcon.tinted(
    IconData icon, {
    required Color color,
    double size = 40,
    double iconSize = 20,
  }) =>
      SoftIcon(
        icon,
        background: color.withValues(alpha: 0.11),
        foreground: color,
        size: size,
        iconSize: iconSize,
      );

  final IconData icon;
  final Color background;
  final Color foreground;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(size * 0.34),
      ),
      child: Icon(icon, size: iconSize, color: foreground),
    );
  }
}

/// The deep teal panel the design leans on for anything "live": the home
/// hero, a job's status, a technician's availability.
class DarkPanel extends StatelessWidget {
  const DarkPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(22),
    this.margin = const EdgeInsets.symmetric(horizontal: kGutter),
    this.radius = 26,
    this.minHeight = 0,
    this.solidColor,
    this.showGlow = true,
  });

  final Widget child;
  final EdgeInsets padding;
  final EdgeInsets margin;
  final double radius;
  final double minHeight;

  /// When set, the panel is a flat colour instead of the gradient.
  final Color? solidColor;
  final bool showGlow;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: margin,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Container(
          constraints: BoxConstraints(minHeight: minHeight),
          decoration: BoxDecoration(
            color: solidColor,
            gradient: solidColor != null
                ? null
                : const LinearGradient(
                    colors: [AppColors.panelStart, AppColors.panelEnd],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
          ),
          child: Stack(
            children: [
              if (showGlow)
                Positioned(
                  right: -55,
                  top: -60,
                  child: Container(
                    width: 210,
                    height: 210,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          AppColors.panelGlow.withValues(alpha: 0.30),
                          AppColors.panelGlow.withValues(alpha: 0.0),
                        ],
                        stops: const [0.35, 1],
                      ),
                    ),
                  ),
                ),
              Padding(padding: padding, child: child),
            ],
          ),
        ),
      ),
    );
  }
}

/// Dashed-border card used where a list would otherwise be empty.
class EmptyStateCard extends StatelessWidget {
  const EmptyStateCard({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String message;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: kGutter),
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: CustomPaint(
          painter: _DashedBorderPainter(radius: 22),
          child: Padding(
            padding: const EdgeInsets.all(17),
            child: Row(
              children: [
                SoftIcon(icon, size: 42, iconSize: 22),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: AppText.cardTitle),
                      const SizedBox(height: 4),
                      Text(message, style: AppText.bodyMuted),
                    ],
                  ),
                ),
                if (onTap != null)
                  const Icon(
                    Icons.chevron_right,
                    size: 19,
                    color: AppColors.mutedForeground,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({required this.radius});

  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.border
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Offset.zero & size,
          Radius.circular(radius),
        ),
      );
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = (distance + 6).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance = next + 5;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter oldDelegate) =>
      oldDelegate.radius != radius;
}

/// One cell of the three-across stat row (earnings, rating, jobs done).
class StatTile extends StatelessWidget {
  const StatTile({super.key, required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: AppColors.card,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.foreground,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              label,
              style: const TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w400,
                color: AppColors.mutedForeground,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Row of five stars, read-only or tappable.
class StarRow extends StatelessWidget {
  const StarRow({
    super.key,
    required this.rating,
    this.size = 18,
    this.onChanged,
  });

  final int rating;
  final double size;
  final ValueChanged<int>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final icon = Icon(
          i < rating ? Icons.star_rounded : Icons.star_border_rounded,
          color: AppColors.star,
          size: onChanged == null ? size : size + 12,
        );
        if (onChanged == null) return icon;
        return GestureDetector(
          onTap: () => onChanged!(i + 1),
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.only(right: 4),
            child: icon,
          ),
        );
      }),
    );
  }
}
