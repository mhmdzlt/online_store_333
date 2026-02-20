import 'dart:convert';

import '../../../utils/image_resolvers.dart';

class ProductModel {
  final String id;
  final String name;
  final String description;
  final double price;
  final String imageUrl;
  final String categoryId;
  final int stock;
  final String? sellerId;
  final double? oldPrice;
  final String? currency;
  final String? carBrandId;
  final String? carModelId;
  final String? carTrimId;
  final String? carGenerationId;
  final String? carSectionV2Id;
  final String? carSubsectionId;
  final String? extraInfo;
  final String? returnPolicy;
  final bool isActive;
  final bool isFeatured;
  final bool isBestSeller;
  final DateTime? createdAt;
  final List<Map<String, dynamic>> productImages;
  final List<String> imageUrls;
  final int? salesCount;

  const ProductModel({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.imageUrl,
    required this.categoryId,
    required this.stock,
    this.sellerId,
    this.oldPrice,
    this.currency,
    this.carBrandId,
    this.carModelId,
    this.carTrimId,
    this.carGenerationId,
    this.carSectionV2Id,
    this.carSubsectionId,
    this.extraInfo,
    this.returnPolicy,
    this.isActive = true,
    this.isFeatured = false,
    this.isBestSeller = false,
    this.createdAt,
    this.productImages = const [],
    this.imageUrls = const [],
    this.salesCount,
  });

  factory ProductModel.fromMap(Map<String, dynamic> map) {
    final rawImages = map['product_images'];
    final images = rawImages is List
        ? rawImages
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList()
        : <Map<String, dynamic>>[];

    final imageUrls = _extractImageUrls(images, map['image_url']);
    final primaryImageUrl = imageUrls.isNotEmpty
        ? imageUrls.first
        : _sanitizeSingleImageUrl(map['image_url']);

    return ProductModel(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      description: map['description']?.toString() ?? '',
      price: (map['price'] as num?)?.toDouble() ?? 0,
      imageUrl: primaryImageUrl,
      categoryId: map['category_id']?.toString() ?? '',
      stock: (map['stock'] as num?)?.toInt() ?? 0,
      sellerId: map['seller_id']?.toString(),
      oldPrice: (map['old_price'] as num?)?.toDouble(),
      currency: map['currency']?.toString(),
      carBrandId: map['car_brand_id']?.toString(),
      carModelId: map['car_model_id']?.toString(),
      carTrimId: map['car_trim_id']?.toString(),
      carGenerationId: map['car_generation_id']?.toString(),
      carSectionV2Id: map['car_section_v2_id']?.toString(),
      carSubsectionId: map['car_subsection_id']?.toString(),
      extraInfo: map['extra_info']?.toString(),
      returnPolicy: map['return_policy']?.toString(),
      isActive: (map['is_active'] as bool?) ?? true,
      isFeatured: (map['is_featured'] as bool?) ?? false,
      isBestSeller: (map['is_best_seller'] as bool?) ?? false,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString())
          : null,
      productImages: images,
      imageUrls: imageUrls,
      salesCount: (map['sales_count'] as num?)?.toInt(),
    );
  }

  static List<String> _extractImageUrls(
    List<Map<String, dynamic>> productImages,
    dynamic rawImageUrl,
  ) {
    final imageUrls = <String>[];
    if (productImages.isNotEmpty) {
      final images = productImages.toList()
        ..sort((a, b) {
          final aOrder = (a['sort_order'] as num?)?.toInt() ?? 0;
          final bOrder = (b['sort_order'] as num?)?.toInt() ?? 0;
          return bOrder.compareTo(aOrder);
        });

      for (final img in images) {
        final url = (img['image_url'] as String? ?? '').trim();
        if (isValidNetworkImageUrl(url)) {
          imageUrls.add(url);
        }
      }
    }

    final raw = rawImageUrl?.toString().trim() ?? '';
    if (isValidNetworkImageUrl(raw)) {
      imageUrls.add(raw);
    }

    return imageUrls;
  }

  static String _sanitizeSingleImageUrl(dynamic rawImageUrl) {
    final raw = rawImageUrl?.toString().trim() ?? '';
    return isValidNetworkImageUrl(raw) ? raw : '';
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'price': price,
      'image_url': imageUrl,
      'category_id': categoryId,
      'stock': stock,
      'seller_id': sellerId,
      'old_price': oldPrice,
      'currency': currency,
      'car_brand_id': carBrandId,
      'car_model_id': carModelId,
      'car_trim_id': carTrimId,
      'car_generation_id': carGenerationId,
      'car_section_v2_id': carSectionV2Id,
      'car_subsection_id': carSubsectionId,
      'extra_info': extraInfo,
      'return_policy': returnPolicy,
      'is_active': isActive,
      'is_featured': isFeatured,
      'is_best_seller': isBestSeller,
      'created_at': createdAt?.toIso8601String(),
      'product_images': productImages,
      'sales_count': salesCount,
    };
  }

  Map<String, dynamic>? get extraInfoMap {
    final raw = extraInfo;
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {}
    return null;
  }

  DateTime? get discountEndAt {
    final value = extraInfoMap?['discount_end_at']?.toString();
    if (value == null || value.trim().isEmpty) return null;
    return DateTime.tryParse(value);
  }

  bool get isDiscountActive {
    final old = oldPrice;
    if (old == null || old <= price) return false;
    final endAt = discountEndAt;
    if (endAt == null) return true;
    return DateTime.now().isBefore(endAt.toLocal());
  }

  double? get effectiveOldPrice {
    return isDiscountActive ? oldPrice : null;
  }

  int get effectiveDiscountPercent {
    final old = effectiveOldPrice;
    if (old == null || old <= 0 || old <= price) return 0;
    return (((old - price) / old) * 100).round();
  }
}
