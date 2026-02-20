import '../enums/order_status.dart';

class Order {
  const Order({
    required this.id,
    required this.itemsCount,
    required this.total,
    required this.status,
    required this.createdAt,
    this.phone,
  });

  final String id;
  final int itemsCount;
  final double total;
  final OrderStatus status;
  final DateTime createdAt;
  final String? phone;
}
