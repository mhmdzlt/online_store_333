import 'package:flutter/material.dart';

import '../../../data/models/product/product_model.dart';
import 'horizontal_mini_product_card.dart';

class HorizontalProductsSection extends StatelessWidget {
  final String title;
  final List<ProductModel> products;
  final VoidCallback? onReturn;

  const HorizontalProductsSection({
    super.key,
    required this.title,
    required this.products,
    this.onReturn,
  });

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        SizedBox(
          height: 190,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            itemCount: products.length,
            itemBuilder: (context, index) {
              final product = products[index];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: HorizontalMiniProductCard(
                  product: product,
                  onReturn: onReturn,
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}
