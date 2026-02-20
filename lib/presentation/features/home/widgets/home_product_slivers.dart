import 'package:flutter/material.dart';
import 'package:design_system/design_system.dart';
import '../../../../core/localization/language_text.dart';

import '../../../../data/models/product/product_model.dart';
import '../../../widgets/common/product_card.dart';

List<Widget> buildHomeProductSlivers({
  required BuildContext context,
  required bool isLoadingProducts,
  required bool isRefreshing,
  required List<ProductModel> products,
  required bool hasActiveFilters,
  required String searchQuery,
  required VoidCallback onEditFilters,
  required VoidCallback onResetFilters,
  required VoidCallback onClearSearch,
}) {
  if (isLoadingProducts) {
    return [
      SliverToBoxAdapter(
        child: isRefreshing
            ? const SizedBox(height: 200)
            : const SizedBox(
                height: 200,
                child: AppLoading(),
              ),
      ),
    ];
  }

  if (products.isEmpty) {
    if (hasActiveFilters) {
      return [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Column(
              children: [
                Text(
                  context.tr(
                    ar: 'لا توجد نتائج مطابقة للفلاتر.',
                    en: 'No results match the selected filters.',
                    ckb: 'هیچ ئەنجامێک لەگەڵ فلتەرە هەڵبژێردراوەکان ناگونجێت.',
                    ku: 'Tu encam bi fîlterên hilbijartî re li hev nayên.',
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    OutlinedButton(
                      onPressed: onEditFilters,
                      child: Text(
                        context.tr(
                            ar: 'تعديل الفلاتر',
                            en: 'Edit filters',
                            ckb: 'گۆڕینی فلتەرەکان',
                            ku: 'Fîlteran biguherîne'),
                      ),
                    ),
                    OutlinedButton(
                      onPressed: onResetFilters,
                      child: Text(
                        context.tr(
                            ar: 'مسح الفلاتر',
                            en: 'Clear filters',
                            ckb: 'سڕینەوەی فلتەرەکان',
                            ku: 'Fîlteran paqij bike'),
                      ),
                    ),
                    if (searchQuery.trim().isNotEmpty)
                      OutlinedButton(
                        onPressed: onClearSearch,
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
              ],
            ),
          ),
        ),
      ];
    }

    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 32),
          child: AppEmptyState(
            message: context.tr(
              ar: 'لا توجد منتجات متاحة حالياً',
              en: 'No products are available right now',
              ckb: 'ئێستا هیچ کاڵایەک بەردەست نییە',
              ku: 'Niha tu berhem tune ye',
            ),
          ),
        ),
      ),
    ];
  }

  return [
    SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0),
      sliver: SliverGrid(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final product = products[index];
            return ProductCard(
              product: product,
              onReturn: onClearSearch,
            );
          },
          childCount: products.length,
        ),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 210,
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
          mainAxisExtent: 300,
        ),
      ),
    ),
  ];
}
