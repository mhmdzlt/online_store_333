import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class VehicleGarageEntryV2 {
  const VehicleGarageEntryV2({
    required this.brandId,
    required this.brandName,
    required this.modelId,
    required this.modelName,
    required this.generationId,
    required this.generationLabel,
    required this.trimId,
    required this.trimName,
  });

  final String brandId;
  final String brandName;
  final String modelId;
  final String modelName;
  final String generationId;
  final String generationLabel;
  final String trimId;
  final String trimName;

  String get key => '$brandId|$modelId|$generationId|$trimId';

  Map<String, dynamic> toJson() => <String, dynamic>{
    'brand_id': brandId,
    'brand_name': brandName,
    'model_id': modelId,
    'model_name': modelName,
    'generation_id': generationId,
    'generation_label': generationLabel,
    'trim_id': trimId,
    'trim_name': trimName,
  };

  static VehicleGarageEntryV2? tryFromJson(Object? value) {
    if (value is! Map) return null;

    String? s(Object? v) => v?.toString();

    final brandId = s(value['brand_id']);
    final brandName = s(value['brand_name']);
    final modelId = s(value['model_id']);
    final modelName = s(value['model_name']);
    final generationId = s(value['generation_id']);
    final generationLabel = s(value['generation_label']);
    final trimId = s(value['trim_id']);
    final trimName = s(value['trim_name']);

    if (brandId == null ||
        brandName == null ||
        modelId == null ||
        modelName == null ||
        generationId == null ||
        generationLabel == null ||
        trimId == null ||
        trimName == null) {
      return null;
    }

    return VehicleGarageEntryV2(
      brandId: brandId,
      brandName: brandName,
      modelId: modelId,
      modelName: modelName,
      generationId: generationId,
      generationLabel: generationLabel,
      trimId: trimId,
      trimName: trimName,
    );
  }
}

class VehicleGarageServiceV2 {
  static const String _entriesKey = 'vehicle_garage_entries_v2';
  static const String _lastKey = 'vehicle_garage_last_v2';

  Future<List<VehicleGarageEntryV2>> loadEntries() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_entriesKey);
    if (raw == null || raw.isEmpty) return <VehicleGarageEntryV2>[];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <VehicleGarageEntryV2>[];

      final result = <VehicleGarageEntryV2>[];
      for (final item in decoded) {
        final entry = VehicleGarageEntryV2.tryFromJson(item);
        if (entry != null) result.add(entry);
      }
      return result;
    } catch (_) {
      return <VehicleGarageEntryV2>[];
    }
  }

  Future<void> saveEntries(List<VehicleGarageEntryV2> entries) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(entries.map((e) => e.toJson()).toList());
    await prefs.setString(_entriesKey, encoded);
  }

  Future<void> addOrBump(VehicleGarageEntryV2 entry, {int max = 3}) async {
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

  Future<VehicleGarageEntryV2?> loadLast() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_lastKey);
    if (raw == null || raw.isEmpty) return null;

    try {
      final decoded = jsonDecode(raw);
      return VehicleGarageEntryV2.tryFromJson(decoded);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveLast(VehicleGarageEntryV2 entry) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastKey, jsonEncode(entry.toJson()));
  }

  Future<void> clearLast() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_lastKey);
  }
}
