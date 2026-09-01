import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Single source of truth for light/dark mode. AppColors' getters and
/// MaterialApp's own `themeMode` both read this, so hand-rolled widgets
/// (via AppColors) and Flutter's native ones (via Theme.of(context))
/// never disagree about which mode is active.
///
/// A ChangeNotifier rather than routing through InheritedWidget/
/// Theme.of(context): AppColors is used from hundreds of places that
/// aren't widgets (or don't have a BuildContext handy), so it needs a
/// plain static read, not a context lookup. Every screen still reacts
/// correctly because [InnselfApp] rebuilds its entire subtree from the
/// root on every change (see app.dart) -- non-const widgets re-read
/// AppColors fresh on every build.
class ThemeController extends ChangeNotifier {
  ThemeController._();
  static final instance = ThemeController._();

  static const _prefsKey = 'theme_mode';

  ThemeMode _mode = ThemeMode.system;
  ThemeMode get mode => _mode;

  /// Resolves ThemeMode.system against the actual platform setting --
  /// needed because AppColors reads this directly, with no
  /// MediaQuery/Theme.of(context) available to resolve it for us.
  bool get isDark {
    if (_mode == ThemeMode.dark) return true;
    if (_mode == ThemeMode.light) return false;
    return SchedulerBinding.instance.platformDispatcher.platformBrightness == Brightness.dark;
  }

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefsKey);
    _mode = switch (saved) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
    // Repaints if the OS-level setting flips while on "system" -- the
    // getter above already handles this on every read, but nothing
    // would otherwise tell the app's rebuilt-from-root tree to redraw.
    SchedulerBinding.instance.platformDispatcher.onPlatformBrightnessChanged = () {
      if (_mode == ThemeMode.system) notifyListeners();
    };
    notifyListeners();
  }

  Future<void> setMode(ThemeMode mode) async {
    if (_mode == mode) return;
    _mode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, mode.name);
  }
}
