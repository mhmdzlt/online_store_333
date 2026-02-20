import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../../data/repositories/notification_repository.dart';

class DeviceTokenService {
  DeviceTokenService._();

  static final DeviceTokenService instance = DeviceTokenService._();

  FirebaseMessaging get _messaging => FirebaseMessaging.instance;
  NotificationRepository _notificationRepository =
      SupabaseNotificationRepository();

  void configure(NotificationRepository repository) {
    _notificationRepository = repository;
  }

  Future<void> registerDeviceToken({
    String? phone,
    String? platform,
  }) async {
    try {
      final settings = await _messaging.requestPermission();
      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        return;
      }

      final token = await _messaging.getToken();
      if (kDebugMode) {
        debugPrint('FCM token = $token');
      }
      if (token == null) return;

      final resolvedPlatform = platform ?? Platform.operatingSystem;

      if (phone != null && phone.isNotEmpty) {
        await _notificationRepository.saveDeviceToken(
          token: token,
          phone: phone,
          platform: resolvedPlatform,
        );
      }

      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
        if (kDebugMode) {
          debugPrint('FCM token refreshed = $newToken');
        }

        if (phone != null && phone.isNotEmpty) {
          await _notificationRepository.saveDeviceToken(
            token: newToken,
            phone: phone,
            platform: resolvedPlatform,
          );
        }
      });
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('Error registering device token: $e\n$st');
      }
    }
  }

  Future<void> updateDeviceWithPhoneAndOrder({
    required String phone,
    required String orderNumber,
  }) async {
    try {
      final token = await _messaging.getToken();
      if (token == null) return;

      await _notificationRepository.saveDeviceToken(
        token: token,
        phone: phone,
        platform: Platform.operatingSystem,
      );
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('Error updating device token metadata: $e\n$st');
      }
    }
  }
}
