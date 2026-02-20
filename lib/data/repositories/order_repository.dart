import '../datasources/remote/supabase_order_datasource.dart';

abstract class OrderRepository {
  Future<Map<String, dynamic>> createOrderPublic({
    required String customerName,
    required String phone,
    required String city,
    String? area,
    required String address,
    String? notes,
    required String shippingMethod,
    required String paymentMethod,
    required List<Map<String, dynamic>> items,
    num shippingCost,
    num discountAmount,
    String? orderNumber,
    String? influencerRefCode,
  });

  Future<Map<String, dynamic>?> trackOrder({
    required String orderNumber,
    required String phone,
  });

  Future<List<Map<String, dynamic>>> fetchMyOrders({int limit});
}

class SupabaseOrderRepository implements OrderRepository {
  SupabaseOrderRepository({SupabaseOrderDataSource? dataSource})
      : _dataSource = dataSource ?? SupabaseOrderDataSource();

  final SupabaseOrderDataSource _dataSource;

  @override
  Future<Map<String, dynamic>> createOrderPublic({
    required String customerName,
    required String phone,
    required String city,
    String? area,
    required String address,
    String? notes,
    required String shippingMethod,
    required String paymentMethod,
    required List<Map<String, dynamic>> items,
    num shippingCost = 0,
    num discountAmount = 0,
    String? orderNumber,
    String? influencerRefCode,
  }) {
    return _dataSource.createOrderPublic(
      customerName: customerName,
      phone: phone,
      city: city,
      area: area,
      address: address,
      notes: notes,
      shippingMethod: shippingMethod,
      paymentMethod: paymentMethod,
      items: items,
      shippingCost: shippingCost,
      discountAmount: discountAmount,
      orderNumber: orderNumber,
      influencerRefCode: influencerRefCode,
    );
  }

  @override
  Future<Map<String, dynamic>?> trackOrder({
    required String orderNumber,
    required String phone,
  }) {
    return _dataSource.trackOrder(orderNumber: orderNumber, phone: phone);
  }

  @override
  Future<List<Map<String, dynamic>>> fetchMyOrders({int limit = 20}) {
    return _dataSource.fetchMyOrders(limit: limit);
  }
}
