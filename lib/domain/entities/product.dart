import '../enums/product_condition.dart';

class Product {
  const Product({
    required this.id,
    required this.name,
    required this.price,
    required this.imageUrl,
    this.description,
    this.categoryId,
    this.stockQuantity,
    this.rating,
    this.images,
    this.condition = ProductCondition.newCondition,
  });

  final String id;
  final String name;
  final double price;
  final String imageUrl;
  final String? description;
  final String? categoryId;
  final int? stockQuantity;
  final double? rating;
  final List<String>? images;
  final ProductCondition condition;
}
