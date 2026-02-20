import '../datasources/remote/supabase_catalog_datasource.dart';
import '../models/category/category_model.dart';
import '../../domain/entities/category.dart';
import '../../domain/mappers/catalog_domain_mappers.dart';

abstract class CatalogRepository {
  Future<List<Map<String, dynamic>>> fetchPromoBanners();
  Future<List<Map<String, dynamic>>> fetchCategories();
  Future<List<Category>> fetchCategoriesDomain();
  Future<List<Map<String, dynamic>>> fetchCarBrands();
  Future<List<Map<String, dynamic>>> fetchCarModels(String brandId);
  Future<List<Map<String, dynamic>>> fetchCarYears(String modelId);
  Future<List<Map<String, dynamic>>> fetchCarGenerations(String modelId);
  Future<List<Map<String, dynamic>>> fetchCarTrims(String yearId);
  Future<List<Map<String, dynamic>>> fetchCarTrimsByGeneration(
      String generationId);
  Future<List<Map<String, dynamic>>> fetchCarSectionsV2(String trimId);
  Future<List<Map<String, dynamic>>> fetchCarSubsections(String sectionV2Id);
  Future<List<Map<String, dynamic>>> fetchProductsByCarHierarchy({
    required String brandId,
    required String modelId,
    required String yearId,
    required String trimId,
    required String sectionV2Id,
    required String subsectionId,
  });
  Future<List<Map<String, dynamic>>> fetchProductsForPartsBrowser({
    required String brandId,
    required String modelId,
    required String generationId,
    required String trimId,
    required String sectionV2Id,
    required String subsectionId,
  });
  Future<Set<String>> fetchGenerationIdsForYear(String yearId);
}

class SupabaseCatalogRepository implements CatalogRepository {
  SupabaseCatalogRepository({SupabaseCatalogDataSource? dataSource})
      : _dataSource = dataSource ?? SupabaseCatalogDataSource();

  final SupabaseCatalogDataSource _dataSource;

  @override
  Future<List<Map<String, dynamic>>> fetchPromoBanners() {
    return _dataSource.fetchPromoBanners();
  }

  @override
  Future<List<Map<String, dynamic>>> fetchCategories() {
    return _dataSource.fetchCategories();
  }

  @override
  Future<List<Category>> fetchCategoriesDomain() async {
    final rows = await fetchCategories();
    final models = rows.map(CategoryModel.fromMap).toList();
    return models.toDomainList();
  }

  @override
  Future<List<Map<String, dynamic>>> fetchCarBrands() {
    return _dataSource.fetchCarBrands();
  }

  @override
  Future<List<Map<String, dynamic>>> fetchCarModels(String brandId) {
    return _dataSource.fetchCarModels(brandId);
  }

  @override
  Future<List<Map<String, dynamic>>> fetchCarYears(String modelId) {
    return _dataSource.fetchCarYears(modelId);
  }

  @override
  Future<List<Map<String, dynamic>>> fetchCarGenerations(String modelId) {
    return _dataSource.fetchCarGenerations(modelId);
  }

  @override
  Future<List<Map<String, dynamic>>> fetchCarTrims(String yearId) {
    return _dataSource.fetchCarTrims(yearId);
  }

  @override
  Future<List<Map<String, dynamic>>> fetchCarTrimsByGeneration(
      String generationId) {
    return _dataSource.fetchCarTrimsByGeneration(generationId);
  }

  @override
  Future<List<Map<String, dynamic>>> fetchCarSectionsV2(String trimId) {
    return _dataSource.fetchCarSectionsV2(trimId);
  }

  @override
  Future<List<Map<String, dynamic>>> fetchCarSubsections(String sectionV2Id) {
    return _dataSource.fetchCarSubsections(sectionV2Id);
  }

  @override
  Future<List<Map<String, dynamic>>> fetchProductsByCarHierarchy({
    required String brandId,
    required String modelId,
    required String yearId,
    required String trimId,
    required String sectionV2Id,
    required String subsectionId,
  }) {
    return _dataSource.fetchProductsByCarHierarchy(
      brandId: brandId,
      modelId: modelId,
      yearId: yearId,
      trimId: trimId,
      sectionV2Id: sectionV2Id,
      subsectionId: subsectionId,
    );
  }

  @override
  Future<List<Map<String, dynamic>>> fetchProductsForPartsBrowser({
    required String brandId,
    required String modelId,
    required String generationId,
    required String trimId,
    required String sectionV2Id,
    required String subsectionId,
  }) {
    return _dataSource.fetchProductsForPartsBrowser(
      brandId: brandId,
      modelId: modelId,
      generationId: generationId,
      trimId: trimId,
      sectionV2Id: sectionV2Id,
      subsectionId: subsectionId,
    );
  }

  @override
  Future<Set<String>> fetchGenerationIdsForYear(String yearId) {
    return _dataSource.fetchGenerationIdsForYear(yearId);
  }
}
