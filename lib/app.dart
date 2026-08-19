import 'package:flutter/material.dart';

import 'features/auth/screens/auth_gate.dart';

class InnselfApp extends StatelessWidget {
  const InnselfApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Innself',
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      home: const AuthGate(),
    );
  }
}
