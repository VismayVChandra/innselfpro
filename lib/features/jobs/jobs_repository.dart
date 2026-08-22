import 'dart:io';

import '../../core/supabase_client.dart';
import '../../models/category.dart';
import '../../models/job.dart';

const _jobSelect = '*, categories(name)';

class JobsRepository {
  Future<List<Category>> fetchCategories() async {
    final data = await supabase.from('categories').select().order('name');
    return (data as List)
        .map((e) => Category.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  /// [suffix] keeps concurrent uploads from the same caller from
  /// colliding on the same millisecond-based filename.
  Future<String> _uploadJobPhoto(File file, {String suffix = ''}) async {
    final uid = supabase.auth.currentUser!.id;
    final ext = file.path.split('.').last;
    final path = '$uid/${DateTime.now().millisecondsSinceEpoch}$suffix.$ext';
    await supabase.storage.from('job-photos').upload(path, file);
    return supabase.storage.from('job-photos').getPublicUrl(path);
  }

  Future<void> createJob({
    required int categoryId,
    required String description,
    required String location,
    List<File> photos = const [],
    DateTime? scheduledFor,
    String? invitedTechnicianId,
    String? pincode,
    double? lat,
    double? lng,
  }) async {
    final uid = supabase.auth.currentUser!.id;
    final photoUrls = <String>[];
    for (var i = 0; i < photos.length; i++) {
      photoUrls.add(await _uploadJobPhoto(photos[i], suffix: '_$i'));
    }
    await supabase.from('jobs').insert({
      'customer_id': uid,
      'category_id': categoryId,
      'description': description,
      'location': location,
      'photo_urls': photoUrls.isEmpty ? null : photoUrls,
      'scheduled_for': scheduledFor?.toIso8601String(),
      'invited_technician_id': invitedTechnicianId,
      'pincode': ?pincode,
      'lat': ?lat,
      'lng': ?lng,
    });
  }

  Future<List<Job>> fetchMyJobs() async {
    final uid = supabase.auth.currentUser!.id;
    final data = await supabase
        .from('jobs')
        .select(_jobSelect)
        .eq('customer_id', uid)
        .order('created_at', ascending: false);
    return (data as List)
        .map((e) => Job.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  /// Every open job this caller's RLS lets them see, live. A technician
  /// only ever sees: jobs with no invited_technician_id, plus any job
  /// invited to them specifically (jobs_select, migration 008) -- so
  /// this single stream covers both the general feed and "invited to
  /// me" without a second subscription; the caller splits them apart
  /// (job.invitedTechnicianId) and applies its own category/area
  /// filtering client-side, since .stream() only supports chained
  /// .eq() filters, not the .inFilter()/.ilike() the one-shot version
  /// used. Rows carry no categories(name) embed either -- streaming
  /// doesn't support embeds -- so category names come back empty;
  /// resolve them from an already-loaded category list via
  /// Job.copyWithCategoryName.
  Stream<List<Job>> streamOpenJobs() {
    return supabase
        .from('jobs')
        .stream(primaryKey: ['id'])
        .eq('status', 'open')
        .order('created_at', ascending: false)
        .map((rows) => rows.map((e) => Job.fromMap(e)).toList());
  }

  Future<Job> fetchJobById(String id) async {
    final data =
        await supabase.from('jobs').select(_jobSelect).eq('id', id).single();
    return Job.fromMap(data);
  }

  /// Jobs this technician won the bid on -- these drop out of the open
  /// feed once accepted, so they need their own list to stay reachable.
  Future<List<Job>> fetchMyAcceptedJobs() async {
    final uid = supabase.auth.currentUser!.id;
    final bidRows = await supabase
        .from('bids')
        .select('job_id')
        .eq('technician_id', uid)
        .eq('status', 'accepted');
    final jobIds =
        (bidRows as List).map((e) => e['job_id'] as String).toList();
    if (jobIds.isEmpty) return [];
    final data = await supabase
        .from('jobs')
        .select(_jobSelect)
        .inFilter('id', jobIds)
        .order('created_at', ascending: false);
    return (data as List)
        .map((e) => Job.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  /// The technician heading out -- optionally with an ETA the customer
  /// sees on their status panel.
  Future<void> startEnRoute(String jobId, {DateTime? etaAt}) async {
    await supabase.from('jobs').update({
      'status': 'en_route',
      'eta_at': ?etaAt?.toIso8601String(),
    }).eq('id', jobId);
  }

  Future<void> startJob(String jobId) async {
    await supabase.from('jobs').update({'status': 'in_progress'}).eq('id', jobId);
  }

  /// [completionCode] is the 4-digit code the customer reads out --
  /// verified server-side by the complete_job_with_code RPC (migration
  /// 010), which is the only way a job can move to 'completed'; a guard
  /// trigger rejects a plain status update that skips it. [completionPhoto]
  /// is optional proof-of-work, uploaded under the calling (technician's)
  /// own folder in the same bucket job photos already use -- its existing
  /// storage policies only check the upload path's leading uid, not the
  /// caller's role.
  Future<void> completeJob(
    String jobId, {
    required String completionCode,
    File? completionPhoto,
  }) async {
    String? photoUrl;
    if (completionPhoto != null) {
      photoUrl = await _uploadJobPhoto(completionPhoto);
    }
    await supabase.rpc('complete_job_with_code', params: {
      'p_job_id': jobId,
      'p_code': completionCode,
      'p_photo_url': photoUrl,
    });
  }

  /// Cancels a job while it's still open, before any bid is accepted.
  /// Requires migration 005 (adds 'cancelled' to the status CHECK).
  Future<void> cancelJob(String jobId) async {
    await supabase.from('jobs').update({'status': 'cancelled'}).eq('id', jobId);
  }

  /// Cancels a job either party can no longer make, recording why
  /// (migration 015). Valid from open/bid_accepted/en_route only -- once
  /// work has started the RPC refuses, and the dispute flow takes over.
  /// Records the reason and flips the status in one statement, so the
  /// two can't disagree.
  Future<void> cancelJobWithReason({
    required String jobId,
    required String reason,
  }) async {
    await supabase.rpc('cancel_job_with_reason', params: {
      'p_job_id': jobId,
      'p_reason': reason,
    });
  }

  /// Moves the agreed visit time. A plain update -- both participants
  /// already hold update policies on jobs -- with a trigger notifying
  /// whoever didn't make the change.
  Future<void> rescheduleJob({
    required String jobId,
    required DateTime scheduledFor,
  }) async {
    await supabase
        .from('jobs')
        .update({'scheduled_for': scheduledFor.toIso8601String()}).eq('id', jobId);
  }

  /// Why a job was cancelled, for the party who didn't cancel it.
  Future<({String reason, String cancelledBy})?> fetchCancellation(String jobId) async {
    final data = await supabase
        .from('job_cancellations')
        .select('reason, cancelled_by')
        .eq('job_id', jobId)
        .maybeSingle();
    if (data == null) return null;
    return (
      reason: data['reason'] as String,
      cancelledBy: data['cancelled_by'] as String,
    );
  }

  /// Average/min/max/count of accepted bid amounts for a category,
  /// across every customer -- computed server-side by a
  /// SECURITY DEFINER function (migration 008) so it can aggregate
  /// across bids this caller could never individually read under
  /// bids_select, without ever exposing an individual bid. Null if
  /// there isn't enough data yet to be a useful signal.
  Future<({double average, double min, double max, int count})?> fetchPriceGuidance(
    int categoryId,
  ) async {
    final rows = await supabase
        .rpc('category_price_guidance', params: {'p_category_id': categoryId});
    if (rows == null || (rows as List).isEmpty) return null;
    final row = rows.first as Map<String, dynamic>;
    final count = (row['sample_size'] as num).toInt();
    if (count < 3 || row['avg_amount'] == null) return null;
    return (
      average: (row['avg_amount'] as num).toDouble(),
      min: (row['min_amount'] as num).toDouble(),
      max: (row['max_amount'] as num).toDouble(),
      count: count,
    );
  }
}
