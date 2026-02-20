import '../datasources/remote/supabase_notification_datasource.dart';
import '../models/notification/notification_model.dart';

abstract class NotificationRepository {
  Stream<List<NotificationModel>> streamGeneralNotifications();
  Future<List<NotificationModel>> fetchGeneralNotifications();
  Future<List<NotificationModel>> fetchPhoneNotifications(String phone);
  Future<List<NotificationModel>> fetchOrderNotifications(String orderNumber);
  Future<List<NotificationModel>> getNotificationsPublic({
    required String phone,
    required String token,
    String? orderNumber,
  });

  Future<void> saveDeviceToken({
    required String token,
    required String phone,
    required String platform,
  });
}

class SupabaseNotificationRepository implements NotificationRepository {
  SupabaseNotificationRepository({SupabaseNotificationDataSource? dataSource})
      : _dataSource = dataSource ?? SupabaseNotificationDataSource();

  final SupabaseNotificationDataSource _dataSource;

  @override
  Stream<List<NotificationModel>> streamGeneralNotifications() {
    return _dataSource.streamGeneralNotifications().map(
          (rows) => rows
              .map(NotificationModel.fromMap)
              .toList(growable: false),
        );
  }

  @override
  Future<List<NotificationModel>> fetchGeneralNotifications() async {
    final rows = await _dataSource.fetchGeneralNotifications();
    return rows.map(NotificationModel.fromMap).toList(growable: false);
  }

  @override
  Future<List<NotificationModel>> fetchPhoneNotifications(String phone) async {
    final rows = await _dataSource.fetchPhoneNotifications(phone);
    return rows.map(NotificationModel.fromMap).toList(growable: false);
  }

  @override
  Future<List<NotificationModel>> fetchOrderNotifications(
      String orderNumber) async {
    final rows = await _dataSource.fetchOrderNotifications(orderNumber);
    return rows.map(NotificationModel.fromMap).toList(growable: false);
  }

  @override
  Future<List<NotificationModel>> getNotificationsPublic({
    required String phone,
    required String token,
    String? orderNumber,
  }) async {
    final rows = await _dataSource.getNotificationsPublic(
      phone: phone,
      token: token,
      orderNumber: orderNumber,
    );
    return rows.map(NotificationModel.fromMap).toList(growable: false);
  }

  @override
  Future<void> saveDeviceToken({
    required String token,
    required String phone,
    required String platform,
  }) {
    return _dataSource.saveDeviceToken(
      token: token,
      phone: phone,
      platform: platform,
    );
  }
}
