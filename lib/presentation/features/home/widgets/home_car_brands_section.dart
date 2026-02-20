import 'package:flutter/material.dart';
import 'package:design_system/design_system.dart';
import '../../../../core/localization/language_text.dart';

import '../../../../data/models/car/car_brand.dart';
import 'car_brand_card.dart';

class HomeCarBrandsSection extends StatelessWidget {
  const HomeCarBrandsSection({
    super.key,
    required this.isLoading,
    required this.isRefreshing,
    required this.brands,
    required this.searchQuery,
    required this.onBrandTap,
  });

  final bool isLoading;
  final bool isRefreshing;
  final List<CarBrand> brands;
  final String searchQuery;
  final Future<void> Function(CarBrand brand) onBrandTap;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      if (isRefreshing) {
        return const SizedBox(height: 110);
      }
      return const SizedBox(
        height: 110,
        child: AppLoading(),
      );
    }

    if (brands.isEmpty) {
      if (searchQuery.trim().isNotEmpty) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
          child: Text(
            context.tr(
              ar: 'لا توجد ماركات مطابقة',
              en: 'No matching brands found',
              ckb: 'هیچ مارکێکی گونجاو نەدۆزرایەوە',
              ku: 'Tu markeyên guncaw nehatin dîtin',
            ),
          ),
        );
      }
      return const SizedBox.shrink();
    }

    final titleStyle = Theme.of(
      context,
    ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
          child: Text(
            context.tr(
              ar: 'ماركات السيارات',
              en: 'Car brands',
              ckb: 'مارکەکانی ئۆتۆمبێل',
              ku: 'Markeyên erebeyan',
            ),
            style: titleStyle,
          ),
        ),
        SizedBox(
          height: 110,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: brands.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final brand = brands[index];
              return GestureDetector(
                onTap: () async {
                  await onBrandTap(brand);
                },
                child: CarBrandCard(brand: brand),
              );
            },
          ),
        ),
      ],
    );
  }
}
