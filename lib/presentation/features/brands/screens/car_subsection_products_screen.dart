import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../data/repositories/catalog_repository.dart';
import '../../../../core/localization/language_text.dart';
import '../../../../utils/image_resolvers.dart';
import '../../../routing/navigation_helpers.dart';
import 'package:design_system/design_system.dart';

class CarSubsectionProductsScreen extends StatefulWidget {
  const CarSubsectionProductsScreen({
    super.key,
    required this.brandId,
    required this.brandName,
    required this.modelId,
    required this.modelName,
    required this.yearId,
    required this.yearName,
    required this.trimId,
    required this.trimName,
    required this.sectionV2Id,
    required this.sectionName,
    required this.subsectionId,
    required this.subsectionName,
  });

  final String brandId;
  final String brandName;
  final String modelId;
  final String modelName;
  final String yearId;
  final String yearName;
  final String trimId;
  final String trimName;
  final String sectionV2Id;
  final String sectionName;
  final String subsectionId;
  final String subsectionName;

  @override
  State<CarSubsectionProductsScreen> createState() =>
      _CarSubsectionProductsScreenState();
}

class _CarSubsectionProductsScreenState
    extends State<CarSubsectionProductsScreen> with WidgetsBindingObserver {
  late final CatalogRepository _catalog;
  late Future<List<Map<String, dynamic>>> _futureProducts;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  Timer? _searchHintTimer;
  String _searchQuery = '';
  String _searchHintText = 'Search products...';
  List<String> _searchHints = [];
  int _searchHintIndex = 0;
  String _sortOrder = 'latest';
  double _minPrice = 0;
  double _maxPrice = 0;
  RangeValues? _priceRange;
  bool _keyboardVisible = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _catalog = context.read<CatalogRepository>();
    _searchFocusNode.addListener(() {
      if (!_searchFocusNode.hasFocus && _searchQuery.isNotEmpty) {
        _clearSearch();
      }
    });
    _startSearchHintRotation();
    _futureProducts = _catalog.fetchProductsByCarHierarchy(
      brandId: widget.brandId,
      modelId: widget.modelId,
      yearId: widget.yearId,
      trimId: widget.trimId,
      sectionV2Id: widget.sectionV2Id,
      subsectionId: widget.subsectionId,
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchHintTimer?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
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

  Widget _buildSearchField() {
    return AppSearchField(
      controller: _searchController,
      focusNode: _searchFocusNode,
      hintText: _searchHintText,
      onChanged: (value) => setState(() => _searchQuery = value),
      onClear: _clearSearch,
      onFilterTap: _openFilterBottomSheet,
      showFilter: true,
    );
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() => _searchQuery = '');
  }

  void _resetFilters() {
    setState(() {
      _sortOrder = 'latest';
      if (_maxPrice > 0) {
        _priceRange = RangeValues(_minPrice, _maxPrice);
      } else {
        _priceRange = null;
      }
    });
  }

  void _scheduleSearchHintUpdate(List<Map<String, dynamic>> products) {
    final names = <String>{};
    for (final product in products) {
      final name = (product['name'] ?? '').toString().trim();
      if (name.isNotEmpty) names.add(name);
    }
    final nextHints = names.take(10).toList();

    if (listEquals(nextHints, _searchHints)) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _searchHints = nextHints;
        _searchHintIndex = 0;
        if (_searchQuery.trim().isEmpty) {
          _searchHintText = nextHints.isNotEmpty
              ? nextHints.first
              : context.tr(
                  ar: 'ابحث عن منتج...',
                  en: 'Search products...',
                  ckb: 'بەدوای کاڵادا بگەڕێ...',
                  ku: 'Li berhemekê bigere...',
                );
        }
      });
    });
  }

  void _startSearchHintRotation() {
    _searchHintTimer?.cancel();
    _searchHintTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (!mounted) return;
      if (_searchQuery.trim().isNotEmpty) return;
      if (_searchHints.isEmpty) return;

      _searchHintIndex = (_searchHintIndex + 1) % _searchHints.length;
      setState(() {
        _searchHintText = _searchHints[_searchHintIndex];
      });
    });
  }

  bool get _hasActiveFilters {
    final hasQuery = _searchQuery.trim().isNotEmpty;
    final hasPrice = _priceRange != null &&
        (_priceRange!.start > _minPrice || _priceRange!.end < _maxPrice);
    return hasQuery || hasPrice;
  }

  void _updatePriceBounds(List<Map<String, dynamic>> products) {
    if (products.isEmpty) {
      _minPrice = 0;
      _maxPrice = 0;
      _priceRange = null;
      return;
    }

    final prices =
        products.map((p) => (p['price'] as num?)?.toDouble() ?? 0).toList();
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

  String _imageForProduct(Map<String, dynamic> product) {
    final imageUrl = product['image_url'];
    if (imageUrl is String && imageUrl.isNotEmpty) {
      return imageUrl;
    }
    return resolveProductImage(product);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${context.tr(ar: 'منتجات', en: 'Products', ckb: 'کاڵاکان', ku: 'Berhem')} ${widget.subsectionName}',
        ),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _futureProducts,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const AppLoading();
          }
          if (snapshot.hasError) {
            return AppEmptyState(
              message:
                  '${context.tr(ar: 'حدث خطأ', en: 'An error occurred', ckb: 'هەڵەیەک ڕوویدا', ku: 'Çewtiyek çêbû')}: ${snapshot.error}',
            );
          }

          final products = snapshot.data ?? [];
          _updatePriceBounds(products);
          final query = _searchQuery.trim().toLowerCase();
          final priceRange = _priceRange;
          final filtered = products.where((product) {
            final name = (product['name'] ?? '').toString().toLowerCase();
            final matchesSearch = query.isEmpty || name.contains(query);
            final price = (product['price'] as num?)?.toDouble() ?? 0;
            final matchesPrice = priceRange == null ||
                (price >= priceRange.start && price <= priceRange.end);
            return matchesSearch && matchesPrice;
          }).toList();

          switch (_sortOrder) {
            case 'price_asc':
              filtered.sort((a, b) {
                final aPrice = (a['price'] as num?)?.toDouble() ?? 0;
                final bPrice = (b['price'] as num?)?.toDouble() ?? 0;
                return aPrice.compareTo(bPrice);
              });
              break;
            case 'price_desc':
              filtered.sort((a, b) {
                final aPrice = (a['price'] as num?)?.toDouble() ?? 0;
                final bPrice = (b['price'] as num?)?.toDouble() ?? 0;
                return bPrice.compareTo(aPrice);
              });
              break;
            case 'latest':
            default:
              filtered.sort((a, b) {
                final aDate =
                    DateTime.tryParse((a['created_at'] ?? '').toString()) ??
                        DateTime(1970);
                final bDate =
                    DateTime.tryParse((b['created_at'] ?? '').toString()) ??
                        DateTime(1970);
                return bDate.compareTo(aDate);
              });
          }

          _scheduleSearchHintUpdate(filtered);

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: _buildSearchField(),
              ),
              Expanded(
                child: Builder(
                  builder: (context) {
                    if (products.isEmpty) {
                      return AppEmptyState(
                        message: context.tr(
                          ar: 'لا توجد منتجات متاحة',
                          en: 'No products available',
                          ckb: 'هیچ کاڵایەک بەردەست نییە',
                          ku: 'Tu berhem tune ye',
                        ),
                      );
                    }
                    if (filtered.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              context.tr(
                                ar: 'لا توجد نتائج مطابقة للفلاتر.',
                                en: 'No results match the selected filters.',
                                ckb:
                                    'هیچ ئەنجامێک لەگەڵ فلتەرە هەڵبژێردراوەکان ناگونجێت.',
                                ku: 'Tu encam bi fîlterên hilbijartî re li hev nayên.',
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (_hasActiveFilters)
                              Wrap(
                                spacing: 8,
                                children: [
                                  OutlinedButton(
                                    onPressed: _openFilterBottomSheet,
                                    child: Text(
                                      context.tr(
                                          ar: 'تعديل الفلاتر',
                                          en: 'Edit filters',
                                          ckb: 'گۆڕینی فلتەرەکان',
                                          ku: 'Fîlteran biguherîne'),
                                    ),
                                  ),
                                  OutlinedButton(
                                    onPressed: _resetFilters,
                                    child: Text(
                                      context.tr(
                                          ar: 'مسح الفلاتر',
                                          en: 'Clear filters',
                                          ckb: 'سڕینەوەی فلتەرەکان',
                                          ku: 'Fîlteran paqij bike'),
                                    ),
                                  ),
                                  if (_searchQuery.trim().isNotEmpty)
                                    OutlinedButton(
                                      onPressed: _clearSearch,
                                      child: Text(
                                        context.tr(
                                            ar: 'مسح البحث',
                                            en: 'Clear search',
                                            ckb: 'سڕینەوەی گەڕان',
                                            ku: 'Lêgerînê paqij bike'),
                                      ),
                                    ),
                                ],
                              ),
                          ],
                        ),
                      );
                    }
                    return GridView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 0.68,
                      ),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final product = filtered[index];
                        final imageUrl = _imageForProduct(product);
                        final name = product['name'] as String? ?? '';
                        final price =
                            (product['price'] as num?)?.toDouble() ?? 0;
                        final oldPrice =
                            (product['old_price'] as num?)?.toDouble();
                        final currency =
                            product['currency'] as String? ?? 'IQD';
                        return Card(
                          color: Colors.white,
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: () async {
                              NavigationHelpers.goToProductDetail(
                                context,
                                product['id'] as String,
                              );
                              if (mounted) {
                                _clearSearch();
                              }
                            },
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                AspectRatio(
                                  aspectRatio: 1.1,
                                  child: imageUrl.isNotEmpty
                                      ? AppImage(
                                          imageUrl: imageUrl,
                                          fit: BoxFit.cover,
                                          radius: 0,
                                        )
                                      : Container(
                                          color: Colors.grey.shade200,
                                          child: const Icon(
                                              Icons.image_not_supported),
                                        ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 8),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        name,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w600),
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          Text(
                                            '${price.toStringAsFixed(0)} $currency',
                                            style: TextStyle(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .primary,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          if (oldPrice != null &&
                                              oldPrice > price) ...[
                                            const SizedBox(width: 8),
                                            Text(
                                              oldPrice.toStringAsFixed(0),
                                              style: const TextStyle(
                                                color: Colors.black54,
                                                decoration:
                                                    TextDecoration.lineThrough,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _openFilterBottomSheet() {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        var selectedSort = _sortOrder;
        var selectedRange = _priceRange;
        return StatefulBuilder(
          builder: (context, sheetSetState) {
            return Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr(
                        ar: 'فلترة حسب',
                        en: 'Filter by',
                        ckb: 'فلتەرکردن بە',
                        ku: 'Li gorî fîlter bike',
                      ),
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: selectedSort,
                      decoration: InputDecoration(
                        labelText: context.tr(
                            ar: 'الترتيب',
                            en: 'Sort',
                            ckb: 'ڕیزبەندی',
                            ku: 'Rêzkirin'),
                      ),
                      items: [
                        DropdownMenuItem(
                          value: 'latest',
                          child: Text(
                            context.tr(
                                ar: 'الأحدث',
                                en: 'Latest',
                                ckb: 'نوێترین',
                                ku: 'Nûtirîn'),
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'price_asc',
                          child: Text(
                            context.tr(
                                ar: 'السعر: من الأقل للأعلى',
                                en: 'Price: low to high',
                                ckb: 'نرخ: لە کەمەوە بۆ زۆر',
                                ku: 'Buhayê: ji kêm ber bi zêde'),
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'price_desc',
                          child: Text(
                            context.tr(
                                ar: 'السعر: من الأعلى للأقل',
                                en: 'Price: high to low',
                                ckb: 'نرخ: لە زۆرەوە بۆ کەم',
                                ku: 'Buhayê: ji zêde ber bi kêm'),
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        sheetSetState(() {
                          selectedSort = value ?? 'latest';
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    if (_maxPrice > 0)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.tr(
                                ar: 'السعر',
                                en: 'Price',
                                ckb: 'نرخ',
                                ku: 'Buhayê'),
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          RangeSlider(
                            values: selectedRange ??
                                RangeValues(_minPrice, _maxPrice),
                            min: _minPrice,
                            max: _maxPrice,
                            divisions: _maxPrice > _minPrice ? 10 : null,
                            labels: RangeLabels(
                              (selectedRange?.start ?? _minPrice)
                                  .toStringAsFixed(0),
                              (selectedRange?.end ?? _maxPrice)
                                  .toStringAsFixed(0),
                            ),
                            onChanged: (values) {
                              sheetSetState(() {
                                selectedRange = values;
                              });
                            },
                          ),
                        ],
                      ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              sheetSetState(() {
                                selectedSort = 'latest';
                                selectedRange = _maxPrice > 0
                                    ? RangeValues(_minPrice, _maxPrice)
                                    : null;
                              });
                            },
                            child: Text(
                              context.tr(
                                  ar: 'مسح الفلاتر',
                                  en: 'Clear filters',
                                  ckb: 'سڕینەوەی فلتەرەکان',
                                  ku: 'Fîlteran paqij bike'),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              setState(() {
                                _sortOrder = selectedSort;
                                _priceRange = selectedRange;
                              });
                              NavigationHelpers.pop(context);
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
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
