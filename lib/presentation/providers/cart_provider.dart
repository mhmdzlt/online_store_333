import 'dart:convert';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/models/cart/cart_item_model.dart';
import '../../core/services/tracking_service.dart';

class CartProvider extends ChangeNotifier {
  final List<CartItemModel> _items = [];
  String? _sellerId;
  bool _syncingCloud = false;

  List<CartItemModel> get items => List.unmodifiable(_items);
  String? get sellerId => _sellerId;

  double get subtotal => _items.fold(0, (sum, item) => sum + item.lineTotal);

  bool addToCart({
    required String productId,
    required String productName,
    required String imageUrl,
    required String sellerId,
    String? size,
    String? color,
    required double unitPrice,
    int quantity = 1,
  }) {
    if (_sellerId != null && _sellerId != sellerId) {
      return false;
    }

    _sellerId ??= sellerId;

    final index = _items.indexWhere((item) =>
        item.productId == productId &&
        item.size == size &&
        item.color == color);

    if (index >= 0) {
      final current = _items[index];
      _items[index] = current.copyWith(quantity: current.quantity + quantity);
    } else {
      final id = '${productId}_${size ?? ''}_${color ?? ''}';
      _items.add(CartItemModel(
        id: id,
        productId: productId,
        productName: productName,
        productImage: imageUrl,
        sellerId: sellerId,
        size: size,
        color: color,
        quantity: quantity,
        price: unitPrice,
      ));
    }

    notifyListeners();
    TrackingService.instance.trackCartAdd(productId, quantity);
    _persistCart();
    return true;
  }

  void updateQuantity(CartItemModel item, int quantity) {
    if (quantity <= 0) {
      _items.remove(item);
    } else {
      final index = _items.indexOf(item);
      if (index >= 0) {
        _items[index] = item.copyWith(quantity: quantity);
      }
    }
    if (_items.isEmpty) {
      _sellerId = null;
    }
    notifyListeners();
    if (quantity <= 0) {
      TrackingService.instance.trackCartRemove(item.productId, quantity);
    }
    _persistCart();
  }

  void removeItem(CartItemModel item) {
    _items.remove(item);
    if (_items.isEmpty) {
      _sellerId = null;
    }
    notifyListeners();
    TrackingService.instance.trackCartRemove(item.productId, 0);
    _persistCart();
  }

  void clear() {
    _clearInMemory();
    _persistCart();
  }

  Future<void> clearAndSync() async {
    _clearInMemory();
    await _saveToLocalStorage();
    await _syncCartToCloud();
  }

  void _clearInMemory() {
    _items.clear();
    _sellerId = null;
    notifyListeners();
    TrackingService.instance.trackEvent(
      eventName: 'cart_clear',
      eventCategory: 'cart',
      screen: 'cart',
    );
  }

  Future<void> loadCartFromStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cartJson = prefs.getString('cart_items');
      if (cartJson != null && cartJson.isNotEmpty) {
        final List<dynamic> raw = jsonDecode(cartJson);
        _items
          ..clear()
          ..addAll(raw.map((item) =>
              CartItemModel.fromMap(Map<String, dynamic>.from(item))));

        if (_items.isNotEmpty) {
          _sellerId = _items.first.sellerId;
        }

        notifyListeners();
      }

      await syncWithCloudForCurrentUser();
    } catch (_) {
      // Ignore corrupted cache.
    }
  }

  Future<void> syncWithCloudForCurrentUser({
    bool pushLocalIfCloudEmpty = true,
  }) async {
    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    if (userId == null || userId.isEmpty) return;

    try {
      final rows = await client
          .from('user_cart_items')
          .select(
              'item_id, product_id, product_name, product_image, price, quantity, seller_id, size, color')
          .eq('user_id', userId)
          .order('updated_at', ascending: false);

      final cloudItems = List<Map<String, dynamic>>.from(rows)
          .map(
            (row) => CartItemModel(
              id: row['item_id']?.toString() ?? '',
              productId: row['product_id']?.toString() ?? '',
              productName: row['product_name']?.toString() ?? '',
              productImage: row['product_image']?.toString(),
              price: (row['price'] as num?)?.toDouble() ?? 0,
              quantity: (row['quantity'] as num?)?.toInt() ?? 1,
              sellerId: row['seller_id']?.toString(),
              size: row['size']?.toString(),
              color: row['color']?.toString(),
            ),
          )
          .where((item) =>
              item.id.isNotEmpty &&
              item.productId.isNotEmpty &&
              item.quantity > 0 &&
              item.price >= 0)
          .toList();

      if (cloudItems.isNotEmpty) {
        _items
          ..clear()
          ..addAll(cloudItems);
        _sellerId = _items.first.sellerId;
        notifyListeners();
        await _saveToLocalStorage();
        return;
      }

      if (pushLocalIfCloudEmpty && _items.isNotEmpty) {
        await _syncCartToCloud();
      }
    } catch (e) {
      debugPrint('Cart cloud sync fetch failed: $e');
    }
  }

  void _persistCart() {
    unawaited(_saveToLocalStorage());
    unawaited(_syncCartToCloud());
  }

  Future<void> _syncCartToCloud() async {
    if (_syncingCloud) return;

    final client = Supabase.instance.client;
    final userId = client.auth.currentUser?.id;
    if (userId == null || userId.isEmpty) return;

    _syncingCloud = true;
    try {
      await client.from('user_cart_items').delete().eq('user_id', userId);
      if (_items.isEmpty) return;

      final payload = _items
          .map(
            (item) => {
              'user_id': userId,
              'item_id': item.id,
              'product_id': item.productId,
              'product_name': item.productName,
              'product_image': item.productImage,
              'price': item.price,
              'quantity': item.quantity,
              'seller_id': (item.sellerId == null || item.sellerId!.isEmpty)
                  ? null
                  : item.sellerId,
              'size': item.size,
              'color': item.color,
            },
          )
          .toList(growable: false);

      await client
          .from('user_cart_items')
          .upsert(payload, onConflict: 'user_id,item_id');
    } catch (e) {
      debugPrint('Cart cloud sync write failed: $e');
    } finally {
      _syncingCloud = false;
    }
  }

  Future<void> _saveToLocalStorage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final payload = jsonEncode(_items.map((e) => e.toMap()).toList());
      await prefs.setString('cart_items', payload);
    } catch (_) {
      // Ignore persistence errors.
    }
  }
}
