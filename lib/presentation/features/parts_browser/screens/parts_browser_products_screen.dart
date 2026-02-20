import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;

import '../../../../core/localization/language_text.dart';
import '../../../../data/repositories/catalog_repository.dart';
import '../../../../utils/image_resolvers.dart';
import '../../../../core/config/supabase_config.dart';
import '../../../routing/navigation_helpers.dart';
import '../../../screens/image_search/crop_image_search_screen.dart';
import '../../../screens/image_search/image_search_results_map_sheet.dart';
import 'package:design_system/design_system.dart';

class PartsBrowserProductsScreen extends StatefulWidget {
  const PartsBrowserProductsScreen({
    super.key,
    required this.brandId,
    required this.brandName,
    required this.modelId,
    required this.modelName,
    required this.generationId,
    required this.generationName,
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
  final String generationId;
  final String generationName;
  final String trimId;
  final String trimName;
  final String sectionV2Id;
  final String sectionName;
  final String subsectionId;
  final String subsectionName;

  @override
  State<PartsBrowserProductsScreen> createState() =>
      _PartsBrowserProductsScreenState();
}

class _PartsBrowserProductsScreenState
    extends State<PartsBrowserProductsScreen> {
  static const String _imageSearchEndpoint =
      'https://enxihyplaelrdkievkrk.supabase.co/functions/v1/image_search';

  late final CatalogRepository _catalog;
  late Future<List<Map<String, dynamic>>> _futureProducts;
  final TextEditingController _searchController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();
  String _searchQuery = '';
  String _sortOrder = 'latest';
  bool _imageSearchActive = false;
  bool _imageSearchLoading = false;
  List<String> _imageSearchIds = [];

  @override
  void initState() {
    super.initState();
    _catalog = context.read<CatalogRepository>();
    _searchController.text = _searchQuery;
    _futureProducts = _catalog.fetchProductsForPartsBrowser(
      brandId: widget.brandId,
      modelId: widget.modelId,
      generationId: widget.generationId,
      trimId: widget.trimId,
      sectionV2Id: widget.sectionV2Id,
      subsectionId: widget.subsectionId,
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _applyFilters(
    List<Map<String, dynamic>> products,
  ) {
    final query = _searchQuery.trim().toLowerCase();
    final imageSearchActive = _imageSearchActive;
    final imageSearchIds =
        imageSearchActive ? _imageSearchIds : const <String>[];
    final imageSearchSet = imageSearchActive ? imageSearchIds.toSet() : null;
    final imageSearchOrder = imageSearchActive
        ? {for (var i = 0; i < imageSearchIds.length; i++) imageSearchIds[i]: i}
        : const <String, int>{};
    var filtered = products.where((p) {
      final name = (p['name'] ?? '').toString().toLowerCase();
      final id = p['id']?.toString() ?? '';
      final matchesImage = !imageSearchActive ||
          (imageSearchSet != null && imageSearchSet.contains(id));
      return matchesImage && (query.isEmpty || name.contains(query));
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
          final aDate = DateTime.tryParse(a['created_at']?.toString() ?? '');
          final bDate = DateTime.tryParse(b['created_at']?.toString() ?? '');
          if (aDate == null && bDate == null) return 0;
          if (aDate == null) return 1;
          if (bDate == null) return -1;
          return bDate.compareTo(aDate);
        });
    }

    if (imageSearchActive) {
      filtered.sort((a, b) {
        final aId = a['id']?.toString() ?? '';
        final bId = b['id']?.toString() ?? '';
        final aOrder = imageSearchOrder[aId] ?? 999999;
        final bOrder = imageSearchOrder[bId] ?? 999999;
        return aOrder.compareTo(bOrder);
      });
    }

    return filtered;
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

      setState(() {
        _imageSearchActive = true;
        _imageSearchIds = ids;
        _searchController.clear();
        _searchQuery = '';
      });

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
        return;
      }

      List<Map<String, dynamic>> allProducts = const [];
      try {
        allProducts = await _futureProducts;
      } catch (_) {
        allProducts = const [];
      }
      if (!mounted) return;

      final byId = <String, Map<String, dynamic>>{};
      for (final product in allProducts) {
        final id = product['id']?.toString() ?? '';
        if (id.isNotEmpty) byId[id] = product;
      }

      final productsForSheet = <Map<String, dynamic>>[];
      for (final id in ids) {
        final p = byId[id];
        if (p != null) productsForSheet.add(p);
      }

      if (productsForSheet.isEmpty) {
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
        return;
      }

      await ImageSearchResultsMapSheet.show(
        context,
        queryImage: file,
        products: productsForSheet,
      );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.subsectionName.isEmpty
              ? context.tr(
                  ar: 'نتائج القطع',
                  en: 'Parts results',
                  ckb: 'ئەنجامی پارچەکان',
                  ku: 'Encamên parçeyan',
                )
              : widget.subsectionName,
        ),
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.directions_car_outlined),
            label: Text(
              context.tr(
                  ar: 'تغيير', en: 'Change', ckb: 'گۆڕین', ku: 'Biguherîne'),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${context.tr(ar: 'سيارتك', en: 'Your vehicle', ckb: 'ئۆتۆمبێلەکەت', ku: 'Erebeya te')}: ${widget.brandName} ${widget.modelName} - ${widget.generationName} - ${widget.trimName}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    context.tr(
                        ar: 'تغيير المركبة',
                        en: 'Change vehicle',
                        ckb: 'گۆڕینی ئۆتۆمبێل',
                        ku: 'Erebeyê biguherîne'),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(
                    label: Text(
                        '${context.tr(ar: 'الماركة', en: 'Brand', ckb: 'مارکە', ku: 'Marke')}: ${widget.brandName}')),
                Chip(
                    label: Text(
                        '${context.tr(ar: 'الموديل', en: 'Model', ckb: 'مۆدێل', ku: 'Model')}: ${widget.modelName}')),
                Chip(
                    label: Text(
                        '${context.tr(ar: 'الجيل', en: 'Generation', ckb: 'نەوە', ku: 'Nifş')}: ${widget.generationName}')),
                Chip(
                    label: Text(
                        '${context.tr(ar: 'الفئة', en: 'Trim', ckb: 'تریم', ku: 'Trim')}: ${widget.trimName}')),
                Chip(
                    label: Text(
                        '${context.tr(ar: 'القسم', en: 'Section', ckb: 'بەش', ku: 'Beş')}: ${widget.sectionName}')),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: AppSearchField(
                    controller: _searchController,
                    hintText: context.tr(
                      ar: 'ابحث عن منتج...',
                      en: 'Search products...',
                      ckb: 'بەدوای کاڵادا بگەڕێ...',
                      ku: 'Li berhemekê bigere...',
                    ),
                    onChanged: (value) {
                      if (_imageSearchActive) {
                        _imageSearchActive = false;
                        _imageSearchIds = [];
                      }
                      setState(() => _searchQuery = value);
                    },
                    onClear: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed:
                      _imageSearchLoading ? null : _openImageSearchPicker,
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
                const SizedBox(width: 4),
                DropdownButton<String>(
                  value: _sortOrder,
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
                            ar: 'السعر ↑',
                            en: 'Price ↑',
                            ckb: 'نرخ ↑',
                            ku: 'Buhayê ↑'),
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'price_desc',
                      child: Text(
                        context.tr(
                            ar: 'السعر ↓',
                            en: 'Price ↓',
                            ckb: 'نرخ ↓',
                            ku: 'Buhayê ↓'),
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _sortOrder = value);
                  },
                ),
              ],
            ),
          ),
          if (_imageSearchActive)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
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
                      style: const TextStyle(color: Colors.black54),
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
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _futureProducts,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const AppLoading();
                }
                if (snapshot.hasError) {
                  return AppEmptyState(
                    message:
                        '${context.tr(ar: 'حدث خطأ', en: 'An error occurred', ckb: 'هەڵەیەک ڕوویدا', ku: 'Çewtiyek çêbû')}: ${snapshot.error}',
                    icon: Icons.error_outline,
                  );
                }
                final products = snapshot.data ?? [];
                final filtered = _applyFilters(products);

                if (products.isEmpty) {
                  return AppEmptyState(
                    message: context.tr(
                      ar: 'لا توجد منتجات متاحة لهذه الاختيارات.',
                      en: 'No products available for these selections.',
                      ckb: 'هیچ کاڵایەک بۆ ئەم هەڵبژاردنانە بەردەست نییە.',
                      ku: 'Ji bo van hilbijartinan tu berhem tune ye.',
                    ),
                  );
                }
                if (filtered.isEmpty) {
                  return AppEmptyState(
                    message: context.tr(
                      ar: 'لا توجد نتائج مطابقة للبحث.',
                      en: 'No results match your search.',
                      ckb: 'هیچ ئەنجامێک لەگەڵ گەڕانەکەت ناگونجێت.',
                      ku: 'Tu encam bi lêgerîna te re li hev nayê.',
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final product = filtered[index];
                    final imageUrl = resolveProductImage(product);
                    final price =
                        (product['price'] as num?)?.toStringAsFixed(0) ?? '0';
                    return ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      tileColor: Theme.of(context).cardColor,
                      leading: imageUrl.isEmpty
                          ? const CircleAvatar(child: Icon(Icons.image))
                          : AppImage(
                              imageUrl: imageUrl,
                              width: 40,
                              height: 40,
                              shape: AppImageShape.circle,
                              placeholderIcon: Icons.image,
                            ),
                      title: Text(
                        product['name']?.toString() ??
                            context.tr(
                                ar: 'منتج',
                                en: 'Product',
                                ckb: 'کاڵا',
                                ku: 'Berhem'),
                      ),
                      subtitle: Text(
                        '${context.tr(ar: 'السعر', en: 'Price', ckb: 'نرخ', ku: 'Buhayê')}: $price ${product['currency'] ?? ''}',
                      ),
                      onTap: () {
                        final id = product['id']?.toString();
                        if (id == null || id.isEmpty) return;
                        NavigationHelpers.goToProductDetail(context, id);
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
