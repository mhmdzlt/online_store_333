import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';

import '../../../data/models/product/product_model.dart';
import '../../routing/navigation_helpers.dart';

class HorizontalMiniProductCard extends StatelessWidget {
  final ProductModel product;
  final VoidCallback? onReturn;

  const HorizontalMiniProductCard(
      {super.key, required this.product, this.onReturn});

  String _resolveImageUrl() {
    final images = product.imageUrls;
    if (images.isNotEmpty) return images.first;
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = _resolveImageUrl();
    final name = product.name;
    final price = product.price;

    return SizedBox(
      width: 150,
      child: Card(
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () async {
            NavigationHelpers.goToProductDetail(context, product.id);
            onReturn?.call();
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(14),
                    topRight: Radius.circular(14),
                  ),
                  child: imageUrl.isEmpty
                      ? Container(
                          color: Colors.grey.shade100,
                          child: const Center(
                            child: Icon(Icons.image_not_supported),
                          ),
                        )
                      : AppImage(
                          imageUrl: imageUrl,
                          width: double.infinity,
                          height: double.infinity,
                          fit: BoxFit.cover,
                          radius: 0,
                        ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${price.toStringAsFixed(0)} د.ع',
                      style: const TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
