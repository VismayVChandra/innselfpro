import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/supabase_client.dart';
import '../jobs/jobs_repository.dart';
import '../jobs/screens/job_detail_screen.dart';
import '../profile/profile_repository.dart';

/// Must be a top-level function -- FCM runs it in a separate isolate when
/// a data message arrives while the app is backgrounded/terminated. FCM
/// already renders the system notification for the notification+data
/// payload this app sends; there's nothing else to do until the user
/// taps it, which onMessageOpenedApp/getInitialMessage handle instead.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {}

/// Registers this device's FCM token against the signed-in user, and
/// routes a notification tap to the right job. A thin singleton (not a
/// repository, which this app reserves for Supabase table access) since
/// it also owns FirebaseMessaging listener subscriptions that must
/// survive for the app's lifetime.
class PushNotificationsService {
  PushNotificationsService._();
  static final instance = PushNotificationsService._();

  // A getter, not an eager final field -- FirebaseMessaging.instance
  // itself throws on web (no Firebase.initializeApp() there, see
  // main.dart), and an eager field would evaluate it the moment this
  // singleton is constructed, before any of the kIsWeb guards below get
  // a chance to run.
  FirebaseMessaging get _messaging => FirebaseMessaging.instance;
  final _jobsRepository = JobsRepository();
  final _profileRepository = ProfileRepository();
  GlobalKey<NavigatorState>? _navigatorKey;
  bool _initialized = false;

  /// No-ops entirely on web -- main.dart skips Firebase.initializeApp()
  /// there (web needs explicit FirebaseOptions this app doesn't provide),
  /// so every FirebaseMessaging call below would throw if reached. Push
  /// notifications are an Android-only feature for now; the web build
  /// still gets in-app notifications via Supabase Realtime.
  Future<void> init(GlobalKey<NavigatorState> navigatorKey) async {
    if (kIsWeb) return;
    _navigatorKey = navigatorKey;
    if (_initialized) return;
    _initialized = true;

    await _messaging.requestPermission();
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    _messaging.onTokenRefresh.listen(_saveToken);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleTap);

    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) await _handleTap(initialMessage);
  }

  /// Call once a profile is confirmed loaded (sign-in or sign-up) -- a
  /// no-op if permission was denied or no session exists yet.
  Future<void> registerToken() async {
    if (kIsWeb) return;
    if (supabase.auth.currentUser == null) return;
    final token = await _messaging.getToken();
    if (token != null) await _saveToken(token);
  }

  Future<void> _saveToken(String token) async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return;
    await supabase.from('device_tokens').upsert({
      'user_id': uid,
      'token': token,
      'platform': 'android',
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  /// Deletes this device's token row so a shared phone stops notifying
  /// the previous user. Must be called before AuthRepository.signOut()
  /// clears the session, since deleting the row needs the outgoing
  /// user's auth context to satisfy device_tokens_delete_own.
  Future<void> clearToken() async {
    if (kIsWeb) return;
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return;
    final token = await _messaging.getToken();
    if (token == null) return;
    await supabase
        .from('device_tokens')
        .delete()
        .eq('user_id', uid)
        .eq('token', token);
  }

  Future<void> _handleTap(RemoteMessage message) async {
    final jobId = message.data['job_id'] as String?;
    final navigatorState = _navigatorKey?.currentState;
    if (jobId == null || jobId.isEmpty || navigatorState == null) return;
    try {
      final job = await _jobsRepository.fetchJobById(jobId);
      final viewer = await _profileRepository.fetchMyProfile();
      if (viewer == null) return;
      navigatorState.push(
        MaterialPageRoute(
          builder: (_) => JobDetailScreen(initialJob: job, viewerProfile: viewer),
        ),
      );
    } catch (_) {
      // Job may no longer exist or be visible to this user under RLS --
      // nothing useful to show, so fail silently rather than crash on tap.
    }
  }
}
