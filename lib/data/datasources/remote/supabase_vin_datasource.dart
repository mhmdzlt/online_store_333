import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseVinDataSource {
  SupabaseVinDataSource({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<Map<String, dynamic>> decodeVinLocal(String vin) async {
    final res = await _client.rpc('decode_vin_local', params: {
      'p_vin': vin,
    });

    return Map<String, dynamic>.from(res as Map);
  }
}
