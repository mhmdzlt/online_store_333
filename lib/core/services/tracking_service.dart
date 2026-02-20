import 'package:flutter/material.dart';

class TrackingService {
  TrackingService._();

  static final TrackingService instance = TrackingService._();

  Future<void> init({String? userId}) async {}

  Future<void> setTrackingEnabled(bool enabled) async {}

  Future<void> setUserId(String? userId) async {}

  Future<void> trackScreen(String screen) async {}

  Future<void> trackProductView(String productId) async {}

  Future<void> trackCartAdd(String productId, int quantity) async {}

  Future<void> trackCartRemove(String productId, int quantity) async {}

  Future<void> trackFavoriteAdd(String productId) async {}

  Future<void> trackFavoriteRemove(String productId) async {}

  Future<void> trackLogin({String? method}) async {}

  Future<void> trackLogout() async {}

  Future<void> trackSearch({
    required String screen,
    required String query,
  }) async {}

  Future<void> trackEvent({
    required String eventName,
    String? eventCategory,
    String? screen,
    Map<String, dynamic>? metadata,
  }) async {}
}

class TrackingNavigatorObserver extends NavigatorObserver {
  TrackingNavigatorObserver();
}
