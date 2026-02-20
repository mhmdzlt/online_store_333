class CategoryModel {
  final String id;
  final String name;
  final String? imageUrl;
  final int? sortOrder;

  const CategoryModel({
    required this.id,
    required this.name,
    this.imageUrl,
    this.sortOrder,
  });

  factory CategoryModel.fromMap(Map<String, dynamic> map) {
    return CategoryModel(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      imageUrl: map['image_url']?.toString(),
      sortOrder: (map['sort_order'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'image_url': imageUrl,
      'sort_order': sortOrder,
    };
  }
}
