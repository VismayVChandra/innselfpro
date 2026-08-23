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

  /// Sends a recovery email whose link opens this app directly (see the
  /// intent-filter for the innself://reset-callback scheme in
  /// AndroidManifest.xml) rather than a dead web redirect -- unlike
  /// signup confirmation, changing a password is a client-side action
  /// that can't complete before the redirect fires, so this genuinely
  /// needs deep linking rather than being able to lean on the emailed
  /// link alone.
  Future<void> resetPasswordForEmail(String email) {
    return supabase.auth.resetPasswordForEmail(
      email,
      redirectTo: 'innself://reset-callback',
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
