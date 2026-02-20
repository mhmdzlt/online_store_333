class NotificationModel {
  final String id;
  final String title;
  final String body;
  final String? route;
  final String? targetType;
  final Map<String, dynamic> payload;
  final Map<String, dynamic> raw;
  final DateTime? createdAt;

  const NotificationModel({
    required this.id,
    required this.title,
    required this.body,
    required this.payload,
    required this.raw,
    this.route,
    this.targetType,
    this.createdAt,
  });

  factory NotificationModel.fromMap(Map<String, dynamic> map) {
    return NotificationModel(
      id: map['id']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      body: map['body']?.toString() ?? '',
      route: map['route']?.toString(),
      targetType: map['target_type']?.toString(),
      payload: Map<String, dynamic>.from(map['payload'] as Map? ?? {}),
      raw: Map<String, dynamic>.from(map),
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    if (raw.isNotEmpty) return Map<String, dynamic>.from(raw);
    return {
      'id': id,
      'title': title,
      'body': body,
      'route': route,
      'target_type': targetType,
      'payload': payload,
      'created_at': createdAt?.toIso8601String(),
    };
  }
}
