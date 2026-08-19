import 'package:flutter/material.dart';

import '../../../models/profile.dart';
import 'customer_profile_setup_screen.dart';
import 'technician_profile_setup_screen.dart';

/// Shown once, right after signup, before a profiles row exists.
class RoleSelectScreen extends StatelessWidget {
  const RoleSelectScreen({super.key, required this.onProfileCreated});

  final ValueChanged<Profile> onProfileCreated;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'How will you use Innself?',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 32),
                FilledButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => CustomerProfileSetupScreen(
                        onProfileCreated: onProfileCreated,
                      ),
                    ),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text("I'm a Customer"),
                  ),
                ),
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => TechnicianProfileSetupScreen(
                        onProfileCreated: onProfileCreated,
                      ),
                    ),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text("I'm a Technician"),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
