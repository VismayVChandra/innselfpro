import 'package:flutter/material.dart';

import '../../../core/format.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/widgets/surfaces.dart';

/// Dark identity card at the top of both profile tabs.
class ProfileHeaderCard extends StatelessWidget {
  const ProfileHeaderCard({
    super.key,
    required this.name,
    required this.subtitle,
    required this.roleLabel,
  });

  final String name;
  final String subtitle;
  final String roleLabel;

  @override
  Widget build(BuildContext context) {
    return DarkPanel(
      radius: 22,
      padding: const EdgeInsets.all(18),
      showGlow: false,
      solidColor: AppColors.panelStart,
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.peach,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Text(
              initialsOf(name),
              style: const TextStyle(
                color: AppColors.panelStart,
                fontSize: 19,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.onPanelFaint,
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Text(
              roleLabel.toUpperCase(),
              style: const TextStyle(
                color: AppColors.onPanelKicker,
                fontSize: 8.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One row in a profile list: icon tile, label, sub-line, and either a
/// chevron (when tappable) or nothing.
class SettingsRow extends StatelessWidget {
  const SettingsRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
    this.trailing,
    this.iconColor = AppColors.accentForeground,
    this.iconBackground = AppColors.secondary,
    this.labelColor = AppColors.foreground,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;
  final Widget? trailing;
  final Color iconColor;
  final Color iconBackground;
  final Color labelColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: AppCard(
        onTap: onTap,
        radius: 18,
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            SoftIcon(
              icon,
              size: 39,
              iconSize: 19,
              background: iconBackground,
              foreground: iconColor,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: AppText.cardTitle.copyWith(
                      fontSize: 12.5,
                      color: labelColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    maxLines: 2,
                    style: AppText.bodyMuted.copyWith(fontSize: 10.5),
                  ),
                ],
              ),
            ),
            if (trailing != null)
              trailing!
            else if (onTap != null)
              const Icon(
                Icons.chevron_right,
                size: 18,
                color: AppColors.mutedForeground,
              ),
          ],
        ),
      ),
    );
  }
}
