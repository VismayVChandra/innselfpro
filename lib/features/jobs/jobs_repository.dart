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

  /// [categoryIds] narrows to any of the given categories -- used both
  /// for a single explicit category tap (one id) and for defaulting a
  /// technician's feed to their own skill categories (several ids).
  /// Null/empty means no category filter at all. Invite-only jobs
  /// naturally never appear here for anyone but the invited technician
  /// -- jobs_select hides them from everyone else at the RLS level, not
  /// something this query needs to account for.
  Future<List<Job>> fetchOpenJobsFeed({List<int>? categoryIds, String? area}) async {
    var query = supabase
        .from('jobs')
        .select(_jobSelect)
        .eq('status', 'open')
        // Direct requests belong only in fetchInvitedJobsForMe's
        // section -- excluding them here means the invited technician
        // never sees the same job twice.
        .filter('invited_technician_id', 'is', null);
    if (categoryIds != null && categoryIds.isNotEmpty) {
      query = query.inFilter('category_id', categoryIds);
    }
    if (area != null && area.trim().isNotEmpty) {
      query = query.ilike('location', '%${area.trim()}%');
    }
    final data = await query.order('created_at', ascending: false);
    return (data as List)
        .map((e) => Job.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  /// Jobs a customer has invited this technician to directly. Kept as
  /// its own query rather than relying on it surfacing through the
  /// regular feed filters -- a rebooked job might not match the
  /// technician's skill categories or area filter, and it shouldn't get
  /// buried either way.
  Future<List<Job>> fetchInvitedJobsForMe() async {
    final uid = supabase.auth.currentUser!.id;
    final data = await supabase
        .from('jobs')
        .select(_jobSelect)
        .eq('status', 'open')
        .eq('invited_technician_id', uid)
        .order('created_at', ascending: false);
    return (data as List)
        .map((e) => Job.fromMap(e as Map<String, dynamic>))
        .toList();
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

  Future<void> startJob(String jobId) async {
    await supabase.from('jobs').update({'status': 'in_progress'}).eq('id', jobId);
  }

  /// [completionPhoto] is optional proof-of-work, uploaded under the
  /// calling (technician's) own folder in the same bucket job photos
  /// already use -- its existing storage policies only check the
  /// upload path's leading uid, not the caller's role.
  Future<void> completeJob(String jobId, {File? completionPhoto}) async {
    String? photoUrl;
    if (completionPhoto != null) {
      photoUrl = await _uploadJobPhoto(completionPhoto);
    }
    await supabase.from('jobs').update({
      'status': 'completed',
      'completion_photo_url': ?photoUrl,
    }).eq('id', jobId);
  }

  /// Cancels a job while it's still open, before any bid is accepted.
  /// Requires migration 005 (adds 'cancelled' to the status CHECK).
  Future<void> cancelJob(String jobId) async {
    await supabase.from('jobs').update({'status': 'cancelled'}).eq('id', jobId);
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
