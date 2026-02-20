import 'dart:convert';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../firebase_options.dart';
import '../../data/repositories/notification_repository.dart';
import 'tracking_service.dart';
import '../../presentation/routing/navigation_service.dart';
import '../../presentation/routing/route_names.dart';

/// Top-level handler required for background messages on Android.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  debugPrint('🔔 [BG] رسالة واردة: ${message.messageId}');
}

/// Unified notification service for Android + iOS.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  FirebaseMessaging get _messaging => FirebaseMessaging.instance;
  NotificationRepository _notificationRepository =
      SupabaseNotificationRepository();

  bool _initialized = false;
  Map<String, dynamic>? _pendingNavigationData;
  int _pendingNavigationAttempts = 0;

  void configure(NotificationRepository repository) {
    _notificationRepository = repository;
  }

  /// Call after [Firebase.initializeApp].
  Future<void> init({required String? phone}) async {
    if (_initialized) return;
    if (!Platform.isAndroid && !Platform.isIOS) {
      debugPrint('🔔 NotificationService is only configured for Android/iOS.');
      return;
    }

    _initialized = true;

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    await _initLocalNotifications();
    await _requestPermissions();
    _setupForegroundListener();
    _setupOnMessageOpenedApp();
    await _syncTokenWithSupabase(phone: phone);

    FirebaseMessaging.instance.onTokenRefresh.listen(
      (newToken) => _syncTokenWithSupabase(phone: phone, token: newToken),
    );

    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleMessageTap(initialMessage);
    }
    _flushPendingNavigation();
  }

  Future<void> _initLocalNotifications() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _flutterLocalNotificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        debugPrint('🔔 Local notification tapped: ${response.payload}');
        final payload = response.payload;
        if (payload == null || payload.isEmpty) return;
        try {
          final decoded = jsonDecode(payload);
          if (decoded is Map<String, dynamic>) {
            TrackingService.instance.trackEvent(
              eventName: 'notification_opened',
              eventCategory: 'notification',
              screen: 'local',
              metadata: decoded,
            );
            _handleNotificationData(decoded);
          } else if (decoded is Map) {
            final casted = Map<String, dynamic>.from(decoded);
            TrackingService.instance.trackEvent(
              eventName: 'notification_opened',
              eventCategory: 'notification',
              screen: 'local',
              metadata: casted,
            );
            _handleNotificationData(casted);
          }
        } catch (_) {
          // Ignore invalid payloads.
        }
      },
    );

    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'high_importance_channel',
      'High Importance Notifications',
      description: 'This channel is used for important notifications.',
      importance: Importance.max,
      playSound: true,
    );

    await _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  Future<void> _requestPermissions() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      announcement: false,
      carPlay: false,
      provisional: false,
      criticalAlert: false,
    );

    debugPrint(
        '🔔 Notification permission status: ${settings.authorizationStatus}');

    if (Platform.isIOS) {
      await _messaging.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
    }
  }

  void _setupForegroundListener() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('🔔 [FG] رسالة واردة: ${message.messageId}');
      final notification = message.notification;
      final android = notification?.android;

      if (notification != null && (android != null || Platform.isIOS)) {
        _showLocalNotification(
          title: notification.title,
          body: notification.body,
          payload: message.data,
        );
      }
      TrackingService.instance.trackEvent(
        eventName: 'notification_received',
        eventCategory: 'notification',
        screen: 'foreground',
        metadata: message.data,
      );
    });
  }

  void _setupOnMessageOpenedApp() {
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageTap);
  }

  Future<void> _showLocalNotification({
    required String? title,
    required String? body,
    Map<String, dynamic>? payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'high_importance_channel',
      'High Importance Notifications',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
    );

    const iosDetails = DarwinNotificationDetails();

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _flutterLocalNotificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title ?? 'إشعار',
      body ?? '',
      details,
      payload: payload == null ? null : jsonEncode(payload),
    );
  }

  void _handleMessageTap(RemoteMessage message) {
    debugPrint('🔔 المستخدم ضغط على الإشعار: ${message.messageId}');
    debugPrint('🔔 data: ${message.data}');
    TrackingService.instance.trackEvent(
      eventName: 'notification_opened',
      eventCategory: 'notification',
      screen: 'push',
      metadata: message.data,
    );
    _handleNotificationData(message.data);
  }

  Future<void> _handleNotificationData(Map<String, dynamic> data) async {
    final route = data['route']?.toString();
    final rawUrl = data['action_url']?.toString();
    if (route == 'external' ||
        ((route == null || route.isEmpty) && (rawUrl ?? '').isNotEmpty)) {
      if (rawUrl == null || rawUrl.isEmpty) return;
      final uri = Uri.tryParse(rawUrl);
      if (uri == null) return;
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return;
    }
    final navigator = NavigationService.navigatorKey.currentState;
    if (navigator == null) {
      _pendingNavigationData = data;
      _schedulePendingNavigation();
      return;
    }

    _navigateToRoute(route, data);
  }

  void _navigateToRoute(String? route, Map<String, dynamic>? data) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      switch (route) {
        case 'home':
          NavigationService.go(RouteNames.root);
          break;
        case 'notifications':
          NavigationService.go(RouteNames.notifications);
          break;
        case 'cart':
          NavigationService.go(RouteNames.cart);
          break;
        case 'donations':
        case 'freebies':
          NavigationService.go(RouteNames.freebies);
          break;
        case 'tracking':
          final orderId = data?['order_id']?.toString() ??
              data?['order_number']?.toString();
          if (orderId != null && orderId.isNotEmpty) {
            NavigationService.goToOrderTracking(orderId);
          }
          break;
        case 'category':
          final categoryId = data?['category_id']?.toString();
          if (categoryId != null && categoryId.isNotEmpty) {
            NavigationService.goToCategoryProducts(categoryId);
          }
          break;
        case 'product':
          final productId = data?['product_id']?.toString();
          if (productId != null && productId.isNotEmpty) {
            NavigationService.goToProductDetail(productId);
          }
          break;
        case 'external':
          final url = data?['url']?.toString();
          if (url != null && url.isNotEmpty) {
            final uri = Uri.tryParse(url);
            if (uri != null) {
              launchUrl(uri, mode: LaunchMode.externalApplication);
            }
          }
          break;
        default:
          break;
      }
    });
  }

  Future<void> handleNotificationRecord(Map<String, dynamic> record) async {
    final normalized = _normalizeNotificationRecord(record);
    await _handleNotificationData(normalized);
  }

  Map<String, dynamic> _normalizeNotificationRecord(
    Map<String, dynamic> record,
  ) {
    final normalized = <String, dynamic>{};

    for (final entry in record.entries) {
      normalized[entry.key] = entry.value;
    }

    void mergePayload(dynamic payload) {
      if (payload is Map) {
        normalized.addAll(Map<String, dynamic>.from(payload));
      } else if (payload is String && payload.isNotEmpty) {
        try {
          final decoded = jsonDecode(payload);
          if (decoded is Map) {
            normalized.addAll(Map<String, dynamic>.from(decoded));
          }
        } catch (_) {
          // Ignore invalid payloads.
        }
      }
    }

    mergePayload(record['data']);
    mergePayload(record['payload']);
    mergePayload(record['meta']);
    mergePayload(record['metadata']);
    mergePayload(record['extra']);
    mergePayload(record['extra_data']);
    mergePayload(record['notification_data']);
    mergePayload(record['payload_data']);
    mergePayload(record['fcm_data']);

    String? pickFirstValue(List<String> keys) {
      for (final key in keys) {
        final value = normalized[key] ?? record[key];
        if (value == null) continue;
        final text = value.toString().trim();
        if (text.isNotEmpty) return text;
      }
      return null;
    }

    bool isKnownRoute(String? value) {
      if (value == null) return false;
      const known = {
        'home',
        'notifications',
        'cart',
        'donations',
        'tracking',
        'category',
        'product',
        'external',
      };
      return known.contains(value);
    }

    final routed = pickFirstValue([
      'route',
      'target_route',
      'screen',
      'action',
      'type',
    ]);
    if (normalized['route'] == null || normalized['route'].toString().isEmpty) {
      if (isKnownRoute(routed)) {
        normalized['route'] = routed;
      }
    }

    normalized['action_url'] ??= pickFirstValue([
      'action_url',
      'url',
      'link',
      'deep_link',
      'deepLink',
      'actionUrl',
    ]);

    normalized['product_id'] ??= pickFirstValue([
      'product_id',
      'productId',
      'productID',
      'item_id',
      'itemId',
    ]);

    normalized['category_id'] ??= pickFirstValue([
      'category_id',
      'categoryId',
    ]);

    normalized['category_name'] ??= pickFirstValue([
      'category_name',
      'categoryName',
    ]);

    normalized['order_number'] ??= pickFirstValue([
      'order_number',
      'orderNumber',
      'order_no',
      'orderNo',
    ]);

    final productPayload = normalized['product'];
    if (normalized['product_id'] == null && productPayload is Map) {
      final productId = productPayload['id'] ?? productPayload['product_id'];
      if (productId != null) {
        normalized['product_id'] = productId.toString();
      }
    }

    final categoryPayload = normalized['category'];
    if (categoryPayload is Map) {
      if (normalized['category_id'] == null && categoryPayload['id'] != null) {
        normalized['category_id'] = categoryPayload['id'].toString();
      }
      if (normalized['category_name'] == null &&
          categoryPayload['name'] != null) {
        normalized['category_name'] = categoryPayload['name'].toString();
      }
    }

    normalized['route'] ??= record['route'];
    normalized['action_url'] ??= record['action_url'];
    normalized['product_id'] ??= record['product_id'];
    normalized['category_id'] ??= record['category_id'];
    normalized['category_name'] ??= record['category_name'];
    normalized['order_number'] ??= record['order_number'];

    return normalized;
  }

  void _schedulePendingNavigation() {
    if (_pendingNavigationAttempts >= 5) return;
    _pendingNavigationAttempts += 1;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _flushPendingNavigation();
    });
  }

  void _flushPendingNavigation() {
    if (_pendingNavigationData == null) return;
    final data = _pendingNavigationData;
    _pendingNavigationData = null;
    _handleNotificationData(data!);
  }

  Future<void> _syncTokenWithSupabase({
    required String? phone,
    String? token,
  }) async {
    try {
      final resolvedToken = token ?? await _messaging.getToken();
      debugPrint('🔔 FCM TOKEN: $resolvedToken');

      if (resolvedToken == null) return;

      final platformLabel = Platform.isAndroid ? 'android' : 'ios';

      if (phone == null || phone.trim().isEmpty) return;

      await _notificationRepository.saveDeviceToken(
        token: resolvedToken,
        phone: phone,
        platform: platformLabel,
      );

      debugPrint('🔔 save_device_token RPC OK');
    } on PostgrestException catch (e, st) {
      debugPrint('❌ RLS / RPC error while saving device token: ${e.message}');
      debugPrint('$st');
    } catch (e, st) {
      debugPrint('❌ Unexpected error while saving device token: $e');
      debugPrint('$st');
    }
  }
}
