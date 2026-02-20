import 'package:flutter/material.dart';
import '../../../../core/localization/language_text.dart';

import '../../../../data/models/car/car_brand.dart';
import '../../../../data/models/car/car_lookup_item.dart';
import '../../../../data/models/category/category_model.dart';

class HomeFilterSelection {
  const HomeFilterSelection({
    required this.selectedCategoryId,
    required this.selectedBrandId,
    required this.selectedModelId,
    required this.selectedYearId,
    required this.selectedTrimId,
    required this.selectedSectionV2Id,
    required this.selectedSubsectionId,
    required this.selectedPriceRange,
    required this.models,
    required this.years,
    required this.trims,
    required this.sections,
    required this.subsections,
  });

  final String? selectedCategoryId;
  final String? selectedBrandId;
  final String? selectedModelId;
  final String? selectedYearId;
  final String? selectedTrimId;
  final String? selectedSectionV2Id;
  final String? selectedSubsectionId;
  final RangeValues? selectedPriceRange;
  final List<CarLookupItem> models;
  final List<CarLookupItem> years;
  final List<CarLookupItem> trims;
  final List<CarLookupItem> sections;
  final List<CarLookupItem> subsections;
}

class HomeFilterBottomSheet extends StatefulWidget {
  const HomeFilterBottomSheet({
    super.key,
    required this.categories,
    required this.isCategoriesLoading,
    required this.allCarBrands,
    required this.initialSelectedCategoryId,
    required this.initialSelectedBrandId,
    required this.initialSelectedModelId,
    required this.initialSelectedYearId,
    required this.initialSelectedTrimId,
    required this.initialSelectedSectionV2Id,
    required this.initialSelectedSubsectionId,
    required this.initialSelectedPriceRange,
    required this.initialModels,
    required this.initialYears,
    required this.initialTrims,
    required this.initialSections,
    required this.initialSubsections,
    required this.minPrice,
    required this.maxPrice,
    required this.fetchCarModels,
    required this.fetchCarYears,
    required this.fetchCarTrims,
    required this.fetchCarSectionsV2,
    required this.fetchCarSubsections,
    required this.onApply,
  });

  final List<CategoryModel> categories;
  final bool isCategoriesLoading;
  final List<CarBrand> allCarBrands;
  final String? initialSelectedCategoryId;
  final String? initialSelectedBrandId;
  final String? initialSelectedModelId;
  final String? initialSelectedYearId;
  final String? initialSelectedTrimId;
  final String? initialSelectedSectionV2Id;
  final String? initialSelectedSubsectionId;
  final RangeValues? initialSelectedPriceRange;
  final List<CarLookupItem> initialModels;
  final List<CarLookupItem> initialYears;
  final List<CarLookupItem> initialTrims;
  final List<CarLookupItem> initialSections;
  final List<CarLookupItem> initialSubsections;
  final double minPrice;
  final double maxPrice;
  final Future<List<CarLookupItem>> Function(String brandId) fetchCarModels;
  final Future<List<CarLookupItem>> Function(String modelId) fetchCarYears;
  final Future<List<CarLookupItem>> Function(String yearId) fetchCarTrims;
  final Future<List<CarLookupItem>> Function(String trimId) fetchCarSectionsV2;
  final Future<List<CarLookupItem>> Function(String sectionV2Id)
      fetchCarSubsections;
  final Future<void> Function(HomeFilterSelection selection) onApply;

  @override
  State<HomeFilterBottomSheet> createState() => _HomeFilterBottomSheetState();
}

class _HomeFilterBottomSheetState extends State<HomeFilterBottomSheet> {
  late String? _selectedCategoryId;
  late String? _selectedBrandId;
  late String? _selectedModelId;
  late String? _selectedYearId;
  late String? _selectedTrimId;
  late String? _selectedSectionV2Id;
  late String? _selectedSubsectionId;
  late RangeValues? _selectedPriceRange;

  late List<CarLookupItem> _models;
  late List<CarLookupItem> _years;
  late List<CarLookupItem> _trims;
  late List<CarLookupItem> _sections;
  late List<CarLookupItem> _subsections;

