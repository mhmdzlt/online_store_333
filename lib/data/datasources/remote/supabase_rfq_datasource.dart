import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseRfqDataSource {
  SupabaseRfqDataSource({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Never _rethrowFriendly(Object error) {
    if (error is PostgrestException) {
      final code = error.code;
      final message = error.message;

      final isMissingTable =
          code == 'PGRST205' || message.contains('Could not find the table');
      final isMissingFunction =
          code == 'PGRST202' || message.contains('Could not find the function');

      if (isMissingTable || isMissingFunction) {
        throw Exception(
          'ميزة RFQ غير مفعّلة على قاعدة البيانات الحالية. '
          'طبّق Migration الخاصة بـ RFQ على Supabase ثم أعد المحاولة. '
          'إذا استمر الخطأ بعد التطبيق نفّذ: notify pgrst, \'reload schema\'.',
        );
      }

      final isUndefinedFunction = code == '42883';
      final looksLikeRandomBytes = message.contains('gen_random_bytes');
      if (isUndefinedFunction && looksLikeRandomBytes) {
        throw Exception(
          'تعذر إنشاء الطلب بسبب إعدادات قاعدة البيانات (دالة gen_random_bytes غير متوفرة). '
          'أعد تطبيق/تشغيل Migration الخاصة بـ RFQ أو أعد إنشاء دالة create_part_request_public على Supabase ثم جرّب مرة أخرى.',
        );
      }
    }

    throw error;
  }

  Future<Map<String, dynamic>> createPartRequestPublic({
    String? customerName,
    String? customerPhone,
    String? vin,
    String? description,
    String? carBrandId,
    String? carModelId,
    String? carYearId,
    String? carGenerationId,
    String? carTrimId,
    List<String>? imageUrls,
  }) async {
    try {
      final res = await _client.rpc('create_part_request_public', params: {
        'p_customer_name': customerName,
        'p_customer_phone': customerPhone,
        'p_vin': vin,
        'p_description': description,
        'p_car_brand_id': carBrandId,
        'p_car_model_id': carModelId,
        'p_car_year_id': carYearId,
        'p_car_generation_id': carGenerationId,
        'p_car_trim_id': carTrimId,
        'p_image_urls': imageUrls,
      });

      return Map<String, dynamic>.from(res as Map);
    } catch (e) {
      _rethrowFriendly(e);
    }
  }

  Future<List<Map<String, dynamic>>> listOffersPublic({
    required String requestNumber,
    String? customerPhone,
    required String accessToken,
  }) async {
    try {
      final res = await _client.rpc('list_part_offers_public', params: {
        'p_request_number': requestNumber,
        'p_customer_phone': customerPhone,
        'p_access_token': accessToken,
      });

      return List<Map<String, dynamic>>.from(res as List);
    } catch (e) {
      _rethrowFriendly(e);
    }
  }

  Future<List<Map<String, dynamic>>> listMessagesPublic({
    required String requestNumber,
    required String accessToken,
    required String sellerId,
  }) async {
    try {
      final res = await _client.rpc('list_part_messages_public', params: {
        'p_request_number': requestNumber,
        'p_access_token': accessToken,
        'p_seller_id': sellerId,
      });

      return List<Map<String, dynamic>>.from(res as List);
    } catch (e) {
      _rethrowFriendly(e);
    }
  }

  Future<void> sendMessagePublic({
    required String requestNumber,
    required String accessToken,
    required String sellerId,
    required String message,
  }) async {
    try {
      await _client.rpc('send_part_message_public', params: {
        'p_request_number': requestNumber,
        'p_access_token': accessToken,
        'p_seller_id': sellerId,
        'p_message': message,
      });
    } catch (e) {
      _rethrowFriendly(e);
    }
  }
}
