import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/localization/language_text.dart';
import '../../../../data/datasources/remote/supabase_rfq_datasource.dart';
import '../../../../data/models/product/product_model.dart';
import '../../../../data/repositories/product_repository.dart';
import '../../../providers/cart_provider.dart';
import '../../../../utils/local_storage.dart';
import '../../../routing/navigation_helpers.dart';
import '../../../routing/route_names.dart';

class RfqOffersScreen extends StatefulWidget {
  const RfqOffersScreen({
    super.key,
    required this.requestNumber,
  });

  final String requestNumber;

  @override
  State<RfqOffersScreen> createState() => _RfqOffersScreenState();
}

class _RfqOffersScreenState extends State<RfqOffersScreen> {
  final _ds = SupabaseRfqDataSource();

  String? _accessToken;

  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _offers = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final tokenNotFoundMessage = context.tr(
      watch: false,
      ar: 'لم يتم العثور على رمز هذا الطلب على هذا الجهاز. أنشئ طلباً جديداً أو افتح الطلب من قائمة طلباتي.',
      en: 'Request token not found on this device. Create a new request or open it from My Requests.',
      ckb:
          'تۆکنی ئەم داواکارییە لەسەر ئەم ئامێرە نەدۆزرایەوە. داواکاری نوێ دروست بکە یان لە لیستی داواکارییەکانم بکەرەوە.',
      ku: 'Tokena vê daxwazê li ser vê amûrê nehat dîtin. Daxwazek nû çêbike an ji Lîsteya daxwazên min veke.',
    );

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final saved = await LocalStorage.getRfqRequests();
      final match = saved.firstWhere(
        (e) => e['requestNumber'] == widget.requestNumber,
        orElse: () => <String, String>{},
      );

      final accessToken = match['accessToken'];
      final phone = match['customerPhone'];

      if (accessToken == null || accessToken.isEmpty) {
        throw Exception(tokenNotFoundMessage);
      }

      _accessToken = accessToken;

      final offers = await _ds.listOffersPublic(
        requestNumber: widget.requestNumber,
        customerPhone: (phone != null && phone.isNotEmpty) ? phone : null,
        accessToken: accessToken,
      );

