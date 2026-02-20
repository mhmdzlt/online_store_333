import 'package:flutter/material.dart';
import 'package:design_system/design_system.dart';
import 'package:provider/provider.dart';
import '../../../../core/localization/language_text.dart';

import '../../../providers/home_provider.dart';

class HomeFloatingCategoriesBar extends StatelessWidget {
  const HomeFloatingCategoriesBar({
    super.key,
    required this.show,
    required this.selectedCategoryId,
    required this.onSelectAll,
    required this.onSelectCategory,
  });

  final bool show;
  final String? selectedCategoryId;
  final VoidCallback onSelectAll;
  final void Function(String id, String name) onSelectCategory;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !show,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: show ? 1 : 0,
        child: AnimatedSlide(
          duration: const Duration(milliseconds: 200),
          offset: show ? Offset.zero : const Offset(0, -0.3),
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Consumer<HomeProvider>(
              builder: (context, provider, _) {
                final categories = provider.categories;
                if (provider.isLoadingHomeData && categories.isEmpty) {
                  return const SizedBox(
                    height: 44,
                    child: AppLoading(
                      size: 20,
                      padding: EdgeInsets.zero,
                    ),
                  );
                }

                if (categories.isEmpty) {
                  return SizedBox(
                    height: 44,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Text(
                        context.tr(
                          ar: 'لا توجد تصنيفات بعد',
                          en: 'No categories yet',
                          ckb: 'هێشتا هیچ پۆلێک نییە',
                          ku: 'Hêj kategorî tune ne',
                        ),
                      ),
                    ),
                  );
                }

                return SizedBox(
                  height: 44,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: categories.length + 1,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return ChoiceChip(
                          label: Text(
                            context.tr(
                                ar: 'الكل',
                                en: 'All',
                                ckb: 'هەموو',
                                ku: 'Hemû'),
                          ),
                          selected: selectedCategoryId == null,
                          onSelected: (_) => onSelectAll(),
                        );
                      }

                      final category = categories[index - 1];
                      final id = category.id;
                      final name = category.name;

                      return ChoiceChip(
                        label: Text(name),
                        selected: selectedCategoryId == id,
                        onSelected: (_) => onSelectCategory(id, name),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
