import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';

import '../../../core/localization/language_text.dart';

class SectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onMoreTap;

  const SectionHeader({
    super.key,
    required this.title,
    this.onMoreTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.spaceM),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: AppTextStyles.labelLarge,
            ),
          ),
          if (onMoreTap != null)
            TextButton(
              onPressed: onMoreTap,
              child: Text(
                context.tr(
                  ar: 'المزيد',
                  en: 'More',
                  ckb: 'زیاتر',
                  ku: 'Zêdetir',
                ),
              ),
            ),
        ],
      ),
    );
  }
}
