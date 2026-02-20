import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseOrderDataSource {
  SupabaseOrderDataSource({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<Map<String, dynamic>> createOrderPublic({
    required String customerName,
    required String phone,
    required String city,
    String? area,
    required String address,
    String? notes,
    required String shippingMethod,
    required String paymentMethod,
    required List<Map<String, dynamic>> items,
    num shippingCost = 0,
    num discountAmount = 0,
    String? orderNumber,
    String? influencerRefCode,
  }) async {
    final params = <String, dynamic>{
      'p_customer_name': customerName,
      'p_phone': phone,
      'p_city': city,
      'p_area': area,
      'p_address': address,
      'p_notes': notes,
      'p_shipping_method': shippingMethod,
      'p_payment_method': paymentMethod,
      'p_items': items,
      'p_shipping_cost': shippingCost,
      'p_discount_amount': discountAmount,
      'p_order_number': orderNumber,
      if (influencerRefCode != null && influencerRefCode.trim().isNotEmpty)
        'p_influencer_ref_code': influencerRefCode.trim().toUpperCase(),
    };

    dynamic res;
    try {
      res = await _client.rpc('create_order_public', params: params);
    } on PostgrestException catch (error) {
      final message = error.message.toLowerCase();
      final hasRefParam = params.containsKey('p_influencer_ref_code') &&
          (message.contains('p_influencer_ref_code') ||
              message.contains('function create_order_public') ||
              message.contains('does not exist'));

      if (!hasRefParam) rethrow;

      final fallback = Map<String, dynamic>.from(params)
        ..remove('p_influencer_ref_code');
      res = await _client.rpc('create_order_public', params: fallback);
    }

    final result = Map<String, dynamic>.from(res as Map);

    if (influencerRefCode != null && influencerRefCode.trim().isNotEmpty) {
      try {
        await _client.rpc('apply_influencer_ref_to_order_public', params: {
          'p_order_number': result['order_number']?.toString(),
          'p_phone': phone,
          'p_ref_code': influencerRefCode.trim().toUpperCase(),
        });
      } on PostgrestException catch (error) {
        final message = error.message.toLowerCase();
        final missingRpc = message
                .contains('apply_influencer_ref_to_order_public') ||
            error.code == 'PGRST202' ||
            message.contains('function') && message.contains('does not exist');
        if (!missingRpc) rethrow;
      }
    }

    return result;
  }

  Future<Map<String, dynamic>?> trackOrder({
    required String orderNumber,
    required String phone,
  }) async {
    final res = await _client.rpc('track_order_public', params: {
      'p_order_number': orderNumber,
      'p_phone': phone,
    });

    if (res == null) return null;
    return Map<String, dynamic>.from(res as Map);
  }

  Future<List<Map<String, dynamic>>> fetchMyOrders({int limit = 20}) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null || userId.isEmpty) {
      return <Map<String, dynamic>>[];
    }

    try {
      final res = await _client
          .from('orders')
          .select('order_number, status, created_at, total_amount')
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(limit);

      return List<Map<String, dynamic>>.from(res);
    } catch (_) {
      return <Map<String, dynamic>>[];
    }
  }
}
