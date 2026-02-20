import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseInfluencerDataSource {
  SupabaseInfluencerDataSource({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  static const String _influencerReferralBaseUrl = 'https://karza.app';

  final SupabaseClient _client;

  Future<Map<String, dynamic>?> fetchMyProfile() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null || userId.isEmpty) {
      return null;
    }

    try {
      final row = await _client
          .from('influencer_profiles')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      return row;
    } on PostgrestException catch (error) {
      if (_isMissingInfluencerSchema(error)) {
        throw Exception('Influencer program schema is not available yet');
      }
      rethrow;
    }
  }

  Future<void> submitMyApplication({
    required String fullName,
    required String platform,
    String? handle,
    int? audienceSize,
    String? contactPhone,
  }) async {
    final user = _client.auth.currentUser;
    final userId = user?.id;
    if (userId == null || userId.isEmpty) {
      throw Exception('User not authenticated');
    }

    final payload = <String, dynamic>{
      'user_id': userId,
      'full_name': fullName,
      'platform': platform,
      'status': 'pending',
      'contact_email': user?.email,
      if (handle != null && handle.trim().isNotEmpty) 'handle': handle.trim(),
      if (audienceSize != null && audienceSize > 0)
        'audience_size': audienceSize,
      if (contactPhone != null && contactPhone.trim().isNotEmpty)
        'contact_phone': contactPhone.trim(),
    };

    try {
      await _client
          .from('influencer_profiles')
          .upsert(payload, onConflict: 'user_id');
    } on PostgrestException catch (error) {
      if (_isMissingInfluencerSchema(error)) {
        throw Exception('Influencer program schema is not available yet');
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> fetchMyReferralSummary() async {
    final profile = await fetchMyProfile();
    final profileId = profile?['id']?.toString();
    final status = profile?['status']?.toString();

    if (profileId == null || profileId.isEmpty || status != 'approved') {
      return null;
    }

    try {
      final rows = await _client
          .from('influencer_promo_codes')
          .select('code')
          .eq('influencer_id', profileId)
          .eq('is_active', true)
          .order('created_at', ascending: false)
          .limit(1);

      final list = List<Map<String, dynamic>>.from(rows);
      if (list.isEmpty) return null;

      final code = list.first['code']?.toString().trim().toUpperCase();
      if (code == null || code.isEmpty) return null;

      return {
        'code': code,
        'link':
            '$_influencerReferralBaseUrl/?ref=${Uri.encodeQueryComponent(code)}',
      };
    } on PostgrestException catch (error) {
      if (_isMissingInfluencerSchema(error)) {
        throw Exception('Influencer program schema is not available yet');
      }
      rethrow;
    }
  }

  bool _isMissingInfluencerSchema(PostgrestException error) {
    if (error.code == 'PGRST205') return true;
    final message = error.message.toLowerCase();
    return message.contains('influencer_profiles') &&
        (message.contains('not found') || message.contains('could not find'));
  }
}
