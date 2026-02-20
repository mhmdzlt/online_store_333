import '../datasources/remote/supabase_review_datasource.dart';

abstract class ReviewRepository {
  Future<List<Map<String, dynamic>>> fetchProductReviews(String productId);

  Future<void> addProductReview({
    required String productId,
    required String reviewerName,
    required int rating,
    String? comment,
    String? reviewerPhone,
  });
}

class SupabaseReviewRepository implements ReviewRepository {
  SupabaseReviewRepository({SupabaseReviewDataSource? dataSource})
      : _dataSource = dataSource ?? SupabaseReviewDataSource();

  final SupabaseReviewDataSource _dataSource;

  @override
  Future<List<Map<String, dynamic>>> fetchProductReviews(String productId) {
    return _dataSource.fetchProductReviews(productId);
  }

  @override
  Future<void> addProductReview({
    required String productId,
    required String reviewerName,
    required int rating,
    String? comment,
    String? reviewerPhone,
  }) {
    return _dataSource.addProductReview(
      productId: productId,
      reviewerName: reviewerName,
      rating: rating,
      comment: comment,
      reviewerPhone: reviewerPhone,
    );
  }
}
