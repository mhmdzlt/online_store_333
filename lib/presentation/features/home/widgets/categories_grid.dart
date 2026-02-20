import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import '../../../../data/models/category/category_model.dart';

class CategoriesGrid extends StatelessWidget {
  final List<CategoryModel> categories;
  final void Function(CategoryModel) onTap;

  const CategoriesGrid({
    super.key,
    required this.categories,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.spaceM),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 140,
        crossAxisSpacing: AppSizes.spaceS,
        mainAxisSpacing: AppSizes.spaceS,
        childAspectRatio: 0.9,
      ),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final category = categories[index];
        return InkWell(
          onTap: () => onTap(category),
          borderRadius: BorderRadius.circular(AppSizes.cardRadiusS),
          child: Container(
            padding: const EdgeInsets.all(AppSizes.spaceS),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppSizes.cardRadiusS),
              color: Theme.of(context).cardColor,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.category, size: AppSizes.iconSizeM),
                const SizedBox(height: AppSizes.spaceS),
                Text(
                  category.name,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
