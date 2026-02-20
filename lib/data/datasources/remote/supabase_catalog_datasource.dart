import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseCatalogDataSource {
  SupabaseCatalogDataSource({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<List<Map<String, dynamic>>> fetchPromoBanners() async {
    final res = await _client
        .from('promo_banners')
        .select()
        .eq('is_active', true)
        .order('display_order', ascending: true)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(res);
  }

  Future<List<Map<String, dynamic>>> fetchCategories() async {
    final res = await _client
        .from('categories')
        .select()
        .order('sort_order', ascending: true);
    return List<Map<String, dynamic>>.from(res);
  }

  Future<List<Map<String, dynamic>>> fetchCarBrands() async {
    final res = await _client
        .from('car_brands')
        .select('id, name, image_url')
        .eq('is_active', true)
        .order('sort_order', ascending: true);
    return List<Map<String, dynamic>>.from(res);
  }

  Future<List<Map<String, dynamic>>> fetchCarModels(String brandId) async {
    final res =
        await _client.from('car_models').select().eq('brand_id', brandId);
    return List<Map<String, dynamic>>.from(res);
  }

  Future<List<Map<String, dynamic>>> fetchCarYears(String modelId) async {
    final res =
        await _client.from('car_years').select().eq('model_id', modelId);
    return List<Map<String, dynamic>>.from(res);
  }

  Future<List<Map<String, dynamic>>> fetchCarGenerations(String modelId) async {
    final res = await _client
        .from('car_generations')
        .select()
        .eq('model_id', modelId)
        .eq('is_active', true)
        .order('year_from', ascending: true);
    return List<Map<String, dynamic>>.from(res);
  }

  Future<List<Map<String, dynamic>>> fetchCarTrims(String yearId) async {
    final generationIds = await _getGenerationIdsForYearId(yearId);
    if (generationIds.isEmpty) {
      throw PostgrestException(
        message:
            'لا توجد أجيال (car_generations) تغطي هذه السنة/الموديل. لا يمكن جلب الفئات.',
        code: '404',
        details: 'year_id=$yearId',
        hint:
            'تأكد من car_generations.year_from/year_to وأنها تشمل السنة للموديل المحدد.',
      );
    }

    final orFilter =
        generationIds.map((id) => 'generation_id.eq.$id').join(',');
    final res = await _client
        .from('car_trims')
        .select()
        .eq('is_active', true)
        .or(orFilter)
        .order('sort_order', ascending: true);

    return List<Map<String, dynamic>>.from(res);
  }

  Future<List<Map<String, dynamic>>> fetchCarTrimsByGeneration(
      String generationId) async {
    final res = await _client
        .from('car_trims')
        .select()
        .eq('is_active', true)
        .eq('generation_id', generationId)
        .order('sort_order', ascending: true);
    return List<Map<String, dynamic>>.from(res);
  }

  Future<List<Map<String, dynamic>>> fetchCarSectionsV2(String trimId) async {
    try {
      final res = await _client
          .from('car_sections_v2')
          .select()
          .eq('car_trim_id', trimId);
      return List<Map<String, dynamic>>.from(res);
    } catch (_) {
      final res =
          await _client.from('car_sections_v2').select().eq('trim_id', trimId);
      return List<Map<String, dynamic>>.from(res);
    }
  }

  Future<List<Map<String, dynamic>>> fetchCarSubsections(
      String sectionV2Id) async {
    final res = await _client
        .from('car_subsections')
        .select()
        .eq('section_id', sectionV2Id);
    return List<Map<String, dynamic>>.from(res);
  }

  Future<List<Map<String, dynamic>>> fetchProductsByCarHierarchy({
    required String brandId,
    required String modelId,
    required String yearId,
    required String trimId,
    required String sectionV2Id,
    required String subsectionId,
  }) async {
    final generationIds = await _getGenerationIdsForYearId(yearId);
    if (generationIds.isEmpty) return [];

    final res = await _client
        .from('products')
        .select('id, name, price, old_price, currency, image_url, seller_id')
        .eq('car_brand_id', brandId)
        .eq('car_model_id', modelId)
        .eq('car_trim_id', trimId)
        .eq('car_section_v2_id', sectionV2Id)
        .eq('car_subsection_id', subsectionId)
        .inFilter('car_generation_id', generationIds)
        .eq('is_active', true)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(res);
  }

  Future<List<Map<String, dynamic>>> fetchProductsForPartsBrowser({
    required String brandId,
    required String modelId,
    required String generationId,
    required String trimId,
    required String sectionV2Id,
    required String subsectionId,
  }) async {
    final res = await _client
        .from('products')
        .select('id, name, price, old_price, currency, image_url, created_at')
        .eq('car_brand_id', brandId)
        .eq('car_model_id', modelId)
        .eq('car_generation_id', generationId)
        .eq('car_trim_id', trimId)
        .eq('car_section_v2_id', sectionV2Id)
        .eq('car_subsection_id', subsectionId)
        .eq('is_active', true)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(res);
  }

  Future<Set<String>> fetchGenerationIdsForYear(String yearId) async {
    final yearRow = await _client
        .from('car_years')
        .select('id, model_id, year')
        .eq('id', yearId)
        .maybeSingle();

    if (yearRow == null) return <String>{};

    final modelId = yearRow['model_id']?.toString();
    final rawYear = yearRow['year'];
    final year = rawYear is num
        ? rawYear.toInt()
        : int.tryParse(rawYear?.toString() ?? '');

    if (modelId == null || modelId.isEmpty || year == null) {
      return <String>{};
    }

    final generations = await _client
        .from('car_generations')
        .select('id')
        .eq('model_id', modelId)
        .eq('is_active', true)
        .lte('year_from', year)
        .or('year_to.is.null,year_to.gte.$year');

    return (generations as List)
        .map((e) => (e as Map)['id']?.toString())
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet();
  }

  Future<List<String>> _getGenerationIdsForYearId(String yearId) async {
    final yearRow = await _client
        .from('car_years')
        .select('id, model_id, year')
        .eq('id', yearId)
        .maybeSingle();

    if (yearRow == null) return [];

    final modelId = yearRow['model_id']?.toString();
    final rawYear = yearRow['year'];
    final year = rawYear is num
        ? rawYear.toInt()
        : int.tryParse(rawYear?.toString() ?? '');

    if (modelId == null || modelId.isEmpty || year == null) {
      throw PostgrestException(
        message:
            'بيانات السنة غير مكتملة في car_years (model_id/year). لا يمكن تحديد الأجيال.',
        code: '400',
        details: yearRow.toString(),
        hint: 'تأكد أن car_years يحتوي model_id و year صحيحين.',
      );
    }

    final generations = await _client
        .from('car_generations')
        .select('id')
        .eq('model_id', modelId)
        .eq('is_active', true)
        .lte('year_from', year)
        .or('year_to.is.null,year_to.gte.$year');

    return (generations as List)
        .map((e) => (e as Map)['id']?.toString())
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toList();
  }
}
