// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:online_store_333/main.dart';
import 'package:online_store_333/presentation/providers/cart_provider.dart';
import 'package:online_store_333/presentation/providers/favorites_provider.dart';
import 'package:online_store_333/presentation/providers/home_provider.dart';
import 'package:online_store_333/presentation/providers/language_provider.dart';
import 'package:online_store_333/data/repositories/admin_repository.dart';
import 'package:online_store_333/data/repositories/catalog_repository.dart';
import 'package:online_store_333/data/repositories/freebies_repository.dart';
import 'package:online_store_333/data/repositories/notification_repository.dart';
import 'package:online_store_333/data/repositories/order_repository.dart';
import 'package:online_store_333/data/repositories/product_repository.dart';
import 'package:online_store_333/data/repositories/review_repository.dart';
import 'package:online_store_333/data/models/product/product_model.dart';
import 'package:online_store_333/data/models/notification/notification_model.dart';
import 'package:online_store_333/domain/entities/product.dart';
import 'package:online_store_333/domain/entities/category.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    try {
      Supabase.instance;
    } catch (_) {
      await Supabase.initialize(
        url: 'https://enxihyplaelrdkievkrk.supabase.co',
        anonKey:
            'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImVueGloeXBsYWVscmRraWV2a3JrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjM0MDg5NTcsImV4cCI6MjA3ODk4NDk1N30.-QdRQCUaTprZDyDlrNm-7vPKwYFVE1_5ncLVjpSM9Oc',
        authOptions: const FlutterAuthClientOptions(
          authFlowType: AuthFlowType.pkce,
        ),
      );
    }
  });

  testWidgets('App builds with providers', (WidgetTester tester) async {
    final productRepository = _FakeProductRepository();
    final notificationRepository = _FakeNotificationRepository();
    final catalogRepository = _FakeCatalogRepository();
    final orderRepository = _FakeOrderRepository();
    final freebiesRepository = _FakeFreebiesRepository();
    final adminRepository = _FakeAdminRepository();
    final reviewRepository = _FakeReviewRepository();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<ProductRepository>.value(value: productRepository),
          Provider<NotificationRepository>.value(value: notificationRepository),
          Provider<CatalogRepository>.value(value: catalogRepository),
          Provider<OrderRepository>.value(value: orderRepository),
          Provider<FreebiesRepository>.value(value: freebiesRepository),
          Provider<AdminRepository>.value(value: adminRepository),
          Provider<ReviewRepository>.value(value: reviewRepository),
          ChangeNotifierProvider(
            create: (_) => CartProvider(),
          ),
          ChangeNotifierProvider(
            create: (_) => FavoritesProvider(),
          ),
          ChangeNotifierProvider(
            create: (context) => HomeProvider(
              productRepository: context.read<ProductRepository>(),
              notificationRepository: context.read<NotificationRepository>(),
              catalogRepository: context.read<CatalogRepository>(),
            ),
          ),
          ChangeNotifierProvider(
            create: (_) => LanguageProvider(),
          ),
        ],
        child: const MyApp(),
      ),
    );

    expect(find.byType(MyApp), findsOneWidget);
  });
}

class _FakeProductRepository implements ProductRepository {
  @override
  Future<List<ProductModel>> fetchBestSellerProducts() async => [];

  @override
  Future<List<ProductModel>> fetchHomeProducts(
          {String sort = 'latest'}) async =>
      [];

  @override
  Future<ProductModel?> fetchProductById(String id) async => null;

  @override
  Future<List<ProductModel>> fetchProductsByCategory(String categoryId) async =>
      [];

  @override
  Future<List<Product>> fetchBestSellerProductsDomain() async => [];

  @override
  Future<List<Product>> fetchHomeProductsDomain(
          {String sort = 'latest'}) async =>
      [];

  @override
  Future<Product?> fetchProductByIdDomain(String id) async => null;

  @override
  Future<List<Product>> fetchProductsByCategoryDomain(
          String categoryId) async =>
      [];
}

class _FakeNotificationRepository implements NotificationRepository {
  @override
  Future<List<NotificationModel>> fetchGeneralNotifications() async => [];

  @override
  Future<List<NotificationModel>> fetchOrderNotifications(
          String orderNumber) async =>
      [];

  @override
  Future<List<NotificationModel>> fetchPhoneNotifications(String phone) async =>
      [];

  @override
  Future<List<NotificationModel>> getNotificationsPublic({
    required String phone,
    required String token,
    String? orderNumber,
  }) async =>
      [];

  @override
  Future<void> saveDeviceToken({
    required String token,
    required String phone,
    required String platform,
  }) async {}

  @override
  Stream<List<NotificationModel>> streamGeneralNotifications() async* {
    yield [];
  }
}

class _FakeCatalogRepository implements CatalogRepository {
  @override
  Future<List<Map<String, dynamic>>> fetchCarBrands() async => [];

  @override
  Future<List<Map<String, dynamic>>> fetchCarGenerations(
          String modelId) async =>
      [];

