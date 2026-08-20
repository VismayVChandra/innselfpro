import 'package:flutter/material.dart';

import '../../models/profile.dart';
import '../jobs/screens/customer_activity_screen.dart';
import '../jobs/screens/customer_home_screen.dart';
import '../profile/screens/customer_profile_screen.dart';
import 'app_bottom_nav.dart';
import 'refresh_signal.dart';

/// Tab shell for a signed-in customer.
///
/// Rendered as content inside ProfileGate rather than pushed, so tab
/// switching is plain [setState] with no Navigator involved -- signing
/// out still tears the whole thing down cleanly from AuthGate.
class CustomerShell extends StatefulWidget {
  const CustomerShell({super.key, required this.profile});

  final Profile profile;

  @override
  State<CustomerShell> createState() => _CustomerShellState();
}

class _CustomerShellState extends State<CustomerShell> {
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
            CustomerHomeScreen(profile: _profile, onOpenTab: _select),
            CustomerActivityScreen(profile: _profile),
            CustomerProfileScreen(
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
              icon: Icons.home_outlined,
              activeIcon: Icons.home_rounded,
              label: 'Home',
            ),
            NavDestination(
              icon: Icons.access_time_rounded,
              activeIcon: Icons.history_rounded,
              label: 'Activity',
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
