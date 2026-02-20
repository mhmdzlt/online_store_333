import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../../core/localization/language_text.dart';
import '../../../../data/repositories/catalog_repository.dart';
import '../../../routing/navigation_helpers.dart';
import '../../../routing/route_names.dart';
import 'package:design_system/design_system.dart';

class CarTrimsScreen extends StatefulWidget {
  const CarTrimsScreen({
    super.key,
    required this.brandId,
    required this.brandName,
    required this.modelId,
    required this.modelName,
    required this.yearId,
    required this.yearName,
  });

  final String brandId;
  final String brandName;
  final String modelId;
  final String modelName;
  final String yearId;
  final String yearName;

  @override
  State<CarTrimsScreen> createState() => _CarTrimsScreenState();
}

class _CarTrimsScreenState extends State<CarTrimsScreen>
    with WidgetsBindingObserver {
  late final CatalogRepository _catalog;
  late Future<List<Map<String, dynamic>>> _futureTrims;
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
    _futureTrims = _catalog.fetchCarTrims(widget.yearId);
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
    final value = row['name'] ?? row['trim'] ?? row['title'] ?? '';
    return value.toString().trim();
  }

  Widget _buildSearchField() {
    return AppSearchField(
      controller: _searchController,
      focusNode: _searchFocusNode,
      hintText: context.tr(
        ar: 'ابحث عن فئة...',
        en: 'Search trim...',
        ckb: 'بەدوای تریمدا بگەڕێ...',
        ku: 'Li trimê bigere...',
      ),
      onChanged: (value) => setState(() => _searchQuery = value),
      onClear: _clearSearch,
    );
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() => _searchQuery = '');
  }

  Future<void> _showDbReport() async {
    String report;
    try {
      report = context.tr(
        ar: 'راجع البيانات من مصادر Supabase عبر طبقة البيانات.',
        en: 'Review data from Supabase sources through the data layer.',
        ckb: 'زانیارییەکان لە سەرچاوەکانی Supabase لە ڕێگەی چینی داتا ببینە.',
        ku: 'Daneyan ji çavkaniyên Supabase bi qatê daneyan ve binêre.',
      );
    } catch (e) {
      report =
          '${context.tr(ar: 'فشل إنشاء التقرير', en: 'Failed to generate report', ckb: 'دروستکردنی ڕاپۆرت سەرکەوتوو نەبوو', ku: 'Afirandina raporê bi ser neket')}: $e';
    }

    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            context.tr(
              ar: 'تقرير قاعدة البيانات (Supabase)',
              en: 'Database report (Supabase)',
              ckb: 'ڕاپۆرتی بنکەدراوە (Supabase)',
              ku: 'Rapora danegehê (Supabase)',
            ),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: SelectableText(report),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: report));
                if (context.mounted) {
                  NavigationHelpers.pop(context);
                }
              },
              child: Text(
                context.tr(ar: 'نسخ', en: 'Copy', ckb: 'کۆپی', ku: 'Kopî'),
              ),
            ),
            TextButton(
              onPressed: () => NavigationHelpers.pop(context),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${context.tr(ar: 'فئات', en: 'Trims', ckb: 'تریمەکان', ku: 'Trim')} ${widget.yearName} - ${widget.modelName}',
        ),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _futureTrims,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const AppLoading();
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppEmptyState(
                      message:
                          '${context.tr(ar: 'حدث خطأ', en: 'An error occurred', ckb: 'هەڵەیەک ڕوویدا', ku: 'Çewtiyek çêbû')}: ${snapshot.error}',
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: _showDbReport,
                      child: Text(
                        context.tr(
                          ar: 'عرض تقرير قاعدة البيانات',
                          en: 'Show database report',
                          ckb: 'ڕاپۆرتی بنکەدراوە پیشان بدە',
                          ku: 'Rapora danegehê nîşan bide',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          final trims = snapshot.data ?? [];
          final query = _searchQuery.trim().toLowerCase();
          final filtered = trims.where((row) {
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
                    if (trims.isEmpty) {
                      return AppEmptyState(
                        message: context.tr(
                          ar: 'لا توجد فئات متاحة',
                          en: 'No trims available',
                          ckb: 'هیچ تریمێک بەردەست نییە',
                          ku: 'Tu trim tune ye',
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
                        final trim = filtered[index];
                        final name = _displayName(trim);
                        return ListTile(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          tileColor: Theme.of(context).cardColor,
                          title: Text(name),
                          onTap: () async {
                            await NavigationHelpers.push(
                              context,
                              RouteNames.carSectionsV2,
                              extra: {
                                'brandId': widget.brandId,
                                'brandName': widget.brandName,
                                'modelId': widget.modelId,
                                'modelName': widget.modelName,
                                'yearId': widget.yearId,
                                'yearName': widget.yearName,
                                'trimId': trim['id'] as String,
                                'trimName': name,
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
