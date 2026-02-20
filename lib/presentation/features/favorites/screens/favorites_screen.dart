import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/localization/language_text.dart';
import '../../../../data/models/product/product_model.dart';
import '../../../../data/repositories/product_repository.dart';
import '../../../providers/favorites_provider.dart';
import '../../../widgets/common/product_card.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  late final ProductRepository _productRepository;
  Future<List<ProductModel>>? _favoritesFuture;
  String _lastSignature = '';

  @override
  void initState() {
    super.initState();
    _productRepository = context.read<ProductRepository>();
  }

  void _ensureFuture(List<String> favoriteIds) {
    final signature = favoriteIds.join('|');
    if (_favoritesFuture != null && signature == _lastSignature) return;
    _lastSignature = signature;
    _favoritesFuture = _loadFavoriteProducts(favoriteIds);
  }

  Future<List<ProductModel>> _loadFavoriteProducts(List<String> ids) async {
    if (ids.isEmpty) return const <ProductModel>[];

    final uniqueIds =
        ids.map((e) => e.trim()).where((e) => e.isNotEmpty).toSet();
    final futures = uniqueIds.map(_productRepository.fetchProductById).toList();
    final result = await Future.wait(futures);

    return result
        .whereType<ProductModel>()
        .where((product) => product.isActive)
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final favoriteIds =
        context.watch<FavoritesProvider>().favoriteIds.toList(growable: false);

    _ensureFuture(favoriteIds);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          context.tr(
            ar: 'المفضلة',
            en: 'Favorites',
            ckb: 'لیستی دڵخوازەکان',
            ku: 'Watchlist',
          ),
        ),
        centerTitle: true,
      ),
      body: favoriteIds.isEmpty
          ? Center(
              child: AppEmptyState(
                message: context.tr(
                  ar: 'لا توجد عناصر في المفضلة حالياً',
                  en: 'No favorite items yet',
                  ckb: 'هێشتا هیچ کاڵایەک لە لیستی دڵخوازەکان نییە',
                  ku: 'Hêj tu berhem di watchlistê de tune',
                ),
              ),
            )
          : FutureBuilder<List<ProductModel>>(
              future: _favoritesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const AppLoading();
                }

                if (snapshot.hasError) {
                  return Center(
                    child: AppEmptyState(
                      message: context.tr(
                        ar: 'حدث خطأ أثناء تحميل المفضلة',
                        en: 'Error loading favorites',
                        ckb: 'هەڵە لە بارکردنی لیستی دڵخوازەکان',
                        ku: 'Di barkirina watchlistê de çewtî çêbû',
                      ),
                    ),
                  );
                }

                final items = snapshot.data ?? const <ProductModel>[];
                if (items.isEmpty) {
                  return Center(
                    child: AppEmptyState(
                      message: context.tr(
                        ar: 'بعض العناصر لم تعد متاحة حالياً',
                        en: 'Some favorite items are no longer available',
                        ckb:
                            'هەندێک لە کاڵاکانی لیستی دڵخوازەکان ئێستا بەردەست نین',
                        ku: 'Hin berhemên watchlistê niha berdest nînin',
                      ),
                    ),
                  );
                }

                return GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.62,
                  ),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final product = items[index];
                    return Stack(
                      children: [
                        ProductCard(product: product),
                        Positioned(
                          top: 8,
                          left: 8,
                          child: Material(
                            color: Theme.of(context).colorScheme.surface,
                            shape: const CircleBorder(),
                            child: IconButton(
                              tooltip: context.tr(
                                ar: 'إزالة من المفضلة',
                                en: 'Remove from favorites',
                                ckb: 'سڕینەوە لە لیستی دڵخوازەکان',
                                ku: 'Ji watchlistê rake',
                              ),
                              visualDensity: VisualDensity.compact,
                              icon: Icon(
                                Icons.favorite,
                                color: Theme.of(context).colorScheme.error,
                              ),
                              onPressed: () {
                                context
                                    .read<FavoritesProvider>()
                                    .toggleFavorite(product.id);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      context.tr(
                                        ar: 'تمت الإزالة من المفضلة',
                                        en: 'Removed from favorites',
                                        ckb: 'لە لیستی دڵخوازەکان سڕایەوە',
                                        ku: 'Ji watchlistê hate rakirin',
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
    );
  }
}
