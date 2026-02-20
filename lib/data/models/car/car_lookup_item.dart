class CarLookupItem {
  final String id;
  final String name;
  final Map<String, dynamic> raw;

  const CarLookupItem({
    required this.id,
    required this.name,
    required this.raw,
  });

  factory CarLookupItem.fromMap(Map<String, dynamic> map) {
    String pickName() {
      const keys = [
        'name',
        'model',
        'year',
        'trim',
        'section',
        'subsection',
        'title',
      ];
      for (final key in keys) {
        final value = map[key];
        if (value == null) continue;
        final text = value.toString().trim();
        if (text.isNotEmpty) return text;
      }
      return '';
    }

    return CarLookupItem(
      id: map['id']?.toString() ?? '',
      name: pickName(),
      raw: Map<String, dynamic>.from(map),
    );
  }

  Map<String, dynamic> toMap() => Map<String, dynamic>.from(raw);
}
