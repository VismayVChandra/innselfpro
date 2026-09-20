import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'core/supabase_client.dart';
import 'core/theme/theme_controller.dart';
import 'features/notifications/push_notifications_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initSupabase();
  // Web has no google-services.json/GoogleService-Info.plist equivalent --
  // Firebase.initializeApp() needs explicit FirebaseOptions there, which
  // this app doesn't provide since push notifications are an Android-only
  // feature for now. PushNotificationsService itself no-ops on web too,
  // so skipping this here just means we don't crash on startup for
  // nothing -- see that class for where the real guard lives.
  if (!kIsWeb) {
    await Firebase.initializeApp();
  }
  await PushNotificationsService.instance.init(navigatorKey);
  await ThemeController.instance.init();

  // supabase_flutter already watches for the innself://reset-callback
  // deep link (via its bundled app_links dependency) and exchanges it
  // for a session on its own. AuthGate reacts to that reactively (it
  // renders ResetPasswordScreen whenever the latest auth event is
  // passwordRecovery) rather than this file pushing a route via
  // navigatorKey -- that avoided a real startup race, since a stream
  // listener registered here could subscribe after the cold-start deep
  // link had already been processed and its one-off event emitted.
  runApp(const InnselfApp());
}
