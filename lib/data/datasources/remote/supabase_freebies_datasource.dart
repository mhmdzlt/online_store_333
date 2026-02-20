import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseFreebiesDataSource {
  SupabaseFreebiesDataSource({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<List<Map<String, dynamic>>> fetchDonations({
    String? city,
    String status = 'available',
  }) async {
    Future<List<Map<String, dynamic>>> runQuery(String select) async {
      final query = _client.from('donations').select(select);
      final filtered =
          city != null && city.isNotEmpty ? query.eq('city', city) : query;
      final filteredStatus =
          status.isNotEmpty ? filtered.eq('status', status) : filtered;
      final res = await filteredStatus.order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(res);
    }

    const selectWithCoords = '''
          id,
          title,
          description,
          city,
          area,
          status,
          image_urls,
          created_at,
          latitude,
          longitude
        ''';
    const selectWithoutCoords = '''
          id,
          title,
          description,
          city,
          area,
          status,
          image_urls,
          created_at
        ''';

    try {
      return await runQuery(selectWithCoords);
    } on PostgrestException catch (error) {
      if (_isMissingCoordsColumn(error)) {
        return await runQuery(selectWithoutCoords);
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> fetchDonationById(String id) async {
    final res =
        await _client.from('donations').select().eq('id', id).maybeSingle();
    return res;
  }

  Future<List<Map<String, dynamic>>> fetchNearbyDonations({
    required double latitude,
    required double longitude,
    required double radiusKm,
    String? city,
    String status = 'available',
  }) async {
    final Map<String, dynamic> params = {
      'p_lat': latitude,
      'p_lng': longitude,
      'p_radius_km': radiusKm,
    };

    if (city != null && city.isNotEmpty) {
      params['p_city'] = city;
    }
    if (status.isNotEmpty) {
      params['p_status'] = status;
    }

    try {
      final res = await _client.rpc('get_nearby_donations', params: params);
      return List<Map<String, dynamic>>.from(res);
    } on PostgrestException catch (error) {
      if (_isMissingNearbyRpc(error)) {
        return fetchDonations(city: city, status: status);
      }
      rethrow;
    }
  }

  Future<void> submitDonationRequest({
    required String donationId,
    required String name,
    required String phone,
    required String city,
    required String area,
    required String reason,
    required String contactMethod,
  }) async {
    final payload = {
      'donation_id': donationId,
      'requester_name': name,
      'requester_phone': phone,
      'city': city,
      'area': area,
      'reason': reason,
      'contact_method': contactMethod,
    };

    try {
      await _client.from('donation_requests').insert(payload);
    } on PostgrestException catch (error) {
      if (_isMissingContactMethodColumn(error)) {
        payload.remove('contact_method');
        await _client.from('donation_requests').insert(payload);
        return;
      }
      rethrow;
    }
  }

  Future<void> confirmDonationDelivered({
    required String donationId,
    required String actorPhone,
  }) async {
    await _client.rpc('mark_donation_delivered_public', params: {
      'p_donation_id': donationId,
      'p_actor_phone': actorPhone,
    });
  }

  Future<bool> canConfirmDonationDelivery({
    required String donationId,
    required String actorPhone,
  }) async {
    final phone = actorPhone.trim();
    if (phone.isEmpty) return false;

    final donation = await _client
        .from('donations')
        .select('donor_phone')
        .eq('id', donationId)
        .maybeSingle();

    if (donation == null) return false;

    final donorPhone = (donation['donor_phone']?.toString() ?? '').trim();
    if (donorPhone.isNotEmpty && donorPhone == phone) {
      return true;
    }

    final acceptedRows = await _client
        .from('donation_requests')
        .select('id')
        .eq('donation_id', donationId)
        .eq('requester_phone', phone)
        .inFilter('status', const [
      'accepted',
      'approved',
      'reserved',
      'in_progress',
      'completed',
    ]).limit(1);

    return acceptedRows.isNotEmpty;
  }

  Future<void> submitDonationReport({
    required String donationId,
    required String reason,
    String? details,
    String? reporterName,
    String? reporterPhone,
  }) async {
    try {
      await _client.from('donation_reports').insert({
        'donation_id': donationId,
        'reason': reason,
        'details':
            (details == null || details.trim().isEmpty) ? null : details.trim(),
        'reporter_name': (reporterName == null || reporterName.trim().isEmpty)
            ? null
            : reporterName.trim(),
        'reporter_phone':
            (reporterPhone == null || reporterPhone.trim().isEmpty)
                ? null
                : reporterPhone.trim(),
      });
    } on PostgrestException catch (error) {
      if (error.code == 'PGRST205' ||
          error.message.toLowerCase().contains('donation_reports')) {
        throw StateError(
          'ميزة البلاغات غير مفعّلة في قاعدة البيانات بعد. شغّل migration الخاص بها.',
        );
      }
      rethrow;
    }
  }

  Future<void> submitDonation({
    required String donorName,
    required String donorPhone,
    required String city,
    required String area,
    required String title,
    required String description,
    required List<XFile> images,
    double? latitude,
    double? longitude,
  }) async {
    final storage = _client.storage.from('product-images');
    final List<String> imageUrls = [];

    for (final img in images) {
      final bytes = await img.readAsBytes();
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${img.name}';
      final path = 'donations/$fileName';

      await storage.uploadBinary(
        path,
        bytes,
        fileOptions: const FileOptions(
          cacheControl: '3600',
          upsert: false,
        ),
      );

      final publicUrl = storage.getPublicUrl(path);
      imageUrls.add(publicUrl);
    }

    final payload = {
      'donor_name': donorName,
      'donor_phone': donorPhone,
      'city': city,
      'area': area,
      'title': title,
      'description': description,
      'status': 'available',
      'image_urls': imageUrls,
    };

    if (latitude != null) {
      payload['latitude'] = latitude;
    }
    if (longitude != null) {
      payload['longitude'] = longitude;
    }

    try {
      await _client.from('donations').insert(payload);
    } on PostgrestException catch (error) {
      if (_isMissingCoordsColumn(error)) {
        payload.remove('latitude');
        payload.remove('longitude');
        await _client.from('donations').insert(payload);
        return;
      }
      rethrow;
    }
  }

  bool _isMissingCoordsColumn(PostgrestException error) {
    if (error.code == '42703') return true;
    final message = error.message.toLowerCase();
    return message.contains('column') &&
        (message.contains('latitude') ||
            message.contains('longitude') ||
            message.contains('lat') ||
            message.contains('lng'));
  }

  bool _isMissingNearbyRpc(PostgrestException error) {
    if (error.code == '42883') return true;
    final message = error.message.toLowerCase();
    return message.contains('get_nearby_donations');
  }

  bool _isMissingContactMethodColumn(PostgrestException error) {
    if (error.code == '42703') return true;
    final message = error.message.toLowerCase();
    return message.contains('contact_method');
  }
}
