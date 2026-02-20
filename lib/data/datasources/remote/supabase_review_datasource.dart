import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseReviewDataSource {
  SupabaseReviewDataSource({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<List<Map<String, dynamic>>> fetchProductReviews(
      String productId) async {
    if (productId.trim().isEmpty) {
      return <Map<String, dynamic>>[];
    }

    final res = await _client
        .from('product_reviews')
        .select('id, reviewer_name, rating, comment, created_at')
        .eq('product_id', productId)
        .eq('is_approved', true)
        .order('created_at', ascending: false)
        .limit(100);

    return List<Map<String, dynamic>>.from(res);
  }

  Future<void> addProductReview({
    required String productId,
    required String reviewerName,
    required int rating,
    String? comment,
    String? reviewerPhone,
  }) async {
    if (productId.trim().isEmpty) {
      throw ArgumentError('productId is empty');
    }
    await _client.from('product_reviews').insert({
      'product_id': productId,
      'reviewer_name': reviewerName,
      'reviewer_phone': reviewerPhone,
      'rating': rating,
      'comment': comment,
    });
  }
}
