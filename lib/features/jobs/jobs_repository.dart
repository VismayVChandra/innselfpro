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

  Future<String> _uploadJobPhoto(File file) async {
    final uid = supabase.auth.currentUser!.id;
    final ext = file.path.split('.').last;
    final path = '$uid/${DateTime.now().millisecondsSinceEpoch}.$ext';
    await supabase.storage.from('job-photos').upload(path, file);
    return supabase.storage.from('job-photos').getPublicUrl(path);
  }

  Future<void> createJob({
    required int categoryId,
    required String description,
    required String location,
    File? photo,
    DateTime? scheduledFor,
  }) async {
    final uid = supabase.auth.currentUser!.id;
    String? photoUrl;
    if (photo != null) {
      photoUrl = await _uploadJobPhoto(photo);
    }
    await supabase.from('jobs').insert({
      'customer_id': uid,
      'category_id': categoryId,
      'description': description,
      'location': location,
      'photo_url': photoUrl,
      'scheduled_for': scheduledFor?.toIso8601String(),
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
  /// Null/empty means no category filter at all.
  Future<List<Job>> fetchOpenJobsFeed({List<int>? categoryIds, String? area}) async {
    var query = supabase.from('jobs').select(_jobSelect).eq('status', 'open');
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
}
