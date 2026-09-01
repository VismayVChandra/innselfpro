import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'core/theme/theme_controller.dart';
import 'features/auth/screens/auth_gate.dart';

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
      ),
    );
  }
}
