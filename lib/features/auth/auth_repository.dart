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
