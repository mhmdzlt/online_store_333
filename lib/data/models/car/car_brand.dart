class CarBrand {
  final String id;
  final String name;
  final String? imageUrl;

  const CarBrand({
    required this.id,
    required this.name,
    this.imageUrl,
  });

  factory CarBrand.fromMap(Map<String, dynamic> map) {
    return CarBrand(
      id: map['id'] as String,
      name: map['name'] as String,
      imageUrl: map['image_url'] as String?,
    );
  }
}
