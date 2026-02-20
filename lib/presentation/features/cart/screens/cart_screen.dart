import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../data/models/cart/cart_item_model.dart';
import '../../../../data/models/product/product_model.dart';
import '../../../../data/repositories/product_repository.dart';
import '../../../../utils/image_resolvers.dart';
import '../../../providers/cart_provider.dart';
import '../../../providers/language_provider.dart';
import '../../../routing/navigation_helpers.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  late final Future<List<ProductModel>> _sponsoredFuture;

  String _t(
    String code, {
    required String ar,
    required String en,
    required String ckb,
    required String ku,
  }) {
    switch (code) {
      case 'en':
        return en;
      case 'ckb':
        return ckb;
      case 'ku':
        return ku;
      case 'ar':
      default:
        return ar;
    }
  }

  @override
  void initState() {
    super.initState();
    final repository = context.read<ProductRepository>();
    _sponsoredFuture = repository.fetchBestSellerProducts().then(
          (items) => items.take(12).toList(growable: false),
        );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final code = context.watch<LanguageProvider>().locale.languageCode;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Text(
          _t(
            code,
            ar: 'سلة التسوق',
            en: 'eBay shopping cart',
            ckb: 'سەبەتەی کڕین',
            ku: 'Sepeta kirînê',
          ),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    _t(
                      code,
                      ar: 'المزيد قريباً',
                      en: 'More options coming soon',
                      ckb: 'هەڵبژاردەی زیاتر بەزوویی دێت',
                      ku: 'Vebijarkên zêdetir nêzîk in',
                    ),
                  ),
                ),
              );
            },
            icon: const Icon(Icons.more_vert),
          ),
        ],
      ),
      body: Selector<CartProvider, List<CartItemModel>>(
        selector: (_, cart) => cart.items,
        builder: (context, items, _) {
          if (items.isEmpty) {
            return Center(
              child: Text(
                _t(
                  code,
                  ar: 'سلتك فارغة',
                  en: 'Your cart is empty',
                  ckb: 'سەبەتەکەت بەتاڵە',
                  ku: 'Sepeta te vala ye',
                ),
              ),
            );
          }

          final subtotal =
              items.fold<double>(0, (sum, item) => sum + item.lineTotal);

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
            children: [
              Text(
                _t(
                  code,
                  ar: 'سلتك',
                  en: 'Your cart',
                  ckb: 'سەبەتەکەت',
                  ku: 'Sepeta te',
                ),
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              const Divider(height: 1),
              const SizedBox(height: 10),
              ...items.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _CartItemTile(item: item, languageCode: code),
                ),
              ),
              const Divider(height: 1),
              const SizedBox(height: 12),
              _SummaryRow(
                label: _t(
                  code,
                  ar: 'العناصر (${items.length})',
                  en: 'Item (${items.length})',
                  ckb: 'کاڵا (${items.length})',
                  ku: 'Tişt (${items.length})',
                ),
                value: subtotal.toStringAsFixed(0),
              ),
              const SizedBox(height: 10),
              _SummaryRow(
                label: _t(
                  code,
                  ar: 'الشحن',
                  en: 'Shipping',
                  ckb: 'گەیاندن',
                  ku: 'Şandin',
                ),
                value: _t(
                  code,
                  ar: 'مجاني',
                  en: 'Free',
                  ckb: 'بەخۆڕایی',
                  ku: 'Belaş',
                ),
                valueColor: colorScheme.primary,
              ),
              const SizedBox(height: 10),
              const Divider(height: 1),
              const SizedBox(height: 10),
              _SummaryRow(
                label: _t(
                  code,
                  ar: 'المجموع الفرعي',
                  en: 'Subtotal',
                  ckb: 'کۆی لاوەکی',
                  ku: 'Tevahîya jêr',
                ),
                value: subtotal.toStringAsFixed(0),
                isBold: true,
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => NavigationHelpers.goToCheckout(context),
                  child: Text(
                    _t(
                      code,
                      ar: 'الانتقال لإتمام الطلب',
                      en: 'Go to checkout',
                      ckb: 'بڕۆ بۆ تەواوکردنی داوا',
                      ku: 'Biçe checkoutê',
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 22),
              Text(
                _t(
                  code,
                  ar: 'منتجات مشابهة ممولة',
                  en: 'Similar sponsored items',
                  ckb: 'کاڵاکانی هاوشێوەی پاڵپشتیکراو',
                  ku: 'Berhemên sponsor ên wekhev',
                ),
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              FutureBuilder<List<ProductModel>>(
                future: _sponsoredFuture,
                builder: (context, snapshot) {
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const SizedBox.shrink();
                  }
                  final sponsored = snapshot.data!;
                  return SizedBox(
                    height: 320,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: sponsored.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 10),
                      itemBuilder: (context, index) {
                        return SizedBox(
                          width: 188,
                          child: _SponsoredProductCard(
                            product: sponsored[index],
                            languageCode: code,
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}

class _CartItemTile extends StatelessWidget {
  const _CartItemTile({required this.item, required this.languageCode});

  final CartItemModel item;
  final String languageCode;

  @override
  Widget build(BuildContext context) {
    String t(
        {required String ar,
        required String en,
        required String ckb,
        required String ku}) {
      final code = languageCode;
      switch (code) {
        case 'en':
          return en;
        case 'ckb':
          return ckb;
        case 'ku':
          return ku;
        case 'ar':
        default:
          return ar;
      }
    }

    final cart = context.read<CartProvider>();
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final imageUrl = item.productImage?.trim() ?? '';
    final hasImage = isValidNetworkImageUrl(imageUrl);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: hasImage
                    ? AppImage(
                        imageUrl: imageUrl,
                        width: 108,
                        height: 108,
                        fit: BoxFit.cover,
                        radius: 14,
                      )
                    : Container(
                        width: 108,
                        height: 108,
                        color: colorScheme.surfaceContainerHighest,
                        alignment: Alignment.center,
                        child: Icon(
                          Icons.image_not_supported_outlined,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.productName,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${item.price.toStringAsFixed(0)} د.ع',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          t(
                            ar: 'الكمية',
                            en: 'Qty',
                            ckb: 'بڕ',
                            ku: 'Hejmar',
                          ),
                          style: theme.textTheme.bodyMedium,
                        ),
                        const SizedBox(width: 8),
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: theme.dividerColor),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                onPressed: () {
                                  cart.updateQuantity(item, item.quantity - 1);
                                },
                                icon: const Icon(Icons.remove),
                              ),
                              Text('${item.quantity}'),
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                onPressed: () {
                                  cart.updateQuantity(item, item.quantity + 1);
                                },
                                icon: const Icon(Icons.add),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        t(
                          ar: 'ميزة الحفظ لوقت لاحق قريباً',
                          en: 'Save for later is coming soon',
                          ckb: 'پاراستن بۆ دواتر بەزوویی دێت',
                          ku: 'Parastin ji bo paşê nêzîk e',
                        ),
                      ),
                    ),
                  );
                },
                child: Text(
                  t(
                    ar: 'احفظ للاحق',
                    en: 'Save for later',
                    ckb: 'بۆ دواتر هەڵبگرە',
                    ku: 'Ji bo paşê tomar bike',
                  ),
                ),
              ),
              TextButton(
                onPressed: () => cart.removeItem(item),
                child: Text(
                  t(
                    ar: 'إزالة',
                    en: 'Remove',
                    ckb: 'سڕینەوە',
                    ku: 'Rake',
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.isBold = false,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final bool isBold;

  @override
  Widget build(BuildContext context) {
    final baseStyle = isBold
        ? Theme.of(context)
            .textTheme
            .titleMedium
            ?.copyWith(fontWeight: FontWeight.w700)
        : Theme.of(context).textTheme.bodyLarge;

    return Row(
      children: [
        Text(label, style: baseStyle),
        const Spacer(),
        Text(value, style: baseStyle?.copyWith(color: valueColor)),
      ],
    );
  }
}

class _SponsoredProductCard extends StatelessWidget {
  const _SponsoredProductCard({
    required this.product,
    required this.languageCode,
  });

  final ProductModel product;
  final String languageCode;

  @override
  Widget build(BuildContext context) {
    String t(
        {required String ar,
        required String en,
        required String ckb,
        required String ku}) {
      final code = languageCode;
      switch (code) {
        case 'en':
          return en;
        case 'ckb':
          return ckb;
        case 'ku':
          return ku;
        case 'ar':
        default:
          return ar;
      }
    }

    final cart = context.read<CartProvider>();
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final image = product.imageUrls.isNotEmpty
        ? product.imageUrls.first
        : product.imageUrl;
    final hasImage = isValidNetworkImageUrl(image);
    final oldPrice = product.effectiveOldPrice;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              InkWell(
                onTap: () =>
                    NavigationHelpers.goToProductDetail(context, product.id),
                child: hasImage
                    ? AppImage(
                        imageUrl: image,
                        width: double.infinity,
                        height: 150,
                        fit: BoxFit.cover,
                        radius: 14,
                      )
                    : Container(
                        width: double.infinity,
                        height: 150,
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          Icons.image_not_supported_outlined,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
              ),
              Positioned(
                top: 6,
                right: 6,
                child: CircleAvatar(
                  radius: 16,
                  backgroundColor: colorScheme.surface,
                  child: const Icon(Icons.favorite_border, size: 18),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            product.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyLarge
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          if (oldPrice != null)
            Text(
              oldPrice.toStringAsFixed(0),
              style: theme.textTheme.bodySmall?.copyWith(
                decoration: TextDecoration.lineThrough,
              ),
            ),
          Text(
            product.price.toStringAsFixed(0),
            style: theme.textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          Text(
            t(
              ar: 'شحن مجاني',
              en: 'Free shipping',
              ckb: 'گەیاندنی بەخۆڕایی',
              ku: 'Şandina belaş',
            ),
            style: theme.textTheme.bodyMedium,
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () {
                final sellerId = product.sellerId;
                if (sellerId == null || sellerId.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        t(
                          ar: 'بيانات البائع غير متوفرة',
                          en: 'Seller data is unavailable',
                          ckb: 'زانیاری فرۆشیار بەردەست نییە',
                          ku: 'Daneyên firoşkar tune ne',
                        ),
                      ),
                    ),
                  );
                  return;
                }

                final added = cart.addToCart(
                  productId: product.id,
                  productName: product.name,
                  imageUrl: image,
                  sellerId: sellerId,
                  unitPrice: product.price,
                );

                if (!added) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        t(
                          ar: 'لا يمكن إضافة منتجات من بائع مختلف لنفس السلة',
                          en: 'Cannot add products from a different seller to the same cart',
                          ckb:
                              'ناتوانرێت کاڵا لە فرۆشیاری جیاواز بۆ هەمان سەبەت زیاد بکرێت',
                          ku: 'Nikare berhemên ji firoşkarekî cuda bo heman sepêtê were zêdekirin',
                        ),
                      ),
                    ),
                  );
                  return;
                }

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      t(
                        ar: 'تمت إضافة المنتج إلى السلة',
                        en: 'Product added to cart',
                        ckb: 'کاڵا زیادکرا بۆ سەبەتەکە',
                        ku: 'Berhem hate zêdekirin bo sepêtê',
                      ),
                    ),
                  ),
                );
              },
              child: Text(
                t(
                  ar: 'أضف إلى السلة',
                  en: 'Add to cart',
                  ckb: 'زیادکردن بۆ سەبەت',
                  ku: 'Tevlî sepêtê bike',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
