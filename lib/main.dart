import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/supabase_client.dart';
import 'features/auth/screens/reset_password_screen.dart';
import 'features/notifications/push_notifications_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initSupabase();
  await Firebase.initializeApp();
  await PushNotificationsService.instance.init(navigatorKey);

  // supabase_flutter already watches for the innself://reset-callback
  // deep link (via its bundled app_links dependency) and exchanges it
  // for a session on its own -- this just reacts to that by pushing the
  // screen that actually sets the new password.
  supabase.auth.onAuthStateChange.listen((data) {
    if (data.event == AuthChangeEvent.passwordRecovery) {
      navigatorKey.currentState?.push(
        MaterialPageRoute(builder: (_) => const ResetPasswordScreen()),
      );
    }
  });

  runApp(const InnselfApp());
}
