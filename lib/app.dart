import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'features/auth/screens/auth_gate.dart';

/// Lets PushNotificationsService push a screen (e.g. from a notification
/// tap) without a BuildContext of its own.
final navigatorKey = GlobalKey<NavigatorState>();

class InnselfApp extends StatelessWidget {
  const InnselfApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'InnSelf',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.build(),
      home: const AuthGate(),
    );
  }
}
