import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:online_store_333/presentation/screens/image_search/camera_image_search_screen.dart';
import 'package:online_store_333/presentation/screens/image_search/crop_image_search_screen.dart';
import 'package:online_store_333/presentation/screens/image_search/image_search_results_sheet.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;

import 'package:design_system/design_system.dart';
import '../../../../data/models/car/car_brand.dart';
import '../../../../data/models/car/car_lookup_item.dart';
import '../../../../data/models/product/product_model.dart';
import '../../../../data/models/promo_banner/promo_banner_model.dart';
import '../../../providers/home_provider.dart';
import '../../../../core/services/tracking_service.dart';
import '../../../../core/localization/language_text.dart';
import '../widgets/home_filter_bottom_sheet.dart';
import '../widgets/home_promo_section.dart';
import '../widgets/home_top_bar.dart';
import '../widgets/home_product_slivers.dart';
import '../../../widgets/common/horizontal_products_section.dart';
import '../../../widgets/common/section_header.dart';
import '../../../routing/route_names.dart';
import '../../../routing/navigation_helpers.dart';
import '../../../../core/services/vehicle_garage_service.dart';
import '../../../../core/config/supabase_config.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with WidgetsBindingObserver, AutomaticKeepAliveClientMixin<HomeScreen> {
  static const int _productPageSize = 24;
  static const String _imageSearchEndpoint =
      'https://enxihyplaelrdkievkrk.supabase.co/functions/v1/image_search';

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  final PageController _promoPageController = PageController();

  Timer? _promoTimer;
  Timer? _searchHintTimer;
  bool _keyboardVisible = false;
  bool _showCategoriesBar = false;
  double _lastScrollOffset = 0;
  bool _isRefreshing = false;
  DateTime _lastTopRefresh = DateTime.fromMillisecondsSinceEpoch(0);

  bool _isLoadingProducts = false;
  bool _isLoadingBanners = false;
  bool _imageSearchActive = false;
  bool _imageSearchLoading = false;
  List<String> _imageSearchIds = [];

  final List<PromoBannerModel> _promoBanners = [];
  List<CarLookupItem> _carModels = [];
  List<CarLookupItem> _carYears = [];
  List<CarLookupItem> _carTrims = [];
  List<CarLookupItem> _carSectionsV2 = [];
  List<CarLookupItem> _carSubsections = [];

  List<ProductModel> _allProducts = [];
  List<ProductModel> _visibleProducts = [];

  final List<CarBrand> _allCarBrands = [];

  String _searchQuery = '';
  final ValueNotifier<String> _searchHintNotifier = ValueNotifier<String>(
    'Search products...',
  );
  List<String> _searchHints = [];
  int _searchHintIndex = 0;
  int _currentPromoIndex = 0;

  String? _selectedCategoryId;
  String? _selectedBrandId;
  String? _selectedModelId;
  String? _selectedYearId;
  Set<String>? _selectedGenerationIdsForYear;
  String? _selectedTrimId;
  String? _selectedSectionV2Id;
  String? _selectedSubsectionId;

  final _garageService = VehicleGarageService();

  double _minPrice = 0;
  double _maxPrice = 0;
  RangeValues? _priceRange;

  int _visibleProductLimit = _productPageSize;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initGarage();
    _searchController.addListener(() {
      final nextValue = _searchController.text;
      if (nextValue == _searchQuery) return;
      _searchQuery = nextValue;
      _applyFilters();
      TrackingService.instance.trackSearch(screen: 'home', query: _searchQuery);
    });
    _searchFocusNode.addListener(() {
      if (!_searchFocusNode.hasFocus && _searchQuery.trim().isNotEmpty) {
        _clearSearch();
      }
    });
    _scrollController.addListener(_handleScroll);
    _startSearchHintRotation();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refresh();
    });
  }

  Future<void> _initGarage() async {
    try {
      await _garageService.loadEntries();
      await _garageService.loadLast();
    } catch (_) {
      // Error loading garage entries
    }
  }

  Future<void> _loadHomeNotifications() async {
    await context.read<HomeProvider>().loadHomeNotifications();
  }

  void _updatePriceBounds() {
    if (_allProducts.isEmpty) {
      _minPrice = 0;
      _maxPrice = 0;
      _priceRange = null;
      return;
    }

    final prices = _allProducts.map((p) => p.price).toList();
    prices.sort();
    _minPrice = prices.first;
    _maxPrice = prices.last;

    if (_priceRange == null) {
      _priceRange = RangeValues(_minPrice, _maxPrice);
    } else {
      final start = _priceRange!.start.clamp(_minPrice, _maxPrice);
      final end = _priceRange!.end.clamp(_minPrice, _maxPrice);
      _priceRange = RangeValues(start, end);
    }
  }

  void _applyFilters({bool markLoaded = false}) {
    final query = _searchQuery.trim().toLowerCase();
    final imageSearchActive = _imageSearchActive;
    final imageSearchIds =
        imageSearchActive ? _imageSearchIds : const <String>[];
    final imageSearchSet = imageSearchActive ? imageSearchIds.toSet() : null;
    final imageSearchOrder = imageSearchActive
        ? {for (var i = 0; i < imageSearchIds.length; i++) imageSearchIds[i]: i}
        : const <String, int>{};
    final selectedCategory = _selectedCategoryId;
    final selectedBrand = _selectedBrandId;
    final selectedModel = _selectedModelId;
    final selectedYear = _selectedYearId;
    final selectedGenerationIdsForYear = _selectedGenerationIdsForYear;
    final selectedTrim = _selectedTrimId;
    final selectedSectionV2 = _selectedSectionV2Id;
    final selectedSubsection = _selectedSubsectionId;
    final priceRange = _priceRange;

    final filtered = _allProducts.where((product) {
      final matchesImage = !imageSearchActive ||
          (imageSearchSet != null && imageSearchSet.contains(product.id));
      final name = product.name.toLowerCase();
      final matchesSearch = query.isEmpty || name.contains(query);

      final categoryId = product.categoryId;
      final matchesCategory =
          selectedCategory == null || categoryId == selectedCategory;

      final brandId = product.carBrandId;
      final matchesBrand = selectedBrand == null || brandId == selectedBrand;

      final modelId = product.carModelId;
      final matchesModel = selectedModel == null || modelId == selectedModel;

      final generationId = product.carGenerationId;
      final matchesYear = selectedYear == null ||
          selectedGenerationIdsForYear == null ||
          (generationId != null &&
              selectedGenerationIdsForYear.contains(generationId));

      final trimId = product.carTrimId;
      final matchesTrim = selectedTrim == null || trimId == selectedTrim;

      final sectionV2Id = product.carSectionV2Id;
      final matchesSectionV2 =
          selectedSectionV2 == null || sectionV2Id == selectedSectionV2;

      final subsectionId = product.carSubsectionId;
      final matchesSubsection =
          selectedSubsection == null || subsectionId == selectedSubsection;

      final price = product.price;
      final matchesPrice = priceRange == null ||
          (price >= priceRange.start && price <= priceRange.end);

      return matchesImage &&
          matchesSearch &&
          matchesCategory &&
          matchesBrand &&
          matchesModel &&
          matchesYear &&
          matchesTrim &&
          matchesSectionV2 &&
          matchesSubsection &&
          matchesPrice;
    }).toList();

    if (imageSearchActive) {
      filtered.sort((a, b) {
        final aOrder = imageSearchOrder[a.id] ?? 999999;
        final bOrder = imageSearchOrder[b.id] ?? 999999;
        return aOrder.compareTo(bOrder);
      });
    }

    final filteredBrands = _allCarBrands.where((brand) {
      final name = brand.name.toLowerCase();
      return query.isEmpty || name.contains(query);
    }).toList();

    setState(() {
      _visibleProducts = filtered;
      _visibleProductLimit = min(_productPageSize, filtered.length);
      _refreshSearchHintsFromContent(filtered, filteredBrands);
      if (markLoaded) {
        _isLoadingProducts = false;
      }
    });
  }

  String? _stringValue(dynamic value) {
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isNotEmpty) return trimmed;
    }
    return null;
  }

  String? _bannerField(PromoBannerModel banner, List<String> keys) {
    for (final key in keys) {
      final parsed = _stringValue(banner.raw[key]);
      if (parsed != null) return parsed;
    }
    return null;
  }

  void _refreshSearchHintsFromContent(
    List<ProductModel> products,
    List<CarBrand> brands,
  ) {
    final names = <String>{};
    for (final product in products) {
      final name = product.name.trim();
      if (name.isNotEmpty) names.add(name);
    }
    for (final brand in brands) {
      final name = brand.name.trim();
      if (name.isNotEmpty) names.add(name);
    }

    final nextHints = names.take(10).toList();
    _searchHints = nextHints;
    _searchHintIndex = 0;

    if (_searchQuery.trim().isEmpty) {
      _searchHintNotifier.value = nextHints.isNotEmpty
          ? nextHints.first
          : context.tr(
              watch: false,
              ar: 'ابحث عن منتج...',
              en: 'Search products...',
              ckb: 'بەدوای کاڵادا بگەڕێ...',
              ku: 'Li berhemekê bigere...',
            );
    }
  }

  void _startSearchHintRotation() {
    _searchHintTimer?.cancel();
    _searchHintTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (!mounted) return;
      if (_searchQuery.trim().isNotEmpty) return;
      if (_searchHints.isEmpty) return;

      _searchHintIndex = (_searchHintIndex + 1) % _searchHints.length;
      _searchHintNotifier.value = _searchHints[_searchHintIndex];
    });
  }

  void _clearSearch() {
    _searchController.clear();
    _searchQuery = '';
    _applyFilters();
  }

  void _resetFilters() {
    setState(() {
      _selectedCategoryId = null;
      _selectedBrandId = null;
      _selectedModelId = null;
      _selectedYearId = null;
      _selectedGenerationIdsForYear = null;
      _selectedTrimId = null;
      _selectedSectionV2Id = null;
      _selectedSubsectionId = null;
      if (_maxPrice > 0) {
        _priceRange = RangeValues(_minPrice, _maxPrice);
      } else {
        _priceRange = null;
      }
      _imageSearchActive = false;
      _imageSearchIds = [];
    });
    _applyFilters();
  }

  Future<void> _openImageSearchPicker() async {
    if (_imageSearchLoading) return;
    final picked = await CameraImageSearchScreen.open(context);
    if (picked == null) return;

    await _searchByImage(picked);
  }

  Future<void> _searchByImage(XFile file) async {
    final selected = await CropImageSearchScreen.open(context, file);
    if (selected == null) return;
    file = selected;

    setState(() {
      _imageSearchLoading = true;
    });

    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse(_imageSearchEndpoint),
      );
      request.headers['apikey'] = SupabaseConfig.anonKey;
      request.headers['Authorization'] = 'Bearer ${SupabaseConfig.anonKey}';
      request.files.add(
        await http.MultipartFile.fromPath(
          'image',
          file.path,
          filename: file.name,
        ),
      );

      final response = await request.send();
      final body = await response.stream.bytesToString();
      if (response.statusCode >= 400) {
        final details = _extractImageSearchError(body);
        throw Exception(
          'image_search_failed: ${response.statusCode}${details == null ? '' : ' - $details'}',
        );
      }

      final decoded = jsonDecode(body);
      final results = decoded is Map<String, dynamic>
          ? (decoded['results'] as List?) ?? const []
          : const [];
      final ids = results
          .whereType<Map>()
          .map((e) => e['id']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toList();

      final idsSet = ids.toSet();
      final idsOrder = {for (var i = 0; i < ids.length; i++) ids[i]: i};
      final productsForSheet =
          _allProducts.where((p) => idsSet.contains(p.id)).toList()
            ..sort((a, b) {
              final aOrder = idsOrder[a.id] ?? 999999;
              final bOrder = idsOrder[b.id] ?? 999999;
              return aOrder.compareTo(bOrder);
            });

      setState(() {
        _imageSearchActive = true;
        _imageSearchIds = ids;
        _searchController.clear();
        _searchQuery = '';
      });
      _applyFilters();

      if (!mounted) return;
      if (ids.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.tr(
                ar: 'لا توجد منتجات مشابهة حالياً.',
                en: 'No similar products found right now.',
                ckb: 'ئێستا هیچ کاڵای هاوشێوە نەدۆزرایەوە.',
                ku: 'Niha tu berhemên weke hev nehatin dîtin.',
              ),
            ),
          ),
        );
      } else {
        await ImageSearchResultsSheet.show(
          context,
          queryImage: file,
          products: productsForSheet,
        );
      }
    } catch (e) {
      if (!mounted) return;
      _showImageSearchError(
        '${context.tr(ar: 'تعذر البحث بالصورة', en: 'Image search failed', ckb: 'گەڕان بە وێنە سەرکەوتوو نەبوو', ku: 'Lêgerîna bi wêne bi ser neket')}: $e',
      );
    } finally {
      if (mounted) {
        setState(() => _imageSearchLoading = false);
      }
    }
  }

  void _clearImageSearch() {
    setState(() {
      _imageSearchActive = false;
      _imageSearchIds = [];
    });
    _applyFilters();
  }

  String? _extractImageSearchError(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        final error = decoded['error']?.toString();
        final detail = decoded['detail']?.toString();
        if (detail != null && detail.isNotEmpty) return detail;
        if (error != null && error.isNotEmpty) return error;
      }
    } catch (_) {}
    return null;
  }

  Future<void> _showImageSearchError(String message) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            context.tr(
              ar: 'خطأ في البحث بالصورة',
              en: 'Image search error',
              ckb: 'هەڵەی گەڕان بە وێنە',
              ku: 'Çewtiya lêgerîna bi wêne',
            ),
          ),
          content: SelectableText(message),
          actions: [
            TextButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: message));
              },
              child: Text(
                context.tr(ar: 'نسخ', en: 'Copy', ckb: 'کۆپی', ku: 'Kopî'),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                context.tr(
                    ar: 'إغلاق', en: 'Close', ckb: 'داخستن', ku: 'Bigire'),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _syncSelectedYearGenerationFilter() async {
    final yearId = _selectedYearId;
    if (yearId == null || yearId.trim().isEmpty) {
      if (!mounted) return;
      setState(() => _selectedGenerationIdsForYear = null);
      return;
    }

    try {
      final ids = await context.read<HomeProvider>().fetchGenerationIdsForYear(
            yearId,
          );
      if (!mounted) return;
      setState(() => _selectedGenerationIdsForYear = ids);
    } catch (_) {
      if (!mounted) return;
      setState(() => _selectedGenerationIdsForYear = <String>{});
    }
  }

  bool get _hasActiveFilters {
    final hasQuery = _searchQuery.trim().isNotEmpty;
    final hasCategory = _selectedCategoryId != null;
    final hasBrand = _selectedBrandId != null;
    final hasModel = _selectedModelId != null;
    final hasYear = _selectedYearId != null;
    final hasTrim = _selectedTrimId != null;
    final hasSection = _selectedSectionV2Id != null;
    final hasSubsection = _selectedSubsectionId != null;
    final hasPrice = _priceRange != null &&
        (_priceRange!.start > _minPrice || _priceRange!.end < _maxPrice);
    return hasQuery ||
        hasCategory ||
        hasBrand ||
        hasModel ||
        hasYear ||
        hasTrim ||
        hasSection ||
        hasSubsection ||
        hasPrice;
  }

  Future<void> _loadCarBrands() async {
    try {
      final brands = await context.read<HomeProvider>().fetchCarBrands();
      if (mounted) {
        setState(() {
          _allCarBrands
            ..clear()
            ..addAll(brands);
        });
      }
      _applyFilters();
    } catch (_) {}
  }

  Future<void> _refresh() async {
    if (mounted) {
      setState(() {
        _isRefreshing = true;
        _isLoadingProducts = true;
        _isLoadingBanners = true;
      });
    }
    final provider = context.read<HomeProvider>();
    await provider.loadHomeData();

    final shuffled = List<ProductModel>.from(provider.homeProducts)
      ..shuffle(Random());

    if (mounted) {
      setState(() {
        _allProducts = shuffled;
        _promoBanners
          ..clear()
          ..addAll(provider.promoBanners);
        _currentPromoIndex = 0;
        _isLoadingProducts = false;
        _isLoadingBanners = false;
      });
    }

    _updatePriceBounds();
    _applyFilters(markLoaded: true);
    _startPromoAutoPlay();

    await Future.wait([_loadCarBrands(), _loadHomeNotifications()]);

    if (mounted) {
      setState(() => _isRefreshing = false);
    }
  }

  void _startPromoAutoPlay() {
    _promoTimer?.cancel();

    if (_promoBanners.length <= 1) {
      return;
    }

    _promoTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted ||
          _promoBanners.isEmpty ||
          !_promoPageController.hasClients) {
        return;
      }

      final nextIndex = (_currentPromoIndex + 1) % _promoBanners.length;
      setState(() {
        _currentPromoIndex = nextIndex;
      });

      _promoPageController.animateToPage(
        nextIndex,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _promoTimer?.cancel();
    _searchHintTimer?.cancel();
    _scrollController.removeListener(_handleScroll);
    _promoPageController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _searchHintNotifier.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _handleScroll() {
    if (!_scrollController.hasClients) return;
    final offset = _scrollController.position.pixels;
    final delta = offset - _lastScrollOffset;

    if (delta.abs() < 6) return;

    if (offset <= 8) {
      if (_showCategoriesBar) {
        setState(() => _showCategoriesBar = false);
      }
      if (offset < -40) {
        _refreshOnTopPull();
      }
    } else if (delta < 0 && !_showCategoriesBar) {
      setState(() => _showCategoriesBar = true);
    } else if (delta > 0 && _showCategoriesBar) {
      setState(() => _showCategoriesBar = false);
    }

    if (_scrollController.position.extentAfter < 300) {
      _loadMoreProductsIfNeeded();
    }

    _lastScrollOffset = offset;
  }

  void _loadMoreProductsIfNeeded() {
    if (_visibleProducts.length <= _visibleProductLimit) return;
    setState(() {
      _visibleProductLimit = min(
        _visibleProductLimit + _productPageSize,
        _visibleProducts.length,
      );
    });
  }

  List<ProductModel> get _displayedProducts {
    final upperBound = min(_visibleProductLimit, _visibleProducts.length);
    if (upperBound <= 0) return const <ProductModel>[];
    return _visibleProducts.sublist(0, upperBound);
  }

  bool get _hasMoreProducts => _visibleProducts.length > _visibleProductLimit;

  void _refreshOnTopPull() {
    if (_isRefreshing) return;
    final now = DateTime.now();
    if (now.difference(_lastTopRefresh) < const Duration(seconds: 2)) {
      return;
    }
    _lastTopRefresh = now;
    _refresh();
  }

  Future<void> _refreshPromoBannersOnly() async {
    try {
      final banners = await context.read<HomeProvider>().fetchPromoBanners();
      if (!mounted) return;
      setState(() {
        _promoBanners
          ..clear()
          ..addAll(banners);
        _currentPromoIndex = 0;
        _isLoadingBanners = false;
      });
      _startPromoAutoPlay();
    } catch (_) {}
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshPromoBannersOnly();
    }
  }

  @override
  void didChangeMetrics() {
    final bottomInset = WidgetsBinding
        .instance.platformDispatcher.views.first.viewInsets.bottom;
    final isVisible = bottomInset > 0.0;
    if (_keyboardVisible && !isVisible && _searchQuery.trim().isNotEmpty) {
      _clearSearch();
    }
    _keyboardVisible = isVisible;
  }

  Widget _buildPromoSection() {
    return HomePromoSection(
      isLoading: _isLoadingBanners,
      banners: _promoBanners,
      controller: _promoPageController,
      currentIndex: _currentPromoIndex,
      onPageChanged: (index) {
        setState(() => _currentPromoIndex = index);
        _startPromoAutoPlay();
      },
      onTap: _handlePromoAction,
    );
  }

  void _handlePromoAction(PromoBannerModel banner) {
    final actionType = banner.actionType.isNotEmpty
        ? banner.actionType
        : (_bannerField(banner, ['route', 'action_type']) ?? '');

    final actionValue = banner.actionValue.isNotEmpty
        ? banner.actionValue
        : (_bannerField(banner, [
              'action_value',
              'product_id',
              'category_id',
              'url',
            ]) ??
            '');

    if (actionType == 'product' && actionValue.isNotEmpty) {
      NavigationHelpers.goToProductDetail(context, actionValue);
      return;
    }

    if (actionType == 'category' && actionValue.isNotEmpty) {
      final name = _bannerField(banner, ['category_name', 'name']) ??
          context.tr(ar: 'القسم', en: 'Section', ckb: 'بەش', ku: 'Beş');
      NavigationHelpers.goToCategoryProducts(context, actionValue, name: name);
      return;
    }

    if (actionType == 'route' && actionValue.isNotEmpty) {
      NavigationHelpers.push(context, actionValue);
      return;
    }

    if (actionType == 'screen' && actionValue.isNotEmpty) {
      final route = _internalScreenToRoute(actionValue);
      if (route != null) {
        NavigationHelpers.push(context, route);
      }
      return;
    }

    if (actionType == 'url' && actionValue.isNotEmpty) {
      _openExternalUrl(actionValue);
      return;
    }

    if (actionType == 'phone' && actionValue.isNotEmpty) {
      _openExternalUrl('tel:$actionValue');
      return;
    }

    if (actionType == 'whatsapp' && actionValue.isNotEmpty) {
      final normalized = actionValue.replaceAll(RegExp(r'[^0-9+]'), '');
      final phone = normalized.replaceAll('+', '');
      if (phone.isNotEmpty) {
        _openExternalUrl('https://wa.me/$phone');
      }
      return;
    }

    if (actionValue.startsWith('/')) {
      NavigationHelpers.push(context, actionValue);
    }
  }

  String? _internalScreenToRoute(String value) {
    switch (value) {
      case 'home':
        return RouteNames.home;
      case 'categories':
        return RouteNames.categories;
      case 'free_donations':
        return RouteNames.freebies;
      case 'cart':
        return RouteNames.cart;
      case 'offers':
        return RouteNames.rfqMyRequests;
      default:
        return null;
    }
  }

  Future<void> _openExternalUrl(String url) async {
    final uri = Uri.tryParse(url.trim());
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Widget _buildTopBar() {
    return HomeTopBar(
      searchController: _searchController,
      searchFocusNode: _searchFocusNode,
      searchHintNotifier: _searchHintNotifier,
      onSearchChanged: (value) {
        _searchQuery = value;
        _applyFilters();
      },
      onClearSearch: _clearSearch,
      onFilterTap: _openFilterBottomSheet,
      imageSearchLoading: _imageSearchLoading,
      onImageSearchTap: _openImageSearchPicker,
      onCartTap: () => NavigationHelpers.goToCart(context),
      onQuickLiveTap: () =>
          NavigationHelpers.push(context, RouteNames.rfqCreate),
      onQuickSellingTap: () =>
          NavigationHelpers.push(context, RouteNames.rfqMyRequests),
      onQuickSavedTap: () =>
          NavigationHelpers.push(context, RouteNames.categories),
      onQuickHistoryTap: () =>
          NavigationHelpers.push(context, RouteNames.orderTrackingHome),
      imageSearchActive: _imageSearchActive,
      imageSearchCount: _imageSearchIds.length,
      onClearImageSearch: _clearImageSearch,
    );
  }

  List<Widget> _buildProductSlivers() {
    return buildHomeProductSlivers(
      context: context,
      isLoadingProducts: _isLoadingProducts,
      isRefreshing: _isRefreshing,
      products: _displayedProducts,
      hasActiveFilters: _hasActiveFilters,
      searchQuery: _searchQuery,
      onEditFilters: _openFilterBottomSheet,
      onResetFilters: _resetFilters,
      onClearSearch: _clearSearch,
    );
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: AppColors.backgroundVariant,
      body: SafeArea(
        child: Stack(
          children: [
            RefreshIndicator(
              onRefresh: _refresh,
              color: colorScheme.primary,
              child: CustomScrollView(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(child: _buildTopBar()),
                  const SliverToBoxAdapter(child: SizedBox(height: 10)),
                  SliverToBoxAdapter(child: _buildPromoSection()),
                  const SliverToBoxAdapter(child: SizedBox(height: 18)),
                  if (_displayedProducts.isNotEmpty)
                    SliverToBoxAdapter(
                      child: HorizontalProductsSection(
                        title: context.tr(
                          ar: 'العناصر التي شاهدتها مؤخراً',
                          en: 'Your recently viewed items',
                          ckb: 'ئەو کاڵایانەی دوایی بینیوتن',
                          ku: 'Berhemên ku dawî dîtine',
                        ),
                        products: _displayedProducts.take(12).toList(),
                        onReturn: _clearSearch,
                      ),
                    ),
                  SliverToBoxAdapter(
                    child: SectionHeader(
                      title: context.tr(
                        ar: 'مقترح لك',
                        en: 'Recommended for you',
                        ckb: 'پێشنیار بۆ تۆ',
                        ku: 'Ji bo te pêşniyar kirî',
                      ),
                      onMoreTap: () {
                        NavigationHelpers.push(context, RouteNames.categories);
                      },
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 10)),
                  ..._buildProductSlivers(),
                  if (_hasMoreProducts)
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Center(
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      ),
                    ),
                  const SliverToBoxAdapter(child: SizedBox(height: 24)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openFilterBottomSheet() {
    final provider = context.read<HomeProvider>();
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => HomeFilterBottomSheet(
        categories: provider.categories,
        isCategoriesLoading: provider.isLoadingHomeData,
        allCarBrands: _allCarBrands,
        initialSelectedCategoryId: _selectedCategoryId,
        initialSelectedBrandId: _selectedBrandId,
        initialSelectedModelId: _selectedModelId,
        initialSelectedYearId: _selectedYearId,
        initialSelectedTrimId: _selectedTrimId,
        initialSelectedSectionV2Id: _selectedSectionV2Id,
        initialSelectedSubsectionId: _selectedSubsectionId,
        initialSelectedPriceRange: _priceRange,
        initialModels: _carModels,
        initialYears: _carYears,
        initialTrims: _carTrims,
        initialSections: _carSectionsV2,
        initialSubsections: _carSubsections,
        minPrice: _minPrice,
        maxPrice: _maxPrice,
        fetchCarModels: (brandId) async {
          try {
            return await context.read<HomeProvider>().fetchCarModels(brandId);
          } catch (_) {
            return <CarLookupItem>[];
          }
        },
        fetchCarYears: (modelId) async {
          try {
            return await context.read<HomeProvider>().fetchCarYears(modelId);
          } catch (_) {
            return <CarLookupItem>[];
          }
        },
        fetchCarTrims: (yearId) async {
          try {
            return await context.read<HomeProvider>().fetchCarTrims(yearId);
          } catch (_) {
            return <CarLookupItem>[];
          }
        },
        fetchCarSectionsV2: (trimId) async {
          try {
            return await context
                .read<HomeProvider>()
                .fetchCarSectionsV2(trimId);
          } catch (_) {
            return <CarLookupItem>[];
          }
        },
        fetchCarSubsections: (sectionV2Id) async {
          try {
            return await context
                .read<HomeProvider>()
                .fetchCarSubsections(sectionV2Id);
          } catch (_) {
            return <CarLookupItem>[];
          }
        },
        onApply: (selection) async {
          setState(() {
            _selectedCategoryId = selection.selectedCategoryId;
            _selectedBrandId = selection.selectedBrandId;
            _selectedModelId = selection.selectedModelId;
            _selectedYearId = selection.selectedYearId;
            _selectedGenerationIdsForYear = null;
            _selectedTrimId = selection.selectedTrimId;
            _selectedSectionV2Id = selection.selectedSectionV2Id;
            _selectedSubsectionId = selection.selectedSubsectionId;
            _priceRange = selection.selectedPriceRange;
            _carModels = selection.models;
            _carYears = selection.years;
            _carTrims = selection.trims;
            _carSectionsV2 = selection.sections;
            _carSubsections = selection.subsections;
          });
          NavigationHelpers.pop(sheetContext);
          await _syncSelectedYearGenerationFilter();
          _applyFilters();
        },
      ),
    );
  }
}
