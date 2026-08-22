import 'package:flutter/material.dart';

import '../../../core/format.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/widgets/layout.dart';
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

/// The customer-facing half of KYC (wave 7.1): a small tick shown
/// wherever a technician is being judged -- bid cards, the contact card,
/// their profile. Absence means "not checked yet", not "suspect", so
/// there's deliberately no counterpart badge for unverified.
class VerifiedBadge extends StatelessWidget {
  const VerifiedBadge({super.key, this.showLabel = false, this.size = 13});

  /// Adds the word "Verified" next to the tick -- worth the space on a
  /// profile header, too noisy in a dense row.
  final bool showLabel;
  final double size;

  @override
  Widget build(BuildContext context) {
    final icon = Icon(Icons.verified_rounded, size: size, color: AppColors.success);
    if (!showLabel) return icon;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        icon,
        const SizedBox(width: 4),
        Text(
          'Verified',
          style: AppText.meta.copyWith(
            color: AppColors.success,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

/// Replaces the old free-text "service area" box (wave 6.1): a base
/// location captured via "use my current location" plus a radius slider
/// -- what actually drives real distance matching now, instead of a
/// spelling-sensitive area name. Shared between technician setup and
/// edit profile, the only two places it appears.
class ServiceRadiusPicker extends StatelessWidget {
  const ServiceRadiusPicker({
    super.key,
    required this.hasLocation,
    required this.isLocating,
    required this.radiusKm,
    required this.onSetLocation,
    required this.onRadiusChanged,
    this.locationLabel,
  });

  final bool hasLocation;
  final bool isLocating;
  final int radiusKm;
  final VoidCallback onSetLocation;
  final ValueChanged<double> onRadiusChanged;

  /// Reverse-geocoded from the captured coordinates, e.g. "Koramangala,
  /// Bangalore" -- purely a readable confirmation of where "here" is,
  /// not something matching actually uses (that's still lat/lng).
  final String? locationLabel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: kGutter),
      child: AppCard(
        margin: EdgeInsets.zero,
        radius: 17,
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SoftIcon(
                  hasLocation ? Icons.my_location_rounded : Icons.location_searching_rounded,
                  background: hasLocation ? AppColors.successSurface : AppColors.secondary,
                  foreground: hasLocation ? AppColors.success : AppColors.accentForeground,
                  size: 39,
                  iconSize: 19,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hasLocation ? (locationLabel ?? 'Base location set') : 'Set your base location',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.cardTitle.copyWith(fontSize: 12.5),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        hasLocation
                            ? 'Jobs are matched by real distance from here.'
                            : 'Needed to match you to nearby jobs by distance.',
                        style: AppText.bodyMuted.copyWith(fontSize: 10.5),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: isLocating ? null : onSetLocation,
                  child: isLocating
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(hasLocation ? 'Update' : 'Set'),
                ),
              ],
            ),
            if (hasLocation) ...[
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 6),
                child: Divider(),
              ),
              Row(
                children: [
                  Text('Service radius', style: AppText.bodyMuted.copyWith(fontSize: 11)),
                  const Spacer(),
                  Text(
                    '$radiusKm km',
                    style: AppText.bodyMuted.copyWith(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: AppColors.primary,
                  thumbColor: AppColors.primary,
                  inactiveTrackColor: AppColors.border,
                ),
                child: Slider(
                  value: radiusKm.toDouble().clamp(5, 50),
                  min: 5,
                  max: 50,
                  divisions: 9,
                  label: '$radiusKm km',
                  onChanged: onRadiusChanged,
                ),
              ),
            ],
          ],
        ),
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
