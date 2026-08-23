import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase_client.dart';
import '../../profile/screens/profile_gate.dart';
import '../auth_repository.dart';
import 'login_screen.dart';
import 'reset_password_screen.dart';

/// Routes between the auth screens and the signed-in area based on the
/// current Supabase session. A recovery session (from tapping the
/// password reset link) is deliberately NOT treated as an ordinary
/// sign-in -- previously this fell through to the currentSession != null
/// check below and skipped straight into the app, silently leaving the
/// user "signed in" via the old password with no chance to set a new
/// one. Checking the stream's own event here (rather than main.dart
/// pushing a route via navigatorKey) also removes a startup race: this
/// StreamBuilder subscribes the moment AuthGate is first built, with no
/// dependency on a Navigator having attached yet.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: AuthRepository().authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.data?.event == AuthChangeEvent.passwordRecovery) {
          return const ResetPasswordScreen();
        }
        final session = supabase.auth.currentSession;
        if (session != null) {
          return const ProfileGate();
        }
        return const LoginScreen();
      },
    );
  }
}
