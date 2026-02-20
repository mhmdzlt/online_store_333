import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/localization/language_text.dart';
import '../../../../data/repositories/catalog_repository.dart';
import '../../../routing/navigation_helpers.dart';
import '../../../routing/route_names.dart';
import 'package:design_system/design_system.dart';

class CarYearsScreen extends StatefulWidget {
  const CarYearsScreen({
    super.key,
    required this.brandId,
    required this.brandName,
    required this.modelId,
    required this.modelName,
  });

  final String brandId;
  final String brandName;
  final String modelId;
  final String modelName;

  @override
  State<CarYearsScreen> createState() => _CarYearsScreenState();
}

class _CarYearsScreenState extends State<CarYearsScreen>
    with WidgetsBindingObserver {
  late final CatalogRepository _catalog;
  late Future<List<Map<String, dynamic>>> _futureYears;
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
    _futureYears = _catalog.fetchCarYears(widget.modelId);
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
    final value = row['year'] ?? row['name'] ?? row['title'] ?? '';
    return value.toString().trim();
  }

  Widget _buildSearchField() {
    return AppSearchField(
      controller: _searchController,
      focusNode: _searchFocusNode,
      hintText: context.tr(
        ar: 'ابحث عن سنة...',
        en: 'Search year...',
        ckb: 'بەدوای ساڵدا بگەڕێ...',
        ku: 'Li salê bigere...',
      ),
      onChanged: (value) => setState(() => _searchQuery = value),
      onClear: _clearSearch,
    );
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() => _searchQuery = '');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${context.tr(ar: 'سنوات', en: 'Years', ckb: 'ساڵەکان', ku: 'Sal')} ${widget.modelName}',
        ),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _futureYears,
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

          final years = snapshot.data ?? [];
          final query = _searchQuery.trim().toLowerCase();
          final filtered = years.where((row) {
            final name = _displayName(row).toLowerCase();
            return query.isEmpty || name.contains(query);
          }).toList();

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: _buildSearchField(),
              ),
              Expanded(
                child: Builder(
                  builder: (context) {
                    if (years.isEmpty) {
                      return AppEmptyState(
                        message: context.tr(
                          ar: 'لا توجد سنوات متاحة',
                          en: 'No years available',
                          ckb: 'هیچ ساڵێک بەردەست نییە',
                          ku: 'Tu sal tune ye',
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
                      );
                    }
                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final year = filtered[index];
                        final name = _displayName(year);
                        return ListTile(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          tileColor: Theme.of(context).cardColor,
                          title: Text(name),
                          onTap: () async {
                            await NavigationHelpers.push(
                              context,
                              RouteNames.carTrims,
                              extra: {
                                'brandId': widget.brandId,
                                'brandName': widget.brandName,
                                'modelId': widget.modelId,
                                'modelName': widget.modelName,
                                'yearId': year['id'] as String,
                                'yearName': name,
                              },
                            );
                            if (mounted) {
                              _clearSearch();
                            }
                          },
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
}
