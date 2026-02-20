import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/localization/language_text.dart';
import '../../../../data/repositories/catalog_repository.dart';
import '../../../../core/services/vehicle_garage_service_v2.dart';
import '../../../routing/navigation_helpers.dart';
import '../../../routing/route_names.dart';
import 'package:design_system/design_system.dart';

class PartsBrowserScreen extends StatefulWidget {
  const PartsBrowserScreen({super.key});

  @override
  State<PartsBrowserScreen> createState() => _PartsBrowserScreenState();
}

class _PartsBrowserScreenState extends State<PartsBrowserScreen> {
  late final CatalogRepository _catalog;
  final VehicleGarageServiceV2 _garageService = VehicleGarageServiceV2();

  int _currentStep = 0;

  bool _loadingGarage = true;
  bool _pendingGarageApply = false;
  List<VehicleGarageEntryV2> _garageEntries = const <VehicleGarageEntryV2>[];
  VehicleGarageEntryV2? _lastGarage;

  final List<Map<String, dynamic>> _brands = [];
  final List<Map<String, dynamic>> _models = [];
  final List<Map<String, dynamic>> _generations = [];
  final List<Map<String, dynamic>> _trims = [];
  final List<Map<String, dynamic>> _sections = [];
  final List<Map<String, dynamic>> _subsections = [];

  final Map<String, List<Map<String, dynamic>>> _modelsCache = {};
  final Map<String, List<Map<String, dynamic>>> _generationsCache = {};
  final Map<String, List<Map<String, dynamic>>> _trimsCache = {};
  final Map<String, List<Map<String, dynamic>>> _sectionsCache = {};
  final Map<String, List<Map<String, dynamic>>> _subsectionsCache = {};

  bool _loadingBrands = false;
  bool _loadingModels = false;
  bool _loadingGenerations = false;
  bool _loadingTrims = false;
  bool _loadingSections = false;
  bool _loadingSubsections = false;

  String? _errorBrands;
  String? _errorModels;
  String? _errorGenerations;
  String? _errorTrims;
  String? _errorSections;
  String? _errorSubsections;

  String? _selectedBrandId;
  String? _selectedBrandName;
  String? _selectedModelId;
  String? _selectedModelName;
  String? _selectedGenerationId;
  String? _selectedGenerationName;
  String? _selectedTrimId;
  String? _selectedTrimName;
  String? _selectedSectionId;
  String? _selectedSectionName;
  String? _selectedSubsectionId;
  String? _selectedSubsectionName;

  String _brandQuery = '';
  String _modelQuery = '';
  String _generationQuery = '';
  String _trimQuery = '';
  String _sectionQuery = '';
  String _subsectionQuery = '';

