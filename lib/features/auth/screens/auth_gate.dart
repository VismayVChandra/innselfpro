import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase_client.dart';
import '../auth_repository.dart';
import 'login_screen.dart';
import 'signed_in_placeholder.dart';

/// Routes between the auth screens and the signed-in area based on the
/// current Supabase session. The signed-in destination is a placeholder
/// until Stage 2 (profiles) adds the real home screen.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: AuthRepository().authStateChanges,
      builder: (context, snapshot) {
        final session = supabase.auth.currentSession;
        if (session != null) {
          return const SignedInPlaceholder();
        }
        return const LoginScreen();
      },
    );
  }
}
