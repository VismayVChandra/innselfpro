import 'package:flutter/material.dart';

import 'theme_controller.dart';

/// The light palette -- ported one-to-one from the design prototype's
/// `constants/colors.ts`, plus the handful of literal colours its
/// screens used for the dark hero panels and status accents.
abstract final class _Light {
  static const background = Color(0xFFF7F5F1);
  static const foreground = Color(0xFF10202D);
  static const card = Color(0xFFFFFFFF);
  static const primary = Color(0xFFF0644F);
  static const primaryForeground = Color(0xFFFFFFFF);
  static const secondary = Color(0xFFE8F3EF);
  static const secondaryForeground = Color(0xFF204238);
  static const muted = Color(0xFFECE8E1);
  static const mutedForeground = Color(0xFF6C777B);
  static const accent = Color(0xFFB9E6D8);
  static const accentForeground = Color(0xFF204238);
  static const destructive = Color(0xFFD94B48);
  static const destructiveForeground = Color(0xFFFFFFFF);
  static const border = Color(0xFFDEDBD4);
  static const panelStart = Color(0xFF122C3B);
  static const panelEnd = Color(0xFF1D4B4B);
  static const panelOnline = Color(0xFF1E514D);
  static const panelGlow = Color(0xFF5BA992);
  static const onPanelKicker = Color(0xFF9FDAC8);
  static const onPanelMuted = Color(0xFFC8DED9);
  static const onPanelFaint = Color(0xFFA9C0BF);
  static const peach = Color(0xFFF7C7A1);
  static const success = Color(0xFF347461);
  static const successSurface = Color(0xFFE8F3EF);
  static const warnSurface = Color(0xFFF7E5D7);
  static const warn = Color(0xFFB86C4C);
  static const star = Color(0xFFE0A339);
}

/// The dark companion palette. Not a naive inversion -- each token keeps
/// the light palette's *role* (what it communicates) while getting a
/// value that actually reads well on a dark ground: the coral primary
/// brightens so it still pops against navy instead of graying out, the
/// hero panel gets lifted a shade above the page background so it still
/// reads as an elevated surface instead of disappearing into it, and
/// status accents (success/warn/star) brighten for the same reason
/// text does -- low-chroma colours lose most of their contrast once
/// the ground goes dark.
abstract final class _Dark {
  static const background = Color(0xFF0D1B25);
  static const foreground = Color(0xFFF2EFE9);
  static const card = Color(0xFF16262F);
  static const primary = Color(0xFFFF8770);
  static const primaryForeground = Color(0xFF10202D);
  static const secondary = Color(0xFF143229);
  static const secondaryForeground = Color(0xFF9FDAC8);
  static const muted = Color(0xFF1E2E38);
  static const mutedForeground = Color(0xFF93A0A5);
  static const accent = Color(0xFF1F4A3C);
  static const accentForeground = Color(0xFF9FDAC8);
  static const destructive = Color(0xFFFF6B67);
  static const destructiveForeground = Color(0xFF10202D);
  static const border = Color(0xFF28404D);
  static const panelStart = Color(0xFF1B3A4D);
  static const panelEnd = Color(0xFF24605A);
  static const panelOnline = Color(0xFF2A6560);
  static const panelGlow = Color(0xFF6FC2A8);
  static const onPanelKicker = Color(0xFF9FDAC8);
  static const onPanelMuted = Color(0xFFC8DED9);
  static const onPanelFaint = Color(0xFFA9C0BF);
  static const peach = Color(0xFFF7C7A1);
  static const success = Color(0xFF5FBF9D);
  static const successSurface = Color(0xFF143229);
  static const warnSurface = Color(0xFF3A2A1D);
  static const warn = Color(0xFFE0955F);
  static const star = Color(0xFFF0B84D);
}

/// InnSelf design tokens. Every field is a getter, not a constant --
/// each one reads ThemeController.instance.isDark fresh on every call,
/// so nothing here can be used in a `const` context any more. That's
/// deliberate: real light/dark switching means these values genuinely
/// change at runtime, which `const` folding can never allow.
abstract final class AppColors {
  static bool get _dark => ThemeController.instance.isDark;

