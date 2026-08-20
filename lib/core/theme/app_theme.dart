import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';
import 'app_text.dart';

/// Wires the design tokens into Flutter's own widgets, so anything the
/// app doesn't draw by hand -- text fields, dialogs, snack bars, the
/// text selection handles -- still lands inside the design system.
abstract final class AppTheme {
  static ThemeData build() {
    const scheme = ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.primary,
      onPrimary: AppColors.primaryForeground,
      primaryContainer: AppColors.accent,
      onPrimaryContainer: AppColors.accentForeground,
      secondary: AppColors.accentForeground,
      onSecondary: AppColors.primaryForeground,
      secondaryContainer: AppColors.secondary,
      onSecondaryContainer: AppColors.secondaryForeground,
      error: AppColors.destructive,
      onError: AppColors.destructiveForeground,
      surface: AppColors.background,
      onSurface: AppColors.foreground,
      surfaceContainerHighest: AppColors.muted,
      onSurfaceVariant: AppColors.mutedForeground,
      outline: AppColors.border,
      outlineVariant: AppColors.border,
    );

    const inputBorderRadius = BorderRadius.all(Radius.circular(17));

    OutlineInputBorder inputBorder(Color color, double width) =>
        OutlineInputBorder(
          borderRadius: inputBorderRadius,
          borderSide: BorderSide(color: color, width: width),
        );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: 'Inter',
      scaffoldBackgroundColor: AppColors.background,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        foregroundColor: AppColors.foreground,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: AppText.pageTitle,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
        space: 1,
      ),
      cardTheme: CardThemeData(
        color: AppColors.card,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppColors.radius),
          side: const BorderSide(color: AppColors.border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.card,
        contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
        border: inputBorder(AppColors.border, 1),
        enabledBorder: inputBorder(AppColors.border, 1),
        focusedBorder: inputBorder(AppColors.primary, 1.6),
        errorBorder: inputBorder(AppColors.destructive, 1),
        focusedErrorBorder: inputBorder(AppColors.destructive, 1.6),
        labelStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: AppColors.mutedForeground,
        ),
        floatingLabelStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.primary,
        ),
        hintStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w400,
          color: AppColors.mutedForeground,
        ),
        errorStyle: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: AppColors.destructive,
        ),
      ),
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: AppColors.primary,
        selectionColor: AppColors.accent,
        selectionHandleColor: AppColors.primary,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.primaryForeground,
          disabledBackgroundColor: AppColors.muted,
          disabledForegroundColor: AppColors.mutedForeground,
          minimumSize: const Size(0, 52),
          textStyle: AppText.button,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(17)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.foreground,
          minimumSize: const Size(0, 50),
          side: const BorderSide(color: AppColors.border),
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ),
      iconTheme: const IconThemeData(color: AppColors.foreground),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primary,
        linearTrackColor: AppColors.muted,
        circularTrackColor: Colors.transparent,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.secondary,
        side: BorderSide.none,
        labelStyle: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppColors.secondaryForeground,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        titleTextStyle: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: AppColors.foreground,
        ),
        contentTextStyle: AppText.body,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.foreground,
        contentTextStyle: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 12.5,
          fontWeight: FontWeight.w500,
          color: AppColors.background,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        insetPadding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.accentForeground
              : AppColors.card,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.accent
              : AppColors.muted,
        ),
        trackOutlineColor: const WidgetStatePropertyAll(AppColors.border),
      ),
      textTheme: const TextTheme(
        headlineMedium: AppText.display,
        headlineSmall: AppText.pageTitle,
        titleMedium: AppText.section,
        titleSmall: AppText.cardTitle,
        bodyMedium: AppText.body,
        bodySmall: AppText.bodyMuted,
        labelSmall: AppText.microLabel,
      ),
    );
  }
}
