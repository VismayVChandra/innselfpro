import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Named text styles from the design system. The prototype used Inter at
/// four weights with tight tracking on headings and wide tracking on the
/// small uppercase "eyebrow" labels above them.
abstract final class AppText {
  static const _family = 'Inter';

  /// Small uppercase label that sits above a screen or card title.
  static const eyebrow = TextStyle(
    fontFamily: _family,
    fontSize: 10,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.4,
    color: AppColors.mutedForeground,
  );

  /// Large screen title ("Activity", "Hi, Vismay").
  static const display = TextStyle(
    fontFamily: _family,
    fontSize: 28,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.6,
    color: AppColors.foreground,
  );

  /// Title on a pushed screen's top bar.
  static const pageTitle = TextStyle(
    fontFamily: _family,
    fontSize: 19,
    fontWeight: FontWeight.w700,
    color: AppColors.foreground,
  );

  /// Section heading within a scroll view.
  static const section = TextStyle(
    fontFamily: _family,
    fontSize: 16,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.2,
    color: AppColors.foreground,
  );

  /// Form field label.
  static const fieldLabel = TextStyle(
    fontFamily: _family,
    fontSize: 14,
    fontWeight: FontWeight.w700,
    color: AppColors.foreground,
  );

  /// Card title.
  static const cardTitle = TextStyle(
    fontFamily: _family,
    fontSize: 13,
    fontWeight: FontWeight.w700,
    color: AppColors.foreground,
  );

  /// Slightly larger card title, used where a card is the focus.
  static const cardTitleLarge = TextStyle(
    fontFamily: _family,
    fontSize: 14,
    fontWeight: FontWeight.w700,
    color: AppColors.foreground,
  );

  /// Body copy inside cards.
  static const body = TextStyle(
    fontFamily: _family,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.45,
    color: AppColors.foreground,
  );

  /// Secondary copy inside cards.
  static const bodyMuted = TextStyle(
    fontFamily: _family,
    fontSize: 11,
    fontWeight: FontWeight.w400,
    height: 1.45,
    color: AppColors.mutedForeground,
  );

  /// Emphasised small text (meta rows, chips, inline links).
  static const meta = TextStyle(
    fontFamily: _family,
    fontSize: 11,
    fontWeight: FontWeight.w600,
    color: AppColors.mutedForeground,
  );

  /// Tiny all-caps label inside a card (STATUS, QUOTE, ...).
  static const microLabel = TextStyle(
    fontFamily: _family,
    fontSize: 9,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.8,
    color: AppColors.mutedForeground,
  );

  /// Money and other headline numbers.
  static const amount = TextStyle(
    fontFamily: _family,
    fontSize: 20,
    fontWeight: FontWeight.w700,
    color: AppColors.foreground,
  );

  /// Label on a filled action button.
  static const button = TextStyle(
    fontFamily: _family,
    fontSize: 14,
    fontWeight: FontWeight.w700,
  );
}
