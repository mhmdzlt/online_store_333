import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FavoritesProvider extends ChangeNotifier {
  static const _storageKey = 'favorite_product_ids_v1';

  final Set<String> _favoriteIds = <String>{};
  bool _syncingCloud = false;

  Set<String> get favoriteIds => Set.unmodifiable(_favoriteIds);
  int get count => _favoriteIds.length;

  bool isFavorite(String productId) {
    return _favoriteIds.contains(productId.trim());
  }

  Future<void> loadFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          _favoriteIds.addAll(decoded
              .map((e) => e.toString().trim())
              .where((e) => e.isNotEmpty));
          notifyListeners();
        }
      }

      await syncWithCloudForCurrentUser();
    } catch (_) {
      // Ignore corrupted cache.
    }
  }

  Future<bool> toggleFavorite(String productId) async {
    final id = productId.trim();
    if (id.isEmpty) return false;

    final added = !_favoriteIds.contains(id);
    if (added) {
      _favoriteIds.add(id);
    } else {
      _favoriteIds.remove(id);
    }

    notifyListeners();
    _persist();
    return added;
  }

  Future<void> syncWithCloudForCurrentUser({
    bool pushLocalIfCloudEmpty = true,
  }) async {
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    if (userId == null || userId.isEmpty) return;

    try {
      final rows = await client
          .from('user_favorites')
          .select('product_id')
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      final remoteIds = List<Map<String, dynamic>>.from(rows)
          .map((row) => row['product_id']?.toString().trim() ?? '')
          .where((id) => id.isNotEmpty)
          .toSet();

      if (remoteIds.isNotEmpty) {
        _favoriteIds
          ..clear()
          ..addAll(remoteIds);
        notifyListeners();
        await _saveToLocal();
        return;
      }

      if (pushLocalIfCloudEmpty && _favoriteIds.isNotEmpty) {
        await _syncToCloud();
      }
    } catch (e) {
      debugPrint('Favorites cloud sync fetch failed: $e');
    }
  }

  void _persist() {
    unawaited(_saveToLocal());
    unawaited(_syncToCloud());
  }

  Future<void> _syncToCloud() async {
    if (_syncingCloud) return;

    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    if (userId == null || userId.isEmpty) return;

    _syncingCloud = true;
    try {
      await client.from('user_favorites').delete().eq('user_id', userId);
      if (_favoriteIds.isEmpty) return;

      final payload = _favoriteIds
          .map((id) => {'user_id': userId, 'product_id': id})
          .toList(growable: false);

      await client
          .from('user_favorites')
          .upsert(payload, onConflict: 'user_id,product_id');
    } catch (e) {
      debugPrint('Favorites cloud sync write failed: $e');
    } finally {
      _syncingCloud = false;
    }
  }

  Future<void> _saveToLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_storageKey, jsonEncode(_favoriteIds.toList()));
    } catch (_) {
      // Ignore persistence errors.
    }
  }
}
