import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class LocalStorage {
  static const _phoneKey = 'saved_user_phone';
  static const _userLatKey = 'user_location_lat';
  static const _userLngKey = 'user_location_lng';
  static const _nearbyRadiusKey = 'nearby_radius_km';
  static const _rfqRequestsKey = 'rfq_requests_v1';
  static const _appLanguageKey = 'app_language_code';
  static const _checkoutProfileKey = 'checkout_customer_profile_v1';
  static const _checkoutAddressesKey = 'checkout_customer_addresses_v1';
  static const _userOrderNumbersPrefix = 'user_order_numbers_v1_';
  static const _userCheckoutProfilePrefix = 'checkout_customer_profile_v2_';
  static const _userCheckoutAddressesPrefix = 'checkout_customer_addresses_v2_';
  static const _influencerReferralCodeKey = 'influencer_referral_code_v1';
  static const _influencerReferralSourceKey = 'influencer_referral_source_v1';
  static const _influencerReferralCapturedAtKey =
      'influencer_referral_captured_at_v1';

  static Future<void> saveUserPhone(String phone) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_phoneKey, phone);
  }

  static Future<String?> getUserPhone() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_phoneKey);
  }

  static Future<void> saveUserLocation({
    required double latitude,
    required double longitude,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_userLatKey, latitude);
    await prefs.setDouble(_userLngKey, longitude);
  }

  static Future<Map<String, double>?> getUserLocation() async {
    final prefs = await SharedPreferences.getInstance();
    final lat = prefs.getDouble(_userLatKey);
    final lng = prefs.getDouble(_userLngKey);
    if (lat == null || lng == null) return null;
    return {'lat': lat, 'lng': lng};
  }

  static Future<void> saveNearbyRadius(double radiusKm) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_nearbyRadiusKey, radiusKm);
  }

  static Future<double?> getNearbyRadius() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_nearbyRadiusKey);
  }

  static Future<void> saveRfqRequest({
    required String requestNumber,
    required String accessToken,
    String? customerPhone,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_rfqRequestsKey) ?? <String>[];

    // Store as a compact pipe-separated record to avoid JSON dependency here.
    // Format: requestNumber|accessToken|customerPhone|createdAtIso
    final createdAt = DateTime.now().toIso8601String();
    final record =
        '$requestNumber|$accessToken|${customerPhone ?? ''}|$createdAt';

    // De-duplicate by request number.
    final filtered =
        raw.where((r) => !r.startsWith('$requestNumber|')).toList();
    filtered.insert(0, record);

    await prefs.setStringList(_rfqRequestsKey, filtered);
  }

  static Future<List<Map<String, String>>> getRfqRequests() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_rfqRequestsKey) ?? <String>[];

    return raw
        .map((r) {
          final parts = r.split('|');
          return {
            'requestNumber': parts.isNotEmpty ? parts[0] : '',
            'accessToken': parts.length > 1 ? parts[1] : '',
            'customerPhone': parts.length > 2 ? parts[2] : '',
            'createdAt': parts.length > 3 ? parts[3] : '',
          };
        })
        .where((m) => (m['requestNumber'] ?? '').isNotEmpty)
        .toList();
  }

  static Future<void> saveAppLanguageCode(String code) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_appLanguageKey, code);
  }

  static Future<String?> getAppLanguageCode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_appLanguageKey);
  }

  static Future<void> saveCheckoutProfile({
    required String fullName,
    required String phone,
    required String city,
    String? area,
    required String address,
    String? notes,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = {
      'full_name': fullName,
      'phone': phone,
      'city': city,
      'area': area,
      'address': address,
      'notes': notes,
    };
    await prefs.setString(_checkoutProfileKey, jsonEncode(payload));
  }

  static Future<Map<String, dynamic>?> getCheckoutProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_checkoutProfileKey);
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {}
    return null;
  }

  static String _orderNumbersKeyForUser(String userId) {
    return '$_userOrderNumbersPrefix$userId';
  }

  static String _checkoutProfileKeyForUser(String userId) {
    return '$_userCheckoutProfilePrefix$userId';
  }

  static String _checkoutAddressesKeyForUser(String userId) {
    return '$_userCheckoutAddressesPrefix$userId';
  }

  static Future<void> saveCheckoutProfileForUser({
    required String userId,
    required String fullName,
    required String phone,
    required String city,
    String? area,
    required String address,
    String? notes,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = {
      'full_name': fullName,
      'phone': phone,
      'city': city,
      'area': area,
      'address': address,
      'notes': notes,
    };
    await prefs.setString(
      _checkoutProfileKeyForUser(userId),
      jsonEncode(payload),
    );
  }

  static Future<Map<String, dynamic>?> getCheckoutProfileForUser(
    String userId,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_checkoutProfileKeyForUser(userId));
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {}
    return null;
  }

  static Future<void> saveCheckoutAddresses(
    List<Map<String, dynamic>> addresses,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_checkoutAddressesKey, jsonEncode(addresses));
  }

  static Future<List<Map<String, dynamic>>> getCheckoutAddresses() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_checkoutAddressesKey);
    if (raw == null || raw.trim().isEmpty) return <Map<String, dynamic>>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
    } catch (_) {}
    return <Map<String, dynamic>>[];
  }

  static Future<void> saveCheckoutAddressesForUser({
    required String userId,
    required List<Map<String, dynamic>> addresses,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _checkoutAddressesKeyForUser(userId),
      jsonEncode(addresses),
    );
  }

  static Future<List<Map<String, dynamic>>> getCheckoutAddressesForUser(
    String userId,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_checkoutAddressesKeyForUser(userId));
    if (raw == null || raw.trim().isEmpty) return <Map<String, dynamic>>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
    } catch (_) {}
    return <Map<String, dynamic>>[];
  }

  static Future<void> saveUserOrderNumber({
    required String userId,
    required String orderNumber,
  }) async {
    final trimmed = orderNumber.trim();
    if (trimmed.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final key = _orderNumbersKeyForUser(userId);
    final existing = prefs.getStringList(key) ?? <String>[];

    final filtered = existing.where((n) => n != trimmed).toList();
    filtered.insert(0, trimmed);

    const maxItems = 10;
    if (filtered.length > maxItems) {
      filtered.removeRange(maxItems, filtered.length);
    }

    await prefs.setStringList(key, filtered);
  }

  static Future<List<String>> getUserOrderNumbers(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _orderNumbersKeyForUser(userId);
    return prefs.getStringList(key) ?? <String>[];
  }

  static Future<void> saveInfluencerReferralCode(
    String code, {
    String? source,
  }) async {
    final normalized = code.trim().toUpperCase();
    if (normalized.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_influencerReferralCodeKey, normalized);

    if (source != null && source.trim().isNotEmpty) {
      await prefs.setString(_influencerReferralSourceKey, source.trim());
    }

    await prefs.setString(
      _influencerReferralCapturedAtKey,
      DateTime.now().toUtc().toIso8601String(),
    );
  }

  static Future<String?> getInfluencerReferralCode() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_influencerReferralCodeKey);
    if (value == null || value.trim().isEmpty) return null;
    return value.trim().toUpperCase();
  }

  static Future<Map<String, String>?> getInfluencerReferralInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_influencerReferralCodeKey);
    if (code == null || code.trim().isEmpty) return null;

    return {
      'code': code.trim().toUpperCase(),
      'source': prefs.getString(_influencerReferralSourceKey) ?? '',
      'captured_at': prefs.getString(_influencerReferralCapturedAtKey) ?? '',
    };
  }

  static Future<void> clearInfluencerReferralCode() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_influencerReferralCodeKey);
    await prefs.remove(_influencerReferralSourceKey);
    await prefs.remove(_influencerReferralCapturedAtKey);
  }
}
