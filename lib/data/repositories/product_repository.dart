import '../datasources/remote/supabase_product_datasource.dart';
import '../models/product/product_model.dart';
import '../../domain/entities/product.dart';
import '../../domain/mappers/catalog_domain_mappers.dart';

abstract class ProductRepository {
  Future<List<ProductModel>> fetchHomeProducts({String sort = 'latest'});
  Future<List<ProductModel>> fetchBestSellerProducts();
  Future<List<ProductModel>> fetchProductsByCategory(String categoryId);
  Future<ProductModel?> fetchProductById(String id);

  Future<List<Product>> fetchHomeProductsDomain({String sort = 'latest'});
  Future<List<Product>> fetchBestSellerProductsDomain();
  Future<List<Product>> fetchProductsByCategoryDomain(String categoryId);
  Future<Product?> fetchProductByIdDomain(String id);
}

class SupabaseProductRepository implements ProductRepository {
  SupabaseProductRepository({SupabaseProductDataSource? dataSource})
      : _dataSource = dataSource ?? SupabaseProductDataSource();

  final SupabaseProductDataSource _dataSource;

  @override
  Future<List<ProductModel>> fetchHomeProducts({String sort = 'latest'}) async {
    final rows = await _dataSource.fetchHomeProducts(sort: sort);
    return rows.map(ProductModel.fromMap).toList();
  }

  @override
  Future<List<ProductModel>> fetchBestSellerProducts() async {
    final rows = await _dataSource.fetchBestSellerProducts();
    return rows.map(ProductModel.fromMap).toList();
  }

  @override
  Future<List<ProductModel>> fetchProductsByCategory(String categoryId) async {
    final rows = await _dataSource.fetchProductsByCategory(categoryId);
    return rows.map(ProductModel.fromMap).toList();
  }

  @override
  Future<ProductModel?> fetchProductById(String id) async {
    final row = await _dataSource.fetchProductById(id);
    if (row == null) return null;
    return ProductModel.fromMap(row);
  }

  @override
  Future<List<Product>> fetchHomeProductsDomain(
      {String sort = 'latest'}) async {
    final models = await fetchHomeProducts(sort: sort);
    return models.toDomainList();
  }

  @override
  Future<List<Product>> fetchBestSellerProductsDomain() async {
    final models = await fetchBestSellerProducts();
    return models.toDomainList();
  }

  @override
  Future<List<Product>> fetchProductsByCategoryDomain(String categoryId) async {
    final models = await fetchProductsByCategory(categoryId);
    return models.toDomainList();
  }

  @override
  Future<Product?> fetchProductByIdDomain(String id) async {
    final model = await fetchProductById(id);
    return model?.toDomain();
  }
}
