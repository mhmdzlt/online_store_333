import 'dart:io';

import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:online_store_333/presentation/providers/cart_provider.dart';
import 'package:online_store_333/presentation/routing/navigation_helpers.dart';
import 'package:online_store_333/utils/image_resolvers.dart';
import 'package:provider/provider.dart';

enum ImageSearchMapSort {
  bestMatch,
  popular,
  priceAsc,
  priceDesc,
}

class ImageSearchResultsMapSheet extends StatefulWidget {
  const ImageSearchResultsMapSheet({
    super.key,
    required this.queryImage,
    required this.products,
  });

  final XFile queryImage;
  final List<Map<String, dynamic>> products;

  static Future<void> show(
    BuildContext context, {
    required XFile queryImage,
    required List<Map<String, dynamic>> products,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return ImageSearchResultsMapSheet(
          queryImage: queryImage,
          products: products,
        );
      },
    );
  }

  @override
  State<ImageSearchResultsMapSheet> createState() =>
      _ImageSearchResultsMapSheetState();
}

class _ImageSearchResultsMapSheetState
    extends State<ImageSearchResultsMapSheet> {
  late final List<Map<String, dynamic>> _bestMatch;

  ImageSearchMapSort _sort = ImageSearchMapSort.bestMatch;

  @override
  void initState() {
    super.initState();
    _bestMatch = List<Map<String, dynamic>>.from(widget.products);
  }

  List<Map<String, dynamic>> get _sortedProducts {
    switch (_sort) {
      case ImageSearchMapSort.bestMatch:
        return _bestMatch;
      case ImageSearchMapSort.popular:
        final sorted = List<Map<String, dynamic>>.from(_bestMatch)
          ..sort((a, b) {
            final aSales = (a['sales_count'] as num?)?.toInt() ?? 0;
            final bSales = (b['sales_count'] as num?)?.toInt() ?? 0;
            return bSales.compareTo(aSales);
          });
        return sorted;
      case ImageSearchMapSort.priceAsc:
        final sorted = List<Map<String, dynamic>>.from(_bestMatch)
          ..sort((a, b) {
            final aPrice = (a['price'] as num?)?.toDouble() ?? 0;
            final bPrice = (b['price'] as num?)?.toDouble() ?? 0;
            return aPrice.compareTo(bPrice);
          });
        return sorted;
      case ImageSearchMapSort.priceDesc:
        final sorted = List<Map<String, dynamic>>.from(_bestMatch)
          ..sort((a, b) {
            final aPrice = (a['price'] as num?)?.toDouble() ?? 0;
            final bPrice = (b['price'] as num?)?.toDouble() ?? 0;
            return bPrice.compareTo(aPrice);
          });
        return sorted;
    }
  }

  void _setSort(ImageSearchMapSort next) {
    if (_sort == next) return;
    setState(() => _sort = next);
  }

  void _togglePriceSort() {
    setState(() {
      _sort = _sort == ImageSearchMapSort.priceAsc
          ? ImageSearchMapSort.priceDesc
          : ImageSearchMapSort.priceAsc;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final products = _sortedProducts;

    final mediaQuery = MediaQuery.of(context);
    final sheetHeight = mediaQuery.size.height * 0.85;
    final sheetTop = mediaQuery.size.height - sheetHeight;

    return SizedBox(
      height: mediaQuery.size.height,
      child: Stack(
        children: [
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              height: sheetHeight,
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  _SortRow(
                    sort: _sort,
                    onBestMatch: () => _setSort(ImageSearchMapSort.bestMatch),
                    onPopular: () => _setSort(ImageSearchMapSort.popular),
                    onPrice: _togglePriceSort,
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: GridView.builder(
                        itemCount: products.length,
                        gridDelegate:
                            const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 200,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          mainAxisExtent: 320,
                        ),
                        itemBuilder: (context, index) {
                          final product = products[index];
                          return _ImageSearchMapProductCard(
                            product: product,
                            onReturn: () => Navigator.of(context).pop(),
                          );
                        },
                      ),
                    ),
                  ),
                  SizedBox(height: mediaQuery.padding.bottom),
                ],
              ),
            ),
          ),
          Positioned(
            top: sheetTop - 64,
            left: 16,
            child: _QueryImagePreview(
              file: widget.queryImage,
              borderColor: colorScheme.primary,
            ),
          ),
          Positioned(
            top: sheetTop - 44,
            right: 16,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => Navigator.of(context).pop(),
                borderRadius: BorderRadius.circular(22),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: colorScheme.surface.withValues(alpha: 0.92),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.close,
                    color: colorScheme.onSurface,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SortRow extends StatelessWidget {
  const _SortRow({
    required this.sort,
    required this.onBestMatch,
    required this.onPopular,
    required this.onPrice,
  });

  final ImageSearchMapSort sort;
  final VoidCallback onBestMatch;
  final VoidCallback onPopular;
  final VoidCallback onPrice;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final isBest = sort == ImageSearchMapSort.bestMatch;
    final isPopular = sort == ImageSearchMapSort.popular;
    final isPrice = sort == ImageSearchMapSort.priceAsc ||
        sort == ImageSearchMapSort.priceDesc;

    final selectedColor = colorScheme.primary;
    final unselectedColor = colorScheme.onSurface;

    IconData priceIcon = Icons.unfold_more;
    if (sort == ImageSearchMapSort.priceAsc) {
      priceIcon = Icons.arrow_upward;
    } else if (sort == ImageSearchMapSort.priceDesc) {
      priceIcon = Icons.arrow_downward;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _SortButton(
            label: 'أفضل تطابق',
            icon: Icons.keyboard_arrow_down,
            selected: isBest,
            selectedColor: selectedColor,
            unselectedColor: unselectedColor,
            onTap: onBestMatch,
          ),
          const SizedBox(width: 18),
          _SortButton(
            label: 'الأكثر شيوعاً',
            icon: Icons.keyboard_arrow_down,
            selected: isPopular,
            selectedColor: selectedColor,
            unselectedColor: unselectedColor,
            onTap: onPopular,
          ),
          const SizedBox(width: 18),
          _SortButton(
            label: 'السعر',
            icon: priceIcon,
            selected: isPrice,
            selectedColor: selectedColor,
            unselectedColor: unselectedColor,
            onTap: onPrice,
          ),
        ],
      ),
    );
  }
}

