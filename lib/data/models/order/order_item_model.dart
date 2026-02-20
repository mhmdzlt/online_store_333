class OrderItemModel {
  final String productId;
  final String productName;
  final int quantity;
  final String? size;
  final String? color;
  final double? lineTotal;

  const OrderItemModel({
    required this.productId,
    required this.productName,
    required this.quantity,
    this.size,
    this.color,
    this.lineTotal,
  });

  factory OrderItemModel.fromMap(Map<String, dynamic> map) {
    return OrderItemModel(
      productId: map['product_id']?.toString() ?? '',
      productName: map['product_name']?.toString() ?? '',
      quantity: (map['quantity'] as num?)?.toInt() ?? 0,
      size: map['size']?.toString(),
      color: map['color']?.toString(),
      lineTotal: (map['line_total'] as num?)?.toDouble() ??
          (map['total'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'product_id': productId,
      'product_name': productName,
      'quantity': quantity,
      'size': size,
      'color': color,
      'line_total': lineTotal,
    };
  }
}
