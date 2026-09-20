import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_controller.dart';
import 'features/auth/screens/auth_gate.dart';

/// Every screen in this app was designed for a single phone-width column,
/// never a wide viewport -- there's no per-screen desktop layout. Rather
/// than redesign ~30 screens, cap content to a phone-like width and
/// center it on anything wider, the way WhatsApp Web/Twitter's mobile
/// site degrade on desktop. Web-only: on an actual phone (native app or
/// a phone-width mobile browser) the screen is already under maxWidth,
/// so this is a no-op there -- and gating it to web avoids touching the
/// already-shipped, already-reviewed Android app's behavior at all,
/// including on wide-screen tablets/foldables where this letterboxing
/// would be an actual visual change, not a no-op.
class _ResponsiveShell extends StatelessWidget {
  const _ResponsiveShell({required this.child});

  final Widget? child;

  static const _maxWidth = 480.0;

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb || child == null) return child ?? const SizedBox.shrink();
    return ColoredBox(
      color: AppColors.muted,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _maxWidth),
          child: ColoredBox(color: AppColors.background, child: child),
        ),
      ),
    );
  }
}

/// Lets PushNotificationsService push a screen (e.g. from a notification
/// tap) without a BuildContext of its own.
final navigatorKey = GlobalKey<NavigatorState>();

class InnselfApp extends StatelessWidget {
  const InnselfApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Rebuilds this whole subtree -- MaterialApp included -- on every
    // light/dark change. AppColors' getters and AppTheme.build() both
    // read ThemeController fresh, so a plain rebuild from here is
    // enough for every non-const widget in the tree to pick up the new
    // palette; nothing below needs its own listener. `home` has to stay
    // a fresh (non-const) instance each time too -- a `const AuthGate()`
    // would be `identical()` to the previous one, and Flutter's element
    // diffing skips rebuilding a child entirely when the new widget is
    // identical to the old one, which would silently stop this rebuild
    // from ever reaching AuthGate and everything below it.
    return ListenableBuilder(
      listenable: ThemeController.instance,
      builder: (context, _) => MaterialApp(
        navigatorKey: navigatorKey,
        title: 'InnSelf',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.build(),
        home: AuthGate(),
        builder: (context, child) => _ResponsiveShell(child: child),
      ),
    );
  }
}
