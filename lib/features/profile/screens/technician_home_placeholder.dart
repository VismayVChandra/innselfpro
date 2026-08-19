import 'package:flutter/material.dart';

import '../../../models/profile.dart';
import '../../auth/auth_repository.dart';

/// Temporary landing screen for Stage 2 (profiles) testing.
/// Replaced by the real job feed / accepted jobs / wallet home in later stages.
class TechnicianHomePlaceholder extends StatelessWidget {
  const TechnicianHomePlaceholder({super.key, required this.profile});

  final Profile profile;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Innself - Technician')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Welcome, ${profile.fullName}'),
            const SizedBox(height: 8),
            Text('Phone: ${profile.phone}'),
            if (profile.address != null && profile.address!.isNotEmpty)
              Text('Address: ${profile.address}'),
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
