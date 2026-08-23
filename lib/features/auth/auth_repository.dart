import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase_client.dart';
import '../notifications/push_notifications_service.dart';

class AuthRepository {
  Future<AuthResponse> signUp({
    required String email,
    required String password,
  }) {
    return supabase.auth.signUp(email: email, password: password);
  }

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) {
    return supabase.auth.signInWithPassword(email: email, password: password);
  }

  /// Confirms a signup using the 6-digit code from the confirmation
  /// email (the {{ .Token }} template variable) instead of the emailed
  /// link -- sidesteps needing a working web redirect target for a
  /// native-only app. Signs the user in on success, same as clicking
  /// the link would.
  Future<AuthResponse> verifySignupOtp({
    required String email,
    required String token,
  }) {
    return supabase.auth.verifyOTP(type: OtpType.signup, token: token, email: email);
  }

  Future<void> resendSignupOtp({required String email}) {
    return supabase.auth.resend(type: OtpType.signup, email: email);
  }

  /// Sends a recovery email pointing at a real hosted page
  /// (docs/reset-callback.html) rather than straight at the
  /// innself://reset-callback scheme -- Gmail wraps every link through
  /// its own google.com/url?q=... redirector before forwarding it, and
  /// that wrapper doesn't reliably carry a server-side redirect through
  /// to a non-http(s) scheme (confirmed live: the request succeeds on
  /// Supabase's side, 303, but the phone never leaves the wrapper). A
  /// real page loads fine through the wrapper and then hands off to the
  /// app itself via a visible button, which mobile browsers allow much
  /// more reliably than a bare cross-scheme redirect.
  Future<void> resetPasswordForEmail(String email) {
    return supabase.auth.resetPasswordForEmail(
      email,
      redirectTo: 'https://vismayvchandra.github.io/innselfpro/reset-callback.html',
    );
  }

  /// Sets a new password for the session the recovery deep link just
  /// established. Only valid to call right after an
  /// AuthChangeEvent.passwordRecovery event.
  Future<void> updatePassword(String newPassword) {
    return supabase.auth.updateUser(UserAttributes(password: newPassword));
  }

  /// Clears this device's push token first -- otherwise a shared phone
  /// keeps notifying whoever just signed out.
  Future<void> signOut() async {
    await PushNotificationsService.instance.clearToken();
    await supabase.auth.signOut();
  }

  /// Calls the delete-account Edge Function, which either hard-deletes a
  /// clean account or anonymizes one with history (see the function's
  /// own comment for why). Does not sign out on success -- the caller
  /// should do that once this returns, since the server-side ban doesn't
  /// necessarily invalidate an already-issued client token immediately.
  Future<void> deleteAccount() async {
    final res = await supabase.functions.invoke('delete-account');
    if (res.status != 200) {
      final error = (res.data is Map) ? res.data['error'] : null;
      throw Exception(error ?? 'Failed to delete account (status ${res.status})');
    }
  }

  User? get currentUser => supabase.auth.currentUser;

  Stream<AuthState> get authStateChanges => supabase.auth.onAuthStateChange;
}
