import '../../core/supabase_client.dart';
import '../../models/review.dart';

class ReviewsRepository {
  /// A job can have up to two reviews now (one per direction) -- pass
  /// which one you want.
  Future<Review?> fetchReviewForJob(String jobId, {required String reviewerRole}) async {
    final data = await supabase
        .from('reviews')
        .select()
        .eq('job_id', jobId)
        .eq('reviewer_role', reviewerRole)
        .maybeSingle();
    if (data == null) return null;
    return Review.fromMap(data);
  }

  /// The customer rating the technician -- the original review flow.
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
      'reviewer_role': 'customer',
    });
  }

  /// The technician rating the customer back.
  Future<void> submitTechnicianReview({
    required String jobId,
    required String customerId,
    required int rating,
    String? comment,
  }) async {
    final uid = supabase.auth.currentUser!.id;
    await supabase.from('reviews').insert({
      'job_id': jobId,
      'customer_id': customerId,
      'technician_id': uid,
      'rating': rating,
      'comment': comment,
      'reviewer_role': 'technician',
    });
  }

  /// Reviews a technician has received from customers. Filtered to
  /// reviewer_role = 'customer' -- otherwise a technician's own reviews
  /// of their customers (which also carry their technician_id) would
  /// pollute their own rating.
  Future<List<Review>> fetchReviewsForTechnician() async {
    final uid = supabase.auth.currentUser!.id;
    final data = await supabase
        .from('reviews')
        .select('*, jobs(categories(name))')
        .eq('technician_id', uid)
        .eq('reviewer_role', 'customer')
        .order('created_at', ascending: false);
    return (data as List)
        .map((e) => Review.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  /// Reviews the signed-in customer has received from technicians. The
  /// customer-facing counterpart to fetchReviewsForTechnician.
  Future<List<Review>> fetchReviewsForCustomer() async {
    final uid = supabase.auth.currentUser!.id;
    final data = await supabase
        .from('reviews')
        .select('*, jobs(categories(name))')
        .eq('customer_id', uid)
        .eq('reviewer_role', 'technician')
        .order('created_at', ascending: false);
    return (data as List)
        .map((e) => Review.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  /// A single customer's average rating from technicians who've worked
  /// with them, so a technician can see who they're dealing with.
  Future<({double average, int count})?> fetchCustomerRating(String customerId) async {
    final rows = await supabase
        .from('reviews')
        .select('rating')
        .eq('customer_id', customerId)
        .eq('reviewer_role', 'technician');
    final ratings = (rows as List)
        .map((e) => (e as Map<String, dynamic>)['rating'] as int)
        .toList();
    if (ratings.isEmpty) return null;
    return (
      average: ratings.reduce((a, b) => a + b) / ratings.length,
      count: ratings.length,
    );
  }
}
