import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseProductDataSource {
  SupabaseProductDataSource({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  bool _isMissingRelationshipError(Object error) {
    if (error is! PostgrestException) return false;
    final msg = error.message.toLowerCase();
    return msg.contains('relationship') || msg.contains('could not find');
  }

  bool _isMissingColumnError(Object error) {
    if (error is! PostgrestException) return false;
    final msg = error.message.toLowerCase();
    return (error.code == '42703') ||
        (msg.contains('does not exist') && msg.contains('column'));
  }

  Future<List<Map<String, dynamic>>> fetchHomeProducts({
    String sort = 'latest',
  }) async {
    const selectWithImages = '''
          id,
          category_id,
          car_brand_id,
            car_model_id,
            car_trim_id,
            car_generation_id,
            car_section_v2_id,
            car_subsection_id,
          seller_id,
          name,
          price,
          currency,
          description,
          extra_info,
          return_policy,
          image_url,
          is_active,
          is_featured,
          is_best_seller,
          created_at,
          product_images (
            image_url,
            sort_order
          )
        ''';

    final baseQuery =
        _client.from('products').select(selectWithImages).eq('is_active', true);

    PostgrestTransformBuilder<PostgrestList> orderedQuery;
    switch (sort) {
      case 'price_asc':
        orderedQuery = baseQuery.order('price', ascending: true);
        break;
      case 'price_desc':
        orderedQuery = baseQuery.order('price', ascending: false);
        break;
      case 'best_seller':
        orderedQuery = baseQuery
            .order('is_best_seller', ascending: false)
            .order('created_at', ascending: false);
        break;
      case 'latest':
      default:
        orderedQuery = baseQuery.order('created_at', ascending: false);
    }

    try {
      final res = await orderedQuery;
      return List<Map<String, dynamic>>.from(res);
    } catch (e) {
      if (_isMissingRelationshipError(e) || _isMissingColumnError(e)) {
        const selectNoImages = '''
          id,
          category_id,
          car_brand_id,
          car_model_id,
          car_trim_id,
          car_generation_id,
          car_section_v2_id,
          car_subsection_id,
          seller_id,
          name,
          price,
          currency,
          description,
          extra_info,
          return_policy,
          image_url,
          is_active,
          is_featured,
          is_best_seller,
          created_at
        ''';

        final retryBase = _client
            .from('products')
            .select(selectNoImages)
            .eq('is_active', true);

        PostgrestTransformBuilder<PostgrestList> retryOrdered;
        switch (sort) {
          case 'price_asc':
            retryOrdered = retryBase.order('price', ascending: true);
            break;
          case 'price_desc':
            retryOrdered = retryBase.order('price', ascending: false);
            break;
          case 'best_seller':
            retryOrdered = retryBase
                .order('is_best_seller', ascending: false)
                .order('created_at', ascending: false);
            break;
          case 'latest':
          default:
            retryOrdered = retryBase.order('created_at', ascending: false);
        }

        final retryRes = await retryOrdered;
        return List<Map<String, dynamic>>.from(retryRes);
      }
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> fetchBestSellerProducts() async {
    final res = await _client
        .from('products')
        .select('id, name, price, currency, image_url, seller_id')
        .eq('is_best_seller', true)
        .eq('is_active', true)
        .limit(10);
    return List<Map<String, dynamic>>.from(res);
  }

  Future<List<Map<String, dynamic>>> fetchProductsByCategory(
    String categoryId,
  ) async {
    final res = await _client.from('products').select('''
          id,
          name,
          seller_id,
          price,
          currency,
          image_url,
          is_active,
          is_featured,
          is_best_seller,
          created_at,
          product_images (
            image_url,
            sort_order
          )
        ''').eq('category_id', categoryId).eq('is_active', true).order(
          'created_at',
          ascending: false,
        );
    return List<Map<String, dynamic>>.from(res);
  }

  Future<Map<String, dynamic>?> fetchProductById(String id) async {
    if (id.trim().isEmpty) return null;
    final res = await _client.from('products').select('''
          id,
          seller_id,
          name,
          description,
          extra_info,
          return_policy,
          price,
          old_price,
          currency,
          image_url,
          is_active,
          is_featured,
          is_best_seller,
          created_at,
          product_images (
            image_url,
            sort_order
          )
        ''').eq('id', id).maybeSingle();
    return res;
  }
}
