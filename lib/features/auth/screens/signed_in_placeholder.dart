import 'package:flutter/material.dart';

import '../auth_repository.dart';

/// Temporary landing screen for Stage 1 (auth) testing.
/// Replaced by the real profile-aware home screen in Stage 2.
class SignedInPlaceholder extends StatelessWidget {
  const SignedInPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    final email = AuthRepository().currentUser?.email ?? 'unknown';
    return Scaffold(
      appBar: AppBar(title: const Text('Innself')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Signed in as $email'),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () => AuthRepository().signOut(),
              child: const Text('Sign out'),
            ),
          ],
        ),
      ),
    );
  }
}
