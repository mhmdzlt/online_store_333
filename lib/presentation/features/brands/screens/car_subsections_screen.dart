import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/localization/language_text.dart';
import '../../../../data/repositories/catalog_repository.dart';
import '../../../routing/navigation_helpers.dart';
import '../../../routing/route_names.dart';
import 'package:design_system/design_system.dart';

class CarSubsectionsScreen extends StatefulWidget {
  const CarSubsectionsScreen({
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

  @override
  State<CarSubsectionsScreen> createState() => _CarSubsectionsScreenState();
}

class _CarSubsectionsScreenState extends State<CarSubsectionsScreen>
    with WidgetsBindingObserver {
  late final CatalogRepository _catalog;
  late Future<List<Map<String, dynamic>>> _futureSubsections;
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
    _futureSubsections = _catalog.fetchCarSubsections(widget.sectionV2Id);
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
    final value = row['name'] ?? row['subsection'] ?? row['title'] ?? '';
    return value.toString().trim();
  }

  Widget _buildSearchField() {
    return AppSearchField(
      controller: _searchController,
      focusNode: _searchFocusNode,
      hintText: context.tr(
        ar: 'ابحث عن قسم فرعي...',
        en: 'Search subsection...',
        ckb: 'بەدوای بەشی لاوەکیدا بگەڕێ...',
        ku: 'Li binbeşê bigere...',
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
          '${context.tr(ar: 'الأقسام الفرعية', en: 'Subsections', ckb: 'بەشە لاوەکییەکان', ku: 'Binbeş')} - ${widget.sectionName}',
        ),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _futureSubsections,
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

          final subsections = snapshot.data ?? [];
          final query = _searchQuery.trim().toLowerCase();
          final filtered = subsections.where((row) {
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
                    if (subsections.isEmpty) {
                      return AppEmptyState(
                        message: context.tr(
                          ar: 'لا توجد أقسام فرعية متاحة',
                          en: 'No subsections available',
                          ckb: 'هیچ بەشێکی لاوەکی بەردەست نییە',
                          ku: 'Tu binbeş tune ye',
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
                        final subsection = filtered[index];
                        final name = _displayName(subsection);
                        return ListTile(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          tileColor: Theme.of(context).cardColor,
                          title: Text(name),
                          onTap: () async {
                            await NavigationHelpers.push(
                              context,
                              RouteNames.carSubsectionProducts,
                              extra: {
                                'brandId': widget.brandId,
                                'brandName': widget.brandName,
                                'modelId': widget.modelId,
                                'modelName': widget.modelName,
                                'yearId': widget.yearId,
                                'yearName': widget.yearName,
                                'trimId': widget.trimId,
                                'trimName': widget.trimName,
                                'sectionV2Id': widget.sectionV2Id,
                                'sectionName': widget.sectionName,
                                'subsectionId': subsection['id'] as String,
                                'subsectionName': name,
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
