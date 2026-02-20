import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/localization/language_text.dart';
import '../../../providers/home_provider.dart';
import '../../../../data/models/category/category_model.dart';
import '../../../routing/navigation_helpers.dart';
import 'package:design_system/design_system.dart';

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen>
    with WidgetsBindingObserver {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _searchQuery = '';
  String _sortOrder = 'name_asc';
  bool _isLoading = false;
  List<CategoryModel> _allCategories = [];
  List<CategoryModel> _visibleCategories = [];
  bool _keyboardVisible = false;

  Widget _sectionCard(List<Widget> children) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            children[i],
            if (i != children.length - 1)
              Divider(height: 1, color: theme.colorScheme.outlineVariant),
          ],
        ],
      ),
    );
  }

  Widget _categoryTile(CategoryModel category) {
    final theme = Theme.of(context);
    final name = category.name;
    final initial = name.trim().isEmpty ? '?' : name.characters.first;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      leading: CircleAvatar(
        radius: 18,
        backgroundColor: theme.colorScheme.secondaryContainer,
        child: Text(
          initial,
          style: theme.textTheme.titleSmall?.copyWith(
            color: theme.colorScheme.onSecondaryContainer,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      title: Text(name),
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () {
        NavigationHelpers.goToCategoryProducts(
          context,
          category.id,
          name: name,
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _searchFocusNode.addListener(() {
      if (!_searchFocusNode.hasFocus && _searchQuery.isNotEmpty) {
        _clearSearch();
      }
    });
    _loadCategories();
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
        ar: 'ابحث عن قسم...',
        en: 'Search section...',
        ckb: 'بەدوای پۆل بگەڕێ...',
        ku: 'Li kategoriyekê bigere...',
      ),
      onChanged: (value) {
        _searchQuery = value;
        _applyFilters();
      },
      onClear: _clearSearch,
      onFilterTap: _openFilterBottomSheet,
      showFilter: true,
    );
  }

  void _clearSearch() {
    _searchController.clear();
    _searchQuery = '';
    _applyFilters();
  }

  Future<void> _loadCategories() async {
    setState(() => _isLoading = true);
    try {
      final result = await context.read<HomeProvider>().fetchCategories();
      _allCategories = result;
      _applyFilters();
    } catch (_) {
      _allCategories = [];
      _visibleCategories = [];
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _applyFilters() {
    final query = _searchQuery.trim().toLowerCase();
    final filtered = _allCategories.where((cat) {
      final name = cat.name.toLowerCase();
      return query.isEmpty || name.contains(query);
    }).toList();

    if (_sortOrder == 'name_desc') {
      filtered.sort((a, b) {
        return b.name.compareTo(a.name);
      });
    } else {
      filtered.sort((a, b) {
        return a.name.compareTo(b.name);
      });
    }

    if (mounted) {
      setState(() => _visibleCategories = filtered);
    } else {
      _visibleCategories = filtered;
    }
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
                      ar: 'ترتيب الأقسام',
                      en: 'Sections sorting',
                      ckb: 'ڕیزکردنی پۆلەکان',
                      ku: 'Rêzkirina kategoriyan',
                    ),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<String>(
                    segments: [
                      ButtonSegment(
                        value: 'name_asc',
                        label: Text(context.tr(
                          ar: 'الاسم (أ - ي)',
                          en: 'Name (A - Z)',
                          ckb: 'ناو (ئە - ی)',
                          ku: 'Nav (A - Z)',
                        )),
                      ),
                      ButtonSegment(
                        value: 'name_desc',
                        label: Text(context.tr(
                          ar: 'الاسم (ي - أ)',
                          en: 'Name (Z - A)',
                          ckb: 'ناو (ی - ئە)',
                          ku: 'Nav (Z - A)',
                        )),
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
                          child: Text(context.tr(
                            ar: 'إعادة الضبط',
                            en: 'Reset',
                            ckb: 'ڕیسێت',
                            ku: 'Reset',
                          )),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            setState(() => _sortOrder = selectedSort);
                            _applyFilters();
                            NavigationHelpers.pop(context);
                          },
                          child: Text(context.tr(
                            ar: 'تطبيق',
                            en: 'Apply',
                            ckb: 'جێبەجێکردن',
                            ku: 'Sepandin',
                          )),
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surfaceContainerLowest,
      appBar: AppBar(
        title: Text(context.tr(
          ar: 'الأقسام',
          en: 'Sections',
          ckb: 'پۆلەکان',
          ku: 'Kategorî',
        )),
        centerTitle: true,
      ),
      body: _isLoading
          ? const AppLoading()
          : RefreshIndicator(
              onRefresh: _loadCategories,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(24),
                      border:
                          Border.all(color: theme.colorScheme.outlineVariant),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.tr(
                            ar: 'تصفّح الأقسام',
                            en: 'Browse sections',
                            ckb: 'گەڕان بەناو پۆلەکاندا',
                            ku: 'Li nav kategoriyan bigere',
                          ),
                          style: theme.textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          context.tr(
                            ar: 'اختر القسم المناسب للانتقال إلى المنتجات.',
                            en: 'Choose a section to jump to products.',
                            ckb: 'پۆلی گونجاو هەڵبژێرە بۆ چوون بۆ کاڵاکان.',
                            ku: 'Kategoriyeke guncav hilbijêre da ku biçî berheman.',
                          ),
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _sectionCard([
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: _buildSearchField(),
                    ),
                  ]),
                  const SizedBox(height: 12),
                  if (_visibleCategories.isEmpty)
                    _sectionCard([
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 24,
                        ),
                        child: AppEmptyState(
                          message: context.tr(
                            ar: 'لا توجد أقسام',
                            en: 'No sections found',
                            ckb: 'هیچ پۆلێک نییە',
                            ku: 'Tu kategorî nehatin dîtin',
                          ),
                        ),
                      ),
                    ])
                  else
                    _sectionCard(
                        _visibleCategories.map(_categoryTile).toList()),
                  const SizedBox(height: 12),
                ],
              ),
            ),
    );
  }
}