  static Color get background => _dark ? _Dark.background : _Light.background;
  static Color get foreground => _dark ? _Dark.foreground : _Light.foreground;
  static Color get card => _dark ? _Dark.card : _Light.card;
  static Color get primary => _dark ? _Dark.primary : _Light.primary;
  static Color get primaryForeground => _dark ? _Dark.primaryForeground : _Light.primaryForeground;
  static Color get secondary => _dark ? _Dark.secondary : _Light.secondary;
  static Color get secondaryForeground =>
      _dark ? _Dark.secondaryForeground : _Light.secondaryForeground;
  static Color get muted => _dark ? _Dark.muted : _Light.muted;
  static Color get mutedForeground => _dark ? _Dark.mutedForeground : _Light.mutedForeground;
  static Color get accent => _dark ? _Dark.accent : _Light.accent;
  static Color get accentForeground => _dark ? _Dark.accentForeground : _Light.accentForeground;
  static Color get destructive => _dark ? _Dark.destructive : _Light.destructive;
  static Color get destructiveForeground =>
      _dark ? _Dark.destructiveForeground : _Light.destructiveForeground;
  static Color get border => _dark ? _Dark.border : _Light.border;
  static Color get panelStart => _dark ? _Dark.panelStart : _Light.panelStart;
  static Color get panelEnd => _dark ? _Dark.panelEnd : _Light.panelEnd;
  static Color get panelOnline => _dark ? _Dark.panelOnline : _Light.panelOnline;
  static Color get panelGlow => _dark ? _Dark.panelGlow : _Light.panelGlow;
  static Color get onPanelKicker => _dark ? _Dark.onPanelKicker : _Light.onPanelKicker;
  static Color get onPanelMuted => _dark ? _Dark.onPanelMuted : _Light.onPanelMuted;
  static Color get onPanelFaint => _dark ? _Dark.onPanelFaint : _Light.onPanelFaint;
  static Color get peach => _dark ? _Dark.peach : _Light.peach;
  static Color get success => _dark ? _Dark.success : _Light.success;
  static Color get successSurface => _dark ? _Dark.successSurface : _Light.successSurface;
  static Color get warnSurface => _dark ? _Dark.warnSurface : _Light.warnSurface;
  static Color get warn => _dark ? _Dark.warn : _Light.warn;
  static Color get star => _dark ? _Dark.star : _Light.star;

  /// Corner radius the whole system is built on -- unaffected by theme,
  /// stays a real compile-time constant.
  static const double radius = 18;
}

/// Per-category icon + tint, so a job's category reads at a glance in
/// every list, grid and detail header. Falls back gracefully for any
/// category name that isn't in the seeded list. The hues themselves
/// stay identical in both themes (they're already saturated enough to
/// read on either background) -- only the tinted circle behind each
/// icon (built by the caller via `.withValues(alpha: ...)`) looks
/// different, which resolves for free since it composites over
/// AppColors.card at paint time.
class CategoryStyle {
  const CategoryStyle(this.icon, this.color);

  final IconData icon;
  final Color color;

  static const _styles = <String, CategoryStyle>{
    'Plumber': CategoryStyle(Icons.water_drop_outlined, Color(0xFF4F86C6)),
    'Electrician': CategoryStyle(Icons.bolt_outlined, Color(0xFFE1A73E)),
    'AC Repair': CategoryStyle(Icons.ac_unit_outlined, Color(0xFF6E9FB0)),
    'Cleaning': CategoryStyle(Icons.auto_awesome_outlined, Color(0xFF7D9F83)),
    'Carpenter': CategoryStyle(Icons.handyman_outlined, Color(0xFFBD7954)),
    'Appliance Repair': CategoryStyle(Icons.build_outlined, Color(0xFFA47BB5)),
    'Painter': CategoryStyle(Icons.format_paint_outlined, Color(0xFFC77B8A)),
    'Pest Control': CategoryStyle(Icons.pest_control_outlined, Color(0xFF6F8F6B)),
    'Other': CategoryStyle(Icons.home_repair_service_outlined, Color(0xFF6C777B)),
  };

  static CategoryStyle of(String categoryName) =>
      _styles[categoryName] ??
      CategoryStyle(Icons.home_repair_service_outlined, AppColors.mutedForeground);
}
