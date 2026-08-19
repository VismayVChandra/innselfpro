import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase_client.dart';
import '../../profile/screens/profile_gate.dart';
import '../auth_repository.dart';
import 'login_screen.dart';

/// Routes between the auth screens and the signed-in area based on the
/// current Supabase session.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: AuthRepository().authStateChanges,
      builder: (context, snapshot) {
        final session = supabase.auth.currentSession;
        if (session != null) {
          return const ProfileGate();
        }
        return const LoginScreen();
      },
    );
  }
}
