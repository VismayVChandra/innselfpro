import '../../core/supabase_client.dart';
import '../../models/dispute.dart';

class DisputesRepository {
  Future<Dispute?> fetchDisputeForJob(String jobId) async {
    final data =
        await supabase.from('disputes').select().eq('job_id', jobId).maybeSingle();
    if (data == null) return null;
    return Dispute.fromMap(data);
  }

  Future<void> flagJob({required String jobId, required String reason}) async {
    final uid = supabase.auth.currentUser!.id;
    await supabase.from('disputes').insert({
      'job_id': jobId,
      'flagged_by': uid,
      'reason': reason,
    });
  }
}
