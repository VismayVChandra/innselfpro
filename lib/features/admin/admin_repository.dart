import '../../core/supabase_client.dart';
import '../../models/admin_dispute.dart';
import '../../models/kyc_submission.dart';

/// Everything the hidden admin surface needs. Every call here goes
/// through a SECURITY DEFINER function that re-checks is_admin()
/// server-side (migration 015) -- reaching this repository at all
/// requires [amIAdmin] to have returned true, but that check is a UI
/// convenience, never the thing that actually authorises the read.
class AdminRepository {
  Future<bool> amIAdmin() async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return false;
    final result = await supabase.rpc('is_admin', params: {'p_user_id': uid});
    return result as bool? ?? false;
  }

  /// [status] null means every submission regardless of state.
  Future<List<KycSubmission>> fetchKycSubmissions({String? status}) async {
    final rows = await supabase.rpc('admin_list_kyc', params: {'p_status': status});
    return ((rows ?? []) as List)
        .map((e) => KycSubmission.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  /// Approving flips profiles.is_verified via the sync trigger, which is
  /// what actually puts the badge in front of customers.
  Future<void> setKycStatus({
    required String profileId,
    required String status,
    String? reason,
  }) async {
    await supabase.rpc('admin_set_kyc_status', params: {
      'p_profile_id': profileId,
      'p_status': status,
      'p_reason': reason,
    });
  }

  Future<List<AdminDispute>> fetchDisputes({String? status}) async {
    final rows = await supabase.rpc('admin_list_disputes', params: {'p_status': status});
    return ((rows ?? []) as List)
        .map((e) => AdminDispute.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  /// Closing a dispute is a plain update -- disputes_update_admin
  /// (migration 015) is the policy that allows it.
  Future<void> closeDispute(String disputeId) async {
    await supabase.from('disputes').update({'status': 'closed'}).eq('id', disputeId);
  }
}
