import 'order_item_model.dart';

class OrderModel {
  final String orderNumber;
  final String customerName;
  final String phone;
  final String city;
  final String? area;
  final String address;
  final String? notes;
  final String shippingMethod;
  final String paymentMethod;
  final double shippingCost;
  final double discountAmount;
  final double? totalAmount;
  final String? status;
  final String? rejectionReason;
  final List<OrderItemModel> items;

  const OrderModel({
    required this.orderNumber,
    required this.customerName,
    required this.phone,
    required this.city,
    required this.address,
    required this.shippingMethod,
    required this.paymentMethod,
    required this.shippingCost,
    required this.discountAmount,
    required this.items,
    this.totalAmount,
    this.status,
    this.rejectionReason,
    this.area,
    this.notes,
  });

  factory OrderModel.fromMap(Map<String, dynamic> map) {
    final rawItems = map['items'] ?? map['order_items'];
    final items = rawItems is List
        ? rawItems
            .whereType<Map>()
            .map((e) => OrderItemModel.fromMap(Map<String, dynamic>.from(e)))
            .toList()
        : <OrderItemModel>[];

    return OrderModel(
      orderNumber: map['order_number']?.toString() ?? '',
      customerName: map['customer_name']?.toString() ?? '',
      phone: map['phone']?.toString() ?? '',
      city: map['city']?.toString() ?? '',
      area: map['area']?.toString(),
      address: map['address']?.toString() ?? '',
      notes: map['notes']?.toString(),
      shippingMethod: map['shipping_method']?.toString() ?? '',
      paymentMethod: map['payment_method']?.toString() ?? '',
      shippingCost: (map['shipping_cost'] as num?)?.toDouble() ?? 0,
      discountAmount: (map['discount_amount'] as num?)?.toDouble() ?? 0,
      totalAmount: (map['total_amount'] as num?)?.toDouble() ??
          (map['total'] as num?)?.toDouble(),
      status: map['status']?.toString(),
      rejectionReason: map['rejection_reason']?.toString(),
      items: items,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'order_number': orderNumber,
      'customer_name': customerName,
      'phone': phone,
      'city': city,
      'area': area,
      'address': address,
      'notes': notes,
      'shipping_method': shippingMethod,
      'payment_method': paymentMethod,
      'shipping_cost': shippingCost,
      'discount_amount': discountAmount,
      'total_amount': totalAmount,
      'status': status,
      'rejection_reason': rejectionReason,
      'items': items.map((e) => e.toMap()).toList(),
    };
  }
}
