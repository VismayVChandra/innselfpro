import 'package:flutter/material.dart';

import '../../../models/profile.dart';
import '../../jobs/screens/customer_home_screen.dart';
import '../../jobs/screens/technician_home_screen.dart';
import '../profile_repository.dart';
import 'role_select_screen.dart';

/// Routes a signed-in user to profile setup (no profiles row yet) or to
/// their role's home screen. Deliberately state-driven rather than
/// Navigator-driven: everything here renders within AuthGate's single
/// route, so signing out (which AuthGate reacts to) always works no
/// matter how deep into this state machine the user is.
class ProfileGate extends StatefulWidget {
  const ProfileGate({super.key});

  @override
  State<ProfileGate> createState() => _ProfileGateState();
}

class _ProfileGateState extends State<ProfileGate> {
  bool _loading = true;
  Object? _error;
  Profile? _profile;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final profile = await ProfileRepository().fetchMyProfile();
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  void _onProfileCreated(Profile profile) {
    setState(() => _profile = profile);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_error != null) {
      return Scaffold(
        body: Center(child: Text('Error loading profile: $_error')),
      );
    }
    final profile = _profile;
    if (profile == null) {
      return RoleSelectScreen(onProfileCreated: _onProfileCreated);
    }
    if (profile.isTechnician) {
      return TechnicianHomeScreen(profile: profile);
    }
    return CustomerHomeScreen(profile: profile);
  }
}
