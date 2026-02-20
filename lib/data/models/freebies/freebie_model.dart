class FreebieModel {
  final String id;
  final String title;
  final String description;
  final String city;
  final String? area;
  final String status;
  final List<String> imageUrls;
  final DateTime? createdAt;
  final double? latitude;
  final double? longitude;
  final Map<String, dynamic> raw;

  const FreebieModel({
    required this.id,
    required this.title,
    required this.description,
    required this.city,
    required this.status,
    required this.imageUrls,
    required this.raw,
    this.createdAt,
    this.area,
    this.latitude,
    this.longitude,
  });

  factory FreebieModel.fromMap(Map<String, dynamic> map) {
    final rawImages = map['image_urls'];
    final images =
        rawImages is List ? rawImages.whereType<String>().toList() : <String>[];

    return FreebieModel(
      id: map['id']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      description: map['description']?.toString() ?? '',
      city: map['city']?.toString() ?? '',
      area: map['area']?.toString(),
      status: map['status']?.toString() ?? '',
      imageUrls: images,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString())
          : null,
      latitude: _readDouble(map, ['lat', 'latitude']),
      longitude: _readDouble(map, ['lng', 'longitude', 'lon']),
      raw: Map<String, dynamic>.from(map),
    );
  }

  Map<String, dynamic> toMap() {
    if (raw.isNotEmpty) return Map<String, dynamic>.from(raw);
    return {
      'id': id,
      'title': title,
      'description': description,
      'city': city,
      'area': area,
      'status': status,
      'image_urls': imageUrls,
      'created_at': createdAt?.toIso8601String(),
      'latitude': latitude,
      'longitude': longitude,
    };
  }

  static double? _readDouble(
    Map<String, dynamic> map,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = map[key];
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value);
    }
    return null;
  }
}
