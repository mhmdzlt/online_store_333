import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../shell/root_shell.dart';
import '../features/cart/screens/cart_screen.dart';
import '../features/categories/screens/categories_screen.dart';
import '../features/checkout/screens/checkout_screen.dart';
import '../features/checkout/screens/order_success_screen.dart';
import '../features/donations/screens/donation_details_screen.dart';
import '../features/donations/screens/donations_home_screen.dart';
import '../features/brands/screens/car_brands_screen.dart';
import '../features/brands/screens/car_models_screen.dart';
import '../features/brands/screens/car_years_screen.dart';
import '../features/brands/screens/car_trims_screen.dart';
import '../features/brands/screens/car_sections_v2_screen.dart';
import '../features/brands/screens/car_subsections_screen.dart';
import '../features/brands/screens/car_subsection_products_screen.dart';
import '../features/more/screens/user_search_screen.dart';
import '../features/more/screens/influencer_partnership_screen.dart';
import '../features/notifications/screens/notifications_screen.dart';
import '../features/parts_browser/screens/parts_browser_screen.dart';
import '../features/parts_browser/screens/parts_browser_products_screen.dart';
import '../features/product/screens/product_details_screen.dart';
import '../features/product/screens/product_list_by_category_screen.dart';
import '../features/rfq/screens/rfq_chat_screen.dart';
import '../features/rfq/screens/rfq_create_screen.dart';
import '../features/rfq/screens/rfq_my_requests_screen.dart';
import '../features/rfq/screens/rfq_offers_screen.dart';
import '../features/tracking/screens/order_tracking_screen.dart';
import '../features/donations/screens/donate_item_screen.dart';
import '../features/donations/screens/request_donation_screen.dart';
import '../features/favorites/screens/favorites_screen.dart';
import '../providers/cart_provider.dart';
import '../../core/localization/language_text.dart';
import 'navigation_service.dart';
import 'route_names.dart';