  @override
  void initState() {
    super.initState();
    _selectedCategoryId = widget.initialSelectedCategoryId;
    _selectedBrandId = widget.initialSelectedBrandId;
    _selectedModelId = widget.initialSelectedModelId;
    _selectedYearId = widget.initialSelectedYearId;
    _selectedTrimId = widget.initialSelectedTrimId;
    _selectedSectionV2Id = widget.initialSelectedSectionV2Id;
    _selectedSubsectionId = widget.initialSelectedSubsectionId;
    _selectedPriceRange = widget.initialSelectedPriceRange;

    _models = List<CarLookupItem>.from(widget.initialModels);
    _years = List<CarLookupItem>.from(widget.initialYears);
    _trims = List<CarLookupItem>.from(widget.initialTrims);
    _sections = List<CarLookupItem>.from(widget.initialSections);
    _subsections = List<CarLookupItem>.from(widget.initialSubsections);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 16.0,
        vertical: 12.0,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
            if (widget.isCategoriesLoading && widget.categories.isEmpty)
              const SizedBox(
                height: 60,
                child: Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            else
              Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                    label: Text(
                      context.tr(
                          ar: 'الكل', en: 'All', ckb: 'هەموو', ku: 'Hemû'),
                    ),
                    selected: _selectedCategoryId == null,
                    onSelected: (_) {
                      setState(() {
                        _selectedCategoryId = null;
                      });
                    },
                  ),
                  ...widget.categories.map((c) {
                    final id = c.id;
                    final name = c.name;
                    return ChoiceChip(
                      label: Text(name),
                      selected: _selectedCategoryId == id,
                      onSelected: (_) {
                        setState(() {
                          _selectedCategoryId = id;
                        });
                      },
                    );
                  }),
                ],
              ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _selectedBrandId,
              decoration: InputDecoration(
                labelText: context.tr(
                    ar: 'الماركة', en: 'Brand', ckb: 'مارکە', ku: 'Marke'),
              ),
              items: widget.allCarBrands
                  .map(
                    (brand) => DropdownMenuItem(
                      value: brand.id,
                      child: Text(brand.name),
                    ),
                  )
                  .toList(),
              onChanged: (value) async {
                setState(() {
                  _selectedBrandId = value;
                  _selectedModelId = null;
                  _selectedYearId = null;
                  _selectedTrimId = null;
                  _selectedSectionV2Id = null;
                  _selectedSubsectionId = null;
                  _models = [];
                  _years = [];
                  _trims = [];
                  _sections = [];
                  _subsections = [];
                });
                if (value != null) {
                  final nextModels = await widget.fetchCarModels(value);
                  if (!mounted) return;
                  setState(() {
                    _models = List<CarLookupItem>.from(nextModels);
                  });
                }
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _selectedModelId,
              decoration: InputDecoration(
                labelText: context.tr(
                    ar: 'الموديل', en: 'Model', ckb: 'مۆدێل', ku: 'Model'),
              ),
              items: _models
                  .map(
                    (model) => DropdownMenuItem(
                      value: model.id,
                      child: Text(model.name),
                    ),
                  )
                  .toList(),
              onChanged: _selectedBrandId == null
                  ? null
                  : (value) async {
                      setState(() {
                        _selectedModelId = value;
                        _selectedYearId = null;
                        _selectedTrimId = null;
                        _selectedSectionV2Id = null;
                        _selectedSubsectionId = null;
                        _years = [];
                        _trims = [];
                        _sections = [];
                        _subsections = [];
                      });
                      if (value != null) {
                        final nextYears = await widget.fetchCarYears(value);
                        if (!mounted) return;
                        setState(() {
                          _years = List<CarLookupItem>.from(nextYears);
                        });
                      }
                    },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _selectedYearId,
              decoration: InputDecoration(
                labelText:
                    context.tr(ar: 'السنة', en: 'Year', ckb: 'ساڵ', ku: 'Sal'),
              ),
              items: _years
                  .map(
                    (year) => DropdownMenuItem(
                      value: year.id,
                      child: Text(year.name),
                    ),
                  )
                  .toList(),
              onChanged: _selectedModelId == null
                  ? null
                  : (value) async {
                      setState(() {
                        _selectedYearId = value;
                        _selectedTrimId = null;
                        _selectedSectionV2Id = null;
                        _selectedSubsectionId = null;
                        _trims = [];
                        _sections = [];
                        _subsections = [];
                      });
                      if (value != null) {
                        final nextTrims = await widget.fetchCarTrims(value);
                        if (!mounted) return;
                        setState(() {
                          _trims = List<CarLookupItem>.from(nextTrims);
                        });
                      }
                    },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _selectedTrimId,
              decoration: InputDecoration(
                labelText: context.tr(
                    ar: 'الفئة', en: 'Trim', ckb: 'تریم', ku: 'Trim'),
              ),
              items: _trims
                  .map(
                    (trim) => DropdownMenuItem(
                      value: trim.id,
                      child: Text(trim.name),
                    ),
                  )
                  .toList(),
              onChanged: _selectedYearId == null
                  ? null
                  : (value) async {
                      setState(() {
                        _selectedTrimId = value;
                        _selectedSectionV2Id = null;
                        _selectedSubsectionId = null;
                        _sections = [];
                        _subsections = [];
                      });
                      if (value != null) {
                        final nextSections = await widget.fetchCarSectionsV2(
                          value,
                        );
                        if (!mounted) return;
                        setState(() {
                          _sections = List<CarLookupItem>.from(nextSections);
                        });
                      }
                    },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _selectedSectionV2Id,
              decoration: InputDecoration(
                labelText: context.tr(
                    ar: 'القسم', en: 'Section', ckb: 'بەش', ku: 'Beş'),
              ),
              items: _sections
                  .map(
                    (section) => DropdownMenuItem(
                      value: section.id,
                      child: Text(section.name),
                    ),
                  )
                  .toList(),
              onChanged: _selectedTrimId == null
                  ? null
                  : (value) async {
                      setState(() {
                        _selectedSectionV2Id = value;
                        _selectedSubsectionId = null;
                        _subsections = [];
                      });
                      if (value != null) {
                        final nextSubsections =
                            await widget.fetchCarSubsections(value);
                        if (!mounted) return;
                        setState(() {
                          _subsections =
                              List<CarLookupItem>.from(nextSubsections);
                        });
                      }
                    },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _selectedSubsectionId,
              decoration: InputDecoration(
                labelText: context.tr(
                  ar: 'القسم الفرعي',
                  en: 'Subsection',
                  ckb: 'بەشی لاوەکی',
                  ku: 'Binbeş',
                ),
              ),
              items: _subsections
                  .map(
                    (subsection) => DropdownMenuItem(
                      value: subsection.id,
                      child: Text(subsection.name),
                    ),
                  )
                  .toList(),
              onChanged: _selectedSectionV2Id == null
                  ? null
                  : (value) {
                      setState(() {
                        _selectedSubsectionId = value;
                      });
                    },
            ),
            const SizedBox(height: 16),
            if (widget.maxPrice > 0)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr(
                        ar: 'السعر', en: 'Price', ckb: 'نرخ', ku: 'Buhayê'),
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  RangeSlider(
                    values: _selectedPriceRange ??
                        RangeValues(widget.minPrice, widget.maxPrice),
                    min: widget.minPrice,
                    max: widget.maxPrice,
                    divisions: widget.maxPrice > widget.minPrice ? 10 : null,
                    labels: RangeLabels(
                      (_selectedPriceRange?.start ?? widget.minPrice)
                          .toStringAsFixed(0),
                      (_selectedPriceRange?.end ?? widget.maxPrice)
                          .toStringAsFixed(0),
                    ),
                    onChanged: (values) {
                      setState(() {
                        _selectedPriceRange = values;
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
                      setState(() {
                        _selectedCategoryId = null;
                        _selectedBrandId = null;
                        _selectedModelId = null;
                        _selectedYearId = null;
                        _selectedTrimId = null;
                        _selectedSectionV2Id = null;
                        _selectedSubsectionId = null;
                        _selectedPriceRange = widget.maxPrice > 0
                            ? RangeValues(widget.minPrice, widget.maxPrice)
                            : null;
                        _models = [];
                        _years = [];
                        _trims = [];
                        _sections = [];
                        _subsections = [];
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
                    onPressed: () async {
                      await widget.onApply(
                        HomeFilterSelection(
                          selectedCategoryId: _selectedCategoryId,
                          selectedBrandId: _selectedBrandId,
                          selectedModelId: _selectedModelId,
                          selectedYearId: _selectedYearId,
                          selectedTrimId: _selectedTrimId,
                          selectedSectionV2Id: _selectedSectionV2Id,
                          selectedSubsectionId: _selectedSubsectionId,
                          selectedPriceRange: _selectedPriceRange,
                          models: _models,
                          years: _years,
                          trims: _trims,
                          sections: _sections,
                          subsections: _subsections,
                        ),
                      );
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
      ),
    );
  }
}
