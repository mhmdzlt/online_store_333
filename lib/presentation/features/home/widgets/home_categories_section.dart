import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/localization/language_text.dart';
import '../../../../data/models/category/category_model.dart';
import '../../../providers/home_provider.dart';
import '../../../routing/navigation_helpers.dart';
import 'categories_grid.dart';
import 'package:design_system/design_system.dart';

class HomeCategoriesSection extends StatelessWidget {
  const HomeCategoriesSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<HomeProvider>(
      builder: (context, provider, _) {
        final categories = provider.categories;
        if (provider.isLoadingHomeData && categories.isEmpty) {
          return const SizedBox(
            height: 200,
            child: AppLoading(
              size: 20,
              padding: EdgeInsets.zero,
            ),
          );
        }

        if (categories.isEmpty) {
          return Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0),
            child: AppEmptyState(
              message: context.tr(
                ar: 'لا توجد تصنيفات بعد',
                en: 'No categories yet',
                ckb: 'هێشتا هیچ پۆلێک نییە',
                ku: 'Hêj tu kategorî tune ne',
              ),
            ),
          );
        }

        return CategoriesGrid(
          categories: categories,
          onTap: (CategoryModel category) {
            NavigationHelpers.goToCategoryProducts(
              context,
              category.id,
              name: category.name,
            );
          },
        );
      },
    );
  }
}
