class PromoBannerModel {
  PromoBannerModel({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.ctaText,
    required this.imageUrl,
    required this.backgroundColor,
    required this.textColor,
    required this.actionType,
    required this.actionValue,
    required this.heightFactor,
    required this.widthFactor,
    required this.ctaFullWidth,
    required this.raw,
  });

  final String id;
  final String title;
  final String subtitle;
  final String ctaText;
  final String imageUrl;
  final String backgroundColor;
  final String textColor;
  final String actionType;
  final String actionValue;
  final double heightFactor;
  final double widthFactor;
  final bool ctaFullWidth;
  final Map<String, dynamic> raw;

  factory PromoBannerModel.fromMap(Map<String, dynamic> map) {
    return PromoBannerModel(
      id: map['id']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      subtitle: map['subtitle']?.toString() ?? '',
      ctaText: map['cta_text']?.toString() ?? 'تسوّق الآن',
      imageUrl: map['image_url']?.toString() ?? '',
      backgroundColor: map['background_color']?.toString() ?? '#FF3B30',
      textColor: map['text_color']?.toString() ?? '#FFFFFF',
      actionType: map['action_type']?.toString() ?? '',
      actionValue: map['action_value']?.toString() ?? '',
      heightFactor: _parseHeightFactor(map['height_factor']),
      widthFactor: _parseWidthFactor(map['width_factor']),
      ctaFullWidth: _parseBool(map['cta_full_width'], fallback: true),
      raw: Map<String, dynamic>.from(map),
    );
  }

  Map<String, dynamic> toMap() => Map<String, dynamic>.from(raw);

  static double _parseHeightFactor(dynamic value) {
    if (value is num) {
      return value.toDouble().clamp(0.7, 2.0);
    }
    final parsed = double.tryParse(value?.toString() ?? '');
    if (parsed == null) return 1.0;
    return parsed.clamp(0.7, 2.0);
  }

  static bool _parseBool(dynamic value, {required bool fallback}) {
    if (value is bool) return value;
    final normalized = value?.toString().trim().toLowerCase();
    if (normalized == 'true' || normalized == '1') return true;
    if (normalized == 'false' || normalized == '0') return false;
    return fallback;
  }

  static double _parseWidthFactor(dynamic value) {
    if (value is num) {
      return value.toDouble().clamp(0.7, 1.0);
    }
    final parsed = double.tryParse(value?.toString() ?? '');
    if (parsed == null) return 1.0;
    return parsed.clamp(0.7, 1.0);
  }
}
