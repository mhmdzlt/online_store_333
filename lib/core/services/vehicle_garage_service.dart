import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class VehicleGarageEntry {
  const VehicleGarageEntry({
    required this.brandId,
    required this.brandName,
    required this.modelId,
    required this.modelName,
    required this.yearId,
    required this.yearLabel,
    this.trimId,
    this.trimLabel,
  });

  final String brandId;
  final String brandName;
  final String modelId;
  final String modelName;
  final String yearId;
  final String yearLabel;
  final String? trimId;
  final String? trimLabel;

  String get key => '$brandId|$modelId|$yearId|${trimId ?? ''}';

  Map<String, dynamic> toJson() => <String, dynamic>{
    'brand_id': brandId,
    'brand_name': brandName,
    'model_id': modelId,
    'model_name': modelName,
    'year_id': yearId,
    'year_label': yearLabel,
    'trim_id': trimId,
    'trim_label': trimLabel,
  };

  static VehicleGarageEntry? tryFromJson(Object? value) {
    if (value is! Map) return null;

    String? s(Object? v) => v?.toString();

    final brandId = s(value['brand_id']);
    final brandName = s(value['brand_name']);
    final modelId = s(value['model_id']);
    final modelName = s(value['model_name']);
    final yearId = s(value['year_id']);
    final yearLabel = s(value['year_label']);
    final trimId = s(value['trim_id']);
    final trimLabel = s(value['trim_label']);

    if (brandId == null ||
        brandName == null ||
        modelId == null ||
        modelName == null ||
        yearId == null ||
        yearLabel == null) {
      return null;
    }

    return VehicleGarageEntry(
      brandId: brandId,
      brandName: brandName,
      modelId: modelId,
      modelName: modelName,
      yearId: yearId,
      yearLabel: yearLabel,
      trimId: (trimId == null || trimId.trim().isEmpty) ? null : trimId,
      trimLabel: (trimLabel == null || trimLabel.trim().isEmpty)
          ? null
          : trimLabel,
    );
  }
}

class VehicleGarageService {
  static const String _entriesKey = 'vehicle_garage_entries_v1';
  static const String _lastKey = 'vehicle_garage_last_v1';

  Future<List<VehicleGarageEntry>> loadEntries() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_entriesKey);
    if (raw == null || raw.isEmpty) return <VehicleGarageEntry>[];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <VehicleGarageEntry>[];

      final result = <VehicleGarageEntry>[];
      for (final item in decoded) {
        final entry = VehicleGarageEntry.tryFromJson(item);
        if (entry != null) result.add(entry);
      }
      return result;
    } catch (_) {
      return <VehicleGarageEntry>[];
    }
  }

  Future<void> saveEntries(List<VehicleGarageEntry> entries) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(entries.map((e) => e.toJson()).toList());
    await prefs.setString(_entriesKey, encoded);
  }

  Future<void> addOrBump(VehicleGarageEntry entry, {int max = 3}) async {
    final entries = await loadEntries();

    final filtered = entries.where((e) => e.key != entry.key).toList();
    filtered.insert(0, entry);

    final clipped = filtered.take(max).toList();
    await saveEntries(clipped);
    await saveLast(entry);
  }

  Future<void> removeByKey(String key) async {
    final entries = await loadEntries();
    final updated = entries.where((e) => e.key != key).toList();
    await saveEntries(updated);

    final last = await loadLast();
    if (last?.key == key) {
      await clearLast();
    }
  }

  Future<VehicleGarageEntry?> loadLast() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_lastKey);
    if (raw == null || raw.isEmpty) return null;

    try {
      final decoded = jsonDecode(raw);
      return VehicleGarageEntry.tryFromJson(decoded);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveLast(VehicleGarageEntry entry) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastKey, jsonEncode(entry.toJson()));
  }

  Future<void> clearLast() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_lastKey);
  }
}
