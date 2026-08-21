import 'package:firebase_messaging/firebase_messaging.dart';
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

  final _messaging = FirebaseMessaging.instance;
  final _jobsRepository = JobsRepository();
  final _profileRepository = ProfileRepository();
  GlobalKey<NavigatorState>? _navigatorKey;
  bool _initialized = false;

  Future<void> init(GlobalKey<NavigatorState> navigatorKey) async {
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
