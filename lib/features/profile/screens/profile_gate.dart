import 'package:flutter/material.dart';

import '../../../core/widgets/states.dart';
import '../../../models/profile.dart';
import '../../notifications/push_notifications_service.dart';
import '../../shell/customer_shell.dart';
import '../../shell/technician_shell.dart';
import '../profile_repository.dart';
import 'role_select_screen.dart';

/// Routes a signed-in user to profile setup (no profiles row yet) or to
/// their role's tab shell. Deliberately state-driven rather than
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
      if (profile != null) {
        PushNotificationsService.instance.registerToken();
      }
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
    PushNotificationsService.instance.registerToken();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: LoadingView()));
    }
    if (_error != null) {
      return Scaffold(
        body: Center(
          child: ErrorView(
            message: 'Could not load your profile: $_error',
            onRetry: () {
              setState(() {
                _loading = true;
                _error = null;
              });
              _load();
            },
          ),
        ),
      );
    }
    final profile = _profile;
    if (profile == null) {
      return RoleSelectScreen(onProfileCreated: _onProfileCreated);
    }
    if (profile.isTechnician) {
      return TechnicianShell(profile: profile);
    }
    return CustomerShell(profile: profile);
  }
}
