import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'route_names.dart';

class NavigationHelpers {
  static void go(BuildContext context, String path, {Object? extra}) {
    GoRouter.of(context).go(path, extra: extra);
  }

  static Future<T?> push<T>(BuildContext context, String path,
      {Object? extra}) {
    return GoRouter.of(context).push<T>(path, extra: extra);
  }

  static void replace(BuildContext context, String path, {Object? extra}) {
    GoRouter.of(context).replace(path, extra: extra);
  }

  static void pop<T>(BuildContext context, [T? result]) {
    GoRouter.of(context).pop(result);
  }

  static void goToProductDetail(BuildContext context, String productId) {
    push(context, RouteNames.productDetailPath(productId));
  }

  static void goToCategoryProducts(
    BuildContext context,
    String categoryId, {
    String? name,
  }) {
    final base = RouteNames.categoryProductsPath(categoryId);
    if (name == null || name.trim().isEmpty) {
      push(context, base);
      return;
    }
    final encodedName = Uri.encodeComponent(name);
    push(context, '$base?name=$encodedName');
  }

  static void goToCart(BuildContext context) {
    push(context, RouteNames.cart);
  }

  static void goToFavorites(BuildContext context) {
    push(context, RouteNames.favorites);
  }

  static void goToInfluencerPartnership(BuildContext context) {
    push(context, RouteNames.influencerPartnership);
  }

  static void goToCheckout(BuildContext context) {
    push(context, RouteNames.checkout);
  }

  static void goToNotifications(BuildContext context) {
    push(context, RouteNames.notifications);
  }

  static void goToFreebies(BuildContext context) {
    push(context, RouteNames.freebies);
  }

  static void goToFreebieDetail(BuildContext context, String freebieId) {
    push(context, RouteNames.freebieDetailPath(freebieId));
  }

  static void goToOrderTrackingHome(BuildContext context) {
    push(context, RouteNames.orderTrackingHome);
  }

  static void goToOrderTracking(
    BuildContext context,
    String orderId, {
    String? phone,
  }) {
    push(context, RouteNames.orderTrackingPath(orderId), extra: {
      if (phone != null && phone.isNotEmpty) 'phone': phone,
    });
  }
}
