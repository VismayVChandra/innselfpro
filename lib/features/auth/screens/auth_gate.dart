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
          // AuthGate swapping its own content only changes what the
          // FIRST route shows -- it doesn't touch the Navigator stack.
          // If the user is sitting on a pushed screen at this moment
          // (in practice, always ForgotPasswordScreen's "check your
          // email" state, since that's the only path that leads here),
          // it stays on top and fully hides ResetPasswordScreen
          // underneath. Popping back to the first route is what
          // actually surfaces it. Deferred a frame since Navigator
          // methods can't be called during build().
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.of(context).popUntil((route) => route.isFirst);
          });
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
