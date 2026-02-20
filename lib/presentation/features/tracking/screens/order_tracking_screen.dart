import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/services/device_token_service.dart';
import '../../../../data/models/notification/notification_model.dart';
import '../../../../data/models/order/order_model.dart';
import '../../../../data/repositories/order_repository.dart';
import '../../../../data/repositories/notification_repository.dart';
import '../../../../data/repositories/product_repository.dart';
import '../../../../core/services/tracking_service.dart';
import '../../../../core/localization/language_text.dart';
import '../../../../utils/local_storage.dart' as app_storage;
import '../../../providers/cart_provider.dart';
import '../../../routing/navigation_helpers.dart';
import '../../../routing/route_names.dart';

class OrderTrackingScreen extends StatefulWidget {
  final String? orderNumber;
  final String? phone;

  const OrderTrackingScreen({super.key, this.orderNumber, this.phone});

  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen> {
  final _orderController = TextEditingController();
  final _phoneController = TextEditingController();
  OrderModel? _order;
  bool _loading = false;
  bool _loadingOrderNotifications = false;
  bool _loadingRecentOrders = false;
  bool _reordering = false;
  bool _autoSearchPending = false;
  String? _currentUserId;
  Map<String, dynamic>? _latestAccountOrder;
  List<NotificationModel> _orderNotifications = [];
  List<String> _recentOrderNumbers = [];

  late final OrderRepository _orderRepository;
  late final NotificationRepository _notificationRepository;
  late final ProductRepository _productRepository;

  @override
  void initState() {
    super.initState();
    _orderRepository = context.read<OrderRepository>();
    _notificationRepository = context.read<NotificationRepository>();
    _productRepository = context.read<ProductRepository>();
    TrackingService.instance.trackScreen('order_tracking');
    _currentUserId = Supabase.instance.client.auth.currentUser?.id;
    if (widget.orderNumber != null) {
      _orderController.text = widget.orderNumber!;
      _autoSearchPending = true;
    }
    if (widget.phone != null && widget.phone!.isNotEmpty) {
      _phoneController.text = widget.phone!;
    }
    Future.microtask(_loadSavedPhone);
    if (_currentUserId != null && _currentUserId!.isNotEmpty) {
      Future.microtask(_loadRecentOrders);
    }
  }

  @override
  void dispose() {
    _orderController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final orderNumber = _orderController.text.trim();
    final phone = _phoneController.text.trim();

    if (orderNumber.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.tr(
                watch: false,
                ar: 'يرجى إدخال رقم الطلب أولاً',
                en: 'Please enter the order number first.',
                ckb: 'تکایە سەرەتا ژمارەی داوا بنووسە.',
                ku: 'Ji kerema xwe re berê hejmara fermanê binivîse.',
              ),
            ),
          ),
        );
      }
      return;
    }

    if (phone.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.tr(
                watch: false,
                ar: 'يرجى إدخال رقم الهاتف أولاً',
                en: 'Please enter the phone number first.',
                ckb: 'تکایە سەرەتا ژمارەی تەلەفۆن بنووسە.',
                ku: 'Ji kerema xwe re berê hejmara telefonê binivîse.',
              ),
            ),
          ),
        );
      }
      return;
    }

    TrackingService.instance.trackEvent(
      eventName: 'order_tracking_search',
      eventCategory: 'tracking',
      screen: 'order_tracking',
      metadata: {
        'order_number': orderNumber,
      },
    );
    setState(() {
      _loading = true;
      _order = null;
      _orderNotifications = [];
    });
    try {
      final result = await _orderRepository.trackOrder(
        orderNumber: orderNumber,
        phone: phone,
      );
      setState(
          () => _order = result == null ? null : OrderModel.fromMap(result));
      if (phone.isNotEmpty) {
        await app_storage.LocalStorage.saveUserPhone(phone);
      }
      if (result != null && _currentUserId != null) {
        await app_storage.LocalStorage.saveUserOrderNumber(
          userId: _currentUserId!,
          orderNumber: orderNumber,
        );
        await _loadRecentOrders();
      }
      if (result != null) {
        final orderNumber = _order?.orderNumber;
        if (orderNumber != null && orderNumber.isNotEmpty) {
          await _loadOrderNotifications(orderNumber);
          await DeviceTokenService.instance.updateDeviceWithPhoneAndOrder(
            phone: phone,
            orderNumber: orderNumber,
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                context.tr(
                  watch: false,
                  ar: 'الطلب غير موجود أو البيانات غير صحيحة',
                  en: 'Order not found or provided data is incorrect.',
                  ckb: 'داواکاری نەدۆزرایەوە یان زانیارییەکان دروست نین.',
                  ku: 'Ferman nehat dîtin an dane ne rast in.',
                ),
              ),
            ),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadOrderNotifications(String orderNumber) async {
    setState(() => _loadingOrderNotifications = true);
    try {
      final result =
          await _notificationRepository.fetchOrderNotifications(orderNumber);
      if (mounted) {
        setState(() => _orderNotifications = result);
      }
    } catch (e, st) {
      debugPrint('Error loading order notifications: $e\n$st');
    } finally {
      if (mounted) {
        setState(() => _loadingOrderNotifications = false);
      }
    }
  }

  Future<void> _loadSavedPhone() async {
    final savedPhone = await app_storage.LocalStorage.getUserPhone();
    if (savedPhone != null && savedPhone.isNotEmpty && mounted) {
      _phoneController.text = savedPhone;
    }
    _maybeAutoSearch();
  }

  Future<void> _loadRecentOrders() async {
    if (_currentUserId == null || _currentUserId!.isEmpty) return;
    setState(() => _loadingRecentOrders = true);
    try {
      final localOrders =
          await app_storage.LocalStorage.getUserOrderNumbers(_currentUserId!);
      final remoteRows = await _orderRepository.fetchMyOrders(limit: 30);
      final remoteOrders = remoteRows
          .map((row) => row['order_number']?.toString() ?? '')
          .where((number) => number.trim().isNotEmpty)
          .map((number) => number.trim())
          .toList();

      final merged = <String>[];
      for (final number in [...remoteOrders, ...localOrders]) {
        if (!merged.contains(number)) {
          merged.add(number);
        }
      }

      Map<String, dynamic>? latestOrder;
      for (final row in remoteRows) {
        final number = row['order_number']?.toString().trim() ?? '';
        if (number.isNotEmpty) {
          latestOrder = row;
          break;
        }
      }

      if (mounted) {
        setState(() {
          _recentOrderNumbers = merged;
          _latestAccountOrder = latestOrder;
        });
      }
    } finally {
      if (mounted) {
        setState(() => _loadingRecentOrders = false);
      }
    }
  }

  DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }

  Future<void> _trackLatestAccountOrder() async {
    final latestNumber =
        _latestAccountOrder?['order_number']?.toString().trim() ?? '';
    if (latestNumber.isEmpty) return;

    _orderController.text = latestNumber;
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr(
              watch: false,
              ar: 'تم تعبئة رقم آخر طلب. أضف رقم هاتفك ثم اضغط بحث.',
              en: 'Latest order number filled. Add your phone then tap Search.',
              ckb:
                  'ژمارەی کۆتا داواکاری نووسرا. تکایە ژمارەی تەلەفۆن زیاد بکە و گەڕان بکە.',
              ku: 'Hejmara fermana dawî têket. Ji kerema xwe re telefonê zêde bike û lê bigere.',
            ),
          ),
        ),
      );
      return;
    }

    await _search();
  }

  Widget _buildLatestAccountOrderCard() {
    final colorScheme = Theme.of(context).colorScheme;
    final latest = _latestAccountOrder;
    if (latest == null) {
      return const SizedBox.shrink();
    }

    final orderNumber = latest['order_number']?.toString().trim() ?? '';
    if (orderNumber.isEmpty) {
      return const SizedBox.shrink();
    }

    final createdAt = _parseDateTime(latest['created_at']);
    final status = latest['status']?.toString();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.history_toggle_off, color: colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    context.tr(
                      ar: 'آخر طلب مرتبط بحسابك',
                      en: 'Latest order linked to your account',
                      ckb: 'کۆتا داواکاری پەیوەست بە هەژمارەکەت',
                      ku: 'Fermana dawî ya girêdayî hesabê te',
                    ),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${context.tr(ar: 'رقم الطلب', en: 'Order number', ckb: 'ژمارەی داوا', ku: 'Hejmara fermanê')}: $orderNumber',
            ),
            const SizedBox(height: 4),
            Text(
              '${context.tr(ar: 'الحالة', en: 'Status', ckb: 'دۆخ', ku: 'Rewş')}: ${_statusTitle(status)}',
            ),
            const SizedBox(height: 4),
            Text(
              '${context.tr(ar: 'وقت الإنشاء', en: 'Created', ckb: 'کاتی دروستکردن', ku: 'Dema afirandinê')}: ${_formatRelativeTime(createdAt)}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _loading ? null : _trackLatestAccountOrder,
                icon: const Icon(Icons.search),
                label: Text(
                  context.tr(
                    ar: 'تتبع الآن',
                    en: 'Track now',
                    ckb: 'ئێستا شوێن بکەوە',
                    ku: 'Niha bişopîne',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _reorderCurrentOrder() async {
    final order = _order;
    if (order == null || order.items.isEmpty || _reordering) return;

    setState(() => _reordering = true);

    final cart = context.read<CartProvider>();
    var added = 0;
    var skipped = 0;

    try {
      for (final item in order.items) {
        if (item.productId.trim().isEmpty) {
          skipped++;
          continue;
        }

        final product =
            await _productRepository.fetchProductById(item.productId.trim());
        if (product == null || !product.isActive) {
          skipped++;
          continue;
        }

        final sellerId = product.sellerId;
        if (sellerId == null || sellerId.trim().isEmpty) {
          skipped++;
          continue;
        }

        final imageUrl = product.imageUrls.isNotEmpty
            ? product.imageUrls.first
            : product.imageUrl;
        final quantity = item.quantity <= 0 ? 1 : item.quantity;

        final ok = cart.addToCart(
          productId: product.id,
          productName: product.name,
          imageUrl: imageUrl,
          sellerId: sellerId,
          size: item.size,
          color: item.color,
          unitPrice: product.price,
          quantity: quantity,
        );

        if (ok) {
          added++;
        } else {
          skipped++;
        }
      }

      if (!mounted) return;
      final message = context.tr(
        watch: false,
        ar: 'تمت إضافة $added عنصر إلى السلة${skipped > 0 ? ' (تم تخطي $skipped)' : ''}',
        en: 'Added $added items to cart${skipped > 0 ? ' ($skipped skipped)' : ''}',
        ckb:
            '$added دانە زیادکرا بۆ سەبەت${skipped > 0 ? ' ($skipped پشتگوێخرا)' : ''}',
        ku: '$added tişt li sepêtê zêde bûn${skipped > 0 ? ' ($skipped hatin derbas kirin)' : ''}',
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          action: added > 0
              ? SnackBarAction(
                  label: context.tr(
                    watch: false,
                    ar: 'عرض السلة',
                    en: 'Open cart',
                    ckb: 'بینینی سەبەت',
                    ku: 'Sepetê veke',
                  ),
                  onPressed: () {
                    if (mounted) {
                      NavigationHelpers.go(context, RouteNames.cart);
                    }
                  },
                )
              : null,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _reordering = false);
      }
    }
  }

  void _maybeAutoSearch() {
    if (!_autoSearchPending) return;
    if (_orderController.text.trim().isEmpty) return;
    if (_phoneController.text.trim().isEmpty) return;
    _autoSearchPending = false;
    Future.microtask(_search);
  }

  String _statusTitle(String? status) {
    switch (status) {
      case 'rejected':
        return context.tr(
          ar: 'تم رفض الطلب',
          en: 'Order was rejected',
          ckb: 'داواکارییەکە ڕەتکرایەوە',
          ku: 'Ferman hate redkirin',
        );
      case 'accepted':
        return context.tr(
          ar: 'تم قبول الطلب',
          en: 'Order accepted',
          ckb: 'داواکارییەکە پەسەندکرا',
          ku: 'Ferman hate pejirandin',
        );
      case 'pending_review':
        return context.tr(
          ar: 'الطلب قيد المراجعة',
          en: 'Order under review',
          ckb: 'داواکارییەکە لە پێداچوونەوەدایە',
          ku: 'Ferman di nirxandinê de ye',
        );
      default:
        return context.tr(
          ar: 'حالة الطلب',
          en: 'Order status',
          ckb: 'دۆخی داواکاری',
          ku: 'Rewşa fermanê',
        );
    }
  }

  String _statusSubtitle(OrderModel order) {
    final status = order.status;
    if (status == 'rejected') {
      final reason = order.rejectionReason;
      if (reason != null && reason.trim().isNotEmpty) {
        return '${context.tr(ar: 'سبب الرفض', en: 'Rejection reason', ckb: 'هۆکاری ڕەتکردنەوە', ku: 'Sedema redkirinê')}: $reason';
      }
      return context.tr(
        ar: 'يمكنك تعديل الطلب وإعادة المحاولة.',
        en: 'You can adjust the request and try again.',
        ckb: 'دەتوانیت داواکارییەکە دەستکاری بکەیت و دووبارە هەوڵبدەیت.',
        ku: 'Tu dikarî daxwazê rast bikî û dîsa biceribînî.',
      );
    }
    if (status == 'accepted') {
      return context.tr(
        ar: 'يجري تجهيز طلبك حالياً.',
        en: 'Your order is currently being prepared.',
        ckb: 'ئێستا داواکارییەکەت ئامادەدەکرێت.',
        ku: 'Fermana te niha tê amadekirin.',
      );
    }
    if (status == 'pending_review') {
      return context.tr(
        ar: 'فريقنا يراجع الطلب الآن.',
        en: 'Our team is reviewing your order now.',
        ckb: 'تیمەکەمان ئێستا داواکارییەکەت دەبینێت.',
        ku: 'Tîmê me niha fermana te dinirxîne.',
      );
    }
    return '${context.tr(ar: 'الحالة الحالية', en: 'Current status', ckb: 'دۆخی ئێستا', ku: 'Rewşa niha')}: ${status ?? '-'}';
  }

  IconData _statusIcon(String? status) {
    switch (status) {
      case 'rejected':
        return Icons.cancel_outlined;
      case 'accepted':
        return Icons.check_circle_outline;
      case 'pending_review':
        return Icons.pending_outlined;
      default:
        return Icons.info_outline;
    }
  }

  Color _statusColor(String? status, ColorScheme colorScheme) {
    switch (status) {
      case 'rejected':
        return colorScheme.error;
      case 'accepted':
        return colorScheme.primary;
      case 'pending_review':
        return colorScheme.tertiary;
      default:
        return colorScheme.onSurfaceVariant;
    }
  }

  String _formatRelativeTime(DateTime? dateTime) {
    if (dateTime == null) {
      return context.tr(
        ar: 'بدون وقت',
        en: 'No time',
        ckb: 'کات نییە',
        ku: 'Dem tune',
      );
    }
    final diff = DateTime.now().difference(dateTime.toLocal());
    if (diff.inMinutes < 1) {
      return context.tr(
        ar: 'الآن',
        en: 'Now',
        ckb: 'ئێستا',
        ku: 'Niha',
      );
    }
    if (diff.inHours < 1) {
      return context.tr(
        ar: 'قبل ${diff.inMinutes} دقيقة',
        en: '${diff.inMinutes} min ago',
        ckb: '${diff.inMinutes} خولەک لەمەوبەر',
        ku: '${diff.inMinutes} deq berê',
      );
    }
    if (diff.inDays < 1) {
      return context.tr(
        ar: 'قبل ${diff.inHours} ساعة',
        en: '${diff.inHours}h ago',
        ckb: '${diff.inHours} کاتژمێر لەمەوبەر',
        ku: '${diff.inHours} saet berê',
      );
    }
    return context.tr(
      ar: 'قبل ${diff.inDays} يوم',
      en: '${diff.inDays}d ago',
      ckb: '${diff.inDays} ڕۆژ لەمەوبەر',
      ku: '${diff.inDays} roj berê',
    );
  }

  Widget _buildOrderStatusCard(OrderModel order) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = _statusColor(order.status, colorScheme);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(_statusIcon(order.status), color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _statusTitle(order.status),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 4),
                Text(_statusSubtitle(order)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final items = _order?.items ?? const [];

    return Scaffold(
      appBar: AppBar(
        title: Text(
          context.tr(
            ar: 'تتبع الطلب',
            en: 'Track order',
            ckb: 'شوێنکەوتنی داوا',
            ku: 'Şopandina fermanê',
          ),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_currentUserId != null) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!_loadingRecentOrders &&
                        _latestAccountOrder != null) ...[
                      _buildLatestAccountOrderCard(),
                      const SizedBox(height: 10),
                    ],
                    Row(
                      children: [
                        Icon(Icons.receipt_long_outlined,
                            color: colorScheme.primary),
                        const SizedBox(width: 8),
                        Text(
                          context.tr(
                            ar: 'طلباتي',
                            en: 'My orders',
                            ckb: 'داواکارییەکانم',
                            ku: 'Fermanên min',
                          ),
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (_loadingRecentOrders)
                      const AppLoading(
                          padding: EdgeInsets.symmetric(vertical: 8)),
                    if (!_loadingRecentOrders && _recentOrderNumbers.isEmpty)
                      Text(
                        context.tr(
                          ar: 'لا توجد طلبات محفوظة بعد',
                          en: 'No saved orders yet.',
                          ckb: 'هیچ داواکارییەکی هەڵگیراو نییە.',
                          ku: 'Hêj fermana tomarkirî tune.',
                        ),
                      ),
                    if (!_loadingRecentOrders && _recentOrderNumbers.isNotEmpty)
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _recentOrderNumbers
                            .map(
                              (number) => ActionChip(
                                avatar: const Icon(Icons.search, size: 18),
                                label: Text(number),
                                onPressed: _loading
                                    ? null
                                    : () {
                                        _orderController.text = number;
                                        _search();
                                      },
                              ),
                            )
                            .toList(),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr(
                      ar: 'أدخل رقم الطلب ورقم الهاتف لتتبع الطلب',
                      en: 'Enter order number and phone to track your order',
                      ckb:
                          'ژمارەی داوا و ژمارەی مۆبایل بنووسە بۆ شوێنکەوتنی داواکاری',
                      ku: 'Hejmara fermanê û telefonê binivîse da ku fermanê bişopîne',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _orderController,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      prefixIcon:
                          const Icon(Icons.confirmation_number_outlined),
                      labelText: context.tr(
                        ar: 'رقم الطلب',
                        en: 'Order number',
                        ckb: 'ژمارەی داوا',
                        ku: 'Hejmara fermanê',
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    onSubmitted: (_) {
                      if (!_loading) {
                        _search();
                      }
                    },
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.phone_outlined),
                      labelText: context.tr(
                        ar: 'رقم الهاتف',
                        en: 'Phone number',
                        ckb: 'ژمارەی تەلەفۆن',
                        ku: 'Hejmara telefonê',
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _search,
                      child: _loading
                          ? const AppLoading(
                              size: 18,
                              padding: EdgeInsets.zero,
                            )
                          : Text(
                              context.tr(
                                ar: 'بحث',
                                en: 'Search',
                                ckb: 'گەڕان',
                                ku: 'Lêgerîn',
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (_order != null) ...[
            _buildOrderStatusCard(_order!),
            const SizedBox(height: 10),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr(
                        ar: 'ملخص الطلب',
                        en: 'Order summary',
                        ckb: 'کورتەی داوا',
                        ku: 'Kurteya fermanê',
                      ),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${context.tr(ar: 'رقم الطلب', en: 'Order number', ckb: 'ژمارەی داوا', ku: 'Hejmara fermanê')}: ${_order?.orderNumber ?? '-'}',
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${context.tr(ar: 'عدد العناصر', en: 'Items count', ckb: 'ژمارەی کاڵاکان', ku: 'Hejmara tiştan')}: ${items.length}',
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _reordering ? null : _reorderCurrentOrder,
                        icon: _reordering
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.replay_outlined),
                        label: Text(
                          context.tr(
                            ar: 'إعادة الطلب',
                            en: 'Reorder items',
                            ckb: 'دووبارەکردنەوەی داواکاری',
                            ku: 'Fermanê dîsa bike',
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (_loadingOrderNotifications)
            const AppLoading(padding: EdgeInsets.symmetric(vertical: 16)),
          if (_orderNotifications.isNotEmpty) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(Icons.notifications_active_outlined,
                    color: colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  context.tr(
                    ar: 'تحديثات الطلب',
                    en: 'Order updates',
                    ckb: 'نوێکارییەکانی داوا',
                    ku: 'Nûkirinên fermanê',
                  ),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ..._orderNotifications.map((n) {
              final title = n.title;
              final body = n.body;
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    radius: 16,
                    backgroundColor: colorScheme.primaryContainer,
                    child: Icon(
                      Icons.notifications_none,
                      size: 18,
                      color: colorScheme.onPrimaryContainer,
                    ),
                  ),
                  title: Text(title),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text(body),
                      const SizedBox(height: 4),
                      Text(
                        _formatRelativeTime(n.createdAt),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
              );
            })
          ]
        ],
      ),
    );
  }
}
