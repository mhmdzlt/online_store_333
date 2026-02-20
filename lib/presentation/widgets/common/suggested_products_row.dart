import 'package:flutter/material.dart';

import '../../../data/models/product/product_model.dart';
import 'horizontal_mini_product_card.dart';

class SuggestedProductsRow extends StatelessWidget {
  final List<ProductModel> products;
  final VoidCallback? onReturn;

  const SuggestedProductsRow({
    super.key,
    required this.products,
    this.onReturn,
  });

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4.0, vertical: 8.0),
          child: Text(
            'منتجات مقترحة',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
