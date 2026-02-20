import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../utils/local_storage.dart';
import 'route_names.dart';

class NavigationService {
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  static BuildContext get context =>
      navigatorKey.currentState!.overlay!.context;

  static void go(String path, {Object? extra}) {
    GoRouter.of(context).go(path, extra: extra);
  }

  static void push(String path, {Object? extra}) {
    GoRouter.of(context).push(path, extra: extra);
  }

  static void pop([dynamic result]) {
    GoRouter.of(context).pop(result);
  }

  static void replace(String path, {Object? extra}) {
    GoRouter.of(context).replace(path, extra: extra);
  }

  static void goToProductDetail(String productId) {
    go(RouteNames.productDetailPath(productId));
  }

  static void pushToProductDetail(String productId) {
    push(RouteNames.productDetailPath(productId));
  }

  static void goToCart() {
    go(RouteNames.cart);
  }

  static void goToCheckout() {
    go(RouteNames.checkout);
  }

  static void goToOrderTracking(String orderId) {
    go(RouteNames.orderTrackingPath(orderId));
  }

  static void goToOrderTrackingHome() {
    go(RouteNames.orderTrackingHome);
  }

  static void goToFreebieDetail(String freebieId) {
    go(RouteNames.freebieDetailPath(freebieId));
  }

  static String buildCategoryProductsPath(String categoryId, {String? name}) {
    final base = RouteNames.categoryProductsPath(categoryId);
    if (name == null || name.trim().isEmpty) {
      return base;
    }
    final encodedName = Uri.encodeComponent(name);
    return '$base?name=$encodedName';
  }

  static void goToCategoryProducts(String categoryId, {String? name}) {
    go(buildCategoryProductsPath(categoryId, name: name));
  }

  static bool handleDeepLink(Uri uri) {
    final referralCode = uri.queryParameters['ref'];
    if (referralCode != null && referralCode.trim().isNotEmpty) {
      unawaited(
        LocalStorage.saveInfluencerReferralCode(
          referralCode,
          source: uri.toString(),
        ),
      );
    }

    final path = uri.path;
    if (path.startsWith('/product/')) {
      go(path);
      return true;
    }
    if (path.startsWith('/category/')) {
      go(path + (uri.hasQuery ? '?${uri.query}' : ''));
      return true;
    }
    if (path.startsWith('/freebie/')) {
      go(path);
      return true;
    }
    if (path.startsWith('/order/')) {
      go(path);
      return true;
    }
    if (path == RouteNames.cart ||
        path == RouteNames.checkout ||
        path == RouteNames.notifications ||
        path == RouteNames.freebies ||
        path == RouteNames.categories ||
        path == RouteNames.orderTrackingHome) {
      go(path);
      return true;
    }
    return false;
  }
}
