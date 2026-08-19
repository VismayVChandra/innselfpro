import 'package:flutter/material.dart';

import '../../../models/profile.dart';
import '../profile_repository.dart';
import 'customer_home_placeholder.dart';
import 'role_select_screen.dart';
import 'technician_home_placeholder.dart';

/// Routes a signed-in user to profile setup (no profiles row yet) or to
/// their role's home screen.
class ProfileGate extends StatefulWidget {
  const ProfileGate({super.key});

  @override
  State<ProfileGate> createState() => _ProfileGateState();
}

class _ProfileGateState extends State<ProfileGate> {
  late final Future<Profile?> _profileFuture;

  @override
  void initState() {
    super.initState();
    _profileFuture = ProfileRepository().fetchMyProfile();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Profile?>(
      future: _profileFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(child: Text('Error loading profile: ${snapshot.error}')),
          );
        }
        final profile = snapshot.data;
        if (profile == null) {
          return const RoleSelectScreen();
        }
        if (profile.isTechnician) {
          return TechnicianHomePlaceholder(profile: profile);
        }
        return CustomerHomePlaceholder(profile: profile);
      },
    );
  }
}
