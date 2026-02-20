import 'package:flutter/material.dart';

import '../../data/models/notification/notification_model.dart';
import '../../data/models/product/product_model.dart';
import '../../data/models/car/car_lookup_item.dart';
import '../../data/models/category/category_model.dart';
import '../../data/models/promo_banner/promo_banner_model.dart';
import '../../data/repositories/catalog_repository.dart';
import '../../data/repositories/notification_repository.dart';
import '../../data/repositories/product_repository.dart';
import '../../utils/local_storage.dart';
import '../../data/models/car/car_brand.dart';

class HomeProvider extends ChangeNotifier {
  HomeProvider({
    required ProductRepository productRepository,
    required NotificationRepository notificationRepository,
    required CatalogRepository catalogRepository,
  })  : _productRepository = productRepository,
        _notificationRepository = notificationRepository,
        _catalogRepository = catalogRepository;

  final ProductRepository _productRepository;
  final NotificationRepository _notificationRepository;
  final CatalogRepository _catalogRepository;

  bool _isLoadingHomeData = false;
  List<ProductModel> _homeProducts = [];
  List<CategoryModel> _categories = [];
  List<PromoBannerModel> _promoBanners = [];

  bool _isLoadingNotifications = false;
  bool _hasUnreadNotifications = false;
  List<NotificationModel> _notifications = [];

  bool get isLoadingHomeData => _isLoadingHomeData;
  List<ProductModel> get homeProducts => List.unmodifiable(_homeProducts);
  List<CategoryModel> get categories => List.unmodifiable(_categories);
  List<PromoBannerModel> get promoBanners => List.unmodifiable(_promoBanners);

  bool get isLoadingNotifications => _isLoadingNotifications;
  bool get hasUnreadNotifications => _hasUnreadNotifications;
  List<NotificationModel> get notifications =>
      List.unmodifiable(_notifications);

  Future<List<ProductModel>> fetchHomeProducts() async {
    return _productRepository.fetchHomeProducts();
  }

  Future<void> loadHomeData() async {
    if (_isLoadingHomeData) return;
    _isLoadingHomeData = true;
    notifyListeners();

    try {
      final results = await Future.wait([
        _productRepository.fetchHomeProducts(),
        _catalogRepository.fetchPromoBanners(),
        _catalogRepository.fetchCategories(),
      ]);

      final products = results[0] as List<ProductModel>;
      final rawBanners = results[1] as List<Map<String, dynamic>>;
      final rawCategories = results[2] as List<Map<String, dynamic>>;

      _homeProducts = products;
      _promoBanners =
          rawBanners.map(PromoBannerModel.fromMap).toList(growable: false);
      _categories =
          rawCategories.map(CategoryModel.fromMap).toList(growable: false);
    } catch (_) {
      _homeProducts = [];
      _promoBanners = [];
      _categories = [];
    } finally {
      _isLoadingHomeData = false;
      notifyListeners();
    }
  }

  Future<List<PromoBannerModel>> fetchPromoBanners() async {
    final raw = await _catalogRepository.fetchPromoBanners();
    return raw.map(PromoBannerModel.fromMap).toList();
  }

  Future<List<CategoryModel>> fetchCategories() async {
    final raw = await _catalogRepository.fetchCategories();
    return raw.map(CategoryModel.fromMap).toList();
  }

  Future<List<CarBrand>> fetchCarBrands() async {
    final raw = await _catalogRepository.fetchCarBrands();
    return raw.map(CarBrand.fromMap).toList(growable: false);
  }

  Future<List<CarLookupItem>> fetchCarModels(String brandId) async {
    final raw = await _catalogRepository.fetchCarModels(brandId);
    return raw.map(CarLookupItem.fromMap).toList(growable: false);
  }

  Future<List<CarLookupItem>> fetchCarYears(String modelId) async {
    final raw = await _catalogRepository.fetchCarYears(modelId);
    return raw.map(CarLookupItem.fromMap).toList(growable: false);
  }

  Future<List<CarLookupItem>> fetchCarTrims(String yearId) async {
    final raw = await _catalogRepository.fetchCarTrims(yearId);
    return raw.map(CarLookupItem.fromMap).toList(growable: false);
  }

  Future<List<CarLookupItem>> fetchCarSectionsV2(String trimId) async {
    final raw = await _catalogRepository.fetchCarSectionsV2(trimId);
    return raw.map(CarLookupItem.fromMap).toList(growable: false);
  }

  Future<List<CarLookupItem>> fetchCarSubsections(String sectionV2Id) async {
    final raw = await _catalogRepository.fetchCarSubsections(sectionV2Id);
    return raw.map(CarLookupItem.fromMap).toList(growable: false);
  }

  Future<Set<String>> fetchGenerationIdsForYear(String yearId) {
    return _catalogRepository.fetchGenerationIdsForYear(yearId);
  }

  Future<void> loadHomeNotifications() async {
    if (_isLoadingNotifications) return;
    _isLoadingNotifications = true;
    notifyListeners();

    try {
      final savedPhone = await LocalStorage.getUserPhone();
      final trimmedPhone = savedPhone?.trim();

      List<NotificationModel> raw;
      if (trimmedPhone != null && trimmedPhone.isNotEmpty) {
        raw =
            await _notificationRepository.fetchPhoneNotifications(trimmedPhone);
      } else {
        raw = await _notificationRepository.fetchGeneralNotifications();
      }

      final list = raw.take(5).toList();

      _notifications = list;
      _hasUnreadNotifications = list.isNotEmpty;
    } catch (_) {
      _notifications = [];
      _hasUnreadNotifications = false;
    } finally {
      _isLoadingNotifications = false;
      notifyListeners();
    }
  }

  void clearUnreadNotifications() {
    if (!_hasUnreadNotifications) return;
    _hasUnreadNotifications = false;
    notifyListeners();
  }
}