      if (!mounted) return;
      setState(() {
        _offers = offers;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _openWhatsApp({
    required String phone,
    required String sellerName,
  }) async {
    String normalizePhoneForWhatsApp(String input) {
      const arabicDigits = '٠١٢٣٤٥٦٧٨٩';
      const persianDigits = '۰۱۲۳۴۵۶۷۸۹';
      final buffer = StringBuffer();
      for (final rune in input.runes) {
        final ch = String.fromCharCode(rune);
        final arabicIndex = arabicDigits.indexOf(ch);
        if (arabicIndex != -1) {
          buffer.write(arabicIndex);
          continue;
        }
        final persianIndex = persianDigits.indexOf(ch);
        if (persianIndex != -1) {
          buffer.write(persianIndex);
          continue;
        }
        if (RegExp(r'\d').hasMatch(ch)) {
          buffer.write(ch);
        }
      }

      var digits = buffer.toString();
      if (digits.startsWith('00')) {
        digits = digits.substring(2);
      }
      if (digits.startsWith('0') && digits.length == 11) {
        digits = '964${digits.substring(1)}';
      }
      return digits;
    }

    final normalized = normalizePhoneForWhatsApp(phone);
    final text = Uri.encodeComponent(
      context.tr(
        watch: false,
        ar: 'مرحبا $sellerName، هذا طلب تسعير رقم ${widget.requestNumber}.',
        en: 'Hello $sellerName, this is quotation request number ${widget.requestNumber}.',
        ckb:
            'سڵاو $sellerName، ئەمە داواکاری نرخی ژمارەی ${widget.requestNumber} ـە.',
        ku: 'Silav $sellerName, ev daxwaza bihayê ya bi hejmar ${widget.requestNumber} e.',
      ),
    );
    final uri = Uri.parse('https://wa.me/$normalized?text=$text');

    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr(
              watch: false,
              ar: 'تعذر فتح واتساب',
              en: 'Unable to open WhatsApp',
              ckb: 'ناتوانرێت واتساپ بکرێتەوە',
              ku: 'WhatsApp venabe',
            ),
          ),
        ),
      );
    }
  }

  Future<void> _addOfferToCart(Map<String, dynamic> offer) async {
    final productId = offer['product_id']?.toString();
    final sellerId = offer['seller_id']?.toString();
    if (productId == null || productId.isEmpty || sellerId == null) return;

    final cart = context.read<CartProvider>();

    if (cart.sellerId != null && cart.sellerId != sellerId) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(
            context.tr(
              ar: 'السلة تحتوي منتجات من تاجر آخر',
              en: 'Cart has products from another seller',
              ckb: 'سەبەتەکە کاڵای فرۆشیارێکی تر تێدایە',
              ku: 'Sepetê de berhemên firoşkarekî din hene',
            ),
          ),
          content: Text(
            context.tr(
              ar: 'هل تريد تفريغ السلة وإضافة هذا العرض؟',
              en: 'Do you want to clear the cart and add this offer?',
              ckb: 'دەتەوێت سەبەتەکە بەتاڵ بکەیت و ئەم پێشنیارە زیاد بکەیت؟',
              ku: 'Tu dixwazî sepetê vala bikî û vê pêşniyarê zêde bikî?',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                context.tr(
                  ar: 'إلغاء',
                  en: 'Cancel',
                  ckb: 'هەڵوەشاندنەوە',
                  ku: 'Betal',
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(
                context.tr(
                  ar: 'تفريغ وإضافة',
                  en: 'Clear and add',
                  ckb: 'بەتاڵکردن و زیادکردن',
                  ku: 'Vala bike û zêde bike',
                ),
              ),
            ),
          ],
        ),
      );

      if (!mounted) return;

      if (confirmed != true) return;
      cart.clear();
    }

    final repo = context.read<ProductRepository>();
    final ProductModel? product = await repo.fetchProductById(productId);
    if (product == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr(
              watch: false,
              ar: 'تعذر جلب بيانات المنتج لهذا العرض',
              en: 'Unable to fetch product data for this offer',
              ckb: 'ناتوانرێت زانیاری کاڵا بۆ ئەم پێشنیارە بهێنرێت',
              ku: 'Nikare daneya berhemê ji bo vê pêşniyarê were anîn',
            ),
          ),
        ),
      );
      return;
    }

    final image = product.imageUrls.isNotEmpty ? product.imageUrls.first : '';

    final ok = cart.addToCart(
      productId: product.id,
      productName: product.name,
      imageUrl: image,
      sellerId: product.sellerId ?? sellerId,
      unitPrice: product.price,
      quantity: 1,
    );

    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr(
              watch: false,
              ar: 'تعذر إضافة المنتج إلى السلة',
              en: 'Unable to add product to cart',
              ckb: 'ناتوانرێت کاڵا زیاد بکرێت بۆ سەبەت',
              ku: 'Nikare berhem li sepêtê zêde bibe',
            ),
          ),
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          context.tr(
            watch: false,
            ar: 'تمت إضافة العرض إلى السلة',
            en: 'Offer added to cart',
            ckb: 'پێشنیارەکە زیادکرا بۆ سەبەت',
            ku: 'Pêşniyar li sepêtê zêde bû',
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${context.tr(ar: 'عروض الطلب', en: 'Request offers', ckb: 'پێشنیارەکانی داوا', ku: 'Pêşniyarên daxwazê')} ${widget.requestNumber}',
        ),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: context.tr(
              ar: 'تحديث',
              en: 'Refresh',
              ckb: 'نوێکردنەوە',
              ku: 'Nûkirin',
            ),
            onPressed: _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      _error!,
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : _offers.isEmpty
                  ? Center(
                      child: Text(
                        context.tr(
                          ar: 'لا توجد عروض بعد. حاول لاحقاً.',
                          en: 'No offers yet. Try again later.',
                          ckb: 'هێشتا هیچ پێشنیارێک نییە. دواتر هەوڵ بدەوە.',
                          ku: 'Hêj pêşniyar tune ne. Dûv re dîsa biceribîne.',
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _offers.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final offer = _offers[index];
                        final sellerName =
                            offer['seller_store_name']?.toString() ??
                                context.tr(
                                    ar: 'تاجر',
                                    en: 'Seller',
                                    ckb: 'فرۆشیار',
                                    ku: 'Firoşkar');
                        final sellerPhone =
                            offer['seller_phone']?.toString() ?? '';
                        final price = offer['offered_price'];
                        final currency = offer['currency']?.toString() ?? 'IQD';
                        final guaranteed = offer['guaranteed_fit'] == true;
                        final notes = offer['notes']?.toString();
                        final sellerId = offer['seller_id']?.toString() ?? '';

                        return Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        sellerName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ),
                                    if (price != null)
                                      Text(
                                        '$price $currency',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  guaranteed
                                      ? context.tr(
                                          ar: 'التاجر يضمن التوافق',
                                          en: 'Seller guarantees compatibility',
                                          ckb: 'فرۆشیار گونجاوی دڵنیادەکاتەوە',
                                          ku:
                                              'Firoşkar lihevhatinê garantî dike')
                                      : context.tr(
                                          ar: 'بدون ضمان توافق (VIN اختياري)',
                                          en:
                                              'No compatibility guarantee (VIN optional)',
                                          ckb:
                                              'بێ گەرەنتی گونجاوی (VIN ئیختیاری)',
                                          ku: 'Bê garantîya lihevhatinê (VIN vebijarkî)'),
                                  style: TextStyle(
                                    color: guaranteed
                                        ? Colors.green
                                        : Colors.black54,
                                    fontSize: 12,
                                  ),
                                ),
                                if (notes != null && notes.trim().isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Text(notes),
                                  ),
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    OutlinedButton.icon(
                                      onPressed: sellerPhone.trim().isEmpty
                                          ? null
                                          : () => _openWhatsApp(
                                                phone: sellerPhone,
                                                sellerName: sellerName,
                                              ),
                                      icon: const Icon(Icons.chat),
                                      label: Text(
                                        context.tr(
                                            ar: 'واتساب',
                                            en: 'WhatsApp',
                                            ckb: 'واتساپ',
                                            ku: 'WhatsApp'),
                                      ),
                                    ),
                                    OutlinedButton.icon(
                                      onPressed: (_accessToken == null ||
                                              sellerId.isEmpty)
                                          ? null
                                          : () {
                                              NavigationHelpers.push(
                                                context,
                                                RouteNames.rfqChatPath(
                                                  widget.requestNumber,
                                                  sellerId,
                                                ),
                                                extra: {
                                                  'accessToken': _accessToken,
                                                  'sellerName': sellerName,
                                                },
                                              );
                                            },
                                      icon:
                                          const Icon(Icons.chat_bubble_outline),
                                      label: Text(
                                        context.tr(
                                            ar: 'شات',
                                            en: 'Chat',
                                            ckb: 'چات',
                                            ku: 'Chat'),
                                      ),
                                    ),
                                    ElevatedButton.icon(
                                      onPressed: () => _addOfferToCart(offer),
                                      icon: const Icon(Icons.add_shopping_cart),
                                      label: Text(
                                        context.tr(
                                            ar: 'أضف للسلة',
                                            en: 'Add to cart',
                                            ckb: 'زیادکردن بۆ سەبەت',
                                            ku: 'Tevlî sepêtê bike'),
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: () {
                                        NavigationHelpers.go(
                                          context,
                                          RouteNames.cart,
                                        );
                                      },
                                      child: Text(
                                        context.tr(
                                            ar: 'اذهب للسلة',
                                            en: 'Go to cart',
                                            ckb: 'بڕۆ بۆ سەبەت',
                                            ku: 'Biçe sepêtê'),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
    );
  }
}