class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: RouteNames.root,
    navigatorKey: NavigationService.navigatorKey,
    redirect: (context, state) {
      final cart = context.read<CartProvider>();
      final matched = state.matchedLocation;

      if (matched == RouteNames.checkout && cart.items.isEmpty) {
        return RouteNames.cart;
      }

      if (matched == RouteNames.orderTracking) {
        final orderId = state.pathParameters['id'];
        if (orderId == null || orderId.trim().isEmpty) {
          return RouteNames.orderTrackingHome;
        }
      }

      return null;
    },
    routes: [
      GoRoute(
        path: RouteNames.root,
        pageBuilder: (context, state) =>
            _buildTransitionPage(state, const RootShell()),
      ),
      GoRoute(
        path: RouteNames.productDetail,
        pageBuilder: (context, state) {
          final productId = state.pathParameters['id']!;
          return _buildTransitionPage(
            state,
            ProductDetailsScreen(productId: productId),
          );
        },
      ),
      GoRoute(
        path: RouteNames.cart,
        pageBuilder: (context, state) =>
            _buildTransitionPage(state, const CartScreen()),
      ),
      GoRoute(
        path: RouteNames.favorites,
        pageBuilder: (context, state) =>
            _buildTransitionPage(state, const FavoritesScreen()),
      ),
      GoRoute(
        path: RouteNames.influencerPartnership,
        pageBuilder: (context, state) => _buildTransitionPage(
          state,
          const InfluencerPartnershipScreen(),
        ),
      ),
      GoRoute(
        path: RouteNames.checkout,
        pageBuilder: (context, state) =>
            _buildTransitionPage(state, const CheckoutScreen()),
      ),
      GoRoute(
        path: RouteNames.orderTrackingHome,
        pageBuilder: (context, state) =>
            _buildTransitionPage(state, const OrderTrackingScreen()),
      ),
      GoRoute(
        path: RouteNames.orderTracking,
        pageBuilder: (context, state) {
          final orderId = state.pathParameters['id']!;
          final extra = state.extra;
          String? phone;
          if (extra is Map<String, dynamic>) {
            phone = extra['phone'] as String?;
          }
          return _buildTransitionPage(
            state,
            OrderTrackingScreen(orderNumber: orderId, phone: phone),
          );
        },
      ),
      GoRoute(
        path: RouteNames.orderSuccess,
        pageBuilder: (context, state) {
          final data = _readExtraMap(state);
          if (data == null) {
            return _buildTransitionPage(
              state,
              const _MissingRouteDataScreen(),
            );
          }
          return _buildTransitionPage(
            state,
            OrderSuccessScreen(
              orderNumber: data['orderNumber'] as String,
              phone: data['phone'] as String?,
            ),
          );
        },
      ),
      GoRoute(
        path: RouteNames.freebies,
        pageBuilder: (context, state) =>
            _buildTransitionPage(state, const DonationsHomeScreen()),
      ),
      GoRoute(
        path: RouteNames.freebieDetail,
        pageBuilder: (context, state) {
          final freebieId = state.pathParameters['id']!;
          return _buildTransitionPage(
            state,
            DonationDetailsScreen(donationId: freebieId),
          );
        },
      ),
      GoRoute(
        path: RouteNames.notifications,
        pageBuilder: (context, state) =>
            _buildTransitionPage(state, const NotificationsScreen()),
      ),
      GoRoute(
        path: RouteNames.categories,
        pageBuilder: (context, state) =>
            _buildTransitionPage(state, const CategoriesScreen()),
      ),
      GoRoute(
        path: RouteNames.categoryProducts,
        pageBuilder: (context, state) {
          final categoryId = state.pathParameters['id']!;
          final categoryName = state.uri.queryParameters['name'] ?? 'القسم';
          return _buildTransitionPage(
            state,
            ProductListByCategoryScreen(
              categoryId: categoryId,
              categoryName: categoryName,
            ),
          );
        },
      ),
      GoRoute(
        path: RouteNames.carBrands,
        pageBuilder: (context, state) =>
            _buildTransitionPage(state, const CarBrandsScreen()),
      ),
      GoRoute(
        path: RouteNames.partsBrowser,
        pageBuilder: (context, state) =>
            _buildTransitionPage(state, const PartsBrowserScreen()),
      ),
      GoRoute(
        path: RouteNames.userSearch,
        pageBuilder: (context, state) =>
            _buildTransitionPage(state, const UserSearchScreen()),
      ),
      GoRoute(
        path: RouteNames.rfqMyRequests,
        pageBuilder: (context, state) =>
            _buildTransitionPage(state, const RfqMyRequestsScreen()),
      ),
      GoRoute(
        path: RouteNames.rfqCreate,
        pageBuilder: (context, state) =>
            _buildTransitionPage(state, const RfqCreateScreen()),
      ),
      GoRoute(
        path: RouteNames.rfqOffers,
        pageBuilder: (context, state) {
          final requestNumber = state.pathParameters['requestNumber'] ?? '';
          return _buildTransitionPage(
            state,
            RfqOffersScreen(requestNumber: requestNumber),
          );
        },
      ),
      GoRoute(
        path: RouteNames.rfqChat,
        pageBuilder: (context, state) {
          final requestNumber = state.pathParameters['requestNumber'] ?? '';
          final sellerId = state.pathParameters['sellerId'] ?? '';
          final extra = state.extra;
          final accessToken =
              (extra is Map) ? (extra['accessToken']?.toString() ?? '') : '';
          final sellerName = (extra is Map)
              ? (extra['sellerName']?.toString() ?? 'تاجر')
              : 'تاجر';

          return _buildTransitionPage(
            state,
            RfqChatScreen(
              requestNumber: requestNumber,
              sellerId: sellerId,
              accessToken: accessToken,
              sellerName: sellerName,
            ),
          );
        },
      ),
      GoRoute(
        path: RouteNames.carModels,
        pageBuilder: (context, state) {
          final data = _readExtraMap(state);
          if (data == null) {
            return _buildTransitionPage(
              state,
              const _MissingRouteDataScreen(),
            );
          }
          return _buildTransitionPage(
            state,
            CarModelsScreen(
              brandId: data['brandId'] as String,
              brandName: data['brandName'] as String,
            ),
          );
        },
      ),
      GoRoute(
        path: RouteNames.carYears,
        pageBuilder: (context, state) {
          final data = _readExtraMap(state);
          if (data == null) {
            return _buildTransitionPage(
              state,
              const _MissingRouteDataScreen(),
            );
          }
          return _buildTransitionPage(
            state,
            CarYearsScreen(
              brandId: data['brandId'] as String,
              brandName: data['brandName'] as String,
              modelId: data['modelId'] as String,
              modelName: data['modelName'] as String,
            ),
          );
        },
      ),
      GoRoute(
        path: RouteNames.carTrims,
        pageBuilder: (context, state) {
          final data = _readExtraMap(state);
          if (data == null) {
            return _buildTransitionPage(
              state,
              const _MissingRouteDataScreen(),
            );
          }
          return _buildTransitionPage(
            state,
            CarTrimsScreen(
              brandId: data['brandId'] as String,
              brandName: data['brandName'] as String,
              modelId: data['modelId'] as String,
              modelName: data['modelName'] as String,
              yearId: data['yearId'] as String,
              yearName: data['yearName'] as String,
            ),
          );
        },
      ),
      GoRoute(
        path: RouteNames.carSectionsV2,
        pageBuilder: (context, state) {
          final data = _readExtraMap(state);
          if (data == null) {
            return _buildTransitionPage(
              state,
              const _MissingRouteDataScreen(),
            );
          }
          return _buildTransitionPage(
            state,
            CarSectionsV2Screen(
              brandId: data['brandId'] as String,
              brandName: data['brandName'] as String,
              modelId: data['modelId'] as String,
              modelName: data['modelName'] as String,
              yearId: data['yearId'] as String,
              yearName: data['yearName'] as String,
              trimId: data['trimId'] as String,
              trimName: data['trimName'] as String,
            ),
          );
        },
      ),
      GoRoute(
        path: RouteNames.carSubsections,
        pageBuilder: (context, state) {
          final data = _readExtraMap(state);
          if (data == null) {
            return _buildTransitionPage(
              state,
              const _MissingRouteDataScreen(),
            );
          }
          return _buildTransitionPage(
            state,
            CarSubsectionsScreen(
              brandId: data['brandId'] as String,
              brandName: data['brandName'] as String,
              modelId: data['modelId'] as String,
              modelName: data['modelName'] as String,
              yearId: data['yearId'] as String,
              yearName: data['yearName'] as String,
              trimId: data['trimId'] as String,
              trimName: data['trimName'] as String,
              sectionV2Id: data['sectionV2Id'] as String,
              sectionName: data['sectionName'] as String,
            ),
          );
        },
      ),
      GoRoute(
        path: RouteNames.carSubsectionProducts,
        pageBuilder: (context, state) {
          final data = _readExtraMap(state);
          if (data == null) {
            return _buildTransitionPage(
              state,
              const _MissingRouteDataScreen(),
            );
          }
          return _buildTransitionPage(
            state,
            CarSubsectionProductsScreen(
              brandId: data['brandId'] as String,
              brandName: data['brandName'] as String,
              modelId: data['modelId'] as String,
              modelName: data['modelName'] as String,
              yearId: data['yearId'] as String,
              yearName: data['yearName'] as String,
              trimId: data['trimId'] as String,
              trimName: data['trimName'] as String,
              sectionV2Id: data['sectionV2Id'] as String,
              sectionName: data['sectionName'] as String,
              subsectionId: data['subsectionId'] as String,
              subsectionName: data['subsectionName'] as String,
            ),
          );
        },
      ),
      GoRoute(
        path: RouteNames.partsBrowserProducts,
        pageBuilder: (context, state) {
          final data = _readExtraMap(state);
          if (data == null) {
            return _buildTransitionPage(
              state,
              const _MissingRouteDataScreen(),
            );
          }
          return _buildTransitionPage(
            state,
            PartsBrowserProductsScreen(
              brandId: data['brandId'] as String,
              brandName: data['brandName'] as String,
              modelId: data['modelId'] as String,
              modelName: data['modelName'] as String,
              generationId: data['generationId'] as String,
              generationName: data['generationName'] as String,
              trimId: data['trimId'] as String,
              trimName: data['trimName'] as String,
              sectionV2Id: data['sectionV2Id'] as String,
              sectionName: data['sectionName'] as String,
              subsectionId: data['subsectionId'] as String,
              subsectionName: data['subsectionName'] as String,
            ),
          );
        },
      ),
      GoRoute(
        path: RouteNames.donateItem,
        pageBuilder: (context, state) =>
            _buildTransitionPage(state, const DonateItemScreen()),
      ),
      GoRoute(
        path: RouteNames.requestDonation,
        pageBuilder: (context, state) {
          final data = _readExtraMap(state);
          if (data == null) {
            return _buildTransitionPage(
              state,
              const _MissingRouteDataScreen(),
            );
          }
          return _buildTransitionPage(
            state,
            RequestDonationScreen(
              donationId: data['donationId'] as String,
            ),
          );
        },
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('404', style: Theme.of(context).textTheme.headlineLarge),
            const SizedBox(height: 16),
            Text(
              context.tr(
                ar: 'الصفحة غير موجودة',
                en: 'Page not found',
                ckb: 'پەڕە نەدۆزرایەوە',
                ku: 'Rûpel nehat dîtin',
              ),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => NavigationService.go(RouteNames.root),
              child: Text(
                context.tr(
                  ar: 'العودة للرئيسية',
                  en: 'Back to home',
                  ckb: 'گەڕانەوە بۆ سەرەکی',
                  ku: 'Vegere seretayê',
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  static CustomTransitionPage<void> _buildTransitionPage(
    GoRouterState state,
    Widget child,
  ) {
    return CustomTransitionPage<void>(
      key: state.pageKey,
      child: child,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final offsetTween = Tween<Offset>(
          begin: const Offset(0, 0.03),
          end: Offset.zero,
        ).chain(CurveTween(curve: Curves.easeOutCubic));

        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: animation.drive(offsetTween),
            child: child,
          ),
        );
      },
    );
  }

  static Map<String, dynamic>? _readExtraMap(GoRouterState state) {
    final extra = state.extra;
    if (extra is Map<String, dynamic>) {
      return extra;
    }
    return null;
  }
}

class _MissingRouteDataScreen extends StatelessWidget {
  const _MissingRouteDataScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.link_off, size: 48),
              const SizedBox(height: 12),
              Text(
                context.tr(
                  ar: 'لا يمكن فتح الصفحة بدون بيانات كاملة.',
                  en: 'Cannot open page without complete data.',
                  ckb: 'ناتوانرێت پەڕە بکاتەوە بەبێ زانیاری تەواو.',
                  ku: 'Rûpel bê daneyên temam nayê vekirin.',
                ),
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => NavigationService.go(RouteNames.root),
                child: Text(
                  context.tr(
                    ar: 'العودة للرئيسية',
                    en: 'Back to home',
                    ckb: 'گەڕانەوە بۆ سەرەکی',
                    ku: 'Vegere seretayê',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
