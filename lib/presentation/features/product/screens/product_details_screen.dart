import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide LocalStorage;
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

import '../../../../core/localization/language_text.dart';
import '../../../../core/services/tracking_service.dart';
import '../../../../data/models/product/product_model.dart';
import '../../../../data/repositories/product_repository.dart';
import '../../../../data/repositories/review_repository.dart';
import '../../../../utils/local_storage.dart';
import '../../../routing/navigation_helpers.dart';
import '../../../providers/cart_provider.dart';
import '../../../providers/favorites_provider.dart';
import '../../../widgets/common/product_card.dart';

class ProductDetailsScreen extends StatefulWidget {
  const ProductDetailsScreen({super.key, required this.productId});

  final String productId;

  @override
  State<ProductDetailsScreen> createState() => _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends State<ProductDetailsScreen> {
  late final ProductRepository _productRepository;
  late final ReviewRepository _reviewRepository;
  late Future<ProductModel?> _productFuture;

  int _currentMediaIndex = 0;
  int _quantity = 1;
  Future<List<ProductModel>>? _relatedFuture;
  Future<List<Map<String, dynamic>>>? _reviewsFuture;

  @override
  void initState() {
    super.initState();
    _productRepository = context.read<ProductRepository>();
    _reviewRepository = context.read<ReviewRepository>();
    final productId = widget.productId.trim();
    if (productId.isEmpty) {
      _productFuture = Future.value(null);
      _reviewsFuture = Future.value(const <Map<String, dynamic>>[]);
      return;
    }
    _productFuture = _productRepository.fetchProductById(productId);
    _reviewsFuture = _reviewRepository.fetchProductReviews(productId);
    TrackingService.instance.trackProductView(productId);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: FutureBuilder<ProductModel?>(
        future: _productFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const AppLoading();
          }

          if (snapshot.hasError) {
            return AppEmptyState(
              message: context.tr(
                ar: 'حدث خطأ في تحميل المنتج',
                en: 'Error loading product',
                ckb: 'هەڵەیەک ڕوویدا لە بارکردنی کاڵا',
                ku: 'Di barkirina berhemê de çewtiyek çêbû',
              ),
            );
          }

          final product = snapshot.data;
          if (product == null) {
            return AppEmptyState(
              message: context.tr(
                ar: 'لم يتم العثور على المنتج',
                en: 'Product not found',
                ckb: 'کاڵا نەدۆزرایەوە',
                ku: 'Berhem nehat dîtin',
              ),
            );
          }

          final meta = _parseExtraInfoMeta(product.extraInfo);
          final mediaItems = _buildMediaItems(product, meta);
          final soldLast24h = _readInt(meta, 'sold_last_24h') ??
              _readInt(meta, 'sold_count') ??
              (product.salesCount ?? 0);
          final watchCount = _readInt(meta, 'watch_count') ?? 0;
          final qaItems = _readQa(meta);
          final payments = _readStringList(meta, 'payment_methods');
          final trustBullets = _readStringList(meta, 'trust_bullets');
          final conditionLabel = _readString(meta, 'condition') ??
              context.tr(
                ar: 'مجدد معتمد',
                en: 'Certified refurbished',
                ckb: 'نوێکراوەی پشتڕاستکراو',
                ku: 'Nûkirîya pejirandî',
              );
          final conditionDescription =
              _readString(meta, 'condition_description') ??
                  context.tr(
                    ar: 'منتج تم فحصه ويعمل بشكل ممتاز.',
                    en: 'Inspected product in excellent working condition.',
                    ckb: 'کاڵای پشکنراوە و بە باشترین شێوە کار دەکات.',
                    ku: 'Berhema kontrolkirî ye û bi şertê pir baş dixebite.',
                  );
          final sellerName = _readString(meta, 'seller_name') ??
              context.tr(
                ar: 'البائع',
                en: 'Seller',
                ckb: 'فرۆشیار',
                ku: 'Firoşkar',
              );
          final sellerResponseHours =
              _readInt(meta, 'seller_response_hours') ?? 24;
          final sellerPositive = _resolveSellerPositive(
            product: product,
            meta: meta,
            watchCount: watchCount,
            soldLast24h: soldLast24h,
            sellerResponseHours: sellerResponseHours,
          );
          final sellerSince = _readString(meta, 'seller_since') ?? '';
          final shipsToIraq = _readBool(meta, 'ships_to_iraq') ?? true;
          final shippingFrom = _readString(meta, 'shipping_from') ??
              context.tr(
                ar: 'غير محدد',
                en: 'Not specified',
                ckb: 'دیاری نەکراو',
                ku: 'Nediarkirî',
              );
          final aboutSeller = _readString(meta, 'about_seller') ??
              context.tr(
                ar: 'نوفّر منتجات أصلية وخدمة ما بعد البيع بشكل مستمر.',
                en: 'We provide genuine products and reliable after-sales service.',
                ckb:
                    'بەردەوام کاڵای ڕەسەن و خزمەتگوزاری دوای فرۆشتن دابین دەکەین.',
                ku: 'Em berhemên orîjînal û xizmeta piştî firotinê pêşkêş dikin.',
              );
          final viewCount = _readInt(meta, 'view_count') ?? 0;
          final isWatchlisted =
              context.watch<FavoritesProvider>().isFavorite(product.id);

          _ensureRelatedProducts(product);

          return Stack(
            children: [
              CustomScrollView(
                slivers: [
                  SliverAppBar(
                    pinned: true,
                    backgroundColor: colorScheme.surface,
                    leading: IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back),
                    ),
                    title: Text(
                      context.tr(
                        ar: 'المنتج',
                        en: 'Item',
                        ckb: 'کاڵا',
                        ku: 'Berhem',
                      ),
                    ),
                    actions: [
                      IconButton(
                        onPressed: _copyDeepLink,
                        icon: const Icon(Icons.search),
                      ),
                      IconButton(
                        onPressed: () => NavigationHelpers.goToCart(context),
                        icon: const Icon(Icons.shopping_cart_outlined),
                      ),
                      IconButton(
                        onPressed: _copyDeepLink,
                        icon: const Icon(Icons.share_outlined),
                      ),
                      PopupMenuButton<String>(
                        onSelected: (value) {
                          if (value == 'copy') {
                            _copyDeepLink();
                          }
                        },
                        itemBuilder: (_) => [
                          PopupMenuItem<String>(
                            value: 'copy',
                            child: Text(
                              context.tr(
                                ar: 'نسخ الرابط',
                                en: 'Copy link',
                                ckb: 'کۆپیکردنی بەستەر',
                                ku: 'Girêdanê kopî bike',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  SliverToBoxAdapter(
                    child: _MediaGallery(
                      mediaItems: mediaItems,
                      currentIndex: _currentMediaIndex,
                      onPageChanged: (index) {
                        setState(() => _currentMediaIndex = index);
                      },
                      onTapVideo: _openVideoInApp,
                      soldLast24h: soldLast24h,
                      watchCount: watchCount,
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            product.name,
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 8),
                          _PriceSection(product: product),
                          const SizedBox(height: 10),
                          Text(
                            '$sellerName (${sellerPositive.toStringAsFixed(1)}% تقييم إيجابي)',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 8),
                          if (!shipsToIraq)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: colorScheme.errorContainer,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                context.tr(
                                  ar: 'هذا المنتج لا يدعم الشحن إلى العراق حالياً',
                                  en: 'This product currently does not ship to Iraq',
                                  ckb: 'ئەم کاڵایە ئێستا بۆ عێراق نانێردرێت',
                                  ku: 'Ev berhem niha nayê şandin bo Iraqê',
                                ),
                                style: TextStyle(
                                  color: colorScheme.onErrorContainer,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          const SizedBox(height: 10),
                          DropdownButtonFormField<int>(
                            initialValue: _quantity,
                            decoration: InputDecoration(
                              labelText: context.tr(
                                ar: 'الكمية',
                                en: 'Quantity',
                                ckb: 'بڕ',
                                ku: 'Hejmar',
                              ),
                            ),
                            items: List.generate(10, (i) => i + 1)
                                .map(
                                  (n) => DropdownMenuItem<int>(
                                    value: n,
                                    child: Text('$n'),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) {
                              if (value == null) return;
                              setState(() => _quantity = value);
                            },
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () => _addToCart(product),
                              child: Text(
                                context.tr(
                                  ar: 'خيارات الشراء',
                                  en: 'Buying options',
                                  ckb: 'هەڵبژاردەکانی کڕین',
                                  ku: 'Vebijarkên kirînê',
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                final added = await context
                                    .read<FavoritesProvider>()
                                    .toggleFavorite(product.id);
                                if (added) {
                                  TrackingService.instance
                                      .trackFavoriteAdd(product.id);
                                } else {
                                  TrackingService.instance
                                      .trackFavoriteRemove(product.id);
                                }
                              },
                              icon: Icon(
                                isWatchlisted
                                    ? Icons.favorite
                                    : Icons.favorite_border,
                              ),
                              label: Text(
                                isWatchlisted
                                    ? context.tr(
                                        ar: 'ضمن المفضلة',
                                        en: 'In watchlist',
                                        ckb: 'لە لیستی دڵخوازەکان',
                                        ku: 'Di watchlistê de',
                                      )
                                    : context.tr(
                                        ar: 'أضف للمفضلة',
                                        en: 'Add to Watchlist',
                                        ckb: 'زیادکردن بۆ لیستی چاودێری',
                                        ku: 'Tevlî watchlistê bike',
                                      ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    context.tr(
                                      ar: 'هذا المنتج رائج. تم بيع $soldLast24h مؤخراً.',
                                      en: 'This one\'s trending. $soldLast24h sold recently.',
                                      ckb:
                                          'ئەمە باوە. $soldLast24h دانە دوایین کاتدا فرۆشراوە.',
                                      ku: 'Ev berhem populer e. $soldLast24h di demên dawî de firotîye.',
                                    ),
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(fontWeight: FontWeight.w700),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    context.tr(
                                      ar: 'الطلب عليه مرتفع. $watchCount يراقبونه الآن.',
                                      en: 'People want this. $watchCount are watching.',
                                      ckb:
                                          'داواکاری زۆرە. $watchCount کەس چاودێری دەکەن.',
                                      ku: 'Xelk dixwazin. $watchCount kes li ser temaşe dikin.',
                                    ),
                                    style:
                                        Theme.of(context).textTheme.bodyLarge,
                                  ),
                                  if (viewCount > 0) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      '${context.tr(ar: 'عدد المشاهدات', en: 'Views', ckb: 'ژمارەی بینین', ku: 'Hejmara dîtinan')}: $viewCount',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          ExpansionTile(
                            title: Text(
                              context.tr(
                                ar: 'حول هذا المنتج',
                                en: 'About this item',
                                ckb: 'دەربارەی ئەم کاڵایە',
                                ku: 'Derbarê vê berhemê de',
                              ),
                            ),
                            initiallyExpanded: true,
                            childrenPadding:
                                const EdgeInsets.fromLTRB(16, 0, 16, 12),
                            children: [
                              _InfoLine(
                                  label: context.tr(
                                      ar: 'الحالة',
                                      en: 'Condition',
                                      ckb: 'دۆخ',
                                      ku: 'Rewş'),
                                  value: conditionLabel),
                              _InfoLine(
                                label: context.tr(
                                    ar: 'وصف الحالة',
                                    en: 'Condition Description',
                                    ckb: 'وەسفی دۆخ',
                                    ku: 'Danasîna rewşê'),
                                value: conditionDescription,
                              ),
                              _InfoLine(
                                label: context.tr(
                                    ar: 'رقم المنتج',
                                    en: 'Item number',
                                    ckb: 'ژمارەی کاڵا',
                                    ku: 'Hejmara berhemê'),
                                value: product.id,
                              ),
                              if (product.description.isNotEmpty)
                                _InfoLine(
                                  label: context.tr(
                                      ar: 'الوصف',
                                      en: 'Description',
                                      ckb: 'وەسف',
                                      ku: 'Danasîn'),
                                  value: product.description,
                                ),
                            ],
                          ),
                          ExpansionTile(
                            title: Text(
                              context.tr(
                                ar: 'الشحن والإرجاع والدفع',
                                en: 'Shipping, returns, and payments',
                                ckb: 'گەیاندن و گەڕاندنەوە و پارەدان',
                                ku: 'Şandin, vegerandin û dayîna pereyê',
                              ),
                            ),
                            childrenPadding:
                                const EdgeInsets.fromLTRB(16, 0, 16, 12),
                            children: [
                              _InfoLine(
                                  label: context.tr(
                                      ar: 'الشحن من',
                                      en: 'Shipping from',
                                      ckb: 'گەیاندن لە',
                                      ku: 'Şandin ji'),
                                  value: shippingFrom),
                              _InfoLine(
                                label: context.tr(
                                    ar: 'الشحن',
                                    en: 'Shipping',
                                    ckb: 'گەیاندن',
                                    ku: 'Şandin'),
                                value: shipsToIraq
                                    ? context.tr(
                                        ar: 'يشحن إلى العراق',
                                        en: 'Ships to Iraq',
                                        ckb: 'بۆ عێراق دەنێردرێت',
                                        ku: 'Bo Iraqê tê şandin')
                                    : context.tr(
                                        ar: 'لا يشحن إلى العراق',
                                        en: 'Does not ship to Iraq',
                                        ckb: 'بۆ عێراق نانێردرێت',
                                        ku: 'Bo Iraqê nayê şandin'),
                              ),
                              _InfoLine(
                                label: context.tr(
                                    ar: 'الإرجاع',
                                    en: 'Returns',
                                    ckb: 'گەڕاندنەوە',
                                    ku: 'Vegerandin'),
                                value: product.returnPolicy?.isNotEmpty == true
                                    ? product.returnPolicy!
                                    : context.tr(
                                        ar: 'سياسة الإرجاع غير محددة.',
                                        en: 'Return policy is not specified.',
                                        ckb:
                                            'سیاسەتی گەڕاندنەوە دیاری نەکراوە.',
                                        ku: 'Siyaseta vegerandinê ne diyarkirî ye.'),
                              ),
                              if (payments.isNotEmpty)
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: payments
                                      .map((p) => Chip(label: Text(p)))
                                      .toList(),
                                ),
                            ],
                          ),
                          ExpansionTile(
                            title: Text(
                              context.tr(
                                  ar: 'الأسئلة والأجوبة',
                                  en: 'Q&A',
                                  ckb: 'پرسیار و وەڵام',
                                  ku: 'Pirs û Bersiv'),
                            ),
                            childrenPadding:
                                const EdgeInsets.fromLTRB(16, 0, 16, 12),
                            children: qaItems.isEmpty
                                ? [
                                    Align(
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        context.tr(
                                            ar: 'لا توجد أسئلة حالياً.',
                                            en: 'No questions yet.',
                                            ckb: 'هێشتا هیچ پرسیارێک نییە.',
                                            ku: 'Hêj pirs tune ne.'),
                                      ),
                                    ),
                                  ]
                                : qaItems
                                    .map(
                                      (q) => ListTile(
                                        contentPadding: EdgeInsets.zero,
                                        title: Text(q.question),
                                        subtitle: Text(q.answer),
                                      ),
                                    )
                                    .toList(),
                          ),
                          ExpansionTile(
                            title: Text(
                              context.tr(
                                  ar: 'حول البائع',
                                  en: 'About this seller',
                                  ckb: 'دەربارەی فرۆشیار',
                                  ku: 'Derbarê firoşkar de'),
                            ),
                            childrenPadding:
                                const EdgeInsets.fromLTRB(16, 0, 16, 12),
                            children: [
                              _InfoLine(
                                  label: context.tr(
                                      ar: 'البائع',
                                      en: 'Seller',
                                      ckb: 'فرۆشیار',
                                      ku: 'Firoşkar'),
                                  value: sellerName),
                              _InfoLine(
                                label: context.tr(
                                    ar: 'التقييم الإيجابي',
                                    en: 'Positive feedback',
                                    ckb: 'فیدباکی ئەرێنی',
                                    ku: 'Feedbaxa erênî'),
                                value: '${sellerPositive.toStringAsFixed(1)}%',
                              ),
                              if (sellerSince.isNotEmpty)
                                _InfoLine(
                                    label: context.tr(
                                        ar: 'تاريخ الانضمام',
                                        en: 'Joined',
                                        ckb: 'بەرواری بەشداربوون',
                                        ku: 'Tevlîbûyî'),
                                    value: sellerSince),
                              _InfoLine(
                                label: context.tr(
                                    ar: 'زمن الاستجابة',
                                    en: 'Response time',
                                    ckb: 'کاتی وەڵامدانەوە',
                                    ku: 'Demê bersivdanê'),
                                value: context.tr(
                                  ar: 'عادة خلال $sellerResponseHours ساعة',
                                  en: 'Usually within $sellerResponseHours hours',
                                  ckb:
                                      'زۆربەی کات لە ماوەی $sellerResponseHours کاتژمێر',
                                  ku: 'Bi gelemperî di nav $sellerResponseHours saetan de',
                                ),
                              ),
                              Text(aboutSeller),
                            ],
                          ),
                          if (trustBullets.isNotEmpty)
                            ExpansionTile(
                              title: Text(
                                context.tr(
                                    ar: 'تسوّق بثقة',
                                    en: 'Shop with confidence',
                                    ckb: 'بە دڵنیایی بکڕە',
                                    ku: 'Bi bawerî bikire'),
                              ),
                              childrenPadding:
                                  const EdgeInsets.fromLTRB(16, 0, 16, 12),
                              children: trustBullets
                                  .map((b) => _InfoLine(label: '•', value: b))
                                  .toList(),
                            ),
                          const SizedBox(height: 8),
                          _buildReviewsSection(),
                          const SizedBox(height: 8),
                          FutureBuilder<List<ProductModel>>(
                            future: _relatedFuture,
                            builder: (context, relatedSnapshot) {
                              final related = relatedSnapshot.data ?? const [];
                              if (related.isEmpty) {
                                return const SizedBox.shrink();
                              }
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        context.tr(
                                          ar: 'منتجات مشابهة ممولة',
                                          en: 'Similar sponsored items',
                                          ckb: 'کاڵای هاوشێوەی سپۆنسەرکراو',
                                          ku: 'Berhemên weke hev ên sponsorî',
                                        ),
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleLarge
                                            ?.copyWith(
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                      TextButton(
                                        onPressed: () {
                                          NavigationHelpers
                                              .goToCategoryProducts(
                                            context,
                                            product.categoryId,
                                            name: context.tr(
                                              ar: 'منتجات مشابهة',
                                              en: 'Similar products',
                                              ckb: 'کاڵای هاوشێوە',
                                              ku: 'Berhemên weke hev',
                                            ),
                                          );
                                        },
                                        child: Text(
                                          context.tr(
                                            ar: 'عرض الكل',
                                            en: 'See all',
                                            ckb: 'هەمووی ببینە',
                                            ku: 'Hemûyan bibîne',
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  SizedBox(
                                    height: 265,
                                    child: ListView.separated(
                                      scrollDirection: Axis.horizontal,
                                      itemCount: related.length,
                                      separatorBuilder: (_, __) =>
                                          const SizedBox(width: 10),
                                      itemBuilder: (context, index) {
                                        return SizedBox(
                                          width: 180,
                                          child: ProductCard(
                                            product: related[index],
                                            onReturn: () {
                                              setState(() {
                                                _productFuture =
                                                    _productRepository
                                                        .fetchProductById(
                                                  widget.productId,
                                                );
                                              });
                                            },
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              Positioned(
                left: 12,
                right: 12,
                bottom: 12,
                child: SafeArea(
                  top: false,
                  child: ElevatedButton(
                    onPressed: () => _addToCart(product),
                    child: Text(
                      context.tr(
                          ar: 'أضف إلى السلة',
                          en: 'Add to cart',
                          ckb: 'زیادکردن بۆ سەبەت',
                          ku: 'Li sepêtê zêde bike'),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildReviewsSection() {
    final reviewsFuture = _reviewsFuture ??=
        _reviewRepository.fetchProductReviews(widget.productId);

    return ExpansionTile(
      title: Text(
        context.tr(
          ar: 'التقييمات والتعليقات',
          en: 'Ratings & comments',
          ckb: 'هەڵسەنگاندن و لێدوان',
          ku: 'Nirxandin û şîrove',
          watch: false,
        ),
      ),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      children: [
        FutureBuilder<List<Map<String, dynamic>>>(
          future: reviewsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: AppLoading(size: 20, padding: EdgeInsets.zero),
              );
            }

            final rows = snapshot.data ?? const <Map<String, dynamic>>[];
            final average = rows.isEmpty
                ? 0.0
                : rows
                        .map((e) => (e['rating'] as num?)?.toDouble() ?? 0)
                        .reduce((a, b) => a + b) /
                    rows.length;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      rows.isEmpty
                          ? context.tr(
                              ar: 'لا توجد تقييمات بعد',
                              en: 'No ratings yet',
                              ckb: 'هێشتا هەڵسەنگاندن نییە',
                              ku: 'Hêj nirxandin tune ne',
                              watch: false,
                            )
                          : context.tr(
                              ar: 'متوسط التقييم ${average.toStringAsFixed(1)} من 5',
                              en: 'Average ${average.toStringAsFixed(1)} of 5',
                              ckb:
                                  'ناوەندی هەڵسەنگاندن ${average.toStringAsFixed(1)} لە 5',
                              ku: 'Navîn ${average.toStringAsFixed(1)} ji 5',
                              watch: false,
                            ),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: _showAddReviewDialog,
                      icon: const Icon(Icons.rate_review_outlined, size: 18),
                      label: Text(
                        context.tr(
                          ar: 'أضف تقييم',
                          en: 'Add review',
                          ckb: 'هەڵسەنگاندن زیاد بکە',
                          ku: 'Nirxandin zêde bike',
                          watch: false,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (rows.isEmpty)
                  Text(
                    context.tr(
                      ar: 'كن أول من يكتب تعليقًا حول هذا المنتج.',
                      en: 'Be the first to add a comment for this product.',
                      ckb: 'یەکەم کەس بە کە لێدوان لەسەر ئەم کاڵایە بنووسێت.',
                      ku: 'Tu yê yekem be ku ji bo vê berhemê şîroveyek binivîse.',
                      watch: false,
                    ),
                  )
                else
                  ...rows.take(10).map((row) {
                    final reviewerName =
                        (row['reviewer_name']?.toString() ?? '').trim();
                    final rating = (row['rating'] as num?)?.toInt() ?? 0;
                    final comment = (row['comment']?.toString() ?? '').trim();
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(reviewerName.isEmpty ? '—' : reviewerName),
                      subtitle: comment.isEmpty ? null : Text(comment),
                      trailing: Text('⭐ $rating/5'),
                    );
                  }),
              ],
            );
          },
        ),
      ],
    );
  }

  Future<void> _showAddReviewDialog() async {
    final profile = await LocalStorage.getCheckoutProfile();
    final savedPhone = await LocalStorage.getUserPhone();
    if (!mounted) return;

    final user = Supabase.instance.client.auth.currentUser;
    final userMeta = user?.userMetadata ?? const <String, dynamic>{};
    final accountName = (userMeta['full_name']?.toString() ??
            userMeta['name']?.toString() ??
            '')
        .trim();

    final nameController = TextEditingController(
      text: (profile?['full_name']?.toString() ?? accountName).trim(),
    );
    final commentController = TextEditingController();
    var selectedRating = 5;

    final payload = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(
                context.tr(
                  ar: 'إضافة تقييم وتعليق',
                  en: 'Add rating & comment',
                  ckb: 'زیادکردنی هەڵسەنگاندن و لێدوان',
                  ku: 'Nirxandin û şîrove zêde bike',
                  watch: false,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: InputDecoration(
                        labelText: context.tr(
                          ar: 'الاسم',
                          en: 'Name',
                          ckb: 'ناو',
                          ku: 'Nav',
                          watch: false,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<int>(
                      initialValue: selectedRating,
                      decoration: InputDecoration(
                        labelText: context.tr(
                          ar: 'التقييم',
                          en: 'Rating',
                          ckb: 'هەڵسەنگاندن',
                          ku: 'Nirxandin',
                          watch: false,
                        ),
                      ),
                      items: List.generate(
                        5,
                        (index) => DropdownMenuItem<int>(
                          value: 5 - index,
                          child: Text('⭐ ${5 - index}'),
                        ),
                      ),
                      onChanged: (value) {
                        if (value == null) return;
                        setDialogState(() => selectedRating = value);
                      },
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: commentController,
                      minLines: 2,
                      maxLines: 4,
                      decoration: InputDecoration(
                        labelText: context.tr(
                          ar: 'التعليق (اختياري)',
                          en: 'Comment (optional)',
                          ckb: 'لێدوان (ئیختیاری)',
                          ku: 'Şîrove (bijarte)',
                          watch: false,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: Text(
                    context.tr(
                      ar: 'إلغاء',
                      en: 'Cancel',
                      ckb: 'هەڵوەشاندنەوە',
                      ku: 'Betal',
                      watch: false,
                    ),
                  ),
                ),
                FilledButton(
                  onPressed: () {
                    final reviewerName = nameController.text.trim();
                    if (reviewerName.isEmpty) return;
                    Navigator.of(dialogContext).pop({
                      'reviewer_name': reviewerName,
                      'rating': selectedRating,
                      'comment': commentController.text.trim(),
                    });
                  },
                  child: Text(
                    context.tr(
                      ar: 'إرسال',
                      en: 'Submit',
                      ckb: 'ناردن',
                      ku: 'Şandin',
                      watch: false,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    if (!mounted) return;
    if (payload == null) return;

    try {
      await _reviewRepository.addProductReview(
        productId: widget.productId,
        reviewerName: payload['reviewer_name'].toString(),
        rating: payload['rating'] as int,
        comment: (payload['comment']?.toString() ?? '').trim().isEmpty
            ? null
            : payload['comment'].toString().trim(),
        reviewerPhone: (savedPhone == null || savedPhone.trim().isEmpty)
            ? null
            : savedPhone.trim(),
      );

      if (!mounted) return;

      setState(() {
        _reviewsFuture =
            _reviewRepository.fetchProductReviews(widget.productId);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr(
              ar: 'تم إرسال التقييم بنجاح',
              en: 'Review submitted successfully',
              ckb: 'هەڵسەنگاندن بە سەرکەوتوویی نێردرا',
              ku: 'Nirxandin bi serkeftî hate şandin',
            ),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr(
              ar: 'تعذر إرسال التقييم حالياً',
              en: 'Unable to submit review now',
              ckb: 'نەنێردرایەوە هەڵسەنگاندن لە ئێستادا',
              ku: 'Nirxandin niha nayê şandin',
            ),
          ),
        ),
      );
    }
  }

  void _ensureRelatedProducts(ProductModel product) {
    _relatedFuture ??= _productRepository
        .fetchProductsByCategory(
          product.categoryId,
        )
        .then(
          (items) => items
              .where((e) => e.id != product.id)
              .take(10)
              .toList(growable: false),
        );
  }

  Future<void> _copyDeepLink() async {
    final value = 'product:${widget.productId}';
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          context.tr(
            watch: false,
            ar: 'تم نسخ معرف المنتج',
            en: 'Product identifier copied',
            ckb: 'ناسنامەی کاڵا کۆپی کرا',
            ku: 'Nasnameya berhemê hate kopîkirin',
          ),
        ),
      ),
    );
  }

  Future<void> _openExternal(String value) async {
    final uri = Uri.tryParse(value);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _openVideoInApp(String value) async {
    final uri = Uri.tryParse(value);
    if (uri == null) return;

    final host = uri.host.toLowerCase();
    final isYoutube = host.contains('youtube.com') ||
        host.contains('youtu.be') ||
        value.toLowerCase().contains('youtube');

    if (isYoutube) {
      await _openExternal(value);
      return;
    }

    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (_) => _VideoPlayerDialog(url: value),
    );
  }

  void _addToCart(ProductModel product) {
    final sellerId = product.sellerId;
    if (sellerId == null || sellerId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr(
              watch: false,
              ar: 'تعذر إضافة المنتج: بيانات البائع غير متوفرة',
              en: 'Unable to add product: seller data is unavailable',
              ckb: 'ناتوانرێت کاڵا زیاد بکرێت: زانیاری فرۆشیار بەردەست نییە',
              ku: 'Nikare berhem zêde bike: daneya firoşkar tune ye',
            ),
          ),
        ),
      );
      return;
    }

    final imageUrls = _extractProductImages(product);
    final added = context.read<CartProvider>().addToCart(
          productId: product.id,
          productName: product.name,
          imageUrl: imageUrls.isNotEmpty ? imageUrls.first : '',
          sellerId: sellerId,
          unitPrice: product.price,
          quantity: _quantity,
        );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          added
              ? context.tr(
                  watch: false,
                  ar: 'تمت إضافة المنتج إلى السلة',
                  en: 'Product added to cart',
                  ckb: 'کاڵا زیادکرا بۆ سەبەت',
                  ku: 'Berhem li sepêtê zêde bû',
                )
              : context.tr(
                  watch: false,
                  ar: 'السلة تحتوي على منتجات من بائع آخر. امسح السلة أو أكمل من نفس البائع.',
                  en: 'Cart has items from another seller. Clear cart or continue with same seller.',
                  ckb:
                      'سەبەتەکە کاڵای فرۆشیارێکی تر تێدایە. سەبەت بسڕەوە یان لە هەمان فرۆشیار بەردەوام بە.',
                  ku: 'Sepetê de berhemên firoşkarekî din hene. Sepetê paqij bike an bi heman firoşkar dewam bike.',
                ),
        ),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  List<String> _extractProductImages(ProductModel product) {
    return product.imageUrls;
  }

  Map<String, dynamic>? _parseExtraInfoMeta(String? extraInfo) {
    if (extraInfo == null || extraInfo.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(extraInfo);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {}
    return null;
  }

  List<_MediaItem> _buildMediaItems(
    ProductModel product,
    Map<String, dynamic>? meta,
  ) {
    final imageItems = product.imageUrls
        .map((url) => _MediaItem(type: _MediaType.image, url: url, thumb: url))
        .toList();

    if (meta == null) return imageItems;

    final videos = _readStringList(meta, 'video_urls');
    for (final video in videos) {
      imageItems.insert(
        imageItems.length > 1 ? 1 : imageItems.length,
        _MediaItem(
            type: _MediaType.video,
            url: video,
            thumb: imageItems.isNotEmpty ? imageItems.first.thumb : ''),
      );
    }

    return imageItems;
  }

  String? _readString(Map<String, dynamic>? map, String key) {
    final value = map?[key]?.toString().trim();
    if (value == null || value.isEmpty) return null;
    return value;
  }

  int? _readInt(Map<String, dynamic>? map, String key) {
    final value = map?[key];
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  double? _readDouble(Map<String, dynamic>? map, String key) {
    final value = map?[key];
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  double _resolveSellerPositive({
    required ProductModel product,
    required Map<String, dynamic>? meta,
    required int watchCount,
    required int soldLast24h,
    required int sellerResponseHours,
  }) {
    final explicit = _readDouble(meta, 'seller_positive');
    if (explicit != null) {
      return explicit.clamp(0, 100).toDouble();
    }

    final totalSales = (product.salesCount ?? 0) + math.max(0, soldLast24h);
    final salesBoost = math.min(7.0, math.log(totalSales + 1) * 1.6);
    final watchBoost =
        math.min(2.0, math.log(math.max(0, watchCount) + 1) * 0.45);
    final responseBoost =
        math.max(0, 2.0 - ((sellerResponseHours.clamp(1, 72) - 1) / 24));

    final computed = 88.0 + salesBoost + watchBoost + responseBoost;
    return computed.clamp(85.0, 99.8).toDouble();
  }

  bool? _readBool(Map<String, dynamic>? map, String key) {
    final value = map?[key];
    if (value is bool) return value;
    final normalized = value?.toString().toLowerCase().trim();
    if (normalized == 'true' || normalized == '1') return true;
    if (normalized == 'false' || normalized == '0') return false;
    return null;
  }

  List<String> _readStringList(Map<String, dynamic>? map, String key) {
    final value = map?[key];
    if (value is List) {
      return value
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    if (value is String) {
      return value
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    return const [];
  }

  List<_QaItem> _readQa(Map<String, dynamic>? map) {
    final value = map?['qa'];
    if (value is List) {
      return value
          .whereType<Map>()
          .map((entry) {
            final m = Map<String, dynamic>.from(entry);
            return _QaItem(
              question: m['q']?.toString() ?? m['question']?.toString() ?? '',
              answer: m['a']?.toString() ?? m['answer']?.toString() ?? '',
            );
          })
          .where((item) => item.question.isNotEmpty && item.answer.isNotEmpty)
          .toList();
    }

    final raw = map?['qa_text']?.toString() ?? '';
    if (raw.trim().isEmpty) return const [];
    return raw
        .split('\n')
        .map((line) {
          final parts = line.split('|');
          if (parts.length < 2) return null;
          final q = parts[0].trim();
          final a = parts.sublist(1).join('|').trim();
          if (q.isEmpty || a.isEmpty) return null;
          return _QaItem(question: q, answer: a);
        })
        .whereType<_QaItem>()
        .toList();
  }
}

class _MediaGallery extends StatelessWidget {
  const _MediaGallery({
    required this.mediaItems,
    required this.currentIndex,
    required this.onPageChanged,
    required this.onTapVideo,
    required this.soldLast24h,
    required this.watchCount,
  });

  final List<_MediaItem> mediaItems;
  final int currentIndex;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<String> onTapVideo;
  final int soldLast24h;
  final int watchCount;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final safeItems = mediaItems.isEmpty
        ? const [
            _MediaItem(type: _MediaType.image, url: '', thumb: ''),
          ]
        : mediaItems;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (soldLast24h > 0)
          Container(
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$soldLast24h SOLD IN LAST 24 HOURS',
              style: TextStyle(
                color: colorScheme.onErrorContainer,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        SizedBox(
          height: 360,
          child: Stack(
            children: [
              PageView.builder(
                itemCount: safeItems.length,
                onPageChanged: onPageChanged,
                itemBuilder: (context, index) {
                  final item = safeItems[index];
                  if (item.type == _MediaType.video) {
                    return InkWell(
                      onTap: () => onTapVideo(item.url),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Positioned.fill(
                            child: item.thumb.isEmpty
                                ? Container(
                                    color: colorScheme.surfaceContainerHighest,
                                    alignment: Alignment.center,
                                    child: Icon(
                                      Icons.play_circle_fill,
                                      size: 48,
                                      color: colorScheme.primary,
                                    ),
                                  )
                                : AppImage(
                                    imageUrl: item.thumb,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                  ),
                          ),
                          CircleAvatar(
                            radius: 32,
                            backgroundColor: Colors.black45,
                            child: Icon(
                              Icons.play_arrow,
                              color: colorScheme.onPrimary,
                              size: 36,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  if (item.url.isEmpty) {
                    return Container(
                      color: colorScheme.surfaceContainerHighest,
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.image_not_supported,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    );
                  }

                  return AppImage(
                    imageUrl: item.url,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    placeholderIcon: Icons.image_not_supported,
                  );
                },
              ),
              Positioned(
                right: 16,
                bottom: 16,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: colorScheme.surface.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: Text(
                    '$watchCount ♡',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 76,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: safeItems.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final item = safeItems[index];
              final active = index == currentIndex;
              return GestureDetector(
                onTap: () => onPageChanged(index),
                child: Container(
                  width: 76,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: active
                          ? colorScheme.primary
                          : colorScheme.outlineVariant,
                      width: active ? 2 : 1,
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Positioned.fill(
                        child: item.thumb.isEmpty
                            ? Container(
                                color: colorScheme.surfaceContainerHighest,
                              )
                            : AppImage(
                                imageUrl: item.thumb,
                                fit: BoxFit.cover,
                                width: double.infinity,
                              ),
                      ),
                      if (item.type == _MediaType.video)
                        Icon(
                          Icons.play_circle_fill,
                          size: 24,
                          color: colorScheme.onPrimary,
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _PriceSection extends StatefulWidget {
  const _PriceSection({required this.product});

  final ProductModel product;

  @override
  State<_PriceSection> createState() => _PriceSectionState();
}

class _PriceSectionState extends State<_PriceSection> {
  Timer? _ticker;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    if (widget.product.discountEndAt != null) {
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        setState(() {
          _now = DateTime.now();
        });
      });
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final endAt = product.discountEndAt?.toLocal();
    final oldPrice = product.oldPrice;
    final oldPriceIsValid = oldPrice != null && oldPrice > product.price;
    final isTimerActive = endAt == null || _now.isBefore(endAt);
    final hasOld = oldPriceIsValid && isTimerActive;
    final discount =
        hasOld ? (((oldPrice - product.price) / oldPrice) * 100).round() : 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${product.price.toStringAsFixed(0)} ${product.currency ?? 'د.ع'}',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        if (hasOld) ...[
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                '${oldPrice.toStringAsFixed(0)} ${product.currency ?? 'د.ع'}',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      decoration: TextDecoration.lineThrough,
                    ),
              ),
              Text(
                '($discount% ${context.tr(ar: 'خصم', en: 'off', ckb: 'داشکاندن', ku: 'kêmkirin')})',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
          if (endAt != null) ...[
            const SizedBox(height: 6),
            _DiscountCountdown(endAt: endAt),
          ],
        ],
      ],
    );
  }
}

class _DiscountCountdown extends StatefulWidget {
  const _DiscountCountdown({required this.endAt});

  final DateTime endAt;

  @override
  State<_DiscountCountdown> createState() => _DiscountCountdownState();
}

class _DiscountCountdownState extends State<_DiscountCountdown> {
  Timer? _timer;
  Duration _remaining = Duration.zero;

  @override
  void initState() {
    super.initState();
    _updateRemaining();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      _updateRemaining();
    });
  }

  @override
  void didUpdateWidget(covariant _DiscountCountdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.endAt != widget.endAt) {
      _updateRemaining();
    }
  }

  void _updateRemaining() {
    final diff = widget.endAt.difference(DateTime.now());
    setState(() {
      _remaining = diff.isNegative ? Duration.zero : diff;
    });
    if (_remaining == Duration.zero) {
      _timer?.cancel();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_remaining == Duration.zero) {
      return const SizedBox.shrink();
    }

    final days = _remaining.inDays;
    final hours = _remaining.inHours.remainder(24).toString().padLeft(2, '0');
    final minutes =
        _remaining.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds =
        _remaining.inSeconds.remainder(60).toString().padLeft(2, '0');

    final text = days > 0
        ? context.tr(
            ar: 'ينتهي الخصم خلال $days يوم $hours:$minutes:$seconds',
            en: 'Discount ends in $days day(s) $hours:$minutes:$seconds',
            ckb: 'داشکاندن کۆتایی دێت لە $days ڕۆژ $hours:$minutes:$seconds',
            ku: 'Kêmkirin di $days roj de diqede $hours:$minutes:$seconds',
          )
        : context.tr(
            ar: 'ينتهي الخصم خلال $hours:$minutes:$seconds',
            en: 'Discount ends in $hours:$minutes:$seconds',
            ckb: 'داشکاندن کۆتایی دێت لە $hours:$minutes:$seconds',
            ku: 'Kêmkirin di $hours:$minutes:$seconds de diqede',
          );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Theme.of(context).colorScheme.primaryContainer,
      ),
      child: Text(
        text,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onPrimaryContainer,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 135,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

class _QaItem {
  const _QaItem({required this.question, required this.answer});

  final String question;
  final String answer;
}

enum _MediaType { image, video }

class _MediaItem {
  const _MediaItem({
    required this.type,
    required this.url,
    required this.thumb,
  });

  final _MediaType type;
  final String url;
  final String thumb;
}

class _VideoPlayerDialog extends StatefulWidget {
  const _VideoPlayerDialog({required this.url});

  final String url;

  @override
  State<_VideoPlayerDialog> createState() => _VideoPlayerDialogState();
}

class _VideoPlayerDialogState extends State<_VideoPlayerDialog> {
  VideoPlayerController? _controller;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    try {
      final controller =
          VideoPlayerController.networkUrl(Uri.parse(widget.url));
      await controller.initialize();
      await controller.setLooping(true);
      await controller.play();
      if (!mounted) {
        controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = context.tr(
          watch: false,
          ar: 'تعذر تشغيل الفيديو داخل التطبيق',
          en: 'Unable to play video in-app',
          ckb: 'ناتوانرێت ڤیدیۆ لە ناو بەرنامە پەخش بکرێت',
          ku: 'Video di nav appê de nayê lîstin',
        );
      });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.black,
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 40),
      child: Stack(
        children: [
          Positioned.fill(
            child: Center(
              child: _isLoading
                  ? const CircularProgressIndicator()
                  : (_error != null || _controller == null)
                      ? Padding(
                          padding: const EdgeInsets.all(20),
                          child: Text(
                            _error ??
                                context.tr(
                                  ar: 'تعذر تشغيل الفيديو',
                                  en: 'Unable to play video',
                                  ckb: 'ناتوانرێت ڤیدیۆ پەخش بکرێت',
                                  ku: 'Video nayê lîstin',
                                ),
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white),
                          ),
                        )
                      : AspectRatio(
                          aspectRatio: _controller!.value.aspectRatio,
                          child: VideoPlayer(_controller!),
                        ),
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
