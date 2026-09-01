import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import 'layout.dart';

/// Full-width coral call to action with a trailing arrow, and a spinner
/// that replaces the label while the action is in flight.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.icon = Icons.arrow_forward,
    this.margin = const EdgeInsets.symmetric(horizontal: kGutter),
    this.color,
    this.foreground,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;
  final EdgeInsets margin;

  /// Null means AppColors.primary/primaryForeground -- can't be the
  /// default value directly, since that's no longer a compile-time
  /// constant.
  final Color? color;
  final Color? foreground;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !isLoading;
    final resolvedColor = color ?? AppColors.primary;
    final resolvedForeground = foreground ?? AppColors.primaryForeground;
    return Padding(
      padding: margin,
      child: SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: enabled ? onPressed : null,
          style: FilledButton.styleFrom(
            backgroundColor: resolvedColor,
            foregroundColor: resolvedForeground,
            disabledBackgroundColor: AppColors.muted,
            disabledForegroundColor: AppColors.mutedForeground,
            minimumSize: const Size(0, 54),
            textStyle: AppText.button,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(17),
            ),
          ),
          child: isLoading
              ? SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: resolvedForeground,
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(label),
                    if (icon != null) ...[
                      const SizedBox(width: 9),
                      Icon(icon, size: 18),
                    ],
                  ],
                ),
        ),
      ),
    );
  }
}

/// Outlined counterpart to [PrimaryButton]: coral text and border on the
/// page background.
class OutlineButton extends StatelessWidget {
  const OutlineButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.isLoading = false,
    this.color,
    this.margin = const EdgeInsets.symmetric(horizontal: kGutter),
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool isLoading;

  /// Null means AppColors.primary -- see PrimaryButton's [color] for why
  /// this can't be a default parameter value any more.
  final Color? color;
  final EdgeInsets margin;

  @override
  Widget build(BuildContext context) {
    final resolvedColor = color ?? AppColors.primary;
    return Padding(
      padding: margin,
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton(
          onPressed: isLoading ? null : onPressed,
          style: OutlinedButton.styleFrom(
            foregroundColor: resolvedColor,
            side: BorderSide(color: resolvedColor.withValues(alpha: 0.6)),
            minimumSize: const Size(0, 50),
            textStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: isLoading
              ? SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: resolvedColor),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (icon != null) ...[
                      Icon(icon, size: 18),
                      const SizedBox(width: 7),
                    ],
                    Text(label),
                  ],
                ),
        ),
      ),
    );
  }
}

/// Round bordered icon button that sits at the end of a [ScreenHeader].
class CircleIconButton extends StatelessWidget {
  const CircleIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.showDot = false,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final String? tooltip;

  /// Draws the small coral unread marker in the top-right corner.
  final bool showDot;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip ?? '',
      child: SizedBox(
        width: 44,
        height: 44,
        child: Material(
          color: AppColors.card,
          shape: CircleBorder(
            side: BorderSide(color: AppColors.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(icon, size: 21, color: AppColors.foreground),
                if (showDot)
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.primary,
                        border: Border.all(color: AppColors.card),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Selectable chip used for category grids and filter rows.
class ChoicePill extends StatelessWidget {
  const ChoicePill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
        decoration: BoxDecoration(
          color: selected ? AppColors.foreground : AppColors.card,
          border: Border.all(
            color: selected ? AppColors.foreground : AppColors.border,
          ),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected ? AppColors.background : AppColors.foreground,
          ),
        ),
      ),
    );
  }
}
