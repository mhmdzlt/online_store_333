import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/localization/language_text.dart';
import '../../../../data/repositories/catalog_repository.dart';
import '../../../routing/navigation_helpers.dart';
import '../../../routing/route_names.dart';
import 'package:design_system/design_system.dart';

class CarModelsScreen extends StatefulWidget {
  const CarModelsScreen({
    super.key,
    required this.brandId,
    required this.brandName,
  });

  final String brandId;
  final String brandName;

  @override
  State<CarModelsScreen> createState() => _CarModelsScreenState();
}

class _CarModelsScreenState extends State<CarModelsScreen>
    with WidgetsBindingObserver {
  late final CatalogRepository _catalog;
  late Future<List<Map<String, dynamic>>> _futureModels;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _searchQuery = '';
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
    _futureModels = _catalog.fetchCarModels(widget.brandId);
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

  String _displayName(Map<String, dynamic> row) {
    final value = row['name'] ?? row['model'] ?? row['title'] ?? '';
    return value.toString().trim();
  }

  Widget _buildSearchField() {
    return AppSearchField(
      controller: _searchController,
      focusNode: _searchFocusNode,
      hintText: context.tr(
        ar: 'ابحث عن موديل...',
        en: 'Search model...',
        ckb: 'بەدوای مۆدێلدا بگەڕێ...',
        ku: 'Li modelê bigere...',
        watch: false,
      ),
      onChanged: (value) => setState(() => _searchQuery = value),
      onClear: _clearSearch,
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
          childAspectRatio: 3 / 2.4,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) => const _ModelSkeletonCard(),
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
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _futureModels,
        builder: (context, snapshot) {
          final isLoading = snapshot.connectionState == ConnectionState.waiting;
          final error = snapshot.hasError ? snapshot.error?.toString() : null;
          final models = snapshot.data ?? [];
          final query = _searchQuery.trim().toLowerCase();
          final filtered = models.where((row) {
            final name = _displayName(row).toLowerCase();
            return query.isEmpty || name.contains(query);
          }).toList();

          return CustomScrollView(
            slivers: [
              SliverAppBar(
                pinned: true,
                expandedHeight: 80,
                title: Text(
                  '${context.tr(ar: 'موديلات', en: 'Models', ckb: 'مۆدێلەکان', ku: 'Model')} ${widget.brandName}',
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
                  child: AppEmptyState(
                    message:
                        '${context.tr(ar: 'حدث خطأ', en: 'An error occurred', ckb: 'هەڵەیەک ڕوویدا', ku: 'Çewtiyek çêbû')}: $error',
                  ),
                ),
              if (!isLoading && error == null && models.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: AppEmptyState(
                    message: context.tr(
                      ar: 'لا توجد موديلات متاحة',
                      en: 'No models available',
                      ckb: 'هیچ مۆدێلێک بەردەست نییە',
                      ku: 'Tu model tune ye',
                    ),
                  ),
                ),
              if (!isLoading &&
                  error == null &&
                  models.isNotEmpty &&
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
                      childAspectRatio: 3 / 2.4,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final model = filtered[index];
                        final name = _displayName(model);
                        return _ModelGridCard(
                          title: name,
                          onTap: () async {
                            await NavigationHelpers.push(
                              context,
                              RouteNames.carYears,
                              extra: {
                                'brandId': widget.brandId,
                                'brandName': widget.brandName,
                                'modelId': model['id'] as String,
                                'modelName': name,
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
}

class _ModelGridCard extends StatelessWidget {
  const _ModelGridCard({
    required this.title,
    required this.onTap,
  });

  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor:
                    Theme.of(context).colorScheme.surfaceContainerHighest,
                child: const Icon(Icons.directions_car),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModelSkeletonCard extends StatelessWidget {
  const _ModelSkeletonCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: const Padding(
        padding: EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _SkeletonBox(size: 48),
            SizedBox(height: 12),
            _SkeletonBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _SkeletonBox extends StatelessWidget {
  const _SkeletonBox({this.height, this.size});

  final double? height;
  final double? size;

  @override
  Widget build(BuildContext context) {
    final dimension = size ?? height;
    return Container(
      height: dimension,
      width: size ?? double.infinity,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }
}
