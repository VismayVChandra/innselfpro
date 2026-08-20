import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/widgets/layout.dart';
import '../../../core/widgets/surfaces.dart';
import '../../../models/profile.dart';
import '../../auth/auth_repository.dart';
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(top: 24, bottom: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(kTextGutter, 0, kTextGutter, 26),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('ONE LAST THING', style: AppText.eyebrow),
                    SizedBox(height: 6),
                    Text('How will you\nuse InnSelf?', style: AppText.display),
                  ],
                ),
              ),
              _RoleCard(
                icon: Icons.home_outlined,
                eyebrow: 'I NEED HELP',
                title: "I'm a Customer",
                message:
                    'Post a job, get bids from local pros, and pay when the work is done.',
                accent: AppColors.accent,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => CustomerProfileSetupScreen(
                      onProfileCreated: onProfileCreated,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 13),
              _RoleCard(
                icon: Icons.handyman_outlined,
                eyebrow: 'I DO THE WORK',
                title: "I'm a Technician",
                message:
                    'Browse open jobs near you, bid on the ones you want, and get paid.',
                accent: AppColors.warnSurface,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => TechnicianProfileSetupScreen(
                      onProfileCreated: onProfileCreated,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              TextButton(
                onPressed: () => AuthRepository().signOut(),
                child: const Text('Sign out'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.icon,
    required this.eyebrow,
    required this.title,
    required this.message,
    required this.accent,
    required this.onTap,
  });

  final IconData icon;
  final String eyebrow;
  final String title;
  final String message;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      radius: 22,
      padding: const EdgeInsets.all(19),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, size: 23, color: AppColors.accentForeground),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      eyebrow,
                      style: AppText.eyebrow.copyWith(fontSize: 9.5),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppColors.foreground,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.north_east,
                size: 18,
                color: AppColors.mutedForeground,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(message, style: AppText.bodyMuted),
        ],
      ),
    );
  }
}
