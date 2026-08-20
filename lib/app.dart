import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'features/auth/screens/auth_gate.dart';

class InnselfApp extends StatelessWidget {
  const InnselfApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'InnSelf',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.build(),
      home: const AuthGate(),
    );
  }
}
