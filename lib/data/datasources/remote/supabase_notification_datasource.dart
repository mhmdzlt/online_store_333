import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseNotificationDataSource {
  SupabaseNotificationDataSource({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Stream<List<Map<String, dynamic>>> streamGeneralNotifications() {
    return _client.from('notifications').stream(primaryKey: ['id']).map((data) {
      final filtered = data.where((row) {
        final isActive = row['is_active'] == true;
        final targetType = row['target_type']?.toString() ?? 'all';
        return isActive && targetType == 'all';
      }).toList();

      filtered.sort((a, b) {
        final aDate = DateTime.tryParse((a['created_at'] ?? '').toString()) ??
            DateTime(1970);
        final bDate = DateTime.tryParse((b['created_at'] ?? '').toString()) ??
            DateTime(1970);
        return bDate.compareTo(aDate);
      });

      return filtered;
    });
  }

  Future<List<Map<String, dynamic>>> fetchGeneralNotifications() async {
    final res = await _client
        .from('notifications')
        .select()
        .eq('is_active', true)
        .eq('target_type', 'all')
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(res);
  }

  Future<List<Map<String, dynamic>>> fetchPhoneNotifications(
    String phone,
  ) async {
    final res = await _client
        .from('notifications')
        .select()
        .eq('is_active', true)
        .or('target_type.eq.all,target_type.eq.phone')
        .order('created_at', ascending: false);

    final list = List<Map<String, dynamic>>.from(res);
    return list.where((notif) {
      final type = notif['target_type'];
      if (type == 'all') return true;
      if (type == 'phone') {
        final targetPhone = (notif['target_phone'] as String?)?.trim();
        return targetPhone != null && targetPhone == phone;
      }
      return false;
    }).toList();
  }

  Future<List<Map<String, dynamic>>> fetchOrderNotifications(
    String orderNumber,
  ) async {
    final res = await _client
        .from('notifications')
        .select()
        .eq('is_active', true)
        .or('target_type.eq.all,target_type.eq.order')
        .order('created_at', ascending: false);

    final list = List<Map<String, dynamic>>.from(res);
    return list.where((notif) {
      final type = notif['target_type'];
      if (type == 'all') return true;
      if (type == 'order') {
        final targetOrder = notif['target_order_number'] as String?;
        return targetOrder != null && targetOrder == orderNumber;
      }
      return false;
    }).toList();
  }

  Future<List<Map<String, dynamic>>> getNotificationsPublic({
    required String phone,
    required String token,
    String? orderNumber,
  }) async {
    final res = await _client.rpc('get_notifications_public', params: {
      'p_phone': phone,
      'p_token': token,
      'p_order_number': orderNumber,
    });

    final list = (res as List).cast<dynamic>();
    return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<void> saveDeviceToken({
    required String token,
    required String phone,
    required String platform,
  }) async {
    await _client.rpc('save_device_token', params: {
      'p_token': token,
      'p_phone': phone,
      'p_platform': platform,
    });
  }
}
