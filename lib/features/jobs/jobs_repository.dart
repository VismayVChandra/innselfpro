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
}