  final TextEditingController _brandController = TextEditingController();
  final TextEditingController _modelController = TextEditingController();
  final TextEditingController _generationController = TextEditingController();
  final TextEditingController _trimController = TextEditingController();
  final TextEditingController _sectionController = TextEditingController();
  final TextEditingController _subsectionController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _catalog = context.read<CatalogRepository>();
    _loadBrands();
    _loadGarage();
  }

  @override
  void dispose() {
    _brandController.dispose();
    _modelController.dispose();
    _generationController.dispose();
    _trimController.dispose();
    _sectionController.dispose();
    _subsectionController.dispose();
    super.dispose();
  }

  Future<void> _loadBrands() async {
    setState(() {
      _loadingBrands = true;
      _errorBrands = null;
    });
    try {
      final res = await _catalog.fetchCarBrands();
      if (!mounted) return;
      setState(() {
        _brands
          ..clear()
          ..addAll(res);
      });
      if (_pendingGarageApply && _lastGarage != null) {
        _pendingGarageApply = false;
        await _applyGarageEntry(_lastGarage!);
      }
    } catch (e) {
      setState(() => _errorBrands = e.toString());
    } finally {
      if (mounted) {
        setState(() => _loadingBrands = false);
      }
    }
  }

  Future<void> _loadModels(String brandId) async {
    if (_modelsCache.containsKey(brandId)) {
      setState(() {
        _models
          ..clear()
          ..addAll(_modelsCache[brandId]!);
      });
      return;
    }
    setState(() {
      _loadingModels = true;
      _errorModels = null;
    });
    try {
      final res = await _catalog.fetchCarModels(brandId);
      _modelsCache[brandId] = res;
      setState(() {
        _models
          ..clear()
          ..addAll(res);
      });
    } catch (e) {
      setState(() => _errorModels = e.toString());
    } finally {
      if (mounted) {
        setState(() => _loadingModels = false);
      }
    }
  }

  Future<void> _loadGenerations(String modelId) async {
    if (_generationsCache.containsKey(modelId)) {
      setState(() {
        _generations
          ..clear()
          ..addAll(_generationsCache[modelId]!);
      });
      return;
    }
    setState(() {
      _loadingGenerations = true;
      _errorGenerations = null;
    });
    try {
      final res = await _catalog.fetchCarGenerations(modelId);
      _generationsCache[modelId] = res;
      setState(() {
        _generations
          ..clear()
          ..addAll(res);
      });
    } catch (e) {
      setState(() => _errorGenerations = e.toString());
    } finally {
      if (mounted) {
        setState(() => _loadingGenerations = false);
      }
    }
  }

  Future<void> _loadTrims(String generationId) async {
    if (_trimsCache.containsKey(generationId)) {
      setState(() {
        _trims
          ..clear()
          ..addAll(_trimsCache[generationId]!);
      });
      return;
    }
    setState(() {
      _loadingTrims = true;
      _errorTrims = null;
    });
    try {
      final res = await _catalog.fetchCarTrimsByGeneration(generationId);
      _trimsCache[generationId] = res;
      setState(() {
        _trims
          ..clear()
          ..addAll(res);
      });
    } catch (e) {
      setState(() => _errorTrims = e.toString());
    } finally {
      if (mounted) {
        setState(() => _loadingTrims = false);
      }
    }
  }

  Future<void> _loadSections(String trimId) async {
    if (_sectionsCache.containsKey(trimId)) {
      setState(() {
        _sections
          ..clear()
          ..addAll(_sectionsCache[trimId]!);
      });
      return;
    }
    setState(() {
      _loadingSections = true;
      _errorSections = null;
    });
    try {
      final res = await _catalog.fetchCarSectionsV2(trimId);
      _sectionsCache[trimId] = res;
      setState(() {
        _sections
          ..clear()
          ..addAll(res);
      });
    } catch (e) {
      setState(() => _errorSections = e.toString());
    } finally {
      if (mounted) {
        setState(() => _loadingSections = false);
      }
    }
  }

  Future<void> _loadSubsections(String sectionId) async {
    if (_subsectionsCache.containsKey(sectionId)) {
      setState(() {
        _subsections
          ..clear()
          ..addAll(_subsectionsCache[sectionId]!);
      });
      return;
    }
    setState(() {
      _loadingSubsections = true;
      _errorSubsections = null;
    });
    try {
      final res = await _catalog.fetchCarSubsections(sectionId);
      _subsectionsCache[sectionId] = res;
      setState(() {
        _subsections
          ..clear()
          ..addAll(res);
      });
    } catch (e) {
      setState(() => _errorSubsections = e.toString());
    } finally {
      if (mounted) {
        setState(() => _loadingSubsections = false);
      }
    }
  }

  Future<void> _loadGarage() async {
    setState(() => _loadingGarage = true);
    try {
      final entries = await _garageService.loadEntries();
      final last = await _garageService.loadLast();

      if (!mounted) return;
      setState(() {
        _garageEntries = entries;
        _lastGarage = last;
        _loadingGarage = false;
      });

      if (last != null) {
        if (_brands.isNotEmpty) {
          await _applyGarageEntry(last);
        } else {
          _pendingGarageApply = true;
        }
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingGarage = false);
    }
  }

  VehicleGarageEntryV2? _currentVehicleEntryOrNull() {
    final brandId = _selectedBrandId;
    final brandName = _selectedBrandName;
    final modelId = _selectedModelId;
    final modelName = _selectedModelName;
    final generationId = _selectedGenerationId;
    final generationLabel = _selectedGenerationName;
    final trimId = _selectedTrimId;
    final trimName = _selectedTrimName;

    if (brandId == null ||
        brandName == null ||
        modelId == null ||
        modelName == null ||
        generationId == null ||
        generationLabel == null ||
        trimId == null ||
        trimName == null) {
      return null;
    }

    return VehicleGarageEntryV2(
      brandId: brandId,
      brandName: brandName,
      modelId: modelId,
      modelName: modelName,
      generationId: generationId,
      generationLabel: generationLabel,
      trimId: trimId,
      trimName: trimName,
    );
  }

  Future<void> _saveCurrentVehicleToGarage() async {
    final entry = _currentVehicleEntryOrNull();
    if (entry == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr(
              ar: 'اختر السيارة حتى مستوى الفئة أولاً',
              en: 'Select vehicle up to trim level first',
              ckb: 'سەرەتا ئۆتۆمبێلەکە تا ئاستی تریم هەڵبژێرە',
              ku: 'Pêşî erebeyê heya asta trim hilbijêre',
            ),
          ),
        ),
      );
      return;
    }

    await _garageService.addOrBump(entry, max: 3);
    final entries = await _garageService.loadEntries();
    final last = await _garageService.loadLast();
    if (!mounted) return;
    setState(() {
      _garageEntries = entries;
      _lastGarage = last;
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(
      SnackBar(
        content: Text(
          context.tr(
            ar: 'تم حفظ المركبة في مركباتي',
            en: 'Vehicle saved to my garage',
            ckb: 'ئۆتۆمبێلەکە لە ئۆتۆمبێلەکانم پاشەکەوتکرا',
            ku: 'Erebe li garaja min hate tomarkirin',
          ),
        ),
      ),
    );
  }

  Future<void> _removeGarageEntry(VehicleGarageEntryV2 entry) async {
    await _garageService.removeByKey(entry.key);
    final entries = await _garageService.loadEntries();
    final last = await _garageService.loadLast();
    if (!mounted) return;
    setState(() {
      _garageEntries = entries;
      _lastGarage = last;
    });
  }

  Future<void> _applyGarageEntry(VehicleGarageEntryV2 entry) async {
    if (!mounted) return;

    setState(() {
      _selectedBrandId = entry.brandId;
      _selectedBrandName = entry.brandName;
      _resetBelowBrand();
      _currentStep = 1;
    });
    await _loadModels(entry.brandId);
    if (!mounted) return;

    final modelFromCache =
        _models.where((m) => m['id']?.toString() == entry.modelId).toList();
    if (modelFromCache.isEmpty) return;

    setState(() {
      _selectedModelId = entry.modelId;
      _selectedModelName = _displayName(modelFromCache.first);
      _resetBelowModel();
      _currentStep = 2;
    });
    await _loadGenerations(entry.modelId);
    if (!mounted) return;

    final genFromCache = _generations
        .where((g) => g['id']?.toString() == entry.generationId)
        .toList();
    if (genFromCache.isEmpty) return;

    setState(() {
      _selectedGenerationId = entry.generationId;
      _selectedGenerationName = _generationLabel(genFromCache.first);
      _resetBelowGeneration();
      _currentStep = 3;
    });
    await _loadTrims(entry.generationId);
    if (!mounted) return;

    final trimFromCache =
        _trims.where((t) => t['id']?.toString() == entry.trimId).toList();
    if (trimFromCache.isEmpty) return;

    setState(() {
      _selectedTrimId = entry.trimId;
      _selectedTrimName = _displayName(trimFromCache.first);
      _resetBelowTrim();
      _currentStep = 4;
    });
    await _loadSections(entry.trimId);
    if (!mounted) return;

    await _garageService.saveLast(entry);
    setState(() => _lastGarage = entry);
  }

  void _resetBelowBrand() {
    _selectedModelId = null;
    _selectedModelName = null;
    _selectedGenerationId = null;
    _selectedGenerationName = null;
    _selectedTrimId = null;
    _selectedTrimName = null;
    _selectedSectionId = null;
    _selectedSectionName = null;
    _selectedSubsectionId = null;
    _selectedSubsectionName = null;
    _models.clear();
    _generations.clear();
    _trims.clear();
    _sections.clear();
    _subsections.clear();
    _modelQuery = '';
    _generationQuery = '';
    _trimQuery = '';
    _sectionQuery = '';
    _subsectionQuery = '';
  }

  void _resetBelowModel() {
    _selectedGenerationId = null;
    _selectedGenerationName = null;
    _selectedTrimId = null;
    _selectedTrimName = null;
    _selectedSectionId = null;
    _selectedSectionName = null;
    _selectedSubsectionId = null;
    _selectedSubsectionName = null;
    _generations.clear();
    _trims.clear();
    _sections.clear();
    _subsections.clear();
    _generationQuery = '';
    _trimQuery = '';
    _sectionQuery = '';
    _subsectionQuery = '';
  }

  void _resetBelowGeneration() {
    _selectedTrimId = null;
    _selectedTrimName = null;
    _selectedSectionId = null;
    _selectedSectionName = null;
    _selectedSubsectionId = null;
    _selectedSubsectionName = null;
    _trims.clear();
    _sections.clear();
    _subsections.clear();
    _trimQuery = '';
    _sectionQuery = '';
    _subsectionQuery = '';
  }

  void _resetBelowTrim() {
    _selectedSectionId = null;
    _selectedSectionName = null;
    _selectedSubsectionId = null;
    _selectedSubsectionName = null;
    _sections.clear();
    _subsections.clear();
    _sectionQuery = '';
    _subsectionQuery = '';
  }

  void _resetBelowSection() {
    _selectedSubsectionId = null;
    _selectedSubsectionName = null;
    _subsections.clear();
    _subsectionQuery = '';
  }

  String _displayName(Map<String, dynamic> row) {
    final value = row['name'] ??
        row['title'] ??
        row['model'] ??
        row['trim'] ??
        row['section'] ??
        row['subsection'] ??
        row['label'] ??
        '';
    return value.toString().trim();
  }

  String _generationLabel(Map<String, dynamic> row) {
    final name = _displayName(row);
    final fromRaw = row['year_from'];
    final toRaw = row['year_to'];
    final from = fromRaw?.toString() ?? '';
    final toInt =
        toRaw is num ? toRaw.toInt() : int.tryParse(toRaw?.toString() ?? '');
    final toLabel = toInt == 9999
        ? context.tr(
            ar: 'مستمر', en: 'Present', ckb: 'بەردەوام', ku: 'Heta niha')
        : (toRaw?.toString() ?? '');
    final range = [
      from,
      toLabel,
    ].where((e) => e.toString().trim().isNotEmpty).join(' - ');
    if (name.isNotEmpty && range.isNotEmpty) return '$name ($range)';
    if (name.isNotEmpty) return name;
    return range.isNotEmpty
        ? range
        : context.tr(
            ar: 'جيل غير مسمى',
            en: 'Unnamed generation',
            ckb: 'نەوەی بێ ناو',
            ku: 'Nifşê bê nav');
  }

  Widget _buildSummaryChip(String label, String? value) {
    if (value == null || value.trim().isEmpty) return const SizedBox.shrink();
    return Chip(
      label: Text('$label: $value'),
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
    );
  }

  Widget _buildStepContent({
    required String hint,
    required String query,
    required TextEditingController controller,
    required ValueChanged<String> onQueryChanged,
    required bool isLoading,
    required String? error,
    required List<Map<String, dynamic>> items,
    required String Function(Map<String, dynamic>) labelBuilder,
    required void Function(Map<String, dynamic>) onSelect,
    required VoidCallback onRetry,
    String emptyMessage = 'لا توجد نتائج متاحة',
  }) {
    final filtered = items.where((row) {
      final name = labelBuilder(row).toLowerCase();
      return query.trim().isEmpty || name.contains(query.trim().toLowerCase());
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSearchField(
          controller: controller,
          hintText: hint,
          onChanged: onQueryChanged,
          onClear: () {
            controller.clear();
            onQueryChanged('');
          },
        ),
        const SizedBox(height: 8),
        Text(
          '${context.tr(ar: 'عدد النتائج', en: 'Results count', ckb: 'ژمارەی ئەنجامەکان', ku: 'Hejmara encaman')}: ${filtered.length}',
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 280,
          child: Builder(
            builder: (context) {
              if (isLoading) {
                return const AppLoading();
              }
              if (error != null) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${context.tr(ar: 'حدث خطأ', en: 'An error occurred', ckb: 'هەڵەیەک ڕوویدا', ku: 'Çewtiyek çêbû')}: $error',
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton(
                        onPressed: onRetry,
                        child: Text(
                          context.tr(
                              ar: 'إعادة المحاولة',
                              en: 'Retry',
                              ckb: 'دووبارە هەوڵدانەوە',
                              ku: 'Careke din biceribîne'),
                        ),
                      ),
                    ],
                  ),
                );
              }
              if (items.isEmpty) {
                return AppEmptyState(
                  message: emptyMessage,
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
                      OutlinedButton(
                        onPressed: () => onQueryChanged(''),
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
                itemCount: filtered.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final row = filtered[index];
                  final name = labelBuilder(row);
                  return ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    tileColor: Theme.of(context).cardColor,
                    title: Text(name),
                    onTap: () => onSelect(row),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  StepState _stepState(bool isSelected) =>
      isSelected ? StepState.editing : StepState.indexed;

  bool get _canShowResults {
    return _selectedBrandId != null &&
        _selectedModelId != null &&
        _selectedGenerationId != null &&
        _selectedTrimId != null &&
        _selectedSectionId != null &&
        _selectedSubsectionId != null;
  }

  Widget _buildSummaryHeader() {
    final chips = <Widget>[
      _buildSummaryChip(
          context.tr(ar: 'الماركة', en: 'Brand', ckb: 'مارکە', ku: 'Marke'),
          _selectedBrandName),
      _buildSummaryChip(
          context.tr(ar: 'الموديل', en: 'Model', ckb: 'مۆدێل', ku: 'Model'),
          _selectedModelName),
      _buildSummaryChip(
          context.tr(ar: 'الجيل', en: 'Generation', ckb: 'نەوە', ku: 'Nifş'),
          _selectedGenerationName),
      _buildSummaryChip(
          context.tr(ar: 'الفئة', en: 'Trim', ckb: 'تریم', ku: 'Trim'),
          _selectedTrimName),
      _buildSummaryChip(
          context.tr(ar: 'القسم', en: 'Section', ckb: 'بەش', ku: 'Beş'),
          _selectedSectionName),
      _buildSummaryChip(
          context.tr(
              ar: 'الفرعي', en: 'Subsection', ckb: 'لاوەکی', ku: 'Binbeş'),
          _selectedSubsectionName),
    ].where((w) => w is! SizedBox).toList();

    if (chips.isEmpty) {
      chips.add(
        Chip(
          label: Text(
            context.tr(
              ar: 'ابدأ باختيار الماركة',
              en: 'Start by selecting a brand',
              ckb: 'بە هەڵبژاردنی مارکە دەستپێبکە',
              ku: 'Bi hilbijartina markeyê dest pê bike',
            ),
          ),
        ),
      );
    }

    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: SizedBox(
        height: 72,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(vertical: 12),
          itemCount: chips.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (_, index) => chips[index],
        ),
      ),
    );
  }

  Widget _buildGarageCard() {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.garage_outlined),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'مركباتي',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                TextButton.icon(
                  onPressed: _selectedTrimId == null
                      ? null
                      : _saveCurrentVehicleToGarage,
                  icon: const Icon(Icons.bookmark_add_outlined, size: 18),
                  label: Text(
                    context.tr(
                        ar: 'حفظ',
                        en: 'Save',
                        ckb: 'پاشەکەوتکردن',
                        ku: 'Tomar bike'),
                  ),
                ),
              ],
            ),
            Text(
              context.tr(
                ar: 'حتى 3 مركبات محفوظة',
                en: 'Up to 3 saved vehicles',
                ckb: 'تا 3 ئۆتۆمبێلی پاشەکەوتکراو',
                ku: 'Heta 3 erebeyên tomar kirî',
              ),
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.grey.shade700),
            ),
            const SizedBox(height: 8),
            if (_loadingGarage)
              const AppLoading(
                size: 20,
                padding: EdgeInsets.symmetric(vertical: 8),
              )
            else if (_garageEntries.isEmpty)
              Text(
                context.tr(
                  ar: 'لا توجد مركبات محفوظة. اختر السيارة ثم اضغط “حفظ”.',
                  en: 'No saved vehicles. Select a vehicle then tap "Save".',
                  ckb:
                      'هیچ ئۆتۆمبێلێکی پاشەکەوتکراو نییە. ئۆتۆمبێلێک هەڵبژێرە و پاشان "پاشەکەوتکردن" بکە.',
                  ku: 'Tu erebeyên tomar kirî tune ne. Erebeyek hilbijêre û paşê "Save" bike.',
                ),
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Colors.grey.shade700),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _garageEntries.map((e) {
                  final selected = _lastGarage?.key == e.key;
                  return InputChip(
                    selected: selected,
                    showCheckmark: false,
                    selectedColor: colorScheme.primaryContainer,
                    label: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${e.brandName} ${e.modelName}',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          e.generationLabel,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: Colors.grey.shade700),
                        ),
                        Text(
                          e.trimName,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: Colors.grey.shade700),
                        ),
                      ],
                    ),
                    avatar: Icon(
                      selected ? Icons.check_circle : Icons.directions_car,
                      size: 18,
                      color: selected
                          ? colorScheme.onPrimaryContainer
                          : colorScheme.primary,
                    ),
                    onPressed: () => _applyGarageEntry(e),
                    onDeleted: () => _removeGarageEntry(e),
                    deleteIcon: const Icon(Icons.close),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          context.tr(
            ar: 'متصفح القطع (تجريبي)',
            en: 'Parts Browser (Beta)',
            ckb: 'گەڕۆکی پارچەکان (تاقیکردنەوە)',
            ku: 'Geroka parçeyan (beta)',
          ),
        ),
        actions: [
          IconButton(
            tooltip: context.tr(
              ar: 'حفظ المركبة الحالية',
              en: 'Save current vehicle',
              ckb: 'پاشەکەوتکردنی ئۆتۆمبێلی ئێستا',
              ku: 'Erebeya niha tomar bike',
            ),
            onPressed:
                _selectedTrimId == null ? null : _saveCurrentVehicleToGarage,
            icon: const Icon(Icons.bookmark_add_outlined),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: SizedBox(
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _canShowResults
                  ? () async {
                      final entry = _currentVehicleEntryOrNull();
                      if (entry != null) {
                        setState(() => _lastGarage = entry);
                        _garageService.saveLast(entry);
                      }
                      NavigationHelpers.push(
                        context,
                        RouteNames.partsBrowserProducts,
                        extra: {
                          'brandId': _selectedBrandId!,
                          'brandName': _selectedBrandName ?? '',
                          'modelId': _selectedModelId!,
                          'modelName': _selectedModelName ?? '',
                          'generationId': _selectedGenerationId!,
                          'generationName': _selectedGenerationName ?? '',
                          'trimId': _selectedTrimId!,
                          'trimName': _selectedTrimName ?? '',
                          'sectionV2Id': _selectedSectionId!,
                          'sectionName': _selectedSectionName ?? '',
                          'subsectionId': _selectedSubsectionId!,
                          'subsectionName': _selectedSubsectionName ?? '',
                        },
                      );
                    }
                  : null,
              icon: const Icon(Icons.shopping_bag_outlined),
              label: Text(
                context.tr(
                    ar: 'عرض المنتجات',
                    en: 'View products',
                    ckb: 'پیشاندانی کاڵاکان',
                    ku: 'Berheman nîşan bide'),
              ),
            ),
          ),
        ),
      ),
      body: CustomScrollView(
        slivers: [
          SliverPersistentHeader(
            pinned: true,
            delegate: _StickyHeaderDelegate(
              minHeight: 72,
              maxHeight: 72,
              child: _buildSummaryHeader(),
            ),
          ),
          SliverToBoxAdapter(child: _buildGarageCard()),
          SliverToBoxAdapter(
            child: Stepper(
              currentStep: _currentStep,
              onStepTapped: (value) => setState(() => _currentStep = value),
              controlsBuilder: (_, __) => const SizedBox.shrink(),
              steps: [
                Step(
                  title: Text(
                    context.tr(
                        ar: 'الماركة', en: 'Brand', ckb: 'مارکە', ku: 'Marke'),
                  ),
                  state: _stepState(_currentStep == 0),
                  content: _buildStepContent(
                    hint: context.tr(
                        ar: 'ابحث عن ماركة...',
                        en: 'Search brand...',
                        ckb: 'بەدوای مارکەدا بگەڕێ...',
                        ku: 'Li markeyê bigere...'),
                    query: _brandQuery,
                    controller: _brandController,
                    onQueryChanged: (value) =>
                        setState(() => _brandQuery = value),
                    isLoading: _loadingBrands,
                    error: _errorBrands,
                    items: _brands,
                    labelBuilder: (row) => (row['name'] ?? '').toString(),
                    onRetry: _loadBrands,
                    onSelect: (row) async {
                      final id = row['id']?.toString();
                      final name = (row['name'] ?? '').toString();
                      if (id == null || id.isEmpty) return;
                      setState(() {
                        _selectedBrandId = id;
                        _selectedBrandName = name;
                        _resetBelowBrand();
                        _currentStep = 1;
                      });
                      await _loadModels(id);
                    },
                    emptyMessage: context.tr(
                        ar: 'لا توجد ماركات متاحة حالياً',
                        en: 'No brands available right now',
                        ckb: 'ئێستا هیچ مارکەیەک بەردەست نییە',
                        ku: 'Niha tu marke tune ye'),
                  ),
                ),
                Step(
                  title: Text(
                    context.tr(
                        ar: 'الموديل', en: 'Model', ckb: 'مۆدێل', ku: 'Model'),
                  ),
                  state: _stepState(_currentStep == 1),
                  content: _buildStepContent(
                    hint: context.tr(
                        ar: 'ابحث عن موديل...',
                        en: 'Search model...',
                        ckb: 'بەدوای مۆدێلدا بگەڕێ...',
                        ku: 'Li modelê bigere...'),
                    query: _modelQuery,
                    controller: _modelController,
                    onQueryChanged: (value) =>
                        setState(() => _modelQuery = value),
                    isLoading: _loadingModels,
                    error: _errorModels,
                    items: _models,
                    labelBuilder: _displayName,
                    onRetry: () {
                      final brandId = _selectedBrandId;
                      if (brandId != null) {
                        _loadModels(brandId);
                      }
                    },
                    onSelect: (row) async {
                      final id = row['id']?.toString();
                      if (id == null || id.isEmpty) return;
                      setState(() {
                        _selectedModelId = id;
                        _selectedModelName = _displayName(row);
                        _resetBelowModel();
                        _currentStep = 2;
                      });
                      await _loadGenerations(id);
                    },
                    emptyMessage: context.tr(
                        ar: 'لا توجد موديلات متاحة لهذه الماركة',
                        en: 'No models available for this brand',
                        ckb: 'هیچ مۆدێلێک بۆ ئەم مارکەیە بەردەست نییە',
                        ku: 'Ji bo vê markeyê tu model tune ye'),
                  ),
                ),
                Step(
                  title: Text(
                    context.tr(
                        ar: 'الجيل', en: 'Generation', ckb: 'نەوە', ku: 'Nifş'),
                  ),
                  state: _stepState(_currentStep == 2),
                  content: _buildStepContent(
                    hint: context.tr(
                        ar: 'ابحث عن الجيل...',
                        en: 'Search generation...',
                        ckb: 'بەدوای نەوەدا بگەڕێ...',
                        ku: 'Li nifşê bigere...'),
                    query: _generationQuery,
                    controller: _generationController,
                    onQueryChanged: (value) =>
                        setState(() => _generationQuery = value),
                    isLoading: _loadingGenerations,
                    error: _errorGenerations,
                    items: _generations,
                    labelBuilder: _generationLabel,
                    onRetry: () {
                      final modelId = _selectedModelId;
                      if (modelId != null) {
                        _loadGenerations(modelId);
                      }
                    },
                    onSelect: (row) async {
                      final id = row['id']?.toString();
                      if (id == null || id.isEmpty) return;
                      setState(() {
                        _selectedGenerationId = id;
                        _selectedGenerationName = _generationLabel(row);
                        _resetBelowGeneration();
                        _currentStep = 3;
                      });
                      await _loadTrims(id);
                    },
                    emptyMessage: context.tr(
                        ar: 'لا توجد أجيال متاحة لهذا الموديل',
                        en: 'No generations available for this model',
                        ckb: 'هیچ نەوەیەک بۆ ئەم مۆدێلە بەردەست نییە',
                        ku: 'Ji bo vî modelî tu nifş tune ye'),
                  ),
                ),
                Step(
                  title: Text(
                    context.tr(
                        ar: 'الفئة/التريم',
                        en: 'Trim',
                        ckb: 'فئە/تریم',
                        ku: 'Trim'),
                  ),
                  state: _stepState(_currentStep == 3),
                  content: _buildStepContent(
                    hint: context.tr(
                        ar: 'ابحث عن الفئة...',
                        en: 'Search trim...',
                        ckb: 'بەدوای تریمدا بگەڕێ...',
                        ku: 'Li trimê bigere...'),
                    query: _trimQuery,
                    controller: _trimController,
                    onQueryChanged: (value) =>
                        setState(() => _trimQuery = value),
                    isLoading: _loadingTrims,
                    error: _errorTrims,
                    items: _trims,
                    labelBuilder: _displayName,
                    onRetry: () {
                      final generationId = _selectedGenerationId;
                      if (generationId != null) {
                        _loadTrims(generationId);
                      }
                    },
                    onSelect: (row) async {
                      final id = row['id']?.toString();
                      if (id == null || id.isEmpty) return;
                      setState(() {
                        _selectedTrimId = id;
                        _selectedTrimName = _displayName(row);
                        _resetBelowTrim();
                        _currentStep = 4;
                      });
                      await _loadSections(id);
                    },
                    emptyMessage: context.tr(
                        ar: 'لا توجد فئات متاحة لهذا الجيل',
                        en: 'No trims available for this generation',
                        ckb: 'هیچ تریمێک بۆ ئەم نەوەیە بەردەست نییە',
                        ku: 'Ji bo vî nifşî tu trim tune ye'),
                  ),
                ),
                Step(
                  title: Text(
                    context.tr(
                        ar: 'القسم', en: 'Section', ckb: 'بەش', ku: 'Beş'),
                  ),
                  state: _stepState(_currentStep == 4),
                  content: _buildStepContent(
                    hint: context.tr(
                        ar: 'ابحث عن قسم...',
                        en: 'Search section...',
                        ckb: 'بەدوای بەشدا بگەڕێ...',
                        ku: 'Li beşê bigere...'),
                    query: _sectionQuery,
                    controller: _sectionController,
                    onQueryChanged: (value) =>
                        setState(() => _sectionQuery = value),
                    isLoading: _loadingSections,
                    error: _errorSections,
                    items: _sections,
                    labelBuilder: _displayName,
                    onRetry: () {
                      final trimId = _selectedTrimId;
                      if (trimId != null) {
                        _loadSections(trimId);
                      }
                    },
                    onSelect: (row) async {
                      final id = row['id']?.toString();
                      if (id == null || id.isEmpty) return;
                      setState(() {
                        _selectedSectionId = id;
                        _selectedSectionName = _displayName(row);
                        _resetBelowSection();
                        _currentStep = 5;
                      });
                      await _loadSubsections(id);
                    },
                    emptyMessage: context.tr(
                        ar: 'لا توجد أقسام متاحة لهذه الفئة',
                        en: 'No sections available for this trim',
                        ckb: 'هیچ بەشێک بۆ ئەم تریمە بەردەست نییە',
                        ku: 'Ji bo vî trimî tu beş tune ye'),
                  ),
                ),
                Step(
                  title: Text(
                    context.tr(
                        ar: 'القسم الفرعي',
                        en: 'Subsection',
                        ckb: 'بەشی لاوەکی',
                        ku: 'Binbeş'),
                  ),
                  state: _stepState(_currentStep == 5),
                  content: _buildStepContent(
                    hint: context.tr(
                        ar: 'ابحث عن قسم فرعي...',
                        en: 'Search subsection...',
                        ckb: 'بەدوای بەشی لاوەکیدا بگەڕێ...',
                        ku: 'Li binbeşê bigere...'),
                    query: _subsectionQuery,
                    controller: _subsectionController,
                    onQueryChanged: (value) =>
                        setState(() => _subsectionQuery = value),
                    isLoading: _loadingSubsections,
                    error: _errorSubsections,
                    items: _subsections,
                    labelBuilder: _displayName,
                    onRetry: () {
                      final sectionId = _selectedSectionId;
                      if (sectionId != null) {
                        _loadSubsections(sectionId);
                      }
                    },
                    onSelect: (row) {
                      final id = row['id']?.toString();
                      if (id == null || id.isEmpty) return;
                      setState(() {
                        _selectedSubsectionId = id;
                        _selectedSubsectionName = _displayName(row);
                      });
                    },
                    emptyMessage: context.tr(
                        ar: 'لا توجد أقسام فرعية متاحة لهذا القسم',
                        en: 'No subsections available for this section',
                        ckb: 'هیچ بەشێکی لاوەکی بۆ ئەم بەشە بەردەست نییە',
                        ku: 'Ji bo vî beşî tu binbeş tune ye'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StickyHeaderDelegate extends SliverPersistentHeaderDelegate {
  _StickyHeaderDelegate({
    required this.minHeight,
    required this.maxHeight,
    required this.child,
  });

  final double minHeight;
  final double maxHeight;
  final Widget child;

  @override
  double get minExtent => minHeight;

  @override
  double get maxExtent => maxHeight;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Material(
      elevation: overlapsContent ? 1 : 0,
      child: SizedBox.expand(child: child),
    );
  }

  @override
  bool shouldRebuild(covariant _StickyHeaderDelegate oldDelegate) {
    return minHeight != oldDelegate.minHeight ||
        maxHeight != oldDelegate.maxHeight ||
        child != oldDelegate.child;
  }
}