  @override
  Future<List<Map<String, dynamic>>> fetchCarModels(String brandId) async => [];

  @override
  Future<List<Map<String, dynamic>>> fetchCarSectionsV2(String trimId) async =>
      [];

  @override
  Future<List<Map<String, dynamic>>> fetchCarSubsections(
          String sectionV2Id) async =>
      [];

  @override
  Future<List<Map<String, dynamic>>> fetchCarTrims(String yearId) async => [];

  @override
  Future<List<Map<String, dynamic>>> fetchCarTrimsByGeneration(
          String generationId) async =>
      [];

  @override
  Future<List<Map<String, dynamic>>> fetchCarYears(String modelId) async => [];

  @override
  Future<List<Map<String, dynamic>>> fetchCategories() async => [];

  @override
  Future<List<Category>> fetchCategoriesDomain() async => [];

  @override
  Future<List<Map<String, dynamic>>> fetchProductsByCarHierarchy({
    required String brandId,
    required String modelId,
    required String yearId,
    required String trimId,
    required String sectionV2Id,
    required String subsectionId,
  }) async =>
      [];

  @override
  Future<List<Map<String, dynamic>>> fetchProductsForPartsBrowser({
    required String brandId,
    required String modelId,
    required String generationId,
    required String trimId,
    required String sectionV2Id,
    required String subsectionId,
  }) async =>
      [];

  @override
  Future<List<Map<String, dynamic>>> fetchPromoBanners() async => [];

  @override
  Future<Set<String>> fetchGenerationIdsForYear(String yearId) async => {};
}

class _FakeOrderRepository implements OrderRepository {
  @override
  Future<Map<String, dynamic>> createOrderPublic({
    required String customerName,
    required String phone,
    required String city,
    String? area,
    required String address,
    String? notes,
    required String shippingMethod,
    required String paymentMethod,
    required List<Map<String, dynamic>> items,
    String? influencerRefCode,
    num shippingCost = 0,
    num discountAmount = 0,
    String? orderNumber,
  }) async =>
      {'order_number': 'TEST-ORDER'};

  @override
  Future<Map<String, dynamic>?> trackOrder({
    required String orderNumber,
    required String phone,
  }) async =>
      null;

  @override
  Future<List<Map<String, dynamic>>> fetchMyOrders({int limit = 20}) async =>
      [];
}

class _FakeFreebiesRepository implements FreebiesRepository {
  @override
  Future<List<Map<String, dynamic>>> fetchDonations({
    String? city,
    String status = 'available',
  }) async =>
      [];

  @override
  Future<Map<String, dynamic>?> fetchDonationById(String id) async => null;

  @override
  Future<List<Map<String, dynamic>>> fetchNearbyDonations({
    required double latitude,
    required double longitude,
    required double radiusKm,
    String? city,
    String status = 'available',
  }) async =>
      [];

  @override
  Future<void> submitDonation({
    required String donorName,
    required String donorPhone,
    required String city,
    required String area,
    required String title,
    required String description,
    required List<XFile> images,
    double? latitude,
    double? longitude,
  }) async {}

  @override
  Future<void> submitDonationRequest({
    required String donationId,
    required String name,
    required String phone,
    required String city,
    required String area,
    required String reason,
    required String contactMethod,
  }) async {}

  @override
  Future<void> confirmDonationDelivered({
    required String donationId,
    required String actorPhone,
  }) async {}

  @override
  Future<bool> canConfirmDonationDelivery({
    required String donationId,
    required String actorPhone,
  }) async =>
      false;

  @override
  Future<void> submitDonationReport({
    required String donationId,
    required String reason,
    String? details,
    String? reporterName,
    String? reporterPhone,
  }) async {}
}

class _FakeAdminRepository implements AdminRepository {
  @override
  Stream<List<Map<String, dynamic>>> streamUserEvents({int limit = 50}) async* {
    yield [];
  }

  @override
  Future<List<Map<String, dynamic>>> listPendingProducts({
    int limit = 100,
    int offset = 0,
  }) async =>
      [];

  @override
  Future<List<Map<String, dynamic>>> listSellerProductControls() async => [];

  @override
  Future<Map<String, dynamic>> reviewProduct({
    required String productId,
    required bool approve,
    String? note,
  }) async =>
      {
        'product_id': productId,
        'status': approve ? 'approved' : 'rejected',
      };

  @override
  Future<Map<String, dynamic>> setSellerProductControl({
    required String sellerId,
    required bool canAddProducts,
    required String approvalMode,
    required bool isBlocked,
    String? notes,
  }) async =>
      {
        'seller_id': sellerId,
        'can_add_products': canAddProducts,
        'approval_mode': approvalMode,
        'is_blocked': isBlocked,
      };
}

class _FakeReviewRepository implements ReviewRepository {
  @override
  Future<void> addProductReview({
    required String productId,
    required String reviewerName,
    required int rating,
    String? comment,
    String? reviewerPhone,
  }) async {}

  @override
  Future<List<Map<String, dynamic>>> fetchProductReviews(
          String productId) async =>
      [];
}
