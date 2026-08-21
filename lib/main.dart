import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'core/supabase_client.dart';
import 'features/notifications/push_notifications_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initSupabase();
  await Firebase.initializeApp();
  await PushNotificationsService.instance.init(navigatorKey);
  runApp(const InnselfApp());
}
