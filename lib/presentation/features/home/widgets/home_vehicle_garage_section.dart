import 'package:flutter/material.dart';
import '../../../../core/localization/language_text.dart';

import '../../../../data/models/car/car_brand.dart';
import '../../../../data/models/car/car_lookup_item.dart';
import 'vehicle_status_card.dart';

class HomeVehicleGarageSection extends StatelessWidget {
  const HomeVehicleGarageSection({
    super.key,
    required this.selectedBrandId,
    required this.selectedModelId,
    required this.selectedYearId,
    required this.selectedTrimId,
    required this.allCarBrands,
    required this.carModels,
    required this.carYears,
    required this.carTrims,
    required this.onChange,
  });

  final String? selectedBrandId;
  final String? selectedModelId;
  final String? selectedYearId;
  final String? selectedTrimId;
  final List<CarBrand> allCarBrands;
  final List<CarLookupItem> carModels;
  final List<CarLookupItem> carYears;
  final List<CarLookupItem> carTrims;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) {
    String? lookupName(List<CarLookupItem> items, String? id) {
      if (id == null) return null;
      for (final item in items) {
        if (item.id == id) return item.name;
      }
      return null;
    }

    String? brandName;
    if (selectedBrandId != null) {
      for (final brand in allCarBrands) {
        if (brand.id == selectedBrandId) {
          brandName = brand.name;
          break;
        }
      }
    }

    final modelName = lookupName(carModels, selectedModelId);
    final yearLabel = lookupName(carYears, selectedYearId);
    final trimLabel = lookupName(carTrims, selectedTrimId);

    final summary = <String>[];
    if (brandName != null) summary.add(brandName);
    if (modelName != null) summary.add(modelName);
    if (yearLabel != null) summary.add(yearLabel);
    if (trimLabel != null) summary.add(trimLabel);

    final hasSelectedVehicle = summary.isNotEmpty;
    final subtitle = hasSelectedVehicle
        ? summary.join(' • ')
        : context.tr(
            ar: 'اختر سيارتك للحصول على قطع متوافقة',
            en: 'Select your vehicle to get compatible parts',
            ckb: 'ئۆتۆمبێلەکەت هەڵبژێرە بۆ دەستکردنی پارچەی گونجاو',
            ku: 'Erebeya xwe hilbijêre da ku parçeyên guncaw bistîne',
          );

    return VehicleStatusCard(
      hasSelectedVehicle: hasSelectedVehicle,
      subtitle: subtitle,
      onChange: onChange,
    );
  }
}
