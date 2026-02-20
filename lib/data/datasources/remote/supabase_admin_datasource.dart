import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseAdminDataSource {
  SupabaseAdminDataSource({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Stream<List<Map<String, dynamic>>> streamUserEvents({int limit = 50}) {
    return _client
        .from('user_events')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .limit(limit);
  }

  Future<List<Map<String, dynamic>>> listSellerProductControls() async {
    final res = await _client.rpc('admin_list_seller_product_controls');
    return List<Map<String, dynamic>>.from(res as List);
  }

  Future<Map<String, dynamic>> setSellerProductControl({
    required String sellerId,
    required bool canAddProducts,
    required String approvalMode,
    required bool isBlocked,
    String? notes,
  }) async {
    final res = await _client.rpc('admin_set_seller_product_control', params: {
      'p_seller_id': sellerId,
      'p_can_add_products': canAddProducts,
      'p_approval_mode': approvalMode,
      'p_is_blocked': isBlocked,
      'p_notes': notes,
    });
    return Map<String, dynamic>.from(res as Map);
  }

  Future<List<Map<String, dynamic>>> listPendingProducts({
    int limit = 100,
    int offset = 0,
  }) async {
    final res = await _client.rpc('admin_list_pending_products', params: {
      'p_limit': limit,
      'p_offset': offset,
    });
    return List<Map<String, dynamic>>.from(res as List);
  }

  Future<Map<String, dynamic>> reviewProduct({
    required String productId,
    required bool approve,
    String? note,
  }) async {
    final res = await _client.rpc('admin_review_product', params: {
      'p_product_id': productId,
      'p_action': approve ? 'approve' : 'reject',
      'p_note': note,
    });
    return Map<String, dynamic>.from(res as Map);
  }
}
