import '../../core/supabase_client.dart';
import '../../models/review.dart';

class ReviewsRepository {
  Future<Review?> fetchReviewForJob(String jobId) async {
    final data =
        await supabase.from('reviews').select().eq('job_id', jobId).maybeSingle();
    if (data == null) return null;
    return Review.fromMap(data);
  }

  Future<void> submitReview({
    required String jobId,
    required String technicianId,
    required int rating,
    String? comment,
  }) async {
    final uid = supabase.auth.currentUser!.id;
    await supabase.from('reviews').insert({
      'job_id': jobId,
      'customer_id': uid,
      'technician_id': technicianId,
      'rating': rating,
      'comment': comment,
    });
  }

  Future<List<Review>> fetchReviewsForTechnician() async {
    final uid = supabase.auth.currentUser!.id;
    final data = await supabase
        .from('reviews')
        .select('*, jobs(categories(name))')
        .eq('technician_id', uid)
        .order('created_at', ascending: false);
    return (data as List)
        .map((e) => Review.fromMap(e as Map<String, dynamic>))
        .toList();
  }
}
