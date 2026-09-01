import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Named text styles from the design system. The prototype used Inter at
/// four weights with tight tracking on headings and wide tracking on the
/// small uppercase "eyebrow" labels above them.
///
/// Every field is a getter, not a constant -- each embeds an AppColors
/// color, which is itself dynamic now (see app_colors.dart), so none of
/// these can be `const` any more either.
abstract final class AppText {
  static const _family = 'Inter';

  /// Small uppercase label that sits above a screen or card title.
  static TextStyle get eyebrow => TextStyle(
        fontFamily: _family,
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.4,
        color: AppColors.mutedForeground,
      );

  /// Large screen title ("Activity", "Hi, Vismay").
  static TextStyle get display => TextStyle(
        fontFamily: _family,
        fontSize: 28,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.6,
        color: AppColors.foreground,
      );

  /// Title on a pushed screen's top bar.
  static TextStyle get pageTitle => TextStyle(
        fontFamily: _family,
        fontSize: 19,
        fontWeight: FontWeight.w700,
        color: AppColors.foreground,
      );

  /// Section heading within a scroll view.
  static TextStyle get section => TextStyle(
        fontFamily: _family,
        fontSize: 16,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
        color: AppColors.foreground,
      );

  /// Form field label.
  static TextStyle get fieldLabel => TextStyle(
        fontFamily: _family,
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: AppColors.foreground,
      );

  /// Card title.
  static TextStyle get cardTitle => TextStyle(
        fontFamily: _family,
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: AppColors.foreground,
      );

  /// Slightly larger card title, used where a card is the focus.
  static TextStyle get cardTitleLarge => TextStyle(
        fontFamily: _family,
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: AppColors.foreground,
      );

  /// Body copy inside cards.
  static TextStyle get body => TextStyle(
        fontFamily: _family,
        fontSize: 12,
        fontWeight: FontWeight.w400,
        height: 1.45,
        color: AppColors.foreground,
      );

  /// Secondary copy inside cards.
  static TextStyle get bodyMuted => TextStyle(
        fontFamily: _family,
        fontSize: 11,
        fontWeight: FontWeight.w400,
        height: 1.45,
        color: AppColors.mutedForeground,
      );

  /// Emphasised small text (meta rows, chips, inline links).
  static TextStyle get meta => TextStyle(
        fontFamily: _family,
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: AppColors.mutedForeground,
      );

  /// Tiny all-caps label inside a card (STATUS, QUOTE, ...).
  static TextStyle get microLabel => TextStyle(
        fontFamily: _family,
        fontSize: 9,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
        color: AppColors.mutedForeground,
      );

  /// Money and other headline numbers.
  static TextStyle get amount => TextStyle(
        fontFamily: _family,
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: AppColors.foreground,
      );

  /// Label on a filled action button. No AppColors reference (the
  /// button theme supplies the color) -- kept const, nothing here needs
  /// to change with the mode.
  static const button = TextStyle(
    fontFamily: _family,
    fontSize: 14,
    fontWeight: FontWeight.w700,
  );
}
