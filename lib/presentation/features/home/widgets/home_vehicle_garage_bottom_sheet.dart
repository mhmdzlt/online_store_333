import 'package:flutter/material.dart';
import '../../../../core/localization/language_text.dart';

import '../../../../data/models/car/car_brand.dart';
import '../../../../data/models/car/car_lookup_item.dart';

class HomeVehicleGarageSelection {
  const HomeVehicleGarageSelection({
    required this.selectedBrandId,
    required this.selectedModelId,
    required this.selectedYearId,
    required this.selectedTrimId,
    required this.models,
    required this.years,
    required this.trims,
  });

  final String? selectedBrandId;
  final String? selectedModelId;
  final String? selectedYearId;
  final String? selectedTrimId;
  final List<CarLookupItem> models;
  final List<CarLookupItem> years;
  final List<CarLookupItem> trims;
}

class HomeVehicleGarageBottomSheet extends StatefulWidget {
  const HomeVehicleGarageBottomSheet({
    super.key,
    required this.allCarBrands,
    required this.initialSelectedBrandId,
    required this.initialSelectedModelId,
    required this.initialSelectedYearId,
    required this.initialSelectedTrimId,
    required this.initialModels,
    required this.initialYears,
    required this.initialTrims,
    required this.fetchCarModels,
    required this.fetchCarYears,
    required this.fetchCarTrims,
    required this.onApply,
  });

  final List<CarBrand> allCarBrands;
  final String? initialSelectedBrandId;
  final String? initialSelectedModelId;
  final String? initialSelectedYearId;
  final String? initialSelectedTrimId;
  final List<CarLookupItem> initialModels;
  final List<CarLookupItem> initialYears;
  final List<CarLookupItem> initialTrims;
  final Future<List<CarLookupItem>> Function(String brandId) fetchCarModels;
  final Future<List<CarLookupItem>> Function(String modelId) fetchCarYears;
  final Future<List<CarLookupItem>> Function(String yearId) fetchCarTrims;
  final Future<void> Function(HomeVehicleGarageSelection selection) onApply;

  @override
  State<HomeVehicleGarageBottomSheet> createState() =>
      _HomeVehicleGarageBottomSheetState();
}

class _HomeVehicleGarageBottomSheetState
    extends State<HomeVehicleGarageBottomSheet> {
  late String? _selectedBrandId;
  late String? _selectedModelId;
  late String? _selectedYearId;
  late String? _selectedTrimId;

  late List<CarLookupItem> _models;
  late List<CarLookupItem> _years;
  late List<CarLookupItem> _trims;

  @override
  void initState() {
    super.initState();
    _selectedBrandId = widget.initialSelectedBrandId;
    _selectedModelId = widget.initialSelectedModelId;
    _selectedYearId = widget.initialSelectedYearId;
    _selectedTrimId = widget.initialSelectedTrimId;
    _models = List<CarLookupItem>.from(widget.initialModels);
    _years = List<CarLookupItem>.from(widget.initialYears);
    _trims = List<CarLookupItem>.from(widget.initialTrims);
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
                ar: 'تسوق حسب السيارة',
                en: 'Shop by vehicle',
                ckb: 'بەپێی ئۆتۆمبێل بکڕە',
                ku: 'Li gorî erebeyê bikire',
              ),
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
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
                  _models = [];
                  _years = [];
                  _trims = [];
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
                        _years = [];
                        _trims = [];
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
                        _trims = [];
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
                  ar: 'الفئة (اختياري)',
                  en: 'Trim (optional)',
                  ckb: 'تریم (ئیختیاری)',
                  ku: 'Trim (vebijarkî)',
                ),
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
                  : (value) {
                      setState(() {
                        _selectedTrimId = value;
                      });
                    },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      setState(() {
                        _selectedBrandId = null;
                        _selectedModelId = null;
                        _selectedYearId = null;
                        _selectedTrimId = null;
                        _models = [];
                        _years = [];
                        _trims = [];
                      });
                    },
                    child: Text(
                      context.tr(
                          ar: 'مسح',
                          en: 'Clear',
                          ckb: 'سڕینەوە',
                          ku: 'Paqij bike'),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      if (_selectedBrandId == null ||
                          _selectedModelId == null ||
                          _selectedYearId == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              context.tr(
                                ar: 'اختر الماركة والموديل والسنة أولاً',
                                en: 'Select brand, model, and year first',
                                ckb: 'سەرەتا مارکە و مۆدێل و ساڵ هەڵبژێرە',
                                ku: 'Pêşî marke, model û sal hilbijêre',
                              ),
                            ),
                          ),
                        );
                        return;
                      }

                      await widget.onApply(
                        HomeVehicleGarageSelection(
                          selectedBrandId: _selectedBrandId,
                          selectedModelId: _selectedModelId,
                          selectedYearId: _selectedYearId,
                          selectedTrimId: _selectedTrimId,
                          models: _models,
                          years: _years,
                          trims: _trims,
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
