import '../../core/supabase_client.dart';
import '../../models/admin_dispute.dart';
import '../../models/kyc_submission.dart';
import '../../models/user_report.dart';

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

  /// Short-lived signed URL for a private technician-kyc object --
  /// createSignedUrl still runs under storage RLS, so this only
  /// resolves at all because of the technician_kyc_select_admin policy
  /// (migration 016). Expires in 10 minutes; call again to view again.
  Future<String> getKycDocumentUrl(String path) async {
    final result =
        await supabase.storage.from('technician-kyc').createSignedUrl(path, 600);
    return result;
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

  Future<List<UserReport>> fetchReports({String? status}) async {
    final rows = await supabase.rpc('admin_list_reports', params: {'p_status': status});
    return ((rows ?? []) as List)
        .map((e) => UserReport.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  /// user_reports_update_admin (migration 016) is the policy that
  /// allows this -- same shape as closeDispute.
  Future<void> resolveReport(String reportId) async {
    await supabase.from('user_reports').update({'status': 'reviewed'}).eq('id', reportId);
  }
}
