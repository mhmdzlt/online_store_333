import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../data/models/car/car_brand.dart';
import '../../../../data/repositories/catalog_repository.dart';
import '../../../../core/localization/language_text.dart';
import '../../../routing/navigation_helpers.dart';
import '../../../routing/route_names.dart';
import 'package:design_system/design_system.dart';

class CarBrandsScreen extends StatefulWidget {
  const CarBrandsScreen({super.key});

  @override
  State<CarBrandsScreen> createState() => _CarBrandsScreenState();
}

class _CarBrandsScreenState extends State<CarBrandsScreen>
    with WidgetsBindingObserver {
  late final CatalogRepository _catalog;
  late Future<List<CarBrand>> _futureBrands;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _searchQuery = '';
  String _sortOrder = 'name_asc';
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
    _futureBrands = _catalog.fetchCarBrands().then(
          (rows) => rows.map(CarBrand.fromMap).toList(),
        );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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
      hintText: context.tr(
        ar: 'ابحث عن ماركة...',
        en: 'Search brand...',
        ckb: 'بەدوای مارکەدا بگەڕێ...',
        ku: 'Li markeyê bigere...',
      ),
      onChanged: (value) => setState(() => _searchQuery = value),
      onClear: _clearSearch,
      onFilterTap: _openFilterBottomSheet,
      showFilter: true,
    );
  }

  SliverPadding _buildSkeletonGrid() {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 3 / 4,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) => const _SkeletonCard(),
          childCount: 6,
        ),
      ),
    );
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() => _searchQuery = '');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<List<CarBrand>>(
        future: _futureBrands,
        builder: (context, snapshot) {
          final isLoading = snapshot.connectionState == ConnectionState.waiting;
          final error = snapshot.hasError ? snapshot.error?.toString() : null;
          final brands = snapshot.data ?? [];

          final query = _searchQuery.trim().toLowerCase();
          final filtered = brands.where((brand) {
            final name = brand.name.toLowerCase();
            return query.isEmpty || name.contains(query);
          }).toList();

          if (_sortOrder == 'name_desc') {
            filtered.sort((a, b) => b.name.compareTo(a.name));
          } else {
            filtered.sort((a, b) => a.name.compareTo(b.name));
          }

          return CustomScrollView(
            slivers: [
              SliverAppBar(
                pinned: true,
                expandedHeight: 80,
                title: Text(
                  context.tr(
                    ar: 'اختر ماركة السيارة',
                    en: 'Choose car brand',
                    ckb: 'مارکەی ئۆتۆمبێل هەڵبژێرە',
                    ku: 'Markeya erebeyê hilbijêre',
                  ),
                ),
                centerTitle: true,
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: _buildSearchField(),
                ),
              ),
              if (isLoading) _buildSkeletonGrid(),
              if (!isLoading && error != null)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Text(
                      '${context.tr(ar: 'حدث خطأ', en: 'An error occurred', ckb: 'هەڵەیەک ڕوویدا', ku: 'Çewtiyek çêbû')}: $error',
                    ),
                  ),
                ),
              if (!isLoading && error == null && brands.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Text(
                      context.tr(
                        ar: 'لا توجد ماركات متاحة حالياً',
                        en: 'No brands available right now',
                        ckb: 'ئێستا هیچ مارکەیەک بەردەست نییە',
                        ku: 'Niha tu marke tune ye',
                      ),
                    ),
                  ),
                ),
              if (!isLoading &&
                  error == null &&
                  brands.isNotEmpty &&
                  filtered.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          context.tr(
                            ar: 'لا توجد نتائج مطابقة للبحث.',
                            en: 'No results match your search.',
                            ckb: 'هیچ ئەنجامێک لەگەڵ گەڕانەکەت ناگونجێت.',
                            ku: 'Tu encam bi lêgerîna te re li hev nayê.',
                          ),
                        ),
                        const SizedBox(height: 8),
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
                  ),
                ),
              if (!isLoading && error == null && filtered.isNotEmpty)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  sliver: SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 3 / 4,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final brand = filtered[index];
                        return _BrandGridCard(
                          brand: brand,
                          onTap: () async {
                            await NavigationHelpers.push(
                              context,
                              RouteNames.carModels,
                              extra: {
                                'brandId': brand.id,
                                'brandName': brand.name,
                              },
                            );
                            if (mounted) {
                              _clearSearch();
                            }
                          },
                        );
                      },
                      childCount: filtered.length,
                    ),
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
        return StatefulBuilder(
          builder: (context, sheetSetState) {
            return Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr(
                      ar: 'ترتيب الماركات',
                      en: 'Sort brands',
                      ckb: 'ڕیزبەندی مارکەکان',
                      ku: 'Markeyan rêz bike',
                    ),
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<String>(
                    segments: [
                      ButtonSegment(
                        value: 'name_asc',
                        label: Text(
                          context.tr(
                            ar: 'الاسم (أ - ي)',
                            en: 'Name (A-Z)',
                            ckb: 'ناو (أ - ي)',
                            ku: 'Nav (A-Z)',
                          ),
                        ),
                      ),
                      ButtonSegment(
                        value: 'name_desc',
                        label: Text(
                          context.tr(
                            ar: 'الاسم (ي - أ)',
                            en: 'Name (Z-A)',
                            ckb: 'ناو (ي - أ)',
                            ku: 'Nav (Z-A)',
                          ),
                        ),
                      ),
                    ],
                    selected: {selectedSort},
                    onSelectionChanged: (selection) {
                      sheetSetState(() => selectedSort = selection.first);
                    },
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            sheetSetState(() => selectedSort = 'name_asc');
                          },
                          child: Text(
                            context.tr(
                                ar: 'إعادة الضبط',
                                en: 'Reset',
                                ckb: 'ڕێکخستنەوە',
                                ku: 'Reset'),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            setState(() => _sortOrder = selectedSort);
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
            );
          },
        );
      },
    );
  }
}

class _BrandGridCard extends StatelessWidget {
  const _BrandGridCard({
    required this.brand,
    required this.onTap,
  });

  final CarBrand brand;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fallbackChar =
        brand.name.isNotEmpty ? brand.name.characters.first : '?';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: brand.imageUrl != null && brand.imageUrl!.isNotEmpty
                      ? AppImage(
                          imageUrl: brand.imageUrl!,
                          fit: BoxFit.cover,
                          radius: 12,
                          placeholderIcon: Icons.directions_car_filled,
                        )
                      : Center(
                          child: Text(
                            fallbackChar,
                            style: theme.textTheme.titleLarge,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                brand.name,
                style: theme.textTheme.bodyMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: const Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          children: [
            Expanded(child: _SkeletonBox()),
            SizedBox(height: 8),
            _SkeletonBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _SkeletonBox extends StatelessWidget {
  const _SkeletonBox({this.height});

  final double? height;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.4, end: 0.9),
      duration: const Duration(milliseconds: 900),
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Container(
            height: height,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      },
      onEnd: () {},
    );
  }
}

class CarBrandGridCard extends StatelessWidget {
  final CarBrand brand;
  final VoidCallback? onTap;

  const CarBrandGridCard({super.key, required this.brand, this.onTap});

  @override
  Widget build(BuildContext context) {
    final String? imageUrl = brand.imageUrl;
    final String name = brand.name;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
                child: imageUrl != null && imageUrl.isNotEmpty
                    ? AppImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.cover,
                        radius: 16,
                        placeholderIcon: Icons.directions_car_filled,
                      )
                    : const Center(
                        child: Icon(
                          Icons.directions_car_filled,
                          size: 40,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 4,
              ),
              child: Text(
                name,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
