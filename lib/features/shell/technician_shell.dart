import 'package:flutter/material.dart';

import '../../models/profile.dart';
import '../jobs/screens/technician_accepted_jobs_screen.dart';
import '../jobs/screens/technician_home_screen.dart';
import '../profile/screens/technician_profile_screen.dart';
import 'app_bottom_nav.dart';
import 'refresh_signal.dart';

/// Tab shell for a signed-in technician: the open job feed, the jobs
/// they've won, and their account. Same state-driven approach as
/// [CustomerShell].
class TechnicianShell extends StatefulWidget {
  const TechnicianShell({super.key, required this.profile});

  final Profile profile;

  @override
  State<TechnicianShell> createState() => _TechnicianShellState();
}

class _TechnicianShellState extends State<TechnicianShell> {
  final _refreshSignal = RefreshSignal();
  int _index = 0;
  late Profile _profile = widget.profile;

  @override
  void dispose() {
    _refreshSignal.dispose();
    super.dispose();
  }

  void _select(int index) => setState(() => _index = index);

  @override
  Widget build(BuildContext context) {
    return RefreshScope(
      signal: _refreshSignal,
      child: Scaffold(
        body: IndexedStack(
          index: _index,
          children: [
            TechnicianHomeScreen(profile: _profile, onOpenTab: _select),
            TechnicianAcceptedJobsScreen(profile: _profile),
            TechnicianProfileScreen(
              profile: _profile,
              onProfileUpdated: (p) => setState(() => _profile = p),
            ),
          ],
        ),
        bottomNavigationBar: AppBottomNav(
          currentIndex: _index,
          onSelected: _select,
          destinations: const [
            NavDestination(
              icon: Icons.grid_view_outlined,
              activeIcon: Icons.grid_view_rounded,
              label: 'Feed',
            ),
            NavDestination(
              icon: Icons.work_outline_rounded,
              activeIcon: Icons.work_rounded,
              label: 'My Jobs',
            ),
            NavDestination(
              icon: Icons.person_outline_rounded,
              activeIcon: Icons.person_rounded,
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}