class _SortButton extends StatelessWidget {
  const _SortButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.selectedColor,
    required this.unselectedColor,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final Color selectedColor;
  final Color unselectedColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? selectedColor : unselectedColor;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
            const SizedBox(width: 4),
            Icon(icon, size: 18, color: color),
          ],
        ),
      ),
    );
  }
}

class _QueryImagePreview extends StatelessWidget {
  const _QueryImagePreview({
    required this.file,
    required this.borderColor,
  });

  final XFile file;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    final imageFile = File(file.path);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: borderColor, width: 2),
            color: Theme.of(context).colorScheme.surface,
          ),
          clipBehavior: Clip.antiAlias,
          child: Image.file(imageFile, fit: BoxFit.cover),
        ),
        CustomPaint(
          size: const Size(18, 10),
          painter: _TrianglePainter(color: borderColor),
        ),
      ],
    );
  }
}

class _TrianglePainter extends CustomPainter {
  _TrianglePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(size.width / 2, size.height)
      ..lineTo(0, 0)
      ..lineTo(size.width, 0)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _TrianglePainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class _ImageSearchMapProductCard extends StatelessWidget {
  const _ImageSearchMapProductCard({
    required this.product,
    required this.onReturn,
  });

  final Map<String, dynamic> product;
  final VoidCallback onReturn;

  String _resolveCurrency() {
    final currency = product['currency']?.toString().trim() ?? '';
    return currency.isEmpty ? 'د.ع' : currency;
  }

  double _resolvePrice() {
    return (product['price'] as num?)?.toDouble() ?? 0;
  }

  double? _resolveOldPrice() {
    return (product['old_price'] as num?)?.toDouble();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final id = product['id']?.toString() ?? '';
    final name = product['name']?.toString() ?? 'منتج';
    final price = _resolvePrice();
    final oldPrice = _resolveOldPrice();
    final currency = _resolveCurrency();

    final imageUrl = resolveProductImage(product);

    return InkWell(
      onTap: () async {
        if (id.isEmpty) return;
        NavigationHelpers.goToProductDetail(context, id);
        onReturn();
      },
      child: Card(
        color: colorScheme.surface,
        elevation: 1,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 1.1,
              child: imageUrl.isEmpty
                  ? Container(
                      color: colorScheme.surfaceContainerHighest,
                      child: const Center(
                        child: Icon(Icons.image_not_supported),
                      ),
                    )
                  : AppImage(
                      imageUrl: imageUrl,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      radius: 0,
                    ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Text(
                              '${price.toStringAsFixed(0)} $currency',
                              style: TextStyle(
                                color: colorScheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (oldPrice != null && oldPrice > price) ...[
                              const SizedBox(width: 6),
                              Text(
                                '${oldPrice.toStringAsFixed(0)} $currency',
                                style: TextStyle(
                                  color: colorScheme.onSurfaceVariant,
                                  decoration: TextDecoration.lineThrough,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      IconButton(
                        iconSize: 22,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        icon: const Icon(Icons.add_shopping_cart_outlined),
                        color: colorScheme.primary,
                        onPressed: () {
                          final cart = context.read<CartProvider>();
                          final sellerId = product['seller_id']?.toString();
                          if (sellerId == null || sellerId.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'تعذر إضافة المنتج: بيانات البائع غير متوفرة',
                                ),
                              ),
                            );
                            return;
                          }
                          final added = cart.addToCart(
                            productId: id,
                            productName: name,
                            imageUrl: imageUrl,
                            sellerId: sellerId,
                            unitPrice: price,
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                added
                                    ? 'تمت إضافة المنتج إلى السلة'
                                    : 'السلة تحتوي على منتجات من بائع آخر. امسح السلة أو أكمل من نفس البائع.',
                              ),
                              duration: const Duration(seconds: 1),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
