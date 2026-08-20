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

  Future<List<Job>> fetchOpenJobsFeed({int? categoryId, String? area}) async {
    var query = supabase.from('jobs').select(_jobSelect).eq('status', 'open');
    if (categoryId != null) {
      query = query.eq('category_id', categoryId);
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

  Future<void> completeJob(String jobId) async {
    await supabase.from('jobs').update({'status': 'completed'}).eq('id', jobId);
  }

  /// Cancels a job while it's still open, before any bid is accepted.
  /// Requires migration 005 (adds 'cancelled' to the status CHECK).
  Future<void> cancelJob(String jobId) async {
    await supabase.from('jobs').update({'status': 'cancelled'}).eq('id', jobId);
  }
}
