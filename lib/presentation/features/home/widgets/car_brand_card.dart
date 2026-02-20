import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';

import '../../../../data/models/car/car_brand.dart';

class CarBrandCard extends StatelessWidget {
  final CarBrand brand;

  const CarBrandCard({super.key, required this.brand});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fallbackChar =
        brand.name.isNotEmpty ? brand.name.characters.first : '?';

    Widget buildFallback() {
      return Center(
        child: Text(
          fallbackChar,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      );
    }

    return SizedBox(
      width: 86,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFFF5F1FF),
            ),
            clipBehavior: Clip.antiAlias,
            child: (brand.imageUrl != null && brand.imageUrl!.isNotEmpty)
                ? AppImage(
                    imageUrl: brand.imageUrl!,
                    width: 64,
                    height: 64,
                    fit: BoxFit.cover,
                    shape: AppImageShape.circle,
                    placeholderIcon: Icons.directions_car,
                  )
                : buildFallback(),
          ),
          const SizedBox(height: 8),
          Text(
            brand.name,
            style: theme.textTheme.bodySmall,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
