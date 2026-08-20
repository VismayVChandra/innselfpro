import 'package:flutter/material.dart';

/// InnSelf design tokens.
///
/// Ported one-to-one from the design prototype's `constants/colors.ts`,
/// plus the handful of literal colours its screens used for the dark
/// hero panels and status accents. Nothing in the app should hardcode a
/// colour that isn't defined here.
abstract final class AppColors {
  // Core surfaces
  static const background = Color(0xFFF7F5F1);
  static const foreground = Color(0xFF10202D);

  // Cards / elevated surfaces
  static const card = Color(0xFFFFFFFF);

  // Primary action colour (buttons, links, active states)
  static const primary = Color(0xFFF0644F);
  static const primaryForeground = Color(0xFFFFFFFF);

  // Secondary / less-emphasis interactive surfaces
  static const secondary = Color(0xFFE8F3EF);
  static const secondaryForeground = Color(0xFF204238);

  // Muted / subdued elements (dividers, timestamps, placeholders)
  static const muted = Color(0xFFECE8E1);
  static const mutedForeground = Color(0xFF6C777B);

  // Accent highlights (badges, selected items)
  static const accent = Color(0xFFB9E6D8);
  static const accentForeground = Color(0xFF204238);

  // Destructive actions (errors, dispute flags)
  static const destructive = Color(0xFFD94B48);
  static const destructiveForeground = Color(0xFFFFFFFF);

  // Borders and input outlines
  static const border = Color(0xFFDEDBD4);

  // Dark panels (hero, job status, technician availability)
  static const panelStart = Color(0xFF122C3B);
  static const panelEnd = Color(0xFF1D4B4B);
  static const panelOnline = Color(0xFF1E514D);
  static const panelGlow = Color(0xFF5BA992);
  static const onPanelKicker = Color(0xFF9FDAC8);
  static const onPanelMuted = Color(0xFFC8DED9);
  static const onPanelFaint = Color(0xFFA9C0BF);

  // Warm CTA used on top of the dark panels
  static const peach = Color(0xFFF7C7A1);

  // Status accents
  static const success = Color(0xFF347461);
  static const successSurface = Color(0xFFE8F3EF);
  static const warnSurface = Color(0xFFF7E5D7);
  static const warn = Color(0xFFB86C4C);
  static const star = Color(0xFFE0A339);

  /// Corner radius the whole system is built on.
  static const double radius = 18;
}

/// Per-category icon + tint, so a job's category reads at a glance in
/// every list, grid and detail header. Falls back gracefully for any
/// category name that isn't in the seeded list.
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
      const CategoryStyle(Icons.home_repair_service_outlined, AppColors.mutedForeground);
}
