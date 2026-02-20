import '../../data/models/category/category_model.dart';
import '../../data/models/product/product_model.dart';
import '../entities/category.dart';
import '../entities/product.dart';
import '../enums/product_condition.dart';

extension ProductModelToDomainMapper on ProductModel {
  Product toDomain() {
    return Product(
      id: id,
      name: name,
      price: price,
      imageUrl: imageUrl,
      description: description,
      categoryId: categoryId,
      stockQuantity: stock,
      images: imageUrls,
      condition: ProductCondition.newCondition,
    );
  }
}

extension ProductDomainListMapper on Iterable<ProductModel> {
  List<Product> toDomainList() => map((item) => item.toDomain()).toList();
}

extension CategoryModelToDomainMapper on CategoryModel {
  Category toDomain() {
    return Category(
      id: id,
      name: name,
      imageUrl: imageUrl,
    );
  }
}

extension CategoryDomainListMapper on Iterable<CategoryModel> {
  List<Category> toDomainList() => map((item) => item.toDomain()).toList();
}
