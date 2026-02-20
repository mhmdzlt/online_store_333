import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:online_store_333/presentation/screens/image_search/crop_image_search_screen.dart';
import 'package:online_store_333/presentation/screens/image_search/image_search_results_sheet.dart';

import '../../../../data/models/product/product_model.dart';
import '../../../../data/repositories/product_repository.dart';
import '../../../../core/services/tracking_service.dart';
import '../../../../core/config/supabase_config.dart';
import '../../../../core/localization/language_text.dart';
import '../../../routing/navigation_helpers.dart';
import 'package:design_system/design_system.dart';

class ProductListByCategoryScreen extends StatefulWidget {
  final String categoryId;
  final String categoryName;

  const ProductListByCategoryScreen({
    super.key,
    required this.categoryId,
    required this.categoryName,
  });

  @override
  State<ProductListByCategoryScreen> createState() =>
      _ProductListByCategoryScreenState();
}

class _ProductListByCategoryScreenState
    extends State<ProductListByCategoryScreen> with WidgetsBindingObserver {
  static const String _imageSearchEndpoint =
      'https://enxihyplaelrdkievkrk.supabase.co/functions/v1/image_search';

  late final ProductRepository _productRepository;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final ImagePicker _imagePicker = ImagePicker();
  Timer? _searchHintTimer;

  List<ProductModel> _allProducts = [];
  List<ProductModel> _visibleProducts = [];
  bool _isLoading = false;
  String _searchQuery = '';
  final ValueNotifier<String> _searchHintNotifier = ValueNotifier<String>(
    'Search products...',
  );
  List<String> _searchHints = [];
  int _searchHintIndex = 0;
  String _sortOrder = 'latest';
  double _minPrice = 0;
  double _maxPrice = 0;
  RangeValues? _priceRange;
  bool _keyboardVisible = false;
  bool _imageSearchActive = false;
  bool _imageSearchLoading = false;
  List<String> _imageSearchIds = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _productRepository = context.read<ProductRepository>();
    TrackingService.instance.trackScreen(
      'category_products:${widget.categoryId}',
    );
    _searchFocusNode.addListener(() {
      if (!_searchFocusNode.hasFocus && _searchQuery.isNotEmpty) {
        _clearSearch();
      }
    });
    _startSearchHintRotation();
    _loadProducts();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchHintTimer?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _searchHintNotifier.dispose();
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    final bottomInset = WidgetsBinding
        .instance.platformDispatcher.views.first.viewInsets.bottom;
    final isVisible = bottomInset > 0.0;
    if (_keyboardVisible && !isVisible && _searchQuery.isNotEmpty) {
      _clearSearch();
    }
    _keyboardVisible = isVisible;
  }

  Future<void> _loadProducts() async {
    setState(() => _isLoading = true);
    try {
      final products =
          await _productRepository.fetchProductsByCategory(widget.categoryId);
      _allProducts = products;
      _updatePriceBounds();
      _applyFilters();
    } catch (_) {
      _allProducts = [];
      _visibleProducts = [];
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _applyFilters() {
    final query = _searchQuery.trim().toLowerCase();
    final imageSearchActive = _imageSearchActive;
    final imageSearchIds =
        imageSearchActive ? _imageSearchIds : const <String>[];
    final imageSearchSet = imageSearchActive ? imageSearchIds.toSet() : null;
    final imageSearchOrder = imageSearchActive
        ? {for (var i = 0; i < imageSearchIds.length; i++) imageSearchIds[i]: i}
        : const <String, int>{};
    final priceRange = _priceRange;
    final filtered = _allProducts.where((product) {
      final matchesImage = !imageSearchActive ||
          (imageSearchSet != null && imageSearchSet.contains(product.id));
      final name = product.name.toLowerCase();
      final matchesSearch = query.isEmpty || name.contains(query);
      final price = product.price;
      final matchesPrice = priceRange == null ||
          (price >= priceRange.start && price <= priceRange.end);
      return matchesImage && matchesSearch && matchesPrice;
    }).toList();

    switch (_sortOrder) {
      case 'price_asc':
        filtered.sort((a, b) {
          return a.price.compareTo(b.price);
        });
        break;
      case 'price_desc':
        filtered.sort((a, b) {
          return b.price.compareTo(a.price);
        });
        break;
      case 'latest':
      default:
        filtered.sort((a, b) {
          final aDate = a.createdAt ?? DateTime(1970);
          final bDate = b.createdAt ?? DateTime(1970);
          return bDate.compareTo(aDate);
        });
    }

    if (imageSearchActive) {
      filtered.sort((a, b) {
        final aOrder = imageSearchOrder[a.id] ?? 999999;
        final bOrder = imageSearchOrder[b.id] ?? 999999;
        return aOrder.compareTo(bOrder);
      });
    }

    if (query.isNotEmpty) {
      TrackingService.instance.trackSearch(
        screen: 'category_products:${widget.categoryId}',
        query: query,
      );
    }

    if (mounted) {
      setState(() {
        _visibleProducts = filtered;
        _refreshSearchHintsFromProducts(filtered);
      });
    } else {
      _visibleProducts = filtered;
    }
  }

  void _refreshSearchHintsFromProducts(List<ProductModel> products) {
    final names = <String>{};
    for (final product in products) {
      final name = product.name.trim();
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

  Widget _buildSearchField() {
    return Row(
      children: [
        Expanded(
          child: AppSearchField(
            controller: _searchController,
            focusNode: _searchFocusNode,
            hintListenable: _searchHintNotifier,
            onChanged: (value) {
              if (_imageSearchActive) {
                _imageSearchActive = false;
                _imageSearchIds = [];
              }
              _searchQuery = value;
              _applyFilters();
            },
            onClear: _clearSearch,
            onFilterTap: _openFilterBottomSheet,
            showFilter: true,
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          onPressed: _imageSearchLoading ? null : _openImageSearchPicker,
          icon: _imageSearchLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.photo_camera_outlined),
          tooltip: context.tr(
            ar: 'بحث بالصورة',
            en: 'Search by image',
            ckb: 'گەڕان بە وێنە',
            ku: 'Bi wêne bigere',
          ),
        ),
      ],
    );
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
    _priceRange = RangeValues(_minPrice, _maxPrice);
  }

  void _clearSearch() {
    _searchController.clear();
    _searchQuery = '';
    _applyFilters();
  }

  Future<void> _openImageSearchPicker() async {
    if (_imageSearchLoading) return;
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: Text(
                  context.tr(
                    ar: 'التقاط صورة',
                    en: 'Take a photo',
                    ckb: 'وێنە بگرە',
                    ku: 'Wêne bikişîne',
                  ),
                ),
                onTap: () => NavigationHelpers.pop(context, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: Text(
                  context.tr(
                    ar: 'اختيار من المعرض',
                    en: 'Choose from gallery',
                    ckb: 'لە گەلەری هەڵبژێرە',
                    ku: 'Ji galeriyê hilbijêre',
                  ),
                ),
                onTap: () =>
                    NavigationHelpers.pop(context, ImageSource.gallery),
              ),
            ],
          ),
        );
      },
    );

    if (source == null) return;
    final picked = await _imagePicker.pickImage(
      source: source,
      maxWidth: 1280,
      maxHeight: 1280,
      imageQuality: 85,
    );
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

  Future<void> _openFilterBottomSheet() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        var tempSort = _sortOrder;
        RangeValues tempRange =
            _priceRange ?? RangeValues(_minPrice, _maxPrice);

        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr(
                      ar: 'تصفية المنتجات',
                      en: 'Filter products',
                      ckb: 'فلتەرکردنی کاڵاکان',
                      ku: 'Berheman fîlter bike',
                    ),
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    context.tr(
                        ar: 'الترتيب',
                        en: 'Sort',
                        ckb: 'ڕیزبەندی',
                        ku: 'Rêzkirin'),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      ChoiceChip(
                        label: Text(
                          context.tr(
                              ar: 'الأحدث',
                              en: 'Latest',
                              ckb: 'نوێترین',
                              ku: 'Nûtirîn'),
                        ),
                        selected: tempSort == 'latest',
                        onSelected: (_) {
                          setModalState(() => tempSort = 'latest');
                        },
                      ),
                      ChoiceChip(
                        label: Text(
                          context.tr(
                              ar: 'السعر: الأقل',
                              en: 'Price: low to high',
                              ckb: 'نرخ: لە کەمەوە بۆ زۆر',
                              ku: 'Buhayê: ji kêm ber bi zêde'),
                        ),
                        selected: tempSort == 'price_asc',
                        onSelected: (_) {
                          setModalState(() => tempSort = 'price_asc');
                        },
                      ),
                      ChoiceChip(
                        label: Text(
                          context.tr(
                              ar: 'السعر: الأعلى',
                              en: 'Price: high to low',
                              ckb: 'نرخ: لە زۆرەوە بۆ کەم',
                              ku: 'Buhayê: ji zêde ber bi kêm'),
                        ),
                        selected: tempSort == 'price_desc',
                        onSelected: (_) {
                          setModalState(() => tempSort = 'price_desc');
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    context.tr(
                        ar: 'الحدود السعرية',
                        en: 'Price range',
                        ckb: 'مەودای نرخ',
                        ku: 'Navbera buhayê'),
                  ),
                  RangeSlider(
                    values: tempRange,
                    min: _minPrice,
                    max: _maxPrice,
                    onChanged: (range) {
                      setModalState(() => tempRange = range);
                    },
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => NavigationHelpers.pop(context),
                          child: Text(
                            context.tr(
                                ar: 'إلغاء',
                                en: 'Cancel',
                                ckb: 'هەڵوەشاندنەوە',
                                ku: 'Betal'),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            _sortOrder = tempSort;
                            _priceRange = tempRange;
                            NavigationHelpers.pop(context, 'apply');
                          },
                          child: Text(
                            context.tr(
                                ar: 'تطبيق',
                                en: 'Apply',
                                ckb: 'جێبەجێکردن',
                                ku: 'Bikaranîn'),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            );
          },
        );
      },
    );

    if (selected == 'apply') {
      _applyFilters();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.categoryName),
        centerTitle: true,
      ),
      body: RefreshIndicator(
        onRefresh: _loadProducts,
        child: _isLoading
            ? ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 48),
                  AppLoading(),
                ],
              )
            : ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                cacheExtent: 600,
                itemCount: _visibleProducts.length + 1,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return Column(
                      children: [
                        _buildSearchField(),
                        const SizedBox(height: 12),
                        if (_imageSearchActive)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.image_search,
                                  size: 16,
                                  color: Colors.black54,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    _imageSearchIds.isEmpty
                                        ? context.tr(
                                            ar: 'بحث بالصورة بدون نتائج',
                                            en: 'Image search with no results',
                                            ckb: 'گەڕان بە وێنە بێ ئەنجام',
                                            ku: 'Lêgerîna bi wêne bê encam',
                                          )
                                        : context.tr(
                                            ar: 'بحث بالصورة (${_imageSearchIds.length} نتيجة)',
                                            en: 'Image search (${_imageSearchIds.length} results)',
                                            ckb:
                                                'گەڕان بە وێنە (${_imageSearchIds.length} ئەنجام)',
                                            ku: 'Lêgerîna bi wêne (${_imageSearchIds.length} encam)',
                                          ),
                                    style:
                                        const TextStyle(color: Colors.black54),
                                  ),
                                ),
                                TextButton.icon(
                                  onPressed: _clearImageSearch,
                                  icon: const Icon(Icons.close, size: 16),
                                  label: Text(
                                    context.tr(
                                        ar: 'إلغاء',
                                        en: 'Cancel',
                                        ckb: 'هەڵوەشاندنەوە',
                                        ku: 'Betal'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (_visibleProducts.isEmpty)
                          AppEmptyState(
                            message: context.tr(
                              ar: 'لا توجد منتجات متاحة',
                              en: 'No products available',
                              ckb: 'هیچ کاڵایەک بەردەست نییە',
                              ku: 'Tu berhem tune ye',
                            ),
                          ),
                      ],
                    );
                  }

                  final product = _visibleProducts[index - 1];
                  final name = product.name;
                  final price = product.price;
                  final imageUrl = _resolveProductImage(product);

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      onTap: () {
                        NavigationHelpers.goToProductDetail(
                          context,
                          product.id,
                        );
                      },
                      leading: imageUrl.isEmpty
                          ? Container(
                              width: 50,
                              height: 50,
                              color: Colors.grey.shade200,
                              child: const Icon(Icons.image_not_supported),
                            )
                          : AppImage(
                              imageUrl: imageUrl,
                              width: 50,
                              height: 50,
                              fit: BoxFit.cover,
                              radius: 6,
                            ),
                      title: Text(name),
                      subtitle: Text(
                        '${price.toStringAsFixed(0)} د.ع',
                        style: TextStyle(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }

  String _resolveProductImage(ProductModel product) {
    final images = product.imageUrls;
    if (images.isNotEmpty) return images.first;
    return '';
  }
}
